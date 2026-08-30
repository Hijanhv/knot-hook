// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseCustomAccounting} from "ozhooks/base/BaseCustomAccounting.sol";
import {HookTest} from "oztest/utils/HookTest.sol";
import {KnotFederation} from "../../src/KnotFederation.sol";
import {KnotHook} from "../../src/KnotHook.sol";

abstract contract KnotTestBase is HookTest {
    using CurrencyLibrary for Currency;

    uint256 internal constant MAX_DEADLINE = 12_329_839_823;
    int24 internal constant MIN_TICK = -887220;
    int24 internal constant MAX_TICK = 887220;
    uint160 internal constant REQUIRED_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );

    KnotFederation internal federation;
    KnotHook internal hookA;
    KnotHook internal hookB;
    PoolKey internal keyA;
    PoolKey internal keyB;

    function _deployKnotFixture(
        uint256 feeNumerator,
        uint256 feeDenominator,
        uint256 maxMembers,
        uint256 maturityBlocks,
        uint256 reserveA0,
        uint256 reserveA1,
        uint256 reserveB0,
        uint256 reserveB1
    ) internal {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        federation = new KnotFederation(
            Currency.unwrap(currency0),
            Currency.unwrap(currency1),
            feeNumerator,
            feeDenominator,
            maxMembers,
            address(this)
        );

        hookA = _deployHook(1, "Knot Pool A", "KNOT-A", maturityBlocks);
        hookB = _deployHook(2, "Knot Pool B", "KNOT-B", maturityBlocks);
        federation.register(address(hookA));
        federation.register(address(hookB));

        (keyA,) = initPool(currency0, currency1, IHooks(address(hookA)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        (keyB,) = initPool(currency0, currency1, IHooks(address(hookB)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        _approveHook(hookA);
        _approveHook(hookB);
        hookA.addLiquidity(_addParams(reserveA0, reserveA1));
        hookB.addLiquidity(_addParams(reserveB0, reserveB1));
        vm.roll(block.number + maturityBlocks);
        hookA.activatePendingLiquidity();
        hookB.activatePendingLiquidity();
    }

    function _deployHook(uint256 discriminator, string memory name, string memory symbol, uint256 maturityBlocks)
        internal
        returns (KnotHook hook)
    {
        hook = KnotHook(payable(address(REQUIRED_FLAGS | uint160(discriminator << 80))));
        deployCodeTo(
            "src/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), name, symbol, maturityBlocks),
            address(hook)
        );
    }

    function _swap(PoolKey memory targetKey, bool zeroForOne, int256 amountSpecified)
        internal
        returns (BalanceDelta delta)
    {
        return _swapWithSettings(
            targetKey,
            zeroForOne,
            amountSpecified,
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false})
        );
    }

    function _swapWithSettings(
        PoolKey memory targetKey,
        bool zeroForOne,
        int256 amountSpecified,
        PoolSwapTest.TestSettings memory settings
    ) internal returns (BalanceDelta delta) {
        return swapRouter.swap(
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

    function _addParams(uint256 amount0, uint256 amount1)
        internal
        pure
        returns (BaseCustomAccounting.AddLiquidityParams memory)
    {
        return BaseCustomAccounting.AddLiquidityParams(
            amount0, amount1, amount0, amount1, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0)
        );
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

    function _removeParams(uint256 shares) internal pure returns (BaseCustomAccounting.RemoveLiquidityParams memory) {
        return _removeParams(shares, 0, 0);
    }

    function _removeParams(uint256 shares, uint256 amount0Min, uint256 amount1Min)
        internal
        pure
        returns (BaseCustomAccounting.RemoveLiquidityParams memory)
    {
        return BaseCustomAccounting.RemoveLiquidityParams(
            shares, amount0Min, amount1Min, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0)
        );
    }

    function _fundAndApproveLiquidity(address provider, KnotHook hook, uint256 amount0, uint256 amount1) internal {
        assertTrue(ERC20(Currency.unwrap(currency0)).transfer(provider, amount0));
        assertTrue(ERC20(Currency.unwrap(currency1)).transfer(provider, amount1));
        vm.startPrank(provider);
        ERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
        vm.stopPrank();
    }

    function _fundAndApproveTrader(address trader, uint256 amount0, uint256 amount1) internal {
        if (amount0 != 0) assertTrue(ERC20(Currency.unwrap(currency0)).transfer(trader, amount0));
        if (amount1 != 0) assertTrue(ERC20(Currency.unwrap(currency1)).transfer(trader, amount1));
        vm.startPrank(trader);
        ERC20(Currency.unwrap(currency0)).approve(address(swapRouter), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _approveHook(KnotHook hook) private {
        ERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
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
