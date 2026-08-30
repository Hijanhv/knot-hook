import Link from "next/link";
import KnotLogo from "./KnotLogo";

/**
 * Mark plus wordmark. The letters carry the same violet-to-cyan run as the rope, so the two
 * read as one object rather than an icon sitting beside some text.
 */
export default function Wordmark({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  const mark = size === "lg" ? 56 : size === "sm" ? 32 : 42;
  const text = size === "lg" ? "text-4xl" : size === "sm" ? "text-xl" : "text-3xl";
  return (
    <Link href="/" className="group flex items-center gap-2.5">
      <KnotLogo size={mark} className="transition-transform duration-500 group-hover:rotate-[14deg]" />
      <span
        className={`font-display font-bold leading-none tracking-tightest ${text} bg-gradient-to-r from-violet via-violet-light to-cyan bg-clip-text text-transparent`}
      >
        KNOT
      </span>
    </Link>
  );
}
