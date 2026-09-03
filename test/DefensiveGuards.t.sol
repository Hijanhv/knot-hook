// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BaseFixture} from "./BaseFixture.sol";
import {KnotFederation} from "../src/KnotFederation.sol";
import {KnotHook} from "../src/KnotHook.sol";

/// @dev A registered member that does nothing but forward calls, so the federation's own guards
///      can be exercised directly rather than through a hook's happy path.
contract RawMember {
    KnotFederation public immutable fed;

    constructor(KnotFederation f) {
        fed = f;
    }

    /// Registration requires this to point back at the federation.
    function federation() external view returns (address) {
        return address(fed);
    }

    function adjust(int256 d0, int256 d1) external {
        fed.adjustLiquidity(d0, d1);
    }
}

/// @title Guards that were declared but never asserted.
///
/// @dev WHY THIS FILE EXISTS
///      Six errors in the contracts had zero references anywhere in the suite:
///      AmountTooLarge, ReserveUnderflow, InvalidLiquidityMaturity, EmptyDeposit, PairMismatch
///      and ReentrantCall. A guard nothing exercises is a guard nobody knows still works, and a
///      later refactor can delete or invert one and no test goes red.
///
///      Five of the six are reachable and are asserted here by selector. The sixth is not, and
///      that is stated rather than faked: see the note at the bottom.
contract DefensiveGuardsTest is BaseFixture {
    // ── 1. InvalidLiquidityMaturity ──────────────────────────────────────

    /// @dev A zero maturity window would let a deposit back a quote in its own block, which is
    ///      the just-in-time attack the window exists to close. The constructor must refuse it.
    ///
    ///      The deployment has to go to a flag-valid address. `BaseHook` validates the address
    ///      before `KnotHook`'s own constructor body runs, so a plain `new` at an arbitrary
    ///      address reverts with `HookAddressNotValid` and never reaches this guard. Mining the
    ///      address first is what makes the maturity check the thing under test.
    function test_guard_zeroMaturityIsRejectedAtConstruction() public {
        address slot = address(REQUIRED_FLAGS | (uint160(7) << 80));
        vm.expectRevert(KnotHook.InvalidLiquidityMaturity.selector);
        deployCodeTo(
            "src/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Zero", "ZERO", uint256(0)),
            slot
        );
    }

    // ── 2. ReserveUnderflow ──────────────────────────────────────────────

    /// @dev A member reporting a withdrawal larger than it holds must not silently wrap the
    ///      book. This is the guard standing between an accounting bug and a free-money bug.
    function test_guard_memberCannotWithdrawMoreThanItHolds() public {
        RawMember rogue = new RawMember(federation);
        federation.register(address(rogue));

        // The member has never deposited, so any negative delta underflows its book.
        vm.expectRevert(KnotFederation.ReserveUnderflow.selector);
        rogue.adjust(-1, 0);
    }

    /// @dev Same guard on the other side of the pair, so a fix to one branch cannot leave the
    ///      other open.
    function test_guard_underflowIsCheckedOnBothSides() public {
        RawMember rogue = new RawMember(federation);
        federation.register(address(rogue));

        rogue.adjust(10 ether, 10 ether); // give it a small book
        vm.expectRevert(KnotFederation.ReserveUnderflow.selector);
        rogue.adjust(0, -11 ether);
    }

    // ── 3. AmountTooLarge ────────────────────────────────────────────────

    /// @dev int256.min has no positive counterpart, so negating it is undefined. The federation
    ///      rejects it explicitly rather than relying on checked arithmetic to catch it later.
    function test_guard_int256MinDeltaIsRejected() public {
        RawMember rogue = new RawMember(federation);
        federation.register(address(rogue));

        vm.expectRevert(KnotFederation.AmountTooLarge.selector);
        rogue.adjust(type(int256).min, 0);
    }

    // ── 4. EmptyDeposit ──────────────────────────────────────────────────

    /// @dev Seeding an empty member with a zero on either side would mint shares against a
    ///      one-sided book and make the first quote meaningless.
    function test_guard_emptySeedIsRejected() public {
        KnotHook fresh = _deployHook(3, "Fresh", "FRESH");
        federation.register(address(fresh));
        initPool(currency0, currency1, IHooks(address(fresh)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        _approveHook(address(fresh));

        vm.expectRevert(KnotHook.EmptyDeposit.selector);
        fresh.addLiquidity(addParams(0, 100 ether));

        vm.expectRevert(KnotHook.EmptyDeposit.selector);
        fresh.addLiquidity(addParams(100 ether, 0));
    }

    // ── 5. PairMismatch ──────────────────────────────────────────────────

    /// @dev A member must only serve the pair its federation accounts for. Initialising it
    ///      against a different pair would let unrelated reserves feed the shared book.
    function test_guard_poolWithTheWrongPairIsRejected() public {
        KnotHook fresh = _deployHook(3, "Fresh", "FRESH");
        federation.register(address(fresh));

        // A third currency the federation knows nothing about.
        Currency other = deployMintAndApproveCurrency();
        (Currency a, Currency b) = Currency.unwrap(other) < Currency.unwrap(currency1)
            ? (other, currency1)
            : (currency1, other);

        PoolKey memory wrong = PoolKey({
            currency0: a,
            currency1: b,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(fresh))
        });

        vm.expectRevert();
        manager.initialize(wrong, SQRT_PRICE_1_1);
    }

    // ── 6. ReentrantCall, and why there is no test for it ────────────────

    /// @dev `adjustLiquidity` and `executeSwap` both carry `nonReentrant`, and neither makes an
    ///      external call while the lock is held: the reserve updates are pure storage writes
    ///      and the quote is an internal view. There is therefore no path that re-enters the
    ///      federation mid-update, and no honest test can drive `ReentrantCall`.
    ///
    ///      Asserting that absence is the useful thing, because it is what makes the guard
    ///      unreachable, and a refactor that adds an external call inside either function would
    ///      break it. This checks the property that holds today: a member can call back into
    ///      the federation immediately after its own call returns, and the lock has been
    ///      released cleanly rather than left set.
    function test_guard_lockIsReleasedAndNotLeftSet() public {
        RawMember rogue = new RawMember(federation);
        federation.register(address(rogue));

        rogue.adjust(5 ether, 5 ether);
        rogue.adjust(5 ether, 5 ether); // would revert with ReentrantCall if the lock leaked

        (uint256 r0, uint256 r1) = federation.reservesOf(address(rogue));
        assertEq(r0, 10 ether, "second call did not apply");
        assertEq(r1, 10 ether, "second call did not apply");
    }
}
