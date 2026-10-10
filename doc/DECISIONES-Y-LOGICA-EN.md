# Technical decisions, logic, and gas — Module 21 ZK Dark Pool

Design document explaining **what was built, why, how it flows, and where gas can be improved**.  
Scope: v1 closed (phases 0–7). Sync: 2026-09-15 · `forge test` → **74 PASS**.

Related: [`planificacion-EN.md`](./planificacion-EN.md) · [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md).

---

## 1. What problem it solves

An institutional dark pool needs:

1. **Price / size / side** must not leak on-chain when the order is published.
2. A match is only valid if it is proven (without revealing the limits) that BUY ≥ SELL, there is enough balance, and the execution price is within range.
3. The same order cannot be **executed twice** (double-fill).
4. Settlement must be **atomic** across shielded notes.

v1 solves this with: **Poseidon commitments** + **Groth16 MatchOrders** + **nullifiers** + **ShieldedVault**.

---

## 2. Technical decisions (and why)

### 2.1 Stack and constraints

| Decision | Choice | Reason |
|----------|--------|--------|
| Compiler | Fixed `pragma solidity 0.8.24` | Suite rule: no floating pragma; native overflow checks |
| Tooling | Foundry | Tests, fuzz ≥1000, gas snapshot, Deploy |
| ZK | Circom 2.1.9 + SnarkJS **Groth16 / bn128** | EVM standard (`ecPairing`); mature tooling |
| Commitment hash | **Poseidon** (T3, 2 inputs) | Aligned with circomlib; cheap in-circuit vs keccak |
| EVM | Cancun | Transient storage (`tstore`) for reentrancy |
| Frontend | Out of v1 | Scope limited to contracts + circuit |

### 2.2 Order commitment (blind)

```text
orderCommitment = Poseidon(Poseidon(price, amount), Poseidon(side, salt))
orderNullifier  = Poseidon(salt, side)   // SIDE_BUY=0, SIDE_SELL=1
```

| Decision | Reason |
|----------|--------|
| **Nested** Poseidon (3 hashes), not a 4-input Poseidon | Same shape as Circom with `Poseidon(2)`; avoids Solidity ↔ circuit divergence |
| Only the `bytes32` commitment is published on-chain | No `price`/`amount`/`side` in storage or submit events |
| Private `salt` | Anti-preimage and nullifier uniqueness |
| Nullifier derived from `(salt, side)` | Binds to the side; anti double-fill without revealing price/amount |

**Tradeoff:** 3× Poseidon on-chain if someone verifies the hash in Solidity (~65k). Off-chain (matcher) it is free.

### 2.3 Blind book (`BlindOrderBook` ⊂ `DarkPool`)

| Decision | Reason |
|----------|--------|
| `DarkPool` **inherits** `BlindOrderBook` | A single contract for submit + match; shared `orderNullifiers` / `liveOrders` |
| `liveOrders[commitment] = true` on submit | O(1) lookup; no public CLOB with prices |
| Nullifiers separate from commitments | An order can explicitly “stop being live” and be marked by its nullifier |
| No on-chain matching queue | Matching is **off-chain** (matcher/relayer); on-chain only verifies and settles |

### 2.4 Shielded vault (`ShieldedVault`)

| Decision | Reason |
|----------|--------|
| Merkle notes + `balanceRoot` | Membership proven in-circuit without revealing which leaf |
| `ROOT_HISTORY_SIZE = 30` | Recent roots stay valid (Tornado style); bounded storage |
| Lab depth = **4** (`MatchOrders(4)`) | 16 leaves; fast proofs/fixtures; **not** a production size |
| **One-shot** `setDarkPool` | Only the authorized pool calls `applySettlement` |
| **Proof-based** settlement (no EIP-712 in v1) | Binding comes from Groth16 + nullifiers; smaller signature surface |
| ETH (`token=0`) or ERC-20 | One vault = one asset |
| Optional change notes (`newBuyNote` / `newSellNote`) | Allows “change” without revealing residual amounts on-chain |

### 2.5 `MatchOrders` circuit

| Decision | Reason |
|----------|--------|
| 7 fixed public inputs | Contract and fixtures aligned; no ambiguous calldata |
| Proves: BUY≥SELL, execPrice range, amounts, Merkle notes | Meets `.cursorrules` without leaking limits |
| Groth16 (not Plonk/Halo2) | Ready-made snarkJS verifier; native EVM pairing |
| Lab ptau power-14 | Enough for 4782 constraints; **not** a mainnet ceremony |
| Parameterized depth `MatchOrders(N)` | Must match `MERKLE_TREE_LEVELS` at deploy |

### 2.6 `executeMatch` — CEI order

Intentional order in `DarkPool.executeMatch`:

1. Live and distinct commitments  
2. Free and distinct nullifiers  
3. `isKnownBalanceRoot`  
4. `verifyProof` (expensive pairing)  
5. Effects: `liveOrders=false` + `orderNullifiers=true` (**without** re-calling `_consumeOrder`)  
6. `vault.applySettlement`  
7. `MatchExecuted` event

| Decision | Reason |
|----------|--------|
| **Cheap checks before** the pairing | Fail fast without paying ~229k of `ecPairing` |
| Mark nullifiers **before** settling | CEI: if settle reverts, the whole tx reverts (mark included) |
| **Per-contract** transient lock (`tstore xor address()`) | Allows DarkPool → Vault in the same tx without false “reentrancy” or the classic guard’s SSTORE |
| Embedded `publicInputs[7]` | Binding: the caller cannot lie about commitments/nullifiers/root/exec without invalidating the proof |

### 2.7 Security / product

| Decision | Reason |
|----------|--------|
| Custom errors (`DarkPoolErrors`) | Gas + clarity; no strings |
| SWC-100–136 matrix | Suite-style closeout (module 20) |
| Defensive tests (replay, mismatch, tampered) | “Attack” = revert; no offensive PoCs |
| `via_ir = false` | PoseidonT3 + IR does not compile in practical time |

---

## 3. System logic

### 3.1 Layer view

```text
┌───────────── Off-chain ─────────────┐     ┌──────────── On-chain ────────────┐
│ Traders: price, amount, side, salt  │     │ BlindOrderBook / DarkPool        │
│ → Poseidon commitment               │────►│ submitOrder(commitment)          │
│ Deposit noteAmount + noteSecret     │────►│ ShieldedVault.deposit → Merkle   │
│ Matcher: witness + groth16.prove    │────►│ executeMatch(proof, 7 publics)   │
│                                     │     │   → verify → nullify → settle    │
└─────────────────────────────────────┘     └──────────────────────────────────┘
```

### 3.2 Happy path (step by step)

1. **Deposit**  
   Trader deposits ETH/ERC-20 with `noteCommitment = Poseidon(amount, secret)`.  
   The vault inserts the leaf and updates `balanceRoot`.

2. **Submit order**  
   Off-chain: `commitment = Poseidon(Poseidon(price,amount), Poseidon(side,salt))`.  
   On-chain: `submitOrder(commitment)` → `liveOrders[commitment]=true`.  
   Nobody sees price/amount/side.

3. **Off-chain match**  
   The matcher knows the private BUY and SELL. If `buyPrice >= sellPrice`, it picks an in-range `execPrice` and a bounded `execAmount`.  
   It generates a `MatchOrders` proof that also shows both notes are under the current (or known historical) `balanceRoot`.

4. **On-chain executeMatch**  
   Relayer/matcher sends proof + 7 publics + change notes.  
   The contract validates state + proof; marks nullifiers; the vault spends note nullifiers and inserts change notes.

5. **Final state**  
   Orders no longer live; order and note nullifiers spent; new root; public event with commitments/nullifiers/exec (not the private limits).

### 3.3 What the proof shows (without revealing it)

```text
knowledge of (price, amount, side, salt) for BUY and SELL
  → open buyCommitment / sellCommitment
buyPrice >= sellPrice
sellPrice <= execPrice <= buyPrice
execAmount ≤ order and note amounts
Merkle(buyNote) and Merkle(sellNote) == balanceRoot
public nullifiers = Poseidon(salt, side) for each side
```

### 3.4 Failure paths (summary)

| Condition | Error |
|-----------|--------|
| Zero commitment / not live / BUY==SELL | `InvalidOrderCommitment` |
| Zero nullifier / already used / BUY nullifier == SELL | `OrderAlreadyFilled` |
| Root not in history | `UnknownBalanceRoot` |
| Invalid pairing or signals | `InvalidZKProof` |
| Settle from someone other than `darkPool` | `Unauthorized` |
| Inconsistent deposit amount / `msg.value` | `InvalidDepositAmount` |

### 3.5 What v1 does **not** do (on purpose)

- On-chain matching engine / CLOB with visible prices  
- Complex multi-leg partial fills  
- EIP-712 payout (proof-based only)  
- Depth 20 / production ceremony  
- Next.js frontend  
- Multi-asset cross-pool  

---

## 4. Gas: what exists today and how to improve it

### 4.1 v1 baseline (indicative)

| Path | Approx. gas |
|------|-------------|
| `submitOrder` | ~29 k |
| `PoseidonT3.hash` (1×) | ~18 k |
| `hashOrder` (3×) | ~65 k |
| `Groth16Verifier.verifyProof` | **~229 k** |
| `executeMatch` (mock verifier) | ~135 k |
| Groth16 e2e (test: deposits + match) | ~2.4 M |

Dominant costs: **Groth16 pairing** + **Poseidon × Merkle levels** on deposits.

### 4.2 Already applied in v1

- Cheap checks before the pairing  
- Mark nullifiers without re-SLOAD (`_consumeOrder` is not re-run on the hot path)  
- `vault` / `verifier` immutables cached on the stack  
- Transient reentrancy (no guard SSTORE)  
- Custom errors  
- `_insertChangeNote` without a duplicate capacity check  
- `optimizer_runs = 10_000`

### 4.3 Possible improvements (post-v1)

Ordered by impact / effort. None is “free”: all have tradeoffs.

#### A. High impact (change the ZK model or the tree)

| Improvement | Idea | Tradeoff |
|-------------|------|----------|
| **Recursive / aggregated proofs** | One proof aggregating N matches → a single on-chain pairing | More complex circuit; different toolchain |
| **Another proving system** (Plonk + KZG, Halo2, etc.) | Lower or different verification cost | Different verifier; less snarkJS “plug & play” |
| **Smaller Merkle depth in lab vs prod** | Depth 4 is already lab; in prod depth 20 hurts **deposit**, not so much verify | Anonymity set vs insert gas |
| **Incremental Merkle / sparse tree** | Fewer hashes per deposit if paths are cached | More state complexity |
| **Batch deposits** | Several leaves in one tx amortize overhead | Harder UX and circuit binding |

> The Groth16 pairing (~229k) is **not** reduced by Solidity micro-opts. You must change the proving scheme or verify fewer times (batch/recursive).

#### B. Medium impact (Solidity / calldata / storage)

| Improvement | Idea | Tradeoff |
|-------------|------|----------|
| **Pack publics into fewer words** | Today `uint256[7]`; pack small flags/amounts | Complicates circuit ↔ contract binding |
| **Leaner events** | Fewer indexed fields / fewer fields in `MatchExecuted` | Worse off-chain indexing |
| **Don’t duplicate `liveOrders` + nullifier** | Nullifier as the single source of truth | UX: live orders are harder to “see” |
| **Precompute Merkle zeros** | Already typical in Tornado-like trees; check for avoidable SLOADs | Depends on current implementation |
| **More aggressive Yul verifier** | Hand-tuned pairing path | Maintenance; risk vs snarkJS export |

#### C. Low impact / already near the limit

| Improvement | Note |
|-------------|------|
| More `immutable` / fewer storage reads | Match hot path already caches vault/verifier |
| `unchecked` on Merkle indices | Only if bounds are validated; small saving vs Poseidon |
| `via_ir = true` | Currently **blocked** by PoseidonT3; would need a different hasher or split compilation |
| Optimizer runs > 10k | Diminishing returns; measure with snapshot |

#### D. “Product” cost (not a gas bug)

- The relayer pays the match gas (~pairing + settle).  
- Traders pay for deposits (Poseidon × depth).  
- Off-chain rate-limit / mempool reduces invalid-pairing griefing (SWC-126 informational).

### 4.4 What **not** to “optimize” blindly

- Removing checks before the pairing → expensive fails and worse UX.  
- Weakening nullifier security to save an SSTORE.  
- Depth 20 without re-exporting VK / fixtures → invalid proofs.  
- Forcing `via_ir` without replacing PoseidonT3 → broken build.

---

## 5. Quick mental map (contracts)

| Artifact | Role |
|----------|------|
| `PoseidonHasher` / `OrderCommitment` | Hash aligned with Circom |
| `BlindOrderBook` | Live commitments + order nullifiers |
| `DarkPool` | Orchestrates submit + executeMatch |
| `ShieldedVault` | Notes, roots, settlement |
| `Groth16Verifier` | MatchOrders pairing |
| `VerifierGate` | `InvalidZKProof` helper (tests) |
| `Deploy.s.sol` | hasher → verifier → vault → pool → `setDarkPool` |

---

## 6. How to verify locally

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test
forge test --match-contract DarkPoolGasTest --gas-report
forge snapshot --match-contract DarkPoolGasTest
```

Circuits:

```bash
npm run compile:circuit
npm run generate:proof
npm run export:verifier
```

---

## 7. One-sentence summary

**Off-chain**, trade conditions are hidden and proven; **on-chain**, only commitments are registered, Groth16 is verified, nullifiers are marked, and the vault is settled — with gas dominated by the pairing and the match path already micro-optimized; large gas wins require batching, a different proving system, or a more efficient Merkle tree, not more SLOAD tweaks.
