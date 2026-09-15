# Circuitos — Módulo 21: ZK Dark Pool

Circuito objetivo v1: **`MatchOrders`** (`matchOrders.circom`) — Fase 3.

## Prerrequisitos

- Node.js >= 18
- Circom >= 2.1 (`cargo install --git https://github.com/iden3/circom.git --tag v2.1.9 circom`)
- `npm install` en la raíz del módulo

## Scripts (stubs en Fase 0)

```bash
npm run compile:circuit   # Fase 3
npm run generate:proof    # Fase 3
npm run export:verifier   # Fase 4 → src/verifiers/Groth16Verifier.sol
```

## Artefactos

| Ruta | Versionar |
|------|-----------|
| `circuits/build/` | No (gitignored) |
| `*.ptau` / `*.zkey` | No |
| `test/fixtures/match/` | Sí (fixtures de lab) |

Señales públicas y constraints se documentan al cerrar Fase 3.
