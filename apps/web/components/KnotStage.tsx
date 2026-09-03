"use client";

import dynamic from "next/dynamic";
import KnotLogo from "./KnotLogo";

/**
 * Keeps Three.js out of the first load.
 *
 * Imported statically the renderer put ~130 kB into the homepage's initial chunk, for something
 * that is below the fold on a phone and decorative everywhere. Loading it on its own chunk with
 * `ssr: false` means the page paints on the HTML and the canvas arrives a moment later.
 *
 * The placeholder is the flat logo at the same scale, so the space is never empty and the
 * layout never shifts when the canvas mounts.
 */
const KnotThree = dynamic(() => import("./KnotThree"), {
  ssr: false,
  loading: () => (
    <div className="flex h-full w-full items-center justify-center">
      <KnotLogo size={180} className="animate-float-slow text-ink/10" />
    </div>
  ),
});

export default function KnotStage({ className = "" }: { className?: string }) {
  return <KnotThree className={className} />;
}
