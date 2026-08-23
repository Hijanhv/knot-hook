"use client";
import { useEffect, useState } from "react";

/**
 * The mechanism as a loop, not a static picture: two pools quote, the bound takes the
 * worse one, the difference settles with LPs. The active step cycles so a visitor watching
 * for five seconds sees the whole rule without reading anything.
 */
const STEPS = [
  { k: "local", label: "Local pool quotes", detail: "From this pool's own reserves" },
  { k: "agg", label: "Federation quotes", detail: "From the pair's combined reserves" },
  { k: "bound", label: "Take the worse one", detail: "min for exact input, max for exact output" },
  { k: "lp", label: "Difference stays with LPs", detail: "The taker never gets the surplus" },
];

export default function FlowDiagram() {
  const [active, setActive] = useState(0);
  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const t = setInterval(() => setActive((a) => (a + 1) % STEPS.length), 1900);
    return () => clearInterval(t);
  }, []);

  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      {STEPS.map((s, i) => {
        const on = i === active;
        return (
          <button
            key={s.k}
            onClick={() => setActive(i)}
            className={`group rounded-lg border p-5 text-left transition-all duration-500 ${
              on ? "border-marine bg-surface shadow-lift" : "border-line bg-surface/60"
            }`}
          >
            <span className={`tnum font-mono text-xs transition-colors ${on ? "text-marine" : "text-faint"}`}>
              0{i + 1}
            </span>
            <p className={`mt-2 font-display text-lg leading-snug tracking-tightest transition-colors ${on ? "text-ink" : "text-ink-soft"}`}>
              {s.label}
            </p>
            <p className="mt-1.5 text-sm leading-snug text-muted">{s.detail}</p>
            <span
              className={`mt-4 block h-0.5 origin-left rounded-full bg-marine transition-transform duration-[1800ms] ease-linear ${
                on ? "scale-x-100" : "scale-x-0"
              }`}
            />
          </button>
        );
      })}
    </div>
  );
}
