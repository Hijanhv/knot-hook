// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KnotFaucet
 * @notice Hands a fixed amount of the two demo currencies to any caller so the deployed
 *         federation can be exercised from a browser without pre-funding.
 *
 * The faucet is deliberately dumb. It holds a balance, it pays out a fixed amount, and it
 * refuses to pay the same address again until a cooldown has elapsed. It never mints, so its
 * exposure is capped by whatever it has been funded with, and a drained faucet fails loudly
 * rather than silently handing out zero.
 *
 * Testnet demo scaffolding. It is not part of the hook's trust boundary: the federation and
 * the hooks neither know nor care that this contract exists.
 */
contract KnotFaucet is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable currency0;
    IERC20 public immutable currency1;

    /// @notice Amount of each currency paid out per claim.
    uint256 public dripAmount;

    /// @notice Seconds a claimer must wait between claims.
    uint256 public cooldown;

    /// @notice Last block timestamp at which an address successfully claimed.
    mapping(address claimer => uint256 timestamp) public lastClaimedAt;

    event Dripped(address indexed to, uint256 amount0, uint256 amount1);
    event DripAmountSet(uint256 amount);
    event CooldownSet(uint256 seconds_);

    error ZeroAddress();
    error ZeroAmount();
    error CooldownActive(uint256 availableAt);
    error FaucetEmpty(address currency, uint256 available, uint256 required);

    constructor(IERC20 c0, IERC20 c1, uint256 amount, uint256 cooldownSeconds, address owner_) Ownable(owner_) {
        if (address(c0) == address(0) || address(c1) == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        currency0 = c0;
        currency1 = c1;
        dripAmount = amount;
        cooldown = cooldownSeconds;
    }

    /// @notice Sends `dripAmount` of both currencies to the caller.
    function drip() external {
        _drip(msg.sender);
    }

    /// @notice Sends `dripAmount` of both currencies to `to`, so a relayer can fund a fresh wallet.
    function dripTo(address to) external {
        if (to == address(0)) revert ZeroAddress();
        _drip(to);
    }

    /// @notice Seconds remaining before `claimer` may claim again. Zero means claimable now.
    function cooldownRemaining(address claimer) external view returns (uint256) {
        uint256 last = lastClaimedAt[claimer];
        if (last == 0) return 0;
        uint256 availableAt = last + cooldown;
        return block.timestamp >= availableAt ? 0 : availableAt - block.timestamp;
    }

    /// @notice How many further claims the current balance can cover.
    function claimsRemaining() external view returns (uint256) {
        uint256 a = currency0.balanceOf(address(this)) / dripAmount;
        uint256 b = currency1.balanceOf(address(this)) / dripAmount;
        return a < b ? a : b;
    }

    function setDripAmount(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        dripAmount = amount;
        emit DripAmountSet(amount);
    }

    function setCooldown(uint256 cooldownSeconds) external onlyOwner {
        cooldown = cooldownSeconds;
        emit CooldownSet(cooldownSeconds);
    }

    /// @notice Recovers any ERC-20 held by the faucet.
    function rescue(IERC20 token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        token.safeTransfer(to, amount);
    }

    function _drip(address to) private {
        // A zero timestamp means this address has never claimed. Treating it as a real claim time
        // would gate every first claim behind `cooldown` seconds of chain time, which is invisible
        // on a mature chain and a hard lock on a fresh one.
        uint256 last = lastClaimedAt[to];
        if (last != 0) {
            uint256 availableAt = last + cooldown;
            if (block.timestamp < availableAt) revert CooldownActive(availableAt);
        }

        uint256 amount = dripAmount;
        uint256 held0 = currency0.balanceOf(address(this));
        if (held0 < amount) revert FaucetEmpty(address(currency0), held0, amount);
        uint256 held1 = currency1.balanceOf(address(this));
        if (held1 < amount) revert FaucetEmpty(address(currency1), held1, amount);

        // Effects before interactions. The demo currencies are plain ERC-20s, but the ordering
        // is what keeps the cooldown honest if the faucet is ever pointed at a callback token.
        lastClaimedAt[to] = block.timestamp;

        currency0.safeTransfer(to, amount);
        currency1.safeTransfer(to, amount);

        emit Dripped(to, amount, amount);
    }
}
