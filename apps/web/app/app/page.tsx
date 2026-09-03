"use client";

import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  AGGREGATE_SEED,
  CHAIN_ID,
  DEEP_SEED,
  SHALLOW_SEED,
  federationAbi,
  fmt,
  previewQuote,
} from "@/lib/knot";
import LiveBadge from "@/components/LiveBadge";
import Connect from "@/components/Connect";
import { chainHeadAgeSeconds, isChainHeadStale, publicClient, readChainHead } from "@/lib/rpc";
import { CHAIN } from "@/lib/contracts";
import { ACTIVE_DEPLOYMENT, DEPLOYMENT, DEPLOYMENT_IS_ACTIVE } from "@/lib/deployment";

const e18 = (n: number) => BigInt(Math.round(n * 1e6)) * 10n ** 12n;

/**
 * Reads the deployed federation directly. `preview` is a view, so quotes come from the same
 * contract a swap would execute against, with no client-side approximation of the rule. If the
 * contracts are unreachable the page labels its deterministic reference model explicitly.
 */
export default function AppPage() {
  const [pool, setPool] = useState<"shallow" | "deep">("shallow");
  const [amount, setAmount] = useState(5);
  const [exactInput, setExactInput] = useState(true);
  const [zeroForOne, setZeroForOne] = useState(true);

  const active = ACTIVE_DEPLOYMENT;
  const hook = active ? (pool === "shallow" ? active.contracts.shallow : active.contracts.deep) : null;
  const reservesQuery = useQuery({
    queryKey: ["knot", CHAIN_ID, "reserves"],
    queryFn: async () => {
      if (!active) throw new Error("An active KNOT release manifest is required");
      const head = await readChainHead();
      const [deep, shallow, aggregate0, aggregate1, members, feeNumerator, feeDenominator] = await Promise.all([
        publicClient.readContract({
          address: active.contracts.federation,
          abi: federationAbi,
          functionName: "reservesOf",
          args: [active.contracts.deep],
          blockNumber: head.number,
        }),
        publicClient.readContract({
          address: active.contracts.federation,
          abi: federationAbi,
          functionName: "reservesOf",
          args: [active.contracts.shallow],
          blockNumber: head.number,
        }),
        publicClient.readContract({ address: active.contracts.federation, abi: federationAbi, functionName: "aggregateReserve0", blockNumber: head.number }),
        publicClient.readContract({ address: active.contracts.federation, abi: federationAbi, functionName: "aggregateReserve1", blockNumber: head.number }),
        publicClient.readContract({ address: active.contracts.federation, abi: federationAbi, functionName: "memberCount", blockNumber: head.number }),
        publicClient.readContract({ address: active.contracts.federation, abi: federationAbi, functionName: "feeNumerator", blockNumber: head.number }),
        publicClient.readContract({ address: active.contracts.federation, abi: federationAbi, functionName: "feeDenominator", blockNumber: head.number }),
      ]);
      return { deep, shallow, aggregate: [aggregate0, aggregate1] as const, members, feeNumerator, feeDenominator, head };
    },
    refetchInterval: 12_000,
    retry: 1,
    enabled: DEPLOYMENT_IS_ACTIVE,
  });

  const previewQuery = useQuery({
    queryKey: ["knot", CHAIN_ID, "preview", hook, zeroForOne, exactInput, amount],
    queryFn: async () => {
      if (!active || !hook) throw new Error("An active KNOT release manifest is required");
      const head = await readChainHead();
      const quote = await publicClient.readContract({
        address: active.contracts.federation,
        abi: federationAbi,
        functionName: "preview",
        args: [hook, zeroForOne, exactInput, e18(amount)],
        blockNumber: head.number,
      });
      return { quote, head };
    },
    enabled: DEPLOYMENT_IS_ACTIVE && amount > 0,
    refetchInterval: 12_000,
    retry: 1,
  });

  // The reference mirrors the manifest's seed state so the page is never empty. It tracks the
  // direction and mode toggles too, so the illustrative numbers match the labels above them.
  const fallback = useMemo(() => {
    const local = pool === "shallow" ? SHALLOW_SEED : DEEP_SEED;
    const q = previewQuote(e18(amount), local, AGGREGATE_SEED, zeroForOne, exactInput);
    return [q.local, q.aggregate, q.enforced] as const;
  }, [pool, amount, zeroForOne, exactInput]);

  const chainRead = previewQuery.isSuccess;
  const [localQ, aggQ, enforcedQ] = chainRead ? previewQuery.data.quote : fallback;
  const quotePrefix = chainRead ? "Live" : "Reference";

  const withheld = exactInput
    ? (localQ > enforcedQ ? localQ - enforcedQ : 0n)
    : (enforcedQ > localQ ? enforcedQ - localQ : 0n);
  const bps = localQ > 0n ? Number((withheld * 10000n) / localQ) : 0;
  const binds = withheld > 0n;

  const dr = reservesQuery.data?.deep;
  const sr = reservesQuery.data?.shallow;
  const aggregate = reservesQuery.data?.aggregate;
  const rpcError = previewQuery.isError || reservesQuery.isError;
  const head = previewQuery.data?.head ?? reservesQuery.data?.head;
  const stale = head ? isChainHeadStale(head) : false;
  const liveStatus = !DEPLOYMENT_IS_ACTIVE
    ? "pending"
    : previewQuery.isPending
      ? "loading"
    : rpcError
      ? "offline"
      : stale
        ? "stale"
        : "live";

  return (
    <div className="wrap py-16 md:py-20">
      <div className="mb-8 flex flex-wrap items-end justify-between gap-4 border-b border-line pb-8">
        <div>
          <div className="mb-3 flex flex-wrap items-center gap-2">
            <span className="eyebrow">Quote inspector</span>
            <LiveBadge
              status={liveStatus}
              block={head?.number}
            />
            <span className="pill">read only · chain {CHAIN_ID}</span>
          </div>
          <h1 className="opsz-display font-display text-[2.4rem] font-light leading-[1.02] tracking-[-0.03em] md:text-[3rem]">
            Quote a swap. Watch the bound.
          </h1>
          <p className="mt-2 max-w-xl text-[15px] leading-[1.55] text-ink-soft">
            Explore the exact boundary enforced by <code className="font-mono text-[13px] text-blue">preview()</code>.
            Live values come directly from the deployed federation; fallback values are explicitly labelled as reference data.
          </p>
        </div>
        <div className="flex flex-col items-end gap-2">
          <Connect />
          {active && (
            <a href={`${CHAIN.explorer}/address/${active.contracts.federation}`} target="_blank" rel="noopener noreferrer" className="font-mono text-[11px] uppercase tracking-[0.12em] text-faint hover:text-blue">
              View deployment ↗
            </a>
          )}
        </div>
      </div>

      {!DEPLOYMENT_IS_ACTIVE && (
        <p role="status" className="mb-5 border-l-2 border-amber bg-paper px-4 py-3 text-sm text-ink-soft">
          Active release metadata is unavailable for {CHAIN.name}. {DEPLOYMENT.statusReason} This read-only inspector
          uses the canonical seed fixture and labels every fallback value as reference data.
        </p>
      )}

      {stale && head && (
        <p role="status" className="mb-5 border-l-2 border-amber bg-paper px-4 py-3 text-sm text-ink-soft">
          The RPC head is {chainHeadAgeSeconds(head)} seconds old, so these reads are labelled stale rather than live.
        </p>
      )}

      {DEPLOYMENT_IS_ACTIVE && rpcError && (
        <div role="alert" className="mb-5 flex flex-wrap items-center justify-between gap-3 border-l-2 border-amber bg-paper px-4 py-3 text-sm text-ink-soft">
          <span>The public RPC did not answer. The quote cards use the manifest fixture and are labelled reference calculations.</span>
          <button type="button" className="btn-ghost shrink-0" onClick={() => { void previewQuery.refetch(); void reservesQuery.refetch(); }}>
            Retry reads
          </button>
        </div>
      )}

      <div className="grid gap-5 lg:grid-cols-[360px_1fr]">
        {/* ── controls ── */}
        <div className="card space-y-6">
          <div>
            <p className="eyebrow mb-3">Pool</p>
            <div className="grid grid-cols-2 gap-1.5">
              {(["shallow", "deep"] as const).map((p) => (
                <button key={p} type="button" aria-pressed={pool === p} onClick={() => setPool(p)}
                  className={`px-3 py-2 font-mono text-xs uppercase tracking-[0.1em] transition-colors ${
                    pool === p ? "rounded-[3px] bg-blue text-white" : "rounded-[3px] bg-surface2 text-muted hover:text-ink"}`}>
                  {p}
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="eyebrow mb-3">Direction</p>
            <div className="grid grid-cols-2 gap-1.5">
              <button type="button" aria-pressed={zeroForOne} onClick={() => setZeroForOne(true)}
                className={`px-3 py-2 font-mono text-xs transition-colors ${zeroForOne ? "bg-ink text-canvas" : "bg-canvas text-muted hover:text-ink"}`}>
                token0 → token1
              </button>
              <button type="button" aria-pressed={!zeroForOne} onClick={() => setZeroForOne(false)}
                className={`px-3 py-2 font-mono text-xs transition-colors ${!zeroForOne ? "bg-ink text-canvas" : "bg-canvas text-muted hover:text-ink"}`}>
                token1 → token0
              </button>
            </div>
          </div>

          <div>
            <p className="eyebrow mb-3">Mode</p>
            <div className="grid grid-cols-2 gap-1.5">
              <button type="button" aria-pressed={exactInput} onClick={() => setExactInput(true)}
                className={`px-3 py-2 font-mono text-xs transition-colors ${exactInput ? "bg-ink text-canvas" : "bg-canvas text-muted hover:text-ink"}`}>
                exact input
              </button>
              <button type="button" aria-pressed={!exactInput} onClick={() => setExactInput(false)}
                className={`px-3 py-2 font-mono text-xs transition-colors ${!exactInput ? "bg-ink text-canvas" : "bg-canvas text-muted hover:text-ink"}`}>
                exact output
              </button>
            </div>
          </div>

          <div>
            <div className="mb-2 flex items-baseline justify-between">
              <p className="eyebrow">{exactInput ? "Amount in" : "Amount out"}</p>
              <span className="tnum font-mono text-sm">{amount.toFixed(1)}</span>
            </div>
            <input type="range" min={0.5} max={25} step={0.5} value={amount}
              onChange={(ev) => setAmount(Number(ev.target.value))}
              className="w-full accent-ocean" aria-label={exactInput ? "Exact input amount" : "Exact output amount"} />
          </div>

          {dr && sr && aggregate && reservesQuery.data && (
            <div className="border-t border-line pt-5">
              <p className="eyebrow mb-3">On-chain reserves</p>
              <dl className="space-y-1.5 font-mono text-[11px]">
                <div className="flex justify-between"><dt className="text-faint">deep</dt><dd className="tnum">{fmt(dr[0], 0)} / {fmt(dr[1], 0)}</dd></div>
                <div className="flex justify-between"><dt className="text-faint">shallow</dt><dd className="tnum">{fmt(sr[0], 0)} / {fmt(sr[1], 0)}</dd></div>
                <div className="flex justify-between border-t border-line pt-1.5 text-blue">
                  <dt>contract aggregate</dt><dd className="tnum">{fmt(aggregate[0], 0)} / {fmt(aggregate[1], 0)}</dd>
                </div>
                <div className="flex justify-between"><dt className="text-faint">members</dt><dd>{reservesQuery.data.members.toString()}</dd></div>
                <div className="flex justify-between"><dt className="text-faint">curve fee</dt><dd>{reservesQuery.data.feeNumerator.toString()} / {reservesQuery.data.feeDenominator.toString()}</dd></div>
              </dl>
            </div>
          )}
        </div>

        {/* ── readout ── */}
        <div className="space-y-5">
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="card">
              <p className="eyebrow mb-2">{quotePrefix} local pool quote</p>
              <p className="tnum figure text-[2rem]">{fmt(localQ)}</p>
              <p className="mt-1 text-[13px] text-muted">This pool&rsquo;s reserves alone</p>
            </div>
            <div className="card">
              <p className="eyebrow mb-2">{quotePrefix} federation quote</p>
              <p className="tnum figure text-[2rem]">{fmt(aggQ)}</p>
              <p className="mt-1 text-[13px] text-muted">Virtual curve from summed member reserves</p>
            </div>
          </div>

          <div className="card">
            <div className="flex flex-wrap items-end justify-between gap-6">
              <div>
                <p className="eyebrow mb-2">Enforced · {exactInput ? "what the taker receives" : "what the taker pays"}</p>
                <p className="tnum figure text-[3.25rem] text-blue">{fmt(enforcedQ)}</p>
                <p className="mt-2 font-mono text-[11px] text-faint">
                  {exactInput ? "min(local, aggregate)" : "max(local, aggregate)"}
                </p>
              </div>
              {binds ? (
                <div className="text-right">
                  <p className="eyebrow mb-1">Kept with LPs</p>
                  <p className="tnum figure text-[2rem] text-blue">{fmt(withheld)}</p>
                  <p className="tnum font-mono text-[11px] text-muted">{bps} bps of the local quote</p>
                </div>
              ) : (
                <p className="max-w-[230px] text-[13px] leading-snug text-muted">
                  Not binding here. This pool is in line with the federation&rsquo;s virtual aggregate curve, so it keeps its own quote.
                </p>
              )}
            </div>

            <div className="mt-6 h-1.5 overflow-hidden rounded-full bg-surface2">
              <div className="h-full rounded-full bg-blue transition-all duration-500"
                style={{ width: `${Math.max(2, 100 - bps / 100)}%` }} />
            </div>
            <p className="mt-2 font-mono text-[10px] uppercase tracking-[0.12em] text-faint">
              enforced ÷ local · a shorter bar means the bound is biting harder
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
