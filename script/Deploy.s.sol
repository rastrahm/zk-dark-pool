// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {DarkPool} from "../src/DarkPool.sol";
import {ShieldedVault} from "../src/ShieldedVault.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {Groth16Verifier} from "../src/verifiers/Groth16Verifier.sol";
import {IHasher} from "../src/interfaces/IHasher.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {IShieldedVault} from "../src/interfaces/IShieldedVault.sol";

/**
 * @title Deploy
 * @notice Despliega PoseidonHasher + Groth16Verifier + ShieldedVault + DarkPool (lab).
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `MERKLE_TREE_LEVELS` — default 4 (debe coincidir con MatchOrders(N) y el VK)
 * - `POOL_TOKEN` — address(0) = ETH (default)
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        uint32 levels = uint32(vm.envOr("MERKLE_TREE_LEVELS", uint256(4)));
        address poolToken = vm.envOr("POOL_TOKEN", address(0));

        vm.startBroadcast(pk);

        PoseidonHasher hasher = new PoseidonHasher();
        Groth16Verifier verifier = new Groth16Verifier();
        ShieldedVault vault = new ShieldedVault(levels, IHasher(address(hasher)), poolToken);
        DarkPool pool = new DarkPool(IShieldedVault(address(vault)), IVerifier(address(verifier)));
        vault.setDarkPool(address(pool));

        console2.log("PoseidonHasher", address(hasher));
        console2.log("Groth16Verifier", address(verifier));
        console2.log("ShieldedVault", address(vault));
        console2.log("DarkPool", address(pool));
        console2.log("MERKLE_TREE_LEVELS", levels);
        console2.log("POOL_TOKEN", poolToken);

        vm.stopBroadcast();
    }
}
