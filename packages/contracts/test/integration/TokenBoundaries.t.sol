// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {BaseCustomAccounting} from "ozhooks/base/BaseCustomAccounting.sol";
import {HookTest} from "oztest/utils/HookTest.sol";
import {KnotFederation} from "../../src/core/KnotFederation.sol";
import {KnotHook} from "../../src/hooks/KnotHook.sol";

contract ToggleFeeToken is ERC20 {
    bool public feeEnabled;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }

    function setFeeEnabled(bool enabled) external {
        feeEnabled = enabled;
    }

    /// @dev Models a negative-supply rebase that reduces PoolManager's underlying balance
    /// without changing its ERC-6909 liabilities.
    function forceSupplyDecrease(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (feeEnabled && from != address(0) && to != address(0)) {
            uint256 fee = value / 100;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
        } else {
            super._update(from, to, value);
        }
    }
}

contract CallbackToken is ERC20 {
    address public callbackTarget;
    bytes public callbackData;
    bool public armed;
    bool public swallowFailure;
    bool public lastCallbackSucceeded;
    bytes4 public lastCallbackRevertSelector;

    error CallbackFailed();

    constructor() ERC20("Callback", "CALL") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function arm(address target, bytes calldata data, bool swallow) external {
        callbackTarget = target;
        callbackData = data;
        swallowFailure = swallow;
        lastCallbackSucceeded = false;
        lastCallbackRevertSelector = bytes4(0);
        armed = true;
    }

    function disarm() external {
        armed = false;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        _fireCallback();
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _fireCallback();
        return super.transferFrom(from, to, value);
    }

    function _fireCallback() private {
        if (armed) {
            armed = false;
            (bool success, bytes memory returnData) = callbackTarget.call(callbackData);
            lastCallbackSucceeded = success;
            if (!success && returnData.length >= 4) {
                bytes4 selector;
                assembly ("memory-safe") {
                    selector := mload(add(returnData, 0x20))
                }
                lastCallbackRevertSelector = selector;
            }
            if (!success && !swallowFailure) revert CallbackFailed();
        }
    }
}

/// @notice Executable evidence for KNOT's token boundary.
/// @dev Fee-on-transfer assets are unsupported. The important safety property is that
/// PoolManager refuses the short settlement and rolls back both KNOT reserve books.
contract TokenBoundariesTest is HookTest {
    using CurrencyLibrary for Currency;

    uint160 internal constant REQUIRED_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );

    KnotFederation internal federation;
    KnotHook internal hook;
    ToggleFeeToken internal taxed;
    ToggleFeeToken internal plain;
    PoolKey internal boundaryKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        taxed = new ToggleFeeToken("Taxed", "TAX");
        plain = new ToggleFeeToken("Plain", "PLAIN");

        (address token0, address token1) =
            address(taxed) < address(plain) ? (address(taxed), address(plain)) : (address(plain), address(taxed));
        currency0 = Currency.wrap(token0);
        currency1 = Currency.wrap(token1);
        federation = new KnotFederation(address(manager), token0, token1, 997, 1000, 2, address(this));
        hook = KnotHook(payable(address(REQUIRED_FLAGS | uint160(1 << 80))));
        deployCodeTo(
            "src/hooks/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Knot Token Boundary", "KNOT-T", 1),
            address(hook)
        );
        federation.register(address(hook));
        (boundaryKey,) =
            initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        ERC20(token0).approve(address(hook), type(uint256).max);
        ERC20(token1).approve(address(hook), type(uint256).max);
        ERC20(token0).approve(address(swapRouter), type(uint256).max);
        ERC20(token1).approve(address(swapRouter), type(uint256).max);
        hook.addLiquidity(
            BaseCustomAccounting.AddLiquidityParams(
                100 ether, 100 ether, 0, 0, type(uint256).max, -887220, 887220, bytes32(0)
            )
        );
        vm.roll(block.number + 1);
        hook.activatePendingLiquidity();
    }

    function test_feeOnTransferInputFailsClosedAndRollsBackBothBooks() public {
        taxed.setFeeEnabled(true);
        bool zeroForOne = Currency.unwrap(currency0) == address(taxed);
        (uint256 reserve0Before, uint256 reserve1Before) = federation.reservesOf(address(hook));
        uint256 aggregate0Before = federation.aggregateReserve0();
        uint256 aggregate1Before = federation.aggregateReserve1();
        uint256 claim0Before = manager.balanceOf(address(hook), currency0.toId());
        uint256 claim1Before = manager.balanceOf(address(hook), currency1.toId());

        vm.expectRevert(IPoolManager.CurrencyNotSettled.selector);
        swapRouter.swap(
            boundaryKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(5 ether),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            bytes("")
        );

        (uint256 reserve0After, uint256 reserve1After) = federation.reservesOf(address(hook));
        assertEq(reserve0After, reserve0Before);
        assertEq(reserve1After, reserve1Before);
        assertEq(federation.aggregateReserve0(), aggregate0Before);
        assertEq(federation.aggregateReserve1(), aggregate1Before);
        assertEq(manager.balanceOf(address(hook), currency0.toId()), claim0Before);
        assertEq(manager.balanceOf(address(hook), currency1.toId()), claim1Before);
    }

    function test_feeOnTransferOutputCanUnderdeliverSoPairIsExplicitlyUnsupported() public {
        taxed.setFeeEnabled(true);
        bool zeroForOne = Currency.unwrap(currency1) == address(taxed);
        (,, uint256 quotedOutput) = federation.preview(address(hook), zeroForOne, true, 5 ether);
        uint256 recipientBefore = taxed.balanceOf(address(this));

        swapRouter.swap(
            boundaryKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(5 ether),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            bytes("")
        );

        uint256 received = taxed.balanceOf(address(this)) - recipientBefore;
        assertLt(received, quotedOutput, "taxed output unexpectedly delivered the advertised amount");
        assertEq(received, quotedOutput - quotedOutput / 100, "fixture tax was not reflected in delivery");
    }

    function test_negativeRebaseCanMakeClaimsUnredeemableSoPairIsExplicitlyUnsupported() public {
        Currency rebasingCurrency = Currency.unwrap(currency0) == address(taxed) ? currency0 : currency1;
        uint256 managerBalanceBefore = taxed.balanceOf(address(manager));
        uint256 claimBefore = manager.balanceOf(address(hook), rebasingCurrency.toId());
        (uint256 reserve0Before, uint256 reserve1Before) = federation.reservesOf(address(hook));
        assertEq(managerBalanceBefore, claimBefore, "fixture must start fully backed");

        taxed.forceSupplyDecrease(address(manager), managerBalanceBefore / 2);
        assertLt(taxed.balanceOf(address(manager)), claimBefore, "negative rebase did not break underlying backing");
        assertEq(
            manager.balanceOf(address(hook), rebasingCurrency.toId()), claimBefore, "claim ledger moved with rebase"
        );

        vm.roll(hook.liquidityUnlockBlock(address(this)));
        uint256 allShares = hook.totalSupply();
        vm.expectRevert();
        hook.removeLiquidity(
            BaseCustomAccounting.RemoveLiquidityParams(allShares, 0, 0, type(uint256).max, -887220, 887220, bytes32(0))
        );

        (uint256 reserve0After, uint256 reserve1After) = federation.reservesOf(address(hook));
        assertEq(reserve0After, reserve0Before, "failed redemption mutated reserve0");
        assertEq(reserve1After, reserve1Before, "failed redemption mutated reserve1");
        assertEq(
            manager.balanceOf(address(hook), rebasingCurrency.toId()), claimBefore, "failed redemption burned claims"
        );
    }
}

/// @notice A callback-bearing token is outside the supported pair boundary, but its external
/// call must still be unable to leave KNOT's reserve ledger half-mutated during PoolManager
/// settlement. A swallowed callback failure lets the swap finish; a bubbled failure reverts it.
contract CallbackTokenBoundaryTest is HookTest {
    using CurrencyLibrary for Currency;

    uint160 internal constant REQUIRED_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );

    KnotFederation internal federation;
    KnotHook internal hook;
    CallbackToken internal callbackToken;
    ToggleFeeToken internal plainToken;
    PoolKey internal boundaryKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        callbackToken = new CallbackToken();
        plainToken = new ToggleFeeToken("Plain", "PLAIN");
        (address token0, address token1) = address(callbackToken) < address(plainToken)
            ? (address(callbackToken), address(plainToken))
            : (address(plainToken), address(callbackToken));
        currency0 = Currency.wrap(token0);
        currency1 = Currency.wrap(token1);
        federation = new KnotFederation(address(manager), token0, token1, 997, 1000, 1, address(this));
        hook = KnotHook(payable(address(REQUIRED_FLAGS | uint160(1 << 80))));
        deployCodeTo(
            "src/hooks/KnotHook.sol:KnotHook",
            abi.encode(address(manager), address(federation), "Knot Callback Boundary", "KNOT-C", 1),
            address(hook)
        );
        federation.register(address(hook));
        (boundaryKey,) =
            initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        ERC20(token0).approve(address(hook), type(uint256).max);
        ERC20(token1).approve(address(hook), type(uint256).max);
        ERC20(token0).approve(address(swapRouter), type(uint256).max);
        ERC20(token1).approve(address(swapRouter), type(uint256).max);
        hook.addLiquidity(_add(100 ether, 100 ether));
        vm.roll(block.number + 1);
        hook.activatePendingLiquidity();
        vm.roll(hook.liquidityUnlockBlock(address(this)));

        // Give the token contract real shares so its callback reaches PoolManager.unlock after
        // mutating the federation books, rather than failing early on an empty LP balance.
        assertTrue(hook.transfer(address(callbackToken), 1 ether));
    }

    function test_swallowedReentrantWithdrawalCannotCorruptSuccessfulSwap() public {
        bool zeroForOne = Currency.unwrap(currency0) == address(callbackToken);
        callbackToken.arm(address(hook), abi.encodeCall(hook.removeLiquidity, (_remove(1 ether))), true);
        uint256 callbackSharesBefore = hook.balanceOf(address(callbackToken));

        swapRouter.swap(
            boundaryKey,
            _swapParams(zeroForOne),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            bytes("")
        );

        assertFalse(callbackToken.lastCallbackSucceeded(), "nested PoolManager unlock unexpectedly succeeded");
        assertEq(hook.balanceOf(address(callbackToken)), callbackSharesBefore, "callback burned LP shares");
        _assertBacked();
    }

    function test_bubbledReentrantWithdrawalRollsBackSwapAndBothReserveBooks() public {
        bool zeroForOne = Currency.unwrap(currency0) == address(callbackToken);
        (uint256 reserve0Before, uint256 reserve1Before) = federation.reservesOf(address(hook));
        uint256 claim0Before = manager.balanceOf(address(hook), currency0.toId());
        uint256 claim1Before = manager.balanceOf(address(hook), currency1.toId());
        callbackToken.arm(address(hook), abi.encodeCall(hook.removeLiquidity, (_remove(1 ether))), false);

        vm.expectRevert(CallbackToken.CallbackFailed.selector);
        swapRouter.swap(
            boundaryKey,
            _swapParams(zeroForOne),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            bytes("")
        );

        (uint256 reserve0After, uint256 reserve1After) = federation.reservesOf(address(hook));
        assertEq(reserve0After, reserve0Before);
        assertEq(reserve1After, reserve1Before);
        assertEq(federation.aggregateReserve0(), reserve0Before);
        assertEq(federation.aggregateReserve1(), reserve1Before);
        assertEq(manager.balanceOf(address(hook), currency0.toId()), claim0Before);
        assertEq(manager.balanceOf(address(hook), currency1.toId()), claim1Before);
        callbackToken.disarm();
    }

    function test_liquidityRefundRejectsTokenCallbackReentrancyAndStillPaysOnce() public {
        hook.addLiquidity(_add(1 ether, 1 ether));
        hook.cancelPendingLiquidity();
        (uint256 refund0, uint256 refund1) = hook.claimableLiquidityRefund(address(this));
        uint256 token0Before = ERC20(Currency.unwrap(currency0)).balanceOf(address(this));
        uint256 token1Before = ERC20(Currency.unwrap(currency1)).balanceOf(address(this));

        callbackToken.arm(address(hook), abi.encodeCall(hook.claimLiquidityRefund, ()), true);
        hook.claimLiquidityRefund();

        assertFalse(callbackToken.lastCallbackSucceeded(), "nested refund unexpectedly succeeded");
        assertEq(
            callbackToken.lastCallbackRevertSelector(),
            ReentrancyGuard.ReentrancyGuardReentrantCall.selector,
            "callback did not reach the liquidity guard"
        );
        assertEq(ERC20(Currency.unwrap(currency0)).balanceOf(address(this)) - token0Before, refund0);
        assertEq(ERC20(Currency.unwrap(currency1)).balanceOf(address(this)) - token1Before, refund1);
        (uint256 remaining0, uint256 remaining1) = hook.claimableLiquidityRefund(address(this));
        assertEq(remaining0, 0);
        assertEq(remaining1, 0);
        _assertBacked();
    }

    function _assertBacked() private view {
        (uint256 reserve0, uint256 reserve1) = federation.reservesOf(address(hook));
        assertEq(federation.aggregateReserve0(), reserve0);
        assertEq(federation.aggregateReserve1(), reserve1);
        assertEq(manager.balanceOf(address(hook), currency0.toId()), reserve0 + hook.inactiveAssets0());
        assertEq(manager.balanceOf(address(hook), currency1.toId()), reserve1 + hook.inactiveAssets1());
    }

    function _swapParams(bool zeroForOne) private pure returns (SwapParams memory) {
        return SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(5 ether),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
    }

    function _add(uint256 amount0, uint256 amount1)
        private
        pure
        returns (BaseCustomAccounting.AddLiquidityParams memory)
    {
        return BaseCustomAccounting.AddLiquidityParams(
            amount0, amount1, 0, 0, type(uint256).max, -887220, 887220, bytes32(0)
        );
    }

    function _remove(uint256 shares) private pure returns (BaseCustomAccounting.RemoveLiquidityParams memory) {
        return BaseCustomAccounting.RemoveLiquidityParams(shares, 0, 0, type(uint256).max, -887220, 887220, bytes32(0));
    }
}
