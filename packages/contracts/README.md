# KNOT contracts

This workspace contains the KNOT custom-accounting hook, its reserve federation, deployment
contracts, and the complete Foundry verification suite.

## Layout

```text
src/
├── core/          authenticated federation and aggregate reserve book
├── hooks/         per-member custom-accounting hook and LP lifecycle
└── libraries/     fee-aware constant-product quote math
script/
├── deploy/        deterministic two-phase deployment contracts
├── local/         disposable local-chain lifecycle
└── verify/        owner-run public lifecycle verification
test/
├── unit/          math and economic properties
├── integration/   PoolManager, custody, token and multi-member seams
├── security/      adversarial and coalition scenarios
├── invariant/     stateful reserve, custody and membership properties
├── benchmark/     gas comparison
└── fixtures/      shared test infrastructure
```

## Commands

Run from the repository root:

```bash
npm run check --workspace @knot/contracts
npm run test --workspace @knot/contracts
npm run test:security --workspace @knot/contracts
npm run test:invariant --workspace @knot/contracts
npm run test:coverage
```

The public security boundary is defined in the root [SECURITY.md](../../SECURITY.md). Network
broadcast procedure and wallet handling remain in the private root `AGENTS.md` handoff.
