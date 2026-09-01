// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {BaseFixture} from "./BaseFixture.sol";

/// @title What the federation actually costs a swapper.
///
/// @dev A hook's cost is only meaningful against the thing it replaces, so this measures a Knot
///      swap and a swap on a hookless v4 pool of the same pair in the same test, and reports the
///      difference. Both are warmed first, because a first-touch swap pays for cold storage the
///      hook did not cause and the comparison stops being about the hook.
///
///      The overhead is one federation call: a preview against two reserve books, then four
///      storage writes to update local and aggregate. It is asserted rather than merely logged,
///      so a change that makes the hook materially more expensive fails the suite.
contract GasBenchmarkTest is BaseFixture {
    PoolKey internal plainKey;

    function setUp() public override {
        super.setUp();
        (plainKey,) = initPool(currency0, currency1, IHooks(address(0)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(
            plainKey,
            ModifyLiquidityParams({tickLower: -887220, tickUpper: 887220, liquidityDelta: 500e18, salt: bytes32(0)}),
            ""
        );
    }

    function test_gas_knotVersusPlain() public {
        // warm both paths first so we compare steady-state, not first-touch storage
        doSwap(deepKey, true, -1e18);
        _plainSwap(-1e18);

        uint256 g0 = gasleft();
        doSwap(deepKey, true, -5e18);
        uint256 knotGas = g0 - gasleft();

        g0 = gasleft();
        _plainSwap(-5e18);
        uint256 plainGas = g0 - gasleft();

        emit log_named_uint("knot swap (router->PM->hook)  ", knotGas);
        emit log_named_uint("plain v4 swap (router->PM)    ", plainGas);
        emit log_named_int("hook overhead                 ", int256(knotGas) - int256(plainGas));

        // Uniswap's own guidance budgets a beforeSwap callback at under 50,000 gas, with a hard
        // ceiling of 150,000. Hold the hook to the target, not the ceiling.
        assertLt(knotGas - plainGas, 50_000, "federation overhead exceeded the 50k beforeSwap budget");
    }

    function _plainSwap(int256 amt) internal {
        swapRouter.swap(
            plainKey,
            SwapParams({zeroForOne: true, amountSpecified: amt, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }
}
