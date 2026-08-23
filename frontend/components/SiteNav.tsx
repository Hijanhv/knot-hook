"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import Connect from "./Connect";
import { SITE } from "@/lib/site";

export default function SiteNav() {
  const path = usePathname();
  const onApp = path?.startsWith("/app");

  return (
    <header className="sticky top-0 z-40 border-b border-line bg-canvas/85 backdrop-blur">
      <div className="wrap flex h-16 items-center justify-between gap-6">
        <Link href="/" className="flex items-center gap-2.5">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden className="text-marine">
            <path d="M4 8c5 0 5 8 10 8s6-4 6-4M4 16c5 0 5-8 10-8s6 4 6 4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          </svg>
          <span className="font-display text-lg tracking-tightest">Knot</span>
        </Link>

        <nav className="hidden items-center gap-7 md:flex">
          <Link href="/#problem" className="text-sm text-ink-soft transition-colors hover:text-marine">The problem</Link>
          <Link href="/#how" className="text-sm text-ink-soft transition-colors hover:text-marine">How it works</Link>
          <Link href="/#stack" className="text-sm text-ink-soft transition-colors hover:text-marine">Stack</Link>
          <a href={SITE.docs} target="_blank" rel="noopener noreferrer" className="text-sm text-ink-soft transition-colors hover:text-marine">
            Docs ↗
          </a>
        </nav>

        <div className="flex items-center gap-3">
          {onApp ? <Connect /> : <Link href="/app" className="btn">Launch app</Link>}
        </div>
      </div>
    </header>
  );
}
