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
- Newly activated shares cannot transfer or withdraw until a second maturity window passes.
- Pending liquidity never blocks swaps, active withdrawals, other providers or member-slot removal.
- Activation uses the then-current active ratio. The provider receives shares only at activation and can reclaim any excess.
- Exact-input output never exceeds either the local or aggregate quote.
- Exact-output input is never lower than either reference quote.
- Member and aggregate reserve updates happen atomically with swaps and liquidity changes.
- Federation mutations and public LP activation, cancellation and refund entry points reject
  reentrancy; LP activation completes local effects before calling the federation.
- PoolManager claims exactly back active reserves, pending deposits and provider-owned refunds.
- Both quote directions round against overpayment by the pool.
- LP additions are proportional after the first deposit, and removals burn a proportional share of both reserves.
- A registered hook must report this federation and PoolManager, carry the exact callback bits,
  have runtime code, and keep the same runtime code hash recorded at registration.
- Ownership transfer is two-step, and ownership renunciation is disabled so the membership trust
  root cannot be accidentally orphaned.

## Known limits

- The federation owner is trusted to register only genuine Knot hooks for the configured pair.
- The first registered member anchors the accepted runtime code hash. Deployment verification must
  compare it with the reviewed build; the contract cannot distinguish a deliberately malicious
  first implementation chosen by its owner.
- The owner selects the token pair, initial pool price and membership. There is no timelock,
  multisig requirement, upgrade path, pause or emergency withdrawal in this hackathon version.
- Liquidity-based buddy coalitions can weaken the aggregate reference. This version does not claim coalition-proof MEV prevention.
- Maturity prevents immediate activation, not a coalition built from capital that has already matured.
- KNOT reduces but does not eliminate ordinary same-member sandwiching. In the balanced fixture,
  the closed attacker portfolio remains profitable by about 0.393701 token0 versus 1.803279 in the
  hookless control.
- Pools for the same pair that are not registered members bypass the boundary completely.
- The immutable member cap bounds governance surface, but an active LP can keep a member non-empty
  and therefore keep its slot occupied. The owner cannot evict that LP or confiscate its reserves.
- Federation calls add gas and create a shared liveness dependency for member pools.
- The aggregate reserve state is an internal reference, not an external fair-price oracle.
- The aggregate curve is virtual: it is a quote boundary, not pooled custody or a guarantee that a
  router can execute the same amount across all members. A stricter quote may therefore lose order
  flow even when it retains more value per fill.
- Bounding a quote to the pair's reserves is not toxicity classification. On 67,743 Base swaps,
  raw cross-pool divergence correlated negatively with markout (Spearman rho = -0.130; shuffled
  placebo 0.0005). A directional split was +0.331 bps for locally-favourable swaps and -0.991 bps
  for the rest, but it covered four active pair families and no live KNOT federation. It supports
  studying the selected direction; it does not establish causality or realised KNOT P&L.
- A pending request cannot activate after its member unregisters, but its provider can still cancel and reclaim both assets.
- Native ETH is covered by the full live lifecycle suite. Fee-on-transfer, rebasing and
  callback-bearing ERC-20s are deliberately unsupported. Negative fixtures prove that settlement
  reverts atomically or, for a forced negative rebase, that the external token can make
  PoolManager claims undercollateralized without corrupting KNOT's internal books.
- OpenZeppelin's custom-accounting base is experimental.
- A registered member whose runtime code somehow changes fails closed on federation calls. That
  protects the reserve ledger but can freeze that member's active liquidity; this is a safety-over-
  liveness choice, not an automatic recovery mechanism.
- Knot uses return deltas and holds PoolManager claims. Those capabilities require a professional audit before production use.
