# Diagrama de flujo — Commit, match ZK y settlement

Flujos de decisión internos del dark pool, nullifiers y verificación ZK (módulo 21, **v1 cerrado**).  
**Sync:** 2026-09-15 · alineado a `DarkPool.executeMatch` / `ShieldedVault`.

## 1. submitOrder (commitment ciego)

```mermaid
flowchart TD
    A[Trader: submitOrder commitment] --> B{¿commitment != 0?}
    B -->|No| Z0[Revert InvalidOrderCommitment]
    B -->|Sí| C{¿ya live o ya nullificado?}
    C -->|Sí| Z0
    C -->|No| D[liveOrders commitment = true]
    D --> E[Emit OrderSubmitted]
    Z0 --> End([Fin — revert])
    E --> Ok([Fin — OK · params ocultos])
```

> Off-chain: `commitment = Poseidon(Poseidon(price, amount), Poseidon(side, salt))`.

---

## 2. Generación de proof de match (off-chain — Circom / SnarkJS)

```mermaid
flowchart TD
    A[Matcher conoce BUY + SELL privados] --> B{¿buyPrice >= sellPrice?}
    B -->|No| Fail[No hay match — no generar proof]
    B -->|Sí| C[Elegir execPrice en rango comprometido]
    C --> D[Verificar nonces + saldos apantallados + Merkle paths]
    D --> E[Armar input.json: privados + 7 públicos]
    E --> F[Witness + groth16 prove]
    F --> G[proof + publicSignals]
    G --> H[Export calldata / fixture Foundry]
    H --> Ok([Listo para executeMatch on-chain])
    Fail --> End([Fin])
```

---

## 3. executeMatch (checks → proof → effects → settle)

```mermaid
flowchart TD
    A["Caller: executeMatch(a,b,c, publicInputs[7], newBuyNote, newSellNote)"] --> B{¿buy/sell vivos y distintos?}
    B -->|No| Z1[InvalidOrderCommitment]
    B -->|Sí| C{¿nullifiers libres y distintos?}
    C -->|No| Z2[OrderAlreadyFilled]
    C -->|Sí| D{¿isKnownBalanceRoot?}
    D -->|No| Z3[UnknownBalanceRoot]
    D -->|Sí| E{¿verifier.verifyProof?}
    E -->|No| Z4[InvalidZKProof]
    E -->|Sí| F[liveOrders=false + orderNullifiers=true]
    F --> G["vault.applySettlement(nullifiers, change notes)"]
    G --> H[Emit MatchExecuted]
    Z1 --> End([Fin — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    H --> Ok([Fin — OK · settle atómico])
```

> **CEI (Fase 7):** checks baratos → pairing → mark sin re-SLOAD → settle. Transient `nonReentrant` por contrato.

### Públicos (`publicInputs[7]`)

| Índice | Señal |
|--------|--------|
| 0–1 | `buyCommitment`, `sellCommitment` |
| 2–3 | `buyNullifier`, `sellNullifier` |
| 4 | `balanceRoot` |
| 5–6 | `execAmount`, `execPrice` |

---

## 4. Validación ZK del match (qué demuestra el proof)

```mermaid
flowchart TD
    A[Proof MatchOrders] --> B{¿buyPrice >= sellPrice?}
    B -->|No| Fail[InvalidZKProof]
    B -->|Sí| C{¿notas bajo balanceRoot + montos OK?}
    C -->|No| Fail
    C -->|Sí| D{¿execPrice en rango BUY/SELL?}
    D -->|No| Fail
    D -->|Sí| E{¿commitments = Poseidon params?}
    E -->|No| Fail
    E -->|Sí| Ok([Match válido — settle permitido])
    Fail --> End([Revert on-chain])
```

---

## 5. Anti double-fill (nullifier de orden)

```mermaid
flowchart TD
    A[executeMatch con nullifier N] --> B{¿orderNullifiers N?}
    B -->|Sí| D[OrderAlreadyFilled]
    B -->|No| E[Marcar + settle]
    D --> Fail([Revert])
    E --> Ok([Un solo fill por nullifier])
```

---

## 6. Proof inválida / tampered / price mismatch

```mermaid
flowchart TD
    A[Proof o publicInputs alterados] --> B[verifyProof]
    B --> C{¿pairing OK?}
    C -->|No| D[InvalidZKProof]
    C -->|Sí| E{¿signals == args executeMatch?}
    E -->|No| D
    E -->|Sí| Ok([Path legítimo])
    D --> Fail([Revert — forge / mismatch bloqueado])
```

---

## 7. Settlement apantallado (v1 proof-based)

```mermaid
flowchart TD
    A[Match aprobado] --> B{¿msg.sender == darkPool?}
    B -->|No| U[Unauthorized]
    B -->|Sí| C[Marcar noteNullifiers BUY/SELL]
    C --> D[Insert change notes si != 0]
    D --> E[Actualizar balanceRoot]
    E --> F[Emit SettlementApplied]
    U --> Fail([Revert])
    F --> Done([Assets lógicos movidos · límites no revelados])
```

> v1 **no** usa EIP-712 para payout; el binding lo da Groth16 + nullifiers.

---

## Relación con otros docs

- UML: [`diagrama-de-clases.md`](./diagrama-de-clases.md)
- E2E: [`flujograma.md`](./flujograma.md)
- Gas / SWC: [`GAS.md`](./GAS.md) · [`SWC-AUDIT.md`](./SWC-AUDIT.md)
- Índice: [`README.md`](./README.md)
