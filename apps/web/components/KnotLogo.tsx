"use client";

/**
 * The mark is a TREFOIL: the simplest knot that cannot be untied, and the first real object in
 * knot theory. For a project called Knot that is the honest symbol, and its three-fold symmetry
 * means it reads as a designed thing rather than a default.
 *
 * Drawn as the bare glyph: a black stroke on whatever it sits on, no tile behind it and no
 * second colour. `tile` is kept for anywhere a knocked-out badge is wanted, but it is off by
 * default, so the mark is black and white.
 *
 * The weave is ONE continuous stroke. Layering an over-strand on top of an under-strand leaves a
 * hairline seam wherever the two strokes end, so instead the three passes that go UNDER are just
 * gaps in a single dash pattern. One stroke, three gaps, nothing overlapping, nothing to seam.
 *
 * Both the path and the gap positions were computed rather than drawn. The curve is
 * x = sin t + 2 sin 2t, y = cos t - 2 cos 2t; its three self-crossings were solved for
 * numerically; and over/under alternates around the strand, which is what makes this a knot
 * rather than three arcs lying on one another. The three dash runs come out at 58.1, 62.8 and
 * 62.8 units, which is the three-fold symmetry falling out of the arithmetic on its own.
 */
const D = "M32.0 27.1L33.0 27.2L33.9 27.2L34.9 27.3L35.8 27.4L36.8 27.5L37.7 27.6L38.6 27.8L39.5 28.0L40.4 28.3L41.3 28.5L42.2 28.8L43.1 29.1L43.9 29.5L44.8 29.8L45.6 30.2L46.4 30.6L47.1 31.0L47.9 31.5L48.6 31.9L49.3 32.4L50.0 32.9L50.6 33.4L51.2 34.0L51.8 34.5L52.4 35.1L52.9 35.6L53.4 36.2L53.9 36.8L54.3 37.4L54.8 38.0L55.1 38.6L55.5 39.3L55.8 39.9L56.1 40.5L56.3 41.2L56.5 41.8L56.7 42.4L56.8 43.1L56.9 43.7L57.0 44.3L57.0 44.9L57.0 45.5L57.0 46.1L56.9 46.7L56.8 47.3L56.6 47.9L56.5 48.4L56.3 49.0L56.0 49.5L55.7 50.0L55.4 50.5L55.1 50.9L54.7 51.4L54.4 51.8L53.9 52.2L53.5 52.6L53.0 53.0L52.5 53.3L52.0 53.6L51.4 53.9L50.9 54.1L50.3 54.4L49.7 54.6L49.0 54.7L48.4 54.9L47.7 55.0L47.0 55.1L46.3 55.1L45.6 55.1L44.9 55.1L44.2 55.1L43.4 55.0L42.7 54.9L41.9 54.7L41.1 54.6L40.4 54.4L39.6 54.1L38.8 53.8L38.1 53.5L37.3 53.2L36.5 52.8L35.8 52.4L35.0 52.0L34.2 51.6L33.5 51.1L32.8 50.6L32.0 50.0L31.3 49.5L30.6 48.9L29.9 48.2L29.3 47.6L28.6 46.9L28.0 46.2L27.4 45.5L26.8 44.8L26.2 44.0L25.6 43.3L25.1 42.5L24.6 41.7L24.1 40.9L23.6 40.0L23.2 39.2L22.8 38.3L22.4 37.4L22.0 36.6L21.7 35.7L21.4 34.8L21.1 33.9L20.8 33.0L20.6 32.1L20.4 31.2L20.3 30.3L20.1 29.4L20.0 28.5L19.9 27.6L19.9 26.7L19.9 25.8L19.9 24.9L19.9 24.1L20.0 23.2L20.1 22.4L20.2 21.6L20.4 20.8L20.5 20.0L20.7 19.2L21.0 18.5L21.2 17.8L21.5 17.0L21.8 16.4L22.1 15.7L22.5 15.1L22.9 14.5L23.2 13.9L23.7 13.3L24.1 12.8L24.5 12.3L25.0 11.8L25.5 11.4L26.0 11.0L26.5 10.6L27.0 10.3L27.5 10.0L28.1 9.7L28.6 9.5L29.2 9.3L29.7 9.2L30.3 9.0L30.9 8.9L31.4 8.9L32.0 8.9L32.6 8.9L33.1 8.9L33.7 9.0L34.3 9.2L34.8 9.3L35.4 9.5L35.9 9.7L36.5 10.0L37.0 10.3L37.5 10.6L38.0 11.0L38.5 11.4L39.0 11.8L39.5 12.3L39.9 12.8L40.3 13.3L40.8 13.9L41.1 14.5L41.5 15.1L41.9 15.7L42.2 16.4L42.5 17.0L42.8 17.8L43.0 18.5L43.3 19.2L43.5 20.0L43.6 20.8L43.8 21.6L43.9 22.4L44.0 23.2L44.1 24.1L44.1 24.9L44.1 25.8L44.1 26.7L44.1 27.6L44.0 28.5L43.9 29.4L43.7 30.3L43.6 31.2L43.4 32.1L43.2 33.0L42.9 33.9L42.6 34.8L42.3 35.7L42.0 36.6L41.6 37.4L41.2 38.3L40.8 39.2L40.4 40.0L39.9 40.9L39.4 41.7L38.9 42.5L38.4 43.3L37.8 44.0L37.2 44.8L36.6 45.5L36.0 46.2L35.4 46.9L34.7 47.6L34.1 48.2L33.4 48.9L32.7 49.5L32.0 50.0L31.2 50.6L30.5 51.1L29.8 51.6L29.0 52.0L28.2 52.4L27.5 52.8L26.7 53.2L25.9 53.5L25.2 53.8L24.4 54.1L23.6 54.4L22.9 54.6L22.1 54.7L21.3 54.9L20.6 55.0L19.8 55.1L19.1 55.1L18.4 55.1L17.7 55.1L17.0 55.1L16.3 55.0L15.6 54.9L15.0 54.7L14.3 54.6L13.7 54.4L13.1 54.1L12.6 53.9L12.0 53.6L11.5 53.3L11.0 53.0L10.5 52.6L10.1 52.2L9.6 51.8L9.3 51.4L8.9 50.9L8.6 50.5L8.3 50.0L8.0 49.5L7.7 49.0L7.5 48.4L7.4 47.9L7.2 47.3L7.1 46.7L7.0 46.1L7.0 45.5L7.0 44.9L7.0 44.3L7.1 43.7L7.2 43.1L7.3 42.4L7.5 41.8L7.7 41.2L7.9 40.5L8.2 39.9L8.5 39.3L8.9 38.6L9.2 38.0L9.7 37.4L10.1 36.8L10.6 36.2L11.1 35.6L11.6 35.1L12.2 34.5L12.8 34.0L13.4 33.4L14.0 32.9L14.7 32.4L15.4 31.9L16.1 31.5L16.9 31.0L17.6 30.6L18.4 30.2L19.2 29.8L20.1 29.5L20.9 29.1L21.8 28.8L22.7 28.5L23.6 28.3L24.5 28.0L25.4 27.8L26.3 27.6L27.2 27.5L28.2 27.4L29.1 27.3L30.1 27.2L31.0 27.2Z";
const DASH = "58.1 15.0 62.8 15.0 62.8 15.0 4.7";

export default function KnotLogo({
  size = 34, className = "", tile = false,
}: { size?: number; className?: string; tile?: boolean }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none" className={className}
      role="img" aria-label="Knot">
      {tile && <rect width="64" height="64" rx="10.5" fill="currentColor" />}
      {/* a third of a turn lands the knot back onto its own symmetry */}
      <g className="origin-center transition-transform duration-700 ease-out group-hover:rotate-120">
        <path d={D} fill="none" stroke={tile ? "#fff" : "currentColor"} strokeWidth="8.6"
          strokeLinecap="butt" strokeDasharray={DASH} />
      </g>
    </svg>
  );
}
