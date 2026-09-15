// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DarkPool} from "../../src/DarkPool.sol";
import {ShieldedVault} from "../../src/ShieldedVault.sol";
import {PoseidonHasher} from "../../src/PoseidonHasher.sol";
import {Groth16Verifier} from "../../src/verifiers/Groth16Verifier.sol";
import {MockHasher} from "../../src/mocks/MockHasher.sol";
import {MockVerifier} from "../../src/mocks/MockVerifier.sol";
import {IHasher} from "../../src/interfaces/IHasher.sol";
import {IVerifier} from "../../src/interfaces/IVerifier.sol";
import {IShieldedVault} from "../../src/interfaces/IShieldedVault.sol";
import {ProofFixtureLib} from "./ProofFixture.sol";

/**
 * @title DarkPoolSecurityBase
 * @notice Helpers compartidos para la matriz de seguridad (Fase 6).
 */
abstract contract DarkPoolSecurityBase is Test {
    uint32 internal constant LEVELS = 4;

    /// @dev Notas del escenario lab (generate-proof.mjs).
    bytes32 internal constant BUY_NOTE =
        bytes32(uint256(19030838341674035369044154249169127381732824152483113263777707546006395809300));
    bytes32 internal constant SELL_NOTE =
        bytes32(uint256(10600126810883676610132822687363380738549146871096704933290204019673566972250));

    address internal alice = makeAddr("alice");

    function _loadProof() internal view returns (ProofFixtureLib.ProofData memory) {
        string memory json = vm.readFile("test/fixtures/match/solidity_proof.json");
        return ProofFixtureLib.parse(json);
    }

    /**
     * @notice Pool + vault Poseidon + Groth16 listos con notas y ordenes del fixture.
     */
    function _deployZkReady()
        internal
        returns (DarkPool pool, ShieldedVault vault, ProofFixtureLib.ProofData memory p)
    {
        p = _loadProof();
        PoseidonHasher poseidon = new PoseidonHasher();
        Groth16Verifier groth = new Groth16Verifier();
        vault = new ShieldedVault(LEVELS, IHasher(address(poseidon)), address(0));
        pool = new DarkPool(IShieldedVault(address(vault)), IVerifier(address(groth)));
        vault.setDarkPool(address(pool));

        vm.deal(alice, 100 ether);
        vm.startPrank(alice);
        vault.deposit{value: 1 ether}(1 ether, BUY_NOTE);
        vault.deposit{value: 1 ether}(1 ether, SELL_NOTE);
        vm.stopPrank();

        require(vault.balanceRoot() == bytes32(p.input[4]), "root mismatch");

        pool.submitOrder(bytes32(p.input[0]));
        pool.submitOrder(bytes32(p.input[1]));
    }

    /**
     * @notice Pool mock (verifier configurable) con dos ordenes vivas y un deposit.
     */
    function _deployMockReady(bytes32 buyC, bytes32 sellC, bytes32 buyN, bytes32 sellN)
        internal
        returns (DarkPool pool, ShieldedVault vault, MockVerifier verifier, uint256[7] memory inputs)
    {
        MockHasher hasher = new MockHasher();
        verifier = new MockVerifier();
        vault = new ShieldedVault(LEVELS, IHasher(address(hasher)), address(0));
        pool = new DarkPool(IShieldedVault(address(vault)), IVerifier(address(verifier)));
        vault.setDarkPool(address(pool));

        vm.deal(alice, 100 ether);
        vm.prank(alice);
        vault.deposit{value: 1 ether}(1 ether, keccak256("mock-note"));

        pool.submitOrder(buyC);
        pool.submitOrder(sellC);

        inputs[0] = uint256(buyC);
        inputs[1] = uint256(sellC);
        inputs[2] = uint256(buyN);
        inputs[3] = uint256(sellN);
        inputs[4] = uint256(vault.balanceRoot());
        inputs[5] = 5;
        inputs[6] = 105;
    }
}
