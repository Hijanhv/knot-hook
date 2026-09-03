// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {KnotTestBase} from "../fixtures/KnotTestBase.sol";

/// @dev Executes both member swaps inside one canonical PoolManager unlock and settles only the
///      aggregate currency deltas at the end. This exercises the flash-accounting composition
///      path that two separate test-router calls cannot model.
contract AtomicMemberRouter is IUnlockCallback {
    using CurrencySettler for Currency;

    struct Route {
        address payer;
        PoolKey firstKey;
        PoolKey secondKey;
        bool firstZeroForOne;
        bool secondZeroForOne;
        int256 firstAmount;
        int256 secondAmount;
    }

    IPoolManager public immutable manager;

    constructor(IPoolManager poolManager) {
        manager = poolManager;
    }

    function execute(Route memory route) external returns (int256 net0, int256 net1) {
        return abi.decode(manager.unlock(abi.encode(route)), (int256, int256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager), "only manager");
        Route memory route = abi.decode(data, (Route));

        BalanceDelta first = manager.swap(route.firstKey, _params(route.firstZeroForOne, route.firstAmount), bytes(""));
        BalanceDelta second =
            manager.swap(route.secondKey, _params(route.secondZeroForOne, route.secondAmount), bytes(""));

        int256 net0 = int256(first.amount0()) + int256(second.amount0());
        int256 net1 = int256(first.amount1()) + int256(second.amount1());
        _settle(route.firstKey.currency0, route.payer, net0);
        _settle(route.firstKey.currency1, route.payer, net1);
        return abi.encode(net0, net1);
    }

    function _settle(Currency currency, address payer, int256 delta) private {
        if (delta < 0) currency.settle(manager, payer, uint256(-delta), false);
        else if (delta > 0) currency.take(manager, payer, uint256(delta), false);
    }

    function _params(bool zeroForOne, int256 amountSpecified) private pure returns (SwapParams memory) {
        return SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
    }
}

contract MultiPoolAtomicityTest is KnotTestBase {
    AtomicMemberRouter internal atomicRouter;

    function setUp() public {
        _deployKnotFixture(997, 1000, 2, 1, 1000 ether, 1500 ether, 1000 ether, 500 ether);
        atomicRouter = new AtomicMemberRouter(manager);
        ERC20(Currency.unwrap(currency0)).approve(address(atomicRouter), type(uint256).max);
        ERC20(Currency.unwrap(currency1)).approve(address(atomicRouter), type(uint256).max);
    }

    function test_twoMemberRouteSettlesOneNetDeltaAndKeepsEveryBookBacked() public {
        uint256 inputBefore = currency0.balanceOf(address(this));
        uint256 outputBefore = currency1.balanceOf(address(this));
        uint256 aggregate0Before = federation.aggregateReserve0();
        uint256 aggregate1Before = federation.aggregateReserve1();

        (int256 net0, int256 net1) = atomicRouter.execute(_route(-int256(2 ether), -int256(3 ether)));

        assertEq(net0, -int256(5 ether), "route did not aggregate both input legs");
        assertGt(net1, 0, "route produced no output");
        assertEq(inputBefore - currency0.balanceOf(address(this)), uint256(-net0));
        assertEq(currency1.balanceOf(address(this)) - outputBefore, uint256(net1));
        assertEq(federation.aggregateReserve0(), aggregate0Before + uint256(-net0));
        assertEq(federation.aggregateReserve1(), aggregate1Before - uint256(net1));
        _assertAggregateMatchesMembers();
    }

    function test_secondMemberFailureRollsBackFirstMemberAndPoolManagerClaims() public {
        (uint256 a0Before, uint256 a1Before) = federation.reservesOf(address(hookA));
        (uint256 b0Before, uint256 b1Before) = federation.reservesOf(address(hookB));
        uint256 aggregate0Before = federation.aggregateReserve0();
        uint256 aggregate1Before = federation.aggregateReserve1();
        uint256 claimA0Before = manager.balanceOf(address(hookA), currency0.toId());
        uint256 claimA1Before = manager.balanceOf(address(hookA), currency1.toId());

        AtomicMemberRouter.Route memory route = _route(-int256(2 ether), int256(b1Before));
        vm.expectRevert();
        atomicRouter.execute(route);

        (uint256 a0After, uint256 a1After) = federation.reservesOf(address(hookA));
        (uint256 b0After, uint256 b1After) = federation.reservesOf(address(hookB));
        assertEq(a0After, a0Before, "first member token0 did not roll back");
        assertEq(a1After, a1Before, "first member token1 did not roll back");
        assertEq(b0After, b0Before, "second member token0 moved on failure");
        assertEq(b1After, b1Before, "second member token1 moved on failure");
        assertEq(federation.aggregateReserve0(), aggregate0Before);
        assertEq(federation.aggregateReserve1(), aggregate1Before);
        assertEq(manager.balanceOf(address(hookA), currency0.toId()), claimA0Before);
        assertEq(manager.balanceOf(address(hookA), currency1.toId()), claimA1Before);
        _assertAggregateMatchesMembers();
    }

    function _route(int256 firstAmount, int256 secondAmount)
        private
        view
        returns (AtomicMemberRouter.Route memory route)
    {
        route = AtomicMemberRouter.Route({
            payer: address(this),
            firstKey: keyA,
            secondKey: keyB,
            firstZeroForOne: true,
            secondZeroForOne: true,
            firstAmount: firstAmount,
            secondAmount: secondAmount
        });
    }
}
