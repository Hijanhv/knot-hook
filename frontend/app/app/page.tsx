"use client";

import { useMemo, useState } from "react";
import { useAccount } from "wagmi";
import { knotQuote, fmt } from "@/lib/knot";
import Connect from "@/components/Connect";

/**
 * The live hook. Reserves default to the configuration used across the test suite so the page
 * is explorable before anything is deployed; once addresses are set in env they are read live.
 * Every figure is derived from the same arithmetic the contract runs.
 */
const DEFAULTS = { d0: 1000, d1: 1000, s0: 100, s1: 400 };

export default function AppPage() {
  const { isConnected } = useAccount();
  const [pool, setPool] = useState<"shallow" | "deep">("shallow");
  const [amount, setAmount] = useState(5);
  const [r, setR] = useState(DEFAULTS);

  const q = useMemo(() => {
    const e = (n: number) => BigInt(Math.floor(n * 1e6)) * 10n ** 12n;
    const local: [bigint, bigint] = pool === "shallow" ? [e(r.s0), e(r.s1)] : [e(r.d0), e(r.d1)];
    const agg: [bigint, bigint] = [e(r.d0 + r.s0), e(r.d1 + r.s1)];
    return knotQuote(e(amount), local, agg);
  }, [pool, amount, r]);

  const binds = q.withheld > 0n;
  const withheldBps = q.local > 0n ? Number((q.withheld * 10000n) / q.local) : 0;

  return (
    <div className="wrap py-14">
      <div className="mb-10 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="eyebrow mb-2">Live hook</p>
          <h1 className="font-display text-3xl tracking-tightest md:text-4xl">Quote a swap. Watch the bound.</h1>
          <p className="mt-2 max-w-xl text-ink-soft">
            Both quotes are computed from the same constant-product maths the contract runs. The taker
            receives whichever is worse for them.
          </p>
        </div>
        {!isConnected && <Connect />}
      </div>

      <div className="grid gap-6 lg:grid-cols-[380px_1fr]">
        {/* ── controls ── */}
        <div className="card space-y-6">
          <div>
            <p className="eyebrow mb-3">Pool</p>
            <div className="grid grid-cols-2 gap-2">
              {(["shallow", "deep"] as const).map((p) => (
                <button
                  key={p}
                  onClick={() => setPool(p)}
                  className={`rounded-md border px-3 py-2 text-sm capitalize transition-colors ${
                    pool === p ? "border-marine bg-marine/5 text-marine" : "border-line text-ink-soft hover:border-edge"
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>

          <div>
            <div className="mb-2 flex items-baseline justify-between">
              <p className="eyebrow">Amount in</p>
              <span className="tnum font-mono text-sm">{amount.toFixed(1)} token0</span>
            </div>
            <input
              type="range" min={0.5} max={20} step={0.5} value={amount}
              onChange={(e) => setAmount(Number(e.target.value))}
              className="w-full accent-marine"
              aria-label="Amount in"
            />
          </div>

          <div>
            <p className="eyebrow mb-3">Reserves</p>
            <div className="grid grid-cols-2 gap-3">
              {([["s0", "shallow t0"], ["s1", "shallow t1"], ["d0", "deep t0"], ["d1", "deep t1"]] as const).map(
                ([k, label]) => (
                  <label key={k} className="flex flex-col gap-1">
                    <span className="text-[11px] text-muted">{label}</span>
                    <input
                      type="number"
                      value={r[k]}
                      onChange={(e) => setR({ ...r, [k]: Math.max(1, Number(e.target.value)) })}
                      className="tnum rounded-md border border-line bg-surface px-2 py-1.5 font-mono text-sm focus:border-marine focus:outline-none"
                    />
                  </label>
                )
              )}
            </div>
          </div>
        </div>

        {/* ── result ── */}
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="card">
              <p className="eyebrow mb-2">Local pool quote</p>
              <p className="tnum font-display text-3xl tracking-tightest">{fmt(q.local)}</p>
              <p className="mt-1 text-sm text-muted">From this pool&rsquo;s reserves alone</p>
            </div>
            <div className="card">
              <p className="eyebrow mb-2">Federation quote</p>
              <p className="tnum font-display text-3xl tracking-tightest">{fmt(q.aggregate)}</p>
              <p className="mt-1 text-sm text-muted">From the pair&rsquo;s combined reserves</p>
            </div>
          </div>

          <div className={`card border-2 ${binds ? "border-marine" : "border-line"}`}>
            <div className="flex flex-wrap items-end justify-between gap-4">
              <div>
                <p className="eyebrow mb-2">Enforced — what the taker receives</p>
                <p className="tnum font-display text-4xl tracking-tightest text-marine">{fmt(q.enforced)}</p>
              </div>
              {binds ? (
                <div className="text-right">
                  <p className="eyebrow mb-1">Kept with LPs</p>
                  <p className="tnum font-display text-2xl tracking-tightest text-hemp">{fmt(q.withheld)}</p>
                  <p className="tnum font-mono text-xs text-muted">{withheldBps} bps of the local quote</p>
                </div>
              ) : (
                <p className="max-w-[240px] text-sm text-muted">
                  The bound is not binding here. This pool is in line with the pair, so it keeps its own quote.
                </p>
              )}
            </div>
            <div className="mt-5 h-2 overflow-hidden rounded-full bg-surface2">
              <div
                className="h-full rounded-full bg-marine transition-all duration-500"
                style={{ width: `${Math.max(2, 100 - withheldBps / 100)}%` }}
              />
            </div>
            <p className="mt-2 font-mono text-[11px] text-faint">
              enforced ÷ local — the shorter the bar, the harder the bound is biting
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
