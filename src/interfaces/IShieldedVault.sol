// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IShieldedVault
 * @notice Vault de notas apantalladas: deposito, raiz de saldos y settlement.
 */
interface IShieldedVault {
    /**
     * @notice Deposita assets y registra un note commitment en el Merkle tree.
     * @param amount Monto a apantallar (wei o unidades del token).
     * @param noteCommitment Commitment de la nota (Poseidon off-chain).
     */
    function deposit(uint256 amount, bytes32 noteCommitment) external payable;

    /**
     * @notice Raiz actual del arbol de notas / saldos.
     * @return root Ultima raiz conocida.
     */
    function balanceRoot() external view returns (bytes32 root);

    /**
     * @notice True si la raiz esta en el historial (para proofs de match).
     * @param root Raiz a validar.
     */
    function isKnownBalanceRoot(bytes32 root) external view returns (bool);

    /**
     * @notice Nullifiers de nota gastados.
     * @param nullifierHash Hash del nullifier.
     * @return spent True si ya fue consumido.
     */
    function noteNullifiers(bytes32 nullifierHash) external view returns (bool spent);

    /**
     * @notice Settlement atómico entre notas (solo DarkPool).
     * @param buyNullifier Nullifier de la nota BUY consumida.
     * @param sellNullifier Nullifier de la nota SELL consumida.
     * @param newBuyNote Nueva nota BUY (0 = sin change note).
     * @param newSellNote Nueva nota SELL (0 = sin change note).
     */
    function applySettlement(
        bytes32 buyNullifier,
        bytes32 sellNullifier,
        bytes32 newBuyNote,
        bytes32 newSellNote
    ) external;
}
