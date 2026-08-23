import Link from "next/link";
import KnotMark from "@/components/KnotMark";
import Stat from "@/components/Stat";
import Reveal from "@/components/Reveal";
import FlowDiagram from "@/components/FlowDiagram";
import { SITE } from "@/lib/site";

export default function Home() {
  return (
    <>
      {/* ── Hero ─────────────────────────────────────────────── */}
      <section className="wrap pt-20 pb-16 md:pt-28">
        <div className="grid items-center gap-12 md:grid-cols-[1.15fr_1fr]">
          <div className="animate-rise [animation-delay:80ms]">
            <div className="mb-5 flex flex-wrap items-center gap-2">
              <span className="rounded-full border border-marine/30 bg-marine/5 px-3 py-1 font-mono text-[11px] uppercase tracking-[0.14em] text-marine">
                Uniswap v4 hook
              </span>
              <span className="rounded-full border border-line bg-surface px-3 py-1 font-mono text-[11px] uppercase tracking-[0.14em] text-muted">
                {SITE.cohort} · {SITE.projectId}
              </span>
            </div>
            <h1 className="font-display text-4xl leading-[1.08] tracking-tightest md:text-6xl">
              One pair.<br />Several pools.<br />
              <span className="text-marine">One price boundary.</span>
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-relaxed text-ink-soft">
              A shallow pool can hand an arbitrageur a better quote than the pair&rsquo;s combined liquidity
              actually supports. Knot makes participating pools check both reserve states before a trade,
              and leaves the difference with the LPs who would otherwise have funded it.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/app" className="btn">Launch app</Link>
              <a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="btn-ghost">Read the docs ↗</a>
            </div>
          </div>
          <KnotMark className="w-full text-marine" />
        </div>
      </section>

      {/* ── The problem ──────────────────────────────────────── */}
      <section id="problem" className="rule scroll-mt-20">
        <div className="wrap py-20">
          <Reveal>
            <p className="eyebrow mb-3">The problem</p>
            <h2 className="max-w-2xl font-display text-3xl leading-tight tracking-tightest md:text-4xl">
              Liquidity for one pair is split across pools that know nothing about each other.
            </h2>
          </Reveal>
          <div className="mt-12 grid gap-8 md:grid-cols-3">
            {[
              { n: "01", h: "One pool runs shallow", p: "Same tokens, far less depth. Its price is cheaper to move and slower to correct." },
              { n: "02", h: "It quotes beyond its means", p: "In isolation it offers a rate the pair's combined liquidity does not actually support." },
              { n: "03", h: "The difference leaves", p: "An arbitrageur takes the generous quote. That value was funded by the pool's LPs." },
            ].map((c, i) => (
              <Reveal key={c.n} delay={i * 110}>
                <div className="group border-l-2 border-line pl-5 transition-colors duration-300 hover:border-marine">
                  <span className="font-mono text-xs text-faint transition-colors group-hover:text-marine">{c.n}</span>
                  <h3 className="mt-2 font-display text-xl tracking-tightest">{c.h}</h3>
                  <p className="mt-2 leading-relaxed text-muted">{c.p}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── How it works ─────────────────────────────────────── */}
      <section id="how" className="rule scroll-mt-20">
        <div className="wrap py-20">
          <Reveal>
            <p className="eyebrow mb-3">How it works</p>
            <h2 className="max-w-2xl font-display text-3xl leading-tight tracking-tightest md:text-4xl">
              Every swap is quoted twice. The taker gets the worse one.
            </h2>
            <p className="mt-4 max-w-2xl leading-relaxed text-ink-soft">
              This is arithmetic, not a prediction. There is no model to be wrong, no oracle to read,
              and no classifier deciding who looks like an attacker.
            </p>
          </Reveal>

          <Reveal delay={120} className="mt-12">
            <FlowDiagram />
          </Reveal>

          <Reveal delay={200} className="mt-10">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="card transition-all duration-300 hover:-translate-y-1 hover:border-marine hover:shadow-lift">
                <p className="eyebrow mb-3">Exact input</p>
                <code className="tnum block font-mono text-sm">
                  output = <span className="text-marine">min</span>(local, aggregate)
                </code>
              </div>
              <div className="card transition-all duration-300 hover:-translate-y-1 hover:border-marine hover:shadow-lift">
                <p className="eyebrow mb-3">Exact output</p>
                <code className="tnum block font-mono text-sm">
                  input = <span className="text-marine">max</span>(local, aggregate)
                </code>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ── Measured ─────────────────────────────────────────── */}
      <section className="rule">
        <div className="wrap py-20">
          <Reveal>
            <p className="eyebrow mb-3">Measured</p>
            <h2 className="mb-12 font-display text-3xl tracking-tightest md:text-4xl">
              Every number comes from a test you can run.
            </h2>
          </Reveal>
          <div className="grid gap-10 md:grid-cols-3">
            <Reveal><Stat label="Value kept with LPs" numeric={6674} unit="bps" tone="marine"
              note="Withheld from a taker exploiting a skewed pool and left with LPs." /></Reveal>
            <Reveal delay={110}><Stat label="Gain from splitting 8 ways" numeric={0}
              note="Sliced output is marginally worse than one large trade. Path independence holds." /></Reveal>
            <Reveal delay={220}><Stat label="Sandwich round trip" value="Unprofitable" tone="marine"
              note="An attacker sandwiching a victim through one pool ends the sequence down 1.484 currency0." /></Reveal>
          </div>
          <Reveal delay={300} className="mt-10">
            <code className="inline-block rounded-md border border-line bg-surface2 px-3 py-2 font-mono text-xs text-ink-soft">
              forge test --match-contract MEVProtectionTest -vv
            </code>
          </Reveal>
        </div>
      </section>

      {/* ── Security ─────────────────────────────────────────── */}
      <section className="rule">
        <div className="wrap py-20">
          <Reveal>
            <p className="eyebrow mb-3">Security</p>
            <h2 className="max-w-2xl font-display text-3xl leading-tight tracking-tightest md:text-4xl">
              Reviewed against Uniswap&rsquo;s own v4 security guidance.
            </h2>
            <p className="mt-4 max-w-2xl leading-relaxed text-ink-soft">
              Reserve mutation is restricted to registered members. Both quote directions round against
              the taker. Custody reduces to one equation, asserted as an invariant across 8,192 lifecycle
              calls: <code className="font-mono text-sm text-marine">PoolManager claims = active reserves + inactive provider assets</code>.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <a href={`${SITE.docs}/security`} target="_blank" rel="noopener noreferrer" className="btn-ghost">
                Threat model &amp; limits ↗
              </a>
              <a href={`${SITE.github}/blob/main/research/mev-findings.md`} target="_blank" rel="noopener noreferrer" className="btn-ghost">
                Adversarial results ↗
              </a>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ── Stack ────────────────────────────────────────────── */}
      <section id="stack" className="rule scroll-mt-20">
        <div className="wrap py-20">
          <Reveal>
            <p className="eyebrow mb-3">Stack</p>
            <h2 className="mb-12 font-display text-3xl tracking-tightest md:text-4xl">What it is built on.</h2>
          </Reveal>
          <div className="grid gap-6 md:grid-cols-2">
            <Reveal>
              <div className="card h-full transition-all duration-300 hover:-translate-y-1 hover:shadow-lift">
                <p className="eyebrow mb-4">On-chain</p>
                <ul className="space-y-3 text-sm">
                  <li className="flex justify-between gap-4 border-b border-line pb-3">
                    <span className="text-ink-soft">Protocol</span><span className="font-mono text-ink">Uniswap v4</span>
                  </li>
                  <li className="flex justify-between gap-4 border-b border-line pb-3">
                    <span className="text-ink-soft">Hook base</span><span className="font-mono text-ink">BaseCustomCurve</span>
                  </li>
                  <li className="flex justify-between gap-4 border-b border-line pb-3">
                    <span className="text-ink-soft">Accounting</span><span className="font-mono text-ink">ERC-6909 claims</span>
                  </li>
                  <li className="flex justify-between gap-4 border-b border-line pb-3">
                    <span className="text-ink-soft">Language</span><span className="font-mono text-ink">Solidity 0.8.26</span>
                  </li>
                  <li className="flex justify-between gap-4">
                    <span className="text-ink-soft">Tooling</span><span className="font-mono text-ink">Foundry</span>
                  </li>
                </ul>
              </div>
            </Reveal>
            <Reveal delay={110}>
              <div className="card h-full transition-all duration-300 hover:-translate-y-1 hover:shadow-lift">
                <p className="eyebrow mb-4">Interface</p>
                <ul className="space-y-3 text-sm">
                  <li className="flex justify-between gap-4 border-b border-line pb-3">
                    <span className="text-ink-soft">Framework</span><span className="font-mono text-ink">Next.js 14</span>
                  </li>
                  <li className="flex justify-between gap-4 border-b border-line pb-3">
                    <span className="text-ink-soft">Chain access</span><span className="font-mono text-ink">wagmi · viem</span>
                  </li>
                  <li className="flex justify-between gap-4 border-b border-line pb-3">
                    <span className="text-ink-soft">Wallet</span><span className="font-mono text-ink">MetaMask</span>
                  </li>
                  <li className="flex justify-between gap-4 border-b border-line pb-3">
                    <span className="text-ink-soft">Docs</span><span className="font-mono text-ink">Mintlify</span>
                  </li>
                  <li className="flex justify-between gap-4">
                    <span className="text-ink-soft">No oracle</span><span className="font-mono text-marine">by design</span>
                  </li>
                </ul>
              </div>
            </Reveal>
          </div>
        </div>
      </section>

      {/* ── CTA ──────────────────────────────────────────────── */}
      <section className="rule">
        <div className="wrap py-20 text-center">
          <Reveal>
            <h2 className="mx-auto max-w-2xl font-display text-3xl leading-tight tracking-tightest md:text-4xl">
              Connect a wallet and watch the bound bind.
            </h2>
            <div className="mt-8 flex flex-wrap justify-center gap-3">
              <Link href="/app" className="btn">Launch app</Link>
              <a href={SITE.github} target="_blank" rel="noopener noreferrer" className="btn-ghost">View source ↗</a>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
