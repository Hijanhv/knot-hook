"use client";
import { useEffect, useState } from "react";

/**
 * The mark is a real overhand knot drawn as one continuous path: a single strand that crosses
 * itself and pulls tight. That is the mechanism — separate strands bound at one crossing — so
 * the logo carries the idea rather than decorating it.
 *
 * On mount the path draws itself, then the crossing point pulses once. The animation reads as
 * the knot being TIED, which is a better first impression than a static glyph appearing.
 */
export default function KnotLogo({
  size = 24, animate = true, className = "",
}: { size?: number; animate?: boolean; className?: string }) {
  const [drawn, setDrawn] = useState(!animate);
  useEffect(() => {
    if (!animate) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return setDrawn(true);
    const t = setTimeout(() => setDrawn(true), 60);
    return () => clearTimeout(t);
  }, [animate]);

  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none" className={className} aria-hidden>
      <g stroke="currentColor" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round">
        {/* under-strand, drawn first so the over-strand visually crosses it */}
        <path
          d="M9 31c0-9 7-15 15-15s15 6 15 15"
          strokeDasharray="120"
          strokeDashoffset={drawn ? 0 : 120}
          style={{ transition: "stroke-dashoffset .9s cubic-bezier(.4,0,.2,1)" }}
          opacity="0.45"
        />
        {/* over-strand */}
        <path
          d="M9 17c0 9 7 15 15 15s15-6 15-15"
          strokeDasharray="120"
          strokeDashoffset={drawn ? 0 : 120}
          style={{ transition: "stroke-dashoffset .9s cubic-bezier(.4,0,.2,1) .15s" }}
        />
      </g>
      {/* the crossing: where the two strands are bound */}
      <circle
        cx="24" cy="24" r="3.2" fill="currentColor"
        style={{
          transform: drawn ? "scale(1)" : "scale(0)",
          transformOrigin: "24px 24px",
          transition: "transform .5s cubic-bezier(.34,1.56,.64,1) .95s",
        }}
      />
    </svg>
  );
}
