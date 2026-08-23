// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseCustomAccounting} from "ozhooks/base/BaseCustomAccounting.sol";
import {HookTest} from "oztest/utils/HookTest.sol";
import {KnotFederation} from "../src/KnotFederation.sol";
import {KnotHook} from "../src/KnotHook.sol";

contract KnotHookTest is HookTest {
    using CurrencyLibrary for Currency;

    uint256 private constant MAX_DEADLINE = 12_329_839_823;
    int24 private constant MIN_TICK = -887220;
    int24 private constant MAX_TICK = 887220;
    uint160 private constant REQUIRED_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );

    KnotFederation internal federation;
    KnotHook internal hookA;
    KnotHook internal hookB;
    PoolKey internal keyA;
    PoolKey internal keyB;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        federation =
            new KnotFederation(Currency.unwrap(currency0), Currency.unwrap(currency1), 997, 1000, 3, address(this));

        hookA = KnotHook(payable(address(REQUIRED_FLAGS | uint160(1 << 80))));
        hookB = KnotHook(payable(address(REQUIRED_FLAGS | uint160(2 << 80))));
        deployCodeTo(
            "src/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Knot Pool A", "KNOT-A", 1),
            address(hookA)
        );
        deployCodeTo(
            "src/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Knot Pool B", "KNOT-B", 1),
            address(hookB)
        );
        federation.register(address(hookA));
        federation.register(address(hookB));

        (keyA,) = initPool(currency0, currency1, IHooks(address(hookA)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        (keyB,) = initPool(currency0, currency1, IHooks(address(hookB)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        ERC20(Currency.unwrap(currency0)).approve(address(hookA), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(hookA), type(uint256).max);
        ERC20(Currency.unwrap(currency0)).approve(address(hookB), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(hookB), type(uint256).max);

        hookA.addLiquidity(_addParams(1000 ether, 1500 ether));
        hookB.addLiquidity(_addParams(1000 ether, 500 ether));
        vm.roll(block.number + 1);
        hookA.activatePendingLiquidity();
        hookB.activatePendingLiquidity();
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
        KnotHook emptyHook = KnotHook(payable(address(REQUIRED_FLAGS | uint160(3 << 80))));
        deployCodeTo(
            "src/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Knot Pool C", "KNOT-C", 1),
            address(emptyHook)
        );
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
        _fundAndApprove(provider, hookA, 2 ether, 2 ether);
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
        _fundAndApprove(provider, hookA, 100 ether, 150 ether);
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
        _fundAndApprove(alice, hookA, 100 ether, 150 ether);
        _fundAndApprove(bob, hookA, 100 ether, 150 ether);

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
        _fundAndApprove(provider, hookA, 100 ether, 150 ether);
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
        _fundAndApprove(provider, hookA, 200 ether, 300 ether);
        vm.startPrank(provider);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        vm.expectRevert(KnotHook.PendingLiquidityExists.selector);
        hookA.addLiquidity(_addParams(100 ether, 150 ether));
        vm.stopPrank();
    }

    function test_providerMustClaimRefundBeforeQueueingAgain() public {
        address provider = address(0xB0B);
        _fundAndApprove(provider, hookA, 200 ether, 300 ether);
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
        KnotHook emptyHook = KnotHook(payable(address(REQUIRED_FLAGS | uint160(3 << 80))));
        deployCodeTo(
            "src/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Knot Pool C", "KNOT-C", 1),
            address(emptyHook)
        );
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
        KnotHook thirdHook = KnotHook(payable(address(REQUIRED_FLAGS | uint160(3 << 80))));
        deployCodeTo(
            "src/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Knot Pool C", "KNOT-C", 1),
            address(thirdHook)
        );
        federation.register(address(thirdHook));

        KnotHook fourthHook = KnotHook(payable(address(REQUIRED_FLAGS | uint160(4 << 80))));
        deployCodeTo(
            "src/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Knot Pool D", "KNOT-D", 1),
            address(fourthHook)
        );
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
        _fundAndApprove(provider, hookA, 100 ether, 150 ether);
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

    function test_failedOversizedSwapRollsBackBothReserveBooks() public {
        (uint256 a0Before, uint256 a1Before) = federation.reservesOf(address(hookA));
        uint256 aggregate0Before = federation.aggregateReserve0();
        uint256 aggregate1Before = federation.aggregateReserve1();

        vm.expectRevert();
        _swap(keyA, true, int256(1600 ether));

        (uint256 a0After, uint256 a1After) = federation.reservesOf(address(hookA));
        assertEq(a0After, a0Before);
        assertEq(a1After, a1Before);
        assertEq(federation.aggregateReserve0(), aggregate0Before);
        assertEq(federation.aggregateReserve1(), aggregate1Before);
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

    function testFuzz_quoteNeverBeatsEitherReferenceForExactInput(uint96 rawAmount) public view {
        uint256 amount = bound(uint256(rawAmount), 1e6, 100 ether);
        (uint256 localQuote, uint256 aggregateQuote, uint256 knotQuote) =
            federation.preview(address(hookA), true, true, amount);
        assertLe(knotQuote, localQuote);
        assertLe(knotQuote, aggregateQuote);
    }

    function testFuzz_quoteNeverUnderchargesEitherReferenceForExactOutput(uint96 rawAmount) public view {
        uint256 amount = bound(uint256(rawAmount), 1e6, 100 ether);
        (uint256 localQuote, uint256 aggregateQuote, uint256 knotQuote) =
            federation.preview(address(hookA), true, false, amount);
        assertGe(knotQuote, localQuote);
        assertGe(knotQuote, aggregateQuote);
    }

    function testFuzz_liveExactInputMatchesPreviewAndPreservesCustody(uint96 rawAmount, bool zeroForOne) public {
        uint256 amount = bound(uint256(rawAmount), 1e6, 50 ether);
        (,, uint256 expectedOutput) = federation.preview(address(hookA), zeroForOne, true, amount);
        Currency output = zeroForOne ? currency1 : currency0;
        uint256 outputBefore = output.balanceOf(address(this));

        _swap(keyA, zeroForOne, -int256(amount));

        assertEq(output.balanceOf(address(this)) - outputBefore, expectedOutput);
        _assertAggregateMatchesMembers();
    }

    function _swap(PoolKey memory targetKey, bool zeroForOne, int256 amountSpecified) internal {
        swapRouter.swap(
            targetKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? SQRT_PRICE_1_2 : SQRT_PRICE_2_1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            bytes("")
        );
    }

    function _addParams(uint256 amount0, uint256 amount1)
        internal
        pure
        returns (BaseCustomAccounting.AddLiquidityParams memory)
    {
        return BaseCustomAccounting.AddLiquidityParams(
            amount0, amount1, amount0, amount1, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0)
        );
    }

    function _removeParams(uint256 shares) internal pure returns (BaseCustomAccounting.RemoveLiquidityParams memory) {
        return BaseCustomAccounting.RemoveLiquidityParams(shares, 0, 0, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0));
    }

    function _addParamsLoose(uint256 amount0, uint256 amount1)
        internal
        pure
        returns (BaseCustomAccounting.AddLiquidityParams memory)
    {
        return BaseCustomAccounting.AddLiquidityParams(
            amount0, amount1, 0, 0, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0)
        );
    }

    function _fundAndApprove(address provider, KnotHook hook, uint256 amount0, uint256 amount1) internal {
        assertTrue(ERC20(Currency.unwrap(currency0)).transfer(provider, amount0));
        assertTrue(ERC20(Currency.unwrap(currency1)).transfer(provider, amount1));
        vm.startPrank(provider);
        ERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
        vm.stopPrank();
    }

    function _assertAggregateMatchesMembers() internal view {
        (uint256 a0, uint256 a1) = federation.reservesOf(address(hookA));
        (uint256 b0, uint256 b1) = federation.reservesOf(address(hookB));
        assertEq(federation.aggregateReserve0(), a0 + b0, "aggregate token0");
        assertEq(federation.aggregateReserve1(), a1 + b1, "aggregate token1");
        assertEq(
            manager.balanceOf(address(hookA), currency0.toId()), a0 + hookA.inactiveAssets0(), "pool A token0 claims"
        );
        assertEq(
            manager.balanceOf(address(hookA), currency1.toId()), a1 + hookA.inactiveAssets1(), "pool A token1 claims"
        );
        assertEq(
            manager.balanceOf(address(hookB), currency0.toId()), b0 + hookB.inactiveAssets0(), "pool B token0 claims"
        );
        assertEq(
            manager.balanceOf(address(hookB), currency1.toId()), b1 + hookB.inactiveAssets1(), "pool B token1 claims"
        );
    }
}
