import Link from "next/link";
import KnotMark from "@/components/KnotMark";
import CandleChart from "@/components/CandleChart";
import Reveal from "@/components/Reveal";
import Counter from "@/components/Counter";
import Ticker from "@/components/Ticker";
import FlowDiagram from "@/components/FlowDiagram";
import { SITE } from "@/lib/site";

const FED = "0x91A0489A1BEA8030AC82351D52BDC3F97d6cA129";
const DEEP = "0x346930bcf767614a6C4654904739cBCF4A8f6A88";
const SHALLOW = "0x6B8D77a921Adc5244bC0398fa6133841F3DFaA88";
const scan = (a: string) => `https://sepolia.uniscan.xyz/address/${a}`;

/**
 * White paper, a ruled grid, black ink. A split hero divided by a single vertical rule, a
 * band of open grid squares beneath it, then a full-bleed black field with white panels
 * floating on it.
 */
export default function Home() {
  return (
    <>
      {/* ── Hero: headline left, deck right, one rule between them ───────────────── */}
      <section className="relative border-b border-grid">
        <div className="wrap grid items-stretch gap-0 py-16 md:py-20 lg:grid-cols-[1.15fr_0.85fr]">
          <div className="lg:pr-14">
            <h1 className="font-display text-[clamp(2.75rem,6.6vw,5.25rem)] font-semibold leading-[0.98] tracking-tightest text-ink">
              One pair. Several pools.<br />One price boundary.
            </h1>
          </div>

          <div className="mt-8 border-grid pt-8 lg:mt-0 lg:border-l lg:border-t-0 lg:pl-14 lg:pt-2">
            <p className="text-[17px] leading-[1.6] text-ink">
              A shallow pool can quote better than the pair&rsquo;s combined liquidity supports.
              Knot checks both reserve states before every trade and leaves the difference with
              the LPs who would otherwise have funded it.
            </p>
            <div className="mt-7 flex flex-wrap items-center gap-2">
              <span className="pill">{SITE.cohort}</span>
              <span className="pill">{SITE.projectId}</span>
              <span className="pill">
                <span className="inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-blue" />
                live on unichain sepolia
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* the reference separates major blocks with a band of open grid squares, not a rule */}
      <div className="grid-band" aria-hidden />

      {/* ── Full-bleed black: the mechanism, on a white panel floating on the field ── */}
      <section className="inkfield relative">
        <div className="wrap py-20 md:py-24">
          <p className="text-center font-mono text-[11px] uppercase tracking-[0.18em] text-white/70">
            What does the hook actually do?
          </p>

          <h2 className="mx-auto mt-6 max-w-3xl text-center font-display text-[clamp(1.9rem,4vw,3.1rem)] font-semibold leading-[1.08] tracking-tightest text-white">
            Every swap is quoted twice. The taker gets the worse one.
          </h2>

          <div className="mt-9 flex flex-wrap justify-center gap-3">
            <span className="pill-select pill-select-on">
              <span className="h-2 w-2 rounded-full bg-ink" />exact input · min
            </span>
            <span className="pill-select border-white/35 text-white/85">
              <span className="h-2 w-2 rounded-full bg-white/70" />exact output · max
            </span>
          </div>

          {/* the floating white panel, the reference's central device */}
          <div className="mt-12 overflow-hidden rounded-lg bg-canvas shadow-lift">
            <div className="grid divide-y divide-line md:grid-cols-2 md:divide-x md:divide-y-0">
              {[
                { t: "Shallow pool", s: "bound binds", bind: true,
                  rows: [["local quote", "18.993189"], ["aggregate quote", "6.315922"], ["enforced", "6.315922"], ["withheld → LPs", "12.677266"]] },
                { t: "Deep pool", s: "bound inert", bind: false,
                  rows: [["local quote", "4.960273"], ["aggregate quote", "6.315922"], ["enforced", "4.960273"], ["withheld → LPs", "0"]] },
              ].map((c) => (
                <div key={c.t} className="p-8">
                  <div className="mb-7 flex items-baseline justify-between gap-3">
                    <p className="font-display text-xl font-semibold tracking-tightest text-ink">{c.t}</p>
                    <span className={`rounded-full px-2.5 py-1 font-mono text-[10px] uppercase tracking-[0.12em] ${
                      c.bind ? "bg-ink text-white" : "bg-surface2 text-faint"}`}>
                      {c.s}
                    </span>
                  </div>
                  <dl className="space-y-4">
                    {c.rows.map(([k, v], i) => {
                      const on = i === (c.bind ? 3 : 2);
                      return (
                        <div key={k} className="flex items-baseline justify-between gap-4">
                          <dt className="font-mono text-[10px] uppercase tracking-[0.12em] text-faint">{k}</dt>
                          <dd className={`tnum font-display text-[1.6rem] leading-none ${on ? "font-medium text-ink" : "font-light text-muted"}`}>{v}</dd>
                        </div>
                      );
                    })}
                  </dl>
                </div>
              ))}
            </div>

            <div className="border-t border-line bg-paper px-8 py-5">
              <p className="text-[14px] leading-[1.5] text-muted">
                Same trade size, both pools, verified on-chain. The bound bites the skewed pool
                and leaves the balanced one untouched. That contrast is the mechanism.
              </p>
            </div>
          </div>

          <div className="mt-10 flex justify-center">
            <Link href="/app" className="rounded-[3px] bg-canvas px-16 py-4 text-[15px] font-medium text-ink transition-colors hover:bg-paper">
              Launch app
            </Link>
          </div>
        </div>
      </section>

      <Ticker />

      {/* ── The numbers ───────────────────────────────────────────────────────────── */}
      <section className="border-b border-grid">
        <div className="wrap grid divide-y divide-grid py-14 sm:grid-cols-2 sm:divide-x sm:divide-y-0 lg:grid-cols-4">
          {[
            { v: 6674, u: "bps", l: "kept with LPs", hl: true },
            { v: 1949, u: "×", l: "retained vs fees forgone", hl: true },
            { v: 122, u: "", l: "passing tests" },
            { v: 96.21, u: "%", l: "line coverage", d: 2 },
          ].map((s, i) => (
            <div key={s.l} className={`py-5 ${i === 0 ? "sm:pr-8" : "sm:px-8"} ${i === 3 ? "sm:pr-0" : ""}`}>
              <p className="eyebrow mb-3">{s.l}</p>
              <p className={`figure ${s.hl ? "font-normal text-ink" : "text-muted"}`}>
                <Counter to={s.v} decimals={s.d ?? 0} />
                <span className="ml-1 text-lg text-faint">{s.u}</span>
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* ── How it works ──────────────────────────────────────────────────────────── */}
      <section id="how" className="section scroll-mt-20 border-b border-grid">
        <div className="wrap">
          <div className="grid gap-10 lg:grid-cols-[1fr_1fr]">
            <Reveal>
              <p className="eyebrow mb-5">How it works</p>
              <h2 className="font-display text-[clamp(1.9rem,4vw,3.1rem)] font-semibold leading-[1.06] tracking-tightest text-ink">
                Arithmetic, not a prediction.
              </h2>
              <p className="mt-6 max-w-lg text-[16px] leading-[1.65] text-muted">
                No model to be wrong, no oracle to read, no classifier deciding who looks like an
                attacker. Both reserve states are read before the trade settles, and the taker is
                held to whichever is less favourable.
              </p>
              <div className="mt-8 space-y-3">
                {[["exact input", "output =", "min", "(local, aggregate)"],
                  ["exact output", "input =", "max", "(local, aggregate)"]].map(([label, lhs, op, rhs]) => (
                  <div key={label} className="flex flex-wrap items-baseline gap-x-4 gap-y-1 border-b border-grid pb-3">
                    <span className="eyebrow w-28 shrink-0">{label}</span>
                    <code className="tnum font-mono text-[15px] text-ink">
                      {lhs} <span className="font-semibold text-blue">{op}</span>{rhs}
                    </code>
                  </div>
                ))}
              </div>
            </Reveal>

            <Reveal delay={100}>
              <div className="flex h-full items-center justify-center">
                <KnotMark className="w-full max-w-[420px] animate-bob text-blue" />
              </div>
            </Reveal>
          </div>

          <Reveal delay={160}><div className="mt-14"><FlowDiagram /></div></Reveal>
        </div>
      </section>

      {/* ── The problem ───────────────────────────────────────────────────────────── */}
      <section id="problem" className="section scroll-mt-20 border-b border-grid">
        <div className="wrap">
          <Reveal>
            <p className="eyebrow mb-5">The problem</p>
            <h2 className="max-w-3xl font-display text-[clamp(1.9rem,4vw,3.1rem)] font-semibold leading-[1.06] tracking-tightest text-ink">
              Why fragmented liquidity leaks value
            </h2>
          </Reveal>

          <div className="mt-12 grid divide-y divide-grid border-y border-grid md:grid-cols-3 md:divide-x md:divide-y-0">
            {[
              ["One pool runs shallow", "Same tokens, far less depth. Cheaper to move, and slower to correct once moved."],
              ["It quotes beyond its means", "In isolation it offers a rate the pair's combined liquidity does not actually support."],
              ["The difference leaves", "An arbitrageur takes the generous quote. That value was funded by the pool's own LPs."],
            ].map(([h, p], i) => (
              <Reveal key={h} delay={i * 80}>
                <div className={`h-full py-8 ${i === 0 ? "md:pr-8" : "md:px-8"} ${i === 2 ? "md:pr-0" : ""}`}>
                  {/* numbered because this is a sequence: each step is caused by the one above */}
                  <span className="tnum font-mono text-xs text-blue">0{i + 1}</span>
                  <p className="mt-4 font-display text-xl font-semibold leading-snug tracking-tightest text-ink">{h}</p>
                  <p className="mt-3 text-[15px] leading-[1.6] text-muted">{p}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── Contracts + stack ─────────────────────────────────────────────────────── */}
      <section id="stack" className="section scroll-mt-20 border-b border-grid">
        <div className="wrap grid gap-12 md:grid-cols-2">
          <div>
            <div className="mb-6 flex items-baseline justify-between gap-3">
              <p className="eyebrow">Deployed contracts</p>
              <Link href="/contracts" className="font-mono text-[11px] uppercase tracking-[0.12em] text-blue hover:text-blue-dark">
                view all →
              </Link>
            </div>
            <div className="border-t border-grid">
              {[["KnotFederation", FED], ["KnotHook · deep", DEEP], ["KnotHook · shallow", SHALLOW]].map(([l, a]) => (
                <a key={a} href={scan(a)} target="_blank" rel="noopener noreferrer"
                  className="group flex items-center justify-between gap-3 border-b border-grid py-4 transition-colors hover:bg-paper">
                  <span className="text-[15px] text-ink">{l}</span>
                  <span className="tnum font-mono text-xs text-faint transition-colors group-hover:text-blue">
                    {a.slice(0, 8)}…{a.slice(-6)} ↗
                  </span>
                </a>
              ))}
            </div>
          </div>

          <div>
            <p className="eyebrow mb-6">Stack</p>
            <div className="grid grid-cols-2 gap-x-10 border-t border-grid">
              {[["Protocol", "Uniswap v4"], ["Base", "BaseCustomCurve"], ["Accounting", "ERC-6909"],
                ["Solidity", "0.8.26"], ["Chain", "Unichain Sepolia"], ["Client", "wagmi · viem"],
                ["Docs", "Mintlify"], ["Oracle", "none"]].map(([k, v]) => (
                <div key={k} className="flex justify-between gap-2 border-b border-grid py-3">
                  <span className="font-mono text-[10px] uppercase tracking-[0.1em] text-faint">{k}</span>
                  <span className="font-mono text-[11px] text-ink">{v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── Close ─────────────────────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden">
        <CandleChart className="pointer-events-none absolute inset-x-0 bottom-0 h-[18rem] w-full opacity-[0.22]" />
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-[18rem] bg-gradient-to-t from-canvas via-canvas/60 to-transparent" />
        <div className="wrap relative z-10 flex flex-wrap items-center justify-between gap-8 py-20 md:py-24">
          <h2 className="max-w-xl font-display text-[clamp(1.75rem,3.6vw,2.9rem)] font-semibold leading-[1.06] tracking-tightest text-ink">
            Connect a wallet and<br /><span className="text-blue">watch the bound bind.</span>
          </h2>
          <div className="flex flex-wrap gap-3">
            <Link href="/app" className="btn">Launch app</Link>
            <a href={SITE.github} target="_blank" rel="noopener noreferrer" className="btn-ghost">Source ↗</a>
          </div>
        </div>
      </section>
    </>
  );
}
