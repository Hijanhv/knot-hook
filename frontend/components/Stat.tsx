export default function Stat({
  label, value, unit, note, tone = "ink",
}: { label: string; value: string; unit?: string; note?: string; tone?: "ink" | "marine" | "clay" }) {
  const toneClass = tone === "marine" ? "text-marine" : tone === "clay" ? "text-clay" : "text-ink";
  return (
    <div className="flex flex-col gap-1.5">
      <span className="eyebrow">{label}</span>
      <span className={`tnum font-display text-3xl tracking-tightest ${toneClass}`}>
        {value}
        {unit && <span className="ml-1 font-sans text-base text-muted">{unit}</span>}
      </span>
      {note && <span className="text-sm leading-snug text-muted">{note}</span>}
    </div>
  );
}
