import type { Config } from "tailwindcss";

/**
 * Knot — restraint.
 *
 * A deep navy ground, white type, and exactly one bright accent. The subject is a hard
 * arithmetic boundary, and the design says the same thing by refusing to decorate: no
 * gradients carrying meaning, no second accent competing for the eye, no texture. Structure
 * comes from generous space and hairlines an order of magnitude quieter than the type.
 *
 * The blue is the only saturated colour on the page, so it is spent only on things that are
 * live, interactive, or the result of the mechanism working. Amber is held back for the one
 * case that needs a warning and is never used for profit or loss.
 */
const config: Config = {
  darkMode: ["class"],
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // The ground. Navy rather than black: a slight blue bias toward the accent, so the
        // neutral reads as chosen rather than inherited.
        canvas: "#0A0E17",
        surface: "#101623",
        surface2: "#151C2C",
        elevated: "#1A2233",

        // Hairlines. Both are deliberately close to the ground — borders should be found when
        // looked for, not seen first.
        line: "#1D2637",
        edge: "#283247",

        // Type ramp. Four steps, each a clear stop below the last.
        ink: { DEFAULT: "#FFFFFF", soft: "#B9C2D0" },
        muted: "#8B94A5",
        faint: "#5C6577",

        // The single accent.
        accent: { DEFAULT: "#3D7BFF", light: "#7FA6FF", dim: "#2255C4", deep: "#0E1729" },

        // Aliases kept so existing markup keeps resolving; all collapse onto the one accent.
        ocean: { DEFAULT: "#3D7BFF", dim: "#0E1729", bright: "#7FA6FF", surf: "#7FA6FF", foam: "#A8C4FF" },
        marine: { DEFAULT: "#3D7BFF", dim: "#0E1729", bright: "#7FA6FF" },
        violet: { DEFAULT: "#3D7BFF", deep: "#0E1729", light: "#7FA6FF" },
        cyan: { DEFAULT: "#7FA6FF", deep: "#2255C4", light: "#A8C4FF" },
        sand: { DEFAULT: "#0A0E17", light: "#FFFFFF", deep: "#101623", shadow: "#1D2637" },

        // Reserved for warnings only.
        amber: { DEFAULT: "#E0A030", light: "#F0C070" },
        clay: "#E0A030",
        coral: "#E0A030",
      },
      fontFamily: {
        display: ["var(--font-display)", "system-ui", "sans-serif"],
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "ui-monospace", "monospace"],
      },
      letterSpacing: { tightest: "-0.035em" },
      maxWidth: { content: "76rem" },
      boxShadow: {
        // Depth without harshness: barely-there ambient, plus a long soft drop.
        card: "0 1px 2px rgba(0,0,0,0.30), 0 16px 40px -24px rgba(0,0,0,0.7)",
        lift: "0 1px 2px rgba(0,0,0,0.35), 0 28px 64px -32px rgba(61,123,255,0.45)",
        glow: "0 0 0 1px rgba(61,123,255,0.25), 0 16px 48px -20px rgba(61,123,255,0.5)",
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
