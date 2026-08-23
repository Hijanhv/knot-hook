import Link from "next/link";
import KnotMark from "@/components/KnotMark";
import Reveal from "@/components/Reveal";
import Counter from "@/components/Counter";
import ScrollCue from "@/components/ScrollCue";
import FlowDiagram from "@/components/FlowDiagram";
import { SITE } from "@/lib/site";

/**
 * Structure follows goodgrowth: an animation-led opening where the motion is the content,
 * then a large typographic statement, then a single-column narrative with generous pacing.
 * Sans throughout, set large and tight. Marine on warm paper, as before.
 */
export default function Home() {
  return (
    <>
      {/* ── 1. Opening. The mechanism animating, almost no words. ── */}
      <section className="flex min-h-[78vh] flex-col items-center justify-center px-6">
        <KnotMark className="w-full max-w-[520px] text-marine" />
        <div className="mt-14 flex flex-col items-center gap-6">
          <p className="max-w-md text-center text-sm leading-relaxed text-muted">
            A Uniswap v4 hook. Live on Unichain Sepolia.
          </p>
          <ScrollCue />
        </div>
      </section>

      {/* ── 2. The statement. Type scaled hard against the viewport. ── */}
      <section className="px-6 py-[14vh]">
        <div className="mx-auto max-w-5xl">
          <Reveal>
            <h1 className="text-[clamp(2.75rem,8.5vw,7rem)] font-semibold leading-[0.95] tracking-[-0.045em]">
              One pair.
              <br />
              Several pools.
              <br />
              <span className="text-marine">One price boundary.</span>
            </h1>
          </Reveal>
          <Reveal delay={160}>
            <p className="mt-14 max-w-2xl text-xl leading-[1.65] text-ink-soft md:text-2xl">
              A shallow pool can hand an arbitrageur a better quote than the pair&rsquo;s combined
              liquidity actually supports. Knot makes participating pools check both reserve states
              before a trade, and leaves the difference with the LPs who would otherwise have funded it.
            </p>
          </Reveal>
          <Reveal delay={280}>
            <div className="mt-14 flex flex-wrap items-center gap-4">
              <Link href="/app" className="btn">Launch app</Link>
              <a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="btn-ghost">Docs ↗</a>
              <span className="font-mono text-[11px] uppercase tracking-[0.16em] text-faint">
                {SITE.cohort} · {SITE.projectId}
              </span>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ── 3. The problem, as narrative. Single column, one idea per beat. ── */}
      <section id="problem" className="scroll-mt-24 px-6 py-[12vh]">
        <div className="mx-auto max-w-3xl">
          <Reveal><p className="eyebrow mb-14">The problem</p></Reveal>
          {[
            ["One pool runs shallow.", "Same tokens, far less depth. Its price is cheaper to move and slower to correct."],
            ["It quotes beyond its means.", "In isolation it offers a rate the pair's combined liquidity does not actually support."],
            ["The difference leaves.", "An arbitrageur takes the generous quote. That value was funded by the pool's own LPs."],
          ].map(([h, p], i) => (
            <Reveal key={h} delay={i * 90}>
              <div className="border-t border-line py-12">
                <h2 className="text-3xl font-semibold leading-tight tracking-[-0.035em] md:text-[2.75rem]">{h}</h2>
                <p className="mt-5 max-w-xl text-lg leading-relaxed text-muted">{p}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      {/* ── 4. The rule. The one thing to remember. ── */}
      <section id="how" className="scroll-mt-24 bg-surface2/50 px-6 py-[14vh]">
        <div className="mx-auto max-w-4xl">
          <Reveal>
            <p className="eyebrow mb-10">How it works</p>
            <h2 className="text-[clamp(2rem,5.5vw,3.75rem)] font-semibold leading-[1.05] tracking-[-0.04em]">
              Every swap is quoted twice.
              <br />
              <span className="text-marine">The taker gets the worse one.</span>
            </h2>
          </Reveal>
          <Reveal delay={140}>
            <div className="mt-14 grid gap-4 sm:grid-cols-2">
              <div className="rounded-lg border border-line bg-surface p-7 transition-all duration-300 hover:-translate-y-1 hover:border-marine">
                <p className="eyebrow mb-4">Exact input</p>
                <code className="tnum font-mono text-base">output = <span className="text-marine">min</span>(local, aggregate)</code>
              </div>
              <div className="rounded-lg border border-line bg-surface p-7 transition-all duration-300 hover:-translate-y-1 hover:border-marine">
                <p className="eyebrow mb-4">Exact output</p>
                <code className="tnum font-mono text-base">input = <span className="text-marine">max</span>(local, aggregate)</code>
              </div>
            </div>
          </Reveal>
          <Reveal delay={220}>
            <p className="mt-10 max-w-2xl text-lg leading-relaxed text-ink-soft">
              Arithmetic, not a prediction. No model to be wrong, no oracle to read, no classifier
              deciding who looks like an attacker.
            </p>
          </Reveal>
          <Reveal delay={300}><div className="mt-14"><FlowDiagram /></div></Reveal>
        </div>
      </section>

      {/* ── 5. Results, as a compact list rather than a card grid. ── */}
      <section className="px-6 py-[14vh]">
        <div className="mx-auto max-w-3xl">
          <Reveal>
            <p className="eyebrow mb-4">Measured on-chain</p>
            <h2 className="mb-16 text-[clamp(1.75rem,4.5vw,3rem)] font-semibold leading-tight tracking-[-0.035em]">
              Every number reproduces a test.
            </h2>
          </Reveal>
          {[
            { n: 6674, u: "bps", l: "Value kept with LPs", d: "Withheld from a taker exploiting the skewed pool.", t: "text-marine" },
            { n: 1949, u: "×", l: "Retained vs fees forgone", d: "At 8× skew. Still 262× at 2×.", t: "text-marine" },
            { n: 0, u: "bps", l: "Effect on a balanced pool", d: "The bound is inert where nothing is wrong.", t: "text-ink" },
            { n: 0, u: "", l: "Gain from splitting 8 ways", d: "Sliced output is marginally worse. Path independence holds.", t: "text-ink" },
          ].map((r, i) => (
            <Reveal key={r.l} delay={i * 80}>
              <div className="group flex items-baseline justify-between gap-8 border-t border-line py-8">
                <div>
                  <p className="text-lg font-medium">{r.l}</p>
                  <p className="mt-1.5 text-base text-muted">{r.d}</p>
                </div>
                <p className={`shrink-0 text-4xl font-semibold tracking-[-0.04em] md:text-5xl ${r.t}`}>
                  <Counter to={r.n} />
                  <span className="ml-1 text-lg font-normal text-muted">{r.u}</span>
                </p>
              </div>
            </Reveal>
          ))}
          <Reveal delay={340}>
            <code className="mt-10 inline-block rounded-md border border-line bg-surface px-3 py-2 font-mono text-xs text-muted">
              forge test --match-contract MEVProtectionTest -vv
            </code>
          </Reveal>
        </div>
      </section>

      {/* ── 6. Stack, as a compact spec list. ── */}
      <section id="stack" className="scroll-mt-24 px-6 py-[12vh]">
        <div className="mx-auto max-w-3xl">
          <Reveal><p className="eyebrow mb-12">Stack</p></Reveal>
          <div className="grid gap-x-16 gap-y-0 sm:grid-cols-2">
            {[
              ["Protocol", "Uniswap v4"], ["Hook base", "BaseCustomCurve"],
              ["Accounting", "ERC-6909 claims"], ["Language", "Solidity 0.8.26"],
              ["Network", "Unichain Sepolia"], ["Interface", "Next.js · wagmi"],
              ["Docs", "Mintlify"], ["Oracle", "none, by design"],
            ].map(([k, v], i) => (
              <Reveal key={k} delay={i * 45}>
                <div className="flex items-baseline justify-between border-t border-line py-4">
                  <span className="text-muted">{k}</span>
                  <span className="font-mono text-sm">{v}</span>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── 7. Close. ── */}
      <section className="px-6 pb-[16vh] pt-[8vh]">
        <div className="mx-auto max-w-3xl">
          <Reveal>
            <h2 className="text-[clamp(2rem,6vw,4rem)] font-semibold leading-[1.02] tracking-[-0.045em]">
              Connect a wallet and
              <br />
              <span className="text-marine">watch the bound bind.</span>
            </h2>
            <div className="mt-12 flex flex-wrap gap-4">
              <Link href="/app" className="btn">Launch app</Link>
              <Link href="/demo" className="btn-ghost">The attack demo</Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
