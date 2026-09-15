// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {OrderCommitment} from "../src/libraries/OrderCommitment.sol";
import {PoseidonT3} from "../src/libraries/PoseidonT3.sol";

/**
 * @title OrderCommitmentTest
 * @notice TDD Fase 1: hashOrder / Poseidon anidado y mock keccak.
 */
contract OrderCommitmentTest is Test {
    PoseidonHasher internal poseidon;
    MockHasher internal mock;

    function setUp() public {
        poseidon = new PoseidonHasher();
        mock = new MockHasher();
    }

    function test_PoseidonHashOrder_MatchesLibrary() public view {
        uint256 price = 100e18;
        uint256 amount = 5e18;
        uint256 side = OrderCommitment.SIDE_BUY;
        uint256 salt = 0xdeadbeef;

        bytes32 viaHasher = poseidon.hashOrder(price, amount, side, salt);
        bytes32 viaLib = OrderCommitment.commit(price, amount, side, salt);
        assertEq(viaHasher, viaLib);
    }

    function test_PoseidonHashOrder_Deterministic() public view {
        bytes32 a = poseidon.hashOrder(1, 2, 0, 99);
        bytes32 b = poseidon.hashOrder(1, 2, 0, 99);
        assertEq(a, b);
        assertTrue(a != bytes32(0));
    }

    function test_PoseidonHashOrder_SaltChangesCommitment() public view {
        bytes32 a = poseidon.hashOrder(10, 20, 1, 1);
        bytes32 b = poseidon.hashOrder(10, 20, 1, 2);
        assertTrue(a != b);
    }

    function test_PoseidonHashOrder_SideChangesCommitment() public view {
        bytes32 buy = poseidon.hashOrder(10, 20, OrderCommitment.SIDE_BUY, 7);
        bytes32 sell = poseidon.hashOrder(10, 20, OrderCommitment.SIDE_SELL, 7);
        assertTrue(buy != sell);
    }

    function test_PoseidonHashLeftRight_MatchesT3() public view {
        bytes32 left = bytes32(uint256(11));
        bytes32 right = bytes32(uint256(22));
        bytes32 got = poseidon.hashLeftRight(left, right);
        bytes32 expect = bytes32(PoseidonT3.hash([uint256(left), uint256(right)]));
        assertEq(got, expect);
    }

    function test_MockHashOrder_DistinctFromPoseidon() public view {
        uint256 price = 1;
        uint256 amount = 2;
        uint256 side = 0;
        uint256 salt = 3;
        bytes32 p = poseidon.hashOrder(price, amount, side, salt);
        bytes32 m = mock.hashOrder(price, amount, side, salt);
        assertTrue(p != m);
    }

    function testFuzz_MockHashOrder_Deterministic(uint256 price, uint256 amount, uint256 side, uint256 salt)
        public
        view
    {
        bytes32 a = mock.hashOrder(price, amount, side, salt);
        bytes32 b = mock.hashOrder(price, amount, side, salt);
        assertEq(a, b);
    }

    function testFuzz_PoseidonHashOrder_Deterministic(uint256 price, uint256 amount, uint256 side, uint256 salt)
        public
        view
    {
        // Poseidon opera en el campo BN254; reducir inputs al field.
        uint256 F = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        price %= F;
        amount %= F;
        side %= F;
        salt %= F;

        bytes32 a = poseidon.hashOrder(price, amount, side, salt);
        bytes32 b = poseidon.hashOrder(price, amount, side, salt);
        assertEq(a, b);
    }
}
