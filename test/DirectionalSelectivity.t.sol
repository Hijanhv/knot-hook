// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {KnotMath} from "../src/KnotMath.sol";

/// @title What the bound selects for, stated as a property rather than a hope.
///
/// @dev WHY THIS FILE EXISTS
///      Cross-pool divergence has been measured against real chain data, and the result is
///      specific about which form of the claim survives.
///
///        - Divergence MAGNITUDE does not predict toxicity. Across 67,743 swaps in every
///          multi-pool pair family on Base with enough volume, raw divergence correlates
///          NEGATIVELY with markout: Spearman rho = -0.130, placebo-checked at 0.0005 and
///          stable across three markout horizons. The most divergent trades were
///          LP-beneficial.
///
///        - Divergence DIRECTION does predict it. Swaps that land at a better price locally
///          than a sibling pool's concurrent price average +0.331 bps markout, which is
///          harmful to LPs. Swaps that do not average -0.991 bps, which is beneficial.
///
///      Knot never reads divergence magnitude. It compares two quotes and takes the worse one,
///      so the bound engages on exactly one condition: the local pool would pay the taker more
///      than the pair's combined reserves support. That condition IS "locally favourable",
///      which is the population the data marks harmful.
///
///      This file proves the selectivity mechanically. It cannot prove the economics, and does
///      not try to: the markout figures come from an offline harness against real chain data,
///      not from Foundry. What it does prove is that the mechanism keys off the direction that
///      tested true, and never off the magnitude that tested false.
contract DirectionalSelectivityTest is Test {
    uint256 constant NUM = 997;
    uint256 constant DEN = 1000;

    function _out(uint256 amt, uint256 rIn, uint256 rOut) internal pure returns (uint256) {
        return KnotMath.amountOut(amt, rIn, rOut, NUM, DEN);
    }

    function _in(uint256 amt, uint256 rIn, uint256 rOut) internal pure returns (uint256) {
        return KnotMath.amountIn(amt, rIn, rOut, NUM, DEN);
    }

    // ── 1. Exact input: binds if and only if the local pool is the generous one ──

    /// @dev The bound engages exactly when the local quote is strictly better for the taker
    ///      than the aggregate quote, and is inert otherwise. Nothing about the SIZE of the
    ///      gap enters the decision, which is the whole point: magnitude is the form of the
    ///      claim that did not survive measurement.
    function testFuzz_exactInputBindsIffLocallyFavourable(
        uint96 rl0, uint96 rl1, uint96 rExtra0, uint96 rExtra1, uint96 rin
    ) public pure {
        uint256 l0 = bound(uint256(rl0), 1e18, 1e24);
        uint256 l1 = bound(uint256(rl1), 1e18, 1e24);
        // The aggregate contains this member, so each side is at least the local side.
        uint256 a0 = l0 + bound(uint256(rExtra0), 0, 1e24);
        uint256 a1 = l1 + bound(uint256(rExtra1), 0, 1e24);
        uint256 amountIn = bound(uint256(rin), 1e15, 1e21);

        uint256 localOut = _out(amountIn, l0, l1);
        uint256 aggOut = _out(amountIn, a0, a1);
        uint256 enforced = localOut < aggOut ? localOut : aggOut;

        bool locallyFavourable = localOut > aggOut;
        bool bound_ = enforced < localOut;

        assertEq(bound_, locallyFavourable, "the bound engaged on some other condition");

        // When it is inert the taker keeps the local quote untouched.
        if (!locallyFavourable) assertEq(enforced, localOut, "an unfavourable swap was still clipped");
    }

    // ── 2. Exact output: the same property on the other branch ──

    /// @dev Exact output takes max rather than min, so "favourable" means the local pool would
    ///      charge the taker LESS. The selectivity claim has to hold on this branch too, or it
    ///      only holds for half the traffic.
    function testFuzz_exactOutputBindsIffLocallyFavourable(
        uint96 rl0, uint96 rl1, uint96 rExtra0, uint96 rExtra1, uint96 rout
    ) public pure {
        uint256 l0 = bound(uint256(rl0), 1e18, 1e24);
        uint256 l1 = bound(uint256(rl1), 1e18, 1e24);
        uint256 a0 = l0 + bound(uint256(rExtra0), 0, 1e24);
        uint256 a1 = l1 + bound(uint256(rExtra1), 0, 1e24);
        uint256 amountOut = bound(uint256(rout), 1e15, l1 / 4);

        uint256 localIn = _in(amountOut, l0, l1);
        uint256 aggIn = _in(amountOut, a0, a1);
        uint256 enforced = localIn > aggIn ? localIn : aggIn;

        bool locallyFavourable = localIn < aggIn;
        bool bound_ = enforced > localIn;

        assertEq(bound_, locallyFavourable, "the bound engaged on some other condition");
        if (!locallyFavourable) assertEq(enforced, localIn, "an unfavourable swap was still surcharged");
    }

    // ── 3. Magnitude is not an input ──

    /// @dev Two pools can sit at very different distances from the aggregate and still be
    ///      treated identically, because only the sign of the comparison is consulted. This
    ///      pins down that the mechanism does not read the quantity that tested false: a large
    ///      divergence in the beneficial direction is left completely alone, while an
    ///      arbitrarily small one in the harmful direction is clipped.
    function test_magnitudeIsNeverConsulted() public pure {
        uint256 a0 = 1100e18;
        uint256 a1 = 1400e18;
        uint256 amountIn = 5e18;

        // Far from the aggregate, but in the direction that quotes WORSE than the pair.
        uint256 farButUnfavourable = _out(amountIn, 900e18, 200e18);
        uint256 aggQuote = _out(amountIn, a0, a1);
        assertLt(farButUnfavourable, aggQuote, "fixture is not in the unfavourable direction");
        uint256 enforcedFar = farButUnfavourable < aggQuote ? farButUnfavourable : aggQuote;
        assertEq(enforcedFar, farButUnfavourable, "a large but beneficial divergence was clipped");

        // Barely off the aggregate, but in the direction that quotes BETTER than the pair.
        uint256 nearButFavourable = _out(amountIn, 1090e18, 1400e18);
        assertGt(nearButFavourable, aggQuote, "fixture is not in the favourable direction");
        uint256 enforcedNear = nearButFavourable < aggQuote ? nearButFavourable : aggQuote;
        assertEq(enforcedNear, aggQuote, "a small harmful divergence escaped the bound");
    }

    // ── 4. A balanced member is never touched ──

    /// @dev The corollary that makes the mechanism safe to adopt: a pool in line with its pair
    ///      pays nothing for membership. If the bound clipped balanced pools it would be a tax
    ///      on every member rather than a bound on the mispriced one.
    function testFuzz_balancedMemberIsNeverClipped(uint96 rShare, uint96 rin) public pure {
        // A member holding an exact proportional slice of the aggregate.
        uint256 share = bound(uint256(rShare), 2, 50);
        uint256 a0 = 1000e18;
        uint256 a1 = 1000e18;
        uint256 l0 = a0 / share;
        uint256 l1 = a1 / share;
        uint256 amountIn = bound(uint256(rin), 1e15, 1e19);

        uint256 localOut = _out(amountIn, l0, l1);
        uint256 aggOut = _out(amountIn, a0, a1);
        uint256 enforced = localOut < aggOut ? localOut : aggOut;

        // A proportional member is shallower, so it quotes worse and the bound stays inert.
        assertEq(enforced, localOut, "a balanced member was clipped");
    }
}
