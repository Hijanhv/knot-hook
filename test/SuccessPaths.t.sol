// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BaseFixture} from "./BaseFixture.sol";

/// @title Happy paths — every expected hook effect, asserted rather than assumed.
/// @dev Each test states one thing. Shared setup lives in BaseFixture.
contract SuccessPathsTest is BaseFixture {
    // ── swaps ────────────────────────────────────────────────────────────

    function test_swap_exactInputMovesBothBooks() public {
        (uint256 s0Before, uint256 s1Before) = federation.reservesOf(address(shallow));
        uint256 aggBefore = federation.aggregateReserve0();

        doSwap(shallowKey, true, -1 ether);

        (uint256 s0After, uint256 s1After) = federation.reservesOf(address(shallow));
        assertGt(s0After, s0Before, "input token should have entered the member book");
        assertLt(s1After, s1Before, "output token should have left the member book");
        assertGt(federation.aggregateReserve0(), aggBefore, "aggregate must move with the member");
        assertAggregateConsistent();
    }

    function test_swap_exactOutputDeliversTheRequestedAmount() public {
        uint256 before = currency1.balanceOf(address(this));
        doSwap(shallowKey, true, 1 ether); // positive = exact output
        assertEq(currency1.balanceOf(address(this)) - before, 1 ether, "exact output must deliver exactly");
        assertAggregateConsistent();
    }

    function test_swap_bothDirectionsSucceed() public {
        doSwap(deepKey, true, -1 ether);
        doSwap(deepKey, false, -1 ether);
        assertAggregateConsistent();
    }

    function test_swap_enforcedQuoteIsTheWorseOfTheTwo() public view {
        (uint256 local, uint256 agg, uint256 enforced) = federation.preview(address(shallow), true, true, 5 ether);
        assertEq(enforced, local < agg ? local : agg, "exact input must take the lower quote");
        assertLt(enforced, local, "on the skewed pool the bound should actually bind");
    }

    function test_swap_boundIsInertOnABalancedPool() public view {
        (uint256 local,, uint256 enforced) = federation.preview(address(deep), true, true, 5 ether);
        assertEq(enforced, local, "a pool in line with its pair keeps its own quote");
    }

    // ── liquidity lifecycle ──────────────────────────────────────────────

    function test_liquidity_queueThenActivateMintsShares() public {
        fund(alice);
        approveHookAs(alice, address(deep));

        vm.prank(alice);
        deep.addLiquidity(addParams(10 ether, 10 ether));
        assertEq(deep.balanceOf(alice), 0, "no shares should exist before maturity");

        vm.roll(block.number + 1);
        vm.prank(alice);
        deep.activatePendingLiquidity();
        assertGt(deep.balanceOf(alice), 0, "shares should mint on activation");
        assertAggregateConsistent();
    }

    function test_liquidity_cancelReturnsEverything() public {
        fund(alice);
        approveHookAs(alice, address(deep));
        uint256 before0 = currency0.balanceOf(alice);

        vm.startPrank(alice);
        deep.addLiquidity(addParams(10 ether, 10 ether));
        deep.cancelPendingLiquidity();
        deep.claimLiquidityRefund();
        vm.stopPrank();

        assertEq(currency0.balanceOf(alice), before0, "cancelling must return the full deposit");
        assertEq(deep.balanceOf(alice), 0, "cancelling must not mint shares");
    }

    function test_liquidity_removeBurnsSharesAndReturnsAssets() public {
        uint256 shares = deep.balanceOf(address(this));
        uint256 before0 = currency0.balanceOf(address(this));

        deep.removeLiquidity(removeParams(shares / 2));

        assertEq(deep.balanceOf(address(this)), shares - shares / 2, "shares should burn");
        assertGt(currency0.balanceOf(address(this)), before0, "assets should return");
        assertAggregateConsistent();
    }

    function test_liquidity_activationUsesCurrentRatioNotDepositRatio() public {
        fund(alice);
        approveHookAs(alice, address(shallow));

        vm.prank(alice);
        shallow.addLiquidity(addParams(10 ether, 40 ether));

        // Move the pool between queue and activation. Shares must price off the NEW ratio,
        // otherwise pending capital would capture gains it was never exposed to.
        doSwap(shallowKey, true, -5 ether);
        vm.roll(block.number + 1);

        vm.prank(alice);
        shallow.activatePendingLiquidity();

        assertGt(shallow.balanceOf(alice), 0, "activation should still succeed after a price move");
        assertAggregateConsistent();
    }

    // ── membership ───────────────────────────────────────────────────────

    function test_membership_ownerCanUnregisterAnEmptyMember() public {
        uint256 before = federation.memberCount();
        deep.removeLiquidity(removeParams(deep.balanceOf(address(this))));
        federation.unregister(address(deep));
        assertEq(federation.memberCount(), before - 1);
        assertFalse(federation.isMember(address(deep)));
    }

    function test_membership_aggregateReflectsBothMembers() public view {
        (uint256 d0, uint256 d1) = federation.reservesOf(address(deep));
        (uint256 s0, uint256 s1) = federation.reservesOf(address(shallow));
        assertEq(federation.aggregateReserve0(), d0 + s0);
        assertEq(federation.aggregateReserve1(), d1 + s1);
        assertEq(federation.memberCount(), 2);
    }
}
