import { describe, expect, it } from "vitest";
import manifest from "../../../deployments/unichain-sepolia.json";
import { assertDeploymentManifest, DEPLOYMENT } from "./deployment";

const copy = () => JSON.parse(JSON.stringify(manifest)) as Record<string, unknown>;
const proofTransactions = {
  deploy: `0x${"01".repeat(32)}`,
  activate: `0x${"02".repeat(32)}`,
  routerExactInputZeroForOne: `0x${"03".repeat(32)}`,
  routerExactInputOneForZero: `0x${"04".repeat(32)}`,
  routerExactOutputZeroForOne: `0x${"05".repeat(32)}`,
  routerExactOutputOneForZero: `0x${"06".repeat(32)}`,
};

const pendingCopy = () => {
  const candidate = copy();
  candidate.status = "pending";
  for (const key of ["deployedAtBlock", "contracts", "currencies", "pools", "owner", "verification"]) {
    delete candidate[key];
  }
  return candidate;
};

const activeCopy = () => {
  const candidate = copy();
  candidate.status = "active";
  candidate.deployedAtBlock = 1;
  candidate.contracts = {
    federation: "0x0000000000000000000000000000000000000004",
    deep: "0x0000000000000000000000000000000000002a88",
    shallow: "0x0000000000000000000000000000000000006a88",
  };
  candidate.currencies = {
    currency0: "0x0000000000000000000000000000000000000001",
    currency1: "0x0000000000000000000000000000000000000002",
  };
  candidate.pools = {
    deep: `0x${"11".repeat(32)}`,
    shallow: `0x${"22".repeat(32)}`,
  };
  candidate.owner = "0x0000000000000000000000000000000000000003";
  candidate.verification = {
    verifiedAtBlock: 1,
    previewAmount: "5000000000000000000",
    deepQuote: ["1", "2", "1"],
    shallowQuote: ["3", "2", "2"],
    memberRuntimeCodehash: `0x${"ab".repeat(32)}`,
    memberReserves: {
      deep: ["1000", "1000"],
      shallow: ["100", "400"],
      aggregate: ["1100", "1400"],
    },
    custody: {
      deepClaims: ["1000", "1000"],
      shallowClaims: ["100", "400"],
      deepInactive: ["0", "0"],
      shallowInactive: ["0", "0"],
    },
    sourceVerification: {
      provider: "Sourcify",
      match: "exact_match",
      matchIds: {
        federation: "1",
        deep: "2",
        shallow: "3",
        currency0: "4",
        currency1: "5",
      },
    },
    transactions: { ...proofTransactions },
  };
  return candidate;
};

const proof = (candidate: Record<string, unknown>) => candidate.verification as Record<string, unknown>;

describe("deployment manifest", () => {
  it("accepts the repository's canonical manifest", () => {
    expect(() => assertDeploymentManifest(manifest)).not.toThrow();
    expect(DEPLOYMENT.chain.id).toBe(1301);
    expect(DEPLOYMENT.status).toBe("active");
    expect("contracts" in DEPLOYMENT).toBe(true);
  });

  it("rejects malformed addresses before a build can publish them", () => {
    const candidate = activeCopy();
    (candidate.contracts as Record<string, unknown>).federation = "0x1234";
    expect(() => assertDeploymentManifest(candidate)).toThrow(/federation is not an address/);
  });

  it("rejects a manifest for a different chain", () => {
    const candidate = copy();
    (candidate.chain as Record<string, unknown>).id = 84532;
    expect(() => assertDeploymentManifest(candidate)).toThrow(/Unichain Sepolia/);
  });

  it("rejects a non-canonical PoolManager", () => {
    const candidate = copy();
    (candidate.dependencies as Record<string, unknown>).poolManager = "0x0000000000000000000000000000000000000004";
    expect(() => assertDeploymentManifest(candidate)).toThrow(/official Unichain Sepolia/);
  });

  it("rejects hook addresses whose low bits disagree with the declared permissions", () => {
    const candidate = activeCopy();
    (candidate.contracts as Record<string, unknown>).deep = "0x0000000000000000000000000000000000002a89";
    expect(() => assertDeploymentManifest(candidate)).toThrow(/permission bits/);
  });

  it("rejects impossible fee parameters", () => {
    const candidate = copy();
    (candidate.parameters as Record<string, unknown>).feeNumerator = 1001;
    expect(() => assertDeploymentManifest(candidate)).toThrow(/numerator exceeds denominator/);
  });

  it("requires proof metadata before an active deployment can be published", () => {
    const candidate = pendingCopy();
    candidate.status = "active";
    expect(() => assertDeploymentManifest(candidate)).toThrow(/deployedAtBlock/);
  });

  it("rejects stale release fields while deployment is pending", () => {
    const candidate = pendingCopy();
    candidate.contracts = { federation: "0x0000000000000000000000000000000000000004" };
    expect(() => assertDeploymentManifest(candidate)).toThrow(/cannot carry stale release data/);
  });

  it("accepts a complete active deployment proof", () => {
    const candidate = activeCopy();
    expect(() => assertDeploymentManifest(candidate)).not.toThrow();
  });

  it("rejects an active manifest whose aggregate snapshot does not equal its members", () => {
    const candidate = activeCopy();
    (proof(candidate).memberReserves as Record<string, unknown>).aggregate = ["1099", "1400"];
    expect(() => assertDeploymentManifest(candidate)).toThrow(/aggregate reserves/);
  });

  it("rejects a custody snapshot that does not back the recorded reserves", () => {
    const candidate = activeCopy();
    (proof(candidate).custody as Record<string, unknown>).shallowClaims = ["99", "400"];
    expect(() => assertDeploymentManifest(candidate)).toThrow(/shallow PoolManager claims/);
  });

  it("rejects malformed transaction proof", () => {
    const candidate = activeCopy();
    (proof(candidate).transactions as Record<string, unknown>).swap = "0x1234";
    expect(() => assertDeploymentManifest(candidate)).toThrow(/transaction hash/);
  });

  it("rejects an active manifest without all four Universal Router branches", () => {
    const candidate = activeCopy();
    delete (proof(candidate).transactions as Record<string, unknown>).routerExactOutputOneForZero;
    expect(() => assertDeploymentManifest(candidate)).toThrow(/missing required proof transaction/);
  });

  it("rejects proof metadata whose enforced quote is not the stated boundary", () => {
    const candidate = activeCopy();
    proof(candidate).deepQuote = ["1", "2", "2"];
    expect(() => assertDeploymentManifest(candidate)).toThrow(/deep control quote/);
  });

  it("rejects reused transaction hashes", () => {
    const candidate = activeCopy();
    (proof(candidate).transactions as Record<string, unknown>).activate = proofTransactions.deploy;
    expect(() => assertDeploymentManifest(candidate)).toThrow(/must be distinct/);
  });

  it("accepts an active manifest with no faucet recorded", () => {
    const candidate = activeCopy();
    delete candidate.faucet;
    expect("faucet" in candidate).toBe(false);
    expect(() => assertDeploymentManifest(candidate)).not.toThrow();
  });

  it("accepts a recorded faucet with a positive drip and cooldown", () => {
    const candidate = activeCopy();
    candidate.faucet = {
      address: "0x0000000000000000000000000000000000000005",
      dripAmount: "100000000000000000000",
      cooldownSeconds: 28800,
    };
    expect(() => assertDeploymentManifest(candidate)).not.toThrow();
  });

  it("rejects a faucet with a malformed address", () => {
    const candidate = activeCopy();
    candidate.faucet = {
      address: "0x1234",
      dripAmount: "100000000000000000000",
      cooldownSeconds: 28800,
    };
    expect(() => assertDeploymentManifest(candidate)).toThrow(/faucet.*address/);
  });

  it("rejects a faucet with a zero drip amount", () => {
    const candidate = activeCopy();
    candidate.faucet = {
      address: "0x0000000000000000000000000000000000000005",
      dripAmount: "0",
      cooldownSeconds: 28800,
    };
    expect(() => assertDeploymentManifest(candidate)).toThrow(/faucet\.dripAmount/);
  });

  it("rejects faucet data while deployment is pending", () => {
    const candidate = pendingCopy();
    candidate.faucet = { address: "0x0000000000000000000000000000000000000005" };
    expect(() => assertDeploymentManifest(candidate)).toThrow(/cannot carry stale release data/);
  });
});
