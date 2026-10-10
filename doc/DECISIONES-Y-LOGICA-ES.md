# Decisiones técnicas, lógica y gas — Módulo 21 ZK Dark Pool

Documento de diseño para entender **qué se construyó, por qué, cómo fluye y dónde se puede mejorar el gas**.  
Alcance: v1 cerrado (fases 0–7). Sync: 2026-09-15 · `forge test` → **74 PASS**.

Relacionados: [`planificacion-ES.md`](./planificacion-ES.md) · [`GAS-ES.md`](./GAS-ES.md) · [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md) · [`diagrama-de-flujo-ES.md`](./diagrama-de-flujo-ES.md).

---

## 1. Qué problema resuelve

Un dark pool institucional necesita:

1. Que **precio / tamaño / lado** no se filtren on-chain al publicar la orden.
2. Que un match solo sea válido si se demuestra (sin revelar los límites) que BUY ≥ SELL, hay saldo y el precio de ejecución está en rango.
3. Que no se pueda **doble-ejecutar** la misma orden (double-fill).
4. Que el settlement sea **atómico** entre notas apantalladas.

La v1 resuelve eso con: **Poseidon commitments** + **Groth16 MatchOrders** + **nullifiers** + **ShieldedVault**.

---

## 2. Decisiones técnicas (y por qué)

### 2.1 Stack y constraints

| Decisión | Elección | Motivo |
|----------|----------|--------|
| Compilador | `pragma solidity 0.8.24` fijo | Suite: sin floating pragma; overflow checks nativos |
| Tooling | Foundry | Tests, fuzz ≥1000, gas snapshot, Deploy |
| ZK | Circom 2.1.9 + SnarkJS **Groth16 / bn128** | Estándar EVM (`ecPairing`); tooling maduro |
| Hash de commitment | **Poseidon** (T3, 2-inputs) | Alineado a circomlib; barato en circuito vs keccak |
| EVM | Cancun | Transient storage (`tstore`) para reentrancy |
| Frontend | Fuera de v1 | Alcance acotado a contratos + circuito |

### 2.2 Commitment de orden (ciego)

```text
orderCommitment = Poseidon(Poseidon(price, amount), Poseidon(side, salt))
orderNullifier  = Poseidon(salt, side)   // SIDE_BUY=0, SIDE_SELL=1
```

| Decisión | Motivo |
|----------|--------|
| Poseidon **anidado** (3 hashes), no un Poseidon de 4 inputs | Misma forma que Circom con `Poseidon(2)`; evita divergencia Solidity ↔ circuito |
| On-chain solo se publica el `bytes32` commitment | No hay `price`/`amount`/`side` en storage ni en eventos de submit |
| `salt` privado | Anti-preimagen y unicidad del nullifier |
| Nullifier derivado de `(salt, side)` | Binding al lado; anti double-fill sin revelar price/amount |

**Tradeoff:** 3× Poseidon on-chain si alguien verifica el hash en Solidity (~65k). Off-chain (matcher) es gratuito.

### 2.3 Libro ciego (`BlindOrderBook` ⊂ `DarkPool`)

| Decisión | Motivo |
|----------|--------|
| `DarkPool` **hereda** `BlindOrderBook` | Un solo contrato para submit + match; `orderNullifiers` / `liveOrders` compartidos |
| `liveOrders[commitment] = true` al submit | Lookup O(1); no CLOB público con precios |
| Nullifiers separados de commitments | Una orden puede “dejar de estar live” y quedar marcada por nullifier de forma explícita |
| Sin cola de matching on-chain | Matching es **off-chain** (matcher/relayer); on-chain solo verifica y settle |

### 2.4 Vault apantallado (`ShieldedVault`)

| Decisión | Motivo |
|----------|--------|
| Notas Merkle + `balanceRoot` | Membership en el circuito sin revelar qué hoja |
| `ROOT_HISTORY_SIZE = 30` | Roots recientes válidas (estilo Tornado); acota storage |
| Depth lab = **4** (`MatchOrders(4)`) | 16 hojas; proofs/fixtures rápidos; **no** es tamaño producción |
| `setDarkPool` **one-shot** | Solo el pool autorizado llama `applySettlement` |
| Settlement **proof-based** (sin EIP-712 en v1) | El binding lo da Groth16 + nullifiers; menos superficie de firma |
| ETH (`token=0`) o ERC-20 | Un vault = un asset |
| Change notes opcionales (`newBuyNote` / `newSellNote`) | Permite “vuelto” sin revelar montos residuales on-chain |

### 2.5 Circuito `MatchOrders`

| Decisión | Motivo |
|----------|--------|
| 7 públicos fijos | Contrato y fixtures alineados; sin calldata ambiguo |
| Prueba: BUY≥SELL, rango execPrice, montos, Merkle notes | Cumple `.cursorrules` sin filtrar límites |
| Groth16 (no Plonk/Halo2) | Verifier snarkJS listo; pairing nativo EVM |
| Ptau lab power-14 | Suficiente para 4782 constraints; **no** ceremonia mainnet |
| Depth parametrizado `MatchOrders(N)` | Debe coincidir con `MERKLE_TREE_LEVELS` en deploy |

### 2.6 `executeMatch` — orden CEI

Orden intencional en `DarkPool.executeMatch`:

1. Commitments vivos y distintos  
2. Nullifiers libres y distintos  
3. `isKnownBalanceRoot`  
4. `verifyProof` (pairing caro)  
5. Effects: `liveOrders=false` + `orderNullifiers=true` (**sin** re-llamar `_consumeOrder`)  
6. `vault.applySettlement`  
7. Evento `MatchExecuted`

| Decisión | Motivo |
|----------|--------|
| Checks **baratos antes** del pairing | Fail rápido sin pagar ~229k de `ecPairing` |
| Marcar nullifiers **antes** del settle | CEI: si settle revierte, toda la tx revierte (incluido el mark) |
| Transient lock **por contrato** (`tstore xor address()`) | Permite DarkPool → Vault en la misma tx sin falso “reentrancy” ni SSTORE del guard clásico |
| `publicInputs[7]` embebidos | Binding: el caller no puede mentir commitments/nullifiers/root/exec sin invalidar la proof |

### 2.7 Seguridad / producto

| Decisión | Motivo |
|----------|--------|
| Custom errors (`DarkPoolErrors`) | Gas + claridad; sin strings |
| Matriz SWC-100–136 | Cierre estilo suite (módulo 20) |
| Tests defensivos (replay, mismatch, tampered) | “Ataque” = revert; sin PoCs ofensivos |
| `via_ir = false` | PoseidonT3 + IR no compila en tiempo práctico |

---

## 3. Lógica que sigue el sistema

### 3.1 Vista de capas

```text
┌───────────── Off-chain ─────────────┐     ┌──────────── On-chain ────────────┐
│ Traders: price, amount, side, salt  │     │ BlindOrderBook / DarkPool        │
│ → commitment Poseidon               │────►│ submitOrder(commitment)          │
│ Deposit noteAmount + noteSecret     │────►│ ShieldedVault.deposit → Merkle   │
│ Matcher: witness + groth16.prove    │────►│ executeMatch(proof, 7 públicos)  │
│                                     │     │   → verify → nullify → settle    │
└─────────────────────────────────────┘     └──────────────────────────────────┘
```

### 3.2 Ciclo feliz (paso a paso)

1. **Deposit**  
   Trader deposita ETH/ERC-20 con `noteCommitment = Poseidon(amount, secret)`.  
   El vault inserta la hoja y actualiza `balanceRoot`.

2. **Submit order**  
   Off-chain: `commitment = Poseidon(Poseidon(price,amount), Poseidon(side,salt))`.  
   On-chain: `submitOrder(commitment)` → `liveOrders[commitment]=true`.  
   Nadie ve price/amount/side.

3. **Match off-chain**  
   Matcher conoce BUY y SELL privados. Si `buyPrice >= sellPrice`, elige `execPrice` en rango y `execAmount` acotado.  
   Genera proof `MatchOrders` que además demuestra que ambas notas están bajo el `balanceRoot` actual (o histórico conocido).

4. **executeMatch on-chain**  
   Relayer/matcher envía proof + 7 públicos + change notes.  
   El contrato valida estado + proof; marca nullifiers; el vault gasta nullifiers de nota e inserta change notes.

5. **Estado final**  
   Órdenes ya no live; nullifiers de orden y de nota gastados; nueva raíz; evento público con commitments/nullifiers/exec (no con límites privados).

### 3.3 Qué demuestra el proof (sin revelarlo)

```text
conocimiento de (price, amount, side, salt) BUY y SELL
  → abren buyCommitment / sellCommitment
buyPrice >= sellPrice
sellPrice <= execPrice <= buyPrice
execAmount ≤ amounts de orden y de notas
Merkle(buyNote) y Merkle(sellNote) == balanceRoot
nullifiers públicos = Poseidon(salt, side) de cada lado
```

### 3.4 Caminos de fallo (resumen)

| Condición | Error |
|-----------|--------|
| Commitment cero / no live / BUY==SELL | `InvalidOrderCommitment` |
| Nullifier cero / ya usado / BUY nullifier == SELL | `OrderAlreadyFilled` |
| Root no en historial | `UnknownBalanceRoot` |
| Pairing o signals inválidos | `InvalidZKProof` |
| Settle sin ser `darkPool` | `Unauthorized` |
| Deposit amount / `msg.value` inconsistente | `InvalidDepositAmount` |

### 3.5 Qué **no** hace la v1 (deliberado)

- Matching engine on-chain / CLOB con precios visibles  
- Partial fills multi-leg complejos  
- EIP-712 payout (solo proof-based)  
- Depth 20 / ceremony productiva  
- Frontend Next.js  
- Multi-asset cross-pool  

---

## 4. Gas: qué hay hoy y cómo mejorar

### 4.1 Baseline v1 (orientativo)

| Path | Gas aprox. |
|------|------------|
| `submitOrder` | ~29 k |
| `PoseidonT3.hash` (1×) | ~18 k |
| `hashOrder` (3×) | ~65 k |
| `Groth16Verifier.verifyProof` | **~229 k** |
| `executeMatch` (mock verifier) | ~135 k |
| e2e Groth16 (test: deposits + match) | ~2.4 M |

Dominantes: **pairing Groth16** + **Poseidon × niveles Merkle** en depósitos.

### 4.2 Ya aplicado en v1

- Checks baratos antes de pairing  
- Mark nullifiers sin re-SLOAD (`_consumeOrder` no se re-ejecuta en el hot path)  
- Cache de immutables `vault` / `verifier` en stack  
- Transient reentrancy (sin SSTORE de guard)  
- Custom errors  
- `_insertChangeNote` sin chequeo duplicado de capacidad  
- `optimizer_runs = 10_000`

### 4.3 Mejoras posibles (post-v1)

Ordenadas por impacto / esfuerzo. Ninguna es “gratis”: todas tienen tradeoff.

#### A. Alto impacto (cambian el modelo ZK o el árbol)

| Mejora | Idea | Tradeoff |
|--------|------|----------|
| **Proofs recursivas / agregación** | Un proof que agrega N matches → un solo pairing on-chain | Circuito más complejo; otra toolchain |
| **Otro sistema de prueba** (Plonk + KZG, Halo2, etc.) | Menos o distinto coste de verificación | Verifier distinto; menos “plug & play” snarkJS |
| **Depth Merkle menor en lab vs prod** | Depth 4 ya es lab; en prod depth 20 duele en **deposit**, no tanto en verify | Anonymity set vs gas de insert |
| **Incremental Merkle / sparse tree** | Menos hashes por deposit si se cachean paths | Más complejidad de estado |
| **Batch deposits** | Varias hojas en una tx amortizan overhead | UX y circuit binding más difíciles |

> El pairing Groth16 (~229k) **no** se reduce con micro-opts Solidity. Hay que cambiar el esquema de prueba o verificar menos veces (batch/recursivo).

#### B. Medio impacto (Solidity / calldata / storage)

| Mejora | Idea | Tradeoff |
|--------|------|----------|
| **Pack de públicos en menos words** | Hoy `uint256[7]`; empaquetar flags/montos pequeños | Complica binding circuito ↔ contrato |
| **Eventos más lean** | Menos indexed / menos campos en `MatchExecuted` | Peor indexación off-chain |
| **No duplicar `liveOrders` + nullifier** | Solo nullifier como fuente de verdad | UX: no se puede “ver” fácilmente órdenes vivas |
| **Precomputar zeros Merkle** | Ya típico en árboles Tornado-like; revisar si hay SLOAD evitables | Depende de implementación actual |
| **Verifier Yul más agresivo** | Hand-tuned pairing path | Mantenimiento; riesgo vs snarkJS export |

#### C. Bajo impacto / ya cerca del límite

| Mejora | Nota |
|--------|------|
| Más `immutable` / menos storage reads | Hot path de match ya cachea vault/verifier |
| `unchecked` en índices Merkle | Solo si bounds ya validados; ahorro menor vs Poseidon |
| `via_ir = true` | Hoy **bloqueado** por PoseidonT3; requeriría hasher distinto o split de compilación |
| Optimizer runs > 10k | Retornos decrecientes; medir con snapshot |

#### D. Coste “de producto” (no es bug de gas)

- Relayer paga el gas del match (~pairing + settle).  
- Traders pagan deposit (Poseidon × depth).  
- Rate-limit / mempool off-chain reduce griefing de pairing inválido (SWC-126 informativo).

### 4.4 Qué **no** conviene “optimizar” a ciegas

- Quitar checks antes del pairing → fails caros y peor UX.  
- Bajar seguridad del nullifier para ahorrar un SSTORE.  
- Depth 20 sin re-exportar VK / fixtures → proofs inválidas.  
- Forzar `via_ir` sin reemplazar PoseidonT3 → build roto.

---

## 5. Mapa mental rápido (contratos)

| Artefacto | Rol |
|-----------|-----|
| `PoseidonHasher` / `OrderCommitment` | Hash alineado a Circom |
| `BlindOrderBook` | Commitments vivos + nullifiers de orden |
| `DarkPool` | Orquesta submit + executeMatch |
| `ShieldedVault` | Notas, roots, settlement |
| `Groth16Verifier` | Pairing MatchOrders |
| `VerifierGate` | Helper `InvalidZKProof` (tests) |
| `Deploy.s.sol` | hasher → verifier → vault → pool → `setDarkPool` |

---

## 6. Cómo verificar en local

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test
forge test --match-contract DarkPoolGasTest --gas-report
forge snapshot --match-contract DarkPoolGasTest
```

Circuitos:

```bash
npm run compile:circuit
npm run generate:proof
npm run export:verifier
```

---

## 7. Resumen en una frase

**Off-chain** se ocultan y se prueban las condiciones del trade; **on-chain** solo se registran commitments, se verifica Groth16, se marcan nullifiers y se asienta el vault — con gas dominado por el pairing y ya micro-optimizado en el path de match; las grandes mejoras de gas exigen batching, otro proving system o un Merkle más eficiente, no más tweaks de SLOAD.
