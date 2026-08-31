# MEV protection: measured, not asserted

Every number here comes from `test/MEVProtection.t.sol`. Reproduce with:

```bash
forge test --match-contract MEVProtectionTest -vv
```

## Why this file exists

Across 9,087 test functions scraped from 131 theme-matched UHI repositories, only **28
mention "manipulation"** and **21 mention "attack."** Most hooks prove their code runs. Very
few prove the mechanism survives an adversary. These are the adversarial results, including
the one that goes against us.

## Setup

Two federated pools for the same pair, deliberately asymmetric so the bound has something to
bind against:

| Pool | reserve0 | reserve1 | Role |
|---|---|---|---|
| Deep | 1000 | 1000 | Balanced |
| Shallow | 100 | 400 | Rich in currency1, the "weak link" an attacker would target |

In isolation the shallow pool would hand a currency0 seller an unusually generous amount of
currency1. That is precisely the leak Knot claims to close.

## 1. The core claim holds, and it binds hard

Selling 5 currency0 into the shallow pool:

| | Value |
|---|---|
| Shallow pool's isolated quote | the generous one |
| Federation aggregate quote | the enforced one |
| **Value withheld from the taker, left with LPs** | **6,674 bps of the isolated quote** |

The clamp is not cosmetic. In the skewed configuration it withholds roughly two thirds of
what the isolated pool would have paid out.

## 2. Splitting does not evade the bound

| Path | Output received |
|---|---|
| One 4e18 trade | 5.057301347478414620 |
| Same size, 8 slices in one transaction | 5.057277330351101895 |

Slicing is very slightly **worse** for the taker. Path independence holds, so an attacker
gains nothing by fragmenting. Had this gone the other way the protection would be decorative.

## 3. Sandwiching a victim is unprofitable

Front-run 2e18, victim 1e18, back-run 2e18, all through the shallow pool:

**Attacker currency0 delta: −1.484220902439273232**, a loss.

Sandwiching is not Knot's target (it protects LPs, not swappers), but a protection that
*inverted* under sandwiching would be a real defect. It does not.

## 4. The coalition attack: our weakest result, quantified

`SECURITY.md` discloses this qualitatively: *"Liquidity-based buddy coalitions can weaken the
aggregate reference. This version does not claim coalition-proof MEV prevention."*

Honest, but a claim about magnitude deserves a magnitude. So we measured it. An attacker who
controls a second member pool and skews its ratio:

| | Enforced quote |
|---|---|
| Before coalition skew | 6.315922840581546355 |
| After coalition skew | 9.298871030414048118 |
| **Protection loosened by** | **4,722 bps (≈47%)** |

**An attacker controlling a member pool can loosen the enforced bound by roughly half.** This
is the single most important limitation of the design and it is stated here with a number
rather than a hedge.

Two things bound the damage, neither of which eliminates it:

- Membership is permissioned. The federation owner admits members, so an attacker must first
  be admitted.
- Skewing the aggregate requires real capital in a real pool, proportional to the influence
  sought.

Neither is a proof of safety. Treat permissioned membership as load-bearing security, not
administrative convenience.

## 5. JIT liquidity cannot back a same-block quote

A deposit made in the current block does not move the aggregate. The maturity window means
fresh capital cannot appear, back a single quote, and leave. Verified by asserting the
aggregate is unchanged immediately after a deposit.

## 6. Structural invariants under adversarial flow

- The aggregate always equals the sum of member books, verified after mixed swap sequences.
- Fuzzed across 1,000 randomised swaps (direction, size, target pool), reserves never
  underflow and the aggregate never drifts from the member books.

## What is still not tested

Stated plainly so nobody mistakes this for a clean bill of health.

- **Order-flow migration.** The clamp binds exactly when this pool would otherwise have quoted
  best. Whether the value captured exceeds the routing volume lost is an economic question,
  unmeasured here, and it is the central open risk of the whole design.
- **Real historical flow.** These are constructed scenarios on synthetic reserves, not a replay
  of mainnet swaps. They measure mechanics, not realised LP P&L.
- **Non-standard tokens.** Fee-on-transfer and rebasing tokens need separate deployment testing.
