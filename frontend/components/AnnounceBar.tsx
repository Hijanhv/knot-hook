import { SITE } from "@/lib/site";

/**
 * The full-width blue announcement strip that opens the reference layout. It is the first
 * thing on the page and the only place the blue appears above the fold at full bleed, which
 * is what makes the headline underneath read as the same colour deliberately reused.
 */
export default function AnnounceBar() {
  return (
    <a
      href={SITE.docs}
      target="_blank"
      rel="noopener noreferrer"
      className="group block bg-blue text-center transition-colors hover:bg-blue-dark"
    >
      <p className="px-6 py-3 text-[15px] text-white">
        Introducing Knot: a reserve-aware price boundary for Uniswap v4
        <span className="ml-3 inline-block transition-transform group-hover:translate-x-1">&rarr;</span>
      </p>
    </a>
  );
}
