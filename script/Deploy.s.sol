// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/**
 * @title Deploy
 * @notice Stub de despliegue (Fase 0). Se completa en Fase 7 con hasher + verifier + vault + pool.
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `MERKLE_TREE_LEVELS` — default 4 (lab; debe coincidir con el circuito)
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        uint32 levels = uint32(vm.envOr("MERKLE_TREE_LEVELS", uint256(4)));

        vm.startBroadcast(pk);

        // Fase 7: PoseidonHasher + Groth16Verifier + ShieldedVault + DarkPool
        console2.log("Deploy stub - ZK Dark Pool module 21 (Fase 0)");
        console2.log("MERKLE_TREE_LEVELS", levels);

        vm.stopBroadcast();
    }
}
