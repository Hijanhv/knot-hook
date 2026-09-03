// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {CustomRevert} from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BaseFixture} from "../fixtures/BaseFixture.sol";
import {KnotFederation} from "../../src/core/KnotFederation.sol";
import {KnotHook} from "../../src/hooks/KnotHook.sol";
import {KnotMath} from "../../src/libraries/KnotMath.sol";

/// @title Failure paths: every guard, proven to actually guard.
/// @dev A revert that is never tested is a revert you are only assuming exists.
contract FailurePathsTest is BaseFixture {
    // ── access control ───────────────────────────────────────────────────

    function test_revert_nonOwnerCannotRegister() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        federation.register(address(0xdead));
    }

    function test_revert_nonOwnerCannotUnregister() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        federation.unregister(address(deep));
    }

    function test_ownershipTransferRequiresExplicitAcceptance() public {
        federation.transferOwnership(alice);
        assertEq(federation.owner(), address(this));
        assertEq(federation.pendingOwner(), alice);

        vm.prank(alice);
        federation.acceptOwnership();
        assertEq(federation.owner(), alice);
        assertEq(federation.pendingOwner(), address(0));
    }

    function test_revert_ownerCannotRenounceLoadBearingGovernance() public {
        vm.expectRevert(KnotFederation.OwnershipRenunciationDisabled.selector);
        federation.renounceOwnership();
    }

    function test_revert_nonMemberCannotAdjustReserves() public {
        vm.prank(attacker);
        vm.expectRevert(KnotFederation.NotMember.selector);
        federation.adjustLiquidity(1 ether, 1 ether);
    }

    function test_revert_nonMemberCannotExecuteSwap() public {
        vm.prank(attacker);
        vm.expectRevert(KnotFederation.NotMember.selector);
        federation.executeSwap(true, true, 1 ether);
    }

    function test_revert_int256MinimumLiquidityDeltaWithoutNegationOverflow() public {
        vm.prank(address(deep));
        vm.expectRevert(KnotFederation.AmountTooLarge.selector);
        federation.adjustLiquidity(type(int256).min, 0);
    }

    function test_revert_previewOnAnUnregisteredHook() public {
        vm.expectRevert(KnotFederation.NotMember.selector);
        federation.preview(address(0xdead), true, true, 1 ether);
    }

    // ── membership guards ────────────────────────────────────────────────

    function test_revert_duplicateRegistration() public {
        vm.expectRevert(KnotFederation.AlreadyMember.selector);
        federation.register(address(deep));
    }

    function test_revert_registeredMemberWhoseRuntimeCodeChanges() public {
        vm.etch(address(deep), hex"00");

        vm.expectRevert(KnotFederation.InvalidMember.selector);
        federation.preview(address(deep), true, true, 1 ether);

        vm.expectRevert(KnotFederation.InvalidMember.selector);
        vm.prank(address(deep));
        federation.adjustLiquidity(1, 1);
    }

    function test_revert_registeringAnEOA() public {
        vm.expectRevert(KnotFederation.InvalidMember.selector);
        federation.register(alice);
    }

    function test_revert_unregisteringANonMember() public {
        vm.expectRevert(KnotFederation.NotMember.selector);
        federation.unregister(address(0xdead));
    }

    function test_revert_unregisteringAMemberThatStillHoldsReserves() public {
        vm.expectRevert(KnotFederation.MemberNotEmpty.selector);
        federation.unregister(address(deep));
    }

    // ── constructor validation ───────────────────────────────────────────

    function test_revert_poolManagerWithoutCode() public {
        vm.expectRevert(KnotFederation.InvalidPoolManager.selector);
        new KnotFederation(address(0xBEEF), address(0xAAAA), address(0xBBBB), 997, 1000, 4, address(this));
    }

    function test_revert_unsortedCurrencyPair() public {
        vm.expectRevert(KnotFederation.InvalidPair.selector);
        new KnotFederation(address(manager), address(0xBBBB), address(0xAAAA), 997, 1000, 4, address(this));
    }

    function test_revert_equalCurrencies() public {
        vm.expectRevert(KnotFederation.InvalidPair.selector);
        new KnotFederation(address(manager), address(0xAAAA), address(0xAAAA), 997, 1000, 4, address(this));
    }

    function test_revert_feeNumeratorAboveDenominator() public {
        vm.expectRevert(KnotFederation.InvalidFee.selector);
        new KnotFederation(address(manager), address(0xAAAA), address(0xBBBB), 1001, 1000, 4, address(this));
    }

    function test_revert_zeroFeeNumerator() public {
        vm.expectRevert(KnotFederation.InvalidFee.selector);
        new KnotFederation(address(manager), address(0xAAAA), address(0xBBBB), 0, 1000, 4, address(this));
    }

    function test_revert_zeroMemberLimit() public {
        vm.expectRevert(KnotFederation.InvalidMemberLimit.selector);
        new KnotFederation(address(manager), address(0xAAAA), address(0xBBBB), 997, 1000, 0, address(this));
    }

    function test_revert_currencyWithoutCode() public {
        address invalid = address(0xAAAA);
        address valid = Currency.unwrap(currency1);
        (address token0, address token1) = invalid < valid ? (invalid, valid) : (valid, invalid);
        vm.expectRevert(KnotFederation.InvalidCurrency.selector);
        new KnotFederation(address(manager), token0, token1, 997, 1000, 4, address(this));
    }

    function test_revert_zeroLiquidityMaturity() public {
        vm.expectRevert(KnotHook.InvalidLiquidityMaturity.selector);
        deployCodeTo(
            "src/hooks/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Invalid maturity", "BAD", 0),
            address(REQUIRED_FLAGS | uint160(9 << 80))
        );
    }

    // ── pool initialisation ──────────────────────────────────────────────

    function test_revert_staticFeePoolIsRejected() public {
        // Use a fresh registered hook: reusing `deep` would only prove BaseCustomAccounting's
        // one-pool `AlreadyInitialized` guard, not KNOT's fee-mode requirement.
        KnotHook fresh = _deployHook(3, "Knot Static Fee Probe", "KNOT-F");
        federation.register(address(fresh));
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(fresh),
                IHooks.beforeInitialize.selector,
                abi.encodeWithSelector(KnotHook.InvalidPoolFee.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        initPool(currency0, currency1, IHooks(address(fresh)), 3000, SQRT_PRICE_1_1);
    }

    function test_revert_unregisteredHookCannotInitializeEvenWithTheRightPairAndFee() public {
        KnotHook fresh = _deployHook(3, "Knot Inactive Probe", "KNOT-I");
        vm.expectRevert();
        initPool(currency0, currency1, IHooks(address(fresh)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
    }

    // ── liquidity guards ─────────────────────────────────────────────────

    function test_revert_missingApprovalOnDeposit() public {
        deal(Currency.unwrap(currency0), alice, 100 ether);
        deal(Currency.unwrap(currency1), alice, 100 ether);
        // deliberately no approval to the hook
        vm.prank(alice);
        vm.expectRevert();
        deep.addLiquidity(addParams(1 ether, 1 ether));
    }

    /// @dev Dust cannot mint. At seed supply equals reserve0 so 1 wei still buys 1 share; the
    ///      rounding-to-zero case only appears once reserves have grown away from supply, which
    ///      a swap does. Setting that up is the point of the test.
    function test_revert_dustDepositMintsNoShares() public {
        doSwap(deepKey, true, -500 ether); // reserve0 now far exceeds supply
        fund(alice);
        approveHookAs(alice, address(deep));
        vm.prank(alice);
        vm.expectRevert(KnotHook.ZeroShares.selector);
        deep.addLiquidity(addParams(1, 1));
    }

    function test_revert_secondPendingDepositBeforeSettling() public {
        fund(alice);
        approveHookAs(alice, address(deep));
        vm.startPrank(alice);
        deep.addLiquidity(addParams(10 ether, 10 ether));
        vm.expectRevert(KnotHook.PendingLiquidityExists.selector);
        deep.addLiquidity(addParams(10 ether, 10 ether));
        vm.stopPrank();
    }

    function test_revert_activatingBeforeMaturity() public {
        fund(alice);
        approveHookAs(alice, address(deep));
        vm.startPrank(alice);
        deep.addLiquidity(addParams(10 ether, 10 ether));
        vm.expectRevert(KnotHook.LiquidityNotMature.selector);
        deep.activatePendingLiquidity(); // same block
        vm.stopPrank();
    }

    function test_revert_activatingWithNothingPending() public {
        vm.prank(alice);
        vm.expectRevert(KnotHook.NoPendingLiquidity.selector);
        deep.activatePendingLiquidity();
    }

    function test_revert_cancellingWithNothingPending() public {
        vm.prank(alice);
        vm.expectRevert(KnotHook.NoPendingLiquidity.selector);
        deep.cancelPendingLiquidity();
    }

    function test_revert_claimingWithNoRefund() public {
        vm.prank(alice);
        vm.expectRevert(KnotHook.NoLiquidityRefund.selector);
        deep.claimLiquidityRefund();
    }

    /// @dev A holder of zero shares requesting fewer than total supply clears the ZeroShares
    ///      guard and is stopped by the ERC-20 burn instead. Assert the guard that actually
    ///      fires, not the one that looks likely.
    function test_revert_removingMoreSharesThanHeld() public {
        vm.prank(alice); // holds none
        vm.expectRevert(); // ERC20InsufficientBalance
        deep.removeLiquidity(removeParams(1 ether));
    }

    /// @dev The revert surfaces through v4's unlock callback, which `expectRevert` cannot
    ///      match by selector. Catch it and assert the selector directly, which is more precise than a
    ///      bare expectRevert, which would pass on any failure at all.
    function test_revert_removingMoreSharesThanTotalSupply() public {
        try this.tryRemove(deep.totalSupply() + 1) {
            fail();
        } catch (bytes memory err) {
            assertEq(bytes4(err), KnotHook.ZeroShares.selector, "expected ZeroShares");
        }
    }

    function tryRemove(uint256 shares) external {
        deep.removeLiquidity(removeParams(shares));
    }

    function test_revert_removingZeroShares() public {
        vm.expectRevert(KnotHook.ZeroShares.selector);
        deep.removeLiquidity(removeParams(0));
    }

    /// @dev A provider cannot queue a new deposit while an unclaimed refund is outstanding,
    ///      which keeps the inactive-asset accounting single-valued per provider.
    function test_revert_depositingWithAnUnclaimedRefund() public {
        fund(alice);
        approveHookAs(alice, address(deep));
        vm.startPrank(alice);
        deep.addLiquidity(addParams(10 ether, 10 ether));
        deep.cancelPendingLiquidity(); // creates a refund, unclaimed
        vm.expectRevert(KnotHook.UnclaimedLiquidityRefund.selector);
        deep.addLiquidity(addParams(10 ether, 10 ether));
        vm.stopPrank();
    }

    // ── math boundaries ──────────────────────────────────────────────────
    // KnotMath is a library: calling it internally reverts at the same call depth as the
    // cheatcode, which expectRevert cannot observe. MathWrapper forces a real external call.

    function test_revert_quoteWithZeroAmount() public {
        MathWrapper w = new MathWrapper();
        vm.expectRevert(KnotMath.ZeroAmount.selector);
        w.out(0, 100 ether, 100 ether);
    }

    function test_revert_quoteAgainstEmptyReserves() public {
        MathWrapper w = new MathWrapper();
        vm.expectRevert(KnotMath.InsufficientLiquidity.selector);
        w.out(1 ether, 0, 100 ether);
    }

    function test_revert_exactOutputExceedingReserves() public {
        MathWrapper w = new MathWrapper();
        vm.expectRevert(KnotMath.InsufficientLiquidity.selector);
        w.into(200 ether, 100 ether, 100 ether);
    }

    function test_revert_swapDrainingMoreThanThePoolHolds() public {
        vm.expectRevert();
        doSwap(shallowKey, true, 100_000 ether); // exact output far beyond reserves
    }

    /// @dev A failed swap must leave both books untouched, not partially applied.
    function test_failedSwapRollsBackBothBooks() public {
        uint256 a0 = federation.aggregateReserve0();
        uint256 a1 = federation.aggregateReserve1();
        (uint256 s0, uint256 s1) = federation.reservesOf(address(shallow));

        try this.externalSwap() {} catch {}

        assertEq(federation.aggregateReserve0(), a0, "aggregate0 changed on a reverted swap");
        assertEq(federation.aggregateReserve1(), a1, "aggregate1 changed on a reverted swap");
        (uint256 s0After, uint256 s1After) = federation.reservesOf(address(shallow));
        assertEq(s0After, s0);
        assertEq(s1After, s1);
    }

    function externalSwap() external {
        doSwap(shallowKey, true, 100_000 ether);
    }
}

/// @dev Thin external surface over the pure library, so `expectRevert` can see its reverts.
contract MathWrapper {
    function out(uint256 a, uint256 rIn, uint256 rOut) external pure returns (uint256) {
        return KnotMath.amountOut(a, rIn, rOut, 997, 1000);
    }

    function into(uint256 a, uint256 rIn, uint256 rOut) external pure returns (uint256) {
        return KnotMath.amountIn(a, rIn, rOut, 997, 1000);
    }
}
