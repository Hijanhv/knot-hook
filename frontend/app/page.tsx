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
 * Deep navy, white type, one blue. Structure comes from space and soft-depth cards rather than
 * from hard rules — the mechanism is a single hard boundary, so the page earns its authority by
 * being quiet around it rather than by shouting.
 */
export default function Home() {
  return (
    <>
      <Ticker />

      {/* ── Hero ─────────────────────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden">
        <CandleChart className="pointer-events-none absolute inset-x-0 bottom-0 h-[24rem] w-full opacity-[0.30]" />
        {/* fades the tape into the ground so it reads as atmosphere, not as a chart to inspect */}
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-[24rem] bg-gradient-to-t from-canvas via-canvas/70 to-transparent" />

        <div className="wrap relative z-10 grid items-center gap-16 py-24 md:py-32 lg:grid-cols-[1.1fr_0.9fr]">
          <div>
            <div className="mb-8 flex flex-wrap items-center gap-2">
              <span className="rounded-full bg-accent/15 px-3 py-1 font-mono text-[10px] uppercase tracking-[0.14em] text-accent-light">
                Uniswap v4 hook
              </span>
              <span className="pill">{SITE.cohort}</span>
              <span className="pill">{SITE.projectId}</span>
            </div>

            <h1 className="font-display text-[clamp(2.75rem,6vw,4.75rem)] font-semibold leading-[1.02] tracking-tightest text-ink">
              One pair. Several pools.<br />
              <span className="text-accent">One price boundary.</span>
            </h1>

            <p className="mt-8 max-w-xl text-[17px] leading-[1.65] text-ink-soft">
              A shallow pool can quote better than the pair&rsquo;s combined liquidity supports.
              Knot checks both reserve states before every trade and leaves the difference with
              the LPs who would otherwise have funded it.
            </p>

            <div className="mt-10 flex flex-wrap gap-3">
              <Link href="/app" className="btn">Launch app</Link>
              <Link href="/demo" className="btn-ghost">Attack demo</Link>
              <a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="btn-ghost">Docs ↗</a>
            </div>
          </div>

          <div className="flex items-center justify-center">
            <KnotMark className="w-full max-w-[380px] animate-bob text-accent" />
          </div>
        </div>
      </section>

      {/* ── The numbers, immediately ──────────────────────────────────────────────── */}
      <section className="wrap relative z-10">
        <div className="grid gap-4 rounded-2xl border border-line bg-surface p-8 shadow-card sm:grid-cols-2 lg:grid-cols-4 lg:gap-8">
          {[
            { v: 6674, u: "bps", l: "kept with LPs", hl: true },
            { v: 1949, u: "×", l: "retained vs fees forgone", hl: true },
            { v: 122, u: "", l: "passing tests" },
            { v: 96.32, u: "%", l: "line coverage", d: 2 },
          ].map((s) => (
            <div key={s.l}>
              <p className={`font-display text-4xl font-semibold tracking-tightest md:text-[2.75rem] ${s.hl ? "text-accent" : "text-ink"}`}>
                <Counter to={s.v} decimals={s.d ?? 0} />
                <span className="ml-1 text-xl font-normal text-faint">{s.u}</span>
              </p>
              <p className="mt-2 text-sm text-muted">{s.l}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── The rule ──────────────────────────────────────────────────────────────── */}
      <section id="how" className="section scroll-mt-20">
        <div className="wrap">
          <Reveal>
            <p className="eyebrow mb-4">How it works</p>
            <h2 className="max-w-3xl font-display text-[clamp(1.9rem,3.8vw,3rem)] font-semibold leading-[1.1] tracking-tightest text-ink">
              Every swap is quoted twice. The taker gets the worse one.
            </h2>
            <p className="mt-5 max-w-2xl text-[16px] leading-[1.65] text-muted">
              Arithmetic, not a prediction. No model to be wrong, no oracle to read, no classifier
              deciding who looks like an attacker.
            </p>
          </Reveal>

          <Reveal delay={100}>
            <div className="mt-10 grid gap-4 sm:grid-cols-2">
              {[["exact input", "output =", "min", "(local, aggregate)"],
                ["exact output", "input =", "max", "(local, aggregate)"]].map(([label, lhs, op, rhs]) => (
                <div key={label} className="card">
                  <p className="eyebrow mb-3">{label}</p>
                  <code className="tnum font-mono text-[15px] text-ink-soft">
                    {lhs} <span className="font-semibold text-accent">{op}</span>{rhs}
                  </code>
                </div>
              ))}
            </div>
          </Reveal>

          <Reveal delay={160}><div className="mt-6"><FlowDiagram /></div></Reveal>
        </div>
      </section>

      {/* ── The problem ───────────────────────────────────────────────────────────── */}
      <section id="problem" className="section scroll-mt-20 border-y border-line bg-surface/40">
        <div className="wrap">
          <Reveal>
            <p className="eyebrow mb-4">The problem</p>
            <h2 className="max-w-3xl font-display text-[clamp(1.9rem,3.8vw,3rem)] font-semibold leading-[1.1] tracking-tightest text-ink">
              Why fragmented liquidity leaks value
            </h2>
          </Reveal>

          <div className="mt-12 grid gap-6 md:grid-cols-3">
            {[
              ["One pool runs shallow", "Same tokens, far less depth. Cheaper to move, and slower to correct once moved."],
              ["It quotes beyond its means", "In isolation it offers a rate the pair's combined liquidity does not actually support."],
              ["The difference leaves", "An arbitrageur takes the generous quote. That value was funded by the pool's own LPs."],
            ].map(([h, p], i) => (
              <Reveal key={h} delay={i * 80}>
                <div className="card card-hover h-full">
                  {/* numbered because this is a sequence — each step is caused by the one above it */}
                  <span className="tnum font-mono text-xs text-accent">0{i + 1}</span>
                  <p className="mt-3 font-display text-xl font-semibold leading-snug tracking-tightest text-ink">{h}</p>
                  <p className="mt-3 text-[15px] leading-[1.6] text-muted">{p}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── Live on-chain readout ─────────────────────────────────────────────────── */}
      <section className="section">
        <div className="wrap">
          <Reveal>
            <p className="eyebrow mb-4">Verified on-chain</p>
            <h2 className="max-w-3xl font-display text-[clamp(1.9rem,3.8vw,3rem)] font-semibold leading-[1.1] tracking-tightest text-ink">
              The same trade, in two pools, on Unichain Sepolia
            </h2>
          </Reveal>

          <div className="mt-12 grid gap-6 md:grid-cols-2">
            {[
              { t: "Shallow pool", s: "bound binds", bind: true,
                rows: [["local quote", "18.993189"], ["aggregate quote", "6.315922"], ["enforced", "6.315922"], ["withheld → LPs", "12.677266"]] },
              { t: "Deep pool", s: "bound inert", bind: false,
                rows: [["local quote", "4.960273"], ["aggregate quote", "6.315922"], ["enforced", "4.960273"], ["withheld → LPs", "0"]] },
            ].map((c) => (
              <div key={c.t} className={`card ${c.bind ? "border-accent/40 shadow-lift" : ""}`}>
                <div className="mb-6 flex items-baseline justify-between gap-3">
                  <p className="font-display text-lg font-semibold tracking-tightest text-ink">{c.t}</p>
                  <span className={`rounded-full px-2.5 py-1 font-mono text-[10px] uppercase tracking-[0.12em] ${
                    c.bind ? "bg-accent/15 text-accent-light" : "bg-surface2 text-faint"}`}>
                    {c.s}
                  </span>
                </div>
                <dl className="space-y-3">
                  {c.rows.map(([k, v], i) => {
                    const on = i === (c.bind ? 3 : 2);
                    return (
                      <div key={k} className="flex items-baseline justify-between gap-4 border-b border-line pb-3 last:border-0">
                        <dt className="font-mono text-[11px] uppercase tracking-[0.1em] text-faint">{k}</dt>
                        <dd className={`tnum font-mono text-sm ${on ? "font-semibold text-accent" : "text-ink-soft"}`}>{v}</dd>
                      </div>
                    );
                  })}
                </dl>
              </div>
            ))}
          </div>

          <Reveal delay={120}>
            <p className="mt-8 max-w-2xl text-[15px] leading-[1.6] text-muted">
              Same size, both pools. The bound bites the skewed pool and leaves the balanced one
              untouched. That contrast is the mechanism.
            </p>
          </Reveal>
        </div>
      </section>

      {/* ── Contracts + stack ─────────────────────────────────────────────────────── */}
      <section id="stack" className="section scroll-mt-20 border-y border-line bg-surface/40">
        <div className="wrap grid gap-6 md:grid-cols-2">
          <div className="card">
            <div className="mb-6 flex items-baseline justify-between gap-3">
              <p className="eyebrow">Deployed contracts</p>
              <Link href="/contracts" className="font-mono text-[11px] uppercase tracking-[0.12em] text-accent hover:text-accent-light">
                view all →
              </Link>
            </div>
            <div className="space-y-1">
              {[["KnotFederation", FED], ["KnotHook · deep", DEEP], ["KnotHook · shallow", SHALLOW]].map(([l, a]) => (
                <a key={a} href={scan(a)} target="_blank" rel="noopener noreferrer"
                  className="group flex items-center justify-between gap-3 rounded-lg px-3 py-3 transition-colors hover:bg-surface2">
                  <span className="text-sm text-ink-soft">{l}</span>
                  <span className="tnum font-mono text-xs text-faint transition-colors group-hover:text-accent">
                    {a.slice(0, 8)}…{a.slice(-6)} ↗
                  </span>
                </a>
              ))}
            </div>
          </div>

          <div className="card">
            <p className="eyebrow mb-6">Stack</p>
            <div className="grid grid-cols-2 gap-x-8">
              {[["Protocol", "Uniswap v4"], ["Base", "BaseCustomCurve"], ["Accounting", "ERC-6909"],
                ["Solidity", "0.8.26"], ["Chain", "Unichain Sepolia"], ["Client", "wagmi · viem"],
                ["Docs", "Mintlify"], ["Oracle", "none"]].map(([k, v]) => (
                <div key={k} className="flex justify-between gap-2 border-b border-line py-2.5">
                  <span className="font-mono text-[10px] uppercase tracking-[0.1em] text-faint">{k}</span>
                  <span className="font-mono text-[11px] text-ink-soft">{v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── Close ─────────────────────────────────────────────────────────────────── */}
      <section className="section">
        <div className="wrap flex flex-wrap items-center justify-between gap-8">
          <h2 className="max-w-xl font-display text-[clamp(1.75rem,3.4vw,2.75rem)] font-semibold leading-[1.1] tracking-tightest text-ink">
            Connect a wallet and watch the bound bind.
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
