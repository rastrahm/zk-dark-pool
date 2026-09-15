// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DarkPool} from "../src/DarkPool.sol";
import {DarkPoolErrors} from "../src/errors/DarkPoolErrors.sol";
import {DarkPoolSecurityBase} from "./helpers/DarkPoolSecurityBase.sol";
import {ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title OrderNullifierReplayTest
 * @notice Fase 6: segundo match con mismo nullifier → OrderAlreadyFilled.
 */
contract OrderNullifierReplayTest is DarkPoolSecurityBase {
    function test_nullifierReplay_sameProofTwice_reverts() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));

        // Misma proof de nuevo: commitments ya no viven
        vm.expectRevert(DarkPoolErrors.InvalidOrderCommitment.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));
    }

    function test_nullifierReplay_crossOrderReuse_reverts() public {
        bytes32 buyC = keccak256("rb");
        bytes32 sellC = keccak256("rs");
        bytes32 sharedN = keccak256("shared-nullifier");
        bytes32 otherN = keccak256("other-nullifier");

        (DarkPool pool,,, uint256[7] memory inputs) = _deployMockReady(buyC, sellC, sharedN, otherN);

        pool.executeMatch(
            [uint256(0), 0], [[uint256(0), 0], [uint256(0), 0]], [uint256(0), 0], inputs, bytes32(0), bytes32(0)
        );

        bytes32 buy2 = keccak256("rb2");
        bytes32 sell2 = keccak256("rs2");
        pool.submitOrder(buy2);
        pool.submitOrder(sell2);
        inputs[0] = uint256(buy2);
        inputs[1] = uint256(sell2);
        inputs[2] = uint256(sharedN); // replay buy nullifier
        inputs[3] = uint256(keccak256("fresh-sell-n"));
        inputs[4] = uint256(pool.vault().balanceRoot());

        vm.expectRevert(DarkPoolErrors.OrderAlreadyFilled.selector);
        pool.executeMatch(
            [uint256(0), 0], [[uint256(0), 0], [uint256(0), 0]], [uint256(0), 0], inputs, bytes32(0), bytes32(0)
        );
    }

    function test_nullifierReplay_sellSideReuse_reverts() public {
        bytes32 buyC = keccak256("sb");
        bytes32 sellC = keccak256("ss");
        bytes32 buyN = keccak256("bn");
        bytes32 sellN = keccak256("sn");

        (DarkPool pool,,, uint256[7] memory inputs) = _deployMockReady(buyC, sellC, buyN, sellN);
        pool.executeMatch(
            [uint256(0), 0], [[uint256(0), 0], [uint256(0), 0]], [uint256(0), 0], inputs, bytes32(0), bytes32(0)
        );

        bytes32 buy2 = keccak256("sb2");
        bytes32 sell2 = keccak256("ss2");
        pool.submitOrder(buy2);
        pool.submitOrder(sell2);
        inputs[0] = uint256(buy2);
        inputs[1] = uint256(sell2);
        inputs[2] = uint256(keccak256("fresh-buy-n"));
        inputs[3] = uint256(sellN); // replay sell nullifier
        inputs[4] = uint256(pool.vault().balanceRoot());

        vm.expectRevert(DarkPoolErrors.OrderAlreadyFilled.selector);
        pool.executeMatch(
            [uint256(0), 0], [[uint256(0), 0], [uint256(0), 0]], [uint256(0), 0], inputs, bytes32(0), bytes32(0)
        );
    }

    function testFuzz_nullifierMarkedBlocksReuse(bytes32 buyN, bytes32 sellN) public {
        vm.assume(buyN != bytes32(0) && sellN != bytes32(0) && buyN != sellN);

        bytes32 buyC = keccak256(abi.encodePacked("fuzz-buy", buyN));
        bytes32 sellC = keccak256(abi.encodePacked("fuzz-sell", sellN));

        (DarkPool pool,,, uint256[7] memory inputs) = _deployMockReady(buyC, sellC, buyN, sellN);

        pool.executeMatch(
            [uint256(0), 0], [[uint256(0), 0], [uint256(0), 0]], [uint256(0), 0], inputs, bytes32(0), bytes32(0)
        );
        assertTrue(pool.orderNullifiers(buyN));
        assertTrue(pool.orderNullifiers(sellN));

        bytes32 buy2 = keccak256(abi.encodePacked("fuzz-buy2", buyN));
        bytes32 sell2 = keccak256(abi.encodePacked("fuzz-sell2", sellN));
        pool.submitOrder(buy2);
        pool.submitOrder(sell2);
        inputs[0] = uint256(buy2);
        inputs[1] = uint256(sell2);
        inputs[4] = uint256(pool.vault().balanceRoot());

        vm.expectRevert(DarkPoolErrors.OrderAlreadyFilled.selector);
        pool.executeMatch(
            [uint256(0), 0], [[uint256(0), 0], [uint256(0), 0]], [uint256(0), 0], inputs, bytes32(0), bytes32(0)
        );
    }
}
