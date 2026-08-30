"use client";

import { useState } from "react";
import { knotQuote, amountOut, fmt } from "@/lib/knot";

const e = (n: number) => BigInt(Math.floor(n * 1e6)) * 10n ** 12n;
const D: [bigint, bigint] = [e(1000), e(1000)];
const S: [bigint, bigint] = [e(100), e(400)];
const A: [bigint, bigint] = [e(1100), e(1400)];

/**
 * The cross-pool round trip, run twice: once as if the pools were independent, once under the
 * federation. This is the attack Knot exists to stop, shown rather than described.
 */
function roundTrip(stake: bigint, federated: boolean) {
  const legA = federated ? knotQuote(stake, S, A).enforced : amountOut(stake, S[0], S[1]);
  const legB = federated
    ? knotQuote(legA, [D[1], D[0]], [A[1], A[0]]).enforced
    : amountOut(legA, D[1], D[0]);
  return { legA, legB, pnl: legB - stake };
}

export default function DemoPage() {
  const [stake, setStake] = useState(5);
  const s = e(stake);
  const un = roundTrip(s, false);
  const kn = roundTrip(s, true);
  const removed = un.pnl - kn.pnl;

  return (
    <div className="wrap py-14">
      <p className="eyebrow mb-2">Demo</p>
      <h1 className="font-display text-3xl tracking-tightest md:text-4xl">The cross-pool round trip</h1>
      <p className="mt-3 max-w-2xl text-ink-soft">
        Sell token0 into the skewed pool at its generous rate, then sell the proceeds back through the
        deep pool. When the pools are independent this ends in profit. Run the identical sequence under
        the federation and it does not.
      </p>

      <div className="mt-8 max-w-md">
        <div className="mb-2 flex items-baseline justify-between">
          <span className="eyebrow">Attacker stake</span>
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
          <div key={c.title} className={`card border-2 ${c.bad ? "border-clay/40" : "border-ocean"}`}>
            <p className="font-display text-xl tracking-tightest">{c.title}</p>
            <p className="mt-1 text-sm text-muted">{c.sub}</p>
            <dl className="mt-5 space-y-2.5 text-sm">
              <div className="flex justify-between border-b border-line pb-2">
                <dt className="text-ink-soft">Leg A — token1 out</dt>
                <dd className="tnum font-mono">{fmt(c.r.legA)}</dd>
              </div>
              <div className="flex justify-between border-b border-line pb-2">
                <dt className="text-ink-soft">Leg B — token0 back</dt>
                <dd className="tnum font-mono">{fmt(c.r.legB)}</dd>
              </div>
            </dl>
            <div className="mt-5">
              <p className="eyebrow mb-1">Attacker P&amp;L</p>
              <p className={`tnum font-display text-3xl tracking-tightest ${c.r.pnl > 0n ? "text-clay" : "text-ocean"}`}>
                {c.r.pnl > 0n ? "+" : "−"}{fmt(c.r.pnl > 0n ? c.r.pnl : -c.r.pnl)}
              </p>
              <p className="mt-1 text-sm text-muted">{c.r.pnl > 0n ? "Profitable attack" : "The attack loses money"}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="mt-6 rounded-lg border border-ocean bg-ocean/5 p-6">
        <p className="eyebrow mb-2">Attacker profit removed by Knot</p>
        <p className="tnum font-display text-4xl tracking-tightest text-ocean">{fmt(removed)}</p>
        <p className="mt-2 max-w-2xl text-sm text-ink-soft">
          That value did not disappear. It stayed in the pool, with the LPs who would otherwise have funded it.
        </p>
      </div>

      <p className="mt-8 font-mono text-xs text-faint">
        Reproduce: <code>forge test --match-contract EconomicViabilityTest -vv</code>
      </p>
    </div>
  );
}
