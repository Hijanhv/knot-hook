"use client";

import { useEffect, useState } from "react";import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useAccount, useChainId, useWaitForTransactionReceipt, useWriteContract } from "wagmi";
import { CHAIN } from "@/lib/contracts";
import { CHAIN_ID, fmt } from "@/lib/knot";
import type { ActiveDeploymentManifest, Address } from "@/lib/deployment";
import { publicClient } from "@/lib/rpc";
import { useTokenSymbols } from "@/lib/tokens";
import {
  MAX_UINT160,
  MAX_UINT256,
  MAX_UINT48,
  PERMIT2,
  UNIVERSAL_ROUTER,
  encodeExactInput,
  encodeExactOutput,
  erc20Abi,
  faucetAbi,
  fitsRouter,
  formatCooldown,
  permit2Abi,
  requiredSpend,
  routerAbi,
  swapDeadline,
  swapTokens,
} from "@/lib/swap";

type SwapPanelProps = {
  active: ActiveDeploymentManifest;
  hook: Address;
  poolLabel: "shallow" | "deep";
  zeroForOne: boolean;
  exactInput: boolean;
  /** Amount the taker types: input for exact-input, output for exact-output. */
  specifiedAmount: bigint;
  /** Bound quote from preview: minimum output for exact-input, maximum input for exact-output. */
  enforced: bigint;
  /** False when the quote is the deterministic fallback rather than a live read. */
  live: boolean;
};

type PendingAction = "approve" | "permit" | "swap" | "faucet";
type LastTx = { kind: PendingAction; hash: `0x${string}` };

const txUrl = (hash: string) => `${CHAIN.explorer}/tx/${hash}`;

/**
 * Executes the quoted swap through the deployed Universal Router. Reads stay on the
 * public client; only this panel sends wallet transactions: ERC20 approve of Permit2,
 * Permit2 approval of the router, then `execute`. Every step is explicit and every
 * hash links to the explorer, so nothing about the write path is hidden.
 */
/**
 * Gas, estimated on our own transport rather than the wallet's.
 *
 * MetaMask can hand viem a block whose `gasLimit` is missing for a manually added network, and
 * preparation then dies with "Cannot destructure property 'gasLimit' of null" before the
 * transaction is ever offered for signing. It reads as a contract revert but nothing reverted:
 * the same call estimates fine over the public RPC. Estimating here and passing an explicit
 * limit skips the wallet's preparation path. On failure it returns undefined and the wallet
 * estimates as it did before, so this can only add a path, never remove one.
 */
async function gasFor(
  request: {
    address: Address;
    abi: readonly unknown[];
    functionName: string;
    args?: readonly unknown[];
  },
  account: Address
): Promise<bigint | undefined> {
  try {
    const estimate = await publicClient.estimateContractGas({
      ...request,
      account,
    } as Parameters<typeof publicClient.estimateContractGas>[0]);
    return (estimate * 125n) / 100n;
  } catch {
    return undefined;
  }
}

export default function SwapPanel({
  active,
  hook,
  poolLabel,
  zeroForOne,
  exactInput,
  specifiedAmount,
  enforced,
  live,
}: SwapPanelProps) {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const queryClient = useQueryClient();
  const { writeContractAsync } = useWriteContract();
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null);
  const [lastTx, setLastTx] = useState<LastTx | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [nowSeconds] = useState(() => Math.floor(Date.now() / 1000));

  const { input, output } = swapTokens(active, zeroForOne);
  const amountIn = exactInput ? specifiedAmount : enforced;
  const quoteOut = exactInput ? enforced : specifiedAmount;
  const spend = requiredSpend(exactInput, amountIn, enforced);

  const { inSymbol: tokenIn, outSymbol: tokenOut } = useTokenSymbols(input, output);

  const accountQuery = useQuery({
    queryKey: ["knot", CHAIN_ID, "allowances", address, input],
    queryFn: async () => {
      if (!address) throw new Error("Wallet address is required");
      const [balance, allowance, permit] = await Promise.all([
        publicClient.readContract({ address: input, abi: erc20Abi, functionName: "balanceOf", args: [address] }),
        publicClient.readContract({
          address: input,
          abi: erc20Abi,
          functionName: "allowance",
          args: [address, PERMIT2],
        }),
        publicClient.readContract({
          address: PERMIT2,
          abi: permit2Abi,
          functionName: "allowance",
          args: [address, input, UNIVERSAL_ROUTER],
        }),
      ]);
      return { balance, allowance, permitAmount: permit[0], permitExpiry: permit[1] };
    },
    enabled: Boolean(address),
    refetchInterval: 15_000,
  });

  const receipt = useWaitForTransactionReceipt({
    hash: lastTx?.hash,
    chainId: CHAIN_ID,
    query: { enabled: lastTx !== null },
  });

  const faucet = active.faucet ?? null;
  const faucetQuery = useQuery({
    queryKey: ["knot", CHAIN_ID, "faucet", faucet?.address, address],
    queryFn: async () => {
      if (!faucet) throw new Error("No faucet is recorded in the release manifest");
      const [dripAmount, claims, remaining] = await Promise.all([
        publicClient.readContract({ address: faucet.address, abi: faucetAbi, functionName: "dripAmount" }),
        publicClient.readContract({ address: faucet.address, abi: faucetAbi, functionName: "claimsRemaining" }),
        address
          ? publicClient.readContract({
              address: faucet.address,
              abi: faucetAbi,
              functionName: "cooldownRemaining",
              args: [address],
            })
          : Promise.resolve(0n),
      ]);
      return { dripAmount, claims, remaining };
    },
    enabled: faucet !== null,
    refetchInterval: 30_000,
  });

  useEffect(() => {
    if (receipt.isSuccess) void queryClient.invalidateQueries({ queryKey: ["knot"] });
  }, [receipt.isSuccess, queryClient]);

  const swapped = lastTx?.kind === "swap" && receipt.isSuccess;

  const wrongNetwork = isConnected && chainId !== CHAIN_ID;
  const quoteUsable = live && enforced > 0n && fitsRouter(specifiedAmount, enforced);
  const inSymbol = tokenIn ?? (zeroForOne ? "token0" : "token1");
  const outSymbol = tokenOut ?? (zeroForOne ? "token1" : "token0");
  const balance = accountQuery.data?.balance;
  const allowanceOk = (accountQuery.data?.allowance ?? 0n) >= spend && spend > 0n;
  const permitOk =
    (accountQuery.data?.permitAmount ?? 0n) >= spend &&
    spend > 0n &&
    (accountQuery.data?.permitExpiry ?? 0) > nowSeconds;
  const fundsOk = balance !== undefined && balance >= spend && spend > 0n;

  const run = async (kind: PendingAction, fn: () => Promise<`0x${string}`>) => {
    setPendingAction(kind);
    setActionError(null);
    try {
      const hash = await fn();
      setLastTx({ kind, hash });
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Wallet request failed");
    } finally {
      setPendingAction(null);
    }
  };

  const onApprove = () =>
    run("approve", () =>
      (async () => {
        const req = { address: input, abi: erc20Abi, functionName: "approve", args: [PERMIT2, MAX_UINT256] } as const;
        return writeContractAsync({ ...req, chainId: CHAIN_ID, gas: await gasFor(req, address as Address) });
      })()
    );

  const onPermit = () =>
    run("permit", () =>
      (async () => {
        const req = { address: PERMIT2, abi: permit2Abi, functionName: "approve", args: [input, UNIVERSAL_ROUTER, MAX_UINT160, MAX_UINT48] } as const;
        return writeContractAsync({ ...req, chainId: CHAIN_ID, gas: await gasFor(req, address as Address) });
      })()
    );
  const onFaucet = () =>
    run("faucet", () => {
      if (!faucet) throw new Error("No faucet is recorded in the release manifest");
      const req = { address: faucet.address, abi: faucetAbi, functionName: "drip" } as const;
      return (async () =>
        writeContractAsync({ ...req, chainId: CHAIN_ID, gas: await gasFor(req, address as Address) }))();
    });

  const onSwap = () =>
    run("swap", () => {
      const deadline = swapDeadline();
      const key = {
        currency0: active.currencies.currency0,
        currency1: active.currencies.currency1,
        hooks: hook,
      };
      const call = exactInput
        ? encodeExactInput(
            { key, zeroForOne, amountIn: specifiedAmount, amountOutMinimum: enforced },
            input,
            deadline
          )
        : encodeExactOutput(
            { key, zeroForOne, amountOut: specifiedAmount, amountInMaximum: enforced },
            input,
            deadline
          );
      const req = { address: UNIVERSAL_ROUTER, abi: routerAbi, functionName: "execute", args: [call.commands, call.inputs, call.deadline] } as const;
      return (async () =>
        writeContractAsync({ ...req, chainId: CHAIN_ID, gas: await gasFor(req, address as Address) }))();
    });

  const busy = pendingAction !== null || receipt.isLoading;
  const canSwap =
    isConnected && !wrongNetwork && quoteUsable && fundsOk && allowanceOk && permitOk && !busy;

  const steps = [
    { label: "1 · Funded", done: fundsOk },
    { label: "2 · Approved", done: allowanceOk && permitOk },
    { label: "3 · Swapped", done: swapped },
  ] as const;
  const currentStep = steps.findIndex((step) => !step.done);

  return (
    <div className="card">
      <div className="mb-4 flex flex-wrap items-baseline justify-between gap-2">
        <p className="eyebrow">Execute swap · {poolLabel} pool</p>
        <span className="font-mono text-[11px] text-faint">Universal Router</span>
      </div>

      <dl className="space-y-2 text-[14px]">
        <div className="flex justify-between gap-4">
          <dt className="text-muted">You pay</dt>
          <dd className="tnum font-mono">
            {fmt(amountIn)} {inSymbol}
          </dd>
        </div>
        <div className="flex justify-between gap-4">
          <dt className="text-muted">{exactInput ? "You receive at least" : "You receive"}</dt>
          <dd className="tnum font-mono text-blue">
            {fmt(quoteOut)} {outSymbol}
          </dd>
        </div>
        {address && (
          <div className="flex justify-between gap-4">
            <dt className="text-muted">Your {inSymbol} balance</dt>
            <dd className="tnum font-mono">{balance === undefined ? "…" : fmt(balance)}</dd>
          </div>
        )}
      </dl>

      {!isConnected && (
        <p className="mt-4 border-l-2 border-line bg-paper px-3 py-2 text-[13px] text-muted">
          Connect a wallet above to swap. Quotes remain readable without one.
        </p>
      )}

      {isConnected && wrongNetwork && (
        <p className="mt-4 border-l-2 border-amber bg-paper px-3 py-2 text-[13px] text-ink-soft">
          Wrong network. Switch to {CHAIN.name} to continue.
        </p>
      )}

      {isConnected && !wrongNetwork && !quoteUsable && (
        <p className="mt-4 border-l-2 border-amber bg-paper px-3 py-2 text-[13px] text-ink-soft">
          {live
            ? "This quote cannot execute at the current size. Reduce the amount."
            : "Swaps need a live quote. The public RPC is unreachable right now, so only reference values are shown."}
        </p>
      )}

      {isConnected && !wrongNetwork && quoteUsable && balance !== undefined && !fundsOk && (
        <p className="mt-4 border-l-2 border-amber bg-paper px-3 py-2 text-[13px] text-ink-soft">
          Insufficient {inSymbol} for this size. These are Unichain Sepolia test tokens, not mainnet funds.
        </p>
      )}

      {faucet && (
        <div className="mt-4 border-t border-line pt-4">
          <div className="mb-2 flex flex-wrap items-baseline justify-between gap-2">
            <p className="eyebrow">Test tokens</p>
            {faucetQuery.data && (
              <span className="font-mono text-[11px] text-faint">
                {faucetQuery.data.claims.toString()} claims left in faucet
              </span>
            )}
          </div>
          {!isConnected ? (
            <p className="text-[13px] text-muted">
              Connect a wallet to claim free test tokens from the demo faucet.
            </p>
          ) : faucetQuery.data && faucetQuery.data.claims === 0n ? (
            <p className="border-l-2 border-amber bg-paper px-3 py-2 text-[13px] text-ink-soft">
              The faucet is drained. It never mints, so it pays again only after it is refunded.
            </p>
          ) : faucetQuery.data && faucetQuery.data.remaining > 0n ? (
            <p className="text-[13px] text-muted">
              Next claim in {formatCooldown(Number(faucetQuery.data.remaining))}. One claim per
              wallet per cooldown.
            </p>
          ) : (
            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                className="btn-ghost"
                disabled={busy || wrongNetwork || faucetQuery.isPending}
                onClick={() => void onFaucet()}
              >
                {pendingAction === "faucet" ? "Claiming…" : (
                  <>Get {faucetQuery.data ? fmt(faucetQuery.data.dripAmount) : "…"} test tokens</>
                )}
              </button>
              <span className="text-[12px] text-faint">kETH + kUSD · one claim per cooldown</span>
            </div>
          )}
        </div>
      )}

      {isConnected && !wrongNetwork && quoteUsable && (
        <div className="mt-4 space-y-2">
          <ol className="flex flex-wrap items-center gap-x-2 font-mono text-[11px] uppercase tracking-[0.1em]">
            {steps.map((step, index) => (
              <li
                key={step.label}
                className={
                  step.done
                    ? "text-blue"
                    : index === currentStep
                      ? "text-ink"
                      : "text-faint"
                }
              >
                {step.done ? `${step.label} ✓` : step.label}
                {index < steps.length - 1 && <span className="ml-2 text-faint">→</span>}
              </li>
            ))}
          </ol>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              className={allowanceOk ? "btn-ghost pointer-events-none" : "btn-ghost"}
              disabled={allowanceOk || busy || !fundsOk}
              title={
                allowanceOk
                  ? "Token already approved"
                  : balance === undefined
                    ? "Loading balance…"
                    : !fundsOk
                      ? `Insufficient ${inSymbol} — claim test tokens from the faucet above`
                      : "Approve the token for Permit2"
              }
              onClick={() => void onApprove()}
            >
              {allowanceOk ? "1 · Token approved ✓" : pendingAction === "approve" ? "1 · Approving…" : "1 · Approve token"}
            </button>
            <button
              type="button"
              className={permitOk ? "btn-ghost pointer-events-none" : "btn-ghost"}
              disabled={!allowanceOk || permitOk || busy}
              title={
                permitOk
                  ? "Router already approved"
                  : !allowanceOk
                    ? "Approve the token first"
                    : "Approve the router through Permit2"
              }
              onClick={() => void onPermit()}
            >
              {permitOk ? "2 · Router approved ✓" : pendingAction === "permit" ? "2 · Approving…" : "2 · Approve router"}
            </button>
            <button
              type="button"
              className="btn"
              disabled={!canSwap}
              title={
                canSwap
                  ? `Swap at the bound quote`
                  : !fundsOk
                    ? `Insufficient ${inSymbol} — claim test tokens from the faucet above`
                    : !allowanceOk || !permitOk
                      ? "Finish both approvals first"
                      : "Confirm in your wallet to swap"
              }
              onClick={() => void onSwap()}
            >
              {pendingAction === "swap" || (lastTx?.kind === "swap" && receipt.isLoading)
                ? "Swapping…"
                : `Swap ${inSymbol} → ${outSymbol}`}
            </button>
          </div>
          <p className="text-[12px] leading-snug text-faint">
            Two one-time approvals, then the swap. Each step asks the wallet separately and executes
            at the live bound quote shown above.
          </p>
        </div>
      )}

      {actionError && (
        <p role="alert" className="mt-3 text-[13px] leading-snug text-amber">
          {actionError}
        </p>
      )}

      {lastTx && (
        <p className="mt-3 font-mono text-[11px] text-muted">
          {lastTx.kind} ·{" "}
          <a href={txUrl(lastTx.hash)} target="_blank" rel="noopener noreferrer" className="text-blue hover:underline">
            {lastTx.hash.slice(0, 10)}…{lastTx.hash.slice(-8)} ↗
          </a>{" "}
          {receipt.isLoading && "· confirming"}
          {receipt.isSuccess && "· confirmed"}
          {receipt.isError && "· failed to confirm; check the explorer"}
        </p>
      )}

      {swapped && receipt.isSuccess && (
        <p role="status" className="mt-3 border-l-2 border-blue bg-paper px-3 py-2 text-[13px] text-ink-soft">
          Swap confirmed on {CHAIN.name}. Quotes above refresh from the chain automatically.
        </p>
      )}
    </div>
  );
}
