"use client";

/**
 * The banded sun. Horizontal slices widening toward the bottom is the detail that makes it
 * read as vaporwave rather than a plain circle; the gradient runs hot pink at the top into
 * amber at the horizon.
 */
export default function VaporSun({ size = 300, className = "" }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 200 200" className={className} aria-hidden>
      <defs>
        <linearGradient id="vsun" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#ff0080" />
          <stop offset="45%" stopColor="#ff4da6" />
          <stop offset="72%" stopColor="#ffb800" />
          <stop offset="100%" stopColor="#ffd45c" />
        </linearGradient>
        <mask id="vsun-bands">
          <rect width="200" height="200" fill="#fff" />
          {/* slices widen and separate toward the horizon */}
          {[112, 126, 141, 157, 174].map((y, i) => (
            <rect key={y} x="0" y={y} width="200" height={2 + i * 1.6} fill="#000" />
          ))}
        </mask>
        <filter id="vsun-glow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="7" result="b" />
          <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      <circle cx="100" cy="100" r="72" fill="url(#vsun)" mask="url(#vsun-bands)" filter="url(#vsun-glow)" />
    </svg>
  );
}
