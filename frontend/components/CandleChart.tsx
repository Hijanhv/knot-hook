"use client";
import { useEffect, useRef, useState } from "react";

type Candle = { o: number; h: number; l: number; c: number };

/**
 * A live-feeling market tape. Candles stream right to left on a fixed cadence and the last
 * one ticks between prints, so the page has a pulse without anything on screen being a lie:
 * this is decorative motion, not a claim about real prices.
 *
 * Colour follows the shoreline palette rather than red/green, because in this project red and
 * green would read as profit and loss and mean the wrong thing.
 */
export default function CandleChart({ count = 34, className = "" }: { count?: number; className?: string }) {
  const [candles, setCandles] = useState<Candle[]>([]);
  const price = useRef(100);

  useEffect(() => {
    const step = (): Candle => {
      const o = price.current;
      const drift = (Math.random() - 0.46) * 5.5;
      const c = Math.max(55, Math.min(145, o + drift));
      price.current = c;
      const pad = 0.6 + Math.random() * 3.2;
      return { o, c, h: Math.max(o, c) + pad, l: Math.min(o, c) - pad };
    };

    setCandles(Array.from({ length: count }, step));
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const id = setInterval(() => setCandles((prev) => [...prev.slice(1), step()]), 1400);
    return () => clearInterval(id);
  }, [count]);

  if (!candles.length) return <div className={className} />;

  const lo = Math.min(...candles.map((c) => c.l));
  const hi = Math.max(...candles.map((c) => c.h));
  const span = hi - lo || 1;
  const W = 100, H = 42, slot = W / candles.length, bw = slot * 0.55;
  const y = (v: number) => H - ((v - lo) / span) * H;

  return (
    <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" className={className} aria-hidden>
      {candles.map((c, i) => {
        const x = i * slot + slot / 2;
        const up = c.c >= c.o;
        const stroke = up ? "#3fc9d6" : "#0a6570";
        const last = i === candles.length - 1;
        return (
          <g key={i} opacity={last ? 1 : 0.28 + (i / candles.length) * 0.55}>
            <line x1={x} x2={x} y1={y(c.h)} y2={y(c.l)} stroke={stroke} strokeWidth="0.28" />
            <rect
              x={x - bw / 2}
              y={y(Math.max(c.o, c.c))}
              width={bw}
              height={Math.max(0.4, Math.abs(y(c.o) - y(c.c)))}
              fill={up ? stroke : "none"}
              stroke={stroke}
              strokeWidth="0.28"
            />
          </g>
        );
      })}
    </svg>
  );
}
