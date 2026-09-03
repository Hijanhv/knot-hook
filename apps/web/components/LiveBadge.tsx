"use client";

export type LiveStatus = "pending" | "loading" | "live" | "stale" | "offline";

/** Never lets deterministic reference values masquerade as a live RPC response. */
export default function LiveBadge({ status, block }: { status: LiveStatus; block?: bigint }) {
  const [dot, text] =
    status === "live"
      ? ["bg-blue animate-pulse", `live · block ${block?.toString() ?? "…"}`]
      : status === "pending"
        ? ["bg-amber", "release manifest unavailable"]
      : status === "stale"
        ? ["bg-amber", `stale rpc · block ${block?.toString() ?? "…"}`]
      : status === "loading"
        ? ["bg-faint animate-pulse", "reading unichain sepolia"]
        : ["bg-amber", "rpc unavailable · reference model"];

  return (
    <span className="pill">
      <span className={`inline-block h-1.5 w-1.5 rounded-full ${dot}`} />
      {text}
    </span>
  );
}
