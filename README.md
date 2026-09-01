# Knot

> **One token pair. Several pools. One reserve-aware price boundary.**

> A stale or shallow pool can hand an arbitrageur a better quote than the pair's combined
> liquidity actually supports. Knot makes participating pools check both reserve states before
> a trade, and leaves the difference with the LPs who would otherwise have funded it.

[![Uniswap v4](https://img.shields.io/badge/Uniswap-v4%20hook-FF007A.svg?logo=uniswap)](https://docs.uniswap.org/contracts/v4/overview)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636.svg?logo=solidity)](https://soliditylang.org/)
[![Tests](https://img.shields.io/badge/tests-134%20passing-3FB950.svg)](#verify)
[![Coverage](https://img.shields.io/badge/line%20coverage-96.21%25-3FB950.svg)](#verify)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**UHI10 Hookathon · Sustainable Liquidity & MEV Protection**

**Project ID: `HK-UHI10-1087`**

**Live on Unichain Sepolia.** Federation [`0x91A0…A129`](https://sepolia.uniscan.xyz/address/0x91A0489A1BEA8030AC82351D52BDC3F97d6cA129) ·
deep [`0x3469…6A88`](https://sepolia.uniscan.xyz/address/0x346930bcf767614a6C4654904739cBCF4A8f6A88) ·
shallow [`0x6B8D…AA88`](https://sepolia.uniscan.xyz/address/0x6B8D77a921Adc5244bC0398fa6133841F3DFaA88) ·
[deployment record](deployments/unichain-sepolia-2026-08-23.md)

> **Status:** unaudited hackathon software. The results below are constructed adversarial
> scenarios against the canonical v4 `PoolManager`. They measure mechanics, not realised LP P&L.

---

## The 30-second version

Two Uniswap pools can hold the same tokens and quote very different prices. The shallower one
becomes the weak link: easier to move, and an attacker can take the generous quote it offers
in isolation even though the pair's combined liquidity does not support it.

Knot connects participating pools through one shared reserve ledger. Every swap is quoted
twice, against the local pool and against the federation aggregate, and the trader receives
the **less favourable** of the two. The clipped difference stays with the local pool's LPs.

```text
exact input:   output = min(local output, aggregate output)
exact output:  input  = max(local input,  aggregate input)
```

Pools keep their own reserves, fees and LP ownership. They share only the calculation that
stops one of them becoming the easy exit.

## Key numbers

Measured in `test/MEVProtection.t.sol`, except the gas row (`test/GasBenchmark.t.sol`) and
the size row (`forge build --sizes`). Full write-up:
[`research/mev-findings.md`](research/mev-findings.md).

| | Value |
|---|---|
| Value withheld from a taker exploiting a skewed pool | **6,674 bps** of the isolated quote |
| Advantage from splitting a trade 8 ways | **none**, sliced output is marginally worse |
| Attacker P&L sandwiching through one pool | **−1.484** currency0 (a loss) |
| **Protection loosened by a coalition-controlled member pool** | **4,722 bps (≈47%)** |
| Federation overhead per swap, vs a hookless v4 pool | 41,262 gas (97,023 vs 55,761) |
| `KnotHook` runtime size | 12,936 bytes (24,576 limit) |

That fourth row is the weakest result in the project and it is in the headline table on
purpose. See [Known limits](#known-limits).

## How it works

- **`KnotHook.sol`**: a hook-owned constant-product pool with proportional ERC-20 LP shares.
- **`KnotFederation.sol`**: authenticated per-member reserves plus the O(1) aggregate pair.
- **`KnotMath.sol`**: fee-aware exact-input and exact-output quoting, rounding against the taker
  in both directions.

Membership is bounded and permissioned: the federation owner registers reviewed hook instances,
and only registered hooks can move reserve state. New liquidity must mature before it enters the
shared book, so fresh capital cannot back a single quote and leave. Empty members can unregister
and release their slot.

### Liquidity lifecycle

Each provider has an **independent** pending request. There is no global lock, which means one
provider's pending deposit can never stall swaps, withdrawals, or anyone else's deposit.

1. **Queue**: assets are taken and held inactive. No shares are minted.
2. **Activate**: after the maturity window, shares mint at the *current* reserve ratio, so
   pending capital cannot capture gains that accrued before it entered.
3. **Cancel / claim**: only the provider can activate, cancel or claim, and any excess is
   refundable to them alone.

Custody reduces to one equation: `PoolManager claims = active reserves + inactive provider assets`.

## Verify

Dependencies are vendored under `lib/`, so a fresh clone needs no install step.

```bash
git clone https://github.com/Hijanhv/KNOT-hook-.git && cd KNOT-hook-

forge test                                        # full suite, 134 tests
forge test --match-contract MEVProtectionTest -vv # the adversarial results above

# Coverage needs --ir-minimum. The unoptimised build that coverage forces
# otherwise hits "stack too deep" in script/Deploy.s.sol.
forge coverage --ir-minimum --no-match-coverage "^(test|script)/"
```

## Why this needs to be a hook

A router could compute the same bound, but a trader can simply route around a router. A v4 hook
enforces the rule **inside** each participating pool, and custom accounting lets it compute the
protected amount, update the shared reserve state, and keep the clipped value with the right LPs,
all within the swap.

## Known limits

Stated plainly rather than buried.

- **Coalitions weaken the bound, by about half.** An attacker controlling a member pool can skew
  the aggregate and loosen the enforced quote by ~4,722 bps. Permissioned membership is therefore
  load-bearing security, not administrative convenience.
- **Divergence is not proven to be toxicity.** Knot bounds a quote to what the pair's reserves
  support. It does not follow that the clipped flow was toxic. Tested separately on 67,743 real
  Base swaps across every multi-pool pair family with enough data, raw cross-pool divergence
  correlates *negatively* with markout (Spearman rho = -0.130, placebo-checked at 0.0005, stable
  across three horizons): the most divergent trades were LP-beneficial. A narrower directional
  form did hold (+0.331 bps for locally-favourable swaps against -0.992 bps otherwise). So the
  honest claim is reserve consistency, not toxicity filtering. The adversarial results below are
  constructed sequences and are mechanically real; the economic premise behind them is not
  settled, and the measurement that cuts against it is cited here rather than left out.
- **Order-flow migration is unmeasured.** The clamp binds precisely when this pool would otherwise
  have offered the best price. Whether the value captured exceeds the routing volume lost is the
  central open economic question, and it is not answered here.
- **New pools only.** A pool's hook address is fixed at creation, so existing pools cannot join.
- **Non-member pools stay exploitable.** Anyone can permissionlessly deploy a pool outside the
  federation for the same pair.
- **The aggregate is an internal reference, not a fair-price oracle.**
- **Unaudited.** Non-standard ERC-20s (fee-on-transfer, rebasing) need separate testing.

## Security posture

Reviewed against Uniswap's own [`v4-security-foundations`](https://github.com/Uniswap/uniswap-ai)
guidance.

| Category | Knot |
|---|---|
| `beforeSwapReturnDelta` | **Enabled**. Required for a custom curve. Uniswap rates this flag CRITICAL, so it is the highest-scrutiny part of the design |
| Reentrancy | `nonReentrant` on federation state changes; no callbacks during a quote |
| Access control | Reserve mutation restricted to registered members; membership restricted to the owner |
| Rounding | Both quote directions round against the taker |
| Custody | Hook-owned. `PoolManager claims = active reserves + inactive provider assets` |

## No partner integrations

UHI10's sponsor is the Uniswap Foundation. This project integrates no third-party partner protocols.

## Docs

| File | Contents |
|---|---|
| [`docs/MECHANISM.md`](docs/MECHANISM.md) | The rule, worked through with numbers |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Contracts and how they connect |
| [`docs/TESTING.md`](docs/TESTING.md) | Test layout and what each layer proves |
| [`docs/DEMO.md`](docs/DEMO.md) | Attacker-sequence walkthrough |
| [`research/mev-findings.md`](research/mev-findings.md) | Adversarial results in full, including the coalition number |
| [`SECURITY.md`](SECURITY.md) | Enforced properties and known limits |
