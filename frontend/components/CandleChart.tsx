"use client";
import { useEffect, useRef, useState } from "react";

type Candle = { o: number; h: number; l: number; c: number };

/**
 * A live-feeling market tape. Candles stream right to left on a fixed cadence, with a glow on
 * the leading candle so the eye lands on the present. Decorative motion only — this asserts
 * nothing about real prices.
 *
 * Cyan for up, violet for down, rather than green/red. In a project about LP value those two
 * colours would read as profit and loss and imply a claim the chart is not making. Cyan and
 * violet are also the pairing the Web3 space actually converged on.
 */
export default function CandleChart({
  count = 28, className = "", showArea = true,
}: { count?: number; className?: string; showArea?: boolean }) {
  const [candles, setCandles] = useState<Candle[]>([]);
  const price = useRef(100);

  useEffect(() => {
    const step = (): Candle => {
      const o = price.current;
      const drift = (Math.random() - 0.45) * 6.5;
      const c = Math.max(52, Math.min(148, o + drift));
      price.current = c;
      const pad = 0.8 + Math.random() * 4;
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
  const W = 100, H = 46, slot = W / candles.length, bw = slot * 0.6;
  const y = (v: number) => 3 + (H - 6) - ((v - lo) / span) * (H - 6);

  const closePath = candles.map((c, i) => `${i === 0 ? "M" : "L"}${i * slot + slot / 2},${y(c.c)}`).join(" ");

  return (
    <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" className={className} aria-hidden>
      <defs>
        <linearGradient id="cc-area" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#00e1ff" stopOpacity="0.45" />
          <stop offset="100%" stopColor="#7b2fff" stopOpacity="0" />
        </linearGradient>
        <linearGradient id="cc-line" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#7b2fff" />
          <stop offset="55%" stopColor="#ff0080" />
          <stop offset="100%" stopColor="#00e1ff" />
        </linearGradient>
        <filter id="cc-glow" x="-60%" y="-60%" width="220%" height="220%">
          <feGaussianBlur stdDeviation="0.9" result="b" />
          <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>

      {showArea && (
        <>
          <path d={`${closePath} L${W},${H} L0,${H} Z`} fill="url(#cc-area)" />
          <path d={closePath} stroke="url(#cc-line)" strokeWidth="0.6" fill="none" opacity="1" />
        </>
      )}

      {candles.map((c, i) => {
        const x = i * slot + slot / 2;
        const up = c.c >= c.o;
        const stroke = up ? "#00e1ff" : "#a855f7";
        const last = i === candles.length - 1;
        return (
          <g key={i} opacity={last ? 1 : 0.3 + (i / candles.length) * 0.6} filter={last ? "url(#cc-glow)" : undefined}>
            <line x1={x} x2={x} y1={y(c.h)} y2={y(c.l)} stroke={stroke} strokeWidth="0.3" strokeLinecap="round" />
            <rect
              x={x - bw / 2}
              y={y(Math.max(c.o, c.c))}
              width={bw}
              height={Math.max(0.5, Math.abs(y(c.o) - y(c.c)))}
              fill={up ? stroke : "#7b2fff"}
              stroke={stroke}
              strokeWidth="0.32"
              rx="0.25"
            />
          </g>
        );
      })}
    </svg>
  );
}
