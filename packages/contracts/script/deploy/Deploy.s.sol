// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {KnotFederation} from "../../src/core/KnotFederation.sol";
import {KnotHook} from "../../src/hooks/KnotHook.sol";

contract DeployKnot is Script {
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint160 internal constant FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );

    error HookAddressMismatch();

    function run() external returns (KnotFederation federation, KnotHook hook) {
        // Select the broadcaster with Foundry's encrypted `--account` option and pass the same
        // address through `--sender`. No raw private key is read by this script.
        address deployer = msg.sender;
        IPoolManager manager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        address currency0 = vm.envAddress("CURRENCY0");
        address currency1 = vm.envAddress("CURRENCY1");
        uint256 feeNumerator = vm.envOr("FEE_NUMERATOR", uint256(997));
        uint256 feeDenominator = vm.envOr("FEE_DENOMINATOR", uint256(1000));
        uint256 maxMembers = vm.envOr("MAX_MEMBERS", uint256(8));
        string memory shareName = vm.envOr("SHARE_NAME", string("Knot LP Share"));
        string memory shareSymbol = vm.envOr("SHARE_SYMBOL", string("KNOT-LP"));
        uint256 maturityBlocks = vm.envOr("LIQUIDITY_MATURITY_BLOCKS", uint256(5));

        vm.startBroadcast();
        federation = new KnotFederation(
            address(manager), currency0, currency1, feeNumerator, feeDenominator, maxMembers, deployer
        );
        bytes memory args = abi.encode(manager, federation, shareName, shareSymbol, maturityBlocks);
        (address expected, bytes32 salt) = HookMiner.find(CREATE2_DEPLOYER, FLAGS, type(KnotHook).creationCode, args);
        hook = new KnotHook{salt: salt}(manager, federation, shareName, shareSymbol, maturityBlocks);
        if (address(hook) != expected) revert HookAddressMismatch();
        federation.register(address(hook));
        vm.stopBroadcast();
    }
}
