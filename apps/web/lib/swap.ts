import { encodeAbiParameters } from "viem";
import type { ActiveDeploymentManifest, Address } from "./deployment";

/**
 * Swap execution against the deployed Uniswap Universal Router.
 *
 * Reads stay on the public client, but a swap is a wallet write: ERC20 approve the
 * Permit2 contract, Permit2 approve the router, then Universal Router `execute` with a
 * V4_SWAP carrying one exact-in or exact-out single-hop plus settle/take. The tuple
 * layout mirrors `script/verify/UniversalRouterLifecycle.s.sol`, including its pinned
 * five-field single-hop structs (the deployed router rejects the newer six-field
 * encoding that adds `minHopPriceX36`).
 */

export const UNIVERSAL_ROUTER: Address = "0xf70536B3bcC1bD1a972dc186A2cf84cC6da6Be5D";
export const PERMIT2: Address = "0x000000000022D473030F116dDEE9F6B43aC78BA3";
export const DYNAMIC_FEE = 8388608;
export const TICK_SPACING = 60;

export const MAX_UINT160 = 2n ** 160n - 1n;
/** Permit2 expirations are uint48, which viem types as number. */
export const MAX_UINT48 = 2 ** 48 - 1;
export const MAX_UINT128 = 2n ** 128n - 1n;
export const MAX_UINT256 = 2n ** 256n - 1n;

const V4_SWAP = "0x10";
const ACTIONS_EXACT_IN = "0x060c0f";
const ACTIONS_EXACT_OUT = "0x080c0f";

export const erc20Abi = [
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "decimals",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
  {
    type: "function",
    name: "symbol",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "string" }],
  },
] as const;

export const permit2Abi = [
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "token", type: "address" },
      { name: "spender", type: "address" },
      { name: "amount", type: "uint160" },
      { name: "expiration", type: "uint48" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "token", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [
      { name: "amount", type: "uint160" },
      { name: "expiration", type: "uint48" },
      { name: "nonce", type: "uint48" },
    ],
  },
] as const;

export const routerAbi = [  {
    type: "function",
    name: "execute",
    stateMutability: "payable",
    inputs: [
      { name: "commands", type: "bytes" },
      { name: "inputs", type: "bytes[]" },
      { name: "deadline", type: "uint256" },
    ],
    outputs: [],
  },
] as const;

export type PoolKeyInput = {
  currency0: Address;
  currency1: Address;
  hooks: Address;
};

export type ExactInputSwap = {
  key: PoolKeyInput;
  zeroForOne: boolean;
  amountIn: bigint;
  amountOutMinimum: bigint;
};

export type ExactOutputSwap = {
  key: PoolKeyInput;
  zeroForOne: boolean;
  amountOut: bigint;
  amountInMaximum: bigint;
};

export type RouterCall = {
  commands: `0x${string}`;
  inputs: Array<`0x${string}`>;
  deadline: bigint;
};

const poolKeyComponents = [
  { name: "currency0", type: "address" },
  { name: "currency1", type: "address" },
  { name: "fee", type: "uint24" },
  { name: "tickSpacing", type: "int24" },
  { name: "hooks", type: "address" },
] as const;

const exactInputSingleComponents = [
  {
    name: "params",
    type: "tuple",
    components: [
      { name: "poolKey", type: "tuple", components: [...poolKeyComponents] },
      { name: "zeroForOne", type: "bool" },
      { name: "amountIn", type: "uint128" },
      { name: "amountOutMinimum", type: "uint128" },
      { name: "hookData", type: "bytes" },
    ],
  },
] as const;

const exactOutputSingleComponents = [
  {
    name: "params",
    type: "tuple",
    components: [
      { name: "poolKey", type: "tuple", components: [...poolKeyComponents] },
      { name: "zeroForOne", type: "bool" },
      { name: "amountOut", type: "uint128" },
      { name: "amountInMaximum", type: "uint128" },
      { name: "hookData", type: "bytes" },
    ],
  },
] as const;

const currencyAmountComponents = [
  { name: "currency", type: "address" },
  { name: "amount", type: "uint256" },
] as const;

type PoolKeyTuple = readonly [Address, Address, number, number, Address];

const toPoolKeyTuple = (key: PoolKeyInput): PoolKeyTuple => [
  key.currency0,
  key.currency1,
  DYNAMIC_FEE,
  TICK_SPACING,
  key.hooks,
];

/** Wraps encoded V4 planner actions into one Universal Router command input. */
const encodeRouterCall = (
  actions: `0x${string}`,
  params: Array<`0x${string}`>,
  deadline: bigint
): RouterCall => {
  const inputs = encodeAbiParameters(
    [
      { name: "actions", type: "bytes" },
      { name: "params", type: "bytes[]" },
    ],
    [actions, params]
  );
  return { commands: V4_SWAP, inputs: [inputs], deadline };
};

/** Seconds from now until the router deadline. Twenty minutes tolerates one slow confirmation. */
export const swapDeadline = (nowSeconds = Math.floor(Date.now() / 1000), ttlSeconds = 20 * 60): bigint =>
  BigInt(nowSeconds + ttlSeconds);

/** Input and output token for a direction. currency0 is token0 by definition. */
export const swapTokens = (
  active: Pick<ActiveDeploymentManifest, "currencies">,
  zeroForOne: boolean
): { input: Address; output: Address } =>
  zeroForOne
    ? { input: active.currencies.currency0, output: active.currencies.currency1 }
    : { input: active.currencies.currency1, output: active.currencies.currency0 };

/** Amount the wallet must be able to spend for this quote. */
export const requiredSpend = (exactInput: boolean, amountIn: bigint, amountInMaximum: bigint): bigint =>
  exactInput ? amountIn : amountInMaximum;

/** True when every value fits the router's uint128 fields. */
export const fitsRouter = (...values: Array<bigint>): boolean =>
  values.every((v) => v >= 0n && v <= MAX_UINT128);

export function encodeExactInput(swap: ExactInputSwap, input: Address, deadline: bigint): RouterCall {
  const { currency0, currency1 } = swap.key;
  const poolKey = toPoolKeyTuple(swap.key);
  const single = encodeAbiParameters(exactInputSingleComponents, [
    {
      poolKey: {
        currency0: poolKey[0],
        currency1: poolKey[1],
        fee: poolKey[2],
        tickSpacing: poolKey[3],
        hooks: poolKey[4],
      },
      zeroForOne: swap.zeroForOne,
      amountIn: swap.amountIn,
      amountOutMinimum: swap.amountOutMinimum,
      hookData: "0x",
    },
  ]);
  const settle = encodeAbiParameters(currencyAmountComponents, [input, swap.amountIn]);
  const output = swap.zeroForOne ? currency1 : currency0;
  const take = encodeAbiParameters(currencyAmountComponents, [output, swap.amountOutMinimum]);
  return encodeRouterCall(ACTIONS_EXACT_IN, [single, settle, take], deadline);
}

export function encodeExactOutput(swap: ExactOutputSwap, input: Address, deadline: bigint): RouterCall {
  const { currency0, currency1 } = swap.key;
  const poolKey = toPoolKeyTuple(swap.key);
  const single = encodeAbiParameters(exactOutputSingleComponents, [
    {
      poolKey: {
        currency0: poolKey[0],
        currency1: poolKey[1],
        fee: poolKey[2],
        tickSpacing: poolKey[3],
        hooks: poolKey[4],
      },
      zeroForOne: swap.zeroForOne,
      amountOut: swap.amountOut,
      amountInMaximum: swap.amountInMaximum,
      hookData: "0x",
    },
  ]);
  const settle = encodeAbiParameters(currencyAmountComponents, [input, swap.amountInMaximum]);
  const output = swap.zeroForOne ? currency1 : currency0;
  const take = encodeAbiParameters(currencyAmountComponents, [output, swap.amountOut]);
  return encodeRouterCall(ACTIONS_EXACT_OUT, [single, settle, take], deadline);
}

export const faucetAbi = [
  {
    type: "function",
    name: "drip",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
  {
    type: "function",
    name: "dripTo",
    stateMutability: "nonpayable",
    inputs: [{ name: "to", type: "address" }],
    outputs: [],
  },
  {
    type: "function",
    name: "cooldownRemaining",
    stateMutability: "view",
    inputs: [{ name: "claimer", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "claimsRemaining",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "dripAmount",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

/** Short human form for a faucet cooldown: 45 -> "45s", 2700 -> "45m", 28740 -> "7h 59m". */
export function formatCooldown(totalSeconds: number): string {
  if (!Number.isFinite(totalSeconds) || totalSeconds <= 0) return "0s";
  const seconds = Math.floor(totalSeconds);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const rest = seconds % 60;
  if (hours > 0) return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`;
  if (minutes > 0) return `${minutes}m`;
  return `${rest}s`;
}
