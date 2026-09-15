# Optimización de gas — ZK Dark Pool & Blind Order Book

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract DarkPoolGasTest --gas-report
forge snapshot --match-contract DarkPoolGasTest
```

**Fecha baseline:** 2026-09-15 (Fase 7 / cierre v1)  
**Snapshot:** `.gas-snapshot` (`test/gas/DarkPool.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = false` (PoseidonT3), solc `0.8.24`, EVM Cancun  
**Suite:** `forge test` → **74 PASS**  
**Docs sync:** diagramas y planificación alineados a este baseline.

---

## Baseline operaciones (snapshot test gas)

| Path | Gas (snapshot) | Notas |
|------|----------------|-------|
| `testGas_submitOrder` | **29 447** | Solo mapping live |
| `testGas_deposit_mockHasher` | **99 531** | Merkle insert mock |
| `testGas_executeMatch_mock` | **134 548** | MockVerifier (~2.6k) + settle |
| `testGas_poseidonHashOrder` | **64 711** | 3× PoseidonT3 anidados |
| `testGas_verifyProof_groth16` | **340 223** | Test wrapper + pairing |
| `testGas_e2e_groth16_executeMatch` | **2 424 075** | Deposits Poseidon + match real |

### Gas report (función on-chain)

| Función | Min | Median / Avg | Notas |
|---------|-----|--------------|-------|
| `DarkPool.executeMatch` | ~138 k | ~253 k | Mock vs Groth16 |
| `MockVerifier.verifyProof` | **2 651** | — | Baseline barato |
| `Groth16Verifier.verifyProof` | **228 808** | — | Dominante e2e |
| `PoseidonT3.hash` | **18 229** | — | Por hash 2-inputs |
| `PoseidonHasher.hashLeftRight` | ~19 k | — | Nodo Merkle |

> El coste e2e lo dominan **pairing Groth16** (~229k) + **Poseidon** por nivel Merkle en depósitos; las opts de pool reducen SLOAD/SSTORE en el path de match.

---

## Optimizaciones aplicadas (Fase 7)

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| Transient reentrancy por contrato (`xor address`) | `TransientReentrancyGuard` | Nested DarkPool→Vault sin SSTORE ni falso reentrancy |
| Cache immutables en stack | `DarkPool.executeMatch` | Menos lectura repetida vault/verifier |
| Consume sin re-SLOAD | Tras checks, mark directo (no `_consumeOrder`) | Evita 4 SLOAD redundantes |
| Checks baratos antes de pairing | live / nullifier / root → luego `verifyProof` | Fails baratos no pagan pairing completo |
| Arrays fijos + indices packed | `MerkleTreeWithHistory` | Heredado módulo 17 |
| `_insertChangeNote` sin capacity duplicada | `ShieldedVault` | `_insert` ya valida TreeFull |
| Custom errors | `DarkPoolErrors` | vs `require` strings |
| `optimizer_runs = 10_000` | `foundry.toml` | Inlining hot paths |

### Poseidon vs Groth16 (orientativo)

| Operación | Gas aprox. | Ratio |
|-----------|------------|-------|
| `PoseidonT3.hash` (1×) | 18 229 | 1× |
| `hashOrder` (3× Poseidon) | ~55–65 k | ~3× |
| `Groth16Verifier.verifyProof` | **228 808** | ~12.5× un Poseidon |
| `executeMatch` mock | ~135 k | Overhead book+settle |
| `executeMatch` e2e (test) | ~2.4 M | Deposits + pairing + book |

### Tradeoffs

- **`via_ir = false`:** PoseidonT3 + IR no compila en tiempo práctico.
- **Depth 4 lab:** insert escala con `levels`; prod depth 20 ⇒ más Poseidon en deposit.
- **Groth16:** no optimizable on-chain sin cambiar sistema de prueba / recursive proofs.

---

## Deploy

```bash
anvil   # otra terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `PRIVATE_KEY`, `MERKLE_TREE_LEVELS` (default 4), `POOL_TOKEN` (default `address(0)` = ETH). Ver `.env.example`.

**Importante:** `MERKLE_TREE_LEVELS` debe coincidir con `MatchOrders(N)` y el VK embebido en `Groth16Verifier`.

---

## Referencias

- [`foundry.toml`](../foundry.toml)
- [`test/gas/DarkPool.gas.t.sol`](../test/gas/DarkPool.gas.t.sol)
- [`.gas-snapshot`](../.gas-snapshot)
- [SWC-AUDIT.md](./SWC-AUDIT.md)
