// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DarkPoolErrors} from "../src/errors/DarkPoolErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {OrderCommitment} from "../src/libraries/OrderCommitment.sol";
import {BlindOrderBookHarness} from "./helpers/BlindOrderBookHarness.sol";

/**
 * @title BlindOrderBookTest
 * @notice TDD Fase 1: submit commitment, rechazo zero/duplicado, consume/nullifier.
 */
contract BlindOrderBookTest is Test {
    BlindOrderBookHarness internal book;
    MockHasher internal mock;
    PoseidonHasher internal poseidon;

    event OrderSubmitted(bytes32 indexed commitment, address indexed submitter);

    function setUp() public {
        book = new BlindOrderBookHarness();
        mock = new MockHasher();
        poseidon = new PoseidonHasher();
    }

    function test_SubmitOrder_SuccessWithMockCommitment() public {
        bytes32 commitment = mock.hashOrder(100, 5, OrderCommitment.SIDE_BUY, 42);

        vm.expectEmit(true, true, false, true);
        emit OrderSubmitted(commitment, address(this));

        bytes32 got = book.submitOrder(commitment);
        assertEq(got, commitment);
        assertTrue(book.isLive(commitment));
        assertTrue(book.liveOrders(commitment));
    }

    function test_SubmitOrder_SuccessWithPoseidonCommitment() public {
        bytes32 commitment = poseidon.hashOrder(100e18, 1e18, OrderCommitment.SIDE_SELL, 7);
        book.submitOrder(commitment);
        assertTrue(book.isLive(commitment));
    }

    function test_SubmitOrder_RevertZeroCommitment() public {
        vm.expectRevert(DarkPoolErrors.InvalidOrderCommitment.selector);
        book.submitOrder(bytes32(0));
    }

    function test_SubmitOrder_RevertDuplicate() public {
        bytes32 commitment = mock.hashOrder(1, 2, 0, 3);
        book.submitOrder(commitment);

        vm.expectRevert(DarkPoolErrors.InvalidOrderCommitment.selector);
        book.submitOrder(commitment);
    }

    function test_ConsumeOrder_RemovesLiveAndSetsNullifier() public {
        bytes32 commitment = mock.hashOrder(9, 8, 1, 7);
        bytes32 nullifier = keccak256("nullifier-1");

        book.submitOrder(commitment);
        book.consumeOrder(commitment, nullifier);

        assertFalse(book.isLive(commitment));
        assertTrue(book.orderNullifiers(nullifier));
    }

    function test_ConsumeOrder_RevertNotLive() public {
        bytes32 commitment = mock.hashOrder(1, 1, 0, 1);
        vm.expectRevert(DarkPoolErrors.InvalidOrderCommitment.selector);
        book.consumeOrder(commitment, keccak256("n"));
    }

    function test_ConsumeOrder_RevertNullifierReplay() public {
        bytes32 c1 = mock.hashOrder(1, 2, 0, 10);
        bytes32 c2 = mock.hashOrder(1, 2, 0, 11);
        bytes32 nullifier = keccak256("shared-nullifier");

        book.submitOrder(c1);
        book.submitOrder(c2);
        book.consumeOrder(c1, nullifier);

        vm.expectRevert(DarkPoolErrors.OrderAlreadyFilled.selector);
        book.consumeOrder(c2, nullifier);
    }

    function test_ConsumeOrder_RevertZeroNullifier() public {
        bytes32 commitment = mock.hashOrder(3, 4, 1, 5);
        book.submitOrder(commitment);

        vm.expectRevert(DarkPoolErrors.OrderAlreadyFilled.selector);
        book.consumeOrder(commitment, bytes32(0));
    }

    function testFuzz_SubmitUniqueCommitments(uint256 saltA, uint256 saltB) public {
        vm.assume(saltA != saltB);

        bytes32 a = mock.hashOrder(50, 10, 0, saltA);
        bytes32 b = mock.hashOrder(50, 10, 0, saltB);
        assertTrue(a != b);

        book.submitOrder(a);
        book.submitOrder(b);
        assertTrue(book.isLive(a));
        assertTrue(book.isLive(b));
    }
}
