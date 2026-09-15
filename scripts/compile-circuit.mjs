/**
 * Stub Fase 0 — compila `circuits/matchOrders.circom` (disponible desde Fase 3).
 * Uso: `npm run compile:circuit`
 *
 * Prereq: circom >= 2.1 en PATH.
 */
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const circuit = join(root, "circuits", "matchOrders.circom");

const circom = process.env.CIRCOM_PATH || "circom";
const ver = spawnSync(circom, ["--version"], { encoding: "utf8" });
if (ver.status !== 0) {
  console.error("circom no encontrado. Instala v2.1.9 y asegurate de que este en PATH.");
  process.exit(1);
}
process.stdout.write(ver.stdout || ver.stderr);

if (!existsSync(circuit)) {
  console.log(`[compile] stub Fase 0: falta ${circuit}`);
  console.log("[compile] El circuito MatchOrders se implementa en Fase 3. Nada que compilar aun.");
  process.exit(0);
}

console.error("[compile] Circuito presente pero el script completo llega en Fase 3.");
process.exit(1);
