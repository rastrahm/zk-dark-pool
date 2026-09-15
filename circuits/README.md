# Circuitos Circom — ZK Dark Pool (modulo 21)

**Estado Fase 3:** `MatchOrders(4)` compilado + fixtures Foundry. Docs: [`../doc/README.md`](../doc/README.md).

## matchOrders.circom

| Item | Valor |
|------|-------|
| Template | `MatchOrders(4)` — depth lab = 4 (16 hojas) |
| Hash | Poseidon (circomlib), alineado a `OrderCommitment.sol` |
| Proof system | Groth16 / bn128 |
| Constraints | **4782** |
| Public inputs | **7** |

### Senales publicas (orden fijo)

| # | Nombre | Uso on-chain |
|---|--------|--------------|
| 0 | `buyCommitment` | Orden BUY viva en BlindOrderBook |
| 1 | `sellCommitment` | Orden SELL viva |
| 2 | `buyNullifier` | Anti double-fill BUY |
| 3 | `sellNullifier` | Anti double-fill SELL |
| 4 | `balanceRoot` | Debe pasar `isKnownBalanceRoot` |
| 5 | `execAmount` | Monto ejecutado |
| 6 | `execPrice` | Precio de ejecucion |

### Privadas

Ordenes: `buyPrice`, `buyAmount`, `buySalt`, `sellPrice`, `sellAmount`, `sellSalt`  
Notas: `buyNoteAmount`, `buyNoteSecret`, `sellNoteAmount`, `sellNoteSecret`  
Paths: `buyPathElements[4]`, `buyPathIndices[4]`, `sellPathElements[4]`, `sellPathIndices[4]`

### Relaciones

```text
orderCommitment = Poseidon(Poseidon(price, amount), Poseidon(side, salt))
orderNullifier  = Poseidon(salt, side)              // SIDE_BUY=0, SIDE_SELL=1
noteCommitment  = Poseidon(noteAmount, noteSecret)

buyPrice >= sellPrice
sellPrice <= execPrice <= buyPrice
execAmount <= buyAmount, sellAmount, buyNoteAmount, sellNoteAmount
MerklePoseidon(buyNote)  == balanceRoot
MerklePoseidon(sellNote) == balanceRoot
```

## Comandos

```bash
export PATH="$HOME/.cargo/bin:$PATH"

npm run compile:circuit   # → circuits/build/
npm run generate:proof    # ptau lab pot14 + fixtures test/fixtures/match/
npm run export:verifier   # Fase 4 → src/verifiers/Groth16Verifier.sol
```

### Ptau (lab)

Por defecto se genera un **ptau local inseguro** (`pot14_final_lab.ptau`, power 14) en `circuits/build/` si no existe. Solo laboratorio (4782 constraints > 2^12).

```bash
PTAU_PATH=/ruta/a/tu.ptau npm run generate:proof
PTAU_POWER=14 npm run generate:proof   # default
```

**Nunca** versionar `.ptau` ni `.zkey` de produccion.

### Cambiar profundidad

1. Editar `component main ... = MatchOrders(N);` en `matchOrders.circom`
2. `LEVELS=N npm run generate:proof` y (Fase 4) `npm run export:verifier`
3. Deploy vault/pool con `MERKLE_TREE_LEVELS=N`

## Artefactos

| Ruta | Git |
|------|-----|
| `circuits/build/` | ignorado |
| `test/fixtures/match/` | versionable (Foundry) |
| `src/verifiers/Groth16Verifier.sol` | Fase 4 |
