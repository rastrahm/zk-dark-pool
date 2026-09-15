// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVerifier} from "../interfaces/IVerifier.sol";
import {DarkPoolErrors} from "../errors/DarkPoolErrors.sol";

/**
 * @title VerifierGate
 * @notice Wrapper que revierte con `InvalidZKProof` si la verificacion falla.
 * @dev Patron para DarkPool.executeMatch (Fase 5).
 */
contract VerifierGate {
    /// @notice Verifier Groth16 o mock.
    IVerifier public immutable VERIFIER;

    /**
     * @param verifier_ Implementacion Groth16 o mock.
     */
    constructor(IVerifier verifier_) {
        if (address(verifier_) == address(0)) revert DarkPoolErrors.ZeroAddress();
        VERIFIER = verifier_;
    }

    /**
     * @notice Exige proof valida o revierte.
     * @param a Punto A.
     * @param b Punto B.
     * @param c Punto C.
     * @param input Senales publicas (7).
     */
    function requireValidProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[7] calldata input
    ) external view {
        if (!VERIFIER.verifyProof(a, b, c, input)) {
            revert DarkPoolErrors.InvalidZKProof();
        }
    }
}
