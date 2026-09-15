// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVerifier} from "../interfaces/IVerifier.sol";

/**
 * @title MockVerifier
 * @notice Verifier configurable para unit tests sin pairing real.
 */
contract MockVerifier is IVerifier {
    bool public shouldPass = true;

    /**
     * @notice Configura el resultado de `verifyProof`.
     * @param value True para aceptar cualquier proof.
     */
    function setShouldPass(bool value) external {
        shouldPass = value;
    }

    /**
     * @inheritdoc IVerifier
     */
    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[7] calldata
    ) external view returns (bool) {
        return shouldPass;
    }
}
