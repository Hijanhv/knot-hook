// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";

/// @notice Constant-product quoting with an LP fee retained in the input reserve.
library KnotMath {
    error InvalidFee();
    error InsufficientLiquidity();
    error ZeroAmount();

    function amountOut(
        uint256 inputAmount,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) internal pure returns (uint256 output) {
        _validate(inputAmount, reserveIn, reserveOut, feeNumerator, feeDenominator);
        uint256 netInput = FullMath.mulDiv(inputAmount, feeNumerator, feeDenominator);
        if (netInput == 0) revert ZeroAmount();
        output = FullMath.mulDiv(reserveOut, netInput, reserveIn + netInput);
        if (output == 0 || output >= reserveOut) revert InsufficientLiquidity();
    }

    function amountIn(
        uint256 outputAmount,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) internal pure returns (uint256 input) {
        _validate(outputAmount, reserveIn, reserveOut, feeNumerator, feeDenominator);
        if (outputAmount >= reserveOut) revert InsufficientLiquidity();
        uint256 netInput = FullMath.mulDivRoundingUp(reserveIn, outputAmount, reserveOut - outputAmount);
        input = FullMath.mulDivRoundingUp(netInput, feeDenominator, feeNumerator);
    }

    function _validate(
        uint256 amount,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) private pure {
        if (amount == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        if (feeNumerator == 0 || feeNumerator > feeDenominator) revert InvalidFee();
    }
}
