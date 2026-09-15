// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IVerifier
 * @notice Verificacion Groth16 (7 senales publicas del circuito MatchOrders).
 */
interface IVerifier {
    /**
     * @notice Verifica una prueba Groth16.
     * @param _pA Punto A de la proof.
     * @param _pB Punto B de la proof (G2, orden Ethereum / snarkjs calldata).
     * @param _pC Punto C de la proof.
     * @param _pubSignals [buyCommitment, sellCommitment, buyNullifier, sellNullifier, balanceRoot, execAmount, execPrice].
     * @return True si el pairing es valido.
     */
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[7] calldata _pubSignals
    ) external view returns (bool);
}
