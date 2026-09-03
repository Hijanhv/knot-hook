import rawManifest from "../../../deployments/unichain-sepolia.json";

export type Address = `0x${string}`;

type BaseManifest = {
  schemaVersion: 2;
  statusReason: string;
  chain: { id: number; name: string; rpc: string; explorer: string };
  dependencies: { poolManager: Address };
  hookPermissionBits: `0x${string}`;
  parameters: {
    feeNumerator: number;
    feeDenominator: number;
    maxMembers: number;
    liquidityMaturityBlocks: number;
  };
  seed: { deep: [string, string]; shallow: [string, string] };
};

export type PendingDeploymentManifest = BaseManifest & { status: "pending" };

export type ActiveDeploymentManifest = BaseManifest & {
  status: "active";
  deployedAtBlock: number;
  contracts: { federation: Address; deep: Address; shallow: Address };
  currencies: { currency0: Address; currency1: Address };
  pools: { deep: `0x${string}`; shallow: `0x${string}` };
  owner: Address;
  /** Demo faucet. Optional: absent until the faucet is deployed and recorded. */
  faucet?: { address: Address; dripAmount: string; cooldownSeconds: number };
  verification: {
    verifiedAtBlock: number;
    previewAmount: string;
    deepQuote: [string, string, string];
    shallowQuote: [string, string, string];
    memberRuntimeCodehash: `0x${string}`;
    memberReserves: {
      deep: [string, string];
      shallow: [string, string];
      aggregate: [string, string];
    };
    custody: {
      deepClaims: [string, string];
      shallowClaims: [string, string];
      deepInactive: [string, string];
      shallowInactive: [string, string];
    };
    sourceVerification: {
      provider: "Sourcify";
      match: "exact_match";
      matchIds: {
        federation: string;
        deep: string;
        shallow: string;
        currency0: string;
        currency1: string;
      };
    };
    transactions: Record<string, `0x${string}`>;
  };
};

export type DeploymentManifest = PendingDeploymentManifest | ActiveDeploymentManifest;

const addressPattern = /^0x[0-9a-fA-F]{40}$/;
const uintPattern = /^(0|[1-9][0-9]*)$/;
const transactionPattern = /^0x[0-9a-fA-F]{64}$/;
const expectedHookBits = 0x2a88n;
const unichainSepoliaChainId = 1301;
const unichainSepoliaPoolManager = "0x00b036b58a818b1bc34d502d3fe730db729e62ac";
const publicProofTransactions = [
  "deploy",
  "activate",
  "routerExactInputZeroForOne",
  "routerExactInputOneForZero",
  "routerExactOutputZeroForOne",
  "routerExactOutputOneForZero",
] as const;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

function requireRecord(parent: Record<string, unknown>, key: string) {
  const value = parent[key];
  if (!isRecord(value)) throw new Error(`Deployment manifest: ${key} must be an object`);
  return value;
}

function requireString(parent: Record<string, unknown>, key: string) {
  const value = parent[key];
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Deployment manifest: ${key} must be a non-empty string`);
  }
  return value;
}

function requirePositiveInteger(parent: Record<string, unknown>, key: string) {
  const value = parent[key];
  if (!Number.isSafeInteger(value) || (value as number) <= 0) {
    throw new Error(`Deployment manifest: ${key} must be a positive safe integer`);
  }
  return value as number;
}

function requireAddress(parent: Record<string, unknown>, key: string, scope?: string) {
  const value = requireString(parent, key);
  if (!addressPattern.test(value)) {
    throw new Error(`Deployment manifest: ${scope ? `${scope}.` : ""}${key} is not an address`);
  }
  return value as Address;
}

function requireBytes32(parent: Record<string, unknown>, key: string) {
  const value = requireString(parent, key);
  if (!transactionPattern.test(value)) throw new Error(`Deployment manifest: ${key} must be bytes32`);
  return value as `0x${string}`;
}

function requireReservePair(parent: Record<string, unknown>, key: string) {
  const value = parent[key];
  if (!Array.isArray(value) || value.length !== 2 || value.some((item) => typeof item !== "string" || !uintPattern.test(item))) {
    throw new Error(`Deployment manifest: ${key} must contain two unsigned decimal strings`);
  }
}

function reservePair(parent: Record<string, unknown>, key: string): [string, string] {
  requireReservePair(parent, key);
  return parent[key] as [string, string];
}

/** Rejects incomplete release data before it can be published by the web build. */
export function assertDeploymentManifest(value: unknown): asserts value is DeploymentManifest {
  if (!isRecord(value)) throw new Error("Deployment manifest must be an object");
  if (value.schemaVersion !== 2) throw new Error("Deployment manifest: unsupported schemaVersion");
  if (value.status !== "pending" && value.status !== "active") {
    throw new Error("Deployment manifest: status must be pending or active");
  }
  requireString(value, "statusReason");

  const chain = requireRecord(value, "chain");
  if (requirePositiveInteger(chain, "id") !== unichainSepoliaChainId) {
    throw new Error("Deployment manifest: canonical chain must be Unichain Sepolia");
  }
  requireString(chain, "name");
  for (const field of ["rpc", "explorer"] as const) {
    const url = requireString(chain, field);
    if (!URL.canParse(url) || new URL(url).protocol !== "https:") {
      throw new Error(`Deployment manifest: chain.${field} must be an HTTPS URL`);
    }
  }

  const dependencies = requireRecord(value, "dependencies");
  if (requireAddress(dependencies, "poolManager").toLowerCase() !== unichainSepoliaPoolManager) {
    throw new Error("Deployment manifest: PoolManager is not the official Unichain Sepolia deployment");
  }

  const permissionBits = requireString(value, "hookPermissionBits");
  if (!/^0x[0-9a-fA-F]+$/.test(permissionBits) || BigInt(permissionBits) !== expectedHookBits) {
    throw new Error("Deployment manifest: hookPermissionBits do not match KnotHook callbacks");
  }

  const parameters = requireRecord(value, "parameters");
  const numerator = requirePositiveInteger(parameters, "feeNumerator");
  const denominator = requirePositiveInteger(parameters, "feeDenominator");
  if (numerator > denominator) throw new Error("Deployment manifest: fee numerator exceeds denominator");
  if (numerator !== 997 || denominator !== 1000) {
    throw new Error("Deployment manifest: canonical demo fee must be 997/1000");
  }
  if (requirePositiveInteger(parameters, "maxMembers") < 2) {
    throw new Error("Deployment manifest: canonical demo needs at least two member slots");
  }
  requirePositiveInteger(parameters, "liquidityMaturityBlocks");

  const seed = requireRecord(value, "seed");
  requireReservePair(seed, "deep");
  requireReservePair(seed, "shallow");

  if (value.status === "pending") {
    if ("contracts" in value || "verification" in value || "deployedAtBlock" in value || "faucet" in value) {
      throw new Error("Deployment manifest: pending state cannot carry stale release data");
    }
    return;
  }

  requirePositiveInteger(value, "deployedAtBlock");
  const contracts = requireRecord(value, "contracts");
  for (const field of ["federation", "deep", "shallow"] as const) requireAddress(contracts, field);
  if (new Set(Object.values(contracts)).size !== 3) {
    throw new Error("Deployment manifest: owned contract addresses must be distinct");
  }
  for (const field of ["deep", "shallow"] as const) {
    if ((BigInt(requireAddress(contracts, field)) & 0x3fffn) !== expectedHookBits) {
      throw new Error(`Deployment manifest: contracts.${field} does not carry the declared hook permission bits`);
    }
  }

  const currencies = requireRecord(value, "currencies");
  const currency0 = requireAddress(currencies, "currency0");
  const currency1 = requireAddress(currencies, "currency1");
  if (BigInt(currency0) >= BigInt(currency1)) {
    throw new Error("Deployment manifest: currencies must be canonically sorted");
  }
  const pools = requireRecord(value, "pools");
  const deepPool = requireBytes32(pools, "deep");
  const shallowPool = requireBytes32(pools, "shallow");
  if (deepPool === shallowPool) throw new Error("Deployment manifest: pool IDs must be distinct");
  requireAddress(value, "owner");

  if ("faucet" in value) {
    const faucet = requireRecord(value, "faucet");
    requireAddress(faucet, "address", "faucet");
    const dripAmount = requireString(faucet, "dripAmount");
    if (!uintPattern.test(dripAmount) || BigInt(dripAmount) === 0n) {
      throw new Error("Deployment manifest: faucet.dripAmount must be a positive decimal amount");
    }
    requirePositiveInteger(faucet, "cooldownSeconds");
  }

  const verification = requireRecord(value, "verification");
  requirePositiveInteger(verification, "verifiedAtBlock");
  const previewAmount = requireString(verification, "previewAmount");
  if (!uintPattern.test(previewAmount) || BigInt(previewAmount) === 0n) {
    throw new Error("Deployment manifest: previewAmount must be a positive decimal amount");
  }
  const parsedQuotes: Record<"deepQuote" | "shallowQuote", [bigint, bigint, bigint]> = {
    deepQuote: [0n, 0n, 0n],
    shallowQuote: [0n, 0n, 0n],
  };
  for (const field of ["deepQuote", "shallowQuote"] as const) {
    const quote = verification[field];
    if (!Array.isArray(quote) || quote.length !== 3 || quote.some((item) => typeof item !== "string" || !uintPattern.test(item))) {
      throw new Error(`Deployment manifest: verification.${field} must contain three unsigned decimal strings`);
    }
    parsedQuotes[field] = quote.map(BigInt) as [bigint, bigint, bigint];
  }
  const [deepLocal, deepAggregate, deepEnforced] = parsedQuotes.deepQuote;
  const [shallowLocal, shallowAggregate, shallowEnforced] = parsedQuotes.shallowQuote;
  if (deepEnforced !== deepLocal || deepLocal > deepAggregate) {
    throw new Error("Deployment manifest: deep control quote is not inert");
  }
  if (shallowLocal <= shallowAggregate || shallowEnforced !== shallowAggregate) {
    throw new Error("Deployment manifest: shallow demonstration quote does not bind");
  }
  const runtimeCodehash = requireString(verification, "memberRuntimeCodehash");
  if (!/^0x[0-9a-fA-F]{64}$/.test(runtimeCodehash) || BigInt(runtimeCodehash) === 0n) {
    throw new Error("Deployment manifest: memberRuntimeCodehash must be bytes32");
  }
  const memberReserves = requireRecord(verification, "memberReserves");
  const deep = reservePair(memberReserves, "deep");
  const shallow = reservePair(memberReserves, "shallow");
  const aggregate = reservePair(memberReserves, "aggregate");
  if ([...deep, ...shallow].some((reserve) => BigInt(reserve) === 0n)) {
    throw new Error("Deployment manifest: active member reserves must be non-zero");
  }
  if (
    BigInt(aggregate[0]) !== BigInt(deep[0]) + BigInt(shallow[0]) ||
    BigInt(aggregate[1]) !== BigInt(deep[1]) + BigInt(shallow[1])
  ) {
    throw new Error("Deployment manifest: aggregate reserves must equal both member reserve books");
  }
  const custody = requireRecord(verification, "custody");
  const deepClaims = reservePair(custody, "deepClaims");
  const shallowClaims = reservePair(custody, "shallowClaims");
  const deepInactive = reservePair(custody, "deepInactive");
  const shallowInactive = reservePair(custody, "shallowInactive");
  for (let index = 0; index < 2; index += 1) {
    if (BigInt(deepClaims[index]) !== BigInt(deep[index]) + BigInt(deepInactive[index])) {
      throw new Error("Deployment manifest: deep PoolManager claims do not back the recorded assets");
    }
    if (BigInt(shallowClaims[index]) !== BigInt(shallow[index]) + BigInt(shallowInactive[index])) {
      throw new Error("Deployment manifest: shallow PoolManager claims do not back the recorded assets");
    }
  }
  const sourceVerification = requireRecord(verification, "sourceVerification");
  if (requireString(sourceVerification, "provider") !== "Sourcify") {
    throw new Error("Deployment manifest: unsupported source verification provider");
  }
  if (requireString(sourceVerification, "match") !== "exact_match") {
    throw new Error("Deployment manifest: every release contract must be an exact source match");
  }
  const matchIds = requireRecord(sourceVerification, "matchIds");
  for (const field of ["federation", "deep", "shallow", "currency0", "currency1"] as const) {
    const matchId = requireString(matchIds, field);
    if (!uintPattern.test(matchId) || BigInt(matchId) === 0n) {
      throw new Error(`Deployment manifest: sourceVerification.matchIds.${field} must be a positive integer`);
    }
  }
  const transactions = requireRecord(verification, "transactions");
  for (const label of publicProofTransactions) {
    if (!(label in transactions)) throw new Error(`Deployment manifest: missing required proof transaction ${label}`);
  }
  for (const [label, transaction] of Object.entries(transactions)) {
    if (typeof transaction !== "string" || !transactionPattern.test(transaction)) {
      throw new Error(`Deployment manifest: verification.transactions.${label} is not a transaction hash`);
    }
  }
  if (new Set(Object.values(transactions)).size !== Object.keys(transactions).length) {
    throw new Error("Deployment manifest: proof transaction hashes must be distinct");
  }
}

const candidate: unknown = rawManifest;
assertDeploymentManifest(candidate);

export const DEPLOYMENT = candidate;
export const DEPLOYMENT_IS_ACTIVE = DEPLOYMENT.status === "active";
export const ACTIVE_DEPLOYMENT: ActiveDeploymentManifest | null = DEPLOYMENT.status === "active" ? DEPLOYMENT : null;
