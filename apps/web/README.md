# KNOT web

The product site is a static Next.js application. It teaches the two-quote rule, exposes a
read-only quote inspector, and keeps reference calculations visually distinct from live chain
reads.

## Commands

Run these from the repository root:

```bash
npm run dev --workspace @knot/web
npm run check --workspace @knot/web
npm run build --workspace @knot/web
```

The static export is written to `apps/web/out/` and is ignored by Git.

## Boundaries

- `app/` owns routes and route-level composition.
- `components/` owns reusable visual and interaction pieces.
- `lib/` owns quote math, validated release state, RPC reads and public evidence constants.
- The landing page performs no RPC work.
- Data routes never present the deterministic fixture as live chain state.
