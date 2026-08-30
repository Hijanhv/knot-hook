import Counter from "./Counter";

/**
 * A measured figure. The value counts up on entry so the number reads as something arrived at
 * rather than asserted — which is the whole posture of this project.
 */
export default function Stat({
  label, value, numeric, unit, note, tone = "ink",
}: {
  label: string; value?: string; numeric?: number; unit?: string; note?: string;
  tone?: "ink" | "marine" | "clay";
}) {
  const toneClass =
    tone === "marine" ? "text-accent" : tone === "clay" ? "text-amber" : "text-ink";
  return (
    <div className="group flex flex-col gap-1.5">
      <span className="eyebrow transition-colors group-hover:text-accent">{label}</span>
      <span className={`font-display text-4xl font-semibold tracking-tightest ${toneClass}`}>
        {numeric !== undefined ? <Counter to={numeric} /> : <span className="tnum">{value}</span>}
        {unit && <span className="ml-1 font-sans text-base text-muted">{unit}</span>}
      </span>
      {note && <span className="text-sm leading-snug text-muted">{note}</span>}
      <span className="mt-2 h-px w-0 bg-accent transition-all duration-500 group-hover:w-full" />
    </div>
  );
}
