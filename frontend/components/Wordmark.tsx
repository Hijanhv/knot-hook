import Link from "next/link";
import KnotLogo from "./KnotLogo";

/**
 * Mark plus wordmark. The tile carries the blue and the letters stay black, which is how the
 * reference sets its own: the identity is quiet so the colour can be spent on the headline.
 */
export default function Wordmark({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  const mark = size === "lg" ? 48 : size === "sm" ? 28 : 34;
  const text = size === "lg" ? "text-3xl" : size === "sm" ? "text-lg" : "text-2xl";
  return (
    <Link href="/" className="group flex items-center gap-2.5">
      <KnotLogo size={mark} className="text-blue" />
      <span className={`font-display font-semibold leading-none tracking-tightest text-ink ${text}`}>Knot</span>
    </Link>
  );
}
