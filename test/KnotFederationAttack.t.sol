// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {KnotTestBase} from "./utils/KnotTestBase.sol";

contract KnotFederationAttackTest is KnotTestBase {
    using CurrencyLibrary for Currency;

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
}
