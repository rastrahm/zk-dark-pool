# Flujograma — Ciclo completo ZK Dark Pool

Flujo extremo a extremo entre traders, circuito, dark pool, verifier y vault apantallado (módulo 21, **diseño objetivo v1**).  
**Sync:** 2026-09-15 · pre-implementación.

## Actores

| Actor | Rol |
|-------|-----|
| Buyer / Seller | Generan `(price, amount, side, salt)`, commitment Poseidon, depositan en vault |
| Matcher / Relayer | Construye witness de match, genera proof Groth16, llama `executeMatch` |
| DarkPool | Órdenes ciegas, nullifiers, verify, orquesta settlement |
| ShieldedVault | Notas apantalladas, roots de saldo, transfers atómicos |
| Groth16Verifier | Pairing BN254 / Alt_BN128 (`ecPairing` `0x08`) |
| Circom / SnarkJS | `MatchOrders`, fixtures, export VK |
| Deployer | `Deploy.s.sol`: hasher + verifier + vault + pool |
| CI / Foundry | Unit, fuzz, gas snapshot, e2e fixture |

---

## Flujograma — Deploy

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy.s.sol: PoseidonHasher + Groth16Verifier + ShieldedVault + DarkPool]
    Dep --> Env[TOKEN + MERKLE_LEVELS lab + VK alineada]
    Env --> Ready([Pool listo — circuito debe = verifier])
```

---

## Flujograma principal — Deposit → Commit → Match → Settle

```mermaid
flowchart TD
    Start([Traders depositan en ShieldedVault]) --> Notes[Notas apantalladas + balanceRoot]
    Notes --> Buy[Buyer: commitment = Poseidon price,amount,BUY,salt]
    Notes --> Sell[Seller: commitment = Poseidon price,amount,SELL,salt]
    Buy --> SubB[submitOrder buyCommitment]
    Sell --> SubS[submitOrder sellCommitment]
    SubB --> Book[BlindOrderBook: órdenes vivas]
    SubS --> Book
    Book --> Match{¿buyPrice >= sellPrice off-chain?}
    Match -->|No| Wait[Sin match — órdenes siguen vivas]
    Match -->|Sí| Prove[SnarkJS: MatchOrders proof]
    Prove --> Exec[executeMatch proof + nullifiers + settlement]
    Exec --> Val[Validar commitments + nullifiers + root + proof]
    Val --> Auth{¿todo OK?}
    Auth -->|No| Fail[Revert custom error]
    Auth -->|Sí| Mark[Marcar orderNullifiers]
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
    A[executeMatch entrante] --> B[1. Commitments registrados y vivos]
    B --> C[2. Nullifiers de orden no gastados]
    C --> D[3. balanceRoot conocida]
    D --> E[4. verifyProof Groth16 MatchOrders]
    E --> F[5. Marcar orderNullifiers CEI]
    F --> G[6. Settlement en ShieldedVault]
    B -.->|fail| X1[InvalidOrderCommitment]
    C -.->|fail| X2[OrderAlreadyFilled]
    D -.->|fail| X3[UnknownBalanceRoot]
    E -.->|fail| X4[InvalidZKProof]
    G -.->|fail| X5[InvalidSettlement]
    G --> Ok([Éxito])
```

---

## Flujograma — Toolchain circuito (lab)

```mermaid
flowchart TD
    Start([circuits/matchOrders.circom]) --> Comp[npm run compile:circuit]
    Comp --> Ptau[ptau lab local]
    Ptau --> Setup[npm run generate:proof]
    Setup --> VK[npm run export:verifier]
    VK --> Fix[test/fixtures/match]
    Fix --> Forge[Foundry e2e / gas]
    Forge --> End([Suite en verde])
```

---

## Flujograma — Match gasless vía relayer

```mermaid
flowchart TD
    Start([Traders sin gas para match]) --> Build[Matcher genera proof off-chain]
    Build --> Send[Envía proof + públicos al relayer]
    Send --> Rel[Relayer: executeMatch]
    Rel --> Pool[DarkPool valida y settle]
    Pool --> V[Vault actualiza notas BUY/SELL]
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
| Settlement con montos inconsistentes | `InvalidSettlement` |

---

## Relación con otros diagramas

- Estructura de tipos: [`diagrama-de-clases.md`](./diagrama-de-clases.md)
- Decisiones internas: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md)
- Fases: [`planificacion.md`](./planificacion.md)
- Índice: [`README.md`](./README.md)
