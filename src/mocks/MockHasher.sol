// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IHasher} from "../interfaces/IHasher.sol";

/**
 * @title MockHasher
 * @notice Hasher determinista con keccak256 para tests rapidos (no compatible con Circom).
 * @dev Solo lab / unit tests. Produccion debe usar `PoseidonHasher`.
 */
contract MockHasher is IHasher {
    /**
     * @inheritdoc IHasher
     */
    function hashLeftRight(bytes32 left, bytes32 right) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(left, right));
    }

    /**
     * @inheritdoc IHasher
     */
    function hashOrder(uint256 price, uint256 amount, uint256 side, uint256 salt)
        external
        pure
        returns (bytes32)
    {
        bytes32 left = keccak256(abi.encodePacked(price, amount));
        bytes32 right = keccak256(abi.encodePacked(side, salt));
        return keccak256(abi.encodePacked(left, right));
    }
}
