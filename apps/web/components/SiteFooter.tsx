import Link from "next/link";
import Wordmark from "./Wordmark";
import { SITE, DEPLOYMENTS } from "@/lib/site";

const short = (a: string) => `${a.slice(0, 6)}…${a.slice(-4)}`;

export default function SiteFooter() {
  return (
    <footer className="mt-0 border-t border-grid bg-paper">
      <div className="wrap grid gap-12 py-16 md:grid-cols-4">
        <div>
          <Wordmark size="sm" />
          <p className="mt-3 max-w-xs text-sm leading-relaxed text-muted">
            One token pair. Several pools. One reserve-aware price boundary.
          </p>
          <p className="mt-4 font-mono text-[11px] uppercase tracking-[0.14em] text-faint">
            {SITE.cohort} · {SITE.theme}
          </p>
        </div>

        <div>
          <p className="eyebrow mb-4">Product</p>
          <ul className="space-y-2.5 text-sm">
            <li><Link href="/app" className="text-muted hover:text-blue">App</Link></li>
            <li><a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="text-muted hover:text-blue">Docs ↗</a></li>
            <li><a href={SITE.github} target="_blank" rel="noopener noreferrer" className="text-muted hover:text-blue">GitHub ↗</a></li>
            <li><Link href="/#how" className="text-muted hover:text-blue">How it works</Link></li>
          </ul>
        </div>

        <div>
          <p className="eyebrow mb-4">Stack</p>
          <ul className="space-y-2.5 text-sm">
            <li><a href={SITE.uniswapV4} target="_blank" rel="noopener noreferrer" className="text-muted hover:text-blue">Uniswap v4 ↗</a></li>
            <li><Link href="/contracts" className="text-muted hover:text-blue">Contracts</Link></li>
            <li className="text-ink-soft">Solidity 0.8.26 · Foundry</li>
            <li className="text-ink-soft">Next.js · wagmi · viem</li>
          </ul>
        </div>

        <div>
          <p className="eyebrow mb-4">Contracts</p>
          <ul className="space-y-2.5 font-mono text-xs">
            {DEPLOYMENTS.map((d) => (
              <li key={d.label} className="flex flex-col gap-0.5">
                <span className="text-ink-soft">{d.label}</span>
                <span className="tnum text-faint">{d.address ? short(d.address) : "manifest unavailable"}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <div className="border-t border-grid">
        <div className="wrap flex flex-col gap-2 py-6 text-xs text-faint md:flex-row md:items-center md:justify-between">
          <p>Built for the Uniswap Hook Incubator · {SITE.theme}</p>
          <p>Unaudited hackathon software. Figures measure mechanics, not realised LP P&amp;L.</p>
        </div>
      </div>
    </footer>
  );
}
