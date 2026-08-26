import type { Config } from "tailwindcss";

/**
 * Knot — cordage on paper.
 *
 * The subject is binding: separate pools tied into one reserve calculation. So the
 * palette is marine rope on warm paper rather than the usual DeFi neon-on-black.
 * Deep marine is the brand (the binding), hemp is the warm counterweight (the rope),
 * and a single clay tone marks the value a taker does NOT get to take. Deliberately
 * not red/green — those read as profit/loss and would say the wrong thing.
 */
const config: Config = {
  darkMode: ["class"],
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        canvas: "#f7f5ef",
        surface: "#ffffff",
        surface2: "#efebe0",
        ink: { DEFAULT: "#14181b", soft: "#39423f" },
        muted: "#66706c",
        faint: "#98a09c",
        line: "#e2ddcf",
        edge: "#171c1a",
        marine: { DEFAULT: "#0d4f4a", dim: "#083733", bright: "#3fbfae" },
        hemp: { DEFAULT: "#a8763c", bright: "#c9944f", soft: "#f0e4cf" },
        clay: "#a8452f",
      },
      fontFamily: {
        display: ["var(--font-display)", "Georgia", "serif"],
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "ui-monospace", "monospace"],
      },
      letterSpacing: { tightest: "-0.04em" },
      maxWidth: { content: "68rem" },
      boxShadow: {
        card: "0 1px 2px rgba(20,24,27,0.04), 0 12px 32px -16px rgba(20,24,27,0.16)",
        lift: "0 2px 4px rgba(20,24,27,0.05), 0 24px 60px -24px rgba(13,79,74,0.22)",
      },
      keyframes: {
        rise: { "0%": { opacity: "0", transform: "translateY(14px)" }, "100%": { opacity: "1", transform: "translateY(0)" } },
        draw: { "0%": { strokeDashoffset: "1000" }, "100%": { strokeDashoffset: "0" } },
      },
      animation: {
        rise: "rise .6s cubic-bezier(.2,.7,.2,1) both",
        draw: "draw 2.4s cubic-bezier(.4,0,.2,1) both",
      },
    },
  },
  plugins: [],
};
export default config;
