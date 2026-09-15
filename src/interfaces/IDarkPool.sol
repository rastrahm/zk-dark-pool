// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDarkPool
 * @notice Dark pool ciego: submit de commitments y match ZK con settlement.
 */
interface IDarkPool {
    /**
     * @notice Registra un commitment de orden vivo.
     * @param commitment Commitment Poseidon de la orden.
     * @return same El commitment registrado.
     */
    function submitOrder(bytes32 commitment) external returns (bytes32 same);

    /**
     * @notice Ejecuta un match atómico con proof Groth16 + settlement en vault.
     * @param a Punto A de la proof.
     * @param b Punto B de la proof.
     * @param c Punto C de la proof.
     * @param publicInputs [buyCommitment, sellCommitment, buyNullifier, sellNullifier, balanceRoot, execAmount, execPrice].
     * @param newBuyNote Change note BUY (0 = ninguna).
     * @param newSellNote Change note SELL (0 = ninguna).
     */
    function executeMatch(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[7] calldata publicInputs,
        bytes32 newBuyNote,
        bytes32 newSellNote
    ) external;
}
