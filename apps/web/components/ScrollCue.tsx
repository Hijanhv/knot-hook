"use client";
import { useEffect, useState } from "react";

/** Goodgrowth's "Keep scrolling ↓" affordance: invites rather than demands, then gets out of the way. */
export default function ScrollCue({ label = "Keep scrolling" }: { label?: string }) {
  const [gone, setGone] = useState(false);
  useEffect(() => {
    const f = () => setGone(window.scrollY > 120);
    window.addEventListener("scroll", f, { passive: true });
    return () => window.removeEventListener("scroll", f);
  }, []);
  return (
    <div
      className={`flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.2em] text-faint transition-opacity duration-500 ${
        gone ? "opacity-0" : "opacity-100"
      }`}
    >
      {label}
      <span className="inline-block animate-bounce">↓</span>
    </div>
  );
}
