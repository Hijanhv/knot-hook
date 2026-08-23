"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import Connect from "./Connect";
import KnotLogo from "./KnotLogo";
import { SITE } from "@/lib/site";

export default function SiteNav() {
  const path = usePathname();
  const onApp = path?.startsWith("/app");

  return (
    <header className="sticky top-0 z-40 border-b border-line bg-canvas/85 backdrop-blur">
      <div className="wrap flex h-16 items-center justify-between gap-6">
        <Link href="/" className="group flex items-center gap-2.5">
          <KnotLogo size={26} className="text-marine transition-transform duration-300 group-hover:rotate-[8deg]" />
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
