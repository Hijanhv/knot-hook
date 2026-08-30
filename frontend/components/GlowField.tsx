/**
 * A single soft wash behind the page. Its only job is to keep a large area of navy from
 * reading as flat; it is deliberately too faint to be seen as an element.
 */
export default function GlowField() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <div className="absolute left-1/2 top-[-22rem] h-[46rem] w-[64rem] -translate-x-1/2 rounded-full bg-accent/[0.10] blur-[140px]" />
    </div>
  );
}
