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
    <header className="sticky top-0 z-40 border-b border-line/70 bg-canvas/80 backdrop-blur-xl">
      <div className="wrap flex h-[4.5rem] items-center justify-between gap-6">
        <Wordmark />

        <nav className="hidden items-center gap-8 md:flex">
          <Link href="/#problem" className="text-sm text-muted transition-colors hover:text-ink">The problem</Link>
          <Link href="/#how" className="text-sm text-muted transition-colors hover:text-ink">How it works</Link>
          <Link href="/contracts" className="text-sm text-muted transition-colors hover:text-ink">Contracts</Link>
          <a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="text-sm text-muted transition-colors hover:text-ink">
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
