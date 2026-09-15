# 21 — Privacy-Preserving Dark Pools & ZK Order Books

Dark pool institucional con órdenes ciegas (Poseidon), match Groth16 y settlement atómico en vault apantallado. Solidity `0.8.24` + Foundry + Circom/SnarkJS.

**Estado:** Fases **0–4** ✅ · Fases **5–7** ⏳  
**Suite:** `forge test` → **46 PASS**.

## Docs

| Archivo | Contenido |
|---------|-----------|
| [`doc/README.md`](./doc/README.md) | Índice de documentación |
| [`doc/planificacion.md`](./doc/planificacion.md) | Fases, arquitectura, criterios |
| [`doc/diagrama-de-clases.md`](./doc/diagrama-de-clases.md) | UML |
| [`doc/diagrama-de-flujo.md`](./doc/diagrama-de-flujo.md) | Commit / match / settle |
| [`doc/flujograma.md`](./doc/flujograma.md) | Ciclo e2e |
| [`circuits/README.md`](./circuits/README.md) | Circuito `MatchOrders(4)` + señales |

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std, OpenZeppelin v5.2 en `lib/` |
| Circuitos | Circom 2.1.9 + SnarkJS Groth16 / bn128 |
| Hash | Poseidon (`PoseidonT3` / circomlib) — Fase 1+ |
| Seguridad | `orderNullifiers`, `OrderAlreadyFilled`, `InvalidZKProof` |

## Setup Foundry

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencias (ya en `lib/`; reinstalar si hace falta):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

## Setup Circom / SnarkJS

1. **Node.js** >= 18  
2. **Circom** >= 2.1 (`cargo install --git https://github.com/iden3/circom.git --tag v2.1.9 circom`)  
3. `npm install`

```bash
export PATH="$HOME/.cargo/bin:$PATH"
npm run compile:circuit   # → circuits/build/
npm run generate:proof    # ptau lab + fixtures
npm run export:verifier   # → src/verifiers/Groth16Verifier.sol
```

**No versionar:** `*.ptau`, `*.zkey`, `circuits/build/` (ver `.gitignore`).

## Deploy local

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `.env.example` (`PRIVATE_KEY`, `MERKLE_TREE_LEVELS`, `POOL_TOKEN`).

## Gobernanza de fases

No se avanza de fase sin autorización explícita. Ver [`doc/planificacion.md`](./doc/planificacion.md).
