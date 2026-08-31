import Link from "next/link";
import KnotLogo from "./KnotLogo";

/**
 * Mark plus wordmark, both in black. The glyph sits on the page with no tile behind it, and
 * the name is set large enough to be the thing you read first.
 */
export default function Wordmark({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  const mark = size === "lg" ? 54 : size === "sm" ? 30 : 40;
  const text = size === "lg" ? "text-[2.75rem]" : size === "sm" ? "text-xl" : "text-[2rem]";
  return (
    <Link href="/" className="group flex items-center gap-2.5">
      <KnotLogo size={mark} className="text-ink" />
      <span className={`font-display font-semibold leading-none tracking-tightest text-ink ${text}`}>Knot</span>
    </Link>
  );
}
