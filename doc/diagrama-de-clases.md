# Diagrama de clases — ZK Dark Pool & Blind Order Book

Vista estructural de contratos, circuitos, librerías e interfaces (módulo 21, **v1 cerrado**).  
**Sync:** 2026-09-15 · API = código · `forge test` → **74 PASS**.

## Diagrama (Mermaid)

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

## Relaciones clave

| Relación | Descripción |
|----------|-------------|
| Trader → Poseidon | `commitment = Poseidon(Poseidon(price,amount), Poseidon(side,salt))` off-chain |
| Trader → DarkPool | Solo publica el commitment; parámetros ocultos |
| DarkPool ⊃ BlindOrderBook | Órdenes vivas (`liveOrders`) + `orderNullifiers` |
| DarkPool → Verifier | Match solo con Groth16 válida (7 públicos) |
| DarkPool → ShieldedVault | `applySettlement` con nullifiers de nota + change notes |
| Vault → Hasher | Merkle Poseidon (`hashLeftRight`) en deposit / change notes |
| Circuito → Verifier | Públicos: commitments, nullifiers, root, execAmount, execPrice |

---

## Notas de diseño (v1)

- Órdenes **ciegas**: ningún `price`/`amount`/`side` on-chain hasta el match.
- Nullifiers: `orderNullifiers` + `OrderAlreadyFilled()`; notas vía `noteNullifiers`.
- Proof: BUY ≥ SELL, membership bajo `balanceRoot`, `execPrice` en rango.
- Settlement **proof-based** (sin EIP-712 en v1); solo `darkPool` llama `applySettlement`.
- Transient reentrancy **por contrato** (`tstore` xor `address()`): DarkPool → Vault en la misma tx.
- Stack: Solidity `0.8.24`, Foundry, Poseidon, Groth16/BN254. Frontend Next.js fuera de v1.
- Decisiones / e2e: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md) · [`flujograma.md`](./flujograma.md).
