import Link from "next/link";
import KnotLogo from "./KnotLogo";

/**
 * Mark plus wordmark. The reference sets its own in solid black next to a black mark, so the
 * colour is spent entirely on the headline below rather than on the identity.
 */
export default function Wordmark({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  const mark = size === "lg" ? 48 : size === "sm" ? 28 : 34;
  const text = size === "lg" ? "text-3xl" : size === "sm" ? "text-lg" : "text-2xl";
  return (
    <Link href="/" className="group flex items-center gap-2.5">
      <KnotLogo size={mark} className="transition-transform duration-700 ease-out group-hover:rotate-[120deg]" />
      <span className={`font-display font-semibold leading-none tracking-tightest text-ink ${text}`}>Knot</span>
    </Link>
  );
}
