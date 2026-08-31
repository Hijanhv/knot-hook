// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {KnotMath} from "./KnotMath.sol";

interface IKnotMember {
    function federation() external view returns (address);
}

/// @title Knot Federation
/// @notice Maintains authenticated per-pool and aggregate reserves for one token pair.
contract KnotFederation is Ownable {
    struct Reserves {
        uint256 reserve0;
        uint256 reserve1;
    }

    address public immutable currency0;
    address public immutable currency1;
    uint256 public immutable feeNumerator;
    uint256 public immutable feeDenominator;
    uint256 public immutable maxMembers;
    uint256 public memberCount;
    uint256 public aggregateReserve0;
    uint256 public aggregateReserve1;
    bool private _locked;

    mapping(address hook => bool) public isMember;
    mapping(address hook => Reserves) private _reserves;

    error AlreadyMember();
    error NotMember();
    error InvalidPair();
    error InvalidFee();
    error ReserveUnderflow();
    error ReentrantCall();
    error AmountTooLarge();
    error InvalidMember();
    error InvalidMemberLimit();
    error MemberLimitReached();
    error MemberNotEmpty();

    event MemberRegistered(address indexed hook);
    event MemberUnregistered(address indexed hook);
    event LiquidityAdjusted(
        address indexed hook, int256 delta0, int256 delta1, uint256 aggregateReserve0, uint256 aggregateReserve1
    );
    event FederatedSwap(
        address indexed hook,
        bool zeroForOne,
        bool exactInput,
        uint256 specifiedAmount,
        uint256 localQuote,
        uint256 aggregateQuote,
        uint256 chargedAmount
    );

    modifier onlyMember() {
        if (!isMember[msg.sender]) revert NotMember();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address token0,
        address token1,
        uint256 numerator,
        uint256 denominator,
        uint256 memberLimit,
        address initialOwner
    ) Ownable(initialOwner) {
        if (token0 >= token1) revert InvalidPair();
        if (numerator == 0 || numerator > denominator) revert InvalidFee();
        if (memberLimit == 0) revert InvalidMemberLimit();
        currency0 = token0;
        currency1 = token1;
        feeNumerator = numerator;
        feeDenominator = denominator;
        maxMembers = memberLimit;
    }

    /// @notice Adds a reviewed hook instance to this bounded federation.
    function register(address hook) external onlyOwner {
        if (hook.code.length == 0) revert InvalidMember();
        if (isMember[hook]) revert AlreadyMember();
        if (memberCount == maxMembers) revert MemberLimitReached();
        try IKnotMember(hook).federation() returns (address memberFederation) {
            if (memberFederation != address(this)) revert InvalidMember();
        } catch {
            revert InvalidMember();
        }
        isMember[hook] = true;
        memberCount++;
        emit MemberRegistered(hook);
    }

    /// @notice Removes an empty member so its bounded federation slot can be reused.
    function unregister(address hook) external onlyOwner {
        if (!isMember[hook]) revert NotMember();
        Reserves storage reserves = _reserves[hook];
        if (reserves.reserve0 != 0 || reserves.reserve1 != 0) revert MemberNotEmpty();
        isMember[hook] = false;
        memberCount--;
        emit MemberUnregistered(hook);
    }

    /// @notice Returns one member pool's accounting reserves.
    function reservesOf(address hook) external view returns (uint256 reserve0, uint256 reserve1) {
        Reserves storage reserves = _reserves[hook];
        return (reserves.reserve0, reserves.reserve1);
    }

    /// @notice Applies a member pool's completed liquidity change to both ledgers.
    function adjustLiquidity(int256 delta0, int256 delta1) external onlyMember nonReentrant {
        Reserves storage local = _reserves[msg.sender];
        local.reserve0 = _apply(local.reserve0, delta0);
        local.reserve1 = _apply(local.reserve1, delta1);
        aggregateReserve0 = _apply(aggregateReserve0, delta0);
        aggregateReserve1 = _apply(aggregateReserve1, delta1);
        emit LiquidityAdjusted(msg.sender, delta0, delta1, aggregateReserve0, aggregateReserve1);
    }

    /// @notice Shows the local quote, federation quote and enforceable Knot quote.
    function preview(address hook, bool zeroForOne, bool exactInput, uint256 specifiedAmount)
        public
        view
        returns (uint256 localQuote, uint256 aggregateQuote, uint256 knotQuote)
    {
        if (!isMember[hook]) revert NotMember();
        Reserves storage local = _reserves[hook];
        (uint256 localIn, uint256 localOut) =
            zeroForOne ? (local.reserve0, local.reserve1) : (local.reserve1, local.reserve0);
        (uint256 aggregateIn, uint256 aggregateOut) =
            zeroForOne ? (aggregateReserve0, aggregateReserve1) : (aggregateReserve1, aggregateReserve0);

        if (exactInput) {
            localQuote = KnotMath.amountOut(specifiedAmount, localIn, localOut, feeNumerator, feeDenominator);
            aggregateQuote =
                KnotMath.amountOut(specifiedAmount, aggregateIn, aggregateOut, feeNumerator, feeDenominator);
            knotQuote = localQuote < aggregateQuote ? localQuote : aggregateQuote;
        } else {
            localQuote = KnotMath.amountIn(specifiedAmount, localIn, localOut, feeNumerator, feeDenominator);
            aggregateQuote = KnotMath.amountIn(specifiedAmount, aggregateIn, aggregateOut, feeNumerator, feeDenominator);
            knotQuote = localQuote > aggregateQuote ? localQuote : aggregateQuote;
        }
    }

    /// @notice Quotes and atomically updates the local and aggregate reserve books.
    function executeSwap(bool zeroForOne, bool exactInput, uint256 specifiedAmount)
        external
        onlyMember
        nonReentrant
        returns (uint256 unspecifiedAmount)
    {
        (uint256 localQuote, uint256 aggregateQuote, uint256 knotQuote) =
            preview(msg.sender, zeroForOne, exactInput, specifiedAmount);
        uint256 amountIn = exactInput ? specifiedAmount : knotQuote;
        uint256 amountOut = exactInput ? knotQuote : specifiedAmount;
        Reserves storage local = _reserves[msg.sender];

        if (zeroForOne) {
            local.reserve0 += amountIn;
            local.reserve1 -= amountOut;
            aggregateReserve0 += amountIn;
            aggregateReserve1 -= amountOut;
        } else {
            local.reserve1 += amountIn;
            local.reserve0 -= amountOut;
            aggregateReserve1 += amountIn;
            aggregateReserve0 -= amountOut;
        }
        emit FederatedSwap(msg.sender, zeroForOne, exactInput, specifiedAmount, localQuote, aggregateQuote, knotQuote);
        return knotQuote;
    }

    function _apply(uint256 value, int256 delta) private pure returns (uint256 result) {
        // casting is safe because the branch only runs for a non-negative `delta`
        // forge-lint: disable-next-line(unsafe-typecast)
        if (delta >= 0) return value + uint256(delta);
        if (delta == type(int256).min) revert AmountTooLarge();
        // casting is safe because `delta` is negative and int256.min was rejected above
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 decrease = uint256(-delta);
        if (decrease > value) revert ReserveUnderflow();
        return value - decrease;
    }
}
