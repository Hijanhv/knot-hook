// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {BaseCustomAccounting} from "ozhooks/base/BaseCustomAccounting.sol";
import {KnotFederation} from "../src/KnotFederation.sol";
import {KnotHook} from "../src/KnotHook.sol";

contract DemoToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

/// @title Deploy a WORKING Knot demo, not just the contracts.
///
/// @dev WHY TWO HOOKS AND NOT ONE
///      With a single member the aggregate reserves ARE the local reserves, so
///      `min(local, aggregate)` is always the local quote and the bound never binds. A
///      one-hook deployment would look identical to a plain constant-product pool and would
///      demonstrate nothing. This deploys two members with deliberately asymmetric liquidity
///      so the mechanism is visible the moment the frontend loads.
///
/// @dev THE MATURITY WINDOW
///      Deposits are inactive until they mature, so seeding runs in two phases. Deploy and
///      queue first, wait `LIQUIDITY_MATURITY_BLOCKS`, then run `Activate` to bring the
///      liquidity into the shared book. MATURITY is set to 1 here so the wait is one block.
contract DeployDemo is Script {
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint160 internal constant FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 internal constant MAX_DEADLINE = type(uint256).max;
    int24 internal constant MIN_TICK = -887220;
    int24 internal constant MAX_TICK = 887220;

    error HookAddressMismatch(address expected, address actual);

    function run() external {
        // No key is read here. `--account <name>` supplies the signer, so the raw key never
        // touches the filesystem or an environment variable.
        address me = msg.sender;
        IPoolManager manager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        uint256 maturity = vm.envOr("LIQUIDITY_MATURITY_BLOCKS", uint256(1));

        vm.startBroadcast();

        // ── tokens, sorted so currency0 < currency1 as v4 requires ──
        address tA = address(new DemoToken("Knot Demo USD", "kUSD"));
        address tB = address(new DemoToken("Knot Demo ETH", "kETH"));
        (address c0, address c1) = tA < tB ? (tA, tB) : (tB, tA);
        console.log("currency0      ", c0);
        console.log("currency1      ", c1);

        // ── federation ──
        KnotFederation federation = new KnotFederation(c0, c1, 997, 1000, 8, me);
        console.log("KnotFederation ", address(federation));

        // ── two members, each mined to a flag-valid address ──
        KnotHook deep = _deployHook(manager, federation, "Knot Deep", "KNOT-D", maturity);
        KnotHook shallow = _deployHook(manager, federation, "Knot Shallow", "KNOT-S", maturity);
        federation.register(address(deep));
        federation.register(address(shallow));
        console.log("KnotHook deep  ", address(deep));
        console.log("KnotHook shallow", address(shallow));

        // ── initialise both pools. Dynamic fee flag is required by _beforeInitialize ──
        manager.initialize(_key(c0, c1, address(deep)), SQRT_PRICE_1_1);
        manager.initialize(_key(c0, c1, address(shallow)), SQRT_PRICE_1_1);

        // ── queue asymmetric liquidity: deep is balanced, shallow is skewed 1:4 ──
        ERC20(c0).approve(address(deep), type(uint256).max);
        ERC20(c1).approve(address(deep), type(uint256).max);
        ERC20(c0).approve(address(shallow), type(uint256).max);
        ERC20(c1).approve(address(shallow), type(uint256).max);

        deep.addLiquidity(_add(1000 ether, 1000 ether));
        shallow.addLiquidity(_add(100 ether, 400 ether));

        vm.stopBroadcast();

        console.log("");
        console.log("Queued. Wait %s block(s), then run script/DeployDemo.s.sol:Activate", maturity);
        console.log("");
        console.log("--- frontend/.env.local ---");
        console.log("NEXT_PUBLIC_FEDERATION=%s", address(federation));
        console.log("NEXT_PUBLIC_DEEP_POOL=%s", address(deep));
        console.log("NEXT_PUBLIC_SHALLOW_POOL=%s", address(shallow));
    }

    function _deployHook(IPoolManager m, KnotFederation f, string memory n, string memory s, uint256 mat)
        internal
        returns (KnotHook hook)
    {
        bytes memory args = abi.encode(m, f, n, s, mat);
        (address expected, bytes32 salt) = HookMiner.find(CREATE2_DEPLOYER, FLAGS, type(KnotHook).creationCode, args);
        hook = new KnotHook{salt: salt}(m, f, n, s, mat);
        if (address(hook) != expected) revert HookAddressMismatch(expected, address(hook));
    }

    function _key(address c0, address c1, address hook) internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
    }

    function _add(uint256 a0, uint256 a1) internal pure returns (BaseCustomAccounting.AddLiquidityParams memory) {
        return BaseCustomAccounting.AddLiquidityParams(a0, a1, 0, 0, MAX_DEADLINE, MIN_TICK, MAX_TICK, bytes32(0));
    }
}

/// @dev Phase two. Run once the maturity window has passed.
contract Activate is Script {
    function run() external {
        KnotHook deep = KnotHook(payable(vm.envAddress("DEEP_POOL")));
        KnotHook shallow = KnotHook(payable(vm.envAddress("SHALLOW_POOL")));

        vm.startBroadcast();
        deep.activatePendingLiquidity();
        shallow.activatePendingLiquidity();
        vm.stopBroadcast();

        (uint256 d0, uint256 d1) = deep.reserves();
        (uint256 s0, uint256 s1) = shallow.reserves();
        console.log("deep reserves    %s / %s", d0, d1);
        console.log("shallow reserves %s / %s", s0, s1);
        console.log("Live. The bound binds on the shallow pool.");
    }
}
