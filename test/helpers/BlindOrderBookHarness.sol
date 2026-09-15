// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BlindOrderBook} from "../../src/BlindOrderBook.sol";

/**
 * @title BlindOrderBookHarness
 * @notice Expone `_consumeOrder` para tests de Fase 1.
 */
contract BlindOrderBookHarness is BlindOrderBook {
    /**
     * @notice Wrapper de test sobre `_consumeOrder`.
     * @param commitment Orden viva.
     * @param nullifier Nullifier del fill.
     */
    function consumeOrder(bytes32 commitment, bytes32 nullifier) external {
        _consumeOrder(commitment, nullifier);
    }
}
