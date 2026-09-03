// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {KnotMath} from "../../src/libraries/KnotMath.sol";
import {KnotTestBase} from "../fixtures/KnotTestBase.sol";

contract KnotFederationAttackTest is KnotTestBase {
    using CurrencyLibrary for Currency;

    uint256 private constant MODEL_FEE_NUMERATOR = 997;
    uint256 private constant MODEL_FEE_DENOMINATOR = 1000;

    struct ThreePoolState {
        uint256[3] reserve0;
        uint256[3] reserve1;
    }

    function setUp() public {
        _deployKnotFixture(1, 1, 2, 1, 100 ether, 100 ether, 100 ether, 100 ether);
    }

    function test_canonicalSandwichDampensExitAndRetainsTheClippedValue() public {
        address victim = address(0xA11CE);
        _fundAndApproveTrader(victim, 10 ether, 0);
        (uint256 plainProfit, uint256 plainVictimOutput, uint256 plainFinalProduct) = _plainSandwich();
        uint256 attacker0Before = currency0.balanceOf(address(this));
        uint256 attacker1Before = currency1.balanceOf(address(this));

        _swap(keyA, true, -int256(10 ether));
        uint256 attackerInventory1 = currency1.balanceOf(address(this)) - attacker1Before;

        uint256 victim1Before = currency1.balanceOf(victim);
        vm.prank(victim);
        _swap(keyA, true, -int256(10 ether));
        uint256 victimOutput = currency1.balanceOf(victim) - victim1Before;

        _swap(keyA, false, -int256(attackerInventory1));
        uint256 knotProfit = currency0.balanceOf(address(this)) - attacker0Before;
        (uint256 finalReserve0, uint256 finalReserve1) = federation.reservesOf(address(hookA));

        assertEq(victimOutput, plainVictimOutput, "the canonical victim leg remains the local quote");
        assertGt(knotProfit, 0, "Knot dampens rather than eliminating this sandwich");
        assertLt(knotProfit, plainProfit, "the aggregate exit bound reduces attacker profit");
        assertApproxEqAbs(plainProfit, uint256(110 ether) / 61, 2, "plain CPMM witness");
        assertApproxEqAbs(knotProfit, uint256(50 ether) / 127, 2, "Knot witness");
        assertGt(finalReserve0 * finalReserve1, plainFinalProduct, "the clipped exit remains with target LPs");
        assertGt(
            federation.aggregateReserve0() * federation.aggregateReserve1(), 200 ether * 200 ether, "aggregate product"
        );
        _assertAggregateMatchesMembers();
    }

    function test_pendingBuddyLiquidityCannotMoveTargetQuoteBeforeMaturity() public {
        address provider = address(0xB0B);
        _fundAndApproveLiquidity(provider, hookB, 100 ether, 100 ether);
        (uint256 aggregate0Before, uint256 aggregate1Before) =
            (federation.aggregateReserve0(), federation.aggregateReserve1());
        (, uint256 aggregateQuoteBefore,) = federation.preview(address(hookA), true, true, 10 ether);

        vm.prank(provider);
        hookB.addLiquidity(_addParams(100 ether, 100 ether));

        assertEq(federation.aggregateReserve0(), aggregate0Before);
        assertEq(federation.aggregateReserve1(), aggregate1Before);
        (, uint256 aggregateQuoteWhilePending,) = federation.preview(address(hookA), true, true, 10 ether);
        assertEq(aggregateQuoteWhilePending, aggregateQuoteBefore);

        vm.roll(block.number + 1);
        vm.prank(provider);
        hookB.activatePendingLiquidity();
        (, uint256 aggregateQuoteAfterActivation,) = federation.preview(address(hookA), true, true, 10 ether);
        assertEq(federation.aggregateReserve0(), aggregate0Before + 100 ether);
        assertEq(federation.aggregateReserve1(), aggregate1Before + 100 ether);
        assertGt(aggregateQuoteAfterActivation, aggregateQuoteBefore, "only matured depth changes the shared quote");
        _assertAggregateMatchesMembers();
    }

    function test_buddyPoolTradeImmediatelyChangesTheTargetAggregateReference() public {
        (, uint256 aggregateQuoteBefore,) = federation.preview(address(hookA), true, true, 10 ether);
        _swap(keyB, true, -int256(10 ether));
        (, uint256 aggregateQuoteAfter,) = federation.preview(address(hookA), true, true, 10 ether);

        assertLt(aggregateQuoteAfter, aggregateQuoteBefore);
        _assertAggregateMatchesMembers();
    }

    function testFuzz_crossMemberSandwichDoesNotProfitInBalancedFixture(uint96 rawFront, uint96 rawVictim) public {
        uint256 front = bound(uint256(rawFront), 1e12, 40 ether);
        uint256 victimSize = bound(uint256(rawVictim), 1e12, 40 ether);
        address trader = address(0xB0B);
        _fundAndApproveTrader(trader, victimSize, 0);
        uint256 attacker0Before = currency0.balanceOf(address(this));
        uint256 attacker1Before = currency1.balanceOf(address(this));

        _swap(keyB, true, -int256(front));
        uint256 inventory1 = currency1.balanceOf(address(this)) - attacker1Before;
        vm.prank(trader);
        _swap(keyA, true, -int256(victimSize));
        _swap(keyB, false, -int256(inventory1));

        assertLe(currency0.balanceOf(address(this)), attacker0Before, "cross-member sandwich became profitable");
        _assertAggregateMatchesMembers();
    }

    function testFuzz_sameMemberSandwichNeverBeatsItsPlainCounterfactual(uint96 rawFront, uint96 rawVictim) public {
        uint256 front = bound(uint256(rawFront), 1e12, 40 ether);
        uint256 victimSize = bound(uint256(rawVictim), 1e12, 40 ether);
        address trader = address(0xB0B);
        _fundAndApproveTrader(trader, victimSize, 0);
        uint256 attacker0Before = currency0.balanceOf(address(this));
        uint256 attacker1Before = currency1.balanceOf(address(this));

        _swap(keyA, true, -int256(front));
        uint256 inventory1 = currency1.balanceOf(address(this)) - attacker1Before;
        vm.prank(trader);
        _swap(keyA, true, -int256(victimSize));
        _swap(keyA, false, -int256(inventory1));

        int256 knotPnl = int256(currency0.balanceOf(address(this))) - int256(attacker0Before);
        int256 plainPnl = _plainSandwichPnl(front, victimSize);
        assertLe(knotPnl, plainPnl, "the boundary made a same-member sandwich more profitable");
        _assertAggregateMatchesMembers();
    }

    /// @dev This is a bounded portfolio comparison, not a theorem that KNOT eliminates sandwiching.
    ///      It varies three independent member states and all front/victim/back member choices,
    ///      then compares any profitable closed attacker portfolio with the exact same route
    ///      through plain constant-product pools. A losing route may rationally lose less under
    ///      different state transitions; the security question is whether KNOT creates or
    ///      amplifies positive extraction. This probes that composition without overclaiming.
    function testFuzz_threeMemberExactInputProfitNeverExceedsPlainRoute(
        uint96 raw00,
        uint96 raw01,
        uint96 raw10,
        uint96 raw11,
        uint96 raw20,
        uint96 raw21,
        uint64 rawFront,
        uint64 rawVictim,
        uint8 rawRoute
    ) public pure {
        ThreePoolState memory initial = _boundedState(raw00, raw01, raw10, raw11, raw20, raw21);
        uint256 front = bound(uint256(rawFront), 1e12, 20 ether);
        uint256 victim = bound(uint256(rawVictim), 1e12, 20 ether);
        (uint256 frontMember, uint256 victimMember, uint256 backMember) = _route(rawRoute);

        int256 knotPnl = _exactInputSandwichPnl(initial, front, victim, frontMember, victimMember, backMember, true);
        int256 plainPnl = _exactInputSandwichPnl(initial, front, victim, frontMember, victimMember, backMember, false);

        if (knotPnl > 0) {
            assertLe(knotPnl, plainPnl, "KNOT created or amplified profitable exact-input extraction");
        }
    }

    /// @dev The attacker's opening leg uses exact output, which exercises the max-input side of
    ///      the boundary. The closing leg spends the exact inventory acquired, so both portfolios
    ///      finish in token0 and can be compared without an invented mark price.
    function testFuzz_threeMemberExactOutputProfitNeverExceedsPlainRoute(
        uint96 raw00,
        uint96 raw01,
        uint96 raw10,
        uint96 raw11,
        uint96 raw20,
        uint96 raw21,
        uint64 rawOutput,
        uint64 rawVictim,
        uint8 rawRoute
    ) public pure {
        ThreePoolState memory initial = _boundedState(raw00, raw01, raw10, raw11, raw20, raw21);
        uint256 output = bound(uint256(rawOutput), 1e12, 5 ether);
        uint256 victim = bound(uint256(rawVictim), 1e12, 20 ether);
        (uint256 frontMember, uint256 victimMember, uint256 backMember) = _route(rawRoute);

        int256 knotPnl = _exactOutputSandwichPnl(initial, output, victim, frontMember, victimMember, backMember, true);
        int256 plainPnl = _exactOutputSandwichPnl(initial, output, victim, frontMember, victimMember, backMember, false);

        if (knotPnl > 0) {
            assertLe(knotPnl, plainPnl, "KNOT created or amplified profitable exact-output extraction");
        }
    }

    function _plainSandwich() private pure returns (uint256 profit, uint256 victimOutput, uint256 finalProduct) {
        uint256 reserve0 = 100 ether;
        uint256 reserve1 = 100 ether;
        uint256 attackerInventory = _cpmmOutput(10 ether, reserve0, reserve1);
        reserve0 += 10 ether;
        reserve1 -= attackerInventory;

        victimOutput = _cpmmOutput(10 ether, reserve0, reserve1);
        reserve0 += 10 ether;
        reserve1 -= victimOutput;

        uint256 attackerExit = _cpmmOutput(attackerInventory, reserve1, reserve0);
        reserve1 += attackerInventory;
        reserve0 -= attackerExit;
        profit = attackerExit - 10 ether;
        finalProduct = reserve0 * reserve1;
    }

    function _cpmmOutput(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        return reserveOut * amountIn / (reserveIn + amountIn);
    }

    function _plainSandwichPnl(uint256 front, uint256 victimSize) private pure returns (int256) {
        uint256 reserve0 = 100 ether;
        uint256 reserve1 = 100 ether;
        uint256 inventory1 = _cpmmOutput(front, reserve0, reserve1);
        reserve0 += front;
        reserve1 -= inventory1;
        uint256 victimOutput = _cpmmOutput(victimSize, reserve0, reserve1);
        reserve0 += victimSize;
        reserve1 -= victimOutput;
        uint256 exit0 = _cpmmOutput(inventory1, reserve1, reserve0);
        return int256(exit0) - int256(front);
    }

    function _boundedState(uint96 raw00, uint96 raw01, uint96 raw10, uint96 raw11, uint96 raw20, uint96 raw21)
        private
        pure
        returns (ThreePoolState memory state)
    {
        state.reserve0 = [
            bound(uint256(raw00), 50 ether, 5_000 ether),
            bound(uint256(raw10), 50 ether, 5_000 ether),
            bound(uint256(raw20), 50 ether, 5_000 ether)
        ];
        state.reserve1 = [
            bound(uint256(raw01), 50 ether, 5_000 ether),
            bound(uint256(raw11), 50 ether, 5_000 ether),
            bound(uint256(raw21), 50 ether, 5_000 ether)
        ];
    }

    function _route(uint8 rawRoute) private pure returns (uint256 front, uint256 victim, uint256 back) {
        front = uint256(rawRoute) % 3;
        victim = (uint256(rawRoute) / 3) % 3;
        back = (uint256(rawRoute) / 9) % 3;
    }

    function _exactInputSandwichPnl(
        ThreePoolState memory state,
        uint256 front,
        uint256 victim,
        uint256 frontMember,
        uint256 victimMember,
        uint256 backMember,
        bool federated
    ) private pure returns (int256) {
        uint256 inventory1 = _modelExactInput(state, frontMember, true, front, federated);
        _modelExactInput(state, victimMember, true, victim, federated);
        uint256 exit0 = _modelExactInput(state, backMember, false, inventory1, federated);
        return int256(exit0) - int256(front);
    }

    function _exactOutputSandwichPnl(
        ThreePoolState memory state,
        uint256 output,
        uint256 victim,
        uint256 frontMember,
        uint256 victimMember,
        uint256 backMember,
        bool federated
    ) private pure returns (int256) {
        uint256 input0 = _modelExactOutput(state, frontMember, true, output, federated);
        _modelExactInput(state, victimMember, true, victim, federated);
        uint256 exit0 = _modelExactInput(state, backMember, false, output, federated);
        return int256(exit0) - int256(input0);
    }

    function _modelExactInput(
        ThreePoolState memory state,
        uint256 member,
        bool zeroForOne,
        uint256 amountIn,
        bool federated
    ) private pure returns (uint256 amountOut) {
        (uint256 localIn, uint256 localOut) = zeroForOne
            ? (state.reserve0[member], state.reserve1[member])
            : (state.reserve1[member], state.reserve0[member]);
        uint256 local = KnotMath.amountOut(amountIn, localIn, localOut, MODEL_FEE_NUMERATOR, MODEL_FEE_DENOMINATOR);
        amountOut = local;
        if (federated) {
            (uint256 aggregate0, uint256 aggregate1) = _aggregate(state);
            (uint256 aggregateIn, uint256 aggregateOut) =
                zeroForOne ? (aggregate0, aggregate1) : (aggregate1, aggregate0);
            uint256 shared =
                KnotMath.amountOut(amountIn, aggregateIn, aggregateOut, MODEL_FEE_NUMERATOR, MODEL_FEE_DENOMINATOR);
            if (shared < amountOut) amountOut = shared;
        }
        _applyModelSwap(state, member, zeroForOne, amountIn, amountOut);
    }

    function _modelExactOutput(
        ThreePoolState memory state,
        uint256 member,
        bool zeroForOne,
        uint256 amountOut,
        bool federated
    ) private pure returns (uint256 amountIn) {
        (uint256 localIn, uint256 localOut) = zeroForOne
            ? (state.reserve0[member], state.reserve1[member])
            : (state.reserve1[member], state.reserve0[member]);
        amountIn = KnotMath.amountIn(amountOut, localIn, localOut, MODEL_FEE_NUMERATOR, MODEL_FEE_DENOMINATOR);
        if (federated) {
            (uint256 aggregate0, uint256 aggregate1) = _aggregate(state);
            (uint256 aggregateIn, uint256 aggregateOut) =
                zeroForOne ? (aggregate0, aggregate1) : (aggregate1, aggregate0);
            uint256 shared =
                KnotMath.amountIn(amountOut, aggregateIn, aggregateOut, MODEL_FEE_NUMERATOR, MODEL_FEE_DENOMINATOR);
            if (shared > amountIn) amountIn = shared;
        }
        _applyModelSwap(state, member, zeroForOne, amountIn, amountOut);
    }

    function _aggregate(ThreePoolState memory state) private pure returns (uint256 reserve0, uint256 reserve1) {
        reserve0 = state.reserve0[0] + state.reserve0[1] + state.reserve0[2];
        reserve1 = state.reserve1[0] + state.reserve1[1] + state.reserve1[2];
    }

    function _applyModelSwap(
        ThreePoolState memory state,
        uint256 member,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOut
    ) private pure {
        if (zeroForOne) {
            state.reserve0[member] += amountIn;
            state.reserve1[member] -= amountOut;
        } else {
            state.reserve1[member] += amountIn;
            state.reserve0[member] -= amountOut;
        }
    }
}
