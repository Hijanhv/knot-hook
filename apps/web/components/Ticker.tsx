import { DEPLOYMENT_IS_ACTIVE } from "@/lib/deployment";
import { RELEASE_EVIDENCE } from "@/lib/evidence";

const LINES = [
  DEPLOYMENT_IS_ACTIVE ? "Live on Unichain Sepolia · chain 1301" : "Release manifest unavailable",
  "6,674 bps boundary in the documented 4×-skew fixture",
  "Constructed cross-pool round trip: +13.5843 without the bound, -0.0298 with it",
  `${RELEASE_EVIDENCE.verification.foundryCases} passing Foundry cases · ${RELEASE_EVIDENCE.coverage.lines}% source line coverage`,
  `${RELEASE_EVIDENCE.verification.statefulInvariantProperties} stateful invariants · ${RELEASE_EVIDENCE.verification.highDepthStatefulCalls.toLocaleString()} high-depth calls`,
  "On-chain preview reproduces the documented fixture to the wei",
  "No oracle · no keeper · no off-chain component",
];

/** A compact evidence band. Every sentence carries its scope with the number. */
export default function Ticker() {
  return (
    <>
      <div className="overflow-hidden border-y border-grid bg-paper">
        <div className="flex w-max animate-marquee">
          {[0, 1].map((copy) => (
            <div key={copy} aria-hidden={copy === 1} className="flex shrink-0 items-center">
              {LINES.map((t) => (
                <span key={t} className="flex items-center whitespace-nowrap px-5 py-2 font-mono text-[11px] uppercase tracking-[0.14em] text-faint">
                  <span className="mr-3 inline-block h-1 w-1 rounded-full bg-blue" />
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
