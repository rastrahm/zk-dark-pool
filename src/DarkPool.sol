// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IDarkPool} from "./interfaces/IDarkPool.sol";
import {IShieldedVault} from "./interfaces/IShieldedVault.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";
import {BlindOrderBook} from "./BlindOrderBook.sol";
import {TransientReentrancyGuard} from "./libraries/TransientReentrancyGuard.sol";
import {DarkPoolErrors} from "./errors/DarkPoolErrors.sol";

/**
 * @title DarkPool
 * @notice Order book ciego + match Groth16 + settlement apantallado.
 * @dev CEI: checks → marcar nullifiers → vault.applySettlement.
 *      Gas: cache de immutables; consume sin re-SLOAD tras checks (Fase 7).
 */
contract DarkPool is IDarkPool, BlindOrderBook, TransientReentrancyGuard {
    /// @notice Vault de notas apantalladas.
    IShieldedVault public immutable vault;

    /// @notice Verifier Groth16 del circuito MatchOrders.
    IVerifier public immutable verifier;

    /**
     * @notice Match ejecutado y settled.
     * @param buyCommitment Commitment BUY consumido.
     * @param sellCommitment Commitment SELL consumido.
     * @param buyNullifier Nullifier BUY.
     * @param sellNullifier Nullifier SELL.
     * @param execAmount Monto publico ejecutado.
     * @param execPrice Precio publico ejecutado.
     */
    event MatchExecuted(
        bytes32 indexed buyCommitment,
        bytes32 indexed sellCommitment,
        bytes32 buyNullifier,
        bytes32 sellNullifier,
        uint256 execAmount,
        uint256 execPrice
    );

    /**
     * @notice Despliega el dark pool.
     * @param vault_ ShieldedVault (debe llamar `setDarkPool` con esta address).
     * @param verifier_ Groth16Verifier o MockVerifier.
     */
    constructor(IShieldedVault vault_, IVerifier verifier_) {
        if (address(vault_) == address(0) || address(verifier_) == address(0)) {
            revert DarkPoolErrors.ZeroAddress();
        }
        vault = vault_;
        verifier = verifier_;
    }

    /**
     * @inheritdoc IDarkPool
     */
    function submitOrder(bytes32 commitment) public override(IDarkPool, BlindOrderBook) returns (bytes32) {
        return BlindOrderBook.submitOrder(commitment);
    }

    /**
     * @inheritdoc IDarkPool
     * @dev Orden: live → nullifiers libres → known root → verifyProof → effects → settle.
     */
    function executeMatch(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[7] calldata publicInputs,
        bytes32 newBuyNote,
        bytes32 newSellNote
    ) external nonReentrant {
        IShieldedVault vault_ = vault;
        IVerifier verifier_ = verifier;

        bytes32 buyCommitment = bytes32(publicInputs[0]);
        bytes32 sellCommitment = bytes32(publicInputs[1]);
        bytes32 buyNullifier = bytes32(publicInputs[2]);
        bytes32 sellNullifier = bytes32(publicInputs[3]);
        bytes32 balanceRoot = bytes32(publicInputs[4]);

        if (buyCommitment == bytes32(0) || sellCommitment == bytes32(0) || buyCommitment == sellCommitment) {
            revert DarkPoolErrors.InvalidOrderCommitment();
        }
        if (!liveOrders[buyCommitment] || !liveOrders[sellCommitment]) {
            revert DarkPoolErrors.InvalidOrderCommitment();
        }
        if (
            buyNullifier == bytes32(0) || sellNullifier == bytes32(0) || buyNullifier == sellNullifier
                || orderNullifiers[buyNullifier] || orderNullifiers[sellNullifier]
        ) {
            revert DarkPoolErrors.OrderAlreadyFilled();
        }
        if (!vault_.isKnownBalanceRoot(balanceRoot)) {
            revert DarkPoolErrors.UnknownBalanceRoot();
        }
        if (!verifier_.verifyProof(a, b, c, publicInputs)) {
            revert DarkPoolErrors.InvalidZKProof();
        }

        // Effects: sin re-check de _consumeOrder (ya validados arriba).
        liveOrders[buyCommitment] = false;
        liveOrders[sellCommitment] = false;
        orderNullifiers[buyNullifier] = true;
        orderNullifiers[sellNullifier] = true;

        vault_.applySettlement(buyNullifier, sellNullifier, newBuyNote, newSellNote);

        emit MatchExecuted(
            buyCommitment, sellCommitment, buyNullifier, sellNullifier, publicInputs[5], publicInputs[6]
        );
    }
}
