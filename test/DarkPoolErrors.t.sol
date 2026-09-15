// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DarkPoolErrors} from "../src/errors/DarkPoolErrors.sol";

/**
 * @title DarkPoolErrorsTest
 * @notice Smoke de selectores de errores custom (Fase 1).
 */
contract DarkPoolErrorsTest is Test {
    function test_errorSelectors_distinct() public pure {
        bytes4[10] memory selectors = [
            DarkPoolErrors.OrderAlreadyFilled.selector,
            DarkPoolErrors.InvalidZKProof.selector,
            DarkPoolErrors.InvalidOrderCommitment.selector,
            DarkPoolErrors.UnknownBalanceRoot.selector,
            DarkPoolErrors.InsufficientShieldedBalance.selector,
            DarkPoolErrors.InvalidSettlement.selector,
            DarkPoolErrors.ZeroAddress.selector,
            DarkPoolErrors.Unauthorized.selector,
            DarkPoolErrors.EthTransferFailed.selector,
            DarkPoolErrors.TokenTransferFailed.selector
        ];

        for (uint256 i = 0; i < selectors.length; ++i) {
            assertTrue(selectors[i] != bytes4(0));
            for (uint256 j = i + 1; j < selectors.length; ++j) {
                assertTrue(selectors[i] != selectors[j]);
            }
        }
    }

    function test_OrderAlreadyFilledSelectorMatchesCursorrules() public pure {
        // Obligatorio del modulo: anti double-fill.
        assertEq(
            DarkPoolErrors.OrderAlreadyFilled.selector,
            bytes4(keccak256("OrderAlreadyFilled()"))
        );
    }
}
