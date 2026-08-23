"use client";
import { useEffect, useState } from "react";

/** A hairline read-position indicator. Signals depth without occupying layout. */
export default function ScrollProgress() {
  const [pct, setPct] = useState(0);
  useEffect(() => {
    const onScroll = () => {
      const h = document.documentElement.scrollHeight - window.innerHeight;
      setPct(h > 0 ? (window.scrollY / h) * 100 : 0);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  return (
    <div className="fixed inset-x-0 top-0 z-50 h-[2px] bg-transparent">
      <div className="h-full bg-marine transition-[width] duration-150 ease-out" style={{ width: `${pct}%` }} />
    </div>
  );
}
