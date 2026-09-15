// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DarkPoolErrors} from "./errors/DarkPoolErrors.sol";

/**
 * @title BlindOrderBook
 * @notice Registro on-chain de commitments de orden vivos (parametros ocultos).
 * @dev Fase 1: submit / isLive. `_consumeOrder` es internal para que DarkPool (Fase 5) lo use con CEI.
 */
contract BlindOrderBook {
    /// @notice Commitments de orden aun no filled.
    mapping(bytes32 => bool) public liveOrders;

    /// @notice Nullifiers de orden consumidos (anti double-fill; uso pleno en Fase 5).
    mapping(bytes32 => bool) public orderNullifiers;

    /**
     * @notice Orden ciega registrada.
     * @param commitment Commitment Poseidon de la orden.
     * @param submitter Quien la envio on-chain.
     */
    event OrderSubmitted(bytes32 indexed commitment, address indexed submitter);

    /**
     * @notice Registra un commitment de orden vivo.
     * @param commitment `hash(price, amount, side, salt)` off-chain.
     * @return same El commitment registrado.
     */
    function submitOrder(bytes32 commitment) public virtual returns (bytes32 same) {
        if (commitment == bytes32(0)) {
            revert DarkPoolErrors.InvalidOrderCommitment();
        }
        if (liveOrders[commitment]) {
            revert DarkPoolErrors.InvalidOrderCommitment();
        }

        liveOrders[commitment] = true;
        emit OrderSubmitted(commitment, msg.sender);
        return commitment;
    }

    /**
     * @notice Indica si el commitment esta vivo (no filled).
     * @param commitment Commitment a consultar.
     * @return live True si esta en el libro.
     */
    function isLive(bytes32 commitment) public view returns (bool live) {
        return liveOrders[commitment];
    }

    /**
     * @notice Marca commitment como filled y registra nullifier (CEI).
     * @param commitment Orden viva a consumir.
     * @param nullifier Nullifier unico del fill.
     */
    function _consumeOrder(bytes32 commitment, bytes32 nullifier) internal {
        if (!liveOrders[commitment]) {
            revert DarkPoolErrors.InvalidOrderCommitment();
        }
        if (nullifier == bytes32(0) || orderNullifiers[nullifier]) {
            revert DarkPoolErrors.OrderAlreadyFilled();
        }

        liveOrders[commitment] = false;
        orderNullifiers[nullifier] = true;
    }
}
