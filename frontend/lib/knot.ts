/**
 * Contract surface and deployment config.
 *
 * Addresses are read from env so the same build points at whichever testnet the demo is
 * live on. Absent an address the UI runs in illustrative mode rather than throwing, so a
 * judge can still explore the mechanism before anything is deployed.
 */
export const FEDERATION_ADDRESS = (process.env.NEXT_PUBLIC_FEDERATION ?? "") as `0x${string}` | "";
export const DEEP_POOL = (process.env.NEXT_PUBLIC_DEEP_POOL ?? "") as `0x${string}` | "";
export const SHALLOW_POOL = (process.env.NEXT_PUBLIC_SHALLOW_POOL ?? "") as `0x${string}` | "";
export const CHAIN_ID = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? 1301); // unichain sepolia

export const federationAbi = [
  {
    type: "function",
    name: "preview",
    stateMutability: "view",
    inputs: [
      { name: "hook", type: "address" },
      { name: "zeroForOne", type: "bool" },
      { name: "exactInput", type: "bool" },
      { name: "specifiedAmount", type: "uint256" },
    ],
    outputs: [
      { name: "localQuote", type: "uint256" },
      { name: "aggregateQuote", type: "uint256" },
      { name: "knotQuote", type: "uint256" },
    ],
  },
  {
    type: "function",
    name: "reservesOf",
    stateMutability: "view",
    inputs: [{ name: "hook", type: "address" }],
    outputs: [
      { name: "reserve0", type: "uint256" },
      { name: "reserve1", type: "uint256" },
    ],
  },
  { type: "function", name: "aggregateReserve0", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { type: "function", name: "aggregateReserve1", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { type: "function", name: "memberCount", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
] as const;

/** Constant-product quote with the LP fee retained in the input reserve. Mirrors KnotMath. */
export function amountOut(inAmt: bigint, reserveIn: bigint, reserveOut: bigint, num = 997n, den = 1000n) {
  if (inAmt <= 0n || reserveIn <= 0n || reserveOut <= 0n) return 0n;
  const net = (inAmt * num) / den;
  return (reserveOut * net) / (reserveIn + net);
}

/** The rule, in one function: a taker never beats both references. */
export function knotQuote(inAmt: bigint, local: [bigint, bigint], agg: [bigint, bigint]) {
  const l = amountOut(inAmt, local[0], local[1]);
  const a = amountOut(inAmt, agg[0], agg[1]);
  return { local: l, aggregate: a, enforced: l < a ? l : a, withheld: l > a ? l - a : 0n };
}

export const fmt = (v: bigint, dp = 4) => {
  const s = (Number(v) / 1e18).toFixed(dp);
  return s.replace(/\.?0+$/, "") || "0";
};
