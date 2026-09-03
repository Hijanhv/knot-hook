// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KnotFaucet} from "../../src/periphery/KnotFaucet.sol";

/**
 * @notice Deploys the demo faucet and funds it from the broadcaster's balance.
 *
 * Required environment:
 *   PRIVATE_KEY      the account holding the demo currencies
 *   CURRENCY0        kETH address from the release manifest
 *   CURRENCY1        kUSD address from the release manifest
 *
 * Optional:
 *   FAUCET_DRIP      per-claim amount, default 100e18
 *   FAUCET_COOLDOWN  seconds between claims per address, default 8 hours
 *   FAUCET_FUNDING   amount of each currency to move into the faucet, default 100_000e18
 */
contract DeployFaucet is Script {
    using SafeERC20 for IERC20;

    error InsufficientBalance(address currency, uint256 held, uint256 required);

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);

        IERC20 c0 = IERC20(vm.envAddress("CURRENCY0"));
        IERC20 c1 = IERC20(vm.envAddress("CURRENCY1"));
        uint256 drip = vm.envOr("FAUCET_DRIP", uint256(100 ether));
        uint256 cooldown = vm.envOr("FAUCET_COOLDOWN", uint256(8 hours));
        uint256 funding = vm.envOr("FAUCET_FUNDING", uint256(100_000 ether));

        uint256 held0 = c0.balanceOf(me);
        uint256 held1 = c1.balanceOf(me);
        if (held0 < funding) revert InsufficientBalance(address(c0), held0, funding);
        if (held1 < funding) revert InsufficientBalance(address(c1), held1, funding);

        vm.startBroadcast(pk);

        KnotFaucet faucet = new KnotFaucet(c0, c1, drip, cooldown, me);
        c0.safeTransfer(address(faucet), funding);
        c1.safeTransfer(address(faucet), funding);

        vm.stopBroadcast();

        // Read back through the deployed contract so the log reflects chain state, not intent.
        console2.log("KNOT_FAUCET", address(faucet));
        console2.log("drip", faucet.dripAmount());
        console2.log("cooldown", faucet.cooldown());
        console2.log("claimsRemaining", faucet.claimsRemaining());
        console2.log("DEPLOY_FAUCET_OK");
    }
}
