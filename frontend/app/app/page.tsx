"use client";

import { useMemo, useState } from "react";
import { useReadContract, useReadContracts } from "wagmi";
import { federationAbi, FEDERATION_ADDRESS, DEEP_POOL, SHALLOW_POOL, CHAIN_ID, previewQuote, fmt } from "@/lib/knot";
import Connect from "@/components/Connect";
import LiveBadge from "@/components/LiveBadge";

const e18 = (n: number) => BigInt(Math.round(n * 1e6)) * 10n ** 12n;

/**
 * Reads the deployed federation directly. `preview` is a view, so quotes come from the same
 * contract a swap would execute against — no client-side approximation of the rule. If the
 * contracts are unreachable the page falls back to the reference configuration rather than
 * showing an error, so the mechanism stays explorable without a wallet.
 */
export default function AppPage() {
  const [pool, setPool] = useState<"shallow" | "deep">("shallow");
  const [amount, setAmount] = useState(5);
  const [exactInput, setExactInput] = useState(true);
  const [zeroForOne, setZeroForOne] = useState(true);

  const hook = pool === "shallow" ? SHALLOW_POOL : DEEP_POOL;
  const configured = Boolean(FEDERATION_ADDRESS && hook);

  // live reserves for both members, so the aggregate shown is the real one
  const { data: reserveData } = useReadContracts({
    contracts: configured
      ? [
          { address: FEDERATION_ADDRESS as `0x${string}`, abi: federationAbi, functionName: "reservesOf", args: [DEEP_POOL as `0x${string}`], chainId: CHAIN_ID },
          { address: FEDERATION_ADDRESS as `0x${string}`, abi: federationAbi, functionName: "reservesOf", args: [SHALLOW_POOL as `0x${string}`], chainId: CHAIN_ID },
        ]
      : [],
    query: { enabled: configured, refetchInterval: 12_000 },
  });

  const { data: preview, isSuccess: previewOk } = useReadContract({
    address: FEDERATION_ADDRESS as `0x${string}`,
    abi: federationAbi,
    functionName: "preview",
    args: [hook as `0x${string}`, zeroForOne, exactInput, e18(amount)],
    chainId: CHAIN_ID,
    query: { enabled: configured && amount > 0, refetchInterval: 12_000 },
  });

  // Fallback mirrors the deployed seed state so the page is never empty. It tracks the
  // direction and mode toggles too, so the illustrative numbers match the labels above them.
  const fallback = useMemo(() => {
    const local: [bigint, bigint] = pool === "shallow" ? [e18(100), e18(400)] : [e18(1000), e18(1000)];
    const agg: [bigint, bigint] = [e18(1100), e18(1400)];
    const q = previewQuote(e18(amount), local, agg, zeroForOne, exactInput);
    return [q.local, q.aggregate, q.enforced] as const;
  }, [pool, amount, zeroForOne, exactInput]);

  const live = previewOk && Array.isArray(preview);
  const [localQ, aggQ, enforcedQ] = (live ? (preview as readonly bigint[]) : fallback) as readonly bigint[];

  const withheld = exactInput
    ? (localQ > enforcedQ ? localQ - enforcedQ : 0n)
    : (enforcedQ > localQ ? enforcedQ - localQ : 0n);
  const bps = localQ > 0n ? Number((withheld * 10000n) / localQ) : 0;
  const binds = withheld > 0n;

  const dr = reserveData?.[0]?.result as readonly bigint[] | undefined;
  const sr = reserveData?.[1]?.result as readonly bigint[] | undefined;

  return (
    <div className="wrap py-16 md:py-20">
      <div className="mb-8 flex flex-wrap items-end justify-between gap-4 border-b border-line pb-8">
        <div>
          <div className="mb-3 flex flex-wrap items-center gap-2">
            <span className="eyebrow">Live hook</span>
            <LiveBadge live={live} />
          </div>
          <h1 className="font-display text-3xl font-bold tracking-[-0.03em] md:text-4xl">
            Quote a swap. Watch the bound.
          </h1>
          <p className="mt-2 max-w-xl text-[15px] leading-[1.55] text-ink-soft">
            Quotes are read from <code className="font-mono text-[13px] text-blue">preview()</code> on the
            deployed federation — the same call a swap executes against.
          </p>
        </div>
        <Connect />
      </div>

      <div className="grid gap-5 lg:grid-cols-[360px_1fr]">
        {/* ── controls ── */}
        <div className="card space-y-6">
          <div>
            <p className="eyebrow mb-3">Pool</p>
            <div className="grid grid-cols-2 gap-1.5">
              {(["shallow", "deep"] as const).map((p) => (
                <button key={p} onClick={() => setPool(p)}
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
              <button onClick={() => setZeroForOne(true)}
                className={`px-3 py-2 font-mono text-xs transition-colors ${zeroForOne ? "bg-ink text-canvas" : "bg-canvas text-muted hover:text-ink"}`}>
                token0 → token1
              </button>
              <button onClick={() => setZeroForOne(false)}
                className={`px-3 py-2 font-mono text-xs transition-colors ${!zeroForOne ? "bg-ink text-canvas" : "bg-canvas text-muted hover:text-ink"}`}>
                token1 → token0
              </button>
            </div>
          </div>

          <div>
            <p className="eyebrow mb-3">Mode</p>
            <div className="grid grid-cols-2 gap-1.5">
              <button onClick={() => setExactInput(true)}
                className={`px-3 py-2 font-mono text-xs transition-colors ${exactInput ? "bg-ink text-canvas" : "bg-canvas text-muted hover:text-ink"}`}>
                exact input
              </button>
              <button onClick={() => setExactInput(false)}
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
              className="w-full accent-ocean" aria-label="Amount" />
          </div>

          {(dr || sr) && (
            <div className="border-t border-line pt-5">
              <p className="eyebrow mb-3">On-chain reserves</p>
              <dl className="space-y-1.5 font-mono text-[11px]">
                {dr && <div className="flex justify-between"><dt className="text-faint">deep</dt><dd className="tnum">{fmt(dr[0], 0)} / {fmt(dr[1], 0)}</dd></div>}
                {sr && <div className="flex justify-between"><dt className="text-faint">shallow</dt><dd className="tnum">{fmt(sr[0], 0)} / {fmt(sr[1], 0)}</dd></div>}
                {dr && sr && (
                  <div className="flex justify-between border-t border-line pt-1.5 text-blue">
                    <dt>aggregate</dt><dd className="tnum">{fmt(dr[0] + sr[0], 0)} / {fmt(dr[1] + sr[1], 0)}</dd>
                  </div>
                )}
              </dl>
            </div>
          )}
        </div>

        {/* ── readout ── */}
        <div className="space-y-5">
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="card">
              <p className="eyebrow mb-2">Local pool quote</p>
              <p className="tnum figure text-[2rem]">{fmt(localQ)}</p>
              <p className="mt-1 text-[13px] text-muted">This pool&rsquo;s reserves alone</p>
            </div>
            <div className="card">
              <p className="eyebrow mb-2">Federation quote</p>
              <p className="tnum figure text-[2rem]">{fmt(aggQ)}</p>
              <p className="mt-1 text-[13px] text-muted">The pair&rsquo;s combined reserves</p>
            </div>
          </div>

          <div className="card">
            <div className="flex flex-wrap items-end justify-between gap-6">
              <div>
                <p className="eyebrow mb-2">Enforced — {exactInput ? "what the taker receives" : "what the taker pays"}</p>
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
                  Not binding here. This pool is in line with the pair, so it keeps its own quote.
                </p>
              )}
            </div>

            <div className="mt-6 h-1.5 overflow-hidden rounded-full bg-surface2">
              <div className="h-full rounded-full bg-blue transition-all duration-500"
                style={{ width: `${Math.max(2, 100 - bps / 100)}%` }} />
            </div>
            <p className="mt-2 font-mono text-[10px] uppercase tracking-[0.12em] text-faint">
              enforced ÷ local — a shorter bar means the bound is biting harder
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
