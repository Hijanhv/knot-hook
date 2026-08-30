export const CHAIN = { name: "Unichain Sepolia", id: 1301, explorer: "https://sepolia.uniscan.xyz", rpc: "https://sepolia.unichain.org" };

export const CONTRACTS = [
  {
    name: "KnotFederation",
    address: "0x91A0489A1BEA8030AC82351D52BDC3F97d6cA129",
    role: "Authenticated per-member reserves plus the O(1) aggregate pair. Every quote is derived here.",
    reads: ["preview(address,bool,bool,uint256)", "reservesOf(address)", "aggregateReserve0()", "aggregateReserve1()", "memberCount()"],
  },
  {
    name: "KnotHook — deep",
    address: "0x346930bcf767614a6C4654904739cBCF4A8f6A88",
    role: "Balanced member, seeded 1000 / 1000. The bound is inert here, which is the control case.",
    reads: ["reserves()", "balanceOf(address)", "totalSupply()"],
  },
  {
    name: "KnotHook — shallow",
    address: "0x6B8D77a921Adc5244bC0398fa6133841F3DFaA88",
    role: "Skewed member, seeded 100 / 400. The bound binds here, withholding 6,674 bps.",
    reads: ["reserves()", "balanceOf(address)", "totalSupply()"],
  },
] as const;

// Not deployed separately: KnotMath is a library, inlined into both hooks at compile time.
export const POOL_MANAGER = "0x00b036b58a818b1bc34d502d3fe730db729e62ac";
