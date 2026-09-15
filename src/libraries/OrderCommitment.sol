// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PoseidonT3} from "./PoseidonT3.sol";

/**
 * @title OrderCommitment
 * @notice Commitment ciego `hash(price, amount, side, salt)` via PoseidonT3 anidado.
 * @dev Arbol binario de 2 inputs (alineable a Circom):
 *      `Poseidon(Poseidon(price, amount), Poseidon(side, salt))`.
 */
library OrderCommitment {
    uint256 internal constant SIDE_BUY = 0;
    uint256 internal constant SIDE_SELL = 1;

    /**
     * @notice Calcula el commitment Poseidon de una orden.
     * @param price Precio limite.
     * @param amount Cantidad.
     * @param side Lado (0 BUY / 1 SELL).
     * @param salt Secreto anti-preimagen.
     * @return commitment Field embebido en bytes32.
     */
    function commit(uint256 price, uint256 amount, uint256 side, uint256 salt)
        internal
        pure
        returns (bytes32 commitment)
    {
        uint256 left = PoseidonT3.hash([price, amount]);
        uint256 right = PoseidonT3.hash([side, salt]);
        return bytes32(PoseidonT3.hash([left, right]));
    }
}
