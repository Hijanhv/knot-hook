import type { Metadata } from "next";
import { Fraunces, Instrument_Sans, IBM_Plex_Mono } from "next/font/google";
import "./globals.css";
import SiteNav from "@/components/SiteNav";
import ScrollProgress from "@/components/ScrollProgress";
import GlowField from "@/components/GlowField";
import AnnounceBar from "@/components/AnnounceBar";
import SiteFooter from "@/components/SiteFooter";
import Providers from "./providers";

/**
 * Three faces, each doing one job.
 *
 * Fraunces is the voice: a variable serif with a real optical-size axis, so headlines can be
 * set at high contrast (thin hairlines, heavy stems) while small text on the same family stays
 * sturdy. Its `SOFT` and `WONK` axes are dialled almost off, keeping the character without the
 * novelty. This is what stops a black-and-white page reading as a default.
 *
 * Instrument Sans carries body copy. Quiet, slightly condensed, and it does not compete with
 * the serif the way a geometric sans would.
 *
 * IBM Plex Mono is for figures and addresses. Every number on this site is a measurement, and
 * Plex has proper tabular forms plus a slashed zero.
 */
const display = Fraunces({
  subsets: ["latin"],
  variable: "--font-display",
  display: "swap",
  axes: ["SOFT", "WONK", "opsz"],
});
const sans = Instrument_Sans({ subsets: ["latin"], variable: "--font-sans", display: "swap" });
const mono = IBM_Plex_Mono({ subsets: ["latin"], weight: ["400", "500"], variable: "--font-mono", display: "swap" });

export const metadata: Metadata = {
  title: "Knot: one pair, several pools, one price boundary",
  description:
    "A Uniswap v4 hook. No participating pool can quote more favourably than both its own reserves and the pair's combined reserves allow. The difference stays with LPs.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${display.variable} ${mono.variable}`}>
      <body className="grain min-h-screen bg-canvas font-sans text-ink antialiased">
        <Providers>
          <GlowField />
          <ScrollProgress />
          <div className="relative z-20"><AnnounceBar /><SiteNav /></div>
          <main className="relative z-10">{children}</main>
          <SiteFooter />
        </Providers>
      </body>
    </html>
  );
}
