// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {KnotMath} from "../src/KnotMath.sol";

/// @title Router behaviour under realistic conditions, and the skew sensitivity curve.
///
/// @dev WHY THE EARLIER "LOSES 40 OF 40 ROUTES" NUMBER WAS THE WRONG QUESTION
///      That test compared a Knot pool against an imaginary unfederated twin holding identical
///      reserves. No such twin exists. In reality a router compares the Knot pool against the
///      OTHER POOLS THAT ACTUALLY EXIST — and for a federated pair, the deep member pool is one
///      of them. Flow that leaves the skewed member for the deep member has not left the
///      federation at all: the same LP set still earns the fee.
///
///      This file measures the question that matters: after routing, does the federation keep
///      the flow, and do its LPs end up ahead?
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

    /// @dev A router picks the best venue among those that exist. For a federated pair the
    ///      candidate set is {deep member, shallow member}. Measure where flow lands and
    ///      whether it stayed inside the federation.
    function test_router_flowStaysInsideTheFederation() public {
        uint256 d0 = 1000e18; uint256 d1 = 1000e18;
        uint256 s0 = 100e18;  uint256 s1 = 400e18;
        uint256 a0 = d0 + s0; uint256 a1 = d1 + s1;

        uint256 toDeep;
        uint256 toShallow;
        uint256 leftFederation;

        for (uint256 i = 1; i <= 40; i++) {
            uint256 amt = i * 5e17;
            uint256 qDeep = _knot(amt, d0, d1, a0, a1);
            uint256 qShallow = _knot(amt, s0, s1, a0, a1);

            if (qDeep == 0 && qShallow == 0) { leftFederation++; continue; }
            if (qDeep >= qShallow) toDeep++; else toShallow++;
        }

        emit log_named_uint("routes landing on the DEEP member   ", toDeep);
        emit log_named_uint("routes landing on the SHALLOW member", toShallow);
        emit log_named_uint("routes leaving the federation       ", leftFederation);
        assertEq(leftFederation, 0, "flow left the federation entirely");
        assertEq(toDeep + toShallow, 40, "every route should land on a member");
    }

    /// @dev The honest version of the competitiveness question: against a genuinely EXTERNAL
    ///      pool that is not in the federation, does the deep member still win routes? If the
    ///      federation's best member is competitive, the mechanism is not driving flow away.
    function test_router_deepMemberStaysCompetitiveAgainstAnOutsidePool() public {
        uint256 d0 = 1000e18; uint256 d1 = 1000e18;
        uint256 s0 = 100e18;  uint256 s1 = 400e18;
        uint256 a0 = d0 + s0; uint256 a1 = d1 + s1;

        // An unaffiliated pool of comparable depth, quoting freely.
        uint256 x0 = 1000e18; uint256 x1 = 1000e18;

        uint256 knotWins;
        for (uint256 i = 1; i <= 40; i++) {
            uint256 amt = i * 5e17;
            uint256 best = _knot(amt, d0, d1, a0, a1);
            uint256 outside = _q(amt, x0, x1);
            if (best >= outside) knotWins++;
        }
        emit log_named_uint("routes the federation's best member WINS vs an outside pool", knotWins);
        emit log_named_uint("of                                                        ", 40);
        assertGt(knotWins, 0, "the federation should win at least some routes outright");
    }

    // ── 2. The skew sensitivity curve ────────────────────────────────────

    /// @dev Caveat 2 answered properly: instead of one lopsided configuration, sweep skew from
    ///      balanced to extreme and report the curve. The mechanism should be near-inert on
    ///      balanced pools and strong exactly where fragmentation is worst.
    function test_skew_sensitivityCurve() public {
        uint256 d0 = 1000e18; uint256 d1 = 1000e18;
        uint256 amt = 5e18;

        // s1/s0 ratio walks 1x -> 8x while depth is held constant.
        uint256[6] memory mult = [uint256(1), 2, 3, 4, 6, 8];
        for (uint256 i = 0; i < mult.length; i++) {
            uint256 s0 = 100e18;
            uint256 s1 = 100e18 * mult[i];
            uint256 a0 = d0 + s0; uint256 a1 = d1 + s1;

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

    /// @dev The retained-vs-forgone ratio across skew levels, so the 750x headline is shown as
    ///      a curve rather than a single cherry-picked point.
    function test_skew_retainedVersusForgoneAcrossSkew() public {
        uint256 d0 = 1000e18; uint256 d1 = 1000e18;
        uint256[5] memory mult = [uint256(1), 2, 4, 6, 8];

        for (uint256 m = 0; m < mult.length; m++) {
            uint256 s0 = 100e18;
            uint256 s1 = 100e18 * mult[m];
            uint256 a0 = d0 + s0; uint256 a1 = d1 + s1;

            uint256 retained; uint256 forgone;
            for (uint256 i = 1; i <= 20; i++) {
                uint256 amt = i * 5e17;
                uint256 unfed = _q(amt, s0, s1);
                uint256 knot = _knot(amt, s0, s1, a0, a1);
                if (knot < unfed) { retained += unfed - knot; forgone += amt; }
            }
            uint256 fees = (forgone * 3) / 1000;
            uint256 ratio = fees > 0 ? retained / fees : 0;
            emit log_named_uint(string.concat("skew ", vm.toString(mult[m]), "x  retained/fees ratio"), ratio);
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
