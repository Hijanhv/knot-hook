import Link from "next/link";
import KnotLogo from "./KnotLogo";

/**
 * Mark plus wordmark. The letters use the chrome treatment rather than the rope gradient, so
 * the two are related without competing — the knot supplies the colour, the type supplies the
 * shine.
 */
export default function Wordmark({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  const mark = size === "lg" ? 60 : size === "sm" ? 34 : 46;
  const text = size === "lg" ? "text-4xl" : size === "sm" ? "text-xl" : "text-3xl";
  return (
    <Link href="/" className="group flex items-center gap-2.5">
      <KnotLogo size={mark} className="transition-transform duration-700 ease-out group-hover:rotate-[120deg]" />
      <span className={`chrome font-display font-bold leading-none tracking-tightest ${text}`}>KNOT</span>
    </Link>
  );
}
