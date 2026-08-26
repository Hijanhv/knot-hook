import Link from "next/link";
import KnotMark from "@/components/KnotMark";
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
 * Dense, bordered, instrument-panel layout. Hairlines carry the structure rather than
 * whitespace; every section sits on a grid substrate; figures are mono and tabular. The
 * page should read as a readout, not a brochure.
 */
export default function Home() {
  return (
    <>
      <Ticker />

      {/* ── Hero: split frame, copy left, mechanism right ── */}
      <section className="gridfield border-b border-edge">
        <div className="wrap grid items-stretch lg:grid-cols-[1.05fr_1fr]">
          <div className="border-edge py-14 pr-0 lg:border-r lg:py-20 lg:pr-12">
            <div className="mb-6 flex flex-wrap items-center gap-2 font-mono text-[10px] uppercase tracking-[0.16em]">
              <span className="border border-edge bg-marine px-2 py-1 text-canvas">Uniswap v4 hook</span>
              <span className="border border-edge px-2 py-1 text-muted">{SITE.cohort}</span>
              <span className="border border-edge px-2 py-1 text-muted">{SITE.projectId}</span>
              <span className="flex items-center gap-1.5 border border-edge px-2 py-1 text-marine">
                <span className="inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-marine" />live
              </span>
            </div>

            <h1 className="font-display text-[clamp(2.5rem,6vw,4.75rem)] font-bold leading-[0.94] tracking-[-0.04em]">
              One pair.<br />Several pools.<br /><span className="text-marine">One price boundary.</span>
            </h1>

            <p className="mt-6 max-w-lg text-[15px] leading-[1.55] text-ink-soft">
              A shallow pool can quote better than the pair&rsquo;s combined liquidity supports.
              Knot checks both reserve states before every trade and leaves the difference with
              the LPs who would otherwise have funded it.
            </p>

            <div className="mt-8 flex flex-wrap gap-2">
              <Link href="/app" className="btn">Launch app →</Link>
              <Link href="/demo" className="btn-ghost">Attack demo</Link>
              <a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="btn-ghost">Docs ↗</a>
            </div>
          </div>

          <div className="flex items-center justify-center py-10 lg:py-0">
            <KnotMark className="w-full max-w-[400px] text-marine" />
          </div>
        </div>
      </section>

      {/* ── Readout strip: the numbers, immediately ── */}
      <section className="border-b border-edge bg-surface">
        <div className="wrap grid divide-y divide-edge sm:grid-cols-2 sm:divide-x sm:divide-y-0 lg:grid-cols-4">
          {[
            { v: 6674, u: "bps", l: "kept with LPs", t: "text-marine" },
            { v: 1949, u: "×", l: "retained vs fees forgone", t: "text-marine" },
            { v: 53, u: "", l: "passing tests", t: "text-ink" },
            { v: 96.32, u: "%", l: "line coverage", t: "text-ink", d: 2 },
          ].map((s) => (
            <div key={s.l} className="px-5 py-6">
              <p className={`font-display text-3xl font-bold tracking-[-0.03em] ${s.t}`}>
                <Counter to={s.v} decimals={s.d ?? 0} />
                <span className="ml-0.5 text-lg font-normal text-muted">{s.u}</span>
              </p>
              <p className="mt-1 font-mono text-[10px] uppercase tracking-[0.14em] text-faint">{s.l}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── The rule ── */}
      <section id="how" className="gridfield scroll-mt-20 border-b border-edge">
        <div className="wrap py-14">
          <Reveal>
            <p className="eyebrow mb-3">01 — The rule</p>
            <h2 className="max-w-3xl font-display text-[clamp(1.6rem,3.4vw,2.6rem)] font-bold leading-[1.1] tracking-[-0.03em]">
              Every swap is quoted twice. The taker gets the worse one.
            </h2>
          </Reveal>

          <Reveal delay={100}>
            <div className="mt-8 grid divide-y divide-edge border border-edge bg-surface sm:grid-cols-2 sm:divide-x sm:divide-y-0">
              <div className="p-5">
                <p className="eyebrow mb-2">exact input</p>
                <code className="tnum font-mono text-sm">output = <span className="text-marine">min</span>(local, aggregate)</code>
              </div>
              <div className="p-5">
                <p className="eyebrow mb-2">exact output</p>
                <code className="tnum font-mono text-sm">input = <span className="text-marine">max</span>(local, aggregate)</code>
              </div>
            </div>
          </Reveal>

          <Reveal delay={160}>
            <p className="mt-5 max-w-2xl text-[15px] leading-[1.55] text-ink-soft">
              Arithmetic, not a prediction. No model to be wrong, no oracle to read, no classifier
              deciding who looks like an attacker.
            </p>
          </Reveal>

          <Reveal delay={220}><div className="mt-10"><FlowDiagram /></div></Reveal>
        </div>
      </section>

      {/* ── The problem, as a dense table ── */}
      <section id="problem" className="scroll-mt-20 border-b border-edge bg-surface">
        <div className="wrap py-14">
          <Reveal><p className="eyebrow mb-6">02 — Why fragmentation leaks</p></Reveal>
          <div className="divide-y divide-line border-y border-line">
            {[
              ["One pool runs shallow", "Same tokens, far less depth. Cheaper to move, slower to correct."],
              ["It quotes beyond its means", "In isolation it offers a rate the pair's combined liquidity does not support."],
              ["The difference leaves", "An arbitrageur takes the generous quote. That value was funded by the pool's own LPs."],
            ].map(([h, p], i) => (
              <Reveal key={h} delay={i * 70}>
                <div className="grid gap-1 py-5 md:grid-cols-[1fr_1.6fr] md:gap-8">
                  <p className="font-display text-lg font-semibold tracking-[-0.02em]">{h}</p>
                  <p className="text-[15px] leading-[1.5] text-muted">{p}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── Live on-chain readout, inverted for weight ── */}
      <section className="border-b border-edge bg-ink text-canvas">
        <div className="wrap py-14">
          <Reveal>
            <p className="mb-6 font-mono text-[10px] uppercase tracking-[0.16em] text-canvas/50">
              03 — Verified on Unichain Sepolia
            </p>
          </Reveal>
          <div className="grid gap-px border border-canvas/15 bg-canvas/15 md:grid-cols-2">
            {[
              { t: "Shallow pool · bound binds", rows: [["local quote", "18.993189"], ["aggregate quote", "6.315922"], ["enforced", "6.315922"], ["withheld → LPs", "12.677266"]], hl: 3 },
              { t: "Deep pool · bound inert", rows: [["local quote", "4.960273"], ["aggregate quote", "6.315922"], ["enforced", "4.960273"], ["withheld → LPs", "0"]], hl: 2 },
            ].map((c) => (
              <div key={c.t} className="bg-ink p-6">
                <p className="mb-4 font-mono text-[10px] uppercase tracking-[0.14em] text-canvas/45">{c.t}</p>
                <dl className="space-y-2">
                  {c.rows.map(([k, v], i) => (
                    <div key={k} className={`flex justify-between gap-4 border-b border-canvas/10 pb-2 ${i === c.hl ? "text-marine-bright" : "text-canvas/75"}`}>
                      <dt className="font-mono text-[11px] uppercase tracking-[0.1em]">{k}</dt>
                      <dd className="tnum font-mono text-sm">{v}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            ))}
          </div>
          <Reveal delay={120}>
            <p className="mt-5 max-w-2xl text-[15px] leading-[1.5] text-canvas/60">
              Same size, both pools. The bound bites the skewed pool and leaves the balanced one alone.
              That contrast is the mechanism.
            </p>
          </Reveal>
        </div>
      </section>

      {/* ── Contracts + stack, side by side ── */}
      <section id="stack" className="gridfield scroll-mt-20 border-b border-edge">
        <div className="wrap grid gap-px bg-edge md:grid-cols-2">
          <div className="bg-canvas p-8">
            <p className="eyebrow mb-5">04 — Deployed contracts</p>
            <div className="space-y-3">
              {[["KnotFederation", FED], ["KnotHook · deep", DEEP], ["KnotHook · shallow", SHALLOW]].map(([l, a]) => (
                <a key={a} href={scan(a)} target="_blank" rel="noopener noreferrer"
                  className="group flex items-center justify-between gap-3 border-b border-line pb-2.5 transition-colors hover:border-marine">
                  <span className="text-sm text-ink-soft">{l}</span>
                  <span className="tnum font-mono text-xs text-muted transition-colors group-hover:text-marine">
                    {a.slice(0, 8)}…{a.slice(-6)} ↗
                  </span>
                </a>
              ))}
            </div>
          </div>
          <div className="bg-canvas p-8">
            <p className="eyebrow mb-5">05 — Stack</p>
            <div className="grid grid-cols-2 gap-x-6">
              {[["Protocol", "Uniswap v4"], ["Base", "BaseCustomCurve"], ["Accounting", "ERC-6909"],
                ["Solidity", "0.8.26"], ["Chain", "Unichain Sepolia"], ["Client", "wagmi · viem"],
                ["Docs", "Mintlify"], ["Oracle", "none"]].map(([k, v]) => (
                <div key={k} className="flex justify-between gap-2 border-b border-line py-2">
                  <span className="font-mono text-[10px] uppercase tracking-[0.1em] text-faint">{k}</span>
                  <span className="font-mono text-[11px]">{v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── Close ── */}
      <section className="border-b border-edge bg-surface">
        <div className="wrap flex flex-wrap items-center justify-between gap-6 py-12">
          <h2 className="font-display text-[clamp(1.5rem,3.2vw,2.4rem)] font-bold leading-[1.05] tracking-[-0.03em]">
            Connect a wallet and<br /><span className="text-marine">watch the bound bind.</span>
          </h2>
          <div className="flex flex-wrap gap-2">
            <Link href="/app" className="btn">Launch app →</Link>
            <a href={SITE.github} target="_blank" rel="noopener noreferrer" className="btn-ghost">Source ↗</a>
          </div>
        </div>
      </section>
    </>
  );
}
