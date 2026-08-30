import Link from "next/link";
import KnotLogo from "./KnotLogo";

/**
 * Mark plus wordmark. The type is plain white and the mark carries the only colour, so the two
 * never compete. On hover the knot turns a third of a full turn and lands back on its own
 * three-fold symmetry.
 */
export default function Wordmark({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  const mark = size === "lg" ? 52 : size === "sm" ? 30 : 38;
  const text = size === "lg" ? "text-3xl" : size === "sm" ? "text-lg" : "text-2xl";
  return (
    <Link href="/" className="group flex items-center gap-2.5">
      <KnotLogo size={mark} className="transition-transform duration-700 ease-out group-hover:rotate-[120deg]" />
      <span className={`font-display font-semibold leading-none tracking-tightest text-ink ${text}`}>Knot</span>
    </Link>
  );
}
