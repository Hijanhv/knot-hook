/**
 * Soft radial washes behind the page. They give the sand ground some energy without adding
 * anything the eye has to read — the colour lives in the light rather than in more elements.
 * Fixed, pointer-events-none, and cheap: three blurred divs, no JS.
 */
export default function GlowField() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <div className="absolute -left-32 top-[-10%] h-[36rem] w-[36rem] rounded-full bg-violet/25 blur-[120px]" />
      <div className="absolute -right-40 top-[22%] h-[34rem] w-[34rem] rounded-full bg-cyan/25 blur-[120px]" />
      <div className="absolute bottom-[-12%] left-[28%] h-[30rem] w-[30rem] rounded-full bg-pink/20 blur-[120px]" />
    </div>
  );
}
