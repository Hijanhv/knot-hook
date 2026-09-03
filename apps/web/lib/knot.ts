import { DEPLOYMENT } from "./deployment";

/**
 * Contract surface and deployment config.
 *
 * Chain identity and the deterministic reference fixture come from the validated manifest.
 * Release addresses are exposed only after a complete active deployment passes validation.
 */
export const CHAIN_ID = DEPLOYMENT.chain.id;
export const FEE_NUMERATOR = BigInt(DEPLOYMENT.parameters.feeNumerator);
export const FEE_DENOMINATOR = BigInt(DEPLOYMENT.parameters.feeDenominator);
export const DEEP_SEED = DEPLOYMENT.seed.deep.map(BigInt) as [bigint, bigint];
export const SHALLOW_SEED = DEPLOYMENT.seed.shallow.map(BigInt) as [bigint, bigint];
export const AGGREGATE_SEED: [bigint, bigint] = [
  DEEP_SEED[0] + SHALLOW_SEED[0],
  DEEP_SEED[1] + SHALLOW_SEED[1],
];

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
  { type: "function", name: "feeNumerator", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { type: "function", name: "feeDenominator", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
] as const;

const ceilDiv = (a: bigint, b: bigint) => (a + b - 1n) / b;

/** Constant-product quote with the LP fee retained in the input reserve. Mirrors KnotMath.amountOut. */
export function amountOut(
  inAmt: bigint,
  reserveIn: bigint,
  reserveOut: bigint,
  num = FEE_NUMERATOR,
  den = FEE_DENOMINATOR,
) {
  if (inAmt <= 0n || reserveIn <= 0n || reserveOut <= 0n) return 0n;
  const net = (inAmt * num) / den;
  if (net === 0n) return 0n;
  return (reserveOut * net) / (reserveIn + net);
}

/**
 * Exact-output quote. Mirrors KnotMath.amountIn, including its rounding: both divisions round
 * up, so the taker is never undercharged by a rounding step.
 */
export function amountIn(
  outAmt: bigint,
  reserveIn: bigint,
  reserveOut: bigint,
  num = FEE_NUMERATOR,
  den = FEE_DENOMINATOR,
) {
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
 * A two-leg 0 -> 1 -> 0 fixture. The federated path advances the aggregate after leg one before
 * pricing leg two, matching `KnotFederation.executeSwap` instead of reusing a stale opening book.
 */
export function roundTrip(
  stake: bigint,
  firstPool: [bigint, bigint],
  secondPool: [bigint, bigint],
  aggregate: [bigint, bigint],
  federated: boolean,
) {
  if (!federated) {
    const legA = amountOut(stake, firstPool[0], firstPool[1]);
    const legB = amountOut(legA, secondPool[1], secondPool[0]);
    return { legA, legB, pnl: legB - stake };
  }

  const legA = previewQuote(stake, firstPool, aggregate, true, true).enforced;
  const aggregateAfterLegA: [bigint, bigint] = [aggregate[0] + stake, aggregate[1] - legA];
  const legB = previewQuote(legA, secondPool, aggregateAfterLegA, false, true).enforced;
  return { legA, legB, pnl: legB - stake };
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
  const negative = v < 0n;
  const absolute = negative ? -v : v;
  const scale = 10n ** 18n;
  const whole = absolute / scale;
  if (dp === 0) return `${negative ? "-" : ""}${whole}`;
  const fractional = (absolute % scale).toString().padStart(18, "0").slice(0, dp).replace(/0+$/, "");
  return `${negative ? "-" : ""}${whole}${fractional ? `.${fractional}` : ""}`;
};
