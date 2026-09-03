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
import {KnotFederation} from "../../src/core/KnotFederation.sol";
import {KnotHook} from "../../src/hooks/KnotHook.sol";

/// @dev Fires several swaps inside ONE external call, so every slice shares a transaction.
contract SplitTrader {
    PoolSwapTest private immutable router;
    PoolKey private key;

    constructor(PoolSwapTest r, PoolKey memory k) {
        router = r;
        key = k;
    }

    function splitSwap(bool zeroForOne, int256 total, uint256 slices) external {
        int256 each = total / int256(slices);
        for (uint256 i = 0; i < slices; i++) {
            router.swap(
                key,
                SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: each,
                    sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                }),
                PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
                ""
            );
        }
    }
}

/// @title MEV protection tests for Knot
///
/// @dev WHY THIS FILE EXISTS
///      Knot's claim is narrow and should be tested narrowly: a member pool can never quote more
///      favorably than BOTH its own reserves and the federation's aggregate reserves allow. These
///      tests check that the bound actually binds, that it binds in the attacker's direction, and
///      that the usual evasions do not get around it.
contract MEVProtectionTest is HookTest {
    uint256 private constant MAX_DEADLINE = 12_329_839_823;
    int24 private constant MIN_TICK = -887220;
    int24 private constant MAX_TICK = 887220;
    uint160 private constant FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );

    KnotFederation internal federation;
    KnotHook internal deepPool; // balanced, generous quote in isolation
    KnotHook internal shallowPool; // skewed, the "weak link" an attacker would target
    PoolKey internal deepKey;
    PoolKey internal shallowKey;

    address internal attacker = address(0xA77ACC);

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        federation = new KnotFederation(
            address(manager), Currency.unwrap(currency0), Currency.unwrap(currency1), 997, 1000, 3, address(this)
        );

        deepPool = KnotHook(payable(address(FLAGS | uint160(1 << 80))));
        shallowPool = KnotHook(payable(address(FLAGS | uint160(2 << 80))));
        deployCodeTo(
            "src/hooks/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Deep", "D", 1),
            address(deepPool)
        );
        deployCodeTo(
            "src/hooks/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Shallow", "S", 1),
            address(shallowPool)
        );
        federation.register(address(deepPool));
        federation.register(address(shallowPool));

        (deepKey,) =
            initPool(currency0, currency1, IHooks(address(deepPool)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        (shallowKey,) =
            initPool(currency0, currency1, IHooks(address(shallowPool)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        _approve(address(deepPool));
        _approve(address(shallowPool));

        // Deliberately asymmetric: the shallow pool is rich in currency1, so in isolation it would
        // hand a currency0 seller an unusually generous amount of currency1. That is exactly the
        // "weak link" Knot claims to close.
        deepPool.addLiquidity(_add(1000 ether, 1000 ether));
        shallowPool.addLiquidity(_add(100 ether, 400 ether));
        vm.roll(block.number + 1);
        deepPool.activatePendingLiquidity();
        shallowPool.activatePendingLiquidity();
        vm.roll(deepPool.liquidityUnlockBlock(address(this)));
    }

    // ── 1. The core claim ────────────────────────────────────────────────

    /// @dev The whole thesis. A swap into the skewed pool must not receive the skewed pool's
    ///      isolated quote when the federation's combined reserves do not support it.
    function test_core_skewedPoolCannotPayItsIsolatedQuote() public {
        uint256 amountIn = 5 ether;
        (uint256 localQuote, uint256 aggregateQuote, uint256 knotQuote) =
            federation.preview(address(shallowPool), true, true, amountIn);

        assertGt(localQuote, aggregateQuote, "setup invalid: the shallow pool should be the generous one here");
        assertEq(knotQuote, aggregateQuote, "Knot must enforce the LESS favorable of the two quotes");

        uint256 withheld = localQuote - knotQuote;
        assertGt(withheld, 0, "the clamp did not bind, so this test proves nothing");
        emit log_named_uint("value withheld from the taker and left with LPs (wei)", withheld);
        emit log_named_uint("as a share of the isolated quote (bps)", (withheld * 10_000) / localQuote);
    }

    /// @dev The mirrored direction: for exact-output the bound must be the MORE expensive input.
    function test_core_exactOutputChargesTheHigherOfBothQuotes() public view {
        uint256 amountOut = 5 ether;
        (uint256 localQuote, uint256 aggregateQuote, uint256 knotQuote) =
            federation.preview(address(shallowPool), true, false, amountOut);
        uint256 expected = localQuote > aggregateQuote ? localQuote : aggregateQuote;
        assertEq(knotQuote, expected, "exact-output must never undercharge relative to either reference");
    }

    // ── 2. Does the bound survive the standard evasions? ─────────────────

    /// @dev Path independence. If slicing a trade beat one large trade, the protection would be
    ///      cosmetic. An attacker would simply always slice. Reserves move per slice, so the
    ///      sliced total is not expected to be identical, only NOT BETTER for the attacker.
    function test_evasion_splittingDoesNotBeatOneLargeTrade() public {
        uint256 snap = vm.snapshotState();

        uint256 beforeBal = currency1.balanceOf(address(this));
        _swap(shallowKey, true, 4 ether);
        uint256 singleOut = currency1.balanceOf(address(this)) - beforeBal;

        vm.revertToState(snap);

        SplitTrader trader = new SplitTrader(swapRouter, shallowKey);
        _fund(address(trader));
        uint256 traderBefore = currency1.balanceOf(address(trader));
        trader.splitSwap(true, -4 ether, 8);
        uint256 splitOut = currency1.balanceOf(address(trader)) - traderBefore;

        emit log_named_uint("output, one 4e18 trade", singleOut);
        emit log_named_uint("output, same size in 8 slices", splitOut);
        assertLe(splitOut, singleOut, "splitting produced a BETTER outcome: the bound is evadable");
    }

    /// @dev A complete sandwich in the documented skewed-member fixture: the attacker sells token0,
    ///      a separate victim follows, and the attacker sells every unit of acquired token1 back.
    ///      This is fixture evidence, not a claim that KNOT eliminates every same-pool sandwich;
    ///      the balanced fixture in KnotFederationAttack proves a profitable residual remains.
    function test_evasion_skewedMemberSandwichIsUnprofitableInThisFixture() public {
        address victim = address(0xB0B);
        _fund(attacker);
        _fund(victim);

        uint256 a0 = currency0.balanceOf(attacker);
        uint256 a1 = currency1.balanceOf(attacker);
        _swapAs(attacker, shallowKey, true, 2 ether); // front-run
        uint256 inventory1 = currency1.balanceOf(attacker) - a1;

        _swapAs(victim, shallowKey, true, 1 ether); // victim

        _swapAs(attacker, shallowKey, false, inventory1); // close the attacker's acquired inventory
        uint256 ending0 = currency0.balanceOf(attacker);

        emit log_named_uint("attacker token1 inventory closed", inventory1);
        emit log_named_int("attacker token0 delta across the sandwich", int256(ending0) - int256(a0));
        assertEq(currency1.balanceOf(attacker), a1, "attacker did not close the intermediate inventory");
        assertLt(ending0, a0, "skewed-member fixture unexpectedly produced sandwich profit");
    }

    // ── 3. The disclosed coalition risk, measured rather than asserted ───

    /// @dev SECURITY.md states: "Liquidity-based buddy coalitions can weaken the aggregate
    ///      reference. This version does not claim coalition-proof MEV prevention."
    ///      That disclosure is honest, but it is a claim about magnitude, so it should carry a
    ///      number. Here an attacker controls the second member pool and skews it to drag the
    ///      aggregate toward the quote they want. This test records how far they get.
    function test_coalition_attackerOwnedMemberPoolMovesTheAggregate() public {
        uint256 amountIn = 5 ether;
        (,, uint256 quoteBefore) = federation.preview(address(shallowPool), true, true, amountIn);

        // The attacker adds heavily lopsided liquidity to the pool they control, pushing the
        // aggregate ratio in their favour.
        _fund(attacker);
        vm.startPrank(attacker);
        ERC20(Currency.unwrap(currency0)).approve(address(deepPool), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(deepPool), type(uint256).max);
        vm.stopPrank();

        _swapAs(attacker, deepKey, false, 300 ether); // skew the deep pool's ratio

        (,, uint256 quoteAfter) = federation.preview(address(shallowPool), true, true, amountIn);

        emit log_named_uint("enforced quote before coalition skew", quoteBefore);
        emit log_named_uint("enforced quote after coalition skew ", quoteAfter);
        if (quoteAfter > quoteBefore) {
            emit log_named_uint("aggregate loosened by (wei)", quoteAfter - quoteBefore);
            emit log_named_uint(
                "loosened by (bps of the original quote)", ((quoteAfter - quoteBefore) * 10_000) / quoteBefore
            );
        } else {
            emit log("coalition skew did NOT loosen the enforced quote in this configuration");
        }
        // Deliberately no assertion on direction. This test exists to attach a measured number to
        // a disclosed limitation, not to pass or fail.
    }

    // ── 4. Invariants the bound depends on ───────────────────────────────

    /// @dev The aggregate must always equal the sum of member books, or every quote derived from
    ///      it is meaningless. Checked after real swap activity, not just at rest.
    function test_invariant_aggregateTracksMembersAfterSwaps() public {
        _swap(shallowKey, true, 3 ether);
        _swap(deepKey, false, 2 ether);
        _swap(shallowKey, false, 1 ether);

        (uint256 d0, uint256 d1) = federation.reservesOf(address(deepPool));
        (uint256 s0, uint256 s1) = federation.reservesOf(address(shallowPool));
        assertEq(federation.aggregateReserve0(), d0 + s0, "aggregate0 drifted from member books");
        assertEq(federation.aggregateReserve1(), d1 + s1, "aggregate1 drifted from member books");
    }

    /// @dev Reserves must never be drained below zero by a quote the bound permitted.
    function testFuzz_invariant_reservesNeverUnderflow(uint96 raw, bool zeroForOne, bool useShallow) public {
        uint256 amount = bound(uint256(raw), 1e15, 20 ether);
        PoolKey memory k = useShallow ? shallowKey : deepKey;
        try swapRouter.swap(
            k,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amount),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        ) {} catch {}

        (uint256 d0, uint256 d1) = federation.reservesOf(address(deepPool));
        (uint256 s0, uint256 s1) = federation.reservesOf(address(shallowPool));
        assertEq(federation.aggregateReserve0(), d0 + s0);
        assertEq(federation.aggregateReserve1(), d1 + s1);
    }

    /// @dev JIT: liquidity added now must not be usable to back a quote in the same block.
    function test_jit_freshLiquidityCannotBackTheSameBlockQuote() public {
        (uint256 aggBefore0,) = (federation.aggregateReserve0(), federation.aggregateReserve1());

        _fund(attacker);
        vm.startPrank(attacker);
        ERC20(Currency.unwrap(currency0)).approve(address(deepPool), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(deepPool), type(uint256).max);
        deepPool.addLiquidity(_add(50 ether, 50 ether));
        vm.stopPrank();

        assertEq(federation.aggregateReserve0(), aggBefore0, "pending liquidity leaked into the aggregate immediately");
        emit log("JIT: a same-block deposit does not move the aggregate until it matures");
    }

    // ── helpers ──────────────────────────────────────────────────────────

    function _approve(address who) private {
        ERC20(Currency.unwrap(currency0)).approve(who, type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(who, type(uint256).max);
    }

    function _fund(address who) private {
        deal(Currency.unwrap(currency0), who, 10_000 ether);
        deal(Currency.unwrap(currency1), who, 10_000 ether);
        vm.startPrank(who);
        ERC20(Currency.unwrap(currency0)).approve(address(swapRouter), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _swap(PoolKey memory k, bool zeroForOne, uint256 amount) private {
        swapRouter.swap(
            k,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amount),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }

    function _swapAs(address who, PoolKey memory k, bool zeroForOne, uint256 amount) private {
        vm.prank(who);
        swapRouter.swap(
            k,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amount),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }

    function _add(uint256 a, uint256 b) private pure returns (BaseCustomAccounting.AddLiquidityParams memory) {
        return BaseCustomAccounting.AddLiquidityParams(a, b, 0, 0, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0));
    }
}
