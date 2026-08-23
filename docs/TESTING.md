# Testing

## Run

```bash
forge test -vv
```

The Foundry suite has 29 project-defined checks against a real v4 PoolManager harness, plus two inherited harness smoke entries. Three fuzz properties run 1,000 cases each. Four federation invariants each run 8,192 mixed swap and liquidity-lifecycle calls across both members.

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

The current suite does not prove resistance to a coalition controlling registered liquidity. It also does not benchmark gas across production deployments, non-standard ERC-20s, native ETH or a large lifecycle of member additions.

Before final deployment, add a live-chain broadcast, contract verification and non-standard token checks. The stateful lifecycle invariants, withdrawal lifecycle, local gas report and configurable maturity policy are implemented.
