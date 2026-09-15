// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IShieldedVault} from "./interfaces/IShieldedVault.sol";
import {IHasher} from "./interfaces/IHasher.sol";
import {MerkleTreeWithHistory} from "./libraries/MerkleTreeWithHistory.sol";
import {TransientReentrancyGuard} from "./libraries/TransientReentrancyGuard.sol";
import {DarkPoolErrors} from "./errors/DarkPoolErrors.sol";

/**
 * @title ShieldedVault
 * @notice Vault de notas apantalladas: deposit → Merkle root; settlement via DarkPool.
 * @dev ETH si `token == address(0)`; ERC-20 en caso contrario. CEI + transient reentrancy.
 */
contract ShieldedVault is IShieldedVault, MerkleTreeWithHistory, TransientReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Token del vault (`address(0)` = ETH nativo).
    IERC20 public immutable token;

    /// @notice Contrato autorizado a llamar `applySettlement` (DarkPool).
    address public darkPool;

    /// @notice Note commitments ya depositados (anti replay de leaf).
    mapping(bytes32 => bool) public notes;

    /// @notice Nullifiers de nota gastados (anti double-spend en settlement).
    mapping(bytes32 => bool) public override noteNullifiers;

    /**
     * @notice Deposito apantallado registrado.
     * @param noteCommitment Commitment de la nota.
     * @param leafIndex Indice en el Merkle tree.
     * @param amount Monto depositado.
     * @param from Depositante.
     */
    event Deposited(bytes32 indexed noteCommitment, uint32 leafIndex, uint256 amount, address indexed from);

    /**
     * @notice Settlement aplicado (nullifiers + change notes).
     * @param buyNullifier Nullifier BUY.
     * @param sellNullifier Nullifier SELL.
     * @param newBuyNote Nueva nota BUY (puede ser 0).
     * @param newSellNote Nueva nota SELL (puede ser 0).
     */
    event SettlementApplied(
        bytes32 indexed buyNullifier,
        bytes32 indexed sellNullifier,
        bytes32 newBuyNote,
        bytes32 newSellNote
    );

    /**
     * @notice DarkPool autorizado actualizado.
     * @param darkPool Address del DarkPool.
     */
    event DarkPoolUpdated(address indexed darkPool);

    /**
     * @notice Despliega el vault.
     * @param levels_ Profundidad Merkle (lab tipico: 4).
     * @param hasher_ Poseidon / mock hasher.
     * @param token_ ERC-20 o `address(0)` para ETH.
     */
    constructor(uint32 levels_, IHasher hasher_, address token_) MerkleTreeWithHistory(levels_, hasher_) {
        token = IERC20(token_);
    }

    /**
     * @notice Configura el DarkPool autorizado (una sola vez).
     * @param darkPool_ Address del pool de match.
     */
    function setDarkPool(address darkPool_) external {
        if (darkPool != address(0)) revert DarkPoolErrors.Unauthorized();
        if (darkPool_ == address(0)) revert DarkPoolErrors.ZeroAddress();
        darkPool = darkPool_;
        emit DarkPoolUpdated(darkPool_);
    }

    /**
     * @inheritdoc IShieldedVault
     */
    function balanceRoot() external view returns (bytes32) {
        return getLastRoot();
    }

    /**
     * @inheritdoc IShieldedVault
     */
    function isKnownBalanceRoot(bytes32 root) external view returns (bool) {
        return isKnownRoot(root);
    }

    /**
     * @inheritdoc IShieldedVault
     * @dev Checks → effects (notes + insert) → interactions (pull funds).
     */
    function deposit(uint256 amount, bytes32 noteCommitment) external payable nonReentrant {
        if (amount == 0) revert DarkPoolErrors.InvalidDepositAmount();
        if (noteCommitment == bytes32(0)) revert DarkPoolErrors.InvalidNoteCommitment();
        if (notes[noteCommitment]) revert DarkPoolErrors.InvalidNoteCommitment();

        uint32 _next = nextIndex();
        uint32 capacity;
        unchecked {
            capacity = uint32(1) << levels;
        }
        if (_next >= capacity) revert DarkPoolErrors.TreeFull();

        bool ethMode = address(token) == address(0);
        if (ethMode) {
            if (msg.value != amount) revert DarkPoolErrors.InvalidDepositAmount();
        } else if (msg.value != 0) {
            revert DarkPoolErrors.InvalidDepositAmount();
        }

        notes[noteCommitment] = true;
        uint32 leafIndex = _insert(noteCommitment);

        if (!ethMode) {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }

        emit Deposited(noteCommitment, leafIndex, amount, msg.sender);
    }

    /**
     * @inheritdoc IShieldedVault
     * @dev CEI: nullifiers → insert change notes. Validacion ZK queda en DarkPool (Fase 5).
     */
    function applySettlement(
        bytes32 buyNullifier,
        bytes32 sellNullifier,
        bytes32 newBuyNote,
        bytes32 newSellNote
    ) external nonReentrant {
        if (msg.sender != darkPool) revert DarkPoolErrors.Unauthorized();
        if (buyNullifier == bytes32(0) || sellNullifier == bytes32(0)) {
            revert DarkPoolErrors.InvalidSettlement();
        }
        if (buyNullifier == sellNullifier) revert DarkPoolErrors.InvalidSettlement();
        if (noteNullifiers[buyNullifier] || noteNullifiers[sellNullifier]) {
            revert DarkPoolErrors.InvalidSettlement();
        }

        noteNullifiers[buyNullifier] = true;
        noteNullifiers[sellNullifier] = true;

        if (newBuyNote != bytes32(0)) {
            _insertChangeNote(newBuyNote);
        }
        if (newSellNote != bytes32(0)) {
            _insertChangeNote(newSellNote);
        }

        emit SettlementApplied(buyNullifier, sellNullifier, newBuyNote, newSellNote);
    }

    /**
     * @dev Inserta change note tras checks de unicidad y capacidad.
     */
    function _insertChangeNote(bytes32 noteCommitment) private {
        if (notes[noteCommitment]) revert DarkPoolErrors.InvalidNoteCommitment();

        uint32 _next = nextIndex();
        uint32 capacity;
        unchecked {
            capacity = uint32(1) << levels;
        }
        if (_next >= capacity) revert DarkPoolErrors.TreeFull();

        notes[noteCommitment] = true;
        _insert(noteCommitment);
    }
}
