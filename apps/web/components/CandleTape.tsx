"use client";

import CandleChart from "./CandleChart";

/**
 * The candle tape as a section motif rather than a chart.
 *
 * Same component as the hero uses, masked so it fades out before it reaches the text sitting on
 * top. Candle counts are kept low on purpose: at fifty-plus across a full-bleed band the bodies
 * collapse into a grey wash, and the point is that they read as candles.
 *
 * It is decorative and says nothing about real prices, so it is aria-hidden and never carries
 * a label or an axis. The one place a reader could mistake it for data is if it sat next to a
 * figure, which is why it is only ever used full-bleed behind a heading.
 */
export default function CandleTape({
  className = "",
  height = "h-44",
  opacity = "opacity-[0.22]",
  tone = "ink",
  count = 26,
}: {
  className?: string;
  height?: string;
  opacity?: string;
  tone?: "ink" | "paper";
  count?: number;
}) {
  return (
    <div
      aria-hidden
      className={`pointer-events-none absolute inset-x-0 overflow-hidden ${height} ${opacity} ${className}`}
      style={{
        maskImage: "linear-gradient(to right, transparent, black 12%, black 88%, transparent)",
        WebkitMaskImage: "linear-gradient(to right, transparent, black 12%, black 88%, transparent)",
      }}
    >
      <CandleChart count={count} showArea={false} className={`h-full w-full ${tone === "paper" ? "invert" : ""}`} />
    </div>
  );
}
