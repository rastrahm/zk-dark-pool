// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DarkPool} from "../src/DarkPool.sol";
import {ShieldedVault} from "../src/ShieldedVault.sol";
import {DarkPoolSecurityBase} from "./helpers/DarkPoolSecurityBase.sol";
import {ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title MatchExecutionTest
 * @notice Fase 6: settlement atómico con proof BUY/SELL válida (Groth16).
 */
contract MatchExecutionTest is DarkPoolSecurityBase {
    event MatchExecuted(
        bytes32 indexed buyCommitment,
        bytes32 indexed sellCommitment,
        bytes32 buyNullifier,
        bytes32 sellNullifier,
        uint256 execAmount,
        uint256 execPrice
    );

    function test_zkMatch_settlesAtomically() public {
        (DarkPool pool, ShieldedVault vault, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        bytes32 buyC = bytes32(p.input[0]);
        bytes32 sellC = bytes32(p.input[1]);
        bytes32 buyN = bytes32(p.input[2]);
        bytes32 sellN = bytes32(p.input[3]);
        uint256 execAmount = p.input[5];
        uint256 execPrice = p.input[6];

        assertTrue(pool.isLive(buyC));
        assertTrue(pool.isLive(sellC));

        vm.expectEmit(true, true, false, true);
        emit MatchExecuted(buyC, sellC, buyN, sellN, execAmount, execPrice);

        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));

        assertFalse(pool.isLive(buyC));
        assertFalse(pool.isLive(sellC));
        assertTrue(pool.orderNullifiers(buyN));
        assertTrue(pool.orderNullifiers(sellN));
        assertTrue(vault.noteNullifiers(buyN));
        assertTrue(vault.noteNullifiers(sellN));
        assertEq(execAmount, 5);
        assertEq(execPrice, 105);
    }

    function test_zkMatch_withChangeNotes_updatesBalanceRoot() public {
        (DarkPool pool, ShieldedVault vault, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        bytes32 newBuy = keccak256("change-buy-note");
        bytes32 newSell = keccak256("change-sell-note");
        bytes32 rootBefore = vault.balanceRoot();

        pool.executeMatch(p.a, p.b, p.c, p.input, newBuy, newSell);

        assertTrue(vault.notes(newBuy));
        assertTrue(vault.notes(newSell));
        assertTrue(vault.balanceRoot() != rootBefore);
        assertTrue(vault.isKnownBalanceRoot(rootBefore));
    }
}
