// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {BaseCustomAccounting} from "ozhooks/base/BaseCustomAccounting.sol";
import {KnotFederation} from "../../src/core/KnotFederation.sol";
import {KnotHook} from "../../src/hooks/KnotHook.sol";

contract LocalE2EToken is ERC20 {
    constructor(string memory name, string memory symbol, address holder) ERC20(name, symbol) {
        _mint(holder, 1_000_000 ether);
    }
}

/// @notice Reproducible real-transaction lifecycle for a fresh local Anvil chain.
/// @dev Broadcast only to a disposable local Anvil account; this path never needs a real key.
contract LocalE2E is Script {
    using CurrencyLibrary for Currency;

    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint160 internal constant FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    int24 internal constant MIN_TICK = -887220;
    int24 internal constant MAX_TICK = 887220;

    error AssertionFailed(string reason);
    error HookAddressMismatch(address expected, address actual);

    function run() external {
        address actor = msg.sender;
        vm.startBroadcast();

        PoolManager manager = new PoolManager(actor);
        PoolSwapTest router = new PoolSwapTest(manager);
        LocalE2EToken tokenA = new LocalE2EToken("Local Knot A", "lkA", actor);
        LocalE2EToken tokenB = new LocalE2EToken("Local Knot B", "lkB", actor);
        (address token0, address token1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));

        KnotFederation federation = new KnotFederation(address(manager), token0, token1, 997, 1000, 4, actor);
        KnotHook deep = _deployHook(manager, federation, "Local Knot Deep", "lkDEEP");
        KnotHook shallow = _deployHook(manager, federation, "Local Knot Shallow", "lkSHALLOW");
        federation.register(address(deep));
        federation.register(address(shallow));

        PoolKey memory deepKey = _key(token0, token1, address(deep));
        PoolKey memory shallowKey = _key(token0, token1, address(shallow));
        manager.initialize(deepKey, SQRT_PRICE_1_1);
        manager.initialize(shallowKey, SQRT_PRICE_1_1);

        ERC20(token0).approve(address(deep), type(uint256).max);
        ERC20(token1).approve(address(deep), type(uint256).max);
        ERC20(token0).approve(address(shallow), type(uint256).max);
        ERC20(token1).approve(address(shallow), type(uint256).max);
        ERC20(token0).approve(address(router), type(uint256).max);
        ERC20(token1).approve(address(router), type(uint256).max);

        deep.addLiquidity(_add(1_000 ether, 1_000 ether));
        shallow.addLiquidity(_add(100 ether, 400 ether));
        vm.roll(block.number + 1);
        deep.activatePendingLiquidity();
        shallow.activatePendingLiquidity();

        (uint256 localQuote, uint256 aggregateQuote, uint256 enforcedQuote) =
            federation.preview(address(shallow), true, true, 5 ether);
        _assert(localQuote > aggregateQuote, "fixture did not engage the aggregate boundary");
        _assert(enforcedQuote == aggregateQuote, "exact-input boundary selected the wrong quote");

        uint256 token1Before = ERC20(token1).balanceOf(actor);
        BalanceDelta exactInputDelta = _swap(router, shallowKey, true, -int256(5 ether));
        _assert(exactInputDelta.amount0() == -int128(int256(5 ether)), "exact-input delta changed specified input");
        _assert(ERC20(token1).balanceOf(actor) - token1Before == enforcedQuote, "exact-input output mismatch");

        (,, uint256 reverseExactInputQuote) = federation.preview(address(shallow), false, true, 1 ether);
        uint256 reverseToken0Before = ERC20(token0).balanceOf(actor);
        BalanceDelta reverseExactInputDelta = _swap(router, shallowKey, false, -int256(1 ether));
        _assert(
            reverseExactInputDelta.amount1() == -int128(int256(1 ether)),
            "reverse exact-input delta changed specified input"
        );
        _assert(
            ERC20(token0).balanceOf(actor) - reverseToken0Before == reverseExactInputQuote,
            "reverse exact-input output mismatch"
        );

        uint256 token0Before = ERC20(token0).balanceOf(actor);
        BalanceDelta exactOutputDelta = _swap(router, shallowKey, false, int256(1 ether));
        _assert(exactOutputDelta.amount0() == int128(int256(1 ether)), "exact-output delta changed requested output");
        _assert(ERC20(token0).balanceOf(actor) - token0Before == 1 ether, "exact-output delivery mismatch");

        uint256 exactOutputToken1Before = ERC20(token1).balanceOf(actor);
        BalanceDelta forwardExactOutputDelta = _swap(router, shallowKey, true, int256(1 ether));
        _assert(
            forwardExactOutputDelta.amount1() == int128(int256(1 ether)),
            "forward exact-output delta changed requested output"
        );
        _assert(
            ERC20(token1).balanceOf(actor) - exactOutputToken1Before == 1 ether,
            "forward exact-output delivery mismatch"
        );

        // Queue at the current ratio, move the ratio while the deposit is inactive, then prove
        // activation uses the new ratio and the excess remains fully claimable.
        deep.addLiquidity(_add(10 ether, 10 ether));
        _swap(router, deepKey, true, -int256(20 ether));
        vm.roll(block.number + 1);
        uint256 sharesBefore = deep.balanceOf(actor);
        deep.activatePendingLiquidity();
        uint256 mintedShares = deep.balanceOf(actor) - sharesBefore;
        (uint256 refund0, uint256 refund1) = deep.claimableLiquidityRefund(actor);
        _assert(mintedShares != 0, "mature deposit minted no shares");
        _assert(refund0 != 0 || refund1 != 0, "ratio movement created no refundable excess");
        deep.claimLiquidityRefund();
        vm.roll(deep.liquidityUnlockBlock(actor));
        deep.removeLiquidity(_remove(mintedShares));

        _assertBacked(manager, federation, deep, shallow, token0, token1);
        vm.stopBroadcast();

        console2.log("LOCAL_E2E_OK");
        console2.log("PoolManager", address(manager));
        console2.log("KnotFederation", address(federation));
        console2.log("Deep member", address(deep));
        console2.log("Shallow member", address(shallow));
        console2.log("Exact-input local / aggregate / enforced", localQuote, aggregateQuote, enforcedQuote);
    }

    function _deployHook(IPoolManager manager, KnotFederation federation, string memory name, string memory symbol)
        private
        returns (KnotHook hook)
    {
        bytes memory args = abi.encode(manager, federation, name, symbol, uint256(1));
        (address expected, bytes32 salt) = HookMiner.find(CREATE2_DEPLOYER, FLAGS, type(KnotHook).creationCode, args);
        hook = new KnotHook{salt: salt}(manager, federation, name, symbol, 1);
        if (address(hook) != expected) revert HookAddressMismatch(expected, address(hook));
    }

    function _key(address token0, address token1, address hook) private pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
    }

    function _add(uint256 amount0, uint256 amount1)
        private
        pure
        returns (BaseCustomAccounting.AddLiquidityParams memory)
    {
        return BaseCustomAccounting.AddLiquidityParams(
            amount0, amount1, 0, 0, type(uint256).max, MIN_TICK, MAX_TICK, bytes32(0)
        );
    }

    function _remove(uint256 shares) private pure returns (BaseCustomAccounting.RemoveLiquidityParams memory) {
        return
            BaseCustomAccounting.RemoveLiquidityParams(shares, 0, 0, type(uint256).max, MIN_TICK, MAX_TICK, bytes32(0));
    }

    function _swap(PoolSwapTest router, PoolKey memory key, bool zeroForOne, int256 amountSpecified)
        private
        returns (BalanceDelta)
    {
        return router.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            bytes("")
        );
    }

    function _assertBacked(
        PoolManager manager,
        KnotFederation federation,
        KnotHook deep,
        KnotHook shallow,
        address token0,
        address token1
    ) private view {
        (uint256 deep0, uint256 deep1) = federation.reservesOf(address(deep));
        (uint256 shallow0, uint256 shallow1) = federation.reservesOf(address(shallow));
        _assert(federation.aggregateReserve0() == deep0 + shallow0, "aggregate token0 drift");
        _assert(federation.aggregateReserve1() == deep1 + shallow1, "aggregate token1 drift");
        _assert(
            manager.balanceOf(address(deep), Currency.wrap(token0).toId()) == deep0 + deep.inactiveAssets0(),
            "deep token0 custody mismatch"
        );
        _assert(
            manager.balanceOf(address(deep), Currency.wrap(token1).toId()) == deep1 + deep.inactiveAssets1(),
            "deep token1 custody mismatch"
        );
        _assert(
            manager.balanceOf(address(shallow), Currency.wrap(token0).toId()) == shallow0 + shallow.inactiveAssets0(),
            "shallow token0 custody mismatch"
        );
        _assert(
            manager.balanceOf(address(shallow), Currency.wrap(token1).toId()) == shallow1 + shallow.inactiveAssets1(),
            "shallow token1 custody mismatch"
        );
    }

    function _assert(bool condition, string memory reason) private pure {
        if (!condition) revert AssertionFailed(reason);
    }
}
