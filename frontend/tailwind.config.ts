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
        // Sand, but bright. The previous ground was too low in value for neon to register
        // against — accents only read as electric when the base gives them room.
        canvas: "#fdf4e3",
        sand: { DEFAULT: "#fdf4e3", light: "#fffaf2", deep: "#f2e2c4", shadow: "#dcc59c" },
        surface: "#fffdf9",
        surface2: "#f7ead2",
        // Web3-native accents on sand: electric violet as the brand, cyan as the live/positive
        // signal, Uniswap pink as the highlight. Violet+cyan is the dominant pairing across the
        // space, and the pink is a deliberate nod to the protocol this is built on.
        // Full-saturation, not tinted. Every one of these is at or near maximum chroma.
        ocean: { DEFAULT: "#7b2fff", dim: "#1a0442", bright: "#a855f7", surf: "#00e1ff", foam: "#7df9ff" },
        violet: { DEFAULT: "#7b2fff", deep: "#1a0442", light: "#b085ff" },
        cyan: { DEFAULT: "#00e1ff", deep: "#00b8d4", light: "#7df9ff" },
        pink: { DEFAULT: "#ff0080", light: "#ff4da6" },
        lime: { DEFAULT: "#c4ff2f", deep: "#9ede00" },
        amber: { DEFAULT: "#ffb800", light: "#ffd45c" },
        marine: { DEFAULT: "#7b2fff", dim: "#1a0442", bright: "#00e1ff" },
        coral: "#ff0080",
        clay: "#ff0059",
        hemp: { DEFAULT: "#a8763c", bright: "#c9944f", soft: "#f0e4cf" },
        ink: { DEFAULT: "#150b2e", soft: "#3d2f5c" },
        muted: "#5a5470",
        faint: "#9c93ad",
        line: "#e8d5b4",
        edge: "#150b2e",
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
        lift: "0 2px 4px rgba(21,11,46,0.06), 0 24px 60px -24px rgba(123,47,255,0.45)",
        neon: "0 0 24px -4px rgba(123,47,255,0.55), 0 0 60px -12px rgba(0,225,255,0.4)",
      },
      keyframes: {
        rise: { "0%": { opacity: "0", transform: "translateY(16px)" }, "100%": { opacity: "1", transform: "translateY(0)" } },
        draw: { "0%": { strokeDashoffset: "1000" }, "100%": { strokeDashoffset: "0" } },
        swell: { "0%,100%": { transform: "translateX(0)" }, "50%": { transform: "translateX(-24px)" } },
        bob: { "0%,100%": { transform: "translateY(0)" }, "50%": { transform: "translateY(-6px)" } },
        shimmer: { "0%": { opacity: ".35" }, "50%": { opacity: "1" }, "100%": { opacity: ".35" } },
        "vapor-scroll": { "0%": { backgroundPosition: "0 0" }, "100%": { backgroundPosition: "0 56px" } },
        scan: { "0%": { transform: "translateY(-100%)" }, "100%": { transform: "translateY(100%)" } },
        "hue-drift": { "0%,100%": { filter: "hue-rotate(0deg)" }, "50%": { filter: "hue-rotate(22deg)" } },
      },
      animation: {
        rise: "rise .6s cubic-bezier(.2,.7,.2,1) both",
        draw: "draw 2.4s cubic-bezier(.4,0,.2,1) both",
        swell: "swell 9s ease-in-out infinite",
        bob: "bob 5s ease-in-out infinite",
        shimmer: "shimmer 3.5s ease-in-out infinite",
        "vapor-scroll": "vapor-scroll 2.6s linear infinite",
        scan: "scan 7s linear infinite",
        "hue-drift": "hue-drift 12s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};
export default config;
