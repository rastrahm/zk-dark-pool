// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DarkPool} from "../src/DarkPool.sol";
import {DarkPoolErrors} from "../src/errors/DarkPoolErrors.sol";
import {DarkPoolSecurityBase} from "./helpers/DarkPoolSecurityBase.sol";
import {ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title PriceMismatchTest
 * @notice Fase 6: execPrice / señales de precio alteradas → InvalidZKProof.
 * @dev Un proof válido con BUY < SELL no puede generarse off-chain; on-chain
 *      se detecta vía pairing cuando se manipulan publicInputs de precio/monto.
 */
contract PriceMismatchTest is DarkPoolSecurityBase {
    function test_tamperedExecPrice_revertsInvalidZKProof() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        // execPrice fuera del rango comprometido (105 → 106)
        p.input[6] = p.input[6] + 1;

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));
    }

    function test_tamperedExecAmount_revertsInvalidZKProof() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        p.input[5] = p.input[5] + 1; // execAmount

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));
    }

    function test_ordersRemainLive_afterPriceMismatchReject() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        bytes32 buyC = bytes32(p.input[0]);
        bytes32 sellC = bytes32(p.input[1]);

        p.input[6] = 999; // precio imposible vs proof

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));

        // CEI: no se consumieron ordenes si el proof fallo
        assertTrue(pool.isLive(buyC));
        assertTrue(pool.isLive(sellC));
        assertFalse(pool.orderNullifiers(bytes32(p.input[2])));
    }
}
