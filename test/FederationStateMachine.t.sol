// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseCustomAccounting} from "ozhooks/base/BaseCustomAccounting.sol";
import {Vm} from "forge-std/Vm.sol";
import {KnotFederation} from "../src/KnotFederation.sol";
import {KnotHook} from "../src/KnotHook.sol";
import {KnotTestBase} from "./utils/KnotTestBase.sol";

contract FederatedSwapDriver {
    uint256 private constant MAX_DEADLINE = 12_329_839_823;
    int24 private constant MIN_TICK = -887220;
    int24 private constant MAX_TICK = 887220;
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    KnotFederation public immutable federation;
    KnotHook public immutable hookA;
    KnotHook public immutable hookB;
    PoolSwapTest public immutable router;
    PoolKey internal _keyA;
    PoolKey internal _keyB;

    constructor(
        KnotFederation reserveFederation,
        KnotHook firstHook,
        KnotHook secondHook,
        PoolSwapTest swapRouter,
        PoolKey memory firstKey,
        PoolKey memory secondKey
    ) {
        federation = reserveFederation;
        hookA = firstHook;
        hookB = secondHook;
        router = swapRouter;
        _keyA = firstKey;
        _keyB = secondKey;
        ERC20(Currency.unwrap(firstKey.currency0)).approve(address(swapRouter), type(uint256).max);
        ERC20(Currency.unwrap(firstKey.currency1)).approve(address(swapRouter), type(uint256).max);
        ERC20(Currency.unwrap(firstKey.currency0)).approve(address(firstHook), type(uint256).max);
        ERC20(Currency.unwrap(firstKey.currency1)).approve(address(firstHook), type(uint256).max);
        ERC20(Currency.unwrap(firstKey.currency0)).approve(address(secondHook), type(uint256).max);
        ERC20(Currency.unwrap(firstKey.currency1)).approve(address(secondHook), type(uint256).max);
    }

    function swap(uint8 route, uint96 rawAmount) external {
        bool useA = route & 1 == 0;
        bool zeroForOne = route & 2 == 0;
        bool exactInput = route & 4 == 0;
        KnotHook selectedHook = useA ? hookA : hookB;
        PoolKey memory selectedKey = useA ? _keyA : _keyB;
        (uint256 reserve0, uint256 reserve1) = federation.reservesOf(address(selectedHook));
        uint256 amount;

        if (exactInput) {
            amount = _bound(uint256(rawAmount), 1e6, 25 ether);
        } else {
            uint256 reserveOut = zeroForOne ? reserve1 : reserve0;
            if (reserveOut <= 20e6) return;
            amount = _bound(uint256(rawAmount), 1e6, reserveOut / 20);
        }

        router.swap(
            selectedKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: exactInput ? -int256(amount) : int256(amount),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            bytes("")
        );
    }

    function queueLiquidity(uint8 route, uint96 rawAmount0, uint96 rawAmount1) external {
        KnotHook selectedHook = route & 1 == 0 ? hookA : hookB;
        (,, uint256 activatesAtBlock) = selectedHook.pendingLiquidity(address(this));
        if (activatesAtBlock != 0) return;

        (uint256 refund0, uint256 refund1) = selectedHook.claimableLiquidityRefund(address(this));
        if (refund0 != 0 || refund1 != 0) {
            selectedHook.claimLiquidityRefund();
        }

        uint256 amount0 = _bound(uint256(rawAmount0), 1e12, 5 ether);
        uint256 amount1 = _bound(uint256(rawAmount1), 1e12, 5 ether);
        BaseCustomAccounting.AddLiquidityParams memory params = BaseCustomAccounting.AddLiquidityParams(
            amount0, amount1, 0, 0, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0)
        );
        selectedHook.addLiquidity(params);
    }

    function matureAndActivate(uint8 route) external {
        KnotHook selectedHook = route & 1 == 0 ? hookA : hookB;
        (,, uint256 activatesAtBlock) = selectedHook.pendingLiquidity(address(this));
        if (activatesAtBlock == 0) return;
        if (block.number < activatesAtBlock) VM.roll(activatesAtBlock);
        selectedHook.activatePendingLiquidity();
    }

    function cancelAndClaim(uint8 route) external {
        KnotHook selectedHook = route & 1 == 0 ? hookA : hookB;
        (,, uint256 activatesAtBlock) = selectedHook.pendingLiquidity(address(this));
        if (activatesAtBlock != 0) {
            selectedHook.cancelPendingLiquidity();
        }
        (uint256 refund0, uint256 refund1) = selectedHook.claimableLiquidityRefund(address(this));
        if (refund0 != 0 || refund1 != 0) {
            selectedHook.claimLiquidityRefund();
        }
    }

    function _bound(uint256 value, uint256 minimum, uint256 maximum) private pure returns (uint256) {
        return minimum + value % (maximum - minimum + 1);
    }
}

contract KnotFederationStateMachineTest is KnotTestBase {
    using CurrencyLibrary for Currency;

    FederatedSwapDriver internal driver;

    uint256 internal initialProductA;
    uint256 internal initialProductB;
    uint256 internal initialAggregateProduct;

    function setUp() public {
        _deployKnotFixture(997, 1000, 2, 1, 1000 ether, 1500 ether, 1000 ether, 500 ether);

        initialProductA = 1000 ether * 1500 ether;
        initialProductB = 1000 ether * 500 ether;
        initialAggregateProduct = 2000 ether * 2000 ether;

        driver = new FederatedSwapDriver(federation, hookA, hookB, swapRouter, keyA, keyB);
        assertTrue(ERC20(Currency.unwrap(currency0)).transfer(address(driver), 1_000_000 ether));
        assertTrue(ERC20(Currency.unwrap(currency1)).transfer(address(driver), 1_000_000 ether));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = FederatedSwapDriver.swap.selector;
        selectors[1] = FederatedSwapDriver.queueLiquidity.selector;
        selectors[2] = FederatedSwapDriver.matureAndActivate.selector;
        selectors[3] = FederatedSwapDriver.cancelAndClaim.selector;
        targetContract(address(driver));
        targetSelector(FuzzSelector({addr: address(driver), selectors: selectors}));
    }

    function invariant_aggregateAlwaysEqualsMemberBooks() public view {
        (uint256 a0, uint256 a1) = federation.reservesOf(address(hookA));
        (uint256 b0, uint256 b1) = federation.reservesOf(address(hookB));
        assertEq(federation.aggregateReserve0(), a0 + b0);
        assertEq(federation.aggregateReserve1(), a1 + b1);
    }

    function invariant_everyMemberBookIsExactlyBackedByPoolManagerClaims() public view {
        (uint256 a0, uint256 a1) = federation.reservesOf(address(hookA));
        (uint256 b0, uint256 b1) = federation.reservesOf(address(hookB));
        assertEq(manager.balanceOf(address(hookA), currency0.toId()), a0 + hookA.inactiveAssets0());
        assertEq(manager.balanceOf(address(hookA), currency1.toId()), a1 + hookA.inactiveAssets1());
        assertEq(manager.balanceOf(address(hookB), currency0.toId()), b0 + hookB.inactiveAssets0());
        assertEq(manager.balanceOf(address(hookB), currency1.toId()), b1 + hookB.inactiveAssets1());
    }

    function invariant_localAndAggregateProductsNeverFallAcrossSwapSequences() public view {
        (uint256 a0, uint256 a1) = federation.reservesOf(address(hookA));
        (uint256 b0, uint256 b1) = federation.reservesOf(address(hookB));
        assertGe(a0 * a1, initialProductA);
        assertGe(b0 * b1, initialProductB);
        assertGe(federation.aggregateReserve0() * federation.aggregateReserve1(), initialAggregateProduct);
    }

    function invariant_inactiveAssetsExactlyBackPendingAndRefunds() public view {
        _assertLifecycleTotals(hookA, address(driver));
        _assertLifecycleTotals(hookB, address(driver));
    }

    function _assertLifecycleTotals(KnotHook hook, address provider) private view {
        (uint256 pending0, uint256 pending1, uint256 activatesAtBlock) = hook.pendingLiquidity(provider);
        (uint256 refund0, uint256 refund1) = hook.claimableLiquidityRefund(provider);
        assertEq(hook.inactiveAssets0(), pending0 + refund0);
        assertEq(hook.inactiveAssets1(), pending1 + refund1);
        if (activatesAtBlock == 0) {
            assertEq(pending0, 0);
            assertEq(pending1, 0);
        }
    }
}
