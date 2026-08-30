/**
 * The ruled grid behind the page. Fixed, so the rules stay put while content scrolls over
 * them, which is what makes the page feel like it is drawn on paper rather than scrolling as
 * one slab. Purely decorative and costs nothing.
 */
export default function GlowField() {
  return (
    <div aria-hidden className="gridlines pointer-events-none fixed inset-0 z-0" />
  );
}
