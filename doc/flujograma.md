# Flujograma — Ciclo completo ZK Dark Pool

Flujo extremo a extremo entre traders, circuito, dark pool, verifier y vault apantallado (módulo 21, **v1 cerrado**).  
**Sync:** 2026-09-15 · **74 PASS**.

## Actores

| Actor | Rol |
|-------|-----|
| Buyer / Seller | Generan `(price, amount, side, salt)`, commitment Poseidon, depositan en vault |
| Matcher / Relayer | Construye witness de match, genera proof Groth16, llama `executeMatch` |
| DarkPool | Órdenes ciegas, nullifiers, verify, orquesta settlement |
| ShieldedVault | Notas apantalladas, roots de saldo, `applySettlement` |
| Groth16Verifier | Pairing BN254 / Alt_BN128 (`ecPairing` `0x08`) |
| Circom / SnarkJS | `MatchOrders(4)`, fixtures, export VK |
| Deployer | `Deploy.s.sol`: hasher + verifier + vault + pool + `setDarkPool` |
| CI / Foundry | Unit, fuzz, gas snapshot, e2e fixture |

---

## Flujograma — Deploy

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy.s.sol]
    Dep --> H[PoseidonHasher]
    Dep --> V[Groth16Verifier]
    Dep --> Vault["ShieldedVault(levels, hasher, token)"]
    Dep --> Pool["DarkPool(vault, verifier)"]
    Pool --> Link[vault.setDarkPool pool]
    Link --> Ready([Pool listo — circuito = VK = depth])
```

> `MERKLE_TREE_LEVELS` debe coincidir con `MatchOrders(N)` y el verifier exportado.

---

## Flujograma principal — Deposit → Commit → Match → Settle

```mermaid
flowchart TD
    Start([Traders depositan en ShieldedVault]) --> Notes[Notas apantalladas + balanceRoot]
    Notes --> Buy[Buyer: commitment Poseidon anidado]
    Notes --> Sell[Seller: commitment Poseidon anidado]
    Buy --> SubB[submitOrder buyCommitment]
    Sell --> SubS[submitOrder sellCommitment]
    SubB --> Book[BlindOrderBook: liveOrders]
    SubS --> Book
    Book --> Match{¿buyPrice >= sellPrice off-chain?}
    Match -->|No| Wait[Sin match — órdenes siguen vivas]
    Match -->|Sí| Prove[SnarkJS: MatchOrders proof]
    Prove --> Exec["executeMatch + change notes"]
    Exec --> Val[live → nullifiers → root → proof]
    Val --> Auth{¿todo OK?}
    Auth -->|No| Fail[Revert custom error]
    Auth -->|Sí| Mark[Marcar orderNullifiers + unlive]
    Mark --> Settle[ShieldedVault.applySettlement]
    Settle --> Done([Match atómico · límites no revelados])
    Fail --> End([Fin])
    Done --> End
    Wait --> End
```

---

## Flujograma — Capas de defensa en executeMatch

```mermaid
flowchart TD
    A[executeMatch entrante] --> B[1. Commitments vivos y distintos]
    B --> C[2. Nullifiers de orden libres]
    C --> D[3. balanceRoot conocida]
    D --> E[4. verifyProof Groth16 MatchOrders]
    E --> F[5. Mark liveOrders/nullifiers CEI]
    F --> G[6. applySettlement en ShieldedVault]
    B -.->|fail| X1[InvalidOrderCommitment]
    C -.->|fail| X2[OrderAlreadyFilled]
    D -.->|fail| X3[UnknownBalanceRoot]
    E -.->|fail| X4[InvalidZKProof]
    G -.->|fail| X5[Unauthorized / InvalidSettlement]
    G --> Ok([Éxito + MatchExecuted])
```

---

## Flujograma — Toolchain circuito (lab)

```mermaid
flowchart TD
    Start([circuits/matchOrders.circom]) --> Comp[npm run compile:circuit]
    Comp --> Ptau[ptau lab local pot14]
    Ptau --> Setup[npm run generate:proof]
    Setup --> VK[npm run export:verifier]
    VK --> Fix[test/fixtures/match]
    Fix --> Forge[Foundry e2e / gas]
    Forge --> End([Suite 74 PASS])
```

---

## Flujograma — Match vía relayer

```mermaid
flowchart TD
    Start([Traders sin gas para match]) --> Build[Matcher genera proof off-chain]
    Build --> Send[Envía proof + 7 públicos + change notes]
    Send --> Rel[Relayer: executeMatch]
    Rel --> Pool[DarkPool valida y settle]
    Pool --> V[Vault: noteNullifiers + change notes]
    V --> Done([Tx confirmada · fee opcional post-v1])
```

---

## Matriz de caminos felices / fallo

| Escenario | Resultado esperado |
|-----------|-------------------|
| `submitOrder` con commitment válido | Orden viva + `OrderSubmitted` |
| Match proof válida + BUY ≥ SELL | Settlement + nullifiers marcados |
| Mismo `orderNullifier` dos veces | `OrderAlreadyFilled` |
| Root de saldo desconocida | `UnknownBalanceRoot` |
| Proof / signals alterados | `InvalidZKProof` |
| Price mismatch (BUY < SELL) | No proof válida → `InvalidZKProof` |
| `applySettlement` sin ser darkPool | `Unauthorized` |
| Deposit con amount/msg.value inconsistente | `InvalidDepositAmount` |

---

## Relación con otros diagramas

- Estructura de tipos: [`diagrama-de-clases.md`](./diagrama-de-clases.md)
- Decisiones internas: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md)
- Fases: [`planificacion.md`](./planificacion.md)
- Gas / SWC: [`GAS.md`](./GAS.md) · [`SWC-AUDIT.md`](./SWC-AUDIT.md)
- Índice: [`README.md`](./README.md)
