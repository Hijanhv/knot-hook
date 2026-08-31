import { DEPLOYED } from "./contracts";

/**
 * Contract surface and deployment config.
 *
 * Addresses come from env so one build can point at any deployment, and fall back to the live
 * one so a fresh clone reads the real chain with no setup. If the RPC is unreachable the UI
 * still drops to reference values rather than throwing, so the mechanism stays explorable.
 */
export const FEDERATION_ADDRESS = (process.env.NEXT_PUBLIC_FEDERATION ?? DEPLOYED.federation) as `0x${string}`;
export const DEEP_POOL = (process.env.NEXT_PUBLIC_DEEP_POOL ?? DEPLOYED.deep) as `0x${string}`;
export const SHALLOW_POOL = (process.env.NEXT_PUBLIC_SHALLOW_POOL ?? DEPLOYED.shallow) as `0x${string}`;
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

const ceilDiv = (a: bigint, b: bigint) => (a + b - 1n) / b;

/** Constant-product quote with the LP fee retained in the input reserve. Mirrors KnotMath.amountOut. */
export function amountOut(inAmt: bigint, reserveIn: bigint, reserveOut: bigint, num = 997n, den = 1000n) {
  if (inAmt <= 0n || reserveIn <= 0n || reserveOut <= 0n) return 0n;
  const net = (inAmt * num) / den;
  if (net === 0n) return 0n;
  return (reserveOut * net) / (reserveIn + net);
}

/**
 * Exact-output quote. Mirrors KnotMath.amountIn, including its rounding: both divisions round
 * up, so the taker is never undercharged by a rounding step.
 */
export function amountIn(outAmt: bigint, reserveIn: bigint, reserveOut: bigint, num = 997n, den = 1000n) {
  if (outAmt <= 0n || reserveIn <= 0n || reserveOut <= 0n || outAmt >= reserveOut) return 0n;
  return ceilDiv(ceilDiv(reserveIn * outAmt, reserveOut - outAmt) * den, num);
}

/** The rule, in one function: a taker never beats both references. Exact input only. */
export function knotQuote(inAmt: bigint, local: [bigint, bigint], agg: [bigint, bigint]) {
  const l = amountOut(inAmt, local[0], local[1]);
  const a = amountOut(inAmt, agg[0], agg[1]);
  return { local: l, aggregate: a, enforced: l < a ? l : a, withheld: l > a ? l - a : 0n };
}

/**
 * Client-side mirror of `KnotFederation.preview`, honouring both directions and both swap
 * modes. Used only when the contracts are unreachable. The live path reads `preview()` itself.
 * Reserves are given in canonical (token0, token1) order and swapped here for a 1 -> 0 trade,
 * exactly as the contract does.
 */
export function previewQuote(
  specifiedAmount: bigint,
  local: [bigint, bigint],
  agg: [bigint, bigint],
  zeroForOne: boolean,
  exactInput: boolean,
) {
  const [localIn, localOut] = zeroForOne ? local : [local[1], local[0]];
  const [aggIn, aggOut] = zeroForOne ? agg : [agg[1], agg[0]];

  if (exactInput) {
    // The taker receives the smaller of the two outputs.
    const l = amountOut(specifiedAmount, localIn, localOut);
    const a = amountOut(specifiedAmount, aggIn, aggOut);
    return { local: l, aggregate: a, enforced: l < a ? l : a };
  }
  // The taker pays the larger of the two inputs.
  const l = amountIn(specifiedAmount, localIn, localOut);
  const a = amountIn(specifiedAmount, aggIn, aggOut);
  return { local: l, aggregate: a, enforced: l > a ? l : a };
}

/**
 * Formats an 18-decimal amount. Trailing zeros are trimmed only after a decimal point, so a
 * whole-number reserve keeps its magnitude: fmt(1000e18, 0) is "1000", not "1".
 */
export const fmt = (v: bigint, dp = 4) => {
  const s = (Number(v) / 1e18).toFixed(dp);
  if (!s.includes(".")) return s;
  return s.replace(/0+$/, "").replace(/\.$/, "") || "0";
};
