# Flowchart — Full ZK Dark Pool cycle

End-to-end flow between traders, circuit, dark pool, verifier, and shielded vault (module 21, **v1 closed**).  
**Sync:** 2026-09-15 · **74 PASS**.

## Actors

| Actor | Role |
|-------|------|
| Buyer / Seller | Generate `(price, amount, side, salt)`, Poseidon commitment, deposit into the vault |
| Matcher / Relayer | Builds the match witness, generates the Groth16 proof, calls `executeMatch` |
| DarkPool | Blind orders, nullifiers, verify, orchestrates settlement |
| ShieldedVault | Shielded notes, balance roots, `applySettlement` |
| Groth16Verifier | BN254 / Alt_BN128 pairing (`ecPairing` `0x08`) |
| Circom / SnarkJS | `MatchOrders(4)`, fixtures, VK export |
| Deployer | `Deploy.s.sol`: hasher + verifier + vault + pool + `setDarkPool` |
| CI / Foundry | Unit, fuzz, gas snapshot, e2e fixture |

---

## Flowchart — Deploy

```mermaid
flowchart TD
    Start([Start]) --> Dep[Deploy.s.sol]
    Dep --> H[PoseidonHasher]
    Dep --> V[Groth16Verifier]
    Dep --> Vault["ShieldedVault(levels, hasher, token)"]
    Dep --> Pool["DarkPool(vault, verifier)"]
    Pool --> Link[vault.setDarkPool pool]
    Link --> Ready([Pool ready — circuit = VK = depth])
```

> `MERKLE_TREE_LEVELS` must match `MatchOrders(N)` and the exported verifier.

---

## Main flowchart — Deposit → Commit → Match → Settle

```mermaid
flowchart TD
    Start([Traders deposit into ShieldedVault]) --> Notes[Shielded notes + balanceRoot]
    Notes --> Buy[Buyer: nested Poseidon commitment]
    Notes --> Sell[Seller: nested Poseidon commitment]
    Buy --> SubB[submitOrder buyCommitment]
    Sell --> SubS[submitOrder sellCommitment]
    SubB --> Book[BlindOrderBook: liveOrders]
    SubS --> Book
    Book --> Match{buyPrice >= sellPrice off-chain?}
    Match -->|No| Wait[No match — orders stay live]
    Match -->|Yes| Prove[SnarkJS: MatchOrders proof]
    Prove --> Exec["executeMatch + change notes"]
    Exec --> Val[live → nullifiers → root → proof]
    Val --> Auth{all OK?}
    Auth -->|No| Fail[Revert custom error]
    Auth -->|Yes| Mark[Mark orderNullifiers + unlive]
    Mark --> Settle[ShieldedVault.applySettlement]
    Settle --> Done([Atomic match · limits not revealed])
    Fail --> End([End])
    Done --> End
    Wait --> End
```

---

## Flowchart — Defense layers in executeMatch

```mermaid
flowchart TD
    A[Incoming executeMatch] --> B[1. Live and distinct commitments]
    B --> C[2. Free order nullifiers]
    C --> D[3. Known balanceRoot]
    D --> E[4. verifyProof Groth16 MatchOrders]
    E --> F[5. Mark liveOrders/nullifiers CEI]
    F --> G[6. applySettlement in ShieldedVault]
    B -.->|fail| X1[InvalidOrderCommitment]
    C -.->|fail| X2[OrderAlreadyFilled]
    D -.->|fail| X3[UnknownBalanceRoot]
    E -.->|fail| X4[InvalidZKProof]
    G -.->|fail| X5[Unauthorized / InvalidSettlement]
    G --> Ok([Success + MatchExecuted])
```

---

## Flowchart — Circuit toolchain (lab)

```mermaid
flowchart TD
    Start([circuits/matchOrders.circom]) --> Comp[npm run compile:circuit]
    Comp --> Ptau[local lab ptau pot14]
    Ptau --> Setup[npm run generate:proof]
    Setup --> VK[npm run export:verifier]
    VK --> Fix[test/fixtures/match]
    Fix --> Forge[Foundry e2e / gas]
    Forge --> End([Suite 74 PASS])
```

---

## Flowchart — Match via relayer

```mermaid
flowchart TD
    Start([Traders without gas for the match]) --> Build[Matcher generates proof off-chain]
    Build --> Send[Sends proof + 7 publics + change notes]
    Send --> Rel[Relayer: executeMatch]
    Rel --> Pool[DarkPool validates and settles]
    Pool --> V[Vault: noteNullifiers + change notes]
    V --> Done([Tx confirmed · optional fee post-v1])
```

---

## Happy / failure path matrix

| Scenario | Expected result |
|----------|-----------------|
| `submitOrder` with a valid commitment | Live order + `OrderSubmitted` |
| Valid match proof + BUY ≥ SELL | Settlement + nullifiers marked |
| Same `orderNullifier` twice | `OrderAlreadyFilled` |
| Unknown balance root | `UnknownBalanceRoot` |
| Altered proof / signals | `InvalidZKProof` |
| Price mismatch (BUY < SELL) | No valid proof → `InvalidZKProof` |
| `applySettlement` not from darkPool | `Unauthorized` |
| Deposit with inconsistent amount/msg.value | `InvalidDepositAmount` |

---

## Related diagrams

- Type structure: [`diagrama-de-clases-EN.md`](./diagrama-de-clases-EN.md)
- Internal decisions: [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md)
- Phases: [`planificacion-EN.md`](./planificacion-EN.md)
- Gas / SWC: [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md)
- Index: [`README-EN.md`](./README-EN.md)
