// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {BaseCustomAccounting} from "ozhooks/base/BaseCustomAccounting.sol";
import {HookTest} from "oztest/utils/HookTest.sol";
import {KnotFederation} from "../src/KnotFederation.sol";
import {KnotHook} from "../src/KnotHook.sol";

/// @title Shared fixture for every Knot test.
///
/// @dev WHY THIS EXISTS
///      Each test file previously rebuilt the same federation, two hooks, two pools and the
///      seed liquidity by hand. That is ~40 lines of setup per file, four near-identical
///      copies, and any change to the lifecycle meant editing all of them. Everything common
///      now lives here, so individual tests are short enough to read in one screen and state
///      exactly one thing.
///
///      Two members with ASYMMETRIC reserves is not a stylistic choice. With one member, or
///      with two balanced members, the aggregate matches the local reserves, `min()` always
///      returns the local quote, and the bound never binds. A symmetric fixture would make
///      every assertion below vacuously true.
abstract contract BaseFixture is HookTest {
    uint256 internal constant MAX_DEADLINE = type(uint256).max;
    int24 internal constant MIN_TICK = -887220;
    int24 internal constant MAX_TICK = 887220;
    uint256 internal constant FEE_NUM = 997;
    uint256 internal constant FEE_DEN = 1000;

    uint160 internal constant REQUIRED_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );

    // Deep pool is balanced; shallow is skewed 1:4 so the bound has something to bind against.
    uint256 internal constant DEEP_0 = 1000 ether;
    uint256 internal constant DEEP_1 = 1000 ether;
    uint256 internal constant SHALLOW_0 = 100 ether;
    uint256 internal constant SHALLOW_1 = 400 ether;

    KnotFederation internal federation;
    KnotHook internal deep;
    KnotHook internal shallow;
    PoolKey internal deepKey;
    PoolKey internal shallowKey;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal attacker = makeAddr("attacker");

    function setUp() public virtual {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        federation = new KnotFederation(
            Currency.unwrap(currency0), Currency.unwrap(currency1), FEE_NUM, FEE_DEN, 4, address(this)
        );

        deep = _deployHook(1, "Knot Deep", "KNOT-D");
        shallow = _deployHook(2, "Knot Shallow", "KNOT-S");
        federation.register(address(deep));
        federation.register(address(shallow));

        (deepKey,) = initPool(currency0, currency1, IHooks(address(deep)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        (shallowKey,) =
            initPool(currency0, currency1, IHooks(address(shallow)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        _approveHook(address(deep));
        _approveHook(address(shallow));

        deep.addLiquidity(addParams(DEEP_0, DEEP_1));
        shallow.addLiquidity(addParams(SHALLOW_0, SHALLOW_1));
        vm.roll(block.number + 1);
        deep.activatePendingLiquidity();
        shallow.activatePendingLiquidity();
    }

    // ── helpers ──────────────────────────────────────────────────────────

    function _deployHook(uint160 slot, string memory name, string memory sym) internal returns (KnotHook h) {
        h = KnotHook(payable(address(REQUIRED_FLAGS | (slot << 80))));
        deployCodeTo("src/KnotHook.sol:KnotHook", abi.encode(address(manager), address(federation), name, sym, 1), address(h));
    }

    function _approveHook(address h) internal {
        ERC20(Currency.unwrap(currency0)).approve(h, type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(h, type(uint256).max);
    }

    /// @dev Funds an actor and approves the router. Approvals to a HOOK are deliberately not
    ///      granted here, so missing-approval failure paths stay testable.
    function fund(address who) internal {
        deal(Currency.unwrap(currency0), who, 10_000 ether);
        deal(Currency.unwrap(currency1), who, 10_000 ether);
        vm.startPrank(who);
        ERC20(Currency.unwrap(currency0)).approve(address(swapRouter), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function approveHookAs(address who, address hook) internal {
        vm.startPrank(who);
        ERC20(Currency.unwrap(currency0)).approve(hook, type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function doSwap(PoolKey memory key, bool zeroForOne, int256 amountSpecified) internal {
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }

    function doSwapAs(address who, PoolKey memory key, bool zeroForOne, int256 amountSpecified) internal {
        vm.prank(who);
        doSwap(key, zeroForOne, amountSpecified);
    }

    function addParams(uint256 a0, uint256 a1) internal pure returns (BaseCustomAccounting.AddLiquidityParams memory) {
        return BaseCustomAccounting.AddLiquidityParams(a0, a1, 0, 0, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0));
    }

    function removeParams(uint256 shares) internal pure returns (BaseCustomAccounting.RemoveLiquidityParams memory) {
        return BaseCustomAccounting.RemoveLiquidityParams(shares, 0, 0, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0));
    }

    /// @dev The invariant every other assertion rests on: the aggregate is exactly the sum of
    ///      its members. If this drifts, every quote derived from it is meaningless.
    function assertAggregateConsistent() internal view {
        (uint256 d0, uint256 d1) = federation.reservesOf(address(deep));
        (uint256 s0, uint256 s1) = federation.reservesOf(address(shallow));
        assertEq(federation.aggregateReserve0(), d0 + s0, "aggregate0 drifted from member books");
        assertEq(federation.aggregateReserve1(), d1 + s1, "aggregate1 drifted from member books");
    }
}
