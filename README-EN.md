# 21 — Privacy-Preserving Dark Pools & ZK Order Books

Institutional dark pool with blind orders (Poseidon), Groth16 matching, and atomic settlement in a shielded vault. Solidity `0.8.24` + Foundry + Circom/SnarkJS.

**Status:** Phases **0–7** ✅ (module v1 closed).  
**Suite:** `forge test` → **74 PASS**.

## Docs

| File | Contents |
|------|----------|
| [`doc/README-EN.md`](./doc/README-EN.md) | Documentation index |
| [`doc/planificacion-EN.md`](./doc/planificacion-EN.md) | Phases, architecture, criteria |
| [`doc/diagrama-de-clases-EN.md`](./doc/diagrama-de-clases-EN.md) | UML (real API) |
| [`doc/diagrama-de-flujo-EN.md`](./doc/diagrama-de-flujo-EN.md) | Commit / match / settle |
| [`doc/flujograma-EN.md`](./doc/flujograma-EN.md) | End-to-end cycle |
| [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) | SWC-100–136 matrix |
| [`doc/GAS-EN.md`](./doc/GAS-EN.md) | Poseidon vs Groth16 + snapshot |
| [`doc/DECISIONES-Y-LOGICA-EN.md`](./doc/DECISIONES-Y-LOGICA-EN.md) | Technical decisions, logic, and gas |
| [`circuits/README.md`](./circuits/README.md) | `MatchOrders(4)` circuit + signals |
| [`portfolio/index.html`](./portfolio/index.html) | Portfolio landing page (ES/EN) |

## Stack

| Layer | Technology |
|-------|------------|
| Contracts | Solidity `0.8.24` (fixed pragma) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std, OpenZeppelin v5.2 in `lib/` |
| Circuits | Circom 2.1.9 + SnarkJS Groth16 / bn128 |
| Hash | Poseidon (`PoseidonT3` / circomlib) |
| Security | `orderNullifiers`, `OrderAlreadyFilled`, `InvalidZKProof` |

## Foundry setup

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencies (already in `lib/`; reinstall if needed):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

## Circom / SnarkJS setup

1. **Node.js** >= 18  
2. **Circom** >= 2.1 (`cargo install --git https://github.com/iden3/circom.git --tag v2.1.9 circom`)  
3. `npm install`

```bash
export PATH="$HOME/.cargo/bin:$PATH"
npm run compile:circuit   # → circuits/build/
npm run generate:proof    # lab ptau + fixtures
npm run export:verifier   # → src/verifiers/Groth16Verifier.sol
```

**Do not commit:** `*.ptau`, `*.zkey`, `circuits/build/` (see `.gitignore`).

## Local deploy

```bash
anvil   # in another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `.env.example` (`PRIVATE_KEY`, `MERKLE_TREE_LEVELS`, `POOL_TOKEN`).

## Gas and security

```bash
forge test --match-contract DarkPoolGasTest --gas-report
forge snapshot --match-contract DarkPoolGasTest
```

| Doc | Summary |
|-----|---------|
| [`doc/GAS-EN.md`](./doc/GAS-EN.md) | Poseidon ~18k · Groth16 verify ~229k · e2e ~2.4M |
| [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) | 0 vulnerable · 5 informational |

## Governance

**Module v1 closed** (phases 0–7). Extensions (Next.js, depth 20, ceremony) require new authorization.
