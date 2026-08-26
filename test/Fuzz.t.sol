// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BaseFixture} from "./BaseFixture.sol";
import {KnotMath} from "../src/KnotMath.sol";

/// @title Randomised inputs, to catch the cases nobody thinks to write.
///
/// @dev Every property here is one a human would assert by hand for a single case. Fuzzing
///      makes the same assertion across thousands of reserve shapes and trade sizes, which is
///      where rounding, ordering and boundary faults actually live.
contract FuzzTest is BaseFixture {
    uint256 constant NUM = 997;
    uint256 constant DEN = 1000;

    // ── the bound ────────────────────────────────────────────────────────

    /// The core safety property: a taker can never beat BOTH references.
    function testFuzz_enforcedNeverBeatsEitherReference(uint96 raw) public view {
        uint256 amt = bound(uint256(raw), 1e12, 50 ether);
        (uint256 local, uint256 agg, uint256 enforced) = federation.preview(address(shallow), true, true, amt);
        assertLe(enforced, local, "enforced beat the local reference");
        assertLe(enforced, agg, "enforced beat the aggregate reference");
        assertEq(enforced, local < agg ? local : agg, "enforced is not the minimum");
    }

    /// Mirrored for exact output: the taker never pays LESS than both references demand.
    function testFuzz_exactOutputNeverUnderchargesEitherReference(uint96 raw) public view {
        uint256 amt = bound(uint256(raw), 1e12, 20 ether);
        (uint256 local, uint256 agg, uint256 enforced) = federation.preview(address(shallow), true, false, amt);
        assertGe(enforced, local, "undercharged against the local reference");
        assertGe(enforced, agg, "undercharged against the aggregate reference");
    }

    /// Direction must not create an asymmetry the bound fails to cover.
    function testFuzz_boundHoldsInBothDirections(uint96 raw, bool zeroForOne, bool useShallow) public view {
        uint256 amt = bound(uint256(raw), 1e12, 20 ether);
        address hook = useShallow ? address(shallow) : address(deep);
        (uint256 local, uint256 agg, uint256 enforced) = federation.preview(hook, zeroForOne, true, amt);
        assertLe(enforced, local < agg ? local : agg);
    }

    // ── live swaps ───────────────────────────────────────────────────────

    /// After any single swap the aggregate must still equal the sum of members. Swaps that
    /// exceed liquidity are expected to revert and are skipped, not treated as failures.
    function testFuzz_aggregateStaysConsistentAfterASwap(uint96 raw, bool zeroForOne, bool useShallow) public {
        uint256 amt = bound(uint256(raw), 1e12, 20 ether);
        try this.externalSwap(useShallow, zeroForOne, -int256(amt)) {} catch {}
        assertAggregateConsistent();
    }

    /// A sequence of swaps must not let reserves drift, underflow, or drain a member to zero.
    function testFuzz_reservesSurviveLongSequences(uint96 seed) public {
        uint256 s = uint256(seed);
        for (uint256 i = 0; i < 12; i++) {
            s = uint256(keccak256(abi.encode(s)));
            uint256 amt = bound(s, 1e12, 5 ether);
            try this.externalSwap(s % 2 == 0, (s >> 8) % 2 == 0, -int256(amt)) {} catch {}
        }
        assertAggregateConsistent();
        (uint256 d0, uint256 d1) = federation.reservesOf(address(deep));
        (uint256 s0, uint256 s1) = federation.reservesOf(address(shallow));
        assertGt(d0, 0); assertGt(d1, 0); assertGt(s0, 0); assertGt(s1, 0);
    }

    /// Splitting a trade must never beat sending it whole. If it did, the bound would be
    /// cosmetic, because an attacker would simply always slice.
    function testFuzz_splittingNeverBeatsOneTrade(uint96 raw, uint8 rawSlices) public {
        uint256 total = bound(uint256(raw), 1e15, 5 ether);
        uint256 slices = bound(uint256(rawSlices), 2, 8);

        uint256 snap = vm.snapshotState();
        uint256 before = currency1.balanceOf(address(this));
        try this.externalSwap(true, true, -int256(total)) {} catch { vm.revertToState(snap); return; }
        uint256 whole = currency1.balanceOf(address(this)) - before;

        vm.revertToState(snap);
        before = currency1.balanceOf(address(this));
        for (uint256 i = 0; i < slices; i++) {
            try this.externalSwap(true, true, -int256(total / slices)) {} catch {}
        }
        uint256 sliced = currency1.balanceOf(address(this)) - before;

        assertLe(sliced, whole + 1, "splitting produced a better outcome than one trade");
    }

    // ── liquidity lifecycle ──────────────────────────────────────────────

    /// Any deposit that mints shares must be recoverable: activate, then remove, and the
    /// provider ends up with assets back and no shares left.
    function testFuzz_depositThenFullWithdrawalRoundTrips(uint96 rawA, uint96 rawB) public {
        uint256 a0 = bound(uint256(rawA), 1 ether, 100 ether);
        uint256 a1 = bound(uint256(rawB), 1 ether, 100 ether);

        fund(alice);
        approveHookAs(alice, address(deep));

        vm.startPrank(alice);
        try deep.addLiquidity(addParams(a0, a1)) {} catch { vm.stopPrank(); return; }
        vm.stopPrank();

        vm.roll(block.number + 1);
        vm.prank(alice);
        deep.activatePendingLiquidity();

        uint256 shares = deep.balanceOf(alice);
        if (shares == 0) return;

        vm.prank(alice);
        deep.removeLiquidity(removeParams(shares));

        assertEq(deep.balanceOf(alice), 0, "shares should be fully burned");
        assertAggregateConsistent();
    }

    /// Cancelling must always return exactly what was deposited, whatever the amounts.
    function testFuzz_cancelIsAlwaysWholeAndExact(uint96 rawA, uint96 rawB) public {
        uint256 a0 = bound(uint256(rawA), 1 ether, 100 ether);
        uint256 a1 = bound(uint256(rawB), 1 ether, 100 ether);

        fund(alice);
        approveHookAs(alice, address(deep));
        uint256 before0 = currency0.balanceOf(alice);
        uint256 before1 = currency1.balanceOf(alice);

        vm.startPrank(alice);
        try deep.addLiquidity(addParams(a0, a1)) {} catch { vm.stopPrank(); return; }
        deep.cancelPendingLiquidity();
        deep.claimLiquidityRefund();
        vm.stopPrank();

        assertEq(currency0.balanceOf(alice), before0, "currency0 not fully returned");
        assertEq(currency1.balanceOf(alice), before1, "currency1 not fully returned");
    }

    // ── pure math ────────────────────────────────────────────────────────

    /// Rounding must always favour the pool. A quote that rounded the taker's way would leak
    /// value one wei at a time, which is exactly the kind of fault fuzzing exists to find.
    function testFuzz_roundingAlwaysFavoursThePool(uint96 rawIn, uint96 rawR0, uint96 rawR1) public pure {
        uint256 amt = bound(uint256(rawIn), 1e12, 100 ether);
        uint256 r0 = bound(uint256(rawR0), 1 ether, 1_000_000 ether);
        uint256 r1 = bound(uint256(rawR1), 1 ether, 1_000_000 ether);

        uint256 out = KnotMath.amountOut(amt, r0, r1, NUM, DEN);
        assertLt(out, r1, "a quote drained the entire output reserve");

        // k must never decrease: the pool is never worse off after the trade.
        uint256 kBefore = r0 * r1;
        uint256 kAfter = (r0 + (amt * NUM) / DEN) * (r1 - out);
        assertGe(kAfter, kBefore, "constant product decreased, so the pool lost value");
    }

    /// Larger input must never yield less output. A non-monotone curve would be arbitrageable.
    function testFuzz_outputIsMonotoneInInput(uint96 rawA, uint96 rawB) public pure {
        uint256 a = bound(uint256(rawA), 1e12, 50 ether);
        uint256 b = bound(uint256(rawB), 1e12, 50 ether);
        (uint256 lo, uint256 hi) = a < b ? (a, b) : (b, a);
        assertLe(
            KnotMath.amountOut(lo, 500 ether, 500 ether, NUM, DEN),
            KnotMath.amountOut(hi, 500 ether, 500 ether, NUM, DEN),
            "a larger trade returned less output"
        );
    }

    /// The aggregate can never be smaller than any single member it contains.
    function testFuzz_aggregateDominatesEveryMember(uint96 raw, bool zeroForOne) public {
        uint256 amt = bound(uint256(raw), 1e12, 10 ether);
        try this.externalSwap(true, zeroForOne, -int256(amt)) {} catch {}
        (uint256 d0, uint256 d1) = federation.reservesOf(address(deep));
        (uint256 s0, uint256 s1) = federation.reservesOf(address(shallow));
        assertGe(federation.aggregateReserve0(), d0);
        assertGe(federation.aggregateReserve0(), s0);
        assertGe(federation.aggregateReserve1(), d1);
        assertGe(federation.aggregateReserve1(), s1);
    }

    // ── helper ───────────────────────────────────────────────────────────

    /// @dev External so individual fuzz runs can try/catch a reverting swap without aborting.
    function externalSwap(bool useShallow, bool zeroForOne, int256 amount) external {
        doSwap(useShallow ? shallowKey : deepKey, zeroForOne, amount);
    }
}
