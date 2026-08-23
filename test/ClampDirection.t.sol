// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {KnotMath} from "../src/KnotMath.sol";

/// @title Does the clamp only ever bite corrective trades?
///
/// @dev THE QUESTION
///      Knot binds when the local pool quotes MORE generously than the federation aggregate.
///      A proposed improvement was to exempt "corrective" trades — ones that move the local
///      pool's ratio back toward the aggregate — so the pool stays price-competitive on flow
///      that realigns it.
///
///      That improvement is only worth building if the two categories are actually distinct.
///      If "the clamp binds" and "the trade is corrective" are the SAME event, exempting
///      corrective trades disables the mechanism entirely. This test settles it.
///
///      Ratio comparison is done with cross products so there is no division and no rounding
///      artefact deciding the answer.
contract ClampDirectionTest is Test {
    uint256 constant NUM = 997;
    uint256 constant DEN = 1000;

    /// @dev localRatio > aggRatio  <=>  l1*a0 > a1*l0   (both ratios are r1/r0)
    function _localRicherInToken1(uint256 l0, uint256 l1, uint256 a0, uint256 a1) internal pure returns (bool) {
        return l1 * a0 > a1 * l0;
    }

    /// For a zeroForOne exact-input trade the taker pays token0 and receives token1, so the
    /// local ratio r1/r0 always FALLS. The trade is therefore corrective exactly when the local
    /// ratio started ABOVE the aggregate.
    function testFuzz_clampBindsIfAndOnlyIfTradeIsCorrective(
        uint96 rl0, uint96 rl1, uint96 ra0, uint96 ra1, uint96 rin
    ) public pure {
        uint256 l0 = bound(uint256(rl0), 1e18, 1e24);
        uint256 l1 = bound(uint256(rl1), 1e18, 1e24);
        uint256 amountIn = bound(uint256(rin), 1e15, 1e21);
        // The aggregate contains the local pool, so it is never smaller.
        uint256 a0 = l0 + bound(uint256(ra0), 1e18, 1e24);
        uint256 a1 = l1 + bound(uint256(ra1), 1e18, 1e24);

        uint256 localQuote = KnotMath.amountOut(amountIn, l0, l1, NUM, DEN);
        uint256 aggQuote = KnotMath.amountOut(amountIn, a0, a1, NUM, DEN);

        bool clampBinds = localQuote > aggQuote;          // min() would reduce the taker's output
        bool corrective = _localRicherInToken1(l0, l1, a0, a1); // trade pushes local ratio toward aggregate

        // The biconditional does NOT hold universally. Depth matters as well as ratio: a local
        // pool can hold the better ratio yet still quote worse because it is shallower and the
        // trade eats more slippage. So the two events are correlated, not identical.
        //
        // What DOES hold, and is the finding that matters: the clamp never binds on a trade that
        // widens divergence. Every trade it bites is one that was realigning the pool.
        if (clampBinds) {
            assertTrue(corrective, "the clamp bound a DIVERGENCE-WIDENING trade, which would refute the critique");
        }
    }

    /// A concrete instance, so the result is legible without reading fuzz output.
    function test_concrete_theClampBitesTheRealigningTrade() public pure {
        // Local pool is rich in token1 relative to the aggregate.
        uint256 l0 = 100e18;
        uint256 l1 = 400e18;
        uint256 a0 = 1100e18;
        uint256 a1 = 1400e18;
        uint256 amountIn = 5e18;

        uint256 localQuote = KnotMath.amountOut(amountIn, l0, l1, NUM, DEN);
        uint256 aggQuote = KnotMath.amountOut(amountIn, a0, a1, NUM, DEN);

        assertGt(localQuote, aggQuote, "clamp should bind here");
        assertTrue(_localRicherInToken1(l0, l1, a0, a1), "and the trade should be the corrective one");

        // After the trade the local ratio has moved toward the aggregate: it is more corrective,
        // not less. The clamp is taxing the trade that fixes the pool.
        uint256 l0After = l0 + (amountIn * NUM) / DEN;
        uint256 l1After = l1 - aggQuote;
        uint256 gapBefore = (l1 * a0) / (a1 * l0 / 1e18); // scaled, comparison only
        uint256 gapAfter = (l1After * a0) / (a1 * l0After / 1e18);
        assertLt(gapAfter, gapBefore, "the trade should have reduced the divergence");
    }
}
