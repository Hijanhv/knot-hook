// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {KnotFederation} from "../../src/core/KnotFederation.sol";
import {KnotHook} from "../../src/hooks/KnotHook.sol";

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

interface IPermit2Allowance {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

/// @notice Broadcasts all four single-hop swap branches through Uniswap's deployed Universal Router.
/// @dev The deployed Unichain Sepolia Universal Router uses the five-field single-hop tuple from
///      the pinned v4-periphery release. Newer IV4Router source adds `minHopPriceX36`, but encoding
///      that newer tuple for this deployed router makes its calldata decoder reject the command.
///      This release check must pass against the public deployment before its manifest may be active.
contract UniversalRouterLifecycle is Script {
    using SafeERC20 for IERC20;

    struct ExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        bytes hookData;
    }

    struct ExactOutputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountOut;
        uint128 amountInMaximum;
        bytes hookData;
    }

    address internal constant UNICHAIN_SEPOLIA_POOL_MANAGER = 0x00B036B58a818B1BC34d502D3fE730Db729e62AC;
    address internal constant UNICHAIN_SEPOLIA_UNIVERSAL_ROUTER = 0xf70536B3bcC1bD1a972dc186A2cf84cC6da6Be5D;
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    bytes1 internal constant V4_SWAP = 0x10;
    bytes1 internal constant SWAP_EXACT_IN_SINGLE = 0x06;
    bytes1 internal constant SWAP_EXACT_OUT_SINGLE = 0x08;
    bytes1 internal constant SETTLE_ALL = 0x0C;
    bytes1 internal constant TAKE_ALL = 0x0F;

    error WrongChain();
    error DeploymentMismatch();
    error MissingCode(address target);
    error BalanceMismatch(string reason);
    error AmountTooLarge();

    function run() external {
        if (block.chainid != 1301) revert WrongChain();
        if (UNICHAIN_SEPOLIA_POOL_MANAGER.code.length == 0) revert MissingCode(UNICHAIN_SEPOLIA_POOL_MANAGER);
        if (UNICHAIN_SEPOLIA_UNIVERSAL_ROUTER.code.length == 0) revert MissingCode(UNICHAIN_SEPOLIA_UNIVERSAL_ROUTER);
        if (PERMIT2.code.length == 0) revert MissingCode(PERMIT2);

        KnotFederation federation = KnotFederation(vm.envAddress("KNOT_FEDERATION"));
        KnotHook hook = KnotHook(payable(vm.envAddress("KNOT_MEMBER")));
        if (
            address(federation.poolManager()) != UNICHAIN_SEPOLIA_POOL_MANAGER
                || address(hook.poolManager()) != UNICHAIN_SEPOLIA_POOL_MANAGER
                || address(hook.federation()) != address(federation) || !federation.isMember(address(hook))
        ) revert DeploymentMismatch();

        address token0 = federation.currency0();
        address token1 = federation.currency1();
        if (token0 == address(0)) revert DeploymentMismatch();
        uint128 amount = _toUint128(vm.envOr("ROUTER_PROOF_AMOUNT", uint256(1e15)));
        address actor = msg.sender;
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        vm.startBroadcast();
        IERC20(token0).forceApprove(PERMIT2, type(uint256).max);
        IERC20(token1).forceApprove(PERMIT2, type(uint256).max);
        IPermit2Allowance(PERMIT2).approve(
            token0, UNICHAIN_SEPOLIA_UNIVERSAL_ROUTER, type(uint160).max, type(uint48).max
        );
        IPermit2Allowance(PERMIT2).approve(
            token1, UNICHAIN_SEPOLIA_UNIVERSAL_ROUTER, type(uint160).max, type(uint48).max
        );

        _exactInput(federation, key, actor, true, amount);
        _exactInput(federation, key, actor, false, amount);
        _exactOutput(federation, key, actor, true, amount);
        _exactOutput(federation, key, actor, false, amount);
        vm.stopBroadcast();

        console2.log("UNIVERSAL_ROUTER_LIFECYCLE_OK");
    }

    function _exactInput(KnotFederation federation, PoolKey memory key, address actor, bool zeroForOne, uint128 amount)
        private
    {
        address input = Currency.unwrap(zeroForOne ? key.currency0 : key.currency1);
        address output = Currency.unwrap(zeroForOne ? key.currency1 : key.currency0);
        (,, uint256 minimumOutput) = federation.preview(address(key.hooks), zeroForOne, true, amount);
        uint256 inputBefore = IERC20(input).balanceOf(actor);
        uint256 outputBefore = IERC20(output).balanceOf(actor);

        bytes[] memory actionParams = new bytes[](3);
        actionParams[0] = abi.encode(
            ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amount,
                amountOutMinimum: _toUint128(minimumOutput),
                hookData: bytes("")
            })
        );
        actionParams[1] = abi.encode(Currency.wrap(input), uint256(amount));
        actionParams[2] = abi.encode(Currency.wrap(output), minimumOutput);
        _execute(abi.encodePacked(SWAP_EXACT_IN_SINGLE, SETTLE_ALL, TAKE_ALL), actionParams);

        if (inputBefore - IERC20(input).balanceOf(actor) != amount) revert BalanceMismatch("exact-input spend");
        if (IERC20(output).balanceOf(actor) - outputBefore != minimumOutput) {
            revert BalanceMismatch("exact-input output");
        }
    }

    function _exactOutput(KnotFederation federation, PoolKey memory key, address actor, bool zeroForOne, uint128 amount)
        private
    {
        address input = Currency.unwrap(zeroForOne ? key.currency0 : key.currency1);
        address output = Currency.unwrap(zeroForOne ? key.currency1 : key.currency0);
        (,, uint256 maximumInput) = federation.preview(address(key.hooks), zeroForOne, false, amount);
        uint256 inputBefore = IERC20(input).balanceOf(actor);
        uint256 outputBefore = IERC20(output).balanceOf(actor);

        bytes[] memory actionParams = new bytes[](3);
        actionParams[0] = abi.encode(
            ExactOutputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountOut: amount,
                amountInMaximum: _toUint128(maximumInput),
                hookData: bytes("")
            })
        );
        actionParams[1] = abi.encode(Currency.wrap(input), maximumInput);
        actionParams[2] = abi.encode(Currency.wrap(output), uint256(amount));
        _execute(abi.encodePacked(SWAP_EXACT_OUT_SINGLE, SETTLE_ALL, TAKE_ALL), actionParams);

        if (inputBefore - IERC20(input).balanceOf(actor) != maximumInput) revert BalanceMismatch("exact-output spend");
        if (IERC20(output).balanceOf(actor) - outputBefore != amount) revert BalanceMismatch("exact-output delivery");
    }

    function _execute(bytes memory actions, bytes[] memory actionParams) private {
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, actionParams);
        IUniversalRouter(UNICHAIN_SEPOLIA_UNIVERSAL_ROUTER).execute(
            abi.encodePacked(V4_SWAP), inputs, block.timestamp + 10 minutes
        );
    }

    function _toUint128(uint256 amount) private pure returns (uint128) {
        if (amount > type(uint128).max) revert AmountTooLarge();
        return uint128(amount);
    }
}
