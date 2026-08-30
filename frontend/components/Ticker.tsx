const LINES = [
  "Live on Unichain Sepolia · chain 1301",
  "6,674 bps withheld from a taker exploiting the skewed pool",
  "Cross-pool round trip flips from +13.58 to −0.075",
  "53 passing Foundry tests · 96.32% line coverage",
  "Four stateful invariants over 8,192 lifecycle calls",
  "Bound verified on-chain, reproduces the suite to the wei",
  "No oracle · no keeper · no off-chain component",
];

/** A live status band. Dense, factual, always moving — the page's pulse. */
export default function Ticker() {
  return (
    <>
      <div className="overflow-hidden border-b border-line bg-surface/60">
        <div className="flex w-max animate-marquee">
          {[0, 1].map((copy) => (
            <div key={copy} aria-hidden={copy === 1} className="flex shrink-0 items-center">
              {LINES.map((t) => (
                <span key={t} className="flex items-center whitespace-nowrap px-5 py-2 font-mono text-[11px] uppercase tracking-[0.14em] text-faint">
                  <span className="mr-3 inline-block h-1 w-1 rounded-full bg-accent" />
                  {t}
                </span>
              ))}
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
