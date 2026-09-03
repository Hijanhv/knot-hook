// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BaseFixture} from "../fixtures/BaseFixture.sol";
import {KnotHook} from "../../src/hooks/KnotHook.sol";

/// @title Adversarial extraction attempts that the rest of the suite does not cover.
///
/// @dev WHAT THIS FILE IS FOR
///      `MEVProtection.t.sol` proves the bound holds against the textbook single-pool evasions:
///      slicing, one sandwich, same-block JIT. This file attacks the parts of the design that
///      are specific to a FEDERATION, plus the manipulation vectors that constant-product AMMs
///      have historically actually died to.
///
///      Every test here measures attacker profit and loss in the currency the attacker started
///      with, and asserts they end down. Where a mechanism is structurally immune rather than
///      merely expensive, the test says so and proves the structure instead.
contract MEVAdversarialTest is BaseFixture {
    function _bal(Currency c, address who) internal view returns (uint256) {
        return ERC20(Currency.unwrap(c)).balanceOf(who);
    }

    // ── 1. Reserve manipulation by donation ──────────────────────────────
    //
    // The attack that killed more than one constant-product fork: move the pool's price by
    // transferring tokens straight to it, then trade against the price you just moved. It works
    // whenever a pool derives reserves from `balanceOf`.

    /// @dev Knot books reserves in the federation rather than reading a balance, so a donation
    ///      should be inert. Proving inertness is worth more than proving it is expensive: an
    ///      expensive attack gets cheaper with a flash loan, a structurally ignored one does not.
    function test_donation_directTransferCannotMoveAnyQuote() public {
        (uint256 q0Local, uint256 q0Agg, uint256 q0Knot) = federation.preview(address(shallow), true, true, 5 ether);

        // Donate a quarter of the shallow pool's depth straight to every address that could
        // plausibly be read as holding its reserves.
        deal(Currency.unwrap(currency0), attacker, 1_000 ether);
        vm.startPrank(attacker);
        ERC20(Currency.unwrap(currency0)).transfer(address(shallow), 25 ether);
        ERC20(Currency.unwrap(currency0)).transfer(address(manager), 25 ether);
        ERC20(Currency.unwrap(currency0)).transfer(address(federation), 25 ether);
        vm.stopPrank();

        (uint256 q1Local, uint256 q1Agg, uint256 q1Knot) = federation.preview(address(shallow), true, true, 5 ether);

        assertEq(q1Local, q0Local, "a donation moved the local quote");
        assertEq(q1Agg, q0Agg, "a donation moved the aggregate quote");
        assertEq(q1Knot, q0Knot, "a donation moved the enforced quote");
    }

    /// @dev Same idea against the reserve books themselves, which is what quotes are derived
    ///      from. Donated tokens must never become quotable liquidity.
    function test_donation_neverBecomesQuotableReserves() public {
        (uint256 r0, uint256 r1) = federation.reservesOf(address(shallow));
        uint256 agg0 = federation.aggregateReserve0();

        deal(Currency.unwrap(currency0), attacker, 500 ether);
        vm.prank(attacker);
        ERC20(Currency.unwrap(currency0)).transfer(address(shallow), 100 ether);

        (uint256 r0After, uint256 r1After) = federation.reservesOf(address(shallow));
        assertEq(r0After, r0, "donation entered the member book");
        assertEq(r1After, r1, "donation moved the other side of the member book");
        assertEq(federation.aggregateReserve0(), agg0, "donation entered the aggregate");
    }

    // ── 2. Cross-member sandwich ─────────────────────────────────────────

    /// @dev The single-pool sandwich is already covered. This is the federated version: the
    ///      attacker moves the AGGREGATE by trading the deep member, so the victim's quote in
    ///      the shallow member shifts, then unwinds. If the shared reference were exploitable,
    ///      this is the shape that would do it.
    function test_sandwich_acrossTwoMembersStillLosesMoney() public {
        fund(attacker);
        fund(bob);

        uint256 opening0 = _bal(currency0, attacker);
        uint256 held1 = _bal(currency1, attacker);

        doSwapAs(attacker, deepKey, true, -40 ether); // front-run through the OTHER member
        uint256 bought1 = _bal(currency1, attacker) - held1;

        doSwapAs(bob, shallowKey, true, -5 ether); // victim trades the shallow member
        doSwapAs(attacker, deepKey, false, -int256(bought1)); // unwind the whole leg

        assertLt(_bal(currency0, attacker), opening0, "cross-member sandwich turned a profit");
        assertAggregateConsistent();
    }

    /// @dev Back-running alone, with no front-run leg. Cheaper than a sandwich and often the
    ///      residual profit once a sandwich is priced out, so it needs its own assertion.
    function test_backrun_aloneDoesNotExtractValue() public {
        fund(attacker);
        fund(bob);

        uint256 opening1 = _bal(currency1, attacker);

        doSwapAs(bob, shallowKey, true, -5 ether); // victim first
        uint256 held0 = _bal(currency0, attacker);
        doSwapAs(attacker, shallowKey, false, -20 ether); // attacker follows the move
        uint256 bought0 = _bal(currency0, attacker) - held0;
        doSwapAs(attacker, shallowKey, true, -int256(bought0)); // close back out

        assertLt(_bal(currency1, attacker), opening1, "back-running extracted value");
        assertAggregateConsistent();
    }

    // ── 3. Ordering and priority independence ────────────────────────────

    /// @dev Everything a hook can see about ordering is gameable: gas price, base fee, coinbase,
    ///      block number. Knot reads none of them. This pins that down, because it is also the
    ///      property that makes the output deterministic: identical state plus identical
    ///      arguments must give an identical quote regardless of how the block is built.
    function test_ordering_quoteIsIndependentOfEveryBlockLevelSignal() public {
        (,, uint256 baseline) = federation.preview(address(shallow), true, true, 5 ether);

        vm.txGasPrice(500 gwei);
        vm.fee(300 gwei);
        vm.coinbase(attacker);
        vm.roll(block.number + 5_000);
        vm.warp(block.timestamp + 365 days);
        vm.prevrandao(bytes32(uint256(0xdeadbeef)));

        (,, uint256 underPressure) = federation.preview(address(shallow), true, true, 5 ether);
        assertEq(underPressure, baseline, "quote moved with a block-level signal");
    }

    // ── 4. Multi-block just-in-time liquidity ────────────────────────────

    /// @dev Waiting out deposit maturity must not create a free option to activate immediately
    ///      before a known victim and exit in that same block. Activation starts a second,
    ///      equally long lock; removal succeeds only after that window closes.
    function test_maturedJitCannotActivateBeforeVictimAndExitInSameBlock() public {
        fund(attacker);
        fund(bob);
        approveHookAs(attacker, address(shallow));

        vm.prank(attacker);
        shallow.addLiquidity(addParams(20 ether, 80 ether));

        vm.roll(block.number + 2); // sit out the maturity window
        vm.prank(attacker);
        shallow.activatePendingLiquidity();

        doSwapAs(bob, shallowKey, true, -5 ether);

        uint256 shares = shallow.balanceOf(attacker);
        uint256 unlockBlock = shallow.liquidityUnlockBlock(attacker);
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(KnotHook.LiquidityStillLocked.selector, unlockBlock));
        shallow.removeLiquidity(removeParams(shares));

        vm.roll(unlockBlock);
        vm.prank(attacker);
        shallow.removeLiquidity(removeParams(shares));

        (uint256 refund0, uint256 refund1) = shallow.claimableLiquidityRefund(attacker);
        if (refund0 != 0 || refund1 != 0) {
            vm.prank(attacker);
            shallow.claimLiquidityRefund();
        }

        assertEq(shallow.balanceOf(attacker), 0, "shares remained after the exit window");
        assertAggregateConsistent();
    }

    // ── 5. Cyclic extraction across the whole federation ─────────────────

    /// @dev Triangular arbitrage has no third asset here, so the federated analogue is a cycle
    ///      through both members and back. Run it repeatedly: if any single lap is profitable
    ///      the attacker simply loops, so the assertion has to hold every lap, not on average.
    function test_cycle_repeatedTwoPoolLoopBleedsTheAttackerEveryLap() public {
        fund(attacker);
        uint256 opening = _bal(currency0, attacker);
        uint256 previous = opening;

        for (uint256 lap = 0; lap < 6; lap++) {
            doSwapAs(attacker, shallowKey, true, -3 ether);
            doSwapAs(attacker, deepKey, false, -3 ether);

            uint256 now0 = _bal(currency0, attacker);
            assertLt(now0, previous, "a lap of the federation cycle turned a profit");
            previous = now0;
        }

        assertLt(_bal(currency0, attacker), opening, "the cycle was profitable overall");
        assertAggregateConsistent();
    }

    // ── 6. Size extremes ─────────────────────────────────────────────────

    /// @dev A flash loan removes the capital constraint, so the bound has to hold at sizes no
    ///      honest trader would use. The pool must either quote within its reserves or refuse,
    ///      and must never pay out more than it holds.
    function testFuzz_flashScaleTradeNeverOutrunsTheReserves(uint96 raw) public view {
        uint256 amount = uint256(raw);
        vm.assume(amount > 0.01 ether);

        (uint256 r0, uint256 r1) = federation.reservesOf(address(shallow));

        try federation.preview(address(shallow), true, true, amount) returns (uint256 l, uint256 a, uint256 k) {
            assertLe(k, l, "enforced beat the local reference");
            assertLe(k, a, "enforced beat the aggregate reference");
            assertLt(k, r1, "quote promised more than the member holds");
            assertLt(k, federation.aggregateReserve1(), "quote promised more than the pair holds");
        } catch {
            // Refusing an impossible trade is the correct outcome, not a failure.
        }
        assertGt(r0, 0, "member book emptied");
    }

    // ── 7. Read-only reentrancy ──────────────────────────────────────────

    /// @dev `preview` is the integration surface. If it could be read mid-swap while the books
    ///      were half-updated, an integrator could be fed a quote that never existed. The books
    ///      move inside one `nonReentrant` call, so there is no window; this asserts the
    ///      before-and-after relationship a reader depends on.
    function test_readonly_previewIsNeverObservableMidUpdate() public {
        fund(bob);

        (uint256 beforeLocal,,) = federation.preview(address(shallow), true, true, 1 ether);
        (uint256 r0Before,) = federation.reservesOf(address(shallow));

        doSwapAs(bob, shallowKey, true, -5 ether);

        (uint256 afterLocal,,) = federation.preview(address(shallow), true, true, 1 ether);
        (uint256 r0After,) = federation.reservesOf(address(shallow));

        assertGt(r0After, r0Before, "the swap did not move the book at all");
        assertLt(afterLocal, beforeLocal, "book moved but the quote did not follow it");
        assertAggregateConsistent();
    }

    // ── 8. Exact-output variants ─────────────────────────────────────────

    /// @dev Every sandwich above is exact-input. Exact-output takes the OTHER branch of the
    ///      bound (max instead of min) and is a separate code path, so a sandwich built out of
    ///      exact-output legs needs its own assertion rather than an argument by symmetry.
    function test_sandwich_builtFromExactOutputLegsAlsoLoses() public {
        fund(attacker);
        fund(bob);

        uint256 opening0 = _bal(currency0, attacker);
        uint256 held1 = _bal(currency1, attacker);

        doSwapAs(attacker, shallowKey, true, 20 ether); // exact OUTPUT: buy 20 token1
        uint256 bought1 = _bal(currency1, attacker) - held1;

        doSwapAs(bob, shallowKey, true, -5 ether);
        doSwapAs(attacker, shallowKey, false, -int256(bought1));

        assertLt(_bal(currency0, attacker), opening0, "exact-output sandwich turned a profit");
        assertAggregateConsistent();
    }

    // ── 9. Griefing ──────────────────────────────────────────────────────

    /// @dev Extraction is not the only hostile goal. A hook that can be pushed into a state
    ///      where honest swaps revert is a denial-of-service surface, and for an AMM that is a
    ///      loss of its own. Drive the shallow member hard in one direction, then check an
    ///      ordinary trade in both directions still settles.
    function test_grief_hostileFlowCannotBlockHonestSwaps() public {
        fund(attacker);
        fund(bob);

        for (uint256 i = 0; i < 8; i++) {
            doSwapAs(attacker, shallowKey, true, -12 ether);
        }

        uint256 bobBefore = _bal(currency1, bob);
        doSwapAs(bob, shallowKey, true, -1 ether);
        assertGt(_bal(currency1, bob), bobBefore, "an honest trade could not settle after hostile flow");

        uint256 bobBack = _bal(currency0, bob);
        doSwapAs(bob, shallowKey, false, -1 ether);
        assertGt(_bal(currency0, bob), bobBack, "the reverse direction was blocked");

        assertAggregateConsistent();
    }

    // ── 10. Three live members ───────────────────────────────────────────

    /// @dev The multi-member bound is fuzzed as pure arithmetic elsewhere. This runs it live:
    ///      a third registered, initialised, funded member, then a cycle through all three.
    ///      More members means a larger aggregate, which is a WEAKER bound on any one pool, so
    ///      this is the direction where the mechanism is most likely to give.
    function test_cycle_threeLiveMembersStillBleedTheAttacker() public {
        KnotHook third = _deployHook(3, "Knot Third", "KNOT-T");
        federation.register(address(third));
        (PoolKey memory thirdKey,) =
            initPool(currency0, currency1, IHooks(address(third)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        _approveHook(address(third));
        third.addLiquidity(addParams(300 ether, 300 ether));
        vm.roll(block.number + 1);
        third.activatePendingLiquidity();

        assertEq(federation.memberCount(), 3, "third member did not register");

        fund(attacker);
        uint256 opening0 = _bal(currency0, attacker);

        for (uint256 lap = 0; lap < 4; lap++) {
            doSwapAs(attacker, shallowKey, true, -2 ether);
            doSwapAs(attacker, thirdKey, false, -2 ether);
            doSwapAs(attacker, deepKey, true, -2 ether);
            doSwapAs(attacker, shallowKey, false, -2 ether);
        }

        assertLt(_bal(currency0, attacker), opening0, "a three-member cycle was profitable");

        // assertAggregateConsistent() only sums the fixture's two members, so with a third
        // registered it would report drift that is not there. Check all three explicitly.
        (uint256 d0, uint256 d1) = federation.reservesOf(address(deep));
        (uint256 s0, uint256 s1) = federation.reservesOf(address(shallow));
        (uint256 t0, uint256 t1) = federation.reservesOf(address(third));
        assertEq(federation.aggregateReserve0(), d0 + s0 + t0, "aggregate0 drifted across three members");
        assertEq(federation.aggregateReserve1(), d1 + s1 + t1, "aggregate1 drifted across three members");
    }

    // ── 11. First depositor ──────────────────────────────────────────────

    /// @dev The classic share-inflation attack: be the first depositor into an empty pool, mint
    ///      a single share, donate to inflate its value, and let the next depositor round to
    ///      zero. Knot closes it upstream by restricting the first deposit into an empty member
    ///      to the federation owner. Assert that gate rather than the arithmetic behind it.
    function test_firstDepositor_cannotSeedAnEmptyMember() public {
        KnotHook fresh = _deployHook(3, "Knot Fresh", "KNOT-F");
        federation.register(address(fresh));
        initPool(currency0, currency1, IHooks(address(fresh)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        fund(attacker);
        approveHookAs(attacker, address(fresh));

        assertEq(fresh.totalSupply(), 0, "fresh member was not empty");

        vm.prank(attacker);
        vm.expectRevert(KnotHook.OnlyInitialLiquidityProvider.selector);
        fresh.addLiquidity(addParams(1, 1));
    }
}
