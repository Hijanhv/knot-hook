"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import Wordmark from "./Wordmark";
import { SITE } from "@/lib/site";

export default function SiteNav() {
  const path = usePathname();
  const onApp = path?.startsWith("/app");

  return (
    <header className="sticky top-0 z-40 border-b border-grid bg-canvas/90 backdrop-blur-md">
      <div className="wrap flex h-[4.5rem] items-center justify-between gap-6">
        <Wordmark />

        <nav className="hidden items-center gap-9 md:flex">
          <Link href="/#problem" className="text-[15px] text-muted transition-colors hover:text-ink">The problem</Link>
          <Link href="/#how" className="text-[15px] text-muted transition-colors hover:text-ink">How it works</Link>
          <Link href="/contracts" className="text-[15px] text-muted transition-colors hover:text-ink">Contracts</Link>
          <a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="text-[15px] text-muted transition-colors hover:text-ink">
            Docs <span className="text-faint">↗</span>
          </a>
        </nav>

        <div className="flex items-center gap-2.5">
          <Link href="/demo" className="hidden btn-ghost sm:inline-flex">Attack demo</Link>
          {/* No Connect here on /app: that page renders its own, and showing both put two
              connect buttons on screen at once. */}
          {!onApp && <Link href="/app" className="btn">Launch app</Link>}
        </div>
      </div>
    </header>
  );
}
