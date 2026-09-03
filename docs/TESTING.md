# Testing

## Run

```bash
forge test                                          # 142 tests across 15 suites
forge test --match-contract MEVProtectionTest  -vv  # headline adversarial results
forge test --match-contract MEVAdversarialTest -vv  # federation-specific attacks
forge coverage --ir-minimum --no-match-coverage "^(test|script)/"
```

142 tests run against the canonical v4 `PoolManager`, with nothing mocked but the ERC-20s. Line
coverage on `src/` is 96.21%. Fuzz properties run 1,000 cases each. Four federation invariants
each run 8,192 mixed swap and liquidity-lifecycle calls across both members.

Per-suite counts and the MEV class each test answers are tabulated in the
[test-suite docs](https://knot-38d8bd0e.mintlify.app/security/testing).

## Risk map

| Risk | Coverage |
|---|---|
| Exact input accidentally chooses the generous quote | Output equals `min(local, aggregate)` |
| Exact output undercharges | Input equals `max(local, aggregate)` |
| Quote rule fails at other sizes | Two 1,000-case fuzz properties |
| Swap updates only one ledger | Aggregate equals the sum of both member books after swaps |
| Ledger diverges from actual custody | Hook claims equal active reserves plus pending deposits and claimable refunds |
| Round trip creates free inventory | Same-pool buy and reverse ends with less input token |
| LP share math drifts | Add and remove return supply and reserves to the prior state |
| Unbalanced deposit silently takes excess tokens | Only proportional amounts are transferred; unused tokens stay with the LP |
| Full LP exit erases another member | Only the exiting member is removed from the aggregate |
| Failed settlement leaves a ghost reserve update | Oversized swap reverts both books atomically |
| Arbitrary caller fabricates reserves | Non-member liquidity and swap updates revert |
| Owner registers an EOA | Code and federation identity checks reject it |
| Same hook is counted twice | Duplicate registration reverts |
| Owner exceeds the federation bound | Registration stops at the immutable member cap |
| Dead member consumes a slot forever | A drained member can unregister even with an abandoned pending request; the provider can still reclaim it |
| Attacker binds the one-shot hook first | Only the federation owner can initialize a registered member |
| JIT liquidity changes the shared quote immediately | Deposits stay pending for the configured maturity window |
| Arbitrary depositor freezes trading | Permissionless requests are independent and never gate swaps, active withdrawals or other deposits |
| Pending capital captures pre-activation returns | No shares are minted until activation at the then-current active ratio |
| Stranger forces another LP into toxic flow | Only the provider can activate or cancel that provider's request |
| Reserve-ratio movement strands excess assets | Activation credits excess to a provider-only refund claim |
| Fuzzed live swap differs from preview | 1,000 swaps compare received output and custody against the pre-trade quote |
| Mixed lifecycle sequences desynchronize books | Four 8,192-call state machines mix swaps, queues, activations, cancellations and refunds with zero handler reverts |
| Conservative quote fails to preserve product | Local and aggregate products never fall across mixed exact modes |

## What is not proved

A coalition controlling registered liquidity is measured rather than resisted: it loosens the
enforced quote by 4,722 bps. That number is published rather than omitted, and permissioned
membership is what bounds it.

Non-standard ERC-20s, fee-on-transfer and rebasing tokens, are untested and unsupported. Order
flow migration is unmeasured: whether the value retained exceeds the routing volume lost is the
open economic question and this suite does not answer it.

Gas, native ETH and the stateful lifecycle are no longer gaps. `GasBenchmark.t.sol` measures the
federation overhead against a hookless v4 pool and asserts it under Uniswap's 50,000 gas
`beforeSwap` budget, `KnotNativeEth.t.sol` runs the full lifecycle with native ETH as
`currency0`, and four state machines cover mixed lifecycle sequences.
