# Planning — Module 21: Privacy-Preserving Dark Pools & ZK Order Books

**Status:** Phases **0–7** ✅ (module v1 closed).  
**Progress rule:** the per-phase authorization rule applied during construction; v1 has no pending phases.  
**Suite:** `forge test` → **74 PASS**.  
**Docs sync:** 2026-09-15 — diagrams/API = code; SWC-AUDIT + GAS + Deploy; circuits README v1.

---

## 1. Goal

Build a **privacy-preserving institutional Dark Pool** that allows:

- Submitting orders as **Poseidon commitments** `hash(price, amount, side, salt)` without revealing parameters on-chain.
- Validating matches with **Groth16 proofs** (BN254 / Alt_BN128) showing that:
  1. BUY price ≥ SELL price.
  2. Valid nonces and sufficient shielded balances.
  3. The execution price lies within the committed range, without revealing the limits.
- Preventing double-fill with `orderNullifiers` and `error OrderAlreadyFilled()`.
- Executing proof-based **atomic settlement** between `ShieldedVault` notes (`applySettlement`).

Stack: **Foundry + Solidity `0.8.24`** + **Circom + SnarkJS**. The Next.js frontend is **out of v1 scope**.

---

## 2. Scope

| Included (v1) | Excluded (v1) |
|---------------|---------------|
| `DarkPool` — submitOrder / executeMatch / nullifiers | Public CLOB order book with visible prices |
| Poseidon commitments for blind orders | Plonk / Halo2 / Stark |
| Circom `MatchOrders` circuit + binding to commitments/nullifiers | Production off-chain matching engine |
| `Groth16Verifier` + `VerifierGate` / `InvalidZKProof` | Mainnet trusted setup (local lab ptau) |
| `ShieldedVault` — notes + atomic settlement | Multi-asset cross-pool routing |
| `BlindOrderBook` — registry of live commitments | Complex multi-leg partial fills |
| Tests: match OK, nullifier replay, price mismatch, tampered proof, gas | Next.js frontend (App Router) |
| Circom/SnarkJS scripts + `Deploy.s.sol` | Compliance / sanctions screening |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- **Exact** Solidity `0.8.24` (no floating pragma).
- OpenZeppelin Contracts v5.x in `lib/` (suite deps); prefer **transient reentrancy** (Cancun) where applicable.
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports / snapshot.
- **Custom errors** (no `require` strings).
- Strict CEI; ETH via **`.call{value: ...}("")`** / Yul (never `transfer`/`send`).
- NatSpec on public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests first in every contract phase.
- Architecture explained before coding (this document + diagrams).

### Module 21 (local `.cursorrules`)

- Commitments: Poseidon `hash(price, amount, side, salt)`.
- `mapping(bytes32 => bool) public orderNullifiers` + `OrderAlreadyFilled()`.
- On-chain ZK verification of the match (price, balances, range).
- Atomic settlement between shielded vaults.
- Tooling: Foundry + SnarkJS/Groth16; Poseidon vs pairing gas.

### Circom / SnarkJS (v1)

- `circuits/matchOrders.circom` → `MatchOrders`; build in `circuits/build/` (gitignored).
- Fixtures: `test/fixtures/match/` (committed).
- Local lab ptau; **do not** commit production `.ptau` / `.zkey`.

### Next.js (`nextjs.cursorrules`) — post-v1

- UI: shielded deposit, submit order, view commitment, trigger match, settlement history.
- App Router, Zod, Vitest + RTL, JSDoc, no `any`.
- **Outside** phases 0–7.

---

## 4. Target architecture (v1)

```
21-zk-dark-pool/
├── README.md                    # language index
├── README-ES.md / README-EN.md
├── .cursorrules
├── .gitignore
├── .env.example
├── .gas-snapshot
├── foundry.toml
├── remappings.txt
├── package.json
├── portfolio/                   # ES/EN landing
├── doc/                         # every doc in -ES.md and -EN.md
│   ├── README.md                # language index
│   ├── README-{ES,EN}.md
│   ├── planificacion-{ES,EN}.md
│   ├── diagrama-de-clases-{ES,EN}.md
│   ├── diagrama-de-flujo-{ES,EN}.md
│   ├── flujograma-{ES,EN}.md
│   ├── SWC-AUDIT-{ES,EN}.md
│   ├── GAS-{ES,EN}.md
│   └── DECISIONES-Y-LOGICA-{ES,EN}.md
├── circuits/
│   ├── README.md
│   ├── matchOrders.circom
│   ├── merkleTree.circom
│   └── build/                   # gitignored
├── scripts/
│   ├── compile-circuit.mjs
│   ├── generate-proof.mjs
│   └── export-verifier.mjs
├── src/
│   ├── DarkPool.sol
│   ├── BlindOrderBook.sol
│   ├── ShieldedVault.sol
│   ├── PoseidonHasher.sol
│   ├── verifiers/
│   │   ├── Groth16Verifier.sol
│   │   └── VerifierGate.sol
│   ├── interfaces/
│   │   ├── IDarkPool.sol
│   │   ├── IShieldedVault.sol
│   │   ├── IHasher.sol
│   │   └── IVerifier.sol
│   ├── libraries/
│   │   ├── PoseidonT3.sol
│   │   ├── OrderCommitment.sol
│   │   ├── MerkleTreeWithHistory.sol
│   │   └── TransientReentrancyGuard.sol
│   ├── errors/
│   │   └── DarkPoolErrors.sol
│   └── mocks/
│       ├── MockVerifier.sol
│       ├── MockHasher.sol
│       └── MockERC20.sol
├── test/
│   ├── helpers/
│   ├── MatchExecution.t.sol
│   ├── OrderNullifierReplay.t.sol
│   ├── PriceMismatch.t.sol
│   ├── TamperedProof.t.sol
│   ├── DarkPoolMatch.t.sol
│   ├── ProofVerification.t.sol
│   ├── ShieldedVault.t.sol
│   ├── gas/DarkPool.gas.t.sol
│   └── fixtures/match/
└── script/
    └── Deploy.s.sol
```

### Contracts and responsibilities

| Artifact | Responsibility |
|----------|----------------|
| `DarkPool` | `submitOrder` / `executeMatch`; inherits the book; orchestrates verify + settle |
| `BlindOrderBook` | `liveOrders` + `orderNullifiers` (DarkPool base) |
| `ShieldedVault` | Deposit + Merkle; `applySettlement` only from `darkPool` |
| `MerkleTreeWithHistory` | Insert + ring of 30 roots |
| `PoseidonHasher` / `PoseidonT3` / `OrderCommitment` | Hash aligned with circomlib |
| `IVerifier` / `Groth16Verifier` | Groth16 pairing (7 publics) |
| `VerifierGate` | `requireValidProof` → `InvalidZKProof` |
| `TransientReentrancyGuard` | Per-contract EIP-1153 lock (`xor address`) |
| `MockVerifier` / `MockHasher` / `MockERC20` | Tests |
| `DarkPoolErrors` | 13 module custom errors |

---

## 5. Custom errors (module)

```solidity
error OrderAlreadyFilled();          // required (.cursorrules)
error InvalidZKProof();              // failed / tampered / mismatched proof
error InvalidOrderCommitment();      // zero / duplicate / not registered
error InvalidNoteCommitment();       // zero / duplicate note (Phase 2)
error TreeFull();                    // balance Merkle tree full (Phase 2)
error UnknownBalanceRoot();          // balance root not in history
error InsufficientShieldedBalance(); // insufficient shielded balance (if checked on-chain)
error InvalidSettlement();           // inconsistent amounts / notes
error ZeroAddress();
error Unauthorized();                // admin / darkPool
error EthTransferFailed();
error TokenTransferFailed();
error InvalidDepositAmount();        // inconsistent msg.value / amount (Phase 2)
```

Module requirements: `OrderAlreadyFilled()`, ZK match verification, atomic settlement, blind commitments.

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|------|--------|
| **Gate** | No code for a phase is written until: *“I authorize Phase N”*. |
| **Delivery** | On close: acceptance checklist + files touched. |
| **Block** | New scope → document it and wait for new authorization. |
| **TDD** | In contract phases: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|-------|------|--------|---------------|
| 0 | Foundry + Node/Circom setup + structure | ✅ Completed | ✅ Authorized |
| 1 | Errors + Hasher + OrderCommitment + BlindOrderBook | ✅ Completed | ✅ Authorized |
| 2 | ShieldedVault (deposit + roots) | ✅ Completed | ✅ Authorized |
| 3 | Circom `MatchOrders` circuit + scripts | ✅ Completed | ✅ Authorized |
| 4 | `Groth16Verifier` + fixtures | ✅ Completed | ✅ Authorized |
| 5 | `DarkPool.submitOrder` + `executeMatch` + settlement | ✅ Completed | ✅ Authorized |
| 6 | Security suite: replay / mismatch / tampered | ✅ Completed | ✅ Authorized |
| 7 | Gas + Deploy + NatSpec / v1 closeout | ✅ Completed | ✅ Authorized |

---

## 7. Phase details

### Phase 0 — Foundry setup + ZK toolchain ✅

**Goal:** compilable repo + documented Circom/SnarkJS toolchain.

1. Foundry scaffold (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`).
2. Dependencies: `forge-std`, OpenZeppelin v5.
3. Folders `src/{verifiers,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas}`, `circuits/`, `scripts/`, `script/`, `test/fixtures/`.
4. `package.json` with `snarkjs` / utilities; `.env.example`; stub + smoke test; `README.md`.

**Exit criterion:** `forge build` and `forge test` green; README with Circom prereqs.

**Done (2026-09-15):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir = false`, fuzz `runs = 1000`, RPC `mainnet` / `sepolia`, `fs_permissions` for fixtures).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencies in `lib/` (gitignored): `forge-std` + OpenZeppelin **v5.2.0** (copied from module 17).
- Folders `src/{verifiers,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas,fixtures/match}`, `circuits/`, `scripts/`, `script/`, `zkeys/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + IERC20 remapping + fuzz 1000).
- Stub `script/Deploy.s.sol` (Phase 7), Node stubs `scripts/{compile-circuit,generate-proof,export-verifier}.mjs`.
- `package.json` + `npm install` (`snarkjs`, `circomlib`, `circomlibjs`, `poseidon-solidity`); `.env.example`; `README.md` + `circuits/README.md`.
- Circom **2.1.9** verified in PATH.
- `forge build` OK; `forge test` → **3 PASS** (fuzz 1000).

---

### Phase 1 — Errors + Hasher + OrderCommitment + BlindOrderBook ✅

**Goal:** order commitments and blind on-chain registry.

1. TDD: `hashOrder(price, amount, side, salt)`; submit commitment; reject zero/duplicate.
2. `PoseidonT3` + `OrderCommitment` via `IHasher`.
3. `DarkPoolErrors.sol` with the errors from §5 (incl. `OrderAlreadyFilled`).
4. Minimal `BlindOrderBook` structure / mapping of live commitments.

**Exit criterion:** commitment + book tests green.

**Done (2026-09-15):**
- `src/errors/DarkPoolErrors.sol` — 10 custom errors (incl. `OrderAlreadyFilled`).
- `src/interfaces/IHasher.sol` — `hashLeftRight` + `hashOrder`.
- `src/libraries/PoseidonT3.sol` — 2-input Poseidon (poseidon-solidity MIT, pragma `0.8.24`).
- `src/libraries/OrderCommitment.sol` — `Poseidon(Poseidon(price,amount), Poseidon(side,salt))`; `SIDE_BUY=0` / `SIDE_SELL=1`.
- `src/PoseidonHasher.sol` — IHasher wrapper aligned with Circom.
- `src/mocks/MockHasher.sol` — nested keccak for fast book tests.
- `src/BlindOrderBook.sol` — `submitOrder` / `isLive` / `liveOrders` / `orderNullifiers` + internal `_consumeOrder`.
- `test/helpers/BlindOrderBookHarness.sol` — exposes consume for tests.
- Tests: `DarkPoolErrors.t.sol`, `OrderCommitment.t.sol`, `BlindOrderBook.t.sol` (fuzz 1000).
- `Placeholder` stub removed.
- **`forge test` → 19 PASS**.

---

### Phase 2 — ShieldedVault ✅

**Goal:** shielded deposits and balance root.

1. TDD: deposit token/ETH → note commitment; `balanceRoot` updated.
2. Note nullifiers (preparation for settlement).
3. CEI + transient reentrancy; transfer custom errors.

**Exit criterion:** deposit unit + fuzz tests green.

**Done (2026-09-15):**
- `DarkPoolErrors`: +`InvalidNoteCommitment`, `TreeFull`, `InvalidDepositAmount` (13 errors).
- `TransientReentrancyGuard` (EIP-1153 Cancun).
- `MerkleTreeWithHistory` — insert, 30-root ring, `isKnownRoot` (adapted to DarkPoolErrors).
- `IShieldedVault` + `ShieldedVault`: ETH (`token=0`) / ERC-20 deposit; `balanceRoot`; `noteNullifiers`; `applySettlement` (`darkPool` only).
- One-shot `setDarkPool`; CEI: notes+insert before `safeTransferFrom`.
- `MockERC20` for tests.
- Tests: `ShieldedVault.t.sol` — ETH/ERC-20, TreeFull, historical roots, settlement nullifiers, fuzz 1000.
- **`forge test` → 38 PASS**.

---

### Phase 3 — Circom circuit + proof scripts ✅

**Goal:** reproducible match circuit.

1. `matchOrders.circom`: BUY ≥ SELL, Poseidon commitments, nullifiers, binding to root/exec.
2. Scripts: compile → witness → prove (Groth16) → export calldata/fixtures.
3. Document the lab ptau and public signal order; artifacts in `circuits/build/` ignored.

**Exit criterion:** lab proof generated; public signals documented.

**Done (2026-09-15):**
- Circom **2.1.9**: `circuits/matchOrders.circom` + `merkleTree.circom`.
- Compilation: **4782** constraints, **7** public inputs, **26** private.
- Relations: nested OrderCommit (= Solidity), nullifier `Poseidon(salt, side)`, Merkle notes under `balanceRoot`, price/amount ranges (`GreaterEqThan(64)`).
- Scripts: `compile-circuit.mjs`, `generate-proof.mjs` (lab ptau **power-14**).
- Fixtures: `test/fixtures/match/{input,proof,public,verification_key}.json` — `snarkjs.verify = true`.
- Docs: `circuits/README.md` (public signal order).
- **`forge test` → 38 PASS** (no regression).

---

### Phase 4 — On-chain verifier + fixtures ✅

**Goal:** `Groth16Verifier` usable from Foundry.

1. Export / adapt `Groth16Verifier.sol` (`pragma 0.8.24`).
2. `IVerifier` wrapper + `MockVerifier` for unit tests.
3. Fixtures in `test/fixtures/match/` consumable by Solidity tests.

**Exit criterion:** valid pairing test + invalid proof → revert.

**Done (2026-09-15):**
- `scripts/export-verifier.mjs` — snarkjs export + pragma `0.8.24` patch + `is IVerifier` (7 publics).
- `src/verifiers/Groth16Verifier.sol` (GPL-3.0 snarkJS) + `VerifierGate` (`InvalidZKProof`).
- `src/interfaces/IVerifier.sol` + `src/mocks/MockVerifier.sol`.
- Fixture `test/fixtures/match/solidity_proof.json` (a/b/c/input hex, Ethereum order).
- Tests: `ProofVerification.t.sol` — valid, tampered proof/inputs → false / `InvalidZKProof`, mock gate.
- **`forge test` → 46 PASS**.

---

### Phase 5 — DarkPool match + settlement ✅

**Goal:** atomic ZK match with anti double-fill.

1. Tests first: valid match; nullifier marked; vault settle.
2. CEI order: live commitments → free nullifiers → root → proof → mark → settle.
3. Binding: public signals must match the `executeMatch` args.

**Exit criterion:** e2e with real fixture or mock verifier + correct settlement.

**Done (2026-09-15):**
- `IDarkPool` + `DarkPool` (inherits `BlindOrderBook` + transient reentrancy).
- `executeMatch`: live → nullifiers → `isKnownBalanceRoot` → `verifyProof` → mark → `vault.applySettlement(newBuyNote, newSellNote)`.
- **Per-contract** transient lock (`xor` with `address()`), allows DarkPool → Vault in the same tx.
- Mock tests: success, nullifier replay, unknown root, not live, invalid proof.
- E2E: Poseidon vault + `Groth16Verifier` + MatchOrders fixture — on-chain `balanceRoot` == circuit.
- **`forge test` → 53 PASS** (consume-without-re-SLOAD opts in Phase 7).

---

### Phase 6 — Security matrix (module tests) ✅

| Type | What it validates |
|------|-------------------|
| ZK Match Execution | Atomic settlement with valid BUY/SELL proofs |
| Order Nullifier Replay | Second match → `OrderAlreadyFilled` |
| Price Mismatch | BUY < SELL / invalid range → `InvalidZKProof` |
| Tampered Proof | Altered proof or commitments → `InvalidZKProof` |

**Exit criterion:** `MatchExecution`, `OrderNullifierReplay`, `PriceMismatch`, `TamperedProof` green.

**Done (2026-09-15):**
- `test/helpers/DarkPoolSecurityBase.sol` — ZK/mock deploy + fixture notes.
- `MatchExecution.t.sol` — atomic settle + change notes update the root.
- `OrderNullifierReplay.t.sol` — same proof twice, cross-order reuse, nullifier fuzz.
- `PriceMismatch.t.sol` — tampered execPrice/execAmount → `InvalidZKProof`; orders stay live (CEI).
- `TamperedProof.t.sol` — proof A, commitments, nullifier, root, mock false.
- **`forge test` → 68 PASS**.

---

### Phase 7 — Gas + Deploy + hardening ✅

**Goal:** profiling and v1 closeout.

1. Gas: Poseidon commitment updates vs Groth16 pairing; snapshot / `doc/GAS-EN.md`.
2. `Deploy.s.sol` + complete NatSpec.
3. Update diagrams / planning to “implemented”.
4. `doc/SWC-AUDIT-EN.md` in module 20 style.

**Exit criterion:** full suite green; module v1 ready to close.

**Done (2026-09-15):**
- Gas opts: consume without re-SLOAD; cached immutables; checks before pairing; lean `_insertChangeNote`; per-address transient lock.
- `test/gas/DarkPool.gas.t.sol` + `.gas-snapshot` + `doc/GAS-EN.md` (Poseidon ~18k vs Groth16 ~229k).
- `script/Deploy.s.sol` — hasher + verifier + vault + pool + `setDarkPool`.
- `doc/SWC-AUDIT-EN.md` — SWC-100–136 matrix (0 vulnerable, 5 informational).
- Docs sync: UML/flows/circuits aligned with the real API (`executeMatch` + change notes; no EIP-712 in v1).
- **`forge test` → 74 PASS**.

---

## 8. Cryptographic model (v1)

### Order commitment and nullifier

```text
orderCommitment = Poseidon(Poseidon(price, amount), Poseidon(side, salt))
orderNullifier  = Poseidon(salt, side)              // SIDE_BUY=0, SIDE_SELL=1
noteCommitment  = Poseidon(noteAmount, noteSecret)
```

The proof shows:

1. Knowledge of the params that open `buyCommitment` and `sellCommitment`.
2. `buyPrice >= sellPrice` and `sellPrice <= execPrice <= buyPrice`.
3. `execAmount` bounded by order amounts and shielded note amounts.
4. Membership of both notes under `balanceRoot`.
5. Binding to the public nullifiers (anti-replay).

### Public signals (v1 — fixed order)

```text
publicInputs = [
  buyCommitment,
  sellCommitment,
  buyNullifier,
  sellNullifier,
  balanceRoot,
  execAmount,
  execPrice
]
```

Exactly aligned: `matchOrders.circom` ↔ `DarkPool.executeMatch` (Phase 5) ↔ fixtures.

---

## 9. Global acceptance criteria (v1)

- [x] Fixed pragma `0.8.24` in every contract.
- [x] Orders only as Poseidon commitments (params hidden until match).
- [x] `orderNullifiers` + `OrderAlreadyFilled`.
- [x] On-chain Groth16 verification of the match (price, balances, range).
- [x] Atomic settlement in `ShieldedVault`.
- [x] Tests: match OK, nullifier replay, price mismatch, tampered proof.
- [x] NatSpec + custom errors + CEI / reentrancy.
- [x] Circom/SnarkJS documented; secrets/ptau/zkey not committed.
- [x] Documentation (`doc/`) aligned with final code + GAS + SWC.

---

## 10. Post-v1 status

Module **v1 is closed** (phases 0–7). Extensions require new scope authorization.

Reference suite: `forge test` → **74 PASS**.

Optional post-v1: Next.js frontend, multi-leg partial fills, depth 20, production ceremony.
