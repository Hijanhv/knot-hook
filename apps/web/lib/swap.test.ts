import { describe, expect, it } from "vitest";
import { decodeAbiParameters, decodeFunctionData, encodeFunctionData } from "viem";
import {
  MAX_UINT128,
  encodeExactInput,
  encodeExactOutput,
  faucetAbi,
  fitsRouter,
  formatCooldown,
  requiredSpend,
  swapDeadline,
  swapTokens,
} from "./swap";

const hook = "0x1c828fA6d4232E80aaeCEb143736092b0F822A88" as const;
const c0 = "0x0784b9D734f2a6d13209087964640B1aD7699AAe" as const;
const c1 = "0x243B3f2672Bdd36b63cA960AE201ECDDA4a7b83e" as const;

const active = {
  currencies: { currency0: c0, currency1: c1 },
};

const routerCallParams = [
  { name: "actions", type: "bytes" },
  { name: "params", type: "bytes[]" },
] as const;

const poolKeyComponents = [
  { name: "currency0", type: "address" },
  { name: "currency1", type: "address" },
  { name: "fee", type: "uint24" },
  { name: "tickSpacing", type: "int24" },
  { name: "hooks", type: "address" },
] as const;

const exactInputSingleParams = [
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

describe("swap helpers", () => {
  it("picks the input token by direction", () => {
    expect(swapTokens(active, true)).toEqual({ input: c0, output: c1 });
    expect(swapTokens(active, false)).toEqual({ input: c1, output: c0 });
  });

  it("requires the spend side of the quote", () => {
    expect(requiredSpend(true, 5n, 7n)).toBe(5n);
    expect(requiredSpend(false, 5n, 7n)).toBe(7n);
  });

  it("rejects values outside uint128", () => {
    expect(fitsRouter(0n, MAX_UINT128)).toBe(true);
    expect(fitsRouter(MAX_UINT128 + 1n)).toBe(false);
    expect(fitsRouter(-1n)).toBe(false);
  });

  it("sets a future router deadline", () => {
    expect(swapDeadline(1_000, 1_200)).toBe(2_200n);
  });

  it("encodes an exact-input call the router can decode", () => {
    const call = encodeExactInput(
      {
        key: { currency0: c0, currency1: c1, hooks: hook },
        zeroForOne: true,
        amountIn: 5_000_000_000_000_000_000n,
        amountOutMinimum: 6_315_900_000_000_000_000n,
      },
      c0,
      2_200n
    );
    expect(call.commands).toBe("0x10");
    expect(call.inputs).toHaveLength(1);
    expect(call.deadline).toBe(2_200n);

    const [actions, params] = decodeAbiParameters(routerCallParams, call.inputs[0]);
    expect(actions.toLowerCase()).toBe("0x060c0f");
    expect(params).toHaveLength(3);

    const [single] = decodeAbiParameters(exactInputSingleParams, params[0]);
    expect(single.poolKey.currency0.toLowerCase()).toBe(c0.toLowerCase());
    expect(single.poolKey.hooks.toLowerCase()).toBe(hook.toLowerCase());
    expect(single.poolKey.fee).toBe(8388608);
    expect(single.poolKey.tickSpacing).toBe(60);
    expect(single.zeroForOne).toBe(true);
    expect(single.amountIn).toBe(5_000_000_000_000_000_000n);
    expect(single.amountOutMinimum).toBe(6_315_900_000_000_000_000n);
  });

  it("encodes an exact-output call with the output action tag", () => {    const call = encodeExactOutput(
      {
        key: { currency0: c0, currency1: c1, hooks: hook },
        zeroForOne: false,
        amountOut: 5_000_000_000_000_000_000n,
        amountInMaximum: 7_000_000_000_000_000_000n,
      },
      c1,
      2_200n
    );
    const [actions, params] = decodeAbiParameters(routerCallParams, call.inputs[0]);
    expect(actions.toLowerCase()).toBe("0x080c0f");
    expect(params).toHaveLength(3);
  });

  it("round-trips faucet calls through the faucet ABI", () => {
    const drip = encodeFunctionData({ abi: faucetAbi, functionName: "drip" });
    expect(decodeFunctionData({ abi: faucetAbi, data: drip }).functionName).toBe("drip");

    const to = "0x0000000000000000000000000000000000000007";
    const dripTo = encodeFunctionData({ abi: faucetAbi, functionName: "dripTo", args: [to] });
    const decoded = decodeFunctionData({ abi: faucetAbi, data: dripTo });
    expect(decoded.functionName).toBe("dripTo");
    expect(decoded.args).toEqual([to]);
  });

  it("formats faucet cooldowns compactly", () => {
    expect(formatCooldown(0)).toBe("0s");
    expect(formatCooldown(-5)).toBe("0s");
    expect(formatCooldown(45)).toBe("45s");
    expect(formatCooldown(2700)).toBe("45m");
    expect(formatCooldown(28800)).toBe("8h");
    expect(formatCooldown(28740)).toBe("7h 59m");
  });
});
