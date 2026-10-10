# Gas optimization — ZK Dark Pool & Blind Order Book

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract DarkPoolGasTest --gas-report
forge snapshot --match-contract DarkPoolGasTest
```

**Baseline date:** 2026-09-15 (Phase 7 / v1 closeout)  
**Snapshot:** `.gas-snapshot` (`test/gas/DarkPool.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = false` (PoseidonT3), solc `0.8.24`, EVM Cancun  
**Suite:** `forge test` → **74 PASS**  
**Docs sync:** diagrams and planning aligned with this baseline.

---

## Operation baseline (snapshot test gas)

| Path | Gas (snapshot) | Notes |
|------|----------------|-------|
| `testGas_submitOrder` | **29 447** | Live mapping only |
| `testGas_deposit_mockHasher` | **99 531** | Mock Merkle insert |
| `testGas_executeMatch_mock` | **134 548** | MockVerifier (~2.6k) + settle |
| `testGas_poseidonHashOrder` | **64 711** | 3× nested PoseidonT3 |
| `testGas_verifyProof_groth16` | **340 223** | Test wrapper + pairing |
| `testGas_e2e_groth16_executeMatch` | **2 424 075** | Poseidon deposits + real match |

### Gas report (on-chain function)

| Function | Min | Median / Avg | Notes |
|----------|-----|--------------|-------|
| `DarkPool.executeMatch` | ~138 k | ~253 k | Mock vs Groth16 |
| `MockVerifier.verifyProof` | **2 651** | — | Cheap baseline |
| `Groth16Verifier.verifyProof` | **228 808** | — | Dominant in e2e |
| `PoseidonT3.hash` | **18 229** | — | Per 2-input hash |
| `PoseidonHasher.hashLeftRight` | ~19 k | — | Merkle node |

> E2E cost is dominated by the **Groth16 pairing** (~229k) + **Poseidon** per Merkle level on deposits; pool opts reduce SLOAD/SSTORE on the match path.

---

## Applied optimizations (Phase 7)

| Technique | Where | Effect |
|-----------|-------|--------|
| Per-contract transient reentrancy (`xor address`) | `TransientReentrancyGuard` | Nested DarkPool→Vault without SSTORE or false reentrancy |
| Cache immutables on the stack | `DarkPool.executeMatch` | Fewer repeated vault/verifier reads |
| Consume without re-SLOAD | After checks, direct mark (no `_consumeOrder`) | Avoids 4 redundant SLOADs |
| Cheap checks before pairing | live / nullifier / root → then `verifyProof` | Cheap fails don’t pay the full pairing |
| Fixed arrays + packed indices | `MerkleTreeWithHistory` | Inherited from module 17 |
| `_insertChangeNote` without duplicate capacity check | `ShieldedVault` | `_insert` already checks TreeFull |
| Custom errors | `DarkPoolErrors` | vs `require` strings |
| `optimizer_runs = 10_000` | `foundry.toml` | Hot path inlining |

### Poseidon vs Groth16 (indicative)

| Operation | Approx. gas | Ratio |
|-----------|-------------|-------|
| `PoseidonT3.hash` (1×) | 18 229 | 1× |
| `hashOrder` (3× Poseidon) | ~55–65 k | ~3× |
| `Groth16Verifier.verifyProof` | **228 808** | ~12.5× one Poseidon |
| `executeMatch` mock | ~135 k | Book + settle overhead |
| `executeMatch` e2e (test) | ~2.4 M | Deposits + pairing + book |

### Tradeoffs

- **`via_ir = false`:** PoseidonT3 + IR does not compile in practical time.
- **Lab depth 4:** insert scales with `levels`; prod depth 20 ⇒ more Poseidon on deposit.
- **Groth16:** not optimizable on-chain without changing the proving system / recursive proofs.

---

## Deploy

```bash
anvil   # in another terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `PRIVATE_KEY`, `MERKLE_TREE_LEVELS` (default 4), `POOL_TOKEN` (default `address(0)` = ETH). See `.env.example`.

**Important:** `MERKLE_TREE_LEVELS` must match `MatchOrders(N)` and the VK embedded in `Groth16Verifier`.

---

## References

- [`foundry.toml`](../foundry.toml)
- [`test/gas/DarkPool.gas.t.sol`](../test/gas/DarkPool.gas.t.sol)
- [`.gas-snapshot`](../.gas-snapshot)
- [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md)
