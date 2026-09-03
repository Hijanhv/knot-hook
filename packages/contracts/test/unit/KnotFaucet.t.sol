// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {KnotFaucet} from "../../src/periphery/KnotFaucet.sol";

contract FaucetToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract KnotFaucetTest is Test {
    FaucetToken internal token0;
    FaucetToken internal token1;
    KnotFaucet internal faucet;

    address internal owner = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal constant DRIP = 100 ether;
    uint256 internal constant COOLDOWN = 8 hours;

    function setUp() public {
        token0 = new FaucetToken("Knot Demo ETH", "kETH");
        token1 = new FaucetToken("Knot Demo USD", "kUSD");
        faucet = new KnotFaucet(IERC20(address(token0)), IERC20(address(token1)), DRIP, COOLDOWN, owner);
        token0.transfer(address(faucet), 10_000 ether);
        token1.transfer(address(faucet), 10_000 ether);
    }

    function test_constructor_recordsConfiguration() public view {
        assertEq(address(faucet.currency0()), address(token0));
        assertEq(address(faucet.currency1()), address(token1));
        assertEq(faucet.dripAmount(), DRIP);
        assertEq(faucet.cooldown(), COOLDOWN);
        assertEq(faucet.owner(), owner);
    }

    function test_constructor_rejectsZeroCurrency() public {
        vm.expectRevert(KnotFaucet.ZeroAddress.selector);
        new KnotFaucet(IERC20(address(0)), IERC20(address(token1)), DRIP, COOLDOWN, owner);
        vm.expectRevert(KnotFaucet.ZeroAddress.selector);
        new KnotFaucet(IERC20(address(token0)), IERC20(address(0)), DRIP, COOLDOWN, owner);
    }

    function test_constructor_rejectsZeroAmount() public {
        vm.expectRevert(KnotFaucet.ZeroAmount.selector);
        new KnotFaucet(IERC20(address(token0)), IERC20(address(token1)), 0, COOLDOWN, owner);
    }

    function test_drip_paysBothCurrencies() public {
        vm.prank(alice);
        faucet.drip();
        assertEq(token0.balanceOf(alice), DRIP);
        assertEq(token1.balanceOf(alice), DRIP);
    }

    function test_drip_emitsEvent() public {
        vm.expectEmit(true, false, false, true, address(faucet));
        emit KnotFaucet.Dripped(alice, DRIP, DRIP);
        vm.prank(alice);
        faucet.drip();
    }

    function test_drip_enforcesCooldown() public {
        vm.prank(alice);
        faucet.drip();
        uint256 availableAt = block.timestamp + COOLDOWN;

        vm.expectRevert(abi.encodeWithSelector(KnotFaucet.CooldownActive.selector, availableAt));
        vm.prank(alice);
        faucet.drip();
    }

    function test_drip_allowedAgainAfterCooldown() public {
        vm.prank(alice);
        faucet.drip();
        vm.warp(block.timestamp + COOLDOWN);
        vm.prank(alice);
        faucet.drip();
        assertEq(token0.balanceOf(alice), DRIP * 2);
    }

    function test_drip_cooldownIsPerAddress() public {
        vm.prank(alice);
        faucet.drip();
        vm.prank(bob);
        faucet.drip();
        assertEq(token0.balanceOf(bob), DRIP);
    }

    function test_dripTo_fundsAnotherAddress() public {
        vm.prank(alice);
        faucet.dripTo(bob);
        assertEq(token0.balanceOf(bob), DRIP);
        assertEq(token0.balanceOf(alice), 0);
    }

    function test_dripTo_rejectsZeroAddress() public {
        vm.expectRevert(KnotFaucet.ZeroAddress.selector);
        faucet.dripTo(address(0));
    }

    function test_drip_revertsWhenEmpty() public {
        faucet.rescue(IERC20(address(token0)), owner, token0.balanceOf(address(faucet)));
        vm.expectRevert(abi.encodeWithSelector(KnotFaucet.FaucetEmpty.selector, address(token0), 0, DRIP));
        vm.prank(alice);
        faucet.drip();
    }

    function test_drip_revertsWhenSecondCurrencyEmpty() public {
        faucet.rescue(IERC20(address(token1)), owner, token1.balanceOf(address(faucet)));
        vm.expectRevert(abi.encodeWithSelector(KnotFaucet.FaucetEmpty.selector, address(token1), 0, DRIP));
        vm.prank(alice);
        faucet.drip();
    }

    function test_drip_doesNotConsumeCooldownWhenItReverts() public {
        faucet.rescue(IERC20(address(token0)), owner, token0.balanceOf(address(faucet)));
        vm.prank(alice);
        vm.expectRevert();
        faucet.drip();

        token0.transfer(address(faucet), 1_000 ether);
        vm.prank(alice);
        faucet.drip();
        assertEq(token0.balanceOf(alice), DRIP);
    }

    function test_cooldownRemaining_reportsCorrectly() public {
        assertEq(faucet.cooldownRemaining(alice), 0);
        vm.prank(alice);
        faucet.drip();
        assertEq(faucet.cooldownRemaining(alice), COOLDOWN);
        vm.warp(block.timestamp + COOLDOWN / 2);
        assertEq(faucet.cooldownRemaining(alice), COOLDOWN / 2);
        vm.warp(block.timestamp + COOLDOWN);
        assertEq(faucet.cooldownRemaining(alice), 0);
    }

    function test_claimsRemaining_usesScarcerCurrency() public {
        assertEq(faucet.claimsRemaining(), 100);
        faucet.rescue(IERC20(address(token1)), owner, 9_500 ether);
        assertEq(faucet.claimsRemaining(), 5);
    }

    function test_setDripAmount_onlyOwner() public {
        faucet.setDripAmount(1 ether);
        assertEq(faucet.dripAmount(), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        faucet.setDripAmount(1 ether);
    }

    function test_setDripAmount_rejectsZero() public {
        vm.expectRevert(KnotFaucet.ZeroAmount.selector);
        faucet.setDripAmount(0);
    }

    function test_setCooldown_onlyOwner() public {
        faucet.setCooldown(1 hours);
        assertEq(faucet.cooldown(), 1 hours);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        faucet.setCooldown(1 hours);
    }

    function test_rescue_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        faucet.rescue(IERC20(address(token0)), alice, 1 ether);
    }

    function test_rescue_rejectsZeroAddress() public {
        vm.expectRevert(KnotFaucet.ZeroAddress.selector);
        faucet.rescue(IERC20(address(token0)), address(0), 1 ether);
    }

    /// @dev The faucet must never pay out more than it holds, however the caller interleaves claims.
    function testFuzz_drip_neverExceedsBalance(uint8 claimers, uint96 amount) public {
        amount = uint96(bound(amount, 1 ether, 500 ether));
        faucet.setDripAmount(amount);
        uint256 funded = token0.balanceOf(address(faucet));

        uint256 paid;
        for (uint256 i = 0; i < claimers; i++) {
            address who = address(uint160(0x1000 + i));
            if (paid + amount > funded) {
                vm.expectRevert();
                vm.prank(who);
                faucet.drip();
            } else {
                vm.prank(who);
                faucet.drip();
                paid += amount;
                assertEq(token0.balanceOf(who), amount);
            }
        }
        assertEq(token0.balanceOf(address(faucet)), funded - paid);
    }
}
