"use client";

import { useState } from "react";
import { AGGREGATE_SEED, DEEP_SEED, SHALLOW_SEED, fmt, roundTrip } from "@/lib/knot";

const e = (n: number) => BigInt(Math.floor(n * 1e6)) * 10n ** 12n;

export default function DemoPage() {
  const [stake, setStake] = useState(5);
  const s = e(stake);
  const un = roundTrip(s, SHALLOW_SEED, DEEP_SEED, AGGREGATE_SEED, false);
  const kn = roundTrip(s, SHALLOW_SEED, DEEP_SEED, AGGREGATE_SEED, true);
  const difference = un.pnl - kn.pnl;

  return (
    <div className="wrap py-20 md:py-24">
      <p className="eyebrow mb-2">Demo</p>
      <h1 className="opsz-display font-display text-[2.4rem] font-light leading-[1.02] tracking-[-0.03em] md:text-[3rem]">The cross-pool round trip</h1>
      <p className="mt-3 max-w-2xl text-ink-soft">
        Sell token0 into the skewed pool at its generous rate, then sell the proceeds back through the
        deep pool. This controlled reserve fixture compares independent curves with the same sequence
        under KNOT. It is a mechanics test, not a historical replay or profit forecast.
      </p>

      <div className="mt-8 max-w-md">
        <div className="mb-2 flex items-baseline justify-between">
          <span className="eyebrow">Starting amount</span>
          <span className="tnum font-mono text-sm">{stake.toFixed(1)} token0</span>
        </div>
        <input
          type="range" min={0.5} max={20} step={0.5} value={stake}
          onChange={(ev) => setStake(Number(ev.target.value))}
          className="w-full accent-ocean" aria-label="Attacker stake"
        />
      </div>

      <div className="mt-10 grid gap-5 md:grid-cols-2">
        {[
          { title: "Independent pools", sub: "No federation. Each pool quotes alone.", r: un, bad: true },
          { title: "Under Knot", sub: "Both legs bounded by the aggregate.", r: kn, bad: false },
        ].map((c) => (
          <div key={c.title} className={`card border-2 ${c.bad ? "border-clay/40" : "border-blue"}`}>
            <p className="opsz-text font-display text-xl font-semibold tracking-[-0.01em]">{c.title}</p>
            <p className="mt-1 text-sm text-muted">{c.sub}</p>
            <dl className="mt-5 space-y-2.5 text-sm">
              <div className="flex justify-between border-b border-line pb-2">
                <dt className="text-ink-soft">Leg A · token1 out</dt>
                <dd className="tnum font-mono">{fmt(c.r.legA)}</dd>
              </div>
              <div className="flex justify-between border-b border-line pb-2">
                <dt className="text-ink-soft">Leg B · token0 back</dt>
                <dd className="tnum font-mono">{fmt(c.r.legB)}</dd>
              </div>
            </dl>
            <div className="mt-5">
              <p className="eyebrow mb-1">Fixture P&amp;L</p>
              <p className={`tnum font-display text-3xl tracking-tightest ${c.r.pnl > 0n ? "text-amber" : "text-blue"}`}>
                {c.r.pnl > 0n ? "+" : "-"}{fmt(c.r.pnl > 0n ? c.r.pnl : -c.r.pnl)}
              </p>
              <p className="mt-1 text-sm text-muted">{c.r.pnl > 0n ? "Positive round trip" : "Negative round trip"}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="mt-6 rounded-lg border border-blue bg-blue/5 p-6">
        <p className="eyebrow mb-2">Difference between the two modeled paths</p>
        <p className="tnum font-display text-4xl tracking-tightest text-blue">{fmt(difference)}</p>
        <p className="mt-2 max-w-2xl text-sm text-ink-soft">
          Leg two uses the aggregate state left by leg one. This number is reproducible from the
          contract-model test; it is not claimed as realised LP P&amp;L.
        </p>
      </div>

      <p className="mt-8 font-mono text-xs text-faint">
        Reproduce: <code>forge test --match-contract EconomicViabilityTest -vv</code>
      </p>
    </div>
  );
}
