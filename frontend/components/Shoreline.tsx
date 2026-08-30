"use client";

/**
 * The water's edge. Three offset wave bands drift at different rates, so the boundary between
 * ocean and sand is always moving without ever demanding attention. Pure SVG and CSS: no
 * images, no JS loop, and frozen entirely under prefers-reduced-motion.
 */
export default function Shoreline({ flip = false, className = "" }: { flip?: boolean; className?: string }) {
  return (
    <div className={`pointer-events-none relative h-24 w-full overflow-hidden ${flip ? "rotate-180" : ""} ${className}`} aria-hidden>
      <svg viewBox="0 0 1440 96" preserveAspectRatio="none" className="absolute inset-0 h-full w-full">
        <path className="animate-swell" style={{ animationDuration: "13s" }} fill="#0a6570" fillOpacity="0.10"
          d="M0,42 C240,74 480,10 720,42 C960,74 1200,10 1440,42 L1440,96 L0,96 Z" />
        <path className="animate-swell" style={{ animationDuration: "9s", animationDirection: "reverse" }} fill="#12909e" fillOpacity="0.13"
          d="M0,58 C240,26 480,88 720,58 C960,28 1200,86 1440,58 L1440,96 L0,96 Z" />
        <path className="animate-swell" style={{ animationDuration: "6.5s" }} fill="#3fc9d6" fillOpacity="0.16"
          d="M0,74 C180,92 420,54 720,74 C1020,94 1260,56 1440,74 L1440,96 L0,96 Z" />
      </svg>
    </div>
  );
}
