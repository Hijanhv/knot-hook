"use client";
import { useEffect, useRef, useState } from "react";

type Candle = { o: number; h: number; l: number; c: number };

/** One slot per candle, in user units. The viewBox is sized from this rather than fixed, so a
 *  wide band and a narrow one both get candles at the same proportions instead of stretching a
 *  square drawing to fit.
 *
 *  These bands are laid out with preserveAspectRatio="none" across a roughly 8:1 strip, which
 *  stretches x about 1.7x more than y. The drawing is therefore pre-squashed: bodies and stroke
 *  widths are set narrow here so they land upright rather than as squat bars. */
const SLOT = 8;
const BODY = 2.3;
const H = 48;
const WICK_W = 0.28;
const EDGE_W = 0.34;

/**
 * A live-feeling market tape, drawn as proper hollow candlesticks.
 *
 * Hollow for a rising candle, solid for a falling one. That is the traditional Japanese
 * convention and it is the reason this reads in one colour: direction comes from whether the
 * body is filled, not from red against green. In a project about LP value a red/green chart
 * would imply a profit-and-loss claim this chart is not making.
 *
 * The tape is decorative and asserts nothing about real prices, which is why it carries no axis
 * and no labels and is always aria-hidden.
 */
export default function CandleChart({
  count = 28, className = "", showArea = true,
}: { count?: number; className?: string; showArea?: boolean }) {
  const [candles, setCandles] = useState<Candle[]>([]);
  const price = useRef(100);

  useEffect(() => {
    const step = (): Candle => {
      const o = price.current;
      const drift = (Math.random() - 0.45) * 9.5;
      const c = Math.max(46, Math.min(154, o + drift));
      price.current = c;
      const pad = 1.1 + Math.random() * 5.2;
      return { o, c, h: Math.max(o, c) + pad, l: Math.min(o, c) - pad };
    };
    setCandles(Array.from({ length: count }, step));
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const id = setInterval(() => setCandles((p) => [...p.slice(1), step()]), 1500);
    return () => clearInterval(id);
  }, [count]);

  if (!candles.length) return <div className={className} />;

  const lo = Math.min(...candles.map((c) => c.l));
  const hi = Math.max(...candles.map((c) => c.h));
  const span = hi - lo || 1;
  const W = candles.length * SLOT;
  const y = (v: number) => 4 + (H - 8) - ((v - lo) / span) * (H - 8);

  const closePath = candles.map((c, i) => `${i === 0 ? "M" : "L"}${i * SLOT + SLOT / 2},${y(c.c)}`).join(" ");
  const last = candles[candles.length - 1];
  const lastX = (candles.length - 1) * SLOT + SLOT / 2;

  return (
    <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" className={className} aria-hidden>
      <defs>
        <linearGradient id="cc-area" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#0A0A0B" stopOpacity="0.20" />
          <stop offset="100%" stopColor="#0A0A0B" stopOpacity="0" />
        </linearGradient>
        <filter id="cc-glow" x="-80%" y="-80%" width="260%" height="260%">
          <feGaussianBlur stdDeviation="1.2" result="b" />
          <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>

      {showArea && (
        <>
          <path d={`${closePath} L${W},${H} L0,${H} Z`} fill="url(#cc-area)" />
          <path d={closePath} stroke="#0A0A0B" strokeWidth="0.3" fill="none" opacity="0.5" />
        </>
      )}

      {/* The last close, carried across the tape. It gives the eye a horizontal to read the
          candles against, which is what makes a strip of bars look like a market. */}
      <line
        x1="0" x2={W} y1={y(last.c)} y2={y(last.c)}
        stroke="#0A0A0B" strokeWidth="0.22" strokeDasharray="2.2 2.8" opacity="0.38"
      />

      {candles.map((c, i) => {
        const x = i * SLOT + SLOT / 2;
        const up = c.c >= c.o;
        const isLast = i === candles.length - 1;
        // History fades to the left, so the tape has a direction and the present reads loudest.
        const depth = 0.42 + (i / candles.length) * 0.58;
        return (
          <g key={i} opacity={isLast ? 1 : depth} filter={isLast ? "url(#cc-glow)" : undefined}>
            <line x1={x} x2={x} y1={y(c.h)} y2={y(c.l)} stroke="#0A0A0B" strokeWidth={WICK_W} strokeLinecap="round" />
            <rect
              x={x - BODY / 2}
              y={y(Math.max(c.o, c.c))}
              width={BODY}
              height={Math.max(0.7, Math.abs(y(c.o) - y(c.c)))}
              fill={up ? "#FFFFFF" : "#0A0A0B"}
              stroke="#0A0A0B"
              strokeWidth={EDGE_W}
              rx="0.18"
            />
          </g>
        );
      })}

      {/* Marks the present. Small, but it is the one thing on the tape that holds still. */}
      <ellipse cx={lastX} cy={y(last.c)} rx="0.65" ry="1.15" fill="#0A0A0B" />
    </svg>
  );
}
