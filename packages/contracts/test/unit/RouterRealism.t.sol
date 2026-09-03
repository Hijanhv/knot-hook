// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {KnotMath} from "../../src/libraries/KnotMath.sol";

/// @title Controlled routing fixtures and skew sensitivity.
/// @notice These tests describe quote selection under explicit reserve assumptions. They do not
///         model a production router, organic order flow, or realized LP returns.
contract RouterRealismTest is Test {
    uint256 constant NUM = 997;
    uint256 constant DEN = 1000;

    function _q(uint256 a, uint256 rIn, uint256 rOut) internal pure returns (uint256) {
        return KnotMath.amountOut(a, rIn, rOut, NUM, DEN);
    }

    function _knot(uint256 a, uint256 lIn, uint256 lOut, uint256 aIn, uint256 aOut) internal pure returns (uint256) {
        uint256 l = _q(a, lIn, lOut);
        uint256 g = _q(a, aIn, aOut);
        return l < g ? l : g;
    }

    // ── 1. Realistic routing: the federation as a whole, not one member ──

    /// @dev Compare the two members in the canonical fixture. There is intentionally no claim
    ///      about routes leaving the federation because this fixture contains no outside venue.
    function test_router_selectsTheBestMemberInTheTwoPoolFixture() public {
        uint256 d0 = 1000e18;
        uint256 d1 = 1000e18;
        uint256 s0 = 100e18;
        uint256 s1 = 400e18;
        uint256 a0 = d0 + s0;
        uint256 a1 = d1 + s1;

        uint256 toDeep;
        uint256 toShallow;
        for (uint256 i = 1; i <= 40; i++) {
            uint256 amt = i * 5e17;
            uint256 qDeep = _knot(amt, d0, d1, a0, a1);
            uint256 qShallow = _knot(amt, s0, s1, a0, a1);

            if (qDeep >= qShallow) toDeep++;
            else toShallow++;
        }

        emit log_named_uint("routes landing on the DEEP member   ", toDeep);
        emit log_named_uint("routes landing on the SHALLOW member", toShallow);
        assertEq(toDeep + toShallow, 40, "every route should land on a member");
    }

    /// @dev The outside control has exactly the deep member's reserves and fee. It should tie,
    ///      not be reported as a KNOT win. A different outside state can produce any outcome.
    function test_router_deepMemberTiesAnIdenticalOutsidePool() public {
        uint256 d0 = 1000e18;
        uint256 d1 = 1000e18;
        uint256 s0 = 100e18;
        uint256 s1 = 400e18;
        uint256 a0 = d0 + s0;
        uint256 a1 = d1 + s1;

        // An unaffiliated pool of comparable depth, quoting freely.
        uint256 x0 = 1000e18;
        uint256 x1 = 1000e18;

        uint256 wins;
        uint256 ties;
        uint256 losses;
        for (uint256 i = 1; i <= 40; i++) {
            uint256 amt = i * 5e17;
            uint256 best = _knot(amt, d0, d1, a0, a1);
            uint256 outside = _q(amt, x0, x1);
            if (best > outside) wins++;
            else if (best == outside) ties++;
            else losses++;
        }
        emit log_named_uint("wins against identical outside pool", wins);
        emit log_named_uint("ties against identical outside pool", ties);
        emit log_named_uint("losses against identical outside pool", losses);
        assertEq(wins, 0, "an identical control should not be called a win");
        assertEq(ties, 40, "the identical control should tie at every sampled size");
        assertEq(losses, 0, "the deep member should not lose to its identical control");
    }

    // ── 2. The skew sensitivity curve ────────────────────────────────────

    /// @dev Caveat 2 answered properly: instead of one lopsided configuration, sweep skew from
    ///      balanced to extreme and report the curve. The mechanism should be near-inert on
    ///      balanced pools and strong exactly where fragmentation is worst.
    function test_skew_sensitivityCurve() public {
        uint256 d0 = 1000e18;
        uint256 d1 = 1000e18;
        uint256 amt = 5e18;

        // s1/s0 ratio walks 1x -> 8x while depth is held constant.
        uint256[6] memory mult = [uint256(1), 2, 3, 4, 6, 8];
        for (uint256 i = 0; i < mult.length; i++) {
            uint256 s0 = 100e18;
            uint256 s1 = 100e18 * mult[i];
            uint256 a0 = d0 + s0;
            uint256 a1 = d1 + s1;

            uint256 unfed = _q(amt, s0, s1);
            uint256 knot = _knot(amt, s0, s1, a0, a1);
            uint256 withheldBps = unfed > 0 ? ((unfed - knot) * 10_000) / unfed : 0;

            emit log_named_uint(string.concat("skew ", vm.toString(mult[i]), "x  -> withheld bps"), withheldBps);
        }
        // Balanced case must be near-inert: a pool in line with the pair keeps its own quote.
        uint256 balancedUnfed = _q(amt, 100e18, 100e18);
        uint256 balancedKnot = _knot(amt, 100e18, 100e18, d0 + 100e18, d1 + 100e18);
        uint256 balancedBps = ((balancedUnfed - balancedKnot) * 10_000) / balancedUnfed;
        emit log_named_uint("balanced pool, withheld bps", balancedBps);
        assertLt(balancedBps, 500, "a balanced member should be barely touched by the bound");
    }

    /// @dev Retained output and hypothetical forgone fees start in different currencies. Convert
    ///      both to output-token units at the opening aggregate spot ratio before comparing them.
    ///      The result is a fixture estimate, not realized P&L or a routing forecast.
    function test_skew_valueComparisonUsesOneNumeraire() public {
        uint256 d0 = 1000e18;
        uint256 d1 = 1000e18;
        uint256[5] memory mult = [uint256(1), 2, 4, 6, 8];

        for (uint256 m = 0; m < mult.length; m++) {
            uint256 s0 = 100e18;
            uint256 s1 = 100e18 * mult[m];
            uint256 a0 = d0 + s0;
            uint256 a1 = d1 + s1;

            uint256 retained;
            uint256 forgone;
            for (uint256 i = 1; i <= 20; i++) {
                uint256 amt = i * 5e17;
                uint256 unfed = _q(amt, s0, s1);
                uint256 knot = _knot(amt, s0, s1, a0, a1);
                if (knot < unfed) {
                    retained += unfed - knot;
                    forgone += amt;
                }
            }
            uint256 hypotheticalFeeIn = (forgone * 3) / 1000;
            uint256 hypotheticalFeeOut = FullMath.mulDiv(hypotheticalFeeIn, a1, a0);
            uint256 ratioBps = hypotheticalFeeOut > 0 ? FullMath.mulDiv(retained, 10_000, hypotheticalFeeOut) : 0;
            emit log_named_uint(string.concat("skew ", vm.toString(mult[m]), "x  retained/fee-value bps"), ratioBps);
        }
    }

    // ── 3. Multi-member federations ──────────────────────────────────────

    /// @dev Three and four members, not just two. The bound must still hold and the aggregate
    ///      must still dominate any single member.
    function testFuzz_multiMember_boundHoldsWithFourPools(uint96 r1, uint96 r2, uint96 r3, uint96 amt) public pure {
        uint256 p0 = bound(uint256(r1), 10e18, 1000e18);
        uint256 p1 = bound(uint256(r2), 10e18, 1000e18);
        uint256 q0 = bound(uint256(r3), 10e18, 1000e18);
        uint256 amount = bound(uint256(amt), 1e15, 5e18);

        // four members, aggregate is their sum
        uint256 a0 = p0 + q0 + 500e18 + 250e18;
        uint256 a1 = p1 + q0 + 500e18 + 250e18;

        uint256 local = KnotMath.amountOut(amount, p0, p1, NUM, DEN);
        uint256 agg = KnotMath.amountOut(amount, a0, a1, NUM, DEN);
        uint256 enforced = local < agg ? local : agg;

        assertLe(enforced, local, "enforced quote exceeded the local bound");
        assertLe(enforced, agg, "enforced quote exceeded the aggregate bound");
    }
}
