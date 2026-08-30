import Link from "next/link";

/**
 * No mark, by request. The wordmark carries the identity on its own: heavy, tight, with the
 * final letters in ocean so the word itself reads as sand meeting water.
 */
export default function Wordmark({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  const cls = size === "lg" ? "text-3xl" : size === "sm" ? "text-xl" : "text-2xl";
  return (
    <Link href="/" className={`font-display font-bold tracking-tightest ${cls} leading-none`}>
      <span className="text-ink">KN</span>
      <span className="text-ocean">OT</span>
    </Link>
  );
}
