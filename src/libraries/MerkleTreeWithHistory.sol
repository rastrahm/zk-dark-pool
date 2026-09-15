// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IHasher} from "../interfaces/IHasher.sol";
import {DarkPoolErrors} from "../errors/DarkPoolErrors.sol";

/**
 * @title MerkleTreeWithHistory
 * @notice Arbol Merkle incremental con historial de raices (gas-opt).
 * @dev Arrays fijos (no mappings), indices packed, bit ops, hasher cacheado.
 */
abstract contract MerkleTreeWithHistory {
    /// @notice Tamano del ring buffer de raices historicas.
    uint32 public constant ROOT_HISTORY_SIZE = 30;

    /// @notice Profundidad del arbol (capacidad = 2^levels).
    uint32 public immutable levels;

    /// @notice Hasher Poseidon / mock inyectado.
    IHasher public immutable hasher;

    /// @notice Subarboles llenos por nivel (max 32).
    bytes32[32] public filledSubtrees;

    /// @notice Ceros precomputados por nivel.
    bytes32[32] public zeros;

    /// @notice Ring buffer de raices.
    bytes32[ROOT_HISTORY_SIZE] public roots;

    /// @dev Packed: [currentRootIndex : uint32][nextIndex : uint32] en un slot.
    uint256 private _packedIndices;

    /**
     * @notice Inicializa ceros, subarboles y raiz vacia.
     * @param levels_ Profundidad (1..31).
     * @param hasher_ Contrato IHasher.
     */
    constructor(uint32 levels_, IHasher hasher_) {
        if (levels_ == 0 || levels_ >= 32) revert DarkPoolErrors.InvalidNoteCommitment();
        if (address(hasher_) == address(0)) revert DarkPoolErrors.ZeroAddress();

        levels = levels_;
        hasher = hasher_;

        IHasher h = hasher_;
        bytes32 currentZero;
        for (uint32 i; i < levels_;) {
            zeros[i] = currentZero;
            filledSubtrees[i] = currentZero;
            currentZero = h.hashLeftRight(currentZero, currentZero);
            unchecked {
                ++i;
            }
        }

        roots[0] = currentZero;
    }

    /**
     * @notice Indice de la proxima hoja libre.
     */
    function nextIndex() public view returns (uint32) {
        return uint32(_packedIndices);
    }

    /**
     * @notice Indice actual en el ring de raices.
     */
    function currentRootIndex() public view returns (uint32) {
        return uint32(_packedIndices >> 32);
    }

    /**
     * @notice Ultima raiz conocida (current).
     */
    function getLastRoot() public view returns (bytes32) {
        return roots[uint32(_packedIndices >> 32)];
    }

    /**
     * @notice True si `root` esta en el historial circular (y no es cero).
     * @param root Raiz a validar.
     */
    function isKnownRoot(bytes32 root) public view virtual returns (bool) {
        if (root == bytes32(0)) return false;

        uint32 current = uint32(_packedIndices >> 32);
        uint32 i = current;
        unchecked {
            do {
                if (root == roots[i]) return true;
                if (i == 0) i = ROOT_HISTORY_SIZE;
                --i;
            } while (i != current);
        }
        return false;
    }

    /**
     * @notice Inserta una hoja y actualiza la raiz historica.
     * @param leaf Commitment (no cero).
     * @return index Indice de la hoja insertada.
     */
    function _insert(bytes32 leaf) internal returns (uint32 index) {
        if (leaf == bytes32(0)) revert DarkPoolErrors.InvalidNoteCommitment();

        uint256 packed = _packedIndices;
        uint32 _nextIndex = uint32(packed);
        uint32 _levels = levels;
        uint32 maxIndex;
        unchecked {
            maxIndex = uint32(1) << _levels;
        }
        if (_nextIndex >= maxIndex) revert DarkPoolErrors.TreeFull();

        uint32 currentIndex = _nextIndex;
        bytes32 currentLevelHash = leaf;
        IHasher h = hasher;

        for (uint32 i; i < _levels;) {
            if ((currentIndex & 1) == 0) {
                filledSubtrees[i] = currentLevelHash;
                currentLevelHash = h.hashLeftRight(currentLevelHash, zeros[i]);
            } else {
                currentLevelHash = h.hashLeftRight(filledSubtrees[i], currentLevelHash);
            }
            unchecked {
                currentIndex >>= 1;
                ++i;
            }
        }

        uint32 oldRootIndex = uint32(packed >> 32);
        uint32 newRootIndex;
        unchecked {
            newRootIndex = (oldRootIndex + 1) % ROOT_HISTORY_SIZE;
            _packedIndices = (uint256(newRootIndex) << 32) | uint256(_nextIndex + 1);
        }
        roots[newRootIndex] = currentLevelHash;

        return _nextIndex;
    }
}
