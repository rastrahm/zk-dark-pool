# Diagrama de flujo — Commit, match ZK y settlement

Flujos de decisión internos del dark pool, nullifiers y verificación ZK (módulo 21, **diseño objetivo v1**).  
**Sync:** 2026-09-15.

## 1. submitOrder (commitment ciego)

```mermaid
flowchart TD
    A[Trader: submitOrder commitment] --> B{¿commitment != 0?}
    B -->|No| Z0[Revert InvalidOrderCommitment]
    B -->|Sí| C{¿ya existe / ya nullificado?}
    C -->|Sí| Z0
    C -->|No| D[Registrar commitment en BlindOrderBook]
    D --> E[Emit OrderSubmitted]
    Z0 --> End([Fin — revert])
    E --> Ok([Fin — OK · params ocultos])
```

> `commitment = Poseidon(price, amount, side, salt)` off-chain. Sin exposición de trade params on-chain.

---

## 2. Generación de proof de match (off-chain — Circom / SnarkJS)

```mermaid
flowchart TD
    A[Matcher conoce BUY + SELL privados] --> B{¿buyPrice >= sellPrice?}
    B -->|No| Fail[No hay match — no generar proof]
    B -->|Sí| C[Elegir execPrice en rango comprometido]
    C --> D[Verificar nonces + saldos apantallados]
    D --> E[Armar input.json: privados + públicos]
    E --> F[Witness + groth16 prove]
    F --> G[proof + publicSignals]
    G --> H[Export calldata / fixture Foundry]
    H --> Ok([Listo para executeMatch on-chain])
    Fail --> End([Fin])
```

---

## 3. executeMatch (nullifiers → proof → settle)

```mermaid
flowchart TD
    A[Caller: executeMatch proof + públicos + settlement] --> B{¿buy/sell commitments vivos?}
    B -->|No| Z1[Revert InvalidOrderCommitment]
    B -->|Sí| C{¿orderNullifiers ya true?}
    C -->|Sí| Z2[Revert OrderAlreadyFilled]
    C -->|No| D{¿balanceRoot conocida?}
    D -->|No| Z3[Revert UnknownBalanceRoot]
    D -->|Sí| E[Pack publicInputs alineados al circuito]
    E --> F{¿verifier.verifyProof?}
    F -->|No| Z4[Revert InvalidZKProof]
    F -->|Sí| G[Marcar buyNullifier + sellNullifier]
    G --> H[ShieldedVault.applySettlement CEI]
    H --> I{¿transfers OK?}
    I -->|No| Z5[Revert InvalidSettlement / TokenTransferFailed]
    I -->|Sí| J[Emit MatchExecuted]
    Z1 --> End([Fin — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    Z5 --> End
    J --> Ok([Fin — OK · settle atómico])
```

> CEI: marcar `orderNullifiers` **antes** de tocar el vault. Transient reentrancy.

---

## 4. Validación ZK del match (qué demuestra el proof)

```mermaid
flowchart TD
    A[Proof MatchOrders] --> B{¿buyPrice >= sellPrice?}
    B -->|No| Fail[InvalidZKProof]
    B -->|Sí| C{¿nonces + saldos suficientes?}
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
    E --> Ok([Un solo fill por commitment / nullifier])
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
    E -->|Sí| F{¿BUY precio >= SELL implícito?}
    F -->|No| D
    F -->|Sí| Ok([Path legítimo])
    D --> Fail([Revert — forge / mismatch bloqueado])
```

---

## 7. Settlement apantallado

```mermaid
flowchart TD
    A[Match aprobado] --> B[Consumir notas BUY/SELL vía nullifiers de nota]
    B --> C[Transferir amounts entre shielded notes]
    C --> D{¿EIP-712 o proof-based?}
    D -->|EIP-712| E[Validar firmas dinámicas]
    D -->|Proof| F[Ya cubierto por MatchCircuit]
    E --> G[Actualizar balanceRoot]
    F --> G
    G --> Done([Assets movidos sin revelar límites])
```

---

## Relación con otros docs

- UML: [`diagrama-de-clases.md`](./diagrama-de-clases.md)
- E2E: [`flujograma.md`](./flujograma.md)
- Índice: [`README.md`](./README.md)
