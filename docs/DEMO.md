# Five-minute demo

## Goal

Show that one stale participating pool cannot offer a quote more generous than both its own curve and the pair's aggregate reserve curve.

## Recording flow

1. Create two custom-accounting pools for the same token pair.
2. Seed Pool A at `1,000 A / 1,500 B` and Pool B at `1,000 A / 500 B`.
3. Display Pool A's isolated exact-input quote and the aggregate quote for `10 A`.
4. Execute through Knot and show that output equals the smaller aggregate quote.
5. Repeat with exact output and show that required input equals the larger quote.
6. Display member reserves, aggregate reserves and PoolManager claims after both trades.
7. Run a reverse trade and show the final portfolio.
8. End on scope: registered same-pair pools, not CEX prices or universal MEV protection.

## On-screen numbers

- local reserves and quote;
- aggregate reserves and quote;
- selected Knot quote;
- value retained by the local pool;
- LP share supply; and
- aggregate-versus-member accounting equality.

## Final evidence checklist

- public repository;
- passing test output;
- federation and hook deployment addresses;
- registration and pool initialization transactions;
- liquidity, exact-input and exact-output transactions;
- gas report;
- slide deck; and
- human-narrated video under five minutes.
