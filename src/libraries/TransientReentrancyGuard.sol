// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title TransientReentrancyGuard
 * @notice Reentrancy guard con EIP-1153 `tstore`/`tload` (Cancun) — sin SSTORE.
 * @dev Ahorra gas vs guard basado en storage en cada llamada protegida.
 */
abstract contract TransientReentrancyGuard {
    /// @dev Slot arbitrario dedicado (no colisiona con storage layout).
    uint256 private constant _LOCK_SLOT = 0x9b77e11c5c9f4a5e6d0c8f3a2b1e0d9c8b7a6958473625140f1e2d3c4b5a6970;

    error ReentrancyGuardReentrantCall();

    modifier nonReentrant() {
        assembly {
            if tload(_LOCK_SLOT) {
                mstore(0x00, 0x3ee5aeb5) // ReentrancyGuardReentrantCall()
                revert(0x1c, 0x04)
            }
            tstore(_LOCK_SLOT, 1)
        }
        _;
        assembly {
            tstore(_LOCK_SLOT, 0)
        }
    }
}
