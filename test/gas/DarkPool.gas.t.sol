// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DarkPool} from "../../src/DarkPool.sol";
import {ShieldedVault} from "../../src/ShieldedVault.sol";
import {MockHasher} from "../../src/mocks/MockHasher.sol";
import {MockVerifier} from "../../src/mocks/MockVerifier.sol";
import {PoseidonHasher} from "../../src/PoseidonHasher.sol";
import {Groth16Verifier} from "../../src/verifiers/Groth16Verifier.sol";
import {IHasher} from "../../src/interfaces/IHasher.sol";
import {IVerifier} from "../../src/interfaces/IVerifier.sol";
import {IShieldedVault} from "../../src/interfaces/IShieldedVault.sol";
import {ProofFixtureLib} from "../helpers/ProofFixture.sol";

/**
 * @title DarkPoolGasTest
 * @notice Snapshot: Poseidon vs Groth16 pairing vs match mock/e2e.
 */
contract DarkPoolGasTest is Test {
    uint32 internal constant LEVELS = 4;

    bytes32 internal constant BUY_NOTE =
        bytes32(uint256(19030838341674035369044154249169127381732824152483113263777707546006395809300));
    bytes32 internal constant SELL_NOTE =
        bytes32(uint256(10600126810883676610132822687363380738549146871096704933290204019673566972250));

    DarkPool internal mockPool;
    ShieldedVault internal mockVault;
    MockVerifier internal mockVerifier;
    PoseidonHasher internal poseidon;
    Groth16Verifier internal groth;

    address internal alice = makeAddr("alice");

    function setUp() public {
        MockHasher hasher = new MockHasher();
        mockVerifier = new MockVerifier();
        mockVault = new ShieldedVault(LEVELS, IHasher(address(hasher)), address(0));
        mockPool = new DarkPool(IShieldedVault(address(mockVault)), IVerifier(address(mockVerifier)));
        mockVault.setDarkPool(address(mockPool));

        poseidon = new PoseidonHasher();
        groth = new Groth16Verifier();

        vm.deal(alice, 100 ether);
        vm.prank(alice);
        mockVault.deposit{value: 1 ether}(1 ether, keccak256("gas-note-0"));
    }

    function testGas_submitOrder() public {
        mockPool.submitOrder(keccak256("gas-order"));
    }

    function testGas_deposit_mockHasher() public {
        vm.prank(alice);
        mockVault.deposit{value: 0.5 ether}(0.5 ether, keccak256("gas-dep"));
    }

    function testGas_executeMatch_mock() public {
        bytes32 buyC = keccak256("gas-buy");
        bytes32 sellC = keccak256("gas-sell");
        mockPool.submitOrder(buyC);
        mockPool.submitOrder(sellC);

        uint256[7] memory inputs;
        inputs[0] = uint256(buyC);
        inputs[1] = uint256(sellC);
        inputs[2] = uint256(keccak256("gas-bn"));
        inputs[3] = uint256(keccak256("gas-sn"));
        inputs[4] = uint256(mockVault.balanceRoot());
        inputs[5] = 5;
        inputs[6] = 105;

        mockPool.executeMatch(
            [uint256(0), 0], [[uint256(0), 0], [uint256(0), 0]], [uint256(0), 0], inputs, bytes32(0), bytes32(0)
        );
    }

    function testGas_poseidonHashOrder() public view {
        poseidon.hashOrder(110, 10, 0, 111111111);
    }

    function testGas_verifyProof_groth16() public view {
        ProofFixtureLib.ProofData memory p = _load();
        groth.verifyProof(p.a, p.b, p.c, p.input);
    }

    function testGas_e2e_groth16_executeMatch() public {
        ProofFixtureLib.ProofData memory p = _load();
        ShieldedVault vault = new ShieldedVault(LEVELS, IHasher(address(poseidon)), address(0));
        DarkPool pool = new DarkPool(IShieldedVault(address(vault)), IVerifier(address(groth)));
        vault.setDarkPool(address(pool));

        vm.startPrank(alice);
        vault.deposit{value: 1 ether}(1 ether, BUY_NOTE);
        vault.deposit{value: 1 ether}(1 ether, SELL_NOTE);
        vm.stopPrank();

        pool.submitOrder(bytes32(p.input[0]));
        pool.submitOrder(bytes32(p.input[1]));
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));
    }

    function _load() internal view returns (ProofFixtureLib.ProofData memory) {
        return ProofFixtureLib.parse(vm.readFile("test/fixtures/match/solidity_proof.json"));
    }
}
