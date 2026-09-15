/**
 * Exporta Groth16Verifier.sol (pragma 0.8.24) + fixture Solidity-friendly.
 * Uso: `npm run export:verifier`
 *
 * Requiere: circuits/build/matchOrders_final.zkey (generar con npm run generate:proof).
 */
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as snarkjs from "snarkjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const buildDir = join(root, "circuits", "build");
const zkey = join(buildDir, "matchOrders_final.zkey");
const outSol = join(root, "src", "verifiers", "Groth16Verifier.sol");
const fixturesDir = join(root, "test", "fixtures", "match");
const proofFixture = join(fixturesDir, "proof.json");

function run(cmd, args) {
  const r = spawnSync(cmd, args, { encoding: "utf8", cwd: root });
  if (r.stdout) process.stdout.write(r.stdout);
  if (r.stderr) process.stderr.write(r.stderr);
  if (r.status !== 0) {
    throw new Error(`${cmd} ${args.join(" ")} failed (${r.status})`);
  }
}

function patchVerifier(source) {
  let s = source;
  s = s.replace(/pragma solidity\s+[^;]+;/, "pragma solidity 0.8.24;");

  if (!s.includes("IVerifier")) {
    s = s.replace(
      "contract Groth16Verifier {",
      'import {IVerifier} from "../interfaces/IVerifier.sol";\n\n' +
        "/// @notice Verifier Groth16 generado por snarkJS (GPL-3.0) — VK del circuito MatchOrders(4).\n" +
        "contract Groth16Verifier is IVerifier {",
    );
  }

  // MatchOrders: 7 senales publicas.
  s = s.replace(
    /function verifyProof\(\s*uint\[2\] calldata _pA,\s*uint\[2\]\[2\] calldata _pB,\s*uint\[2\] calldata _pC,\s*uint\[7\] calldata _pubSignals\s*\) public view returns \(bool\)/,
    "function verifyProof(\n" +
      "        uint256[2] calldata _pA,\n" +
      "        uint256[2][2] calldata _pB,\n" +
      "        uint256[2] calldata _pC,\n" +
      "        uint256[7] calldata _pubSignals\n" +
      "    ) public view override returns (bool)",
  );

  // Fallback por si snarkjs emite uint256 ya.
  s = s.replace(
    /function verifyProof\(\s*uint256\[2\] calldata _pA,\s*uint256\[2\]\[2\] calldata _pB,\s*uint256\[2\] calldata _pC,\s*uint256\[7\] calldata _pubSignals\s*\) public view returns \(bool\)/,
    "function verifyProof(\n" +
      "        uint256[2] calldata _pA,\n" +
      "        uint256[2][2] calldata _pB,\n" +
      "        uint256[2] calldata _pC,\n" +
      "        uint256[7] calldata _pubSignals\n" +
      "    ) public view override returns (bool)",
  );

  return s;
}

function toHex(v) {
  return "0x" + BigInt(v).toString(16).padStart(64, "0");
}

async function writeSolidityFixture() {
  if (!existsSync(proofFixture)) {
    console.warn("[export] no proof.json — omito solidity_proof.json");
    return;
  }
  const fix = JSON.parse(readFileSync(proofFixture, "utf8"));
  const { proof, publicSignals } = fix;

  const solidity = {
    a: [toHex(proof.pi_a[0]), toHex(proof.pi_a[1])],
    b: [
      [toHex(proof.pi_b[0][1]), toHex(proof.pi_b[0][0])],
      [toHex(proof.pi_b[1][1]), toHex(proof.pi_b[1][0])],
    ],
    c: [toHex(proof.pi_c[0]), toHex(proof.pi_c[1])],
    input: publicSignals.map(toHex),
    signalOrder: fix.signalOrder,
    levels: fix.levels,
  };

  const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
  solidity.calldata = calldata;

  mkdirSync(fixturesDir, { recursive: true });
  const out = join(fixturesDir, "solidity_proof.json");
  writeFileSync(out, JSON.stringify(solidity, null, 2));
  console.log("[export] wrote", out);
}

async function main() {
  if (!existsSync(zkey)) {
    console.error("[export] falta zkey. Ejecuta: npm run generate:proof");
    process.exit(1);
  }

  mkdirSync(dirname(outSol), { recursive: true });
  const snarkjsBin = join(root, "node_modules", ".bin", "snarkjs");
  const rawPath = join(buildDir, "Groth16Verifier_raw.sol");
  run(snarkjsBin, ["zkey", "export", "solidityverifier", zkey, rawPath]);

  const raw = readFileSync(rawPath, "utf8");
  const patched = patchVerifier(raw);
  writeFileSync(outSol, patched);
  console.log("[export] wrote", outSol);

  await writeSolidityFixture();
  console.log("[export] OK");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
