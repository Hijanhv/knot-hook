/**
 * Static export.
 *
 * Every route in this app is prerendered, so there is nothing a Node server would add. Exporting
 * means it deploys to any static host, which is the difference between being tied to one vendor
 * and being a folder anyone can serve.
 *
 * `trailingSlash` is load-bearing: without it Next emits `app.html` rather than `app/index.html`,
 * and a plain static host 404s on /app/.
 *
 * `NEXT_PUBLIC_BASE_PATH` covers hosts that serve from a subdirectory, such as GitHub Pages at
 * /<repo>/. It is empty for local dev and for root-domain hosts, so those are unaffected.
 */
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

/** @type {import('next').NextConfig} */
export default {
  reactStrictMode: true,
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  basePath,
  assetPrefix: basePath || undefined,
};
