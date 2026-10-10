# SWC Audit — Privacy-Preserving Dark Pools & ZK Order Books

Verification of the ZK dark pool (module 21) against the [SWC Registry](https://swcregistry.io/) (EIP-1470). Style aligned with [`20-institutional-custody-mpc/doc/SWC-AUDIT-EN.md`](../../20-institutional-custody-mpc/doc/SWC-AUDIT-EN.md).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contracts (prod / core):**  
`src/DarkPool.sol`,  
`src/BlindOrderBook.sol`,  
`src/ShieldedVault.sol`,  
`src/PoseidonHasher.sol`,  
`src/libraries/MerkleTreeWithHistory.sol`,  
`src/libraries/OrderCommitment.sol`,  
`src/libraries/PoseidonT3.sol`,  
`src/libraries/TransientReentrancyGuard.sol`,  
`src/errors/DarkPoolErrors.sol`,  
`src/interfaces/IDarkPool.sol`,  
`src/interfaces/IShieldedVault.sol`,  
`src/interfaces/IHasher.sol`,  
`src/interfaces/IVerifier.sol`,  
`src/verifiers/Groth16Verifier.sol`,  
`src/verifiers/VerifierGate.sol`

**Trusted dependencies:** forge-std, OpenZeppelin Contracts v5.2 (`IERC20`, `SafeERC20`), snarkJS Groth16 verifier (GPL-3.0)

**Mocks (out of prod):** `MockHasher`, `MockVerifier`, `MockERC20`  
**Date:** 2026-09-15 (Phase 7 / v1 closeout)  
**Reference tests:** `MatchExecution`, `OrderNullifierReplay`, `PriceMismatch`, `TamperedProof`, `DarkPoolMatch`, `ProofVerification`, `ShieldedVault`, `gas/DarkPool.gas` (74 PASS)  
**Index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md) · [`GAS-EN.md`](./GAS-EN.md)

---

## Executive summary

| Status | Count |
|--------|-------|
| ✅ Mitigated / Not applicable | 31 |
| ⚠️ Informational (ZK / dark pool design) | 5 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within v1 scope. Orders only as **Poseidon commitments**; match with **Groth16** (BUY≥SELL, balances, range); **nullifiers** against double-fill; settlement in **ShieldedVault** with CEI + **per-contract** transient reentrancy. Fixed pragma **`0.8.24`**.

**Suite / module 21 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `DarkPoolErrors` |
| Fixed pragma `0.8.24` | ✅ |
| CEI + reentrancy (pool → vault) | ✅ lock slot `xor` address |
| Poseidon blind commitments | ✅ `OrderCommitment` |
| `orderNullifiers` + `OrderAlreadyFilled` | ✅ |
| On-chain Groth16 match | ✅ 7 publics |
| Atomic vault settlement | ✅ `darkPool` only |
| Fuzz ≥ 1000 | ✅ `foundry.toml` |

---

## Full matrix SWC-100 — SWC-136

| ID | Title | Applies | Status | Evidence in ZK Dark Pool |
|----|-------|---------|--------|--------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; Circom comparators bound amounts off-chain |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) in every `.sol` |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | ERC-20 via `SafeERC20`; ETH deposit via `msg.value` (no outbound payout call in v1) |
| SWC-105 | Unprotected Ether Withdrawal | Yes | ✅ | ETH only enters via `deposit`; no free withdraw to EOAs in v1 (shielded notes) |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `nonReentrant` on `executeMatch` / `deposit` / `applySettlement`; per-contract slot |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `public` / `immutable` / `private` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Partial | ✅ | Settlement makes no external calls to EOAs; SafeERC20 reverts on failure |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | Matchers race for `executeMatch` — see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Vault auth via `msg.sender == darkPool`; no `tx.origin` |
| SWC-116 | Block values as a proxy for time | No | N/A | No critical logic based on `block.timestamp` |
| SWC-117 | Signature Malleability | Partial | ✅ | v1 proof-based settlement (no EIP-712 payout); Groth16 is not classic malleable ECDSA |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No material shadowing |
| SWC-120 | Weak Sources of Randomness | No | N/A | No on-chain RNG (salts off-chain) |
| SWC-121 | Missing Protection against Signature Replay | Yes | ✅ | `orderNullifiers` + `noteNullifiers`; replay tests |
| SWC-122 | Lack of Proper Signature Verification | Yes | ✅ | Groth16 pairing + binding of 7 publics |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + Phase 6 matrix |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Assembly only in PoseidonT3 / transient guard / verifier |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `IDarkPool, BlindOrderBook, TransientReentrancyGuard` |
| SWC-126 | Insufficient Gas Griefing | Partial | ⚠️ | Expensive verifier/pairing; caller pays gas — see risks |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ✅ | Lab Merkle depth 4; O(levels) insert |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge test` |
| SWC-130 | Right-To-Left-Override control character | No | N/A | ASCII in NatSpec/tests |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead variables |
| SWC-132 | Unexpected Ether balance | Yes | ✅ | Vault balance = deposits; not used for auth |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | Yes | ✅ | Fixed-field Poseidon; typed commitments |
| SWC-134 | Message call with hardcoded gas amount | No | N/A | No `.call{gas: ...}` |
| SWC-135 | Code With No Effects | No | N/A | Phase 0 stub paths removed |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Order params hidden (commitments); roots/nullifiers public by design |

---

## Informational risks

### SWC-114 — Match publication order

**Description:** Several matchers may submit the same proof; only the first marks the nullifiers.

**Status:** ⚠️ Inherent to dark pools / relayers.

**Mitigations:** Unique nullifiers; replay tests; commitments stop being live after a fill.

### SWC-126 — Pairing cost / gas griefing

**Description:** `verifyProof` costs ~229k gas; a caller can force pairing work with invalid proofs (they pay the gas).

**Status:** ⚠️ Standard for on-chain verifiers.

**Mitigations:** Live/nullifier/root checks **before** the pairing in `executeMatch` (cheap fails); off-chain rate-limit post-v1.

### Trusted setup (lab)

**Description:** Lab ptau/zkey (power-14) are not a production ceremony.

**Status:** ⚠️ Lab only; no mainnet without a real ceremony.

**Mitigation:** `.ptau`/`.zkey` in `.gitignore`; documented in `circuits/README.md`.

### One-shot `setDarkPool` / deployer trust

**Description:** Whoever deploys the vault sets the DarkPool exactly once; a miswired vault = impossible settlement or attacker-controlled settlement.

**Status:** ⚠️ Trust in the deploy script / deployment multisig.

**Mitigation:** `Deploy.s.sol` wires vault→pool atomically; Unauthorized tests.

### Anonymity set / historical roots

**Description:** `ROOT_HISTORY_SIZE = 30`; very old roots stop being valid.

**Status:** ⚠️ Tornado-like design (UX vs storage tradeoff).

**Mitigation:** `isKnownBalanceRoot`; documented in the diagrams.

---

## SWC → tests mapping

| SWC | Related test(s) |
|-----|-----------------|
| SWC-103 | `forge build` fixed pragma |
| SWC-107 | Nested DarkPool→Vault; per-address transient |
| SWC-121 | `OrderNullifierReplay.t.sol`; vault note nullifiers |
| SWC-122 | `ProofVerification.t.sol`; `MatchExecution.t.sol` |
| SWC-123 | `PriceMismatch`; `TamperedProof`; vault errors |
| SWC-136 | Blind commitments; no price/amount on-chain until match |

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [`20-institutional-custody-mpc/doc/SWC-AUDIT-EN.md`](../../20-institutional-custody-mpc/doc/SWC-AUDIT-EN.md)
- [`17-zk-snarks-privacy/doc/SWC-AUDIT-EN.md`](../../17-zk-snarks-privacy/doc/SWC-AUDIT-EN.md)
- [GAS-EN.md](./GAS-EN.md)
