# Planificación — Módulo 21: Privacy-Preserving Dark Pools & ZK Order Books

**Estado:** Fases **0–3** ✅ · Fases **4–7** ⏳ pendientes.  
**Regla de avance:** no se escribe código de una fase hasta autorización explícita (*“autorizo Fase N”*).  
**Suite:** `forge test` → **38 PASS** · circuito MatchOrders **4782** constraints · fixtures verify OK.  
**Docs sync:** 2026-09-15 — Fase 3 cerrada (Circom MatchOrders).

---

## 1. Objetivo

Construir un **Dark Pool institucional con preservación de privacidad** que permita:

- Enviar órdenes como **commitments Poseidon** `hash(price, amount, side, salt)` sin revelar parámetros on-chain.
- Validar matches con **pruebas Groth16** (BN254 / Alt_BN128) que demuestren:
  1. Precio BUY ≥ precio SELL.
  2. Nonces válidos y saldos apantallados suficientes.
  3. Precio de ejecución dentro del rango comprometido, sin revelar límites.
- Prevenir double-fill con `orderNullifiers` y `error OrderAlreadyFilled()`.
- Ejecutar **settlement atómico** entre vaults de balances apantallados (EIP-712 o proof-based).

Stack: **Foundry + Solidity `0.8.24`** + **Circom + SnarkJS**. Frontend Next.js queda **fuera de alcance v1**.

---

## 2. Alcance

| Incluido (v1) | Excluido (v1) |
|---------------|---------------|
| `DarkPool` — submitOrder / executeMatch / nullifiers | Order book CLOB público con precios visibles |
| Commitments Poseidon de órdenes ciegas | Plonk / Halo2 / Stark |
| Circuito Circom `MatchOrders` + binding a commitments/nullifiers | Matching engine off-chain de producción |
| `Groth16Verifier` + `VerifierGate` / `InvalidZKProof` | Trusted setup mainnet (ptau lab local) |
| `ShieldedVault` — notas + settlement atómico | Multi-asset cross-pool routing |
| `BlindOrderBook` — registro de commitments vivos | Partial fills complejos multi-leg |
| Tests: match OK, nullifier replay, price mismatch, tampered proof, gas | Frontend Next.js (App Router) |
| Scripts Circom/SnarkJS + `Deploy.s.sol` | Compliance / sanctions screening |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- Solidity **exacto** `0.8.24` (sin floating pragma).
- OpenZeppelin Contracts v5.x en `lib/` (deps de suite); preferir **transient reentrancy** (Cancun) cuando aplique.
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports / snapshot.
- **Custom errors** (no `require` strings).
- CEI estricto; ETH vía **`.call{value: ...}("")`** / Yul (nunca `transfer`/`send`).
- NatSpec en API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests primero en cada fase de contratos.
- Arquitectura explicada antes de codear (este documento + diagramas).

### Módulo 21 (`.cursorrules` local)

- Commitments: Poseidon `hash(price, amount, side, salt)`.
- `mapping(bytes32 => bool) public orderNullifiers` + `OrderAlreadyFilled()`.
- Verificación ZK on-chain del match (precio, saldos, rango).
- Settlement atómico entre shielded vaults.
- Tooling: Foundry + SnarkJS/Groth16; gas de Poseidon vs pairing.

### Circom / SnarkJS (v1)

- `circuits/matchOrders.circom` → `MatchOrders`; build en `circuits/build/` (gitignored).
- Fixtures: `test/fixtures/match/` (versionables).
- Ptau lab local; **no** versionar `.ptau` / `.zkey` de producción.

### Next.js (`nextjs.cursorrules`) — post-v1

- UI: deposit shielded, submit order, ver commitment, trigger match, historial de settles.
- App Router, Zod, Vitest + RTL, JSDoc, sin `any`.
- **Fuera** de las fases 0–7.

---

## 4. Arquitectura objetivo (v1)

```
21-zk-dark-pool/
├── README.md
├── .cursorrules
├── .gitignore
├── .env.example
├── foundry.toml
├── remappings.txt
├── package.json
├── doc/
│   ├── README.md
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   └── flujograma.md
├── circuits/
│   ├── README.md
│   ├── matchOrders.circom
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
│   │   └── TransientReentrancyGuard.sol
│   ├── errors/
│   │   └── DarkPoolErrors.sol
│   └── mocks/
│       ├── MockVerifier.sol
│       └── MockHasher.sol
├── test/
│   ├── helpers/
│   ├── MatchExecution.t.sol
│   ├── OrderNullifierReplay.t.sol
│   ├── PriceMismatch.t.sol
│   ├── TamperedProof.t.sol
│   ├── gas/
│   └── fixtures/match/
└── script/
    └── Deploy.s.sol
```

### Contratos y responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `DarkPool` | submitOrder / executeMatch; nullifiers; orquesta verify + settle |
| `BlindOrderBook` | Registro de commitments vivos (puede vivir dentro de DarkPool) |
| `ShieldedVault` | Depósitos apantallados; settlement atómico entre notas |
| `PoseidonHasher` / `PoseidonT3` / `OrderCommitment` | Hash alineado a circomlib |
| `IVerifier` / `Groth16Verifier` | Pairing Groth16 del match |
| `VerifierGate` | `requireValidProof` → `InvalidZKProof` |
| `TransientReentrancyGuard` | Lock EIP-1153 (Cancun) |
| `MockVerifier` / `MockHasher` | Tests unitarios |
| `DarkPoolErrors` | Custom errors del módulo |

---

## 5. Errores custom (módulo)

```solidity
error OrderAlreadyFilled();          // obligatorio (.cursorrules)
error InvalidZKProof();              // proof fallida / tampered / mismatch
error InvalidOrderCommitment();      // zero / duplicado / no registrado
error InvalidNoteCommitment();       // nota cero / duplicada (Fase 2)
error TreeFull();                    // Merkle de saldos lleno (Fase 2)
error UnknownBalanceRoot();          // raíz de saldo no histórica
error InsufficientShieldedBalance(); // saldo apantallado insuficiente (si se chequea on-chain)
error InvalidSettlement();           // montos / notas inconsistentes
error ZeroAddress();
error Unauthorized();                // admin / darkPool
error EthTransferFailed();
error TokenTransferFailed();
error InvalidDepositAmount();        // msg.value / amount inconsistente (Fase 2)
```

Obligatorios del módulo: `OrderAlreadyFilled()`, verificación ZK de match, settlement atómico, commitments ciegos.

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta: *“autorizo Fase N”*. |
| **Entrega** | Al cerrar: checklist de aceptación + archivos tocados. |
| **Bloqueo** | Alcance nuevo → documentar y esperar nueva autorización. |
| **TDD** | En fases de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + Node/Circom + estructura | ✅ Completada | ✅ Autorizada |
| 1 | Errors + Hasher + OrderCommitment + BlindOrderBook | ✅ Completada | ✅ Autorizada |
| 2 | ShieldedVault (depósito + roots) | ✅ Completada | ✅ Autorizada |
| 3 | Circuito Circom `MatchOrders` + scripts | ✅ Completada | ✅ Autorizada |
| 4 | `Groth16Verifier` + fixtures | ⏳ Pendiente | ❌ No autorizada |
| 5 | `DarkPool.submitOrder` + `executeMatch` + settlement | ⏳ Pendiente | ❌ No autorizada |
| 6 | Suite seguridad: replay / mismatch / tampered | ⏳ Pendiente | ❌ No autorizada |
| 7 | Gas + Deploy + NatSpec / cierre v1 | ⏳ Pendiente | ❌ No autorizada |

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry + toolchain ZK ✅

**Objetivo:** repo compilable + toolchain Circom/SnarkJS documentada.

1. Scaffold Foundry (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`).
2. Dependencias: `forge-std`, OpenZeppelin v5.
3. Carpetas `src/{verifiers,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas}`, `circuits/`, `scripts/`, `script/`, `test/fixtures/`.
4. `package.json` con `snarkjs` / utilidades; `.env.example`; stub + smoke test; `README.md`.

**Criterio de salida:** `forge build` y `forge test` en verde; README con prereqs Circom.

**Hecho (2026-09-15):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir = false`, fuzz `runs = 1000`, RPC `mainnet` / `sepolia`, `fs_permissions` a fixtures).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencias en `lib/` (gitignored): `forge-std` + OpenZeppelin **v5.2.0** (copiadas del módulo 17).
- Carpetas `src/{verifiers,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas,fixtures/match}`, `circuits/`, `scripts/`, `script/`, `zkeys/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + remapping IERC20 + fuzz 1000).
- Stub `script/Deploy.s.sol` (Fase 7), stubs Node `scripts/{compile-circuit,generate-proof,export-verifier}.mjs`.
- `package.json` + `npm install` (`snarkjs`, `circomlib`, `circomlibjs`, `poseidon-solidity`); `.env.example`; `README.md` + `circuits/README.md`.
- Circom **2.1.9** verificado en PATH.
- `forge build` OK; `forge test` → **3 PASS** (fuzz 1000).

---

### Fase 1 — Errors + Hasher + OrderCommitment + BlindOrderBook ✅

**Objetivo:** commitments de orden y registro ciego on-chain.

1. TDD: `hashOrder(price, amount, side, salt)`; submit commitment; rechazo zero/duplicado.
2. `PoseidonT3` + `OrderCommitment` vía `IHasher`.
3. `DarkPoolErrors.sol` con errores del §5 (incl. `OrderAlreadyFilled`).
4. Estructura mínima de `BlindOrderBook` / mapping de commitments vivos.

**Criterio de salida:** tests de commitment + book en verde.

**Hecho (2026-09-15):**
- `src/errors/DarkPoolErrors.sol` — 10 custom errors (incl. `OrderAlreadyFilled`).
- `src/interfaces/IHasher.sol` — `hashLeftRight` + `hashOrder`.
- `src/libraries/PoseidonT3.sol` — Poseidon 2-inputs (poseidon-solidity MIT, pragma `0.8.24`).
- `src/libraries/OrderCommitment.sol` — `Poseidon(Poseidon(price,amount), Poseidon(side,salt))`; `SIDE_BUY=0` / `SIDE_SELL=1`.
- `src/PoseidonHasher.sol` — wrapper IHasher alineado a Circom.
- `src/mocks/MockHasher.sol` — keccak anidado para tests rapidos del book.
- `src/BlindOrderBook.sol` — `submitOrder` / `isLive` / `liveOrders` / `orderNullifiers` + `_consumeOrder` internal.
- `test/helpers/BlindOrderBookHarness.sol` — expone consume para tests.
- Tests: `DarkPoolErrors.t.sol`, `OrderCommitment.t.sol`, `BlindOrderBook.t.sol` (fuzz 1000).
- Stub `Placeholder` eliminado.
- **`forge test` → 19 PASS**.

---

### Fase 2 — ShieldedVault ✅

**Objetivo:** depósitos apantallados y raíz de saldos.

1. TDD: deposit token/ETH → note commitment; `balanceRoot` actualizada.
2. Nullifiers de nota (preparación para settlement).
3. CEI + transient reentrancy; custom errors de transfer.

**Criterio de salida:** unit + fuzz de depósitos en verde.

**Hecho (2026-09-15):**
- `DarkPoolErrors`: +`InvalidNoteCommitment`, `TreeFull`, `InvalidDepositAmount` (13 errores).
- `TransientReentrancyGuard` (EIP-1153 Cancun).
- `MerkleTreeWithHistory` — insert, ring 30 roots, `isKnownRoot` (adaptado a DarkPoolErrors).
- `IShieldedVault` + `ShieldedVault`: deposit ETH (`token=0`) / ERC-20; `balanceRoot`; `noteNullifiers`; `applySettlement` (solo `darkPool`).
- `setDarkPool` one-shot; CEI: notes+insert antes de `safeTransferFrom`.
- `MockERC20` para tests.
- Tests: `ShieldedVault.t.sol` — ETH/ERC-20, TreeFull, roots historicas, settlement nullifiers, fuzz 1000.
- **`forge test` → 38 PASS**.

---

### Fase 3 — Circuito Circom + scripts de proof ✅

**Objetivo:** circuito de match reproducible.

1. `matchOrders.circom`: BUY ≥ SELL, commitments Poseidon, nullifiers, binding a root/exec.
2. Scripts: compile → witness → prove (Groth16) → export calldata/fixtures.
3. Documentar ptau de lab y orden de señales públicas; artefactos en `circuits/build/` ignorados.

**Criterio de salida:** proof de lab generada; señales públicas documentadas.

**Hecho (2026-09-15):**
- Circom **2.1.9**: `circuits/matchOrders.circom` + `merkleTree.circom`.
- Compilacion: **4782** constraints, **7** public inputs, **26** private.
- Relaciones: OrderCommit anidado (= Solidity), nullifier `Poseidon(salt, side)`, notas Merkle bajo `balanceRoot`, rangos precio/monto (`GreaterEqThan(64)`).
- Scripts: `compile-circuit.mjs`, `generate-proof.mjs` (ptau lab **power-14**).
- Fixtures: `test/fixtures/match/{input,proof,public,verification_key}.json` — `snarkjs.verify = true`.
- Docs: `circuits/README.md` (orden de señales publicas).
- **`forge test` → 38 PASS** (sin regresion).

---

### Fase 4 — Verifier on-chain + fixtures

**Objetivo:** `Groth16Verifier` integrable desde Foundry.

1. Export / adaptar `Groth16Verifier.sol` (`pragma 0.8.24`).
2. Wrapper `IVerifier` + `MockVerifier` para unit tests.
3. Fixtures en `test/fixtures/match/` consumibles por tests Solidity.

**Criterio de salida:** test de pairing válida + proof inválida → revert.

---

### Fase 5 — DarkPool match + settlement

**Objetivo:** match ZK atómico con anti-double-fill.

1. Tests primero: match válido; nullifier marcado; vault settle.
2. Orden CEI: commitments vivos → nullifiers libres → root → proof → marcar → settle.
3. Binding: señales públicas deben coincidir con args de `executeMatch`.

**Criterio de salida:** e2e con fixture real o mock verifier + settlement correcto.

---

### Fase 6 — Matriz de seguridad (tests del módulo)

| Tipo | Qué valida |
|------|------------|
| ZK Match Execution | Settlement atómico con proofs BUY/SELL válidos |
| Order Nullifier Replay | Segundo match → `OrderAlreadyFilled` |
| Price Mismatch | BUY < SELL / rango inválido → `InvalidZKProof` |
| Tampered Proof | Proof o commitments alterados → `InvalidZKProof` |

**Criterio de salida:** `MatchExecution`, `OrderNullifierReplay`, `PriceMismatch`, `TamperedProof` en verde.

---

### Fase 7 — Gas + Deploy + hardening

**Objetivo:** profiling y cierre v1.

1. Gas: Poseidon commitment updates vs Groth16 pairing; snapshot / `doc/GAS.md` (si se autoriza crear).
2. `Deploy.s.sol` + NatSpec completo.
3. Actualizar diagramas / planificación a “implementado”.
4. Opcional: `doc/SWC-AUDIT.md` estilo módulos previos.

**Criterio de salida:** suite completa en verde; módulo v1 listo para cierre.

---

## 8. Modelo criptográfico (v1)

### Order commitment y nullifier

```text
orderCommitment = Poseidon(Poseidon(price, amount), Poseidon(side, salt))
orderNullifier  = Poseidon(salt, side)              // SIDE_BUY=0, SIDE_SELL=1
noteCommitment  = Poseidon(noteAmount, noteSecret)
```

El proof demuestra:

1. Conocimiento de params que abren `buyCommitment` y `sellCommitment`.
2. `buyPrice >= sellPrice` y `sellPrice <= execPrice <= buyPrice`.
3. `execAmount` acotado por amounts de orden y de notas apantalladas.
4. Membership de ambas notas bajo `balanceRoot`.
5. Binding a nullifiers públicos (anti-replay).

### Señales públicas (v1 — orden fijo)

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

Alineado exactamente: `matchOrders.circom` ↔ `DarkPool.executeMatch` (Fase 5) ↔ fixtures.

---

## 9. Criterios de aceptación globales (v1)

- [ ] Pragma fijo `0.8.24` en todos los contratos.
- [ ] Órdenes solo como commitments Poseidon (params ocultos hasta match).
- [ ] `orderNullifiers` + `OrderAlreadyFilled`.
- [ ] Verificación Groth16 on-chain del match (precio, saldos, rango).
- [ ] Settlement atómico en `ShieldedVault`.
- [ ] Tests: match OK, nullifier replay, price mismatch, tampered proof.
- [ ] NatSpec + custom errors + CEI / reentrancy.
- [ ] Circom/SnarkJS documentados; secretos/ptau/zkey no versionados.
- [ ] Documentación (`doc/`) alineada al código final + GAS (+ SWC opcional).

---

## 10. Próximo paso

**Fase 3** ✅ cerrada.

Para continuar, responde: **autorizo Fase 4**.
