<p align="center">
  <img src="assets/readme/banner.svg" alt="KNOT: one token pair, several pools, one price boundary" width="100%">
</p>

<p align="center">
  <a href="https://youtu.be/meiTAZnvS1w">demo video</a> ·
  <a href="https://youtu.be/c9qJY4lcO0Q">pitch video</a> ·
  <b><a href="https://knot-hook-web.vercel.app/">App</a></b> ·
  <b><a href="https://knot-38d8bd0e.mintlify.app">Documentation</a></b> ·
  <a href="https://knot-38d8bd0e.mintlify.app/mechanism/before-knot">Before KNOT</a> ·
  <a href="https://knot-38d8bd0e.mintlify.app/reference/architecture">Architecture</a> ·
  <a href="https://knot-38d8bd0e.mintlify.app/security/testing">Verification</a> ·
  <a href="assets/pitch/knot-pitch-deck.pdf">Pitch deck</a> ·
  <a href="#see-it-on-chain">On-chain proof</a> ·
  <a href="SECURITY.md">Security boundaries</a>
</p>

**UHI10 Hookathon · Sustainable Liquidity & MEV Protection**

**Project ID: `HK-UHI10-1087`**

> When the same token pair is split across several pools, one shallow or skewed pool can quote
> far beyond the price implied by the participating liquidity as a whole. KNOT gives those pools
> one shared, deterministic price boundary without pooling their custody or LP ownership.

[![Uniswap v4](https://img.shields.io/badge/Uniswap-v4%20hook-FF007A.svg?logo=uniswap)](https://docs.uniswap.org/contracts/v4/overview)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636.svg?logo=solidity)](https://soliditylang.org/)
[![Tests](https://img.shields.io/badge/Foundry-204%20passing-3FB950.svg)](#verification)
[![Coverage](https://img.shields.io/badge/line%20coverage-99.32%25-3FB950.svg)](#verification)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> KNOT is unaudited hackathon software. Its experiments measure a bounded quote rule in constructed
> scenarios; they do not prove universal MEV protection or realised LP profit.

## Partner integrations

No partner integrations.

## Try it

The pools are live and anyone can trade against them.

1. Open the [app](https://knot-hook-web.vercel.app/app/) and connect a wallet on Unichain Sepolia.
2. Claim 100 kETH and 100 kUSD from the demo faucet. Gas is paid in Unichain Sepolia ETH, which
   public faucets supply.
3. Approve the token, then approve the router through Permit2. Both are one-time.
4. Swap. The quote on screen is the limit the swap is submitted with, so it settles at the
   enforced bound or it reverts.

Choose the shallow pool to watch the boundary bind, or the deep pool to watch it stay inert
because that pool's own curve is already the more conservative of the two.

## See it on-chain

Every swap below ran through the deployed hook on **Unichain Sepolia** against the canonical
Uniswap v4 PoolManager. Click a hash to open it in the explorer.

| Swap through the hook | Transaction |
| --- | --- |
| Exact input · token0 → token1 | [`0xe5c64d7c…c50df5`](https://sepolia.uniscan.xyz/tx/0xe5c64d7c64086b9c8a56c0f64d70f0cc1c7a517e812770b65df406c550c50df5) |
| Exact input · token1 → token0 | [`0xffe5985a…c26ac3`](https://sepolia.uniscan.xyz/tx/0xffe5985a4e9597539af1baf01063668d35711ab61856f6aeec3403a71ec26ac3) |
| Exact output · token0 → token1 | [`0xf712456b…3c3890`](https://sepolia.uniscan.xyz/tx/0xf712456bd2b7ed6a7a24356e78cc1654197d24414d85cddd202dd6833d3c3890) |
| Exact output · token1 → token0 | [`0xa8a97a2d…253d93`](https://sepolia.uniscan.xyz/tx/0xa8a97a2da390ed9b4928111012ac4f7c591e58fbb60bba9bf7c2f6c334253d93) |

| Contract | Address |
| --- | --- |
| KnotFederation | [`0x49579383965f68079FB671b1d7AF0071cf206199`](https://sepolia.uniscan.xyz/address/0x49579383965f68079FB671b1d7AF0071cf206199) |
| KnotHook · deep | [`0x55c73752E38403DDd30d03039568A5090256aa88`](https://sepolia.uniscan.xyz/address/0x55c73752E38403DDd30d03039568A5090256aa88) |
| KnotHook · shallow | [`0x1c828fA6d4232E80aaeCEb143736092b0F822A88`](https://sepolia.uniscan.xyz/address/0x1c828fA6d4232E80aaeCEb143736092b0F822A88) |
| kETH · currency0 | [`0x0784b9D734f2a6d13209087964640B1aD7699AAe`](https://sepolia.uniscan.xyz/address/0x0784b9D734f2a6d13209087964640B1aD7699AAe) |
| kUSD · currency1 | [`0x243B3f2672Bdd36b63cA960AE201ECDDA4a7b83e`](https://sepolia.uniscan.xyz/address/0x243B3f2672Bdd36b63cA960AE201ECDDA4a7b83e) |

### Demo faucet

The demo currencies minted their whole supply to the deployer, so a fresh wallet holds nothing
to swap with. [`KnotFaucet.sol`](packages/contracts/src/periphery/KnotFaucet.sol) fixes that: it
holds a funded balance of both currencies and pays a fixed drip per address behind a cooldown.
It never mints, so its exposure is capped by its funding, and it reverts loudly when drained.
It sits outside the hook trust boundary.

Status: **deployed** at
[`0xd9BdcF978669eCa41A6Fd44771AF95C7327f379b`](https://sepolia.uniscan.xyz/address/0xd9BdcF978669eCa41A6Fd44771AF95C7327f379b),
funded with 100,000 of each currency for 1,000 claims of 100 each behind an 8-hour
cooldown. Deployment:
[`0x864ab92d…b72f`](https://sepolia.uniscan.xyz/tx/0x864ab92d7b2a2c5a4b1d73664d81fa0c77ac0136ac4d80def90ea0b047b1b72f).
The app's claim button reads the recorded `faucet` entry in
`deployments/unichain-sepolia.json`; the manifest validator and the contracts page both
understand that field.

To deploy it from the wallet holding the demo currencies:

```bash
cd packages/contracts
CURRENCY0=0x0784b9D734f2a6d13209087964640B1aD7699AAe \
CURRENCY1=0x243B3f2672Bdd36b63cA960AE201ECDDA4a7b83e \
PRIVATE_KEY=<deployer-key> \
forge script script/deploy/DeployFaucet.s.sol:DeployFaucet \
  --rpc-url https://sepolia.unichain.org --broadcast
```

Then record the logged `KNOT_FAUCET` address in the manifest. Defaults pay 100 of each
currency per claim with an 8-hour cooldown per address.

<details>
<summary>Deployment and setup transactions</summary>

| Step | Transaction |
| --- | --- |
| Federation deployed | [`0x3e69ab06…d5a91c`](https://sepolia.uniscan.xyz/tx/0x3e69ab0612e71a10939357032a4cc35317027e8ef1031989b25a0ef04ed5a91c) |
| Deep hook deployed | [`0xc22a5c0e…ce9439`](https://sepolia.uniscan.xyz/tx/0xc22a5c0e59efe04a40daa084fdb9ad24436cacf1b8016f6af1121e96edce9439) |
| Shallow hook deployed | [`0x176b66cd…516e1a`](https://sepolia.uniscan.xyz/tx/0x176b66cdda8e326ffe73df280da0777ca228a4baa72fdd30a13a6925ba516e1a) |
| Deep member registered | [`0xa423e8fb…19f024`](https://sepolia.uniscan.xyz/tx/0xa423e8fb197836df9a74cceae27609c0f40bfc934faee20cfe3eafa9c719f024) |
| Shallow member registered | [`0x2a456f86…22188d`](https://sepolia.uniscan.xyz/tx/0x2a456f86de7c37eca905f6352455dcb2da5ac52fec84198706daa774cf22188d) |
| Deep pool initialized | [`0xefdd72e8…ff2c2c`](https://sepolia.uniscan.xyz/tx/0xefdd72e8ee666916daaf1108e42dfe2a12604e58cffd72deeafbed2490ff2c2c) |
| Shallow pool initialized | [`0xb9f3601e…27102e`](https://sepolia.uniscan.xyz/tx/0xb9f3601eab0a3cab06e15445efc2f9d00977e084d3aed244913fbd6c3e27102e) |
| Deep liquidity queued | [`0x2de56b1d…fff904`](https://sepolia.uniscan.xyz/tx/0x2de56b1de661e36a1597e446c4a0651d25c2c87416c37b9aee2d1ecea1fff904) |
| Shallow liquidity queued | [`0x38a7c3cc…94f918`](https://sepolia.uniscan.xyz/tx/0x38a7c3cc1c1aaa7c74e73e07eb5cb6f2d69a65c2b9b6e94f2b4256bb0094f918) |
| Deep liquidity activated | [`0xe384ac6f…95aec2`](https://sepolia.uniscan.xyz/tx/0xe384ac6ff1ddb27a59c9fb40203d74b0463906fdceb5faf4f90617e3df95aec2) |
| Shallow liquidity activated | [`0xad3ac152…4bd8d6`](https://sepolia.uniscan.xyz/tx/0xad3ac1522a99eba1ff22f5598f35f97ef9f3ed677687f47caafbdb4d864bd8d6) |
| kETH deployed | [`0x7dc6666c…60b52b`](https://sepolia.uniscan.xyz/tx/0x7dc6666c6440236a1aa2a6bd2a02ff83b035063b3dd9544cf138b29ac760b52b) |
| kUSD deployed | [`0x5627a491…062b2b`](https://sepolia.uniscan.xyz/tx/0x5627a491ea97fe41d12ab21276a731177de0809e9860c38d1d2820efb6062b2b) |

</details>

## The idea in one minute

Every participating pool keeps its own reserves, LP shares and fees. A shared federation stores
an authenticated reserve book for the same token pair and maintains the sum of all member reserves
in constant time.

Before each swap, KNOT computes two constant-product quotes:

1. the quote from that pool's local reserves;
2. the quote from the federation's aggregate reserves.

The trader receives the less favourable result:

$$
\text{exact input output} = \min(\text{local output}, \text{aggregate output})
$$

$$
\text{exact output input} = \max(\text{local input}, \text{aggregate input})
$$

If the local pool already offers the less favourable price, KNOT changes nothing. If the local
pool offers the better price, the difference is never paid out and remains in that pool's
reserves. No oracle, keeper, auction or off-chain classifier participates in the decision.

## A concrete example

The canonical test fixture has two member pools:

| Member | token0 | token1 | Purpose |
| --- | ---: | ---: | --- |
| Deep | 1,000 | 1,000 | Balanced control |
| Shallow | 100 | 400 | Deliberately skewed member |
| Aggregate | 1,100 | 1,400 | Virtual federation curve |

For a 5-token exact-input trade through the shallow member:

| Quote | Output |
| --- | ---: |
| Shallow pool alone | 18.993189 |
| Federation aggregate | 6.315922 |
| KNOT-enforced output | **6.315922** |

The bound reduces the isolated quote by **6,674 bps** in this fixture. In the balanced deep member,
the local quote is already more conservative and the bound is inert. The example proves the
selection rule, not that reserve divergence is inherently toxic.

## Why this belongs in a Uniswap v4 hook

A router-only rule can be bypassed by using another router. KNOT enforces the boundary inside
each participating pool:

| v4 primitive | KNOT use |
| --- | --- |
| Hook permissions | Intercept initialization, swaps and liquidity modification |
| Before-swap return delta | Replace the pool's normal quote with the bounded custom-accounting result |
| PoolManager unlock accounting | Settle input and output atomically |
| ERC-6909 claims | Back active reserves, pending deposits and refunds inside PoolManager custody |
| Dynamic fee flag | Keep the constant-product fee inside KNOT's quote instead of charging twice |

The hook returns no external oracle price. It executes a deterministic reserve policy against
the same call that updates both the local and aggregate books.

## Architecture

```mermaid
flowchart LR
    T[Trader] -->|swap| PM[Uniswap v4 PoolManager]
    PM -->|beforeSwap| HA[KnotHook A]
    PM -->|beforeSwap| HB[KnotHook B]
    HA -->|authenticated update| F[KnotFederation]
    HB -->|authenticated update| F
    F -->|local + aggregate quote| HA
    F -->|local + aggregate quote| HB
    HA <-->|claims and settlement| PM
    HB <-->|claims and settlement| PM
```

- [`KnotHook.sol`](packages/contracts/src/hooks/KnotHook.sol) owns one member's custom-accounting
  reserves, LP shares, pending liquidity and PoolManager claims.
- [`KnotFederation.sol`](packages/contracts/src/core/KnotFederation.sol) authenticates members,
  maintains per-member books and updates the O(1) aggregate.
- [`KnotMath.sol`](packages/contracts/src/libraries/KnotMath.sol) implements fee-aware exact-input
  and exact-output quotes with rounding against the taker.

The federation never custodies tokens. It is the shared accounting authority; each hook remains
the custody and LP boundary for its own pool.

## Liquidity lifecycle

New capital cannot enter the quote and immediately leave:

1. **Queue:** the hook takes the assets but excludes them from active reserves.
2. **Mature:** the request waits an immutable number of blocks.
3. **Activate:** shares mint at the current reserve ratio, not the earlier deposit ratio.
4. **Exit lock:** newly activated shares wait through a second maturity window before transfer
   or withdrawal.
5. **Cancel or claim:** only the provider can cancel a pending request or claim unused assets.

Pending capital never blocks swaps, active withdrawals, other deposits or removal of an empty
member. The custody identity is:

```text
PoolManager claims = active reserves + inactive provider assets + provider refunds
```

## Unichain Sepolia deployment

KNOT is live on **Unichain Sepolia (chain 1301)** against the canonical Uniswap v4
[PoolManager](https://sepolia.uniscan.xyz/address/0x00b036b58a818b1bc34d502d3fe730db729e62ac).
The release began at block `61583973`; its two members were activated after the configured
one-block maturity window and then exercised through the deployed Universal Router in all four
single-hop modes.

| Component | Address |
| --- | --- |
| KnotFederation | [`0x49579383965f68079FB671b1d7AF0071cf206199`](https://sepolia.uniscan.xyz/address/0x49579383965f68079FB671b1d7AF0071cf206199) |
| KnotHook · deep | [`0x55c73752E38403DDd30d03039568A5090256aa88`](https://sepolia.uniscan.xyz/address/0x55c73752E38403DDd30d03039568A5090256aa88) |
| KnotHook · shallow | [`0x1c828fA6d4232E80aaeCEb143736092b0F822A88`](https://sepolia.uniscan.xyz/address/0x1c828fA6d4232E80aaeCEb143736092b0F822A88) |
| kETH · currency0 | [`0x0784b9D734f2a6d13209087964640B1aD7699AAe`](https://sepolia.uniscan.xyz/address/0x0784b9D734f2a6d13209087964640B1aD7699AAe) |
| kUSD · currency1 | [`0x243B3f2672Bdd36b63cA960AE201ECDDA4a7b83e`](https://sepolia.uniscan.xyz/address/0x243B3f2672Bdd36b63cA960AE201ECDDA4a7b83e) |

| Pool | Pool ID |
| --- | --- |
| Deep | `0xa37acc9c7b38bddba8dd58392ef174e031308d7d674250d3ac96ca5b668b6ce4` |
| Shallow | `0xfd1361ff40dcbffa9fbf20ab5dc741b0378f74cfb55c0d9519322126fe8b6d71` |

The public proof transactions are linked in the canonical
[`unichain-sepolia.json`](deployments/unichain-sepolia.json) manifest. That manifest also records
the runtime code hash, post-proof reserve snapshot, quote outputs, PoolManager claim backing, and
each deployment, registration, initialization, activation, and router transaction hash. The web
app refuses to build an active release if any required proof field is missing or inconsistent.
The federation, both hooks, and both test tokens are exact creation- and runtime-bytecode matches
on Sourcify.

## Quick start

Prerequisites: Node.js 22+, npm 10+ and Foundry.

```bash
git clone https://github.com/Hijanhv/knot-hook.git
cd knot-hook
npm install
npm run check
npm test
npm run dev
```

Open `http://localhost:3000`. The quote inspector reads the live federation on Unichain Sepolia;
if the public RPC is unavailable, it switches to the deterministic fixture and labels that data
as a reference calculation.

Run focused contract suites from the workspace root:

```bash
npm run test:unit --workspace @knot/contracts
npm run test:integration --workspace @knot/contracts
npm run test:security --workspace @knot/contracts
npm run test:invariant --workspace @knot/contracts
npm run test:coverage
```

Run the full transaction lifecycle on a disposable Anvil chain:

```bash
cd packages/contracts
anvil --port 8550 --chain-id 31337 --block-time 1 --gas-limit 200000000 --silent &
knot_anvil_pid=$!
trap 'kill "$knot_anvil_pid"' EXIT

forge script script/local/LocalE2E.s.sol:LocalE2E \
  --rpc-url http://127.0.0.1:8550 \
  --unlocked \
  --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 \
  --broadcast \
  --slow
```

Success ends with `LOCAL_E2E_OK` after two members deploy and seed, all four swap branches execute,
pending liquidity activates and refunds, LP shares withdraw, and every reserve/custody identity is
checked again.

## Verification

`forge test` runs **204 passing cases across 20 suites**. The KNOT source reports **99.32% line,
96.95% statement, 84.62% branch and 100% function coverage**.

| Area | Evidence |
| --- | --- |
| Quote math | Independent integer oracle, both directions, both swap modes, rounding and boundary values |
| Hook integration | Canonical v4 PoolManager execution, settlement rollback, native ETH and custody identities |
| Federation safety | Authentication, code identity, membership churn, aggregate equality and atomic multi-member batches |
| Liquidity safety | Pending isolation, maturity boundaries, activation ratio, refund ownership and exit lock |
| Adversarial behavior | Sandwiches, backruns, slicing, cycles, donation, JIT liquidity, buddy pools and coalition influence |
| Stateful checks | Five high-depth invariant properties and 163,840 calls with zero handler reverts |
| Runtime | 13,801-byte hook, leaving 10,775 bytes below EIP-170 |
| Gas | 41,458-gas hook overhead against the matching hookless v4 fixture |

Detailed suite ownership is in the public [testing guide](apps/docs/security/testing.mdx); the
bounded economic results and methodology are summarized in [the results guide](apps/docs/security/results.mdx).

## Results that constrain the claim

The tests deliberately preserve results that are inconvenient but important:

- a balanced same-member sandwich remains profitable at about **0.393701 token0** with KNOT,
  compared with **1.803279 token0** in the hookless fixture;
- a coalition-controlled member can loosen the aggregate boundary by **4,722 bps** in the
  constructed capital-bounded scenario;
- pools outside the federation bypass the boundary;
- corrective flow can be clipped because KNOT selects quote direction, not trader intent;
- the aggregate curve is a virtual policy boundary, not a fair-price oracle or executable
  cross-pool route.

KNOT is therefore a deterministic reserve-aware boundary for participating pools—not universal
MEV prevention.

## Repository map

```text
knot-hook/
├── apps/
│   ├── web/                       Next.js product and quote inspector
│   └── docs/                      Mintlify documentation
├── packages/
│   └── contracts/
│       ├── src/{core,hooks,libraries}/
│       ├── script/{deploy,local,verify}/
│       ├── test/{unit,integration,security,invariant,benchmark,fixtures}/
│       └── lib/                   Pinned contract dependencies
├── docs/
│   ├── protocol/                  Design and mechanism notes
│   ├── assurance/                 Verification guide
│   ├── research/                  Economic methodology and results
│   └── submission/                Demo and form preparation
├── assets/readme/                 Repository visuals
├── SECURITY.md                    Trust assumptions and unsupported assets
└── package.json                   Workspace command surface
```

## Security boundaries

Supported now:

- one owner-approved federation for one canonically sorted pair;
- exact-input and exact-output swaps in both directions;
- conventional ERC-20 pairs and native ETH;
- bounded membership and two-stage LP maturity;
- custom accounting against the canonical v4 PoolManager.

Explicitly unsupported:

- fee-on-transfer, rebasing or callback-bearing ERC-20s;
- permissionless federation membership;
- unregistered pools, cross-pair or cross-chain strategies;
- an external fair-price guarantee;
- coalition-proof or universal MEV protection;
- production use without an independent audit.

Read [SECURITY.md](SECURITY.md) before changing hook permissions, membership, reserve accounting,
settlement or LP lifecycle logic.

## License

[MIT](LICENSE)
