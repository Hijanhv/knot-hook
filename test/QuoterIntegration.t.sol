// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {V4Quoter} from "@uniswap/v4-periphery/src/lens/V4Quoter.sol";
import {IV4Quoter} from "@uniswap/v4-periphery/src/interfaces/IV4Quoter.sol";
import {BaseFixture} from "./BaseFixture.sol";
import {KnotMath} from "../src/KnotMath.sol";

/// @title Can a router actually quote this hook?
///
/// @dev WHY THIS FILE EXISTS
///      Knot is a custom-curve hook: it holds its own reserves and returns a delta from
///      `beforeSwap`, so the pool's price is NOT in the PoolManager's tick state. That raises a
///      fair question, and one the cohort asks directly: can standard routing infrastructure
///      still get a price out of it?
///
///      Asserting an answer from first principles would be guessing. This file settles it by
///      running Uniswap's own canonical `V4Quoter` against a live Knot pool and checking that
///      what it returns is exactly what a swap then pays out.
///
///      The distinction that matters, and which these tests are careful to separate:
///        - ON-CHAIN quoting works, because `V4Quoter` simulates a real `poolManager.swap()`,
///          which invokes `beforeSwap` and therefore prices through the hook's curve.
///        - Uniswap's HOSTED auto-router is a separate, off-chain concern. It discovers pools
///          from indexed tick state, which a custom-curve pool does not populate. No test here
///          can speak to that, and none claims to.
contract QuoterIntegrationTest is BaseFixture {
    V4Quoter internal quoter;

    function setUp() public override {
        super.setUp();
        quoter = new V4Quoter(manager);
    }

    function _quote(bool onShallow, uint128 amountIn) internal returns (uint256 out) {
        (out,) = quoter.quoteExactInputSingle(
            IV4Quoter.QuoteExactSingleParams({
                poolKey: onShallow ? shallowKey : deepKey,
                zeroForOne: true,
                exactAmount: amountIn,
                hookData: ""
            })
        );
    }

    /// @dev The headline: the canonical quoter returns a number for a Knot pool at all.
    function test_quoter_returnsAQuoteForACustomCurvePool() public {
        assertGt(_quote(true, 1 ether), 0, "quoter returned nothing for the shallow pool");
        assertGt(_quote(false, 1 ether), 0, "quoter returned nothing for the deep pool");
    }

    /// @dev A quote is only useful if it is the price actually paid. Quote, then swap the same
    ///      size, and require the two to agree to the wei.
    function test_quoter_matchesTheSwapItPredicts() public {
        uint128 amountIn = 1 ether;

        uint256 quoted = _quote(true, amountIn);
        uint256 balanceBefore = currency1.balanceOfSelf();
        doSwap(shallowKey, true, -int256(uint256(amountIn)));
        uint256 received = currency1.balanceOfSelf() - balanceBefore;

        assertEq(quoted, received, "quote did not match the executed swap");
    }

    /// @dev The bound is the whole product, so the quoter must report the BOUNDED price rather
    ///      than the pool's own unbounded curve. If a router could see the local quote, it
    ///      would route into a price the hook will not honour.
    function test_quoter_reportsTheBoundedPriceNotTheLocalOne() public {
        uint128 amountIn = 1 ether;

        uint256 localOnly = KnotMath.amountOut(amountIn, SHALLOW_0, SHALLOW_1, FEE_NUM, FEE_DEN);
        uint256 aggregate =
            KnotMath.amountOut(amountIn, DEEP_0 + SHALLOW_0, DEEP_1 + SHALLOW_1, FEE_NUM, FEE_DEN);
        assertLt(aggregate, localOnly, "fixture is not skewed; this test would be vacuous");

        assertEq(_quote(true, amountIn), aggregate, "quoter did not report the bound");
    }

    /// @dev Where the bound is inert the quoter should report the pool's own curve untouched,
    ///      confirming it is not simply always returning the aggregate.
    function test_quoter_reportsTheLocalPriceWhereTheBoundIsInert() public {
        uint128 amountIn = 1 ether;
        uint256 localOnly = KnotMath.amountOut(amountIn, DEEP_0, DEEP_1, FEE_NUM, FEE_DEN);

        assertEq(_quote(false, amountIn), localOnly, "deep pool should quote its own curve");
    }

    /// @dev A router comparing venues must be able to tell the two members apart on price.
    ///
    ///      Note which way round this goes, because the obvious guess is wrong. The deep pool is
    ///      NOT automatically the better venue: it is balanced 1:1, while the shallow pool is
    ///      token1-rich at 1:4 and is bounded only to the aggregate ratio of 1100:1400, which is
    ///      still the more favourable rate. The bound caps how far a member may quote past the
    ///      pair; it does not force every member onto one price.
    function test_quoter_letsARouterRankTheTwoMembers() public {
        uint256 onDeep = _quote(false, 1 ether);
        uint256 onShallow = _quote(true, 1 ether);

        assertTrue(onDeep != onShallow, "router cannot distinguish the members");
        assertEq(onDeep, KnotMath.amountOut(1 ether, DEEP_0, DEEP_1, FEE_NUM, FEE_DEN));
        assertEq(
            onShallow,
            KnotMath.amountOut(1 ether, DEEP_0 + SHALLOW_0, DEEP_1 + SHALLOW_1, FEE_NUM, FEE_DEN)
        );
    }
}
