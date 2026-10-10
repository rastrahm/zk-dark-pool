# Class diagram — ZK Dark Pool & Blind Order Book

Structural view of contracts, circuits, libraries, and interfaces (module 21, **v1 closed**).  
**Sync:** 2026-09-15 · API = code · `forge test` → **74 PASS**.

## Diagram (Mermaid)

```mermaid
classDiagram
    direction TB

    class IDarkPool {
        <<interface>>
        +submitOrder(commitment) bytes32
        +executeMatch(a,b,c,publicInputs,newBuyNote,newSellNote)
    }

    class IShieldedVault {
        <<interface>>
        +deposit(amount, noteCommitment) payable
        +balanceRoot() bytes32
        +isKnownBalanceRoot(root) bool
        +noteNullifiers(hash) bool
        +applySettlement(buyNullifier, sellNullifier, newBuyNote, newSellNote)
    }

    class IHasher {
        <<interface>>
        +hashLeftRight(left, right) bytes32
        +hashOrder(price, amount, side, salt) bytes32
    }

    class IVerifier {
        <<interface>>
        +verifyProof(a, b, c, input) bool
    }

    class DarkPoolErrors {
        <<errors>>
        +OrderAlreadyFilled()
        +InvalidZKProof()
        +InvalidOrderCommitment()
        +InvalidNoteCommitment()
        +TreeFull()
        +UnknownBalanceRoot()
        +InsufficientShieldedBalance()
        +InvalidSettlement()
        +ZeroAddress()
        +Unauthorized()
        +EthTransferFailed()
        +TokenTransferFailed()
        +InvalidDepositAmount()
    }

    class TransientReentrancyGuard {
        <<abstract>>
        +nonReentrant()
    }

    class MerkleTreeWithHistory {
        <<abstract>>
        +levels uint32
        +insert(leaf) uint32
        +isKnownRoot(root) bool
        +getLastRoot() bytes32
    }

    class PoseidonT3 {
        <<library>>
        +hash(uint256[2]) uint256
    }

    class OrderCommitment {
        <<library>>
        +commit(price, amount, side, salt) bytes32
        +SIDE_BUY SIDE_SELL
    }

    class PoseidonHasher {
        +hashLeftRight(left, right) bytes32
        +hashOrder(price, amount, side, salt) bytes32
    }

    class ShieldedVault {
        +token IERC20
        +darkPool address
        +notes mapping
        +noteNullifiers mapping
        +setDarkPool(darkPool) one-shot
        +deposit(amount, noteCommitment)
        +applySettlement(...)
    }

    class BlindOrderBook {
        +liveOrders mapping
        +orderNullifiers mapping
        +submitOrder(commitment) bytes32
        +isLive(commitment) bool
    }

    class DarkPool {
        +vault IShieldedVault
        +verifier IVerifier
        +submitOrder(commitment)
        +executeMatch(proof, publicInputs, changeNotes)
    }

    class Groth16Verifier {
        +verifyProof(a, b, c, input[7]) bool
    }

    class VerifierGate {
        +VERIFIER IVerifier
        +requireValidProof(a,b,c,input)
    }

    class MockVerifier {
        <<mock>>
        +shouldPass bool
        +verifyProof(...) bool
    }

    class MockHasher {
        <<mock>>
        +hashLeftRight(...) bytes32
        +hashOrder(...) bytes32
    }

    class MockERC20 {
        <<mock>>
        +mint(to, amount)
    }

    class MatchCircuit {
        <<circom MatchOrders~4~>>
        +buyCommitment public
        +sellCommitment public
        +buyNullifier public
        +sellNullifier public
        +balanceRoot public
        +execAmount public
        +execPrice public
    }

    IDarkPool <|.. DarkPool
    IShieldedVault <|.. ShieldedVault
    IHasher <|.. PoseidonHasher
    IHasher <|.. MockHasher
    IVerifier <|.. Groth16Verifier
    IVerifier <|.. MockVerifier

    TransientReentrancyGuard <|-- DarkPool
    TransientReentrancyGuard <|-- ShieldedVault
    MerkleTreeWithHistory <|-- ShieldedVault
    BlindOrderBook <|-- DarkPool
    PoseidonHasher --> PoseidonT3
    PoseidonHasher --> OrderCommitment
    VerifierGate --> IVerifier
    DarkPool --> IVerifier : verifyProof
    DarkPool --> IShieldedVault : applySettlement
    ShieldedVault --> IHasher : Merkle insert
    DarkPool --> DarkPoolErrors : reverts
    BlindOrderBook --> DarkPoolErrors : OrderAlreadyFilled
    Groth16Verifier ..> MatchCircuit : VK matches
```

---

## Key relationships

| Relationship | Description |
|--------------|-------------|
| Trader → Poseidon | `commitment = Poseidon(Poseidon(price,amount), Poseidon(side,salt))` off-chain |
| Trader → DarkPool | Only publishes the commitment; parameters stay hidden |
| DarkPool ⊃ BlindOrderBook | Live orders (`liveOrders`) + `orderNullifiers` |
| DarkPool → Verifier | Match only with a valid Groth16 proof (7 publics) |
| DarkPool → ShieldedVault | `applySettlement` with note nullifiers + change notes |
| Vault → Hasher | Poseidon Merkle (`hashLeftRight`) on deposit / change notes |
| Circuit → Verifier | Publics: commitments, nullifiers, root, execAmount, execPrice |

---

## Design notes (v1)

- **Blind** orders: no `price`/`amount`/`side` on-chain until the match.
- Nullifiers: `orderNullifiers` + `OrderAlreadyFilled()`; notes via `noteNullifiers`.
- Proof: BUY ≥ SELL, membership under `balanceRoot`, `execPrice` in range.
- **Proof-based** settlement (no EIP-712 in v1); only `darkPool` calls `applySettlement`.
- **Per-contract** transient reentrancy (`tstore` xor `address()`): DarkPool → Vault in the same tx.
- Stack: Solidity `0.8.24`, Foundry, Poseidon, Groth16/BN254. Next.js frontend out of v1.
- Decisions / e2e: [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md) · [`flujograma-EN.md`](./flujograma-EN.md).
