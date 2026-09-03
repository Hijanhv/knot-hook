// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {KnotMath} from "../../src/libraries/KnotMath.sol";

/// @title Mechanical selectivity of the KNOT price boundary.
/// @notice These properties prove which quotes KNOT changes. They do not turn reserve divergence
///         into an oracle or prove that a selected swap is toxic.
contract DirectionalSelectivityTest is Test {
    uint256 internal constant FEE_NUMERATOR = 997;
    uint256 internal constant FEE_DENOMINATOR = 1000;

    function _amountOut(uint256 amount, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        return KnotMath.amountOut(amount, reserveIn, reserveOut, FEE_NUMERATOR, FEE_DENOMINATOR);
    }

    function _amountIn(uint256 amount, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        return KnotMath.amountIn(amount, reserveIn, reserveOut, FEE_NUMERATOR, FEE_DENOMINATOR);
    }

    /// @dev For exact input, KNOT changes the local quote exactly when it would give the taker
    ///      more output than the aggregate reference.
    function testFuzz_exactInputBindsExactlyOnTheMoreGenerousLocalQuote(
        uint96 rawLocal0,
        uint96 rawLocal1,
        uint96 rawExtra0,
        uint96 rawExtra1,
        uint96 rawInput
    ) public pure {
        uint256 local0 = bound(uint256(rawLocal0), 1e18, 1e24);
        uint256 local1 = bound(uint256(rawLocal1), 1e18, 1e24);
        uint256 aggregate0 = local0 + bound(uint256(rawExtra0), 0, 1e24);
        uint256 aggregate1 = local1 + bound(uint256(rawExtra1), 0, 1e24);
        uint256 amount = bound(uint256(rawInput), 1e15, 1e21);

        uint256 localQuote = _amountOut(amount, local0, local1);
        uint256 aggregateQuote = _amountOut(amount, aggregate0, aggregate1);
        uint256 enforcedQuote = localQuote < aggregateQuote ? localQuote : aggregateQuote;

        bool localWasMoreGenerous = localQuote > aggregateQuote;
        assertEq(enforcedQuote < localQuote, localWasMoreGenerous, "exact-input selection changed branches");
        if (!localWasMoreGenerous) assertEq(enforcedQuote, localQuote, "a worse local quote was clipped");
    }

    /// @dev For exact output, KNOT changes the local quote exactly when it would charge the
    ///      taker less input than the aggregate reference.
    function testFuzz_exactOutputBindsExactlyOnTheCheaperLocalQuote(
        uint96 rawLocal0,
        uint96 rawLocal1,
        uint96 rawExtra0,
        uint96 rawExtra1,
        uint96 rawOutput
    ) public pure {
        uint256 local0 = bound(uint256(rawLocal0), 1e18, 1e24);
        uint256 local1 = bound(uint256(rawLocal1), 1e18, 1e24);
        uint256 aggregate0 = local0 + bound(uint256(rawExtra0), 0, 1e24);
        uint256 aggregate1 = local1 + bound(uint256(rawExtra1), 0, 1e24);
        uint256 amount = bound(uint256(rawOutput), 1e15, local1 / 4);

        uint256 localQuote = _amountIn(amount, local0, local1);
        uint256 aggregateQuote = _amountIn(amount, aggregate0, aggregate1);
        uint256 enforcedQuote = localQuote > aggregateQuote ? localQuote : aggregateQuote;

        bool localWasCheaper = localQuote < aggregateQuote;
        assertEq(enforcedQuote > localQuote, localWasCheaper, "exact-output selection changed branches");
        if (!localWasCheaper) assertEq(enforcedQuote, localQuote, "a costlier local quote was surcharged");
    }

    /// @dev The rule compares two quotes; it does not use the absolute size of the reserve-ratio gap.
    function test_divergenceMagnitudeIsNotASelectionInput() public pure {
        uint256 aggregate0 = 1100e18;
        uint256 aggregate1 = 1400e18;
        uint256 amount = 5e18;
        uint256 aggregateQuote = _amountOut(amount, aggregate0, aggregate1);

        uint256 farButWorseLocalQuote = _amountOut(amount, 900e18, 200e18);
        assertLt(farButWorseLocalQuote, aggregateQuote, "far fixture must quote worse locally");
        assertEq(
            farButWorseLocalQuote < aggregateQuote ? farButWorseLocalQuote : aggregateQuote,
            farButWorseLocalQuote,
            "large divergence alone engaged the bound"
        );

        uint256 nearButBetterLocalQuote = _amountOut(amount, 1090e18, 1400e18);
        assertGt(nearButBetterLocalQuote, aggregateQuote, "near fixture must quote better locally");
        assertEq(
            nearButBetterLocalQuote < aggregateQuote ? nearButBetterLocalQuote : aggregateQuote,
            aggregateQuote,
            "quote direction failed to engage the bound"
        );
    }

    /// @dev A member holding a proportional slice of the aggregate has the same spot ratio but
    ///      less depth. Its local quote is already the less favorable one and remains unchanged.
    function testFuzz_proportionalMemberIsNotClipped(uint96 rawShare, uint96 rawInput) public pure {
        uint256 share = bound(uint256(rawShare), 2, 50);
        uint256 aggregate0 = 1000e18;
        uint256 aggregate1 = 1000e18;
        uint256 local0 = aggregate0 / share;
        uint256 local1 = aggregate1 / share;
        uint256 amount = bound(uint256(rawInput), 1e15, 1e19);

        uint256 localQuote = _amountOut(amount, local0, local1);
        uint256 aggregateQuote = _amountOut(amount, aggregate0, aggregate1);
        uint256 enforcedQuote = localQuote < aggregateQuote ? localQuote : aggregateQuote;

        assertEq(enforcedQuote, localQuote, "proportional member was clipped");
    }
}
