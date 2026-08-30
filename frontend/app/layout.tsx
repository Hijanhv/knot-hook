import type { Metadata } from "next";
import { IBM_Plex_Sans, Space_Grotesk, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import SiteNav from "@/components/SiteNav";
import ScrollProgress from "@/components/ScrollProgress";
import GlowField from "@/components/GlowField";
import SiteFooter from "@/components/SiteFooter";
import Providers from "./providers";

const sans = IBM_Plex_Sans({ subsets: ["latin"], weight: ["400","500","600"], variable: "--font-sans", display: "swap" });
const display = Space_Grotesk({ subsets: ["latin"], variable: "--font-display", display: "swap" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-mono", display: "swap" });

export const metadata: Metadata = {
  title: "Knot — one pair, several pools, one price boundary",
  description:
    "A Uniswap v4 hook. No participating pool can quote more favourably than both its own reserves and the pair's combined reserves allow. The difference stays with LPs.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${display.variable} ${mono.variable}`}>
      <body className="scanlines min-h-screen bg-canvas font-sans text-ink antialiased">
        <Providers>
          <GlowField />
          <ScrollProgress />
          <div className="relative z-20"><SiteNav /></div>
          <main className="relative z-10">{children}</main>
          <SiteFooter />
        </Providers>
      </body>
    </html>
  );
}
