# Ideation

## Start with what a hook can know

A local hook cannot know the true Binance price without importing an oracle. It can know something smaller and fully verifiable: the reserves of other participating v4 pools for the same pair.

That matters because one pool can become stale or heavily skewed while another pool already reflects opposite flow. An arbitrageur receives the generous local quote, and the stale pool's LPs pay to reconnect prices.

## Design constraints

Knot was derived under six constraints:

1. No CEX feed, keeper or off-chain classifier.
2. No attempt to decide whether a trader is good or toxic.
3. Instant atomic swaps for exact input and exact output.
4. Constant work per quote, regardless of federation size.
5. Every reserve used for pricing belongs to an authenticated member.
6. Local PoolManager claims and the aggregate ledger move together.

## Derivation

The local curve remains the hard liquidity limit. The federation curve becomes a second price boundary.

For exact input, a larger output is better for the trader and worse for the pool. The safe choice is the smaller quote.

For exact output, a smaller input is better for the trader and worse for the pool. The safe choice is the larger quote.

That produces one symmetric rule:

```text
exact input  -> min(local output, aggregate output)
exact output -> max(local input,  aggregate input)
```

The selected trade updates both reserve books atomically. The aggregate book is always the sum of member books, so quoting is O(1). It never loops through pools during a swap.

## Why the obvious alternatives are different

### “Just route to the best pool”

Best-price routing helps the trader extract the stale quote. Knot protects the chosen pool from quoting more generously than both reserve views.

### “Arbitrage will fix it anyway”

That correction is the value leakage. Knot keeps the clipped wedge with the local pool instead of paying the first arbitrageur to discover it.

### “Use a TWAP”

A TWAP imports a delayed history from one venue and can remain stale after a jump. Knot uses the current on-chain reserve state of participating pools. It is still not an external fair-price oracle.

### “Read every pool during the swap”

That makes gas grow with membership and creates a large external-call surface. Knot maintains one aggregate reserve pair incrementally.

### “Let every pool join permissionlessly”

A fake pool could report imaginary reserves and move the aggregate quote. This version makes membership explicit and authenticated.

## Narrow claim

Knot reduces stale-quote leakage among registered v4 pools for one pair. It does not solve CEX-DEX LVR, unregistered venues, every sandwich, or a coalition that controls registered liquidity.
