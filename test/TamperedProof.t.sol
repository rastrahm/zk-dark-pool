// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DarkPool} from "../src/DarkPool.sol";
import {DarkPoolErrors} from "../src/errors/DarkPoolErrors.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";
import {DarkPoolSecurityBase} from "./helpers/DarkPoolSecurityBase.sol";
import {ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title TamperedProofTest
 * @notice Fase 6: proof o commitments alterados → InvalidZKProof.
 */
contract TamperedProofTest is DarkPoolSecurityBase {
    function test_tamperedProofPointA_reverts() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        p.a[0] = p.a[0] + 1;

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));
    }

    function test_tamperedBuyCommitment_reverts() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        // Alterar commitment publico sin re-submit: deja de estar live O falla proof.
        // Aqui alteramos input pero mantenemos orden viva original — pairing falla.
        bytes32 originalBuy = bytes32(p.input[0]);
        p.input[0] = p.input[0] + 1;

        // Commitment alterado no esta live
        vm.expectRevert(DarkPoolErrors.InvalidOrderCommitment.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));

        // Restaurar commitment live pero con proof que no matchea (submit el falso)
        // Caso pairing: submit falso + inputs alterados respecto a proof
        pool.submitOrder(bytes32(p.input[0]));
        // sell sigue siendo el original del fixture
        assertTrue(pool.isLive(originalBuy));

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));
    }

    function test_tamperedSellNullifier_reverts() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        p.input[3] = p.input[3] + 1;

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));
    }

    function test_tamperedBalanceRoot_revertsUnknownOrInvalidProof() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        p.input[4] = uint256(keccak256("fake-root"));

        // Root desconocida se chequea antes del pairing
        vm.expectRevert(DarkPoolErrors.UnknownBalanceRoot.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));
    }

    function test_mockVerifierFalse_revertsInvalidZKProof() public {
        bytes32 buyC = keccak256("tb");
        bytes32 sellC = keccak256("ts");
        (DarkPool pool,, MockVerifier verifier, uint256[7] memory inputs) =
            _deployMockReady(buyC, sellC, keccak256("tn1"), keccak256("tn2"));

        verifier.setShouldPass(false);

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        pool.executeMatch(
            [uint256(0), 0], [[uint256(0), 0], [uint256(0), 0]], [uint256(0), 0], inputs, bytes32(0), bytes32(0)
        );

        assertTrue(pool.isLive(buyC));
        assertTrue(pool.isLive(sellC));
    }

    function test_ordersRemainLive_afterTamperedProof() public {
        (DarkPool pool,, ProofFixtureLib.ProofData memory p) = _deployZkReady();

        bytes32 buyC = bytes32(p.input[0]);
        bytes32 sellC = bytes32(p.input[1]);
        p.a[1] = p.a[1] + 1;

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        pool.executeMatch(p.a, p.b, p.c, p.input, bytes32(0), bytes32(0));

        assertTrue(pool.isLive(buyC));
        assertTrue(pool.isLive(sellC));
    }
}
