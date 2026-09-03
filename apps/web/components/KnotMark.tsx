"use client";
import { useEffect, useState } from "react";

/**
 * The hero figure. Two pools quote independently, then a bound is drawn across them and the
 * surplus is pulled back. It loops slowly so the mechanism is legible to someone who never
 * scrolls: watch it once and you know what the hook does.
 */
export default function KnotMark({ className = "" }: { className?: string }) {
  const [t, setT] = useState(0);
  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const frame = requestAnimationFrame(() => setT(3));
      return () => cancelAnimationFrame(frame);
    }
    const id = setInterval(() => setT((x) => (x + 1) % 4), 1600);
    return () => clearInterval(id);
  }, []);

  const bound = t >= 2;

  return (
    <svg viewBox="0 0 360 260" fill="none" className={className} role="img"
      aria-label="Two pools quoting independently, bounded by their combined reserves">
      <defs>
        <linearGradient id="kg" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="currentColor" stopOpacity="0.15" />
          <stop offset="50%" stopColor="currentColor" stopOpacity="0.9" />
          <stop offset="100%" stopColor="currentColor" stopOpacity="0.15" />
        </linearGradient>
      </defs>

      {/* the two strands: deep pool above, shallow below */}
      <path d="M20 78C110 78 140 130 180 130s70-52 160-52" stroke="url(#kg)" strokeWidth="2.5" strokeLinecap="round" />
      <path d="M20 182C110 182 140 130 180 130s70 52 160 52" stroke="url(#kg)" strokeWidth="2.5" strokeLinecap="round" opacity="0.5" />

      {/* pool nodes, breathing so the picture is never fully static */}
      {[[20, 78], [340, 78], [20, 182], [340, 182]].map(([cx, cy], i) => (
        <circle key={i} cx={cx} cy={cy} r="4" fill="currentColor" opacity="0.55">
          <animate attributeName="r" values="4;5.4;4" dur="3.2s" begin={`${i * 0.4}s`} repeatCount="indefinite" />
        </circle>
      ))}

      {/* the crossing, where the bound is enforced */}
      <circle cx="180" cy="130" r={bound ? 9 : 5} fill="currentColor"
        style={{ transition: "r .5s cubic-bezier(.34,1.56,.64,1)" }} />
      <circle cx="180" cy="130" r="22" stroke="currentColor" strokeWidth="1"
        opacity={bound ? 0.4 : 0.12} style={{ transition: "opacity .6s" }} />
      <circle cx="180" cy="130" r="34" stroke="currentColor" strokeWidth="1"
        opacity={bound ? 0.18 : 0} style={{ transition: "opacity .8s" }} />

      {/* the surplus being withheld: a marker that travels out then is pulled back */}
      <circle r="5" fill="currentColor" opacity="0.85">
        <animateMotion dur="6.4s" repeatCount="indefinite"
          path="M20 182C110 182 140 130 180 130s70 52 160 52" keyPoints="0;0.5;0.5;0" keyTimes="0;0.4;0.55;1" calcMode="spline"
          keySplines="0.4 0 0.2 1;0 0 1 1;0.4 0 0.2 1" />
      </circle>

      <text x="180" y="228" textAnchor="middle" className="fill-current font-mono"
        style={{ fontSize: 11, opacity: 0.5, letterSpacing: "0.14em" }}>
        {bound ? "BOUND ENFORCED" : "TWO QUOTES"}
      </text>
    </svg>
  );
}
