# Unichain Sepolia, 23 August 2026

Chain 1301 · PoolManager `0x00b036b58a818b1bc34d502d3fe730db729e62ac`

## Addresses

| Contract | Address |
| --- | --- |
| `KnotFederation` | [`0x91A0489A1BEA8030AC82351D52BDC3F97d6cA129`](https://sepolia.uniscan.xyz/address/0x91A0489A1BEA8030AC82351D52BDC3F97d6cA129) |
| `KnotHook` deep | [`0x346930bcf767614a6C4654904739cBCF4A8f6A88`](https://sepolia.uniscan.xyz/address/0x346930bcf767614a6C4654904739cBCF4A8f6A88) |
| `KnotHook` shallow | [`0x6B8D77a921Adc5244bC0398fa6133841F3DFaA88`](https://sepolia.uniscan.xyz/address/0x6B8D77a921Adc5244bC0398fa6133841F3DFaA88) |

Both hook addresses were mined with `HookMiner` so their low bits carry the required permission
flags. Federation owner: `0x35d8E75295366e6A12B988084096d89233dF4e9C`.

## Seeded state

| Pool | reserve0 | reserve1 |
| --- | --- | --- |
| Deep | 1,000 | 1,000 |
| Shallow | 100 | 400 |
| **Aggregate** | **1,100** | **1,400** |

The asymmetry is deliberate. With balanced members the aggregate matches the local reserves and
the bound never binds, so a symmetric deployment would demonstrate nothing.

## The bound, verified on-chain

```bash
cast call 0x91A0489A1BEA8030AC82351D52BDC3F97d6cA129 \
  "preview(address,bool,bool,uint256)(uint256,uint256,uint256)" \
  0x6B8D77a921Adc5244bC0398fa6133841F3DFaA88 true true 5000000000000000000 \
  --rpc-url https://sepolia.unichain.org
```

**Shallow pool**, 5 tokens in. The bound binds:

| | |
| --- | --- |
| Local quote | 18.993189503262370814 |
| Aggregate quote | 6.315922840581546355 |
| **Enforced** | **6.315922840581546355** |
| **Withheld, kept with LPs** | **12.677, 6,674 bps** |

**Deep pool**, same size. The bound is inert, as designed:

| | |
| --- | --- |
| Local quote | 4.960273038901078125 |
| Aggregate quote | 6.315922840581546355 |
| **Enforced** | **4.960273038901078125** |

A pool in line with its pair keeps its own quote. The contrast between the two pools is the
demonstration.

The 6,674 bps figure matches `MEVProtectionTest` exactly, so the deployed contracts reproduce the
suite to the wei.

## Cost

0.0000065 ETH total across both phases.
