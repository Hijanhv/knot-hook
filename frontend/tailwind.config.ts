import type { Config } from "tailwindcss";

/**
 * Knot: white paper, a ruled grid, black ink.
 *
 * Monochrome by choice. White ground, black text, and black doing the three jobs an accent
 * would otherwise do: the headline, anything interactive, and the full-bleed sections.
 * Separation comes from weight and contrast rather than hue. A faint ruled grid runs behind
 * the whole page, which is where the engineered feeling comes from rather than from borders
 * on every element.
 *
 * The `blue`/`accent`/`ocean` names are kept as aliases so existing markup keeps resolving;
 * they all point at the same black ramp. Amber survives for warnings only.
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

        // The accent, such as it is: black, with a grey for the second step and a near-white
        // tint for filled chips.
        blue: {
          DEFAULT: "#0A0A0B",
          dark: "#000000",
          light: "#3C3C40",
          wash: "#0A0A0B",
          tint: "#F1F1F3",
        },

        // Aliases so existing markup keeps resolving onto the single accent.
        accent: { DEFAULT: "#0A0A0B", light: "#3C3C40", dim: "#000000", deep: "#F1F1F3" },
        ocean: { DEFAULT: "#0A0A0B", dim: "#F1F1F3", bright: "#3C3C40", surf: "#3C3C40", foam: "#F1F1F3" },
        marine: { DEFAULT: "#0A0A0B", dim: "#F1F1F3", bright: "#3C3C40" },
        violet: { DEFAULT: "#0A0A0B", deep: "#000000", light: "#3C3C40" },
        cyan: { DEFAULT: "#3C3C40", deep: "#000000", light: "#F1F1F3" },
        sand: { DEFAULT: "#FFFFFF", light: "#FFFFFF", deep: "#F5F5F7", shadow: "#E2E2E5" },

        // Warnings only. Never used for profit or loss.
        amber: { DEFAULT: "#B4670A", light: "#D98C1F" },
        clay: "#B4670A",
        coral: "#B4670A",
      },
      fontFamily: {
        display: ["var(--font-display)", "Georgia", "Times New Roman", "serif"],
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "ui-monospace", "monospace"],
      },
      rotate: { "120": "120deg" },
      letterSpacing: { tightest: "-0.03em", ultra: "0.24em" },
      maxWidth: { content: "84rem" },
      boxShadow: {
        card: "0 1px 2px rgba(10,10,11,0.04)",
        lift: "0 2px 4px rgba(10,10,11,0.04), 0 20px 48px -28px rgba(10,10,11,0.28)",
        glow: "0 8px 24px -10px rgba(10,10,11,0.40)",
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
