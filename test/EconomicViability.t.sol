// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {KnotMath} from "../src/KnotMath.sol";

/// @title Is Knot worth building? The three tests that decide it.
///
/// @dev THE BASELINE, AND WHY IT IS FAIR
///      Without a federation, each pool quotes from its own reserves alone. That is exactly
///      `localQuote`. So `localQuote` IS the unfederated counterfactual, and comparing it to
///      the enforced Knot quote is a like-for-like measurement of what the mechanism changes.
///      No mock protocol needed.
contract EconomicViabilityTest is Test {
    uint256 constant NUM = 997;
    uint256 constant DEN = 1000;

    // Deep pool: balanced and large. Shallow pool: skewed, the "weak link".
    uint256 constant D0 = 1000e18;
    uint256 constant D1 = 1000e18;
    uint256 constant S0 = 100e18;
    uint256 constant S1 = 400e18;
    uint256 constant A0 = D0 + S0;
    uint256 constant A1 = D1 + S1;

    function _local(uint256 amtIn, uint256 rIn, uint256 rOut) internal pure returns (uint256) {
        return KnotMath.amountOut(amtIn, rIn, rOut, NUM, DEN);
    }

    function _knot(uint256 amtIn, uint256 lIn, uint256 lOut, uint256 aIn, uint256 aOut)
        internal pure returns (uint256)
    {
        uint256 l = KnotMath.amountOut(amtIn, lIn, lOut, NUM, DEN);
        uint256 a = KnotMath.amountOut(amtIn, aIn, aOut, NUM, DEN);
        return l < a ? l : a;
    }

    // ── 1. THE CORE THESIS: the cross-pool round trip ───────────────────

    /// @dev The attack Knot exists to stop. Sell token0 into the skewed pool at its generous
    ///      rate, then sell the token1 proceeds back into the deep pool. If the pair is
    ///      fragmented, that round trip can end in profit. Does the federation close it?
    function test_thesis_crossPoolRoundTripIsLessProfitableUnderKnot() public {
        uint256 stake = 5e18; // token0 in

        // ── unfederated: each pool quotes alone ──
        uint256 legAUn = _local(stake, S0, S1);   // token0 -> token1 via shallow
        uint256 legBUn = _local(legAUn, D1, D0);  // token1 -> token0 via deep
        int256 pnlUnfederated = int256(legBUn) - int256(stake);

        // ── under Knot: both legs bounded by the aggregate ──
        uint256 legAKn = _knot(stake, S0, S1, A0, A1);
        uint256 legBKn = _knot(legAKn, D1, D0, A1, A0);
        int256 pnlKnot = int256(legBKn) - int256(stake);

        emit log_named_int("round-trip P&L, unfederated (wei)", pnlUnfederated);
        emit log_named_int("round-trip P&L, under Knot   (wei)", pnlKnot);
        emit log_named_int("attacker profit removed by Knot ", pnlUnfederated - pnlKnot);

        assertLt(pnlKnot, pnlUnfederated, "Knot must make the cross-pool round trip strictly less profitable");
    }

    /// @dev Same attack, swept across sizes, so the result is not one lucky configuration.
    function test_thesis_roundTripClosedAcrossSizes() public {
        uint256[6] memory sizes = [uint256(1e17), 5e17, 1e18, 5e18, 1e19, 2e19];
        uint256 closed;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 s = sizes[i];
            uint256 aU = _local(s, S0, S1);
            int256 un = int256(_local(aU, D1, D0)) - int256(s);
            uint256 aK = _knot(s, S0, S1, A0, A1);
            int256 kn = int256(_knot(aK, D1, D0, A1, A0)) - int256(s);
            if (kn < un) closed++;
            emit log_named_int(string.concat("size ", vm.toString(s / 1e17), "e17  delta"), un - kn);
        }
        assertEq(closed, sizes.length, "Knot should reduce attacker P&L at every size tested");
    }

    // ── 2. ROUTER COMPETITION: the question that decides viability ──────

    /// @dev THE DECISIVE TEST. A router sends flow wherever execution is best. Knot only ever
    ///      quotes equal-or-worse than the same pool unfederated, so it can only LOSE routes,
    ///      never win one it would not already have won.
    ///
    ///      The real question is the trade-off: on the routes it loses, how much value did it
    ///      retain for LPs, and how much volume did it forgo to do so?
    function test_router_measureRoutesLostAndValueRetained() public {
        uint256 lost;
        uint256 total;
        uint256 retainedTotal;
        uint256 forgoneVolume;

        for (uint256 i = 1; i <= 40; i++) {
            uint256 amtIn = i * 5e17; // 0.5 .. 20 token0
            total++;

            uint256 unfed = _local(amtIn, S0, S1);
            uint256 knot = _knot(amtIn, S0, S1, A0, A1);

            if (knot < unfed) {
                lost++;                            // a router comparing the two picks the other venue
                retainedTotal += unfed - knot;     // value that stayed with LPs
                forgoneVolume += amtIn;            // notional that would route away
            }
        }

        emit log_named_uint("quotes sampled                      ", total);
        emit log_named_uint("routes Knot would LOSE to an unfederated twin", lost);
        emit log_named_uint("value retained for LPs across them (wei)", retainedTotal);
        emit log_named_uint("notional forgone if all reroute (wei)   ", forgoneVolume);

        // The 30 bps LP fee is the revenue actually lost when volume reroutes.
        uint256 feeRevenueForgone = (forgoneVolume * 3) / 1000;
        emit log_named_uint("LP fee revenue forgone at 30bps (wei)   ", feeRevenueForgone);
        emit log_named_int("net to LPs: retained - fees forgone (wei)", int256(retainedTotal) - int256(feeRevenueForgone));

        // No pass/fail assertion on the sign. This test exists to produce the number that the
        // design decision depends on, not to be green.
        assertGt(total, 0);
    }

    /// @dev Sanity: Knot can never quote BETTER than the unfederated pool. If it could, the
    ///      bound would be inverted somewhere.
    function testFuzz_router_knotNeverQuotesBetterThanUnfederated(uint96 raw) public pure {
        uint256 amtIn = bound(uint256(raw), 1e15, 50e18);
        uint256 unfed = _local(amtIn, S0, S1);
        uint256 knot = _knot(amtIn, S0, S1, A0, A1);
        assertLe(knot, unfed, "Knot quoted BETTER than unfederated, which inverts the mechanism");
    }

    // ── 3. MULTI-BLOCK / STATEFUL ATTACK ────────────────────────────────

    /// @dev Attacks that need several blocks. State carries between them, so a bound that only
    ///      holds within one transaction would leak here. Reserves are advanced between steps
    ///      exactly as real swaps would move them.
    function test_stateful_repeatedDrainCannotBeatTheBound() public {
        uint256 l0 = S0;
        uint256 l1 = S1;
        uint256 a0 = A0;
        uint256 a1 = A1;

        uint256 spent;
        uint256 received;

        // Twelve sequential extraction attempts, state carried forward.
        for (uint256 i = 0; i < 12; i++) {
            uint256 amtIn = 1e18;
            uint256 out = _knot(amtIn, l0, l1, a0, a1);
            if (out == 0 || out >= l1) break;

            spent += amtIn;
            received += out;

            uint256 net = (amtIn * NUM) / DEN;
            l0 += net; l1 -= out;
            a0 += net; a1 -= out;
        }

        emit log_named_uint("token0 spent over 12 sequential attempts", spent);
        emit log_named_uint("token1 received                          ", received);

        // Every step re-reads live reserves, so the bound cannot be worn down by repetition:
        // each successive quote is priced off the state the previous step left behind.
        uint256 finalQuote = _knot(1e18, l0, l1, a0, a1);
        uint256 firstQuote = _knot(1e18, S0, S1, A0, A1);
        emit log_named_uint("quote for 1e18 at step 1 ", firstQuote);
        emit log_named_uint("quote for 1e18 at step 13", finalQuote);
        assertLt(finalQuote, firstQuote, "extraction should get harder, not easier, as the pool is drained");
    }

    /// @dev The aggregate must stay consistent with member books across a long mixed sequence,
    ///      or every quote derived from it is meaningless.
    function testFuzz_stateful_boundHoldsAcrossLongSequences(uint96 seed) public pure {
        uint256 l0 = S0; uint256 l1 = S1; uint256 a0 = A0; uint256 a1 = A1;
        uint256 s = uint256(seed);

        for (uint256 i = 0; i < 20; i++) {
            s = uint256(keccak256(abi.encode(s)));
            uint256 amtIn = bound(s, 1e15, 2e18);
            uint256 out = _knot(amtIn, l0, l1, a0, a1);
            if (out == 0 || out >= l1) break;

            // The enforced quote must never exceed what the local pool alone would allow.
            assertLe(out, _local(amtIn, l0, l1), "enforced quote exceeded the local bound");

            uint256 net = (amtIn * NUM) / DEN;
            l0 += net; l1 -= out; a0 += net; a1 -= out;
            assertGe(a0, l0, "aggregate fell below its member");
            assertGe(a1, l1, "aggregate fell below its member");
        }
    }
}
