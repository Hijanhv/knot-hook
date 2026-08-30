import Link from "next/link";
import KnotMark from "@/components/KnotMark";
import CandleChart from "@/components/CandleChart";
import Shoreline from "@/components/Shoreline";
import VaporGrid from "@/components/VaporGrid";
import VaporSun from "@/components/VaporSun";
import GlitchText from "@/components/GlitchText";
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
      <section className="sunset relative overflow-hidden border-b border-edge">
        {/* the horizon: banded sun, perspective grid running to it, market tape over the top */}
        <VaporSun size={340} className="animate-bob pointer-events-none absolute right-[6%] top-6 opacity-70 md:right-[12%]" />
        <VaporGrid className="absolute inset-x-0 bottom-0 h-64" />
        <CandleChart className="pointer-events-none absolute inset-x-0 bottom-0 h-[22rem] w-full opacity-[0.5] md:h-[26rem]" />
        <div className="wrap relative z-10 grid items-stretch lg:grid-cols-[1.05fr_1fr]">
          <div className="border-edge py-14 pr-0 lg:border-r lg:py-20 lg:pr-12">
            <div className="mb-6 flex flex-wrap items-center gap-2 font-mono text-[10px] uppercase tracking-[0.16em]">
              <span className="border border-edge bg-ocean px-2 py-1 text-sand-light">Uniswap v4 hook</span>
              <span className="border border-edge px-2 py-1 text-muted">{SITE.cohort}</span>
              <span className="border border-edge px-2 py-1 text-muted">{SITE.projectId}</span>
              <span className="flex items-center gap-1.5 border border-edge px-2 py-1 text-ocean">
                <span className="inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-ocean" />live
              </span>
            </div>

            <h1 className="font-display text-[clamp(3.25rem,8vw,6.5rem)] font-bold leading-[0.9] tracking-tightest">
              <GlitchText>One pair.</GlitchText><br />
              <GlitchText>Several pools.</GlitchText><br />
              <span className="chrome"><GlitchText>One price boundary.</GlitchText></span>
            </h1>

            <p className="mt-7 max-w-xl text-[17px] leading-[1.6] text-ink-soft">
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
            <KnotMark className="w-full max-w-[420px] animate-bob text-ocean" />
          </div>
        </div>
        <Shoreline className="relative z-10 -mb-1" />
      </section>

      {/* ── Readout strip: the numbers, immediately ── */}
      <section className="border-b border-edge bg-surface">
        <div className="wrap grid divide-y divide-edge sm:grid-cols-2 sm:divide-x sm:divide-y-0 lg:grid-cols-4">
          {[
            { v: 6674, u: "bps", l: "kept with LPs", t: "text-ocean" },
            { v: 1949, u: "×", l: "retained vs fees forgone", t: "text-ocean" },
            { v: 122, u: "", l: "passing tests", t: "text-ink" },
            { v: 96.32, u: "%", l: "line coverage", t: "text-ink", d: 2 },
          ].map((s) => (
            <div key={s.l} className="px-5 py-6">
              <p className={`font-display text-4xl font-bold tracking-tightest md:text-5xl ${s.t}`}>
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
            <p className="eyebrow mb-3 text-pink">01 — The rule</p>
            <h2 className="max-w-4xl font-display text-[clamp(2rem,4.6vw,3.6rem)] font-bold leading-[1.05] tracking-tightest">
              Every swap is quoted twice. The taker gets the worse one.
            </h2>
          </Reveal>

          <Reveal delay={100}>
            <div className="mt-8 grid divide-y divide-edge border border-edge bg-surface sm:grid-cols-2 sm:divide-x sm:divide-y-0">
              <div className="p-5">
                <p className="eyebrow mb-2">exact input</p>
                <code className="tnum font-mono text-sm">output = <span className="text-ocean">min</span>(local, aggregate)</code>
              </div>
              <div className="p-5">
                <p className="eyebrow mb-2">exact output</p>
                <code className="tnum font-mono text-sm">input = <span className="text-ocean">max</span>(local, aggregate)</code>
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
          <Reveal><p className="eyebrow mb-6 text-pink">02 — Why fragmentation leaks</p></Reveal>
          <div className="divide-y divide-line border-y border-line">
            {[
              ["One pool runs shallow", "Same tokens, far less depth. Cheaper to move, slower to correct."],
              ["It quotes beyond its means", "In isolation it offers a rate the pair's combined liquidity does not support."],
              ["The difference leaves", "An arbitrageur takes the generous quote. That value was funded by the pool's own LPs."],
            ].map(([h, p], i) => (
              <Reveal key={h} delay={i * 70}>
                <div className="grid gap-1 py-5 md:grid-cols-[1fr_1.6fr] md:gap-8">
                  <p className="font-display text-2xl font-bold tracking-tightest">{h}</p>
                  <p className="text-[15px] leading-[1.5] text-muted">{p}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── Live on-chain readout, inverted for weight ── */}
      <section className="relative overflow-hidden border-b border-edge bg-violet-deep text-sand-light">
        <VaporGrid className="absolute inset-x-0 bottom-0 h-40 opacity-60" />
        <div className="wrap relative z-10 py-14">
          <Reveal>
            <p className="mb-6 font-mono text-[10px] uppercase tracking-[0.16em] text-cyan">
              03 — Verified on Unichain Sepolia
            </p>
          </Reveal>
          <div className="grid gap-px border border-sand-light/20 bg-sand-light/20 md:grid-cols-2">
            {[
              { t: "Shallow pool · bound binds", rows: [["local quote", "18.993189"], ["aggregate quote", "6.315922"], ["enforced", "6.315922"], ["withheld → LPs", "12.677266"]], hl: 3 },
              { t: "Deep pool · bound inert", rows: [["local quote", "4.960273"], ["aggregate quote", "6.315922"], ["enforced", "4.960273"], ["withheld → LPs", "0"]], hl: 2 },
            ].map((c) => (
              <div key={c.t} className="bg-violet-deep/80 p-6 backdrop-blur-sm">
                <p className="mb-4 font-mono text-[10px] uppercase tracking-[0.14em] text-sand-light/50">{c.t}</p>
                <dl className="space-y-2">
                  {c.rows.map(([k, v], i) => (
                    <div key={k} className={`flex justify-between gap-4 border-b border-sand-light/15 pb-2 ${i === c.hl ? "text-ocean-surf" : "text-sand-light/80"}`}>
                      <dt className="font-mono text-[11px] uppercase tracking-[0.1em]">{k}</dt>
                      <dd className="tnum font-mono text-sm">{v}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            ))}
          </div>
          <Reveal delay={120}>
            <p className="mt-5 max-w-2xl text-[15px] leading-[1.5] text-sand-light/65">
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
            <div className="mb-5 flex items-baseline justify-between gap-3">
              <p className="eyebrow text-pink">04 — Deployed contracts</p>
              <Link href="/contracts" className="font-mono text-[11px] uppercase tracking-[0.12em] text-ocean hover:underline">all contracts →</Link>
            </div>
            <div className="space-y-3">
              {[["KnotFederation", FED], ["KnotHook · deep", DEEP], ["KnotHook · shallow", SHALLOW]].map(([l, a]) => (
                <a key={a} href={scan(a)} target="_blank" rel="noopener noreferrer"
                  className="group flex items-center justify-between gap-3 border-b border-line pb-2.5 transition-colors hover:border-ocean">
                  <span className="text-sm text-ink-soft">{l}</span>
                  <span className="tnum font-mono text-xs text-muted transition-colors group-hover:text-ocean">
                    {a.slice(0, 8)}…{a.slice(-6)} ↗
                  </span>
                </a>
              ))}
            </div>
          </div>
          <div className="bg-canvas p-8">
            <p className="eyebrow mb-5 text-pink">05 — Stack</p>
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
          <h2 className="font-display text-[clamp(1.9rem,4.2vw,3.2rem)] font-bold leading-[1.02] tracking-tightest">
            Connect a wallet and<br /><span className="text-ocean">watch the bound bind.</span>
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
