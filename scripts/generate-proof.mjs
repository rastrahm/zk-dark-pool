/**
 * Setup Groth16 (ptau lab) + genera proof + fixtures Foundry.
 * Uso: `npm run generate:proof`
 *
 * Artefactos en circuits/build/ (gitignored).
 * Fixtures en test/fixtures/match/ (versionables).
 *
 * Env:
 *   PTAU_PATH — ruta a powersOfTau (default: genera pot14 lab local si falta)
 *   LEVELS    — debe coincidir con MatchOrders(N) (default 4)
 */
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  writeFileSync,
  copyFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildPoseidon } from "circomlibjs";
import * as snarkjs from "snarkjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const buildDir = join(root, "circuits", "build");
const fixturesDir = join(root, "test", "fixtures", "match");
const LEVELS = Number(process.env.LEVELS || 4);
const PTAU_POWER = Number(process.env.PTAU_POWER || 14);

const r1cs = join(buildDir, "matchOrders.r1cs");
const wasm = join(buildDir, "matchOrders_js", "matchOrders.wasm");
const zkey = join(buildDir, "matchOrders_final.zkey");
const vkeyPath = join(buildDir, "verification_key.json");

const SIDE_BUY = 0n;
const SIDE_SELL = 1n;

mkdirSync(buildDir, { recursive: true });
mkdirSync(fixturesDir, { recursive: true });

function run(cmd, args) {
  const r = spawnSync(cmd, args, { encoding: "utf8", cwd: root });
  if (r.stdout) process.stdout.write(r.stdout);
  if (r.stderr) process.stderr.write(r.stderr);
  if (r.status !== 0) {
    throw new Error(`${cmd} ${args.join(" ")} failed (${r.status})`);
  }
}

async function ensurePtau() {
  const defaultPtau = join(buildDir, `pot${PTAU_POWER}_final_lab.ptau`);
  const ptau = process.env.PTAU_PATH || defaultPtau;
  if (existsSync(ptau)) {
    console.log("[ptau] using", ptau);
    return ptau;
  }

  console.log(`[ptau] generating local lab ptau (power ${PTAU_POWER}) via snarkjs CLI`);
  const snarkjsBin = join(root, "node_modules", ".bin", "snarkjs");
  const p0 = join(buildDir, `pot${PTAU_POWER}_0000.ptau`);
  const p1 = join(buildDir, `pot${PTAU_POWER}_0001.ptau`);
  run(snarkjsBin, ["powersoftau", "new", "bn128", String(PTAU_POWER), p0, "-v"]);
  run(snarkjsBin, [
    "powersoftau",
    "contribute",
    p0,
    p1,
    "--name=lab",
    "-v",
    "-e=lab-entropy-" + Date.now(),
  ]);
  run(snarkjsBin, ["powersoftau", "prepare", "phase2", p1, ptau, "-v"]);
  console.log("[ptau] saved", ptau);
  return ptau;
}

function toHex(f) {
  return "0x" + BigInt(f).toString(16).padStart(64, "0");
}

function poseidonHash(poseidon, inputs) {
  const F = poseidon.F;
  return F.toObject(poseidon(inputs.map((x) => F.e(x))));
}

/** Alineado a OrderCommitment.sol / OrderCommit circom. */
function orderCommitment(poseidon, price, amount, side, salt) {
  const left = poseidonHash(poseidon, [price, amount]);
  const right = poseidonHash(poseidon, [side, salt]);
  return poseidonHash(poseidon, [left, right]);
}

function orderNullifier(poseidon, salt, side) {
  return poseidonHash(poseidon, [salt, side]);
}

function noteCommitment(poseidon, noteAmount, noteSecret) {
  return poseidonHash(poseidon, [noteAmount, noteSecret]);
}

/** Arbol Merkle Poseidon alineado a MerkleTreeWithHistory on-chain. */
function buildMerkleTree(poseidon, leaves, levels) {
  const capacity = 1 << levels;
  if (leaves.length > capacity) throw new Error("too many leaves");

  const zeros = [];
  let z = 0n;
  zeros.push(z);
  for (let i = 1; i <= levels; i++) {
    z = poseidonHash(poseidon, [z, z]);
    zeros.push(z);
  }

  const layers = [];
  const layer0 = Array(capacity).fill(zeros[0]);
  for (let i = 0; i < leaves.length; i++) layer0[i] = leaves[i];
  layers.push(layer0);

  for (let lvl = 0; lvl < levels; lvl++) {
    const prev = layers[lvl];
    const next = [];
    for (let i = 0; i < prev.length; i += 2) {
      next.push(poseidonHash(poseidon, [prev[i], prev[i + 1]]));
    }
    layers.push(next);
  }

  const root = layers[levels][0];

  function path(index) {
    const pathElements = [];
    const pathIndices = [];
    let idx = index;
    for (let lvl = 0; lvl < levels; lvl++) {
      const sib = idx ^ 1;
      pathElements.push(layers[lvl][sib]);
      pathIndices.push(idx & 1);
      idx >>= 1;
    }
    return { pathElements, pathIndices };
  }

  return { root, path, zeros };
}

async function main() {
  if (!existsSync(r1cs) || !existsSync(wasm)) {
    console.log("[setup] compilando circuito primero...");
    run("node", [join(root, "scripts", "compile-circuit.mjs")]);
  }

  const ptau = await ensurePtau();

  if (!existsSync(zkey)) {
    const zkey0 = join(buildDir, "matchOrders_0000.zkey");
    console.log("[zkey] groth16 setup");
    await snarkjs.zKey.newZKey(r1cs, ptau, zkey0);
    console.log("[zkey] contribute (lab entropy)");
    await snarkjs.zKey.contribute(
      zkey0,
      zkey,
      "lab-phase2",
      "phase2-lab-entropy-" + Date.now(),
    );
  } else {
    console.log("[zkey] reusing", zkey);
  }

  const vkey = await snarkjs.zKey.exportVerificationKey(zkey);
  writeFileSync(vkeyPath, JSON.stringify(vkey, null, 2));

  const poseidon = await buildPoseidon();

  // Escenario lab: BUY @ 110, SELL @ 100, exec @ 105, amount 5
  const buyPrice = 110n;
  const buyAmount = 10n;
  const buySalt = 111111111n;
  const sellPrice = 100n;
  const sellAmount = 8n;
  const sellSalt = 222222222n;
  const execPrice = 105n;
  const execAmount = 5n;

  const buyNoteAmount = 20n;
  const buyNoteSecret = 333333333n;
  const sellNoteAmount = 15n;
  const sellNoteSecret = 444444444n;

  const buyComm = orderCommitment(poseidon, buyPrice, buyAmount, SIDE_BUY, buySalt);
  const sellComm = orderCommitment(poseidon, sellPrice, sellAmount, SIDE_SELL, sellSalt);
  const buyNull = orderNullifier(poseidon, buySalt, SIDE_BUY);
  const sellNull = orderNullifier(poseidon, sellSalt, SIDE_SELL);

  const buyNote = noteCommitment(poseidon, buyNoteAmount, buyNoteSecret);
  const sellNote = noteCommitment(poseidon, sellNoteAmount, sellNoteSecret);

  const { root, path } = buildMerkleTree(poseidon, [buyNote, sellNote], LEVELS);
  const buyPath = path(0);
  const sellPath = path(1);

  const input = {
    buyCommitment: buyComm.toString(),
    sellCommitment: sellComm.toString(),
    buyNullifier: buyNull.toString(),
    sellNullifier: sellNull.toString(),
    balanceRoot: root.toString(),
    execAmount: execAmount.toString(),
    execPrice: execPrice.toString(),
    buyPrice: buyPrice.toString(),
    buyAmount: buyAmount.toString(),
    buySalt: buySalt.toString(),
    sellPrice: sellPrice.toString(),
    sellAmount: sellAmount.toString(),
    sellSalt: sellSalt.toString(),
    buyNoteAmount: buyNoteAmount.toString(),
    buyNoteSecret: buyNoteSecret.toString(),
    sellNoteAmount: sellNoteAmount.toString(),
    sellNoteSecret: sellNoteSecret.toString(),
    buyPathElements: buyPath.pathElements.map((x) => x.toString()),
    buyPathIndices: buyPath.pathIndices.map((x) => x.toString()),
    sellPathElements: sellPath.pathElements.map((x) => x.toString()),
    sellPathIndices: sellPath.pathIndices.map((x) => x.toString()),
  };

  const inputPath = join(buildDir, "input.json");
  writeFileSync(inputPath, JSON.stringify(input, null, 2));
  console.log("[prove] generating witness + proof");

  const { proof, publicSignals } = await snarkjs.groth16.fullProve(input, wasm, zkey);
  const ok = await snarkjs.groth16.verify(vkey, publicSignals, proof);
  if (!ok) throw new Error("local verify failed");
  console.log("[prove] verified OK");
  console.log(
    "[prove] publicSignals order: buyCommitment, sellCommitment, buyNullifier, sellNullifier, balanceRoot, execAmount, execPrice",
  );
  console.log(publicSignals);

  const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
  writeFileSync(join(buildDir, "proof.json"), JSON.stringify(proof, null, 2));
  writeFileSync(join(buildDir, "public.json"), JSON.stringify(publicSignals, null, 2));
  writeFileSync(join(buildDir, "calldata.txt"), calldata);

  const signalOrder = [
    "buyCommitment",
    "sellCommitment",
    "buyNullifier",
    "sellNullifier",
    "balanceRoot",
    "execAmount",
    "execPrice",
  ];

  const fixture = {
    levels: LEVELS,
    publicSignals,
    publicInputsHex: publicSignals.map(toHex),
    proof,
    calldata,
    signalOrder,
    scenario: {
      buyPrice: buyPrice.toString(),
      sellPrice: sellPrice.toString(),
      execPrice: execPrice.toString(),
      execAmount: execAmount.toString(),
      buyCommitment: buyComm.toString(),
      sellCommitment: sellComm.toString(),
      buyNullifier: buyNull.toString(),
      sellNullifier: sellNull.toString(),
      buyNote: buyNote.toString(),
      sellNote: sellNote.toString(),
      buyLeafIndex: 0,
      sellLeafIndex: 1,
    },
  };
  writeFileSync(join(fixturesDir, "proof.json"), JSON.stringify(fixture, null, 2));
  writeFileSync(join(fixturesDir, "public.json"), JSON.stringify(publicSignals, null, 2));
  writeFileSync(join(fixturesDir, "input.json"), JSON.stringify(input, null, 2));
  copyFileSync(vkeyPath, join(fixturesDir, "verification_key.json"));

  console.log("[fixtures] wrote", fixturesDir);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
