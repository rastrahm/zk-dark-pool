// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IHasher
 * @notice Hash Poseidon (o mock) para nodos Merkle y commitments de orden.
 */
interface IHasher {
    /**
     * @notice Hash de dos field elements (nodos Merkle / composicion).
     * @param left Hijo izquierdo.
     * @param right Hijo derecho.
     * @return Hash resultante (field embebido en bytes32).
     */
    function hashLeftRight(bytes32 left, bytes32 right) external pure returns (bytes32);

    /**
     * @notice Commitment ciego de orden: Poseidon(Poseidon(price, amount), Poseidon(side, salt)).
     * @param price Precio limite (field).
     * @param amount Cantidad (field).
     * @param side 0 = BUY, 1 = SELL (u otro encoding documentado).
     * @param salt Aleatorio privado anti-preimagen.
     * @return commitment Commitment publico on-chain.
     */
    function hashOrder(uint256 price, uint256 amount, uint256 side, uint256 salt)
        external
        pure
        returns (bytes32 commitment);
}
