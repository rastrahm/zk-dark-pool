// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title DarkPoolErrors
 * @notice Custom errors del ZK Dark Pool (modulo 21).
 */
library DarkPoolErrors {
    /// @notice El nullifier de orden ya fue usado en un match previo.
    error OrderAlreadyFilled();

    /// @notice La prueba Groth16 no verifico o las senales no coinciden.
    error InvalidZKProof();

    /// @notice Commitment de orden cero, duplicado o no registrado.
    error InvalidOrderCommitment();

    /// @notice La raiz de saldos apantallados no esta en el historial conocido.
    error UnknownBalanceRoot();

    /// @notice Saldo apantallado insuficiente para el settlement.
    error InsufficientShieldedBalance();

    /// @notice Montos o notas de settlement inconsistentes.
    error InvalidSettlement();

    /// @notice Se recibio address(0) donde no esta permitido.
    error ZeroAddress();

    /// @notice Caller no autorizado (admin / roles).
    error Unauthorized();

    /// @notice Fallo la transferencia ETH via `.call`.
    error EthTransferFailed();

    /// @notice Fallo la transferencia ERC-20.
    error TokenTransferFailed();
}
