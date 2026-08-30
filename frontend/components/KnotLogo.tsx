"use client";
import { useEffect, useState } from "react";

/** Trefoil knot, traced parametrically: x = sin t + 2 sin 2t, y = cos t - 2 cos 2t. */
const TREFOIL = "M 32.00,25.55 L 33.15,25.57 L 34.29,25.63 L 35.43,25.73 L 36.56,25.88 L 37.69,26.07 L 38.79,26.30 L 39.89,26.56 L 40.96,26.87 L 42.01,27.22 L 43.04,27.60 L 44.05,28.01 L 45.02,28.47 L 45.97,28.95 L 46.88,29.47 L 47.76,30.02 L 48.61,30.59 L 49.41,31.19 L 50.18,31.82 L 50.90,32.47 L 51.58,33.14 L 52.22,33.83 L 52.81,34.54 L 53.35,35.26 L 53.84,35.99 L 54.29,36.74 L 54.68,37.49 L 55.03,38.24 L 55.32,39.00 L 55.56,39.76 L 55.75,40.52 L 55.88,41.27 L 55.97,42.02 L 56.00,42.76 L 55.98,43.49 L 55.91,44.20 L 55.78,44.90 L 55.61,45.57 L 55.39,46.23 L 55.11,46.87 L 54.79,47.48 L 54.42,48.06 L 54.01,48.61 L 53.55,49.14 L 53.05,49.63 L 52.51,50.08 L 51.93,50.50 L 51.31,50.88 L 50.66,51.22 L 49.97,51.52 L 49.25,51.78 L 48.50,52.00 L 47.72,52.17 L 46.91,52.30 L 46.09,52.38 L 45.24,52.41 L 44.37,52.40 L 43.49,52.34 L 42.59,52.23 L 41.69,52.07 L 40.77,51.86 L 39.85,51.61 L 38.93,51.31 L 38.00,50.96 L 37.08,50.56 L 36.16,50.12 L 35.24,49.63 L 34.34,49.10 L 33.44,48.52 L 32.56,47.90 L 31.70,47.24 L 30.86,46.54 L 30.03,45.80 L 29.23,45.02 L 28.45,44.21 L 27.70,43.37 L 26.98,42.49 L 26.28,41.58 L 25.62,40.65 L 24.99,39.69 L 24.40,38.70 L 23.85,37.70 L 23.33,36.68 L 22.85,35.64 L 22.41,34.58 L 22.01,33.52 L 21.66,32.44 L 21.34,31.37 L 21.07,30.28 L 20.84,29.20 L 20.66,28.11 L 20.52,27.04 L 20.42,25.96 L 20.37,24.90 L 20.36,23.85 L 20.39,22.82 L 20.47,21.80 L 20.59,20.80 L 20.75,19.82 L 20.95,18.87 L 21.19,17.95 L 21.47,17.05 L 21.79,16.19 L 22.14,15.36 L 22.53,14.56 L 22.95,13.81 L 23.40,13.09 L 23.89,12.41 L 24.40,11.78 L 24.94,11.19 L 25.50,10.65 L 26.08,10.15 L 26.69,9.71 L 27.31,9.31 L 27.95,8.97 L 28.60,8.67 L 29.27,8.43 L 29.94,8.24 L 30.63,8.11 L 31.31,8.03 L 32.00,8.00 L 32.69,8.03 L 33.37,8.11 L 34.06,8.24 L 34.73,8.43 L 35.40,8.67 L 36.05,8.97 L 36.69,9.31 L 37.31,9.71 L 37.92,10.15 L 38.50,10.65 L 39.06,11.19 L 39.60,11.78 L 40.11,12.41 L 40.60,13.09 L 41.05,13.81 L 41.47,14.56 L 41.86,15.36 L 42.21,16.19 L 42.53,17.05 L 42.81,17.95 L 43.05,18.87 L 43.25,19.82 L 43.41,20.80 L 43.53,21.80 L 43.61,22.82 L 43.64,23.85 L 43.63,24.90 L 43.58,25.96 L 43.48,27.04 L 43.34,28.11 L 43.16,29.20 L 42.93,30.28 L 42.66,31.37 L 42.34,32.44 L 41.99,33.52 L 41.59,34.58 L 41.15,35.64 L 40.67,36.68 L 40.15,37.70 L 39.60,38.70 L 39.01,39.69 L 38.38,40.65 L 37.72,41.58 L 37.02,42.49 L 36.30,43.37 L 35.55,44.21 L 34.77,45.02 L 33.97,45.80 L 33.14,46.54 L 32.30,47.24 L 31.44,47.90 L 30.56,48.52 L 29.66,49.10 L 28.76,49.63 L 27.84,50.12 L 26.92,50.56 L 26.00,50.96 L 25.07,51.31 L 24.15,51.61 L 23.23,51.86 L 22.31,52.07 L 21.41,52.23 L 20.51,52.34 L 19.63,52.40 L 18.76,52.41 L 17.91,52.38 L 17.09,52.30 L 16.28,52.17 L 15.50,52.00 L 14.75,51.78 L 14.03,51.52 L 13.34,51.22 L 12.69,50.88 L 12.07,50.50 L 11.49,50.08 L 10.95,49.63 L 10.45,49.14 L 9.99,48.61 L 9.58,48.06 L 9.21,47.48 L 8.89,46.87 L 8.61,46.23 L 8.39,45.57 L 8.22,44.90 L 8.09,44.20 L 8.02,43.49 L 8.00,42.76 L 8.03,42.02 L 8.12,41.27 L 8.25,40.52 L 8.44,39.76 L 8.68,39.00 L 8.97,38.24 L 9.32,37.49 L 9.71,36.74 L 10.16,35.99 L 10.65,35.26 L 11.19,34.54 L 11.78,33.83 L 12.42,33.14 L 13.10,32.47 L 13.82,31.82 L 14.59,31.19 L 15.39,30.59 L 16.24,30.02 L 17.12,29.47 L 18.03,28.95 L 18.98,28.47 L 19.95,28.01 L 20.96,27.60 L 21.99,27.22 L 23.04,26.87 L 24.11,26.56 L 25.21,26.30 L 26.31,26.07 L 27.44,25.88 L 28.57,25.73 L 29.71,25.63 L 30.85,25.57 L 32.00,25.55 Z";
const LEN = 224;

/**
 * The mark is a TREFOIL — the simplest knot that cannot be untied, and the first real object
 * in knot theory. For a project called Knot that is the honest symbol, and unlike two crossed
 * arcs it has genuine three-fold symmetry, so it reads as a designed thing rather than a
 * default.
 *
 * The weave is done in two passes: a wide stroke in the page colour is laid down first, then
 * the coloured strand is drawn over it with a dash pattern that opens gaps exactly where the
 * rope should pass UNDER. That is what makes it look woven instead of merely overlapped.
 *
 * On mount the strand draws itself once around the knot, then the chrome sheen sweeps.
 */
export default function KnotLogo({
  size = 44, animate = true, className = "",
}: { size?: number; animate?: boolean; className?: string }) {
  const [drawn, setDrawn] = useState(!animate);
  useEffect(() => {
    if (!animate) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return setDrawn(true);
    const t = setTimeout(() => setDrawn(true), 60);
    return () => clearTimeout(t);
  }, [animate]);

  const uid = `tk${size}`;
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none" className={className} role="img" aria-label="Knot">
      <defs>
        <linearGradient id={`${uid}-g`} x1="6" y1="58" x2="58" y2="6" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stopColor="#7b2fff" />
          <stop offset="35%" stopColor="#ff0080" />
          <stop offset="70%" stopColor="#a855f7" />
          <stop offset="100%" stopColor="#00e1ff" />
        </linearGradient>
        <filter id={`${uid}-glow`} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2.2" result="b" />
          <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>

      {/* pass 1: the page-coloured underlay that carves the gaps */}
      <path d={TREFOIL} stroke="var(--knot-bg, #fdf4e3)" strokeWidth="11" strokeLinecap="round" fill="none"
        opacity={drawn ? 1 : 0} style={{ transition: "opacity .3s" }} />

      {/* pass 2: the strand, dashed so it lifts away at the three crossings */}
      <g filter={`url(#${uid}-glow)`}>
        <path
          d={TREFOIL}
          stroke={`url(#${uid}-g)`}
          strokeWidth="6"
          strokeLinecap="round"
          fill="none"
          strokeDasharray={drawn ? "58 16" : `${LEN} ${LEN}`}
          strokeDashoffset={drawn ? 8 : LEN}
          style={{ transition: "stroke-dashoffset 1.15s cubic-bezier(.4,0,.2,1), stroke-dasharray .5s ease 1.1s" }}
        />
      </g>

      {/* the centre: where the three crossings resolve */}
      <circle cx="32" cy="32" r="3.4" fill="#00e1ff"
        style={{
          transform: drawn ? "scale(1)" : "scale(0)",
          transformOrigin: "32px 32px",
          transition: "transform .5s cubic-bezier(.34,1.56,.64,1) 1.25s",
        }} />
    </svg>
  );
}
