"use client";
import { useEffect, useState } from "react";

/**
 * Two strands tied through one crossing, drawn as interlocking loops with a violet-to-cyan
 * gradient. The strands draw themselves on mount, then the crossing settles with a short
 * overshoot, so the mark reads as the knot being TIED rather than a glyph appearing.
 *
 * The gradient runs along the strand rather than across the box, which keeps the colour
 * transition following the rope instead of cutting across it.
 */
export default function KnotLogo({
  size = 44, animate = true, className = "",
}: { size?: number; animate?: boolean; className?: string }) {
  const [drawn, setDrawn] = useState(!animate);
  useEffect(() => {
    if (!animate) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return setDrawn(true);
    const t = setTimeout(() => setDrawn(true), 80);
    return () => clearTimeout(t);
  }, [animate]);

  const uid = `knot-${size}`;
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none" className={className} aria-label="Knot" role="img">
      <defs>
        <linearGradient id={`${uid}-a`} x1="8" y1="52" x2="56" y2="12" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stopColor="#6d3df5" />
          <stop offset="55%" stopColor="#8b5cf6" />
          <stop offset="100%" stopColor="#22d3ee" />
        </linearGradient>
        <linearGradient id={`${uid}-b`} x1="56" y1="52" x2="8" y2="12" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stopColor="#22d3ee" />
          <stop offset="50%" stopColor="#ff007a" />
          <stop offset="100%" stopColor="#6d3df5" />
        </linearGradient>
        <filter id={`${uid}-glow`} x="-40%" y="-40%" width="180%" height="180%">
          <feGaussianBlur stdDeviation="2.4" result="b" />
          <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>

      <g filter={`url(#${uid}-glow)`} strokeWidth="6" strokeLinecap="round" fill="none">
        {/* under-strand: enters low left, loops over, exits low right */}
        <path
          d="M11 46C11 27 21 17 32 17s21 10 21 29"
          stroke={`url(#${uid}-b)`}
          strokeDasharray="150"
          strokeDashoffset={drawn ? 0 : 150}
          opacity={drawn ? 0.85 : 0}
          style={{ transition: "stroke-dashoffset 1s cubic-bezier(.4,0,.2,1), opacity .3s" }}
        />
        {/* over-strand: the mirror, crossing the first at centre */}
        <path
          d="M11 18C11 37 21 47 32 47s21-10 21-29"
          stroke={`url(#${uid}-a)`}
          strokeDasharray="150"
          strokeDashoffset={drawn ? 0 : 150}
          style={{ transition: "stroke-dashoffset 1s cubic-bezier(.4,0,.2,1) .18s" }}
        />
      </g>

      {/* the crossing: where the bound is enforced */}
      <circle
        cx="32" cy="32" r="5.5" fill="#ff007a"
        style={{
          transform: drawn ? "scale(1)" : "scale(0)",
          transformOrigin: "32px 32px",
          transition: "transform .55s cubic-bezier(.34,1.56,.64,1) 1.05s",
        }}
      />
      <circle cx="32" cy="32" r="10" stroke="#22d3ee" strokeWidth="1.2" fill="none"
        opacity={drawn ? 0.5 : 0} style={{ transition: "opacity .6s 1.2s" }} />
    </svg>
  );
}
