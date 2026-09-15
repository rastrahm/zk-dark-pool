// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DarkPoolErrors} from "../src/errors/DarkPoolErrors.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {Groth16Verifier} from "../src/verifiers/Groth16Verifier.sol";
import {VerifierGate} from "../src/verifiers/VerifierGate.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";
import {ProofFixtureBase, ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title ProofVerificationTest
 * @notice Fase 4: pairing valida on-chain + proof invalida → InvalidZKProof.
 */
contract ProofVerificationTest is ProofFixtureBase {
    Groth16Verifier internal verifier;
    VerifierGate internal gate;

    function setUp() public {
        verifier = new Groth16Verifier();
        gate = new VerifierGate(verifier);
    }

    function test_validProof_verifyProof_returnsTrue() public view {
        ProofFixtureLib.ProofData memory p = _loadProof();
        assertTrue(verifier.verifyProof(p.a, p.b, p.c, p.input));
    }

    function test_validProof_requireValidProof_ok() public view {
        ProofFixtureLib.ProofData memory p = _loadProof();
        gate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_tamperedExecPrice_returnsFalse() public view {
        ProofFixtureLib.ProofData memory p = _loadProof();
        p.input[6] = p.input[6] + 1; // execPrice alterado
        assertFalse(verifier.verifyProof(p.a, p.b, p.c, p.input));
    }

    function test_tamperedProof_requireValid_revertsInvalidZKProof() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        p.a[0] = p.a[0] + 1;

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        gate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_tamperedBuyCommitment_revertsInvalidZKProof() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        p.input[0] = p.input[0] + 1;

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        gate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_tamperedBalanceRoot_revertsInvalidZKProof() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        p.input[4] = p.input[4] + 1;

        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        gate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_mockVerifier_gateRespectsFlag() public {
        MockVerifier mock = new MockVerifier();
        VerifierGate mockGate = new VerifierGate(mock);
        ProofFixtureLib.ProofData memory p = _loadProof();

        mockGate.requireValidProof(p.a, p.b, p.c, p.input);

        mock.setShouldPass(false);
        vm.expectRevert(DarkPoolErrors.InvalidZKProof.selector);
        mockGate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_gate_rejectsZeroVerifier() public {
        vm.expectRevert(DarkPoolErrors.ZeroAddress.selector);
        new VerifierGate(IVerifier(address(0)));
    }
}
