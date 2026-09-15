// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Placeholder
 * @notice Stub de Fase 0 para validar el scaffold Foundry del ZK Dark Pool.
 * @dev Se elimina en Fase 1 al introducir Hasher / BlindOrderBook.
 */
contract Placeholder {
    /**
     * @notice Eco de un valor para smoke test de compilacion y llamada.
     * @param value Valor arbitrario.
     * @return same El mismo valor.
     */
    function ping(uint256 value) external pure returns (uint256 same) {
        return value;
    }
}
