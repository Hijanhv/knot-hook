// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BaseFixture} from "./BaseFixture.sol";

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

    /// @dev The same-block JIT case is covered. The harder version respects the maturity window:
    ///      deposit, wait it out, activate, trade against the depth you just added, then leave.
    ///      Maturity delays that attack, it does not forbid it, so the question is whether the
    ///      attacker ends up ahead. Fees plus the bound should mean no.
    function test_jit_multiBlockDepositTradeWithdrawEndsDown() public {
        fund(attacker);
        approveHookAs(attacker, address(shallow));

        uint256 open0 = _bal(currency0, attacker);
        uint256 open1 = _bal(currency1, attacker);

        vm.prank(attacker);
        shallow.addLiquidity(addParams(20 ether, 80 ether));

        vm.roll(block.number + 2); // sit out the maturity window
        vm.prank(attacker);
        shallow.activatePendingLiquidity();

        doSwapAs(attacker, shallowKey, true, -5 ether);

        uint256 shares = shallow.balanceOf(attacker);
        vm.prank(attacker);
        shallow.removeLiquidity(removeParams(shares));

        (uint256 refund0, uint256 refund1) = shallow.claimableLiquidityRefund(attacker);
        if (refund0 != 0 || refund1 != 0) {
            vm.prank(attacker);
            shallow.claimLiquidityRefund();
        }

        // Value the exit at the pool's own closing rate so a token0/token1 mix cannot hide a loss.
        (uint256 r0, uint256 r1) = federation.reservesOf(address(shallow));
        uint256 openValue = open0 + (open1 * r0) / r1;
        uint256 closeValue = _bal(currency0, attacker) + (_bal(currency1, attacker) * r0) / r1;

        assertLt(closeValue, openValue, "multi-block JIT round trip turned a profit");
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
    function testFuzz_flashScaleTradeNeverOutrunsTheReserves(uint96 raw) public {
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
}
