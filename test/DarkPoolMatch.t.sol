// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DarkPool} from "../src/DarkPool.sol";
import {ShieldedVault} from "../src/ShieldedVault.sol";
import {DarkPoolErrors} from "../src/errors/DarkPoolErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {Groth16Verifier} from "../src/verifiers/Groth16Verifier.sol";
import {IHasher} from "../src/interfaces/IHasher.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {IShieldedVault} from "../src/interfaces/IShieldedVault.sol";
import {ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title DarkPoolMatchTest
 * @notice Fase 5: executeMatch mock + e2e Groth16 con fixture MatchOrders.
 */
contract DarkPoolMatchTest is Test {
    uint32 internal constant LEVELS = 4;

    MockHasher internal mockHasher;
    MockVerifier internal mockVerifier;
    ShieldedVault internal mockVault;
    DarkPool internal mockPool;

    address internal alice = makeAddr("alice");

    event MatchExecuted(
        bytes32 indexed buyCommitment,
        bytes32 indexed sellCommitment,
        bytes32 buyNullifier,
        bytes32 sellNullifier,
        uint256 execAmount,
        uint256 execPrice
    );

    function setUp() public {
        mockHasher = new MockHasher();
        mockVerifier = new MockVerifier();
        mockVault = new ShieldedVault(LEVELS, IHasher(address(mockHasher)), address(0));
        mockPool = new DarkPool(IShieldedVault(address(mockVault)), IVerifier(address(mockVerifier)));
        mockVault.setDarkPool(address(mockPool));

        vm.deal(alice, 100 ether);
    }

    function test_constructor_rejectsZero() public {
        vm.expectRevert(DarkPoolErrors.ZeroAddress.selector);
        new DarkPool(IShieldedVault(address(0)), IVerifier(address(mockVerifier)));

        vm.expectRevert(DarkPoolErrors.ZeroAddress.selector);
        new DarkPool(IShieldedVault(address(mockVault)), IVerifier(address(0)));
    }

    function test_submitOrder_thenMatch_mockSuccess() public {
        bytes32 buyC = keccak256("buy-order");
        bytes32 sellC = keccak256("sell-order");
        bytes32 buyN = keccak256("buy-null");
        bytes32 sellN = keccak256("sell-null");

        vm.prank(alice);
        mockVault.deposit{value: 1 ether}(1 ether, keccak256("note-a"));
        vm.prank(alice);
        mockVault.deposit{value: 1 ether}(1 ether, keccak256("note-b"));

        mockPool.submitOrder(buyC);
        mockPool.submitOrder(sellC);

        uint256[7] memory inputs;
        inputs[0] = uint256(buyC);
        inputs[1] = uint256(sellC);
        inputs[2] = uint256(buyN);
        inputs[3] = uint256(sellN);
        inputs[4] = uint256(mockVault.balanceRoot());
        inputs[5] = 5;
        inputs[6] = 105;

        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;

        vm.expectEmit(true, true, false, true);
        emit MatchExecuted(buyC, sellC, buyN, sellN, 5, 105);

        mockPool.executeMatch(a, b, c, inputs, bytes32(0), bytes32(0));

        assertFalse(mockPool.isLive(buyC));
        assertFalse(mockPool.isLive(sellC));
        assertTrue(mockPool.orderNullifiers(buyN));
        assertTrue(mockPool.orderNullifiers(sellN));
        assertTrue(mockVault.noteNullifiers(buyN));
        assertTrue(mockVault.noteNullifiers(sellN));
    }

    function test_executeMatch_replayNullifier_reverts() public {
        bytes32 buyC = keccak256("b1");
        bytes32 sellC = keccak256("s1");
        bytes32 buyN = keccak256("bn1");
        bytes32 sellN = keccak256("sn1");

        vm.prank(alice);
        mockVault.deposit{value: 1 ether}(1 ether, keccak256("n1"));

        mockPool.submitOrder(buyC);
        mockPool.submitOrder(sellC);

        uint256[7] memory inputs;
        inputs[0] = uint256(buyC);
        inputs[1] = uint256(sellC);
        inputs[2] = uint256(buyN);
        inputs[3] = uint256(sellN);
        inputs[4] = uint256(mockVault.balanceRoot());
        inputs[5] = 1;
        inputs[6] = 1;

        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;

        mockPool.executeMatch(a, b, c, inputs, bytes32(0), bytes32(0));

        // Nuevas ordenes, mismos nullifiers
        bytes32 buyC2 = keccak256("b2");
        bytes32 sellC2 = keccak256("s2");
        mockPool.submitOrder(buyC2);
        mockPool.submitOrder(sellC2);
        inputs[0] = uint256(buyC2);
        inputs[1] = uint256(sellC2);
        inputs[4] = uint256(mockVault.balanceRoot());

        vm.expectRevert(DarkPoolErrors.OrderAlreadyFilled.selector);
        mockPool.executeMatch(a, b, c, inputs, bytes32(0), bytes32(0));
    }

    function test_executeMatch_unknownRoot_reverts() public {
        bytes32 buyC = keccak256("bx");
        bytes32 sellC = keccak256("sx");
        mockPool.submitOrder(buyC);
        mockPool.submitOrder(sellC);

        uint256[7] memory inputs;
        inputs[0] = uint256(buyC);
        inputs[1] = uint256(sellC);
        inputs[2] = uint256(keccak256("n1"));
        inputs[3] = uint256(keccak256("n2"));
        inputs[4] = uint256(keccak256("unknown-root"));
        inputs[5] = 1;
        inputs[6] = 1;

        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;

        vm.expectRevert(DarkPoolErrors.UnknownBalanceRoot.selector);
        mockPool.executeMatch(a, b, c, inputs, bytes32(0), bytes32(0));
    }

    function test_executeMatch_notLive_reverts() public {
        uint256[7] memory inputs;
        inputs[0] = uint256(keccak256("missing-buy"));
        inputs[1] = uint256(keccak256("missing-sell"));
        inputs[2] = 1;
        inputs[3] = 2;
        inputs[4] = uint256(mockVault.balanceRoot());

        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;

        vm.expectRevert(DarkPoolErrors.InvalidOrderCommitment.selector);
        mockPool.executeMatch(a, b, c, inputs, bytes32(0), bytes32(0));
    }

    function test_executeMatch_invalidProof_reverts() public {
        mockVerifier.setShouldPass(false);

        bytes32 buyC = keccak256("bp");
        bytes32 sellC = keccak256("sp");
        mockPool.submitOrder(buyC);
        mockPool.submitOrder(sellC);

        vm.prank(alice);
        mockVault.deposit{value: 1 ether}(1 ether, keccak256("np"));

        uint256[7] memory inputs;
        inputs[0] = uint256(buyC);
        inputs[1] = uint256(sellC);
        inputs[2] = uint256(keccak256("np1"));
        inputs[3] = uint256(keccak256("np2"));
        inputs[4] = uint256(mockVault.balanceRoot());
        inputs[5] = 1;
        inputs[6] = 1;

        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        mockPool.executeMatch(a, b, c, inputs, bytes32(0), bytes32(0));
    }

    function test_e2e_groth16_fixture_match() public {
        PoseidonHasher poseidon = new PoseidonHasher();
        Groth16Verifier groth = new Groth16Verifier();
        ShieldedVault vault = new ShieldedVault(LEVELS, IHasher(address(poseidon)), address(0));
        DarkPool pool = new DarkPool(IShieldedVault(address(vault)), IVerifier(address(groth)));
        vault.setDarkPool(address(pool));

        ProofFixtureLib.ProofData memory p = _loadSolidityProof();

        // Notas del escenario lab (generate-proof.mjs) — orden leaf 0, 1.
        bytes32 buyNote = bytes32(
            uint256(19030838341674035369044154249169127381732824152483113263777707546006395809300)
        );
        bytes32 sellNote = bytes32(
            uint256(10600126810883676610132822687363380738549146871096704933290204019673566972250)
        );

        vm.startPrank(alice);
        vault.deposit{value: 1 ether}(1 ether, buyNote);
        vault.deposit{value: 1 ether}(1 ether, sellNote);
        vm.stopPrank();

        bytes32 expectedRoot = bytes32(p.input[4]);
        assertEq(vault.balanceRoot(), expectedRoot, "balanceRoot must match fixture");

        bytes32 buyC = bytes32(p.input[0]);
        bytes32 sellC = bytes32(p.input[1]);
        pool.submitOrder(buyC);
        pool.submitOrder(sellC);

        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));

        assertFalse(pool.isLive(buyC));
        assertFalse(pool.isLive(sellC));
        assertTrue(pool.orderNullifiers(bytes32(p.input[2])));
        assertTrue(pool.orderNullifiers(bytes32(p.input[3])));
    }

    function _loadSolidityProof() internal view returns (ProofFixtureLib.ProofData memory) {
        string memory json = vm.readFile("test/fixtures/match/solidity_proof.json");
        return ProofFixtureLib.parse(json);
    }
}
