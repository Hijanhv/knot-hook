# Security notes

Knot is hackathon code, not audited production software.

## Enforced properties

- Only owner-registered hooks can update federation reserves.
- Duplicate registration is rejected.
- Registration stops at an immutable member cap, and only an empty member can release its slot.
- Only the federation owner can initialize a member or seed its first liquidity.
- Any address can queue later liquidity at the active reserve ratio.
- Each provider can have one inactive request, and only that provider can activate or cancel it.
- New liquidity cannot affect shared quotes until its maturity window passes.
- Pending liquidity never blocks swaps, active withdrawals, other providers or member-slot removal.
- Activation uses the then-current active ratio. The provider receives shares only at activation and can reclaim any excess.
- Exact-input output never exceeds either the local or aggregate quote.
- Exact-output input is never lower than either reference quote.
- Member and aggregate reserve updates happen atomically with swaps and liquidity changes.
- PoolManager claims exactly back active reserves, pending deposits and provider-owned refunds.
- Both quote directions round against overpayment by the pool.
- LP additions are proportional after the first deposit, and removals burn a proportional share of both reserves.

## Known limits

- The federation owner is trusted to register only genuine Knot hooks for the configured pair.
- Liquidity-based buddy coalitions can weaken the aggregate reference. This version does not claim coalition-proof MEV prevention.
- Maturity prevents immediate activation, not a coalition built from capital that has already matured.
- Federation calls add gas and create a shared liveness dependency for member pools.
- The aggregate reserve state is an internal reference, not an external fair-price oracle.
- Divergence magnitude does not predict toxicity and Knot never reads it. On 67,743 real Base
  swaps, raw cross-pool divergence correlated negatively with markout (Spearman rho = -0.130,
  placebo 0.0005). The directional form did hold: +0.331 bps markout for locally-favourable
  swaps against -0.991 bps for the rest. Knot engages on exactly that direction, proven in
  test/DirectionalSelectivity.t.sol.
- The directional evidence comes from sibling pools at different fee tiers on Base, not from a
  Knot federation, and only four multi-tier pair families in that set carried enough volume. It
  supports the choice of signal. It does not measure the benefit on a live federation.
- A pending request cannot activate after its member unregisters, but its provider can still cancel and reclaim both assets.
- Native token behavior and non-standard ERC-20 tokens need separate deployment testing.
- OpenZeppelin's custom-accounting base is experimental.
- Knot uses return deltas and holds PoolManager claims. Those capabilities require a professional audit before production use.
