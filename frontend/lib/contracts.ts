export const CHAIN = { name: "Unichain Sepolia", id: 1301, explorer: "https://sepolia.uniscan.xyz", rpc: "https://sepolia.unichain.org" };

/**
 * The live Unichain Sepolia deployment, recorded in deployments/unichain-sepolia-2026-08-23.md.
 *
 * These are the defaults, not just documentation. Every NEXT_PUBLIC_* address override falls
 * back here, so a clone with no .env.local still reads the real chain instead of claiming the
 * contracts are unpublished. Repoint the env vars to move the site to another deployment.
 */
export const DEPLOYED = {
  federation: "0x91A0489A1BEA8030AC82351D52BDC3F97d6cA129",
  deep: "0x346930bcf767614a6C4654904739cBCF4A8f6A88",
  shallow: "0x6B8D77a921Adc5244bC0398fa6133841F3DFaA88",
} as const;

export const CONTRACTS = [
  {
    name: "KnotFederation",
    address: DEPLOYED.federation,
    role: "Authenticated per-member reserves plus the O(1) aggregate pair. Every quote is derived here.",
    reads: ["preview(address,bool,bool,uint256)", "reservesOf(address)", "aggregateReserve0()", "aggregateReserve1()", "memberCount()"],
  },
  {
    name: "KnotHook · deep",
    address: DEPLOYED.deep,
    role: "Balanced member, seeded 1000 / 1000. The bound is inert here, which is the control case.",
    reads: ["reserves()", "balanceOf(address)", "totalSupply()"],
  },
  {
    name: "KnotHook · shallow",
    address: DEPLOYED.shallow,
    role: "Skewed member, seeded 100 / 400. The bound binds here, withholding 6,674 bps.",
    reads: ["reserves()", "balanceOf(address)", "totalSupply()"],
  },
] as const;

// Not deployed separately: KnotMath is a library, inlined into both hooks at compile time.
export const POOL_MANAGER = "0x00b036b58a818b1bc34d502d3fe730db729e62ac";
