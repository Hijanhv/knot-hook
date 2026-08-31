# Deploying the Knot demo

Two phases, because deposits must mature before they enter the shared book.

## Target networks

| Network | Chain ID | PoolManager | RPC |
| --- | --- | --- | --- |
| **Unichain Sepolia** (default) | 1301 | `0x00b036b58a818b1bc34d502d3fe730db729e62ac` | `https://sepolia.unichain.org` |
| Base Sepolia | 84532 | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` | `https://sepolia.base.org` |

Addresses from [Uniswap's deployment registry](https://docs.uniswap.org/contracts/v4/deployments).

## Before you start

**Import your deployer key into an encrypted keystore.** This repository is public, and a raw
key in a file is one `git add -A` away from permanent exposure. Foundry keeps the key encrypted
at rest and asks for a password at broadcast time.

```bash
cast wallet import uhi-deploy --interactive   # paste the private key, set a password
cast wallet list                              # confirm it is there
```

Every command below passes `--account uhi-deploy`. Never `--private-key`.

**Funding.** A full deployment costs well under 0.05 ETH. Unichain Sepolia ETH comes from
bridging Sepolia ETH at [bridge.unichain.org](https://bridge.unichain.org), which is more reliable than
the direct faucets, which are usually rate-limited.

```bash
cp .env.example .env   # POOL_MANAGER and RPC_URL only; leave PRIVATE_KEY empty
source .env
cast balance $(cast wallet address --account uhi-deploy) --rpc-url $RPC_URL --ether
```

## Phase one: deploy and queue liquidity

```bash
forge script script/DeployDemo.s.sol:DeployDemo \
  --rpc-url $RPC_URL --account uhi-deploy --sender $(cast wallet address --account uhi-deploy) \
  --broadcast -vvv
```

This deploys two demo ERC-20s, the federation, and **two** hook instances mined to
flag-valid addresses, then initialises both pools and queues liquidity: the deep pool
balanced at 1000/1000, the shallow pool skewed at 100/400.

<b>Two members is not optional.</b> With one member the aggregate reserves are the local
reserves, `min(local, aggregate)` is always the local quote, and the bound never binds. A
single-hook deployment demonstrates nothing.

The script prints the three addresses. Put them in `.env` as `DEEP_POOL` and `SHALLOW_POOL`.

## Phase two: activate

Wait one block, then:

```bash
source .env
forge script script/DeployDemo.s.sol:Activate \
  --rpc-url $RPC_URL --account uhi-deploy --sender $(cast wallet address --account uhi-deploy) \
  --broadcast -vvv
```

It prints both reserve pairs. Once the shallow pool reads 100/400, the bound is live.

## Point the frontend at it

```bash
cd frontend
cat > .env.local <<'ENV'
NEXT_PUBLIC_FEDERATION=0x...
NEXT_PUBLIC_DEEP_POOL=0x...
NEXT_PUBLIC_SHALLOW_POOL=0x...
NEXT_PUBLIC_CHAIN_ID=1301
ENV
npm run dev
```

## Verify it is live

```bash
cast call $NEXT_PUBLIC_FEDERATION \
  "preview(address,bool,bool,uint256)(uint256,uint256,uint256)" \
  $SHALLOW_POOL true true 5000000000000000000 \
  --rpc-url $RPC_URL
```

Three numbers: local quote, aggregate quote, enforced quote. On the shallow pool the third
should equal the second and sit well below the first. That gap is the value staying with LPs.

## Record the deployment

Copy the addresses, chain and date into `deployments/`, following the format prior winners
used. A dated record is worth more to a judge than an address pasted in a README.
