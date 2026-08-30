// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BaseCustomAccounting} from "ozhooks/base/BaseCustomAccounting.sol";
import {KnotFederation} from "../src/KnotFederation.sol";
import {KnotHook} from "../src/KnotHook.sol";
import {KnotTestBase} from "./utils/KnotTestBase.sol";

contract KnotHookTest is KnotTestBase {
    using CurrencyLibrary for Currency;

    function setUp() public {
        _deployKnotFixture(997, 1000, 3, 1, 1000 ether, 1500 ether, 1000 ether, 500 ether);
    }

    function test_exactInputUsesTheLessFavorableOfLocalAndAggregateQuotes() public {
        uint256 amountIn = 10 ether;
        (uint256 localQuote, uint256 aggregateQuote, uint256 knotQuote) =
            federation.preview(address(hookA), true, true, amountIn);
        assertGt(localQuote, aggregateQuote, "pool A is locally too favorable");
        assertEq(knotQuote, aggregateQuote, "aggregate reserve state clips output");

        uint256 beforeOutput = currency1.balanceOf(address(this));
        _swap(keyA, true, -int256(amountIn));
        assertEq(currency1.balanceOf(address(this)) - beforeOutput, knotQuote);
        _assertAggregateMatchesMembers();
    }

    function test_exactOutputUsesTheMoreExpensiveOfLocalAndAggregateQuotes() public {
        uint256 amountOut = 10 ether;
        (uint256 localInput, uint256 aggregateInput, uint256 knotInput) =
            federation.preview(address(hookA), true, false, amountOut);
        assertLt(localInput, aggregateInput, "pool A is locally too cheap");
        assertEq(knotInput, aggregateInput, "aggregate reserve state raises required input");

        uint256 beforeInput = currency0.balanceOf(address(this));
        _swap(keyA, true, int256(amountOut));
        assertEq(beforeInput - currency0.balanceOf(address(this)), knotInput);
        _assertAggregateMatchesMembers();
    }

    function test_roundTripPaysForTheFederationWedgeAndFees() public {
        uint256 starting0 = currency0.balanceOf(address(this));
        uint256 starting1 = currency1.balanceOf(address(this));
        uint256 input0 = 10 ether;

        _swap(keyA, true, -int256(input0));
        uint256 bought1 = currency1.balanceOf(address(this)) - starting1;
        _swap(keyA, false, -int256(bought1));

        assertLt(currency0.balanceOf(address(this)), starting0, "round trip cannot create token0");
        assertEq(currency1.balanceOf(address(this)), starting1, "all bought token1 was reversed");
        _assertAggregateMatchesMembers();
    }

    function test_poolManagerClaimSettlementModesPreserveFederationCustody() public {
        uint256 inputAmount = 10 ether;
        (,, uint256 expectedOutput) = federation.preview(address(hookA), true, true, inputAmount);

        _swapWithSettings(
            keyA, true, -int256(inputAmount), PoolSwapTest.TestSettings({takeClaims: true, settleUsingBurn: false})
        );
        assertEq(manager.balanceOf(address(this), currency1.toId()), expectedOutput);

        manager.setOperator(address(swapRouter), true);
        _swapWithSettings(
            keyA, false, -int256(expectedOutput), PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: true})
        );
        assertEq(manager.balanceOf(address(this), currency1.toId()), 0);
        _assertAggregateMatchesMembers();
    }

    function test_liquiditySharesAndAggregateBookMoveTogether() public {
        uint256 supplyBefore = hookA.totalSupply();
        uint256 aggregate0Before = federation.aggregateReserve0();
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        assertEq(hookA.totalSupply(), supplyBefore, "immature capital receives no shares");
        (,, uint256 activatesAtBlock) = hookA.pendingLiquidity(address(this));
        assertGt(activatesAtBlock, block.number);
        assertEq(federation.aggregateReserve0(), aggregate0Before, "immature liquidity is not globally active");

        _swap(keyA, true, -int256(1 ether));
        vm.roll(block.number + 1);
        hookA.activatePendingLiquidity();
        uint256 mintedShares = hookA.totalSupply() - supplyBefore;
        assertGt(mintedShares, 0);
        _assertAggregateMatchesMembers();

        uint256 token0Before = currency0.balanceOf(address(this));
        hookA.removeLiquidity(_removeParams(mintedShares));
        assertEq(hookA.totalSupply(), supplyBefore);
        assertGt(currency0.balanceOf(address(this)) - token0Before, 0);
        _assertAggregateMatchesMembers();
    }

    function test_unbalancedDepositUsesExistingRatioAndLeavesUnusedTokensWithLp() public {
        uint256 token0Before = currency0.balanceOf(address(this));
        uint256 token1Before = currency1.balanceOf(address(this));
        uint256 supplyBefore = hookA.totalSupply();

        hookA.addLiquidity(_addParamsLoose(100 ether, 300 ether));

        assertEq(hookA.totalSupply(), supplyBefore);
        assertEq(token0Before - currency0.balanceOf(address(this)), 100 ether);
        assertEq(token1Before - currency1.balanceOf(address(this)), 150 ether);
        vm.roll(block.number + 1);
        hookA.activatePendingLiquidity();
        assertEq(hookA.totalSupply(), supplyBefore + 100 ether);
        _assertAggregateMatchesMembers();
    }

    function test_liquidityCannotActivateInsideItsDepositBlock() public {
        hookA.addLiquidity(_addParams(100 ether, 150 ether));

        vm.expectRevert(KnotHook.LiquidityNotMature.selector);
        hookA.activatePendingLiquidity();

        uint256 outputBefore = currency1.balanceOf(address(this));
        _swap(keyA, true, -int256(1 ether));
        assertGt(currency1.balanceOf(address(this)) - outputBefore, 0, "pending request cannot stop swaps");
        hookA.removeLiquidity(_removeParams(1 ether));

        vm.roll(block.number + 1);
        hookA.activatePendingLiquidity();
        _assertAggregateMatchesMembers();
    }

    function test_onlyFederationOwnerCanSeedAnEmptyMember() public {
        KnotHook emptyHook = _deployHook(3, "Knot Pool C", "KNOT-C", 1);
        federation.register(address(emptyHook));
        initPool(currency0, currency1, IHooks(address(emptyHook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        address attacker = address(0xA77AC);
        vm.prank(attacker);
        vm.expectRevert(KnotHook.OnlyInitialLiquidityProvider.selector);
        emptyHook.addLiquidity(_addParams(1 ether, 1 ether));
        assertEq(emptyHook.totalSupply(), 0);
        (,, uint256 activatesAtBlock) = emptyHook.pendingLiquidity(attacker);
        assertEq(activatesAtBlock, 0);
    }

    function test_permissionlessProviderCanQueueWithoutBlockingSwapsOrWithdrawals() public {
        address provider = address(0xA77AC);
        _fundAndApproveLiquidity(provider, hookA, 2 ether, 2 ether);
        vm.prank(provider);
        hookA.addLiquidity(_addParamsLoose(1 ether, 1 ether));

        (,, uint256 activatesAtBlock) = hookA.pendingLiquidity(provider);
        assertGt(activatesAtBlock, block.number);
        assertEq(hookA.balanceOf(provider), 0, "pending provider has no active stake");
        uint256 outputBefore = currency1.balanceOf(address(this));
        _swap(keyA, true, -int256(1 ether));
        assertGt(currency1.balanceOf(address(this)) - outputBefore, 0, "permissionless queue cannot stop swaps");
        hookA.removeLiquidity(_removeParams(1 ether));
        _assertAggregateMatchesMembers();
    }

    function test_activationUsesCurrentRatioAndRefundsOriginalProvider() public {
        address provider = address(0xB0B);
        _fundAndApproveLiquidity(provider, hookA, 100 ether, 150 ether);
        vm.prank(provider);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));

        _swap(keyA, true, -int256(25 ether));
        vm.roll(block.number + 1);
        vm.prank(provider);
        hookA.activatePendingLiquidity();

        assertGt(hookA.balanceOf(provider), 0);
        (uint256 refund0, uint256 refund1) = hookA.claimableLiquidityRefund(provider);
        assertGt(refund0 + refund1, 0, "activation-time ratio returns the excess");

        uint256 provider0Before = currency0.balanceOf(provider);
        uint256 provider1Before = currency1.balanceOf(provider);
        vm.prank(provider);
        hookA.claimLiquidityRefund();
        assertEq(currency0.balanceOf(provider) - provider0Before, refund0);
        assertEq(currency1.balanceOf(provider) - provider1Before, refund1);
        _assertAggregateMatchesMembers();
    }

    function test_multipleProvidersQueueIndependentlyAndCannotFreezePool() public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        _fundAndApproveLiquidity(alice, hookA, 100 ether, 150 ether);
        _fundAndApproveLiquidity(bob, hookA, 100 ether, 150 ether);

        vm.prank(alice);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        vm.prank(bob);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        (,, uint256 aliceActivation) = hookA.pendingLiquidity(alice);
        (,, uint256 bobActivation) = hookA.pendingLiquidity(bob);
        assertGt(aliceActivation, block.number);
        assertGt(bobActivation, block.number);

        _swap(keyA, false, -int256(2 ether));
        hookA.removeLiquidity(_removeParams(1 ether));

        vm.roll(block.number + 1);
        vm.prank(bob);
        hookA.activatePendingLiquidity();
        vm.prank(alice);
        hookA.activatePendingLiquidity();
        (,, aliceActivation) = hookA.pendingLiquidity(alice);
        (,, bobActivation) = hookA.pendingLiquidity(bob);
        assertEq(aliceActivation, 0);
        assertEq(bobActivation, 0);
        assertGt(hookA.balanceOf(alice), 0);
        assertGt(hookA.balanceOf(bob), 0);
        _assertAggregateMatchesMembers();
    }

    function test_cancelReturnsAssetsOnlyToOriginalProvider() public {
        address provider = address(0xB0B);
        address attacker = address(0xA77AC);
        _fundAndApproveLiquidity(provider, hookA, 100 ether, 150 ether);
        vm.prank(provider);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));

        vm.prank(attacker);
        vm.expectRevert(KnotHook.NoPendingLiquidity.selector);
        hookA.cancelPendingLiquidity();

        vm.prank(provider);
        hookA.cancelPendingLiquidity();
        (,, uint256 activatesAtBlock) = hookA.pendingLiquidity(provider);
        assertEq(activatesAtBlock, 0);
        vm.prank(attacker);
        vm.expectRevert(KnotHook.NoLiquidityRefund.selector);
        hookA.claimLiquidityRefund();

        uint256 provider0Before = currency0.balanceOf(provider);
        uint256 provider1Before = currency1.balanceOf(provider);
        vm.prank(provider);
        hookA.claimLiquidityRefund();
        assertEq(currency0.balanceOf(provider) - provider0Before, 100 ether);
        assertEq(currency1.balanceOf(provider) - provider1Before, 150 ether);
        _assertAggregateMatchesMembers();
    }

    function test_providerMustResolveExistingRequestBeforeQueueingAgain() public {
        address provider = address(0xB0B);
        _fundAndApproveLiquidity(provider, hookA, 200 ether, 300 ether);
        vm.startPrank(provider);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        vm.expectRevert(KnotHook.PendingLiquidityExists.selector);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        vm.stopPrank();
    }

    function test_providerMustClaimRefundBeforeQueueingAgain() public {
        address provider = address(0xB0B);
        _fundAndApproveLiquidity(provider, hookA, 200 ether, 300 ether);
        vm.startPrank(provider);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        hookA.cancelPendingLiquidity();
        vm.expectRevert(KnotHook.UnclaimedLiquidityRefund.selector);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));

        hookA.claimLiquidityRefund();
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        vm.stopPrank();
    }

    function test_onlyFederationOwnerCanInitializeARegisteredMember() public {
        KnotHook emptyHook = _deployHook(3, "Knot Pool C", "KNOT-C", 1);
        federation.register(address(emptyHook));

        PoolKey memory attemptedKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(emptyHook))
        });
        vm.prank(address(0xA77AC));
        vm.expectRevert();
        manager.initialize(attemptedKey, SQRT_PRICE_1_1);

        initPool(currency0, currency1, IHooks(address(emptyHook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        assertEq(address(emptyHook.poolKey().hooks), address(emptyHook));
    }

    function test_federationEnforcesConfiguredMemberLimit() public {
        KnotHook thirdHook = _deployHook(3, "Knot Pool C", "KNOT-C", 1);
        federation.register(address(thirdHook));

        KnotHook fourthHook = _deployHook(4, "Knot Pool D", "KNOT-D", 1);
        vm.expectRevert(KnotFederation.MemberLimitReached.selector);
        federation.register(address(fourthHook));
        assertEq(federation.memberCount(), federation.maxMembers());
    }

    function test_fullWithdrawalRemovesOnlyThatMemberFromAggregate() public {
        uint256 allShares = hookA.balanceOf(address(this));
        hookA.removeLiquidity(_removeParams(allShares));

        (uint256 a0, uint256 a1) = federation.reservesOf(address(hookA));
        (uint256 b0, uint256 b1) = federation.reservesOf(address(hookB));
        assertEq(a0, 0);
        assertEq(a1, 0);
        assertEq(federation.aggregateReserve0(), b0);
        assertEq(federation.aggregateReserve1(), b1);
        assertEq(manager.balanceOf(address(hookA), currency0.toId()), 0);
        assertEq(manager.balanceOf(address(hookA), currency1.toId()), 0);
    }

    function test_emptyMemberCanExitAndReleaseItsBoundedSlot() public {
        vm.expectRevert(KnotFederation.MemberNotEmpty.selector);
        federation.unregister(address(hookA));

        hookA.removeLiquidity(_removeParams(hookA.balanceOf(address(this))));
        federation.unregister(address(hookA));

        assertFalse(federation.isMember(address(hookA)));
        assertEq(federation.memberCount(), 1);
        (uint256 b0, uint256 b1) = federation.reservesOf(address(hookB));
        assertEq(federation.aggregateReserve0(), b0);
        assertEq(federation.aggregateReserve1(), b1);
    }

    function test_abandonedPendingRequestCannotHoldFederationSlot() public {
        address provider = address(0xB0B);
        _fundAndApproveLiquidity(provider, hookA, 100 ether, 150 ether);
        vm.prank(provider);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));

        hookA.removeLiquidity(_removeParams(hookA.balanceOf(address(this))));
        federation.unregister(address(hookA));
        assertFalse(federation.isMember(address(hookA)));

        vm.expectRevert(KnotHook.InactiveMember.selector);
        hookA.addLiquidity(_addParams(1 ether, 1 ether));

        vm.roll(block.number + 1);
        vm.prank(provider);
        vm.expectRevert(KnotFederation.NotMember.selector);
        hookA.activatePendingLiquidity();

        vm.startPrank(provider);
        hookA.cancelPendingLiquidity();
        uint256 token0Before = currency0.balanceOf(provider);
        uint256 token1Before = currency1.balanceOf(provider);
        hookA.claimLiquidityRefund();
        vm.stopPrank();
        assertEq(currency0.balanceOf(provider) - token0Before, 100 ether);
        assertEq(currency1.balanceOf(provider) - token1Before, 150 ether);
    }

    function test_failedSettlementRollsBackBothReserveBooksAndClaims() public {
        (uint256 a0Before, uint256 a1Before) = federation.reservesOf(address(hookA));
        uint256 aggregate0Before = federation.aggregateReserve0();
        uint256 aggregate1Before = federation.aggregateReserve1();
        uint256 claim0Before = manager.balanceOf(address(hookA), currency0.toId());
        uint256 claim1Before = manager.balanceOf(address(hookA), currency1.toId());

        vm.prank(address(0xBAD));
        vm.expectRevert();
        _swap(keyA, true, -int256(10 ether));

        (uint256 a0After, uint256 a1After) = federation.reservesOf(address(hookA));
        assertEq(a0After, a0Before);
        assertEq(a1After, a1Before);
        assertEq(federation.aggregateReserve0(), aggregate0Before);
        assertEq(federation.aggregateReserve1(), aggregate1Before);
        assertEq(manager.balanceOf(address(hookA), currency0.toId()), claim0Before);
        assertEq(manager.balanceOf(address(hookA), currency1.toId()), claim1Before);
        _assertAggregateMatchesMembers();
    }

    function test_liquiditySlippageFailuresRollBackEveryLedger() public {
        (uint256 reserve0Before, uint256 reserve1Before) = federation.reservesOf(address(hookA));
        uint256 supplyBefore = hookA.totalSupply();
        uint256 claim0Before = manager.balanceOf(address(hookA), currency0.toId());
        uint256 claim1Before = manager.balanceOf(address(hookA), currency1.toId());

        BaseCustomAccounting.AddLiquidityParams memory add = _addParamsLoose(100 ether, 150 ether);
        add.amount0Min = 100 ether + 1;
        vm.expectRevert(BaseCustomAccounting.TooMuchSlippage.selector);
        hookA.addLiquidity(add);

        vm.expectRevert(BaseCustomAccounting.TooMuchSlippage.selector);
        hookA.removeLiquidity(_removeParams(1 ether, 1 ether + 1, 0));

        (uint256 reserve0After, uint256 reserve1After) = federation.reservesOf(address(hookA));
        (,, uint256 activatesAtBlock) = hookA.pendingLiquidity(address(this));
        assertEq(reserve0After, reserve0Before);
        assertEq(reserve1After, reserve1Before);
        assertEq(hookA.totalSupply(), supplyBefore);
        assertEq(activatesAtBlock, 0);
        assertEq(manager.balanceOf(address(hookA), currency0.toId()), claim0Before);
        assertEq(manager.balanceOf(address(hookA), currency1.toId()), claim1Before);
        _assertAggregateMatchesMembers();
    }

    function test_onlyRegisteredHooksCanChangeFederationState() public {
        vm.expectRevert(KnotFederation.NotMember.selector);
        federation.adjustLiquidity(1, 1);
        vm.expectRevert(KnotFederation.NotMember.selector);
        federation.executeSwap(true, true, 1 ether);
    }

    function test_duplicateMembershipIsRejected() public {
        vm.expectRevert(KnotFederation.AlreadyMember.selector);
        federation.register(address(hookA));
    }

    function test_nonHookCannotBeRegisteredEvenByOwner() public {
        vm.expectRevert(KnotFederation.InvalidMember.selector);
        federation.register(address(0xBEEF));
    }

    function test_initialQuoteMatrixExercisesBothLocalAndAggregateBounds() public view {
        for (uint256 memberIndex; memberIndex < 2; memberIndex++) {
            KnotHook selectedHook = memberIndex == 0 ? hookA : hookB;
            for (uint256 directionIndex; directionIndex < 2; directionIndex++) {
                bool zeroForOne = directionIndex == 0;
                bool aggregateStrict = (memberIndex == 0) == zeroForOne;
                for (uint256 modeIndex; modeIndex < 2; modeIndex++) {
                    bool exactInput = modeIndex == 0;
                    (uint256 localQuote, uint256 aggregateQuote, uint256 knotQuote) =
                        federation.preview(address(selectedHook), zeroForOne, exactInput, 10 ether);
                    uint256 expected = aggregateStrict ? aggregateQuote : localQuote;
                    assertEq(knotQuote, expected);
                    if (exactInput) {
                        assertEq(aggregateStrict, aggregateQuote < localQuote);
                    } else {
                        assertEq(aggregateStrict, aggregateQuote > localQuote);
                    }
                }
            }
        }
    }

    function testFuzz_liveSwapMatrixMatchesPreviewAndPreservesCustody(
        uint96 rawAmount,
        bool useA,
        bool zeroForOne,
        bool exactInput
    ) public {
        KnotHook selectedHook = useA ? hookA : hookB;
        PoolKey memory selectedKey = useA ? keyA : keyB;
        (uint256 reserve0, uint256 reserve1) = federation.reservesOf(address(selectedHook));
        uint256 reserveOut = zeroForOne ? reserve1 : reserve0;
        uint256 amount =
            exactInput ? bound(uint256(rawAmount), 1e6, 25 ether) : bound(uint256(rawAmount), 1e6, reserveOut / 20);
        (,, uint256 unspecifiedAmount) = federation.preview(address(selectedHook), zeroForOne, exactInput, amount);
        Currency input = zeroForOne ? currency0 : currency1;
        Currency output = zeroForOne ? currency1 : currency0;
        uint256 inputBefore = input.balanceOf(address(this));
        uint256 outputBefore = output.balanceOf(address(this));

        _swap(selectedKey, zeroForOne, exactInput ? -int256(amount) : int256(amount));

        assertEq(inputBefore - input.balanceOf(address(this)), exactInput ? amount : unspecifiedAmount);
        assertEq(output.balanceOf(address(this)) - outputBefore, exactInput ? unspecifiedAmount : amount);
        _assertAggregateMatchesMembers();
    }
}
