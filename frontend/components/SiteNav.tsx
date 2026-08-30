"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import Connect from "./Connect";
import Wordmark from "./Wordmark";
import { SITE } from "@/lib/site";

export default function SiteNav() {
  const path = usePathname();
  const onApp = path?.startsWith("/app");

  return (
    <header className="sticky top-0 z-40 border-b border-line bg-canvas/85 backdrop-blur">
      <div className="wrap flex h-16 items-center justify-between gap-6">
        <Wordmark />

        <nav className="hidden items-center gap-7 md:flex">
          <Link href="/#problem" className="text-sm text-ink-soft transition-colors hover:text-ocean">The problem</Link>
          <Link href="/#how" className="text-sm text-ink-soft transition-colors hover:text-ocean">How it works</Link>
          <Link href="/contracts" className="text-sm text-ink-soft transition-colors hover:text-ocean">Contracts</Link>
          <a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="text-sm text-ink-soft transition-colors hover:text-ocean">
            Docs ↗
          </a>
        </nav>

        <div className="flex items-center gap-3">
          {/* No Connect here on /app: that page renders its own, and showing both put two
              connect buttons on screen at once. */}
          {!onApp && <Link href="/app" className="btn">Launch app</Link>}
        </div>
      </div>
    </header>
  );
}
