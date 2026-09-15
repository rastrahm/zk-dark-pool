# Auditoría SWC — Privacy-Preserving Dark Pools & ZK Order Books

Verificación del dark pool ZK (módulo 21) contra el [SWC Registry](https://swcregistry.io/) (EIP-1470). Estilo alineado a [`20-institutional-custody-mpc/doc/SWC-AUDIT.md`](../../20-institutional-custody-mpc/doc/SWC-AUDIT.md).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contratos auditados (prod / core):**  
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

**Dependencias de confianza:** forge-std, OpenZeppelin Contracts v5.2 (`IERC20`, `SafeERC20`), snarkJS Groth16 verifier (GPL-3.0)

**Mocks (fuera de prod):** `MockHasher`, `MockVerifier`, `MockERC20`  
**Fecha:** 2026-09-15 (Fase 7 / cierre v1)  
**Referencia tests:** `MatchExecution`, `OrderNullifierReplay`, `PriceMismatch`, `TamperedProof`, `DarkPoolMatch`, `ProofVerification`, `ShieldedVault`, `gas/DarkPool.gas` (74 PASS)  
**Índice:** [`README.md`](./README.md) · README módulo: [`../README.md`](../README.md) · [`GAS.md`](./GAS.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 31 |
| ⚠️ Informativo (diseño ZK / dark pool) | 5 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1. Órdenes solo como **commitments Poseidon**; match con **Groth16** (BUY≥SELL, saldos, rango); **nullifiers** anti double-fill; settlement en **ShieldedVault** con CEI + transient reentrancy **por contrato**. Pragma fijo **`0.8.24`**.

**Principios del suite / módulo 21 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `DarkPoolErrors` |
| Pragma fijo `0.8.24` | ✅ |
| CEI + reentrancy (pool → vault) | ✅ lock slot `xor` address |
| Blind commitments Poseidon | ✅ `OrderCommitment` |
| `orderNullifiers` + `OrderAlreadyFilled` | ✅ |
| Groth16 match on-chain | ✅ 7 públicos |
| Settlement atómico vault | ✅ solo `darkPool` |
| Fuzz ≥ 1000 | ✅ `foundry.toml` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en ZK Dark Pool |
|----|--------|--------|--------|---------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; comparadores Circom acotan montos off-chain |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) en todos los `.sol` |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | ERC-20 vía `SafeERC20`; ETH deposit por `msg.value` (sin call outbound de payout en v1) |
| SWC-105 | Unprotected Ether Withdrawal | Sí | ✅ | ETH solo entra por `deposit`; no hay withdraw libre a EOA en v1 (notas apantalladas) |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | `nonReentrant` en `executeMatch` / `deposit` / `applySettlement`; slot por contrato |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `public` / `immutable` / `private` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | Settlement no hace call externo a EOAs; SafeERC20 revierte en fallo |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Matchers compiten por `executeMatch` — ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth vault vía `msg.sender == darkPool`; no `tx.origin` |
| SWC-116 | Block values as a proxy for time | No | N/A | Sin lógica crítica basada en `block.timestamp` |
| SWC-117 | Signature Malleability | Parcial | ✅ | v1 settlement proof-based (no EIP-712 payout); Groth16 no es ECDSA malleable clásico |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing material |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG on-chain (salts off-chain) |
| SWC-121 | Missing Protection against Signature Replay | Sí | ✅ | `orderNullifiers` + `noteNullifiers`; tests replay |
| SWC-122 | Lack of Proper Signature Verification | Sí | ✅ | Pairing Groth16 + binding de 7 públicos |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + matriz Fase 6 |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Assembly solo en PoseidonT3 / transient guard / verifier |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `IDarkPool, BlindOrderBook, TransientReentrancyGuard` |
| SWC-126 | Insufficient Gas Griefing | Parcial | ⚠️ | Verifier/pairing costoso; caller paga gas — ver riesgos |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ✅ | Merkle depth 4 lab; insert O(levels) |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge test` |
| SWC-130 | Right-To-Left-Override control character | No | N/A | ASCII en NatSpec/tests |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin variables muertas materiales |
| SWC-132 | Unexpected Ether balance | Sí | ✅ | Saldo vault = depósitos; no se usa como auth |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | Sí | ✅ | Poseidon field fijo; commitments tipados |
| SWC-134 | Message call with hardcoded gas amount | No | N/A | Sin `.call{gas: ...}` |
| SWC-135 | Code With No Effects | No | N/A | Paths stub Fase 0 eliminados |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Params de orden ocultos (commitments); roots/nullifiers públicos por diseño |

---

## Riesgos informativos

### SWC-114 — Orden de publicación del match

**Descripción:** Varios matchers pueden enviar el mismo proof; solo el primero marca nullifiers.

**Estado:** ⚠️ Inherente a dark pools / relayers.

**Mitigaciones:** Nullifiers únicos; tests de replay; commitments dejan de estar live tras fill.

### SWC-126 — Coste de pairing / griefing de gas

**Descripción:** `verifyProof` ~229k gas; un caller puede forzar trabajo de pairing con proofs inválidas (paga el gas).

**Estado:** ⚠️ Estándar en verifiers on-chain.

**Mitigaciones:** Checks de live/nullifier/root **antes** del pairing en `executeMatch` (reduce cheap fails); rate-limit off-chain post-v1.

### Trusted setup (lab)

**Descripción:** Ptau/zkey de laboratorio (power-14) no son ceremonia productiva.

**Estado:** ⚠️ Solo lab; no mainnet sin ceremony real.

**Mitigación:** `.gitignore` de `.ptau`/`.zkey`; documentado en `circuits/README.md`.

### `setDarkPool` one-shot / trust en deployer

**Descripción:** Quien despliega el vault fija el DarkPool una sola vez; vault mal cableado = settlement imposible o controlado por atacante.

**Estado:** ⚠️ Trust en deploy script / multisig de despliegue.

**Mitigación:** `Deploy.s.sol` cablea vault→pool atómicamente; tests Unauthorized.

### Anonymity set / raíces históricas

**Descripción:** `ROOT_HISTORY_SIZE = 30`; roots muy antiguas dejan de ser válidas.

**Estado:** ⚠️ Diseño Tornado-like (tradeoff UX vs storage).

**Mitigación:** `isKnownBalanceRoot`; documentado en diagramas.

---

## Mapeo SWC → tests

| SWC | Test(s) relacionado(s) |
|-----|------------------------|
| SWC-103 | `forge build` pragma fijo |
| SWC-107 | Nested DarkPool→Vault; transient per-address |
| SWC-121 | `OrderNullifierReplay.t.sol`; vault note nullifiers |
| SWC-122 | `ProofVerification.t.sol`; `MatchExecution.t.sol` |
| SWC-123 | `PriceMismatch`; `TamperedProof`; vault errors |
| SWC-136 | Commitments ciegos; sin price/amount on-chain hasta match |

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [`20-institutional-custody-mpc/doc/SWC-AUDIT.md`](../../20-institutional-custody-mpc/doc/SWC-AUDIT.md)
- [`17-zk-snarks-privacy/doc/SWC-AUDIT.md`](../../17-zk-snarks-privacy/doc/SWC-AUDIT.md)
- [GAS.md](./GAS.md)
