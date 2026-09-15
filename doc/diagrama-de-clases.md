# Diagrama de clases — ZK Dark Pool & Blind Order Book

Vista estructural de contratos, circuitos, librerías e interfaces (módulo 21, **diseño objetivo v1**).  
**Sync:** 2026-09-15 · pre-implementación (autorización por fases).

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class IDarkPool {
        <<interface>>
        +submitOrder(commitment) bytes32
        +executeMatch(a,b,c,publicInputs,settlement)
        +orderNullifiers(nullifier) bool
        +currentRoot() bytes32
    }

    class IShieldedVault {
        <<interface>>
        +deposit(token, amount, noteCommitment)
        +balanceRoot() bytes32
        +noteNullifiers(hash) bool
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
        +UnknownBalanceRoot()
        +InsufficientShieldedBalance()
        +InvalidSettlement()
        +ZeroAddress()
        +Unauthorized()
        +EthTransferFailed()
        +TokenTransferFailed()
    }

    class TransientReentrancyGuard {
        <<abstract>>
        +nonReentrant()
    }

    class PoseidonT3 {
        <<library>>
        +hash(uint256[2]) uint256
    }

    class OrderCommitment {
        <<library>>
        +commit(price, amount, side, salt) bytes32
    }

    class PoseidonHasher {
        +hashLeftRight(left, right) bytes32
        +hashOrder(price, amount, side, salt) bytes32
    }

    class ShieldedVault {
        +token IERC20
        +notes mapping
        +noteNullifiers mapping
        +deposit(amount, noteCommitment)
        +applySettlement(buyerNote, sellerNote, amounts)
    }

    class BlindOrderBook {
        +orderCommitments mapping
        +orderNullifiers mapping
        +submitOrder(commitment) bytes32
        +isLive(commitment) bool
    }

    class DarkPool {
        +vault IShieldedVault
        +verifier IVerifier
        +hasher IHasher
        +orderNullifiers mapping
        +submitOrder(commitment)
        +executeMatch(proof, publicInputs, settlement)
    }

    class Groth16Verifier {
        +verifyProof(a, b, c, input) bool
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

    class MatchCircuit {
        <<circom MatchOrders>>
        +buyPrice private
        +sellPrice private
        +buyAmount private
        +sellAmount private
        +buySalt private
        +sellSalt private
        +buyNonce private
        +sellNonce private
        +execPrice private
        +buyCommitment public
        +sellCommitment public
        +buyNullifier public
        +sellNullifier public
        +balanceRoot public
        +execAmount public
        +execPricePublic public
    }

    IDarkPool <|.. DarkPool
    IShieldedVault <|.. ShieldedVault
    IHasher <|.. PoseidonHasher
    IHasher <|.. MockHasher
    IVerifier <|.. Groth16Verifier
    IVerifier <|.. MockVerifier

    TransientReentrancyGuard <|-- DarkPool
    TransientReentrancyGuard <|-- ShieldedVault
    PoseidonHasher --> PoseidonT3
    PoseidonHasher --> OrderCommitment
    VerifierGate --> IVerifier
    DarkPool --> IVerifier : verifyProof
    DarkPool --> IShieldedVault : settle
    DarkPool --> BlindOrderBook : live orders
    DarkPool --> DarkPoolErrors : reverts
    BlindOrderBook --> DarkPoolErrors : OrderAlreadyFilled
    Groth16Verifier ..> MatchCircuit : VK matches
```

---

## Relaciones clave

| Relación | Descripción |
|----------|-------------|
| Trader → Poseidon | `commitment = hash(price, amount, side, salt)` off-chain |
| Trader → DarkPool | Solo publica el commitment; parámetros ocultos |
| DarkPool → BlindOrderBook | Órdenes vivas indexadas por commitment |
| DarkPool → Verifier | Match solo con Groth16 válida (precio, saldos, rango) |
| DarkPool → orderNullifiers | Un nullifier = un fill (parcial o total) |
| DarkPool → ShieldedVault | Settlement atómico entre notas apantalladas |
| Circuito → Verifier | Públicos alineados: commitments, nullifiers, root, exec |

---

## Notas de diseño

- Órdenes **ciegas**: ningún `price`/`amount`/`side` on-chain hasta el match probado.
- Nullifiers obligatorios: `mapping(bytes32 => bool) public orderNullifiers` + `error OrderAlreadyFilled()`.
- Proof demuestra: BUY ≥ SELL, nonces/saldos válidos, `execPrice` dentro del rango comprometido.
- Settlement: transferencias entre vaults apantallados (EIP-712 o proof-based).
- Stack: Solidity `0.8.24`, Foundry, Poseidon, Groth16/BN254. Frontend Next.js fuera de v1.
- Diagramas de decisión/e2e: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md) · [`flujograma.md`](./flujograma.md).
