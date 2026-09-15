/**
 * Compila `circuits/matchOrders.circom` → r1cs / wasm / sym en `circuits/build/`.
 * Uso: `npm run compile:circuit`
 *
 * Prereq: circom >= 2.1 en PATH.
 */
import { spawnSync } from "node:child_process";
import { mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const buildDir = join(root, "circuits", "build");
const circuit = join(root, "circuits", "matchOrders.circom");

mkdirSync(buildDir, { recursive: true });

const circom = process.env.CIRCOM_PATH || "circom";
console.log(`[compile] ${circom} --version`);
const ver = spawnSync(circom, ["--version"], { encoding: "utf8" });
if (ver.status !== 0) {
  console.error("circom no encontrado. Instala v2.1.9 y asegurate de que este en PATH.");
  process.exit(1);
}
process.stdout.write(ver.stdout || ver.stderr);

if (!existsSync(circuit)) {
  console.error(`[compile] falta ${circuit}`);
  process.exit(1);
}

console.log(`[compile] compiling ${circuit}`);
const r = spawnSync(
  circom,
  [circuit, "--r1cs", "--wasm", "--sym", "-o", buildDir, "-l", join(root, "node_modules")],
  { encoding: "utf8", cwd: root },
);
process.stdout.write(r.stdout || "");
process.stderr.write(r.stderr || "");
if (r.status !== 0) {
  process.exit(r.status ?? 1);
}

const wasm = join(buildDir, "matchOrders_js", "matchOrders.wasm");
const r1cs = join(buildDir, "matchOrders.r1cs");
if (!existsSync(wasm) || !existsSync(r1cs)) {
  console.error("[compile] faltan artefactos wasm/r1cs");
  process.exit(1);
}
console.log("[compile] OK:", { r1cs, wasm });
