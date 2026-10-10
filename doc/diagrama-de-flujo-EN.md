# Flow diagram — Commit, ZK match, and settlement

Internal decision flows of the dark pool, nullifiers, and ZK verification (module 21, **v1 closed**).  
**Sync:** 2026-09-15 · aligned with `DarkPool.executeMatch` / `ShieldedVault`.

## 1. submitOrder (blind commitment)

```mermaid
flowchart TD
    A[Trader: submitOrder commitment] --> B{commitment != 0?}
    B -->|No| Z0[Revert InvalidOrderCommitment]
    B -->|Yes| C{already live or nullified?}
    C -->|Yes| Z0
    C -->|No| D[liveOrders commitment = true]
    D --> E[Emit OrderSubmitted]
    Z0 --> End([End — revert])
    E --> Ok([End — OK · hidden params])
```

> Off-chain: `commitment = Poseidon(Poseidon(price, amount), Poseidon(side, salt))`.

---

## 2. Match proof generation (off-chain — Circom / SnarkJS)

```mermaid
flowchart TD
    A[Matcher knows private BUY + SELL] --> B{buyPrice >= sellPrice?}
    B -->|No| Fail[No match — do not generate proof]
    B -->|Yes| C[Pick execPrice within committed range]
    C --> D[Check nonces + shielded balances + Merkle paths]
    D --> E[Build input.json: privates + 7 publics]
    E --> F[Witness + groth16 prove]
    F --> G[proof + publicSignals]
    G --> H[Export calldata / Foundry fixture]
    H --> Ok([Ready for on-chain executeMatch])
    Fail --> End([End])
```

---

## 3. executeMatch (checks → proof → effects → settle)

```mermaid
flowchart TD
    A["Caller: executeMatch(a,b,c, publicInputs[7], newBuyNote, newSellNote)"] --> B{buy/sell live and distinct?}
    B -->|No| Z1[InvalidOrderCommitment]
    B -->|Yes| C{nullifiers free and distinct?}
    C -->|No| Z2[OrderAlreadyFilled]
    C -->|Yes| D{isKnownBalanceRoot?}
    D -->|No| Z3[UnknownBalanceRoot]
    D -->|Yes| E{verifier.verifyProof?}
    E -->|No| Z4[InvalidZKProof]
    E -->|Yes| F[liveOrders=false + orderNullifiers=true]
    F --> G["vault.applySettlement(nullifiers, change notes)"]
    G --> H[Emit MatchExecuted]
    Z1 --> End([End — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    H --> Ok([End — OK · atomic settle])
```

> **CEI (Phase 7):** cheap checks → pairing → mark without re-SLOAD → settle. Per-contract transient `nonReentrant`.

### Publics (`publicInputs[7]`)

| Index | Signal |
|-------|--------|
| 0–1 | `buyCommitment`, `sellCommitment` |
| 2–3 | `buyNullifier`, `sellNullifier` |
| 4 | `balanceRoot` |
| 5–6 | `execAmount`, `execPrice` |

---

## 4. ZK match validation (what the proof shows)

```mermaid
flowchart TD
    A[MatchOrders proof] --> B{buyPrice >= sellPrice?}
    B -->|No| Fail[InvalidZKProof]
    B -->|Yes| C{notes under balanceRoot + amounts OK?}
    C -->|No| Fail
    C -->|Yes| D{execPrice within BUY/SELL range?}
    D -->|No| Fail
    D -->|Yes| E{commitments = Poseidon params?}
    E -->|No| Fail
    E -->|Yes| Ok([Valid match — settle allowed])
    Fail --> End([On-chain revert])
```

---

## 5. Anti double-fill (order nullifier)

```mermaid
flowchart TD
    A[executeMatch with nullifier N] --> B{orderNullifiers N?}
    B -->|Yes| D[OrderAlreadyFilled]
    B -->|No| E[Mark + settle]
    D --> Fail([Revert])
    E --> Ok([One fill per nullifier])
```

---

## 6. Invalid / tampered proof / price mismatch

```mermaid
flowchart TD
    A[Altered proof or publicInputs] --> B[verifyProof]
    B --> C{pairing OK?}
    C -->|No| D[InvalidZKProof]
    C -->|Yes| E{signals == executeMatch args?}
    E -->|No| D
    E -->|Yes| Ok([Legitimate path])
    D --> Fail([Revert — forgery / mismatch blocked])
```

---

## 7. Shielded settlement (v1 proof-based)

```mermaid
flowchart TD
    A[Approved match] --> B{msg.sender == darkPool?}
    B -->|No| U[Unauthorized]
    B -->|Yes| C[Mark BUY/SELL noteNullifiers]
    C --> D[Insert change notes if != 0]
    D --> E[Update balanceRoot]
    E --> F[Emit SettlementApplied]
    U --> Fail([Revert])
    F --> Done([Logical assets moved · limits not revealed])
```

> v1 does **not** use EIP-712 for payout; binding comes from Groth16 + nullifiers.

---

## Related docs

- UML: [`diagrama-de-clases-EN.md`](./diagrama-de-clases-EN.md)
- E2E: [`flujograma-EN.md`](./flujograma-EN.md)
- Gas / SWC: [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md)
- Index: [`README-EN.md`](./README-EN.md)
