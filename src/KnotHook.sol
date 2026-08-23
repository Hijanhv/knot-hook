// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseCustomCurve} from "ozhooks/base/BaseCustomCurve.sol";
import {BaseHook} from "ozhooks/base/BaseHook.sol";
import {KnotFederation} from "./KnotFederation.sol";

/// @title Knot Pool
/// @notice A hook-owned AMM whose quote cannot be more favorable than its pair-wide reserve state.
contract KnotHook is BaseCustomCurve, ERC20 {
    struct PendingLiquidity {
        uint256 amount0;
        uint256 amount1;
        uint256 activatesAtBlock;
    }

    struct LiquidityRefund {
        uint256 amount0;
        uint256 amount1;
    }

    KnotFederation public immutable federation;
    uint256 public immutable liquidityMaturityBlocks;

    uint256 public inactiveAssets0;
    uint256 public inactiveAssets1;

    mapping(address provider => PendingLiquidity request) public pendingLiquidity;
    mapping(address provider => LiquidityRefund refund) public claimableLiquidityRefund;

    error PairMismatch();
    error EmptyDeposit();
    error ZeroShares();
    error AmountTooLarge();
    error InvalidLiquidityMaturity();
    error OnlyInitialLiquidityProvider();
    error PendingLiquidityExists();
    error NoPendingLiquidity();
    error LiquidityNotMature();
    error OnlyFederationOwner();
    error InactiveMember();
    error NoLiquidityRefund();
    error UnclaimedLiquidityRefund();

    event LiquidityQueued(address indexed provider, uint256 amount0, uint256 amount1, uint256 activatesAtBlock);
    event LiquidityActivated(
        address indexed provider, uint256 amount0, uint256 amount1, uint256 shares, uint256 refund0, uint256 refund1
    );
    event LiquidityCancelled(address indexed provider, uint256 amount0, uint256 amount1);
    event LiquidityRefundClaimed(address indexed provider, uint256 amount0, uint256 amount1);

    constructor(
        IPoolManager manager,
        KnotFederation reserveFederation,
        string memory shareName,
        string memory shareSymbol,
        uint256 maturityBlocks
    ) BaseHook(manager) ERC20(shareName, shareSymbol) {
        if (maturityBlocks == 0) revert InvalidLiquidityMaturity();
        federation = reserveFederation;
        liquidityMaturityBlocks = maturityBlocks;
    }

    /// @notice Returns this pool's active reserve ledger.
    function reserves() external view returns (uint256 reserve0, uint256 reserve1) {
        return federation.reservesOf(address(this));
    }

    /// @notice Activates the caller's matured deposit at the current active reserve ratio.
    function activatePendingLiquidity() external {
        address provider = msg.sender;
        PendingLiquidity memory request = pendingLiquidity[provider];
        if (request.activatesAtBlock == 0) revert NoPendingLiquidity();
        if (block.number < request.activatesAtBlock) revert LiquidityNotMature();

        delete pendingLiquidity[provider];

        (uint256 reserve0, uint256 reserve1) = federation.reservesOf(address(this));
        uint256 supply = totalSupply();
        uint256 shares;
        uint256 amount0;
        uint256 amount1;

        if (supply == 0) {
            amount0 = request.amount0;
            amount1 = request.amount1;
            shares = amount0 < amount1 ? amount0 : amount1;
        } else {
            if (reserve0 == 0 || reserve1 == 0) revert ZeroShares();
            uint256 shares0 = FullMath.mulDiv(request.amount0, supply, reserve0);
            uint256 shares1 = FullMath.mulDiv(request.amount1, supply, reserve1);
            shares = shares0 < shares1 ? shares0 : shares1;
            if (shares == 0) revert ZeroShares();
            amount0 = FullMath.mulDivRoundingUp(shares, reserve0, supply);
            amount1 = FullMath.mulDivRoundingUp(shares, reserve1, supply);
        }

        uint256 refund0 = request.amount0 - amount0;
        uint256 refund1 = request.amount1 - amount1;
        inactiveAssets0 -= amount0;
        inactiveAssets1 -= amount1;
        federation.adjustLiquidity(_toInt(amount0), _toInt(amount1));
        _mint(provider, shares);
        _creditRefund(provider, refund0, refund1);

        emit LiquidityActivated(provider, amount0, amount1, shares, refund0, refund1);
    }

    /// @notice Cancels the caller's inactive deposit without affecting active liquidity.
    function cancelPendingLiquidity() external {
        address provider = msg.sender;
        PendingLiquidity memory request = pendingLiquidity[provider];
        if (request.activatesAtBlock == 0) revert NoPendingLiquidity();

        delete pendingLiquidity[provider];
        _creditRefund(provider, request.amount0, request.amount1);
        emit LiquidityCancelled(provider, request.amount0, request.amount1);
    }

    /// @notice Withdraws all liquidity assets currently refundable to the caller.
    function claimLiquidityRefund() external {
        LiquidityRefund memory refund = claimableLiquidityRefund[msg.sender];
        if (refund.amount0 == 0 && refund.amount1 == 0) revert NoLiquidityRefund();

        delete claimableLiquidityRefund[msg.sender];
        inactiveAssets0 -= refund.amount0;
        inactiveAssets1 -= refund.amount1;
        _modifyLiquidity(abi.encode(-_toInt128(refund.amount0), -_toInt128(refund.amount1)));

        emit LiquidityRefundClaimed(msg.sender, refund.amount0, refund.amount1);
    }

    function _beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
        internal
        override
        returns (bytes4)
    {
        if (sender != federation.owner()) revert OnlyFederationOwner();
        if (
            !federation.isMember(address(this)) || Currency.unwrap(key.currency0) != federation.currency0()
                || Currency.unwrap(key.currency1) != federation.currency1()
        ) revert PairMismatch();
        return super._beforeInitialize(sender, key, sqrtPriceX96);
    }

    function _getUnspecifiedAmount(SwapParams calldata params) internal override returns (uint256 unspecifiedAmount) {
        bool exactInput = params.amountSpecified < 0;
        if (params.amountSpecified == type(int256).min) revert AmountTooLarge();
        uint256 specifiedAmount = exactInput ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
        if (specifiedAmount > uint256(uint128(type(int128).max))) revert AmountTooLarge();
        unspecifiedAmount = federation.executeSwap(params.zeroForOne, exactInput, specifiedAmount);
        if (unspecifiedAmount > uint256(uint128(type(int128).max))) revert AmountTooLarge();
    }

    function _getSwapFeeAmount(SwapParams calldata params, uint256 unspecifiedAmount)
        internal
        view
        override
        returns (uint256 swapFeeAmount)
    {
        uint256 grossInput = params.amountSpecified < 0 ? uint256(-params.amountSpecified) : unspecifiedAmount;
        uint256 netInput = FullMath.mulDiv(grossInput, federation.feeNumerator(), federation.feeDenominator());
        return grossInput - netInput;
    }

    function _getAmountIn(AddLiquidityParams memory params)
        internal
        view
        override
        returns (uint256 amount0, uint256 amount1, uint256 shares)
    {
        if (!federation.isMember(address(this))) revert InactiveMember();
        if (pendingLiquidity[msg.sender].activatesAtBlock != 0) revert PendingLiquidityExists();
        LiquidityRefund memory refund = claimableLiquidityRefund[msg.sender];
        if (refund.amount0 != 0 || refund.amount1 != 0) revert UnclaimedLiquidityRefund();
        (uint256 reserve0, uint256 reserve1) = federation.reservesOf(address(this));
        uint256 supply = totalSupply();

        if (supply == 0) {
            if (msg.sender != federation.owner()) revert OnlyInitialLiquidityProvider();
            amount0 = params.amount0Desired;
            amount1 = params.amount1Desired;
            if (amount0 == 0 || amount1 == 0) revert EmptyDeposit();
            shares = amount0 < amount1 ? amount0 : amount1;
        } else {
            if (reserve0 == 0 || reserve1 == 0) revert ZeroShares();
            uint256 shares0 = FullMath.mulDiv(params.amount0Desired, supply, reserve0);
            uint256 shares1 = FullMath.mulDiv(params.amount1Desired, supply, reserve1);
            shares = shares0 < shares1 ? shares0 : shares1;
            if (shares == 0) revert ZeroShares();
            amount0 = FullMath.mulDivRoundingUp(shares, reserve0, supply);
            amount1 = FullMath.mulDivRoundingUp(shares, reserve1, supply);
        }
    }

    function _getAmountOut(RemoveLiquidityParams memory params)
        internal
        override
        returns (uint256 amount0, uint256 amount1, uint256 shares)
    {
        (uint256 reserve0, uint256 reserve1) = federation.reservesOf(address(this));
        uint256 supply = totalSupply();
        shares = params.liquidity;
        if (shares == 0 || shares > supply) revert ZeroShares();
        amount0 = FullMath.mulDiv(shares, reserve0, supply);
        amount1 = FullMath.mulDiv(shares, reserve1, supply);
        federation.adjustLiquidity(-_toInt(amount0), -_toInt(amount1));
    }

    function _mint(AddLiquidityParams memory, BalanceDelta callerDelta, BalanceDelta, uint256) internal override {
        int128 delta0 = callerDelta.amount0();
        int128 delta1 = callerDelta.amount1();
        if (delta0 >= 0 || delta1 >= 0) revert EmptyDeposit();

        uint256 amount0 = uint256(uint128(-delta0));
        uint256 amount1 = uint256(uint128(-delta1));
        uint256 activatesAtBlock = block.number + liquidityMaturityBlocks;
        pendingLiquidity[msg.sender] = PendingLiquidity(amount0, amount1, activatesAtBlock);
        inactiveAssets0 += amount0;
        inactiveAssets1 += amount1;

        emit LiquidityQueued(msg.sender, amount0, amount1, activatesAtBlock);
    }

    function _burn(RemoveLiquidityParams memory, BalanceDelta, BalanceDelta, uint256 shares) internal override {
        _burn(msg.sender, shares);
    }

    function _creditRefund(address provider, uint256 amount0, uint256 amount1) private {
        if (amount0 == 0 && amount1 == 0) return;
        LiquidityRefund storage refund = claimableLiquidityRefund[provider];
        refund.amount0 += amount0;
        refund.amount1 += amount1;
    }

    function _toInt(uint256 amount) private pure returns (int256) {
        return int256(_toInt128(amount));
    }

    function _toInt128(uint256 amount) private pure returns (int128) {
        if (amount > uint256(uint128(type(int128).max))) revert AmountTooLarge();
        return int128(uint128(amount));
    }
}
