// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {KnotMath} from "../../src/libraries/KnotMath.sol";

contract KnotMathHarness {
    function amountOut(
        uint256 amount,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) external pure returns (uint256) {
        return KnotMath.amountOut(amount, reserveIn, reserveOut, feeNumerator, feeDenominator);
    }

    function amountIn(
        uint256 amount,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) external pure returns (uint256) {
        return KnotMath.amountIn(amount, reserveIn, reserveOut, feeNumerator, feeDenominator);
    }
}

contract KnotMathTest is Test {
    KnotMathHarness private harness;

    function setUp() public {
        harness = new KnotMathHarness();
    }

    function test_exactQuotesUseDocumentedConservativeRounding() public view {
        uint256 output = harness.amountOut(10 ether, 1000 ether, 1500 ether, 997, 1000);
        uint256 expectedNetInput = 10 ether * 997 / 1000;
        uint256 expectedOutput = 1500 ether * expectedNetInput / (1000 ether + expectedNetInput);
        assertEq(output, expectedOutput);

        uint256 requestedOutput = 10 ether;
        uint256 expectedNetRequired = _ceilDiv(1000 ether * requestedOutput, 1500 ether - requestedOutput);
        uint256 expectedGrossRequired = _ceilDiv(expectedNetRequired * 1000, 997);
        assertEq(harness.amountIn(requestedOutput, 1000 ether, 1500 ether, 997, 1000), expectedGrossRequired);
    }

    function test_extremeInt128SizedQuotesDoNotOverflow() public view {
        uint256 reserve = uint256(uint128(type(int128).max));
        uint256 output = harness.amountOut(reserve, reserve, reserve, 997, 1000);
        assertGt(output, 0);
        assertLt(output, reserve);

        uint256 input = harness.amountIn(reserve / 2, reserve, reserve, 997, 1000);
        assertGt(input, reserve / 2);
        assertLe(input, reserve + reserve / 100);
    }

    function test_invalidAndDustQuotesFailClosed() public {
        vm.expectRevert(KnotMath.ZeroAmount.selector);
        harness.amountOut(0, 100, 100, 997, 1000);
        vm.expectRevert(KnotMath.InsufficientLiquidity.selector);
        harness.amountOut(1, 0, 100, 997, 1000);
        vm.expectRevert(KnotMath.InvalidFee.selector);
        harness.amountOut(1, 100, 100, 0, 1000);
        vm.expectRevert(KnotMath.InvalidFee.selector);
        harness.amountOut(1, 100, 100, 1001, 1000);
        vm.expectRevert(KnotMath.ZeroAmount.selector);
        harness.amountOut(1, 100, 100, 1, 2);
        vm.expectRevert(KnotMath.InsufficientLiquidity.selector);
        harness.amountIn(100, 100, 100, 997, 1000);
    }

    function testFuzz_quotesMatchIndependentIntegerOracle(
        uint128 rawReserveIn,
        uint128 rawReserveOut,
        uint96 rawInput,
        uint96 rawOutput
    ) public view {
        uint256 reserveIn = bound(uint256(rawReserveIn), 1e12, 1e30);
        uint256 reserveOut = bound(uint256(rawReserveOut), 1e12, 1e30);
        uint256 amountIn = bound(uint256(rawInput), 1e6, 1e24);
        uint256 amountOut = bound(uint256(rawOutput), 1e6, reserveOut / 2);

        uint256 netInput = amountIn * 997 / 1000;
        uint256 expectedOutput = reserveOut * netInput / (reserveIn + netInput);
        vm.assume(expectedOutput != 0);
        assertEq(harness.amountOut(amountIn, reserveIn, reserveOut, 997, 1000), expectedOutput);

        uint256 netRequired = _ceilDiv(reserveIn * amountOut, reserveOut - amountOut);
        uint256 expectedInput = _ceilDiv(netRequired * 1000, 997);
        assertEq(harness.amountIn(amountOut, reserveIn, reserveOut, 997, 1000), expectedInput);
    }

    function testFuzz_exactOutputInputIsMinimal(uint128 rawReserveIn, uint128 rawReserveOut, uint96 rawOutput) public {
        uint256 reserveIn = bound(uint256(rawReserveIn), 1e12, 1e30);
        uint256 reserveOut = bound(uint256(rawReserveOut), 1e12, 1e30);
        uint256 requestedOutput = bound(uint256(rawOutput), 1e6, reserveOut / 2);
        uint256 requiredInput = harness.amountIn(requestedOutput, reserveIn, reserveOut, 997, 1000);

        assertGe(harness.amountOut(requiredInput, reserveIn, reserveOut, 997, 1000), requestedOutput);
        uint256 priorInput = requiredInput - 1;
        if (priorInput * 997 / 1000 == 0) {
            vm.expectRevert(KnotMath.ZeroAmount.selector);
            harness.amountOut(priorInput, reserveIn, reserveOut, 997, 1000);
        } else {
            assertLt(harness.amountOut(priorInput, reserveIn, reserveOut, 997, 1000), requestedOutput);
        }
    }

    function _ceilDiv(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        return numerator == 0 ? 0 : (numerator - 1) / denominator + 1;
    }
}
