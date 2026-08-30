"use client";

/**
 * Chromatic split on hover: the same text offset in cyan and pink behind the real glyphs.
 * Vaporwave's core visual joke is a signal that has degraded slightly, so the effect is held
 * to a couple of pixels — enough to read as interference, not as a broken font.
 */
export default function GlitchText({ children, className = "" }: { children: string; className?: string }) {
  return (
    <span className={`group relative inline-block ${className}`} data-text={children}>
      <span aria-hidden className="absolute inset-0 translate-x-0 text-cyan opacity-0 transition-all duration-150 group-hover:-translate-x-[3px] group-hover:opacity-80">
        {children}
      </span>
      <span aria-hidden className="absolute inset-0 translate-x-0 text-pink opacity-0 transition-all duration-150 group-hover:translate-x-[3px] group-hover:opacity-80">
        {children}
      </span>
      <span className="relative">{children}</span>
    </span>
  );
}
