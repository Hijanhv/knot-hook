/**
 * The mechanism as a drawing: two strands (two pools) that would run apart, tied through a
 * single crossing (the shared reserve check). The stroke animates on load so the binding is
 * something the visitor watches happen rather than reads about.
 */
export default function KnotMark({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 320 200" fill="none" className={className} role="img" aria-label="Two strands tied through one crossing">
      <g stroke="currentColor" strokeWidth="2" strokeLinecap="round" className="animate-draw" style={{ strokeDasharray: 1000 }}>
        <path d="M10 60C90 60 110 140 160 140s70-80 150-80" opacity=".9" />
        <path d="M10 140C90 140 110 60 160 60s70 80 150 80" opacity=".55" />
      </g>
      <circle cx="160" cy="100" r="5" fill="currentColor" />
      <circle cx="160" cy="100" r="15" stroke="currentColor" strokeWidth="1" opacity=".35" />
    </svg>
  );
}
