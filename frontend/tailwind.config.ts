import type { Config } from "tailwindcss";

/**
 * Knot — a shoreline.
 *
 * Sand underfoot, ocean as the brand, surf as the accent that marks value being caught and
 * held. The subject is a boundary between two states, so the palette is the most literal
 * boundary there is. Coral is reserved for what an attacker loses, and never used for
 * profit/loss, which red and green would wrongly imply.
 */
const config: Config = {
  darkMode: ["class"],
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // sand, warm and deeper than paper
        canvas: "#eeddc0",
        sand: { DEFAULT: "#eeddc0", light: "#f6ecd9", deep: "#dfc9a4", shadow: "#c9ad83" },
        surface: "#f8f0e1",
        surface2: "#e6d3b3",
        // Web3-native accents on sand: electric violet as the brand, cyan as the live/positive
        // signal, Uniswap pink as the highlight. Violet+cyan is the dominant pairing across the
        // space, and the pink is a deliberate nod to the protocol this is built on.
        ocean: { DEFAULT: "#6d3df5", dim: "#2a1065", bright: "#8b5cf6", surf: "#22d3ee", foam: "#a5f3fc" },
        violet: { DEFAULT: "#6d3df5", deep: "#2a1065", light: "#a78bfa" },
        cyan: { DEFAULT: "#22d3ee", deep: "#0891b2", light: "#a5f3fc" },
        pink: { DEFAULT: "#ff007a", light: "#ff5aa8" },
        marine: { DEFAULT: "#6d3df5", dim: "#2a1065", bright: "#22d3ee" },
        coral: "#ff007a",
        clay: "#e11d6b",
        hemp: { DEFAULT: "#a8763c", bright: "#c9944f", soft: "#f0e4cf" },
        ink: { DEFAULT: "#12212a", soft: "#33474f" },
        muted: "#5d7078",
        faint: "#8a9aa0",
        line: "#d6bf9c",
        edge: "#12212a",
      },
      fontFamily: {
        display: ["var(--font-display)", "system-ui", "sans-serif"],
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "ui-monospace", "monospace"],
      },
      letterSpacing: { tightest: "-0.045em" },
      maxWidth: { content: "78rem" },
      boxShadow: {
        card: "0 1px 2px rgba(18,33,42,0.05), 0 12px 32px -16px rgba(18,33,42,0.2)",
        lift: "0 2px 4px rgba(18,33,42,0.06), 0 24px 60px -24px rgba(10,101,112,0.35)",
      },
      keyframes: {
        rise: { "0%": { opacity: "0", transform: "translateY(16px)" }, "100%": { opacity: "1", transform: "translateY(0)" } },
        draw: { "0%": { strokeDashoffset: "1000" }, "100%": { strokeDashoffset: "0" } },
        swell: { "0%,100%": { transform: "translateX(0)" }, "50%": { transform: "translateX(-24px)" } },
        bob: { "0%,100%": { transform: "translateY(0)" }, "50%": { transform: "translateY(-6px)" } },
        shimmer: { "0%": { opacity: ".35" }, "50%": { opacity: "1" }, "100%": { opacity: ".35" } },
      },
      animation: {
        rise: "rise .6s cubic-bezier(.2,.7,.2,1) both",
        draw: "draw 2.4s cubic-bezier(.4,0,.2,1) both",
        swell: "swell 9s ease-in-out infinite",
        bob: "bob 5s ease-in-out infinite",
        shimmer: "shimmer 3.5s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};
export default config;
