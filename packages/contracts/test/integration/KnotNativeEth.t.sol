// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {KnotFederation} from "../../src/core/KnotFederation.sol";
import {KnotHook} from "../../src/hooks/KnotHook.sol";
import {KnotTestBase} from "../fixtures/KnotTestBase.sol";

contract KnotNativeEthTest is KnotTestBase {
    using CurrencyLibrary for Currency;

    function setUp() public {
        deployFreshManagerAndRouters();
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        currency1 = deployMintAndApproveCurrency();
        federation =
            new KnotFederation(address(manager), address(0), Currency.unwrap(currency1), 997, 1000, 2, address(this));

        hookA = _deployHook(1, "Knot ETH Pool A", "KNOT-ETH-A", 1);
        hookB = _deployHook(2, "Knot ETH Pool B", "KNOT-ETH-B", 1);
        federation.register(address(hookA));
        federation.register(address(hookB));

        (keyA,) = initPool(currency0, currency1, IHooks(address(hookA)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        (keyB,) = initPool(currency0, currency1, IHooks(address(hookB)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        ERC20(Currency.unwrap(currency1)).approve(address(hookA), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(hookB), type(uint256).max);
        vm.deal(address(this), 1_000_000 ether);
        hookA.addLiquidity{value: 1000 ether}(_addParams(1000 ether, 1500 ether));
        hookB.addLiquidity{value: 1000 ether}(_addParams(1000 ether, 500 ether));
        vm.roll(block.number + 1);
        hookA.activatePendingLiquidity();
        hookB.activatePendingLiquidity();
        vm.roll(hookA.liquidityUnlockBlock(address(this)));
    }

    function testFuzz_nativeSwapMatrixMatchesPreviewAndPreservesCustody(
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
        uint256 nativeValue = zeroForOne ? (exactInput ? amount : unspecifiedAmount) : 0;

        _swapWithNativeValue(
            selectedKey,
            zeroForOne,
            exactInput ? -int256(amount) : int256(amount),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            nativeValue
        );

        assertEq(inputBefore - input.balanceOf(address(this)), exactInput ? amount : unspecifiedAmount);
        assertEq(output.balanceOf(address(this)) - outputBefore, exactInput ? unspecifiedAmount : amount);
        _assertAggregateMatchesMembers();
    }

    function test_nativeLiquidityLifecycleReturnsRefundAndWithdrawalToProvider() public {
        address provider = address(0xB0B);
        vm.deal(provider, 200 ether);
        assertTrue(ERC20(Currency.unwrap(currency1)).transfer(provider, 150 ether));
        vm.prank(provider);
        ERC20(Currency.unwrap(currency1)).approve(address(hookA), type(uint256).max);

        vm.prank(provider);
        hookA.addLiquidity{value: 100 ether}(_addParams(100 ether, 150 ether));
        (uint256 pending0, uint256 pending1, uint256 activatesAtBlock) = hookA.pendingLiquidity(provider);
        assertEq(pending0, 100 ether);
        assertEq(pending1, 150 ether);
        assertGt(activatesAtBlock, block.number);

        _swapWithNativeValue(
            keyA, false, -int256(15 ether), PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}), 0
        );
        vm.roll(activatesAtBlock);
        vm.prank(provider);
        hookA.activatePendingLiquidity();

        uint256 shares = hookA.balanceOf(provider);
        (uint256 refund0, uint256 refund1) = hookA.claimableLiquidityRefund(provider);
        assertGt(shares, 0);
        assertGt(refund0, 0, "activation-time repricing creates a native refund");
        uint256 nativeBeforeRefund = provider.balance;
        uint256 tokenBeforeRefund = currency1.balanceOf(provider);
        vm.prank(provider);
        hookA.claimLiquidityRefund();
        assertEq(provider.balance - nativeBeforeRefund, refund0);
        assertEq(currency1.balanceOf(provider) - tokenBeforeRefund, refund1);

        (uint256 reserve0, uint256 reserve1) = federation.reservesOf(address(hookA));
        uint256 supply = hookA.totalSupply();
        uint256 expected0 = shares * reserve0 / supply;
        uint256 expected1 = shares * reserve1 / supply;
        uint256 nativeBeforeWithdrawal = provider.balance;
        uint256 tokenBeforeWithdrawal = currency1.balanceOf(provider);
        vm.roll(hookA.liquidityUnlockBlock(provider));
        vm.prank(provider);
        hookA.removeLiquidity(_removeParams(shares));
        assertEq(provider.balance - nativeBeforeWithdrawal, expected0);
        assertEq(currency1.balanceOf(provider) - tokenBeforeWithdrawal, expected1);
        _assertAggregateMatchesMembers();
    }

    function test_nativePoolManagerClaimsCanFundTheReverseSwap() public {
        uint256 tokenInput = 10 ether;
        (,, uint256 expectedNativeOutput) = federation.preview(address(hookA), false, true, tokenInput);

        _swapWithNativeValue(
            keyA, false, -int256(tokenInput), PoolSwapTest.TestSettings({takeClaims: true, settleUsingBurn: false}), 0
        );
        assertEq(manager.balanceOf(address(this), currency0.toId()), expectedNativeOutput);

        manager.setOperator(address(swapRouter), true);
        _swapWithNativeValue(
            keyA,
            true,
            -int256(expectedNativeOutput),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: true}),
            0
        );
        assertEq(manager.balanceOf(address(this), currency0.toId()), 0);
        _assertAggregateMatchesMembers();
    }

    function test_failedNativeSettlementRollsBackBooksAndClaims() public {
        address unfundedTrader = address(0xBAD);
        (uint256 reserve0Before, uint256 reserve1Before) = federation.reservesOf(address(hookA));
        uint256 aggregate0Before = federation.aggregateReserve0();
        uint256 aggregate1Before = federation.aggregateReserve1();
        uint256 claim0Before = manager.balanceOf(address(hookA), currency0.toId());
        uint256 claim1Before = manager.balanceOf(address(hookA), currency1.toId());

        vm.prank(unfundedTrader);
        vm.expectRevert();
        _swapWithNativeValue(
            keyA, true, -int256(10 ether), PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}), 0
        );

        (uint256 reserve0After, uint256 reserve1After) = federation.reservesOf(address(hookA));
        assertEq(reserve0After, reserve0Before);
        assertEq(reserve1After, reserve1Before);
        assertEq(federation.aggregateReserve0(), aggregate0Before);
        assertEq(federation.aggregateReserve1(), aggregate1Before);
        assertEq(manager.balanceOf(address(hookA), currency0.toId()), claim0Before);
        assertEq(manager.balanceOf(address(hookA), currency1.toId()), claim1Before);
        _assertAggregateMatchesMembers();
    }

    function _swapWithNativeValue(
        PoolKey memory targetKey,
        bool zeroForOne,
        int256 amountSpecified,
        PoolSwapTest.TestSettings memory settings,
        uint256 nativeValue
    ) private returns (BalanceDelta delta) {
        return swapRouter.swap{value: nativeValue}(
            targetKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? SQRT_PRICE_1_2 : SQRT_PRICE_2_1
            }),
            settings,
            bytes("")
        );
    }
}
