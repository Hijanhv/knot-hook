"use client";

/**
 * The signature vaporwave element: a perspective grid running to a horizon, scrolling toward
 * the viewer. Built from a repeating gradient under a 3D rotation rather than drawn lines, so
 * it costs one composited transform and nothing per frame.
 */
export default function VaporGrid({ className = "" }: { className?: string }) {
  return (
    <div className={`pointer-events-none overflow-hidden ${className}`} aria-hidden style={{ perspective: "220px" }}>
      <div
        className="absolute inset-x-[-60%] bottom-0 h-[130%] animate-vapor-scroll"
        style={{
          transform: "rotateX(72deg)",
          transformOrigin: "50% 100%",
          backgroundImage:
            "linear-gradient(to right, rgba(0,225,255,0.55) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,0,128,0.55) 1px, transparent 1px)",
          backgroundSize: "56px 56px",
          maskImage: "linear-gradient(to top, #000 12%, transparent 78%)",
          WebkitMaskImage: "linear-gradient(to top, #000 12%, transparent 78%)",
        }}
      />
    </div>
  );
}
