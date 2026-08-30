import type { Config } from "tailwindcss";

/**
 * Knot — white paper, a ruled grid, one royal blue.
 *
 * Taken from the Minerva reference. White ground, black text, and a single vivid indigo that
 * does three jobs and no others: the headline, anything interactive, and the full-bleed
 * sections. A faint ruled grid runs behind the whole page, which is where the engineered
 * feeling comes from rather than from borders on every element.
 */
const config: Config = {
  darkMode: ["class"],
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        canvas: "#FFFFFF",
        paper: "#FAFAFA",
        surface: "#FFFFFF",
        surface2: "#F5F5F7",

        // The ruled grid, and the two hairline weights above it. All three sit close together
        // on purpose: structure should be found when looked for, never seen first.
        grid: "#ECECEE",
        line: "#E2E2E5",
        edge: "#CFCFD4",

        // Type ramp, black down to a light grey for captions.
        ink: { DEFAULT: "#0A0A0B", soft: "#3C3C40" },
        muted: "#6E6E76",
        faint: "#9B9BA4",

        // The one colour.
        blue: {
          DEFAULT: "#3B33D1",
          dark: "#241DA8",
          light: "#6B63E8",
          wash: "#4A42DC",
          tint: "#EEEDFB",
        },

        // Aliases so existing markup keeps resolving onto the single accent.
        accent: { DEFAULT: "#3B33D1", light: "#6B63E8", dim: "#241DA8", deep: "#EEEDFB" },
        ocean: { DEFAULT: "#3B33D1", dim: "#EEEDFB", bright: "#6B63E8", surf: "#6B63E8", foam: "#EEEDFB" },
        marine: { DEFAULT: "#3B33D1", dim: "#EEEDFB", bright: "#6B63E8" },
        violet: { DEFAULT: "#3B33D1", deep: "#241DA8", light: "#6B63E8" },
        cyan: { DEFAULT: "#6B63E8", deep: "#241DA8", light: "#EEEDFB" },
        sand: { DEFAULT: "#FFFFFF", light: "#FFFFFF", deep: "#F5F5F7", shadow: "#E2E2E5" },

        // Warnings only. Never used for profit or loss.
        amber: { DEFAULT: "#B4670A", light: "#D98C1F" },
        clay: "#B4670A",
        coral: "#B4670A",
      },
      fontFamily: {
        display: ["var(--font-display)", "system-ui", "sans-serif"],
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "ui-monospace", "monospace"],
      },
      letterSpacing: { tightest: "-0.03em" },
      maxWidth: { content: "84rem" },
      boxShadow: {
        card: "0 1px 2px rgba(10,10,11,0.04)",
        lift: "0 2px 4px rgba(10,10,11,0.04), 0 20px 48px -28px rgba(59,51,209,0.30)",
        glow: "0 8px 24px -10px rgba(59,51,209,0.45)",
      },
      keyframes: {
        rise: { "0%": { opacity: "0", transform: "translateY(14px)" }, "100%": { opacity: "1", transform: "translateY(0)" } },
        draw: { "0%": { strokeDashoffset: "1000" }, "100%": { strokeDashoffset: "0" } },
        bob: { "0%,100%": { transform: "translateY(0)" }, "50%": { transform: "translateY(-8px)" } },
        shimmer: { "0%": { opacity: ".35" }, "50%": { opacity: "1" }, "100%": { opacity: ".35" } },
      },
      animation: {
        rise: "rise .7s cubic-bezier(.2,.7,.2,1) both",
        draw: "draw 2.4s cubic-bezier(.4,0,.2,1) both",
        bob: "bob 7s ease-in-out infinite",
        shimmer: "shimmer 3.5s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};
export default config;
