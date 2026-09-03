import { describe, expect, it } from "vitest";
import { amountIn, amountOut, fmt, previewQuote, roundTrip } from "./knot";
import { chainHeadAgeSeconds, isChainHeadStale } from "./rpc";

const ETHER = 10n ** 18n;
const deep: [bigint, bigint] = [1000n * ETHER, 1000n * ETHER];
const shallow: [bigint, bigint] = [100n * ETHER, 400n * ETHER];
const aggregate: [bigint, bigint] = [1100n * ETHER, 1400n * ETHER];

describe("KnotMath TypeScript mirror", () => {
  it("matches the documented deployed exact-input preview to the wei", () => {
    const preview = previewQuote(5n * ETHER, shallow, aggregate, true, true);
    expect(preview.local).toBe(18_993_189_503_262_370_814n);
    expect(preview.aggregate).toBe(6_315_922_840_581_546_355n);
    expect(preview.enforced).toBe(preview.aggregate);
  });

  it("charges the larger exact-output input and that input is minimal", () => {
    const output = 5n * ETHER;
    const preview = previewQuote(output, shallow, aggregate, true, false);
    expect(preview.enforced).toBe(preview.aggregate > preview.local ? preview.aggregate : preview.local);
    expect(amountOut(preview.enforced, aggregate[0], aggregate[1])).toBeGreaterThanOrEqual(output);
    expect(amountOut(preview.enforced - 1n, aggregate[0], aggregate[1])).toBeLessThan(output);
    expect(amountIn(output, aggregate[0], aggregate[1])).toBe(preview.aggregate);
  });

  it("advances the aggregate between round-trip legs", () => {
    const independent = roundTrip(5n * ETHER, shallow, deep, aggregate, false);
    const knot = roundTrip(5n * ETHER, shallow, deep, aggregate, true);
    expect(independent.pnl).toBe(13_584_293_845_014_263_315n);
    expect(knot.pnl).toBe(-29_820_265_399_140_302n);
    expect(independent.pnl - knot.pnl).toBe(13_614_114_110_413_403_617n);
  });

  it("formats 18-decimal integers without converting through a lossy Number", () => {
    expect(fmt(18_993_189_503_262_370_814n, 6)).toBe("18.993189");
    expect(fmt(1000n * ETHER, 0)).toBe("1000");
    expect(fmt(-29_820_265_399_140_302n, 6)).toBe("-0.02982");
  });
});

describe("RPC freshness labels", () => {
  const head = { number: 42n, timestamp: 100n, observedAt: 0 };

  it("uses the chain timestamp instead of treating any successful response as live", () => {
    expect(chainHeadAgeSeconds(head, 190_000)).toBe(90);
    expect(isChainHeadStale(head, 90, 190_000)).toBe(false);
    expect(isChainHeadStale(head, 89, 190_000)).toBe(true);
  });

  it("does not report negative age when local time trails the chain", () => {
    expect(chainHeadAgeSeconds(head, 99_000)).toBe(0);
  });
});
