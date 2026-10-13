// Mock del Worker (PLAN, sezione Server). Uso: node tools/mock_api.mjs [cartella-domande]  (porta 8787)
import { createServer } from "node:http";
import { readFileSync, appendFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { carica } from "./domande_check.mjs";

let files = carica(process.argv[2] ?? "domande");
if (!files.length) files = carica(fileURLToPath(new URL("./fixtures/buone", import.meta.url)));
const domande = files.flatMap((f) => JSON.parse(readFileSync(f.path, "utf8")));
const ids = new Set(domande.map((q) => q.id));
const LOG = join(tmpdir(), "quizzone_esiti_mock.jsonl");
const TOKEN = process.env.QUIZZONE_ADMIN_TOKEN ?? "mock";
const versione = 1; // il mock non modifica mai le domande
console.log(`mock: ${domande.length} domande, log in ${LOG}`);

const rispondi = (res, code, obj) => { res.writeHead(code, { "content-type": "application/json" }); res.end(JSON.stringify(obj)); };
const intIn = (v, a, b) => Number.isInteger(v) && v >= a && v <= b;

createServer((req, res) => {
  const { pathname } = new URL(req.url, "http://x");
  if (req.method === "GET" && pathname === "/v1/versione") return rispondi(res, 200, { versione, totale: domande.length });
  if (req.method === "GET" && pathname === "/v1/domande") return rispondi(res, 200, { versione, domande });
  if (req.method !== "POST" || !(["/v1/esiti", "/v1/segnala"].includes(pathname) || pathname.startsWith("/v1/admin/"))) return rispondi(res, 404, { errore: "non trovato" });

  const chunks = []; let n = 0, troppo = false;
  req.on("data", (c) => { n += c.length; if (n > 65536) troppo = true; else chunks.push(c); });
  req.on("end", () => {
    if (troppo) return rispondi(res, 400, { errore: "troppo grande" });
    if (pathname.startsWith("/v1/admin/")) {
      if (req.headers.authorization !== `Bearer ${TOKEN}`) return rispondi(res, 401, { errore: "non autorizzato" });
      return rispondi(res, 200, { ok: true });
    }
    let b; try { b = JSON.parse(Buffer.concat(chunks).toString()); } catch { return rispondi(res, 400, { errore: "JSON non valido" }); }
    if (pathname === "/v1/segnala") {
      if (!ids.has(b?.id) || !["errata", "ambigua", "altro"].includes(b?.motivo)) return rispondi(res, 400, { errore: "dati non validi" });
      appendFileSync(LOG, JSON.stringify({ segnala: b }) + "\n");
      return rispondi(res, 200, { ok: true });
    }
    const ok = typeof b?.partita === "string" && b.partita && Array.isArray(b.esiti) && b.esiti.length >= 1 && b.esiti.length <= 60 &&
      b.esiti.every((e) => ids.has(e?.id) && intIn(e.giocatori, 1, 8) && intIn(e.giuste, 0, e.giocatori));
    if (!ok) return rispondi(res, 400, { errore: "esiti non validi" });
    appendFileSync(LOG, JSON.stringify({ partita: b.partita, esiti: b.esiti }) + "\n");
    rispondi(res, 200, { ok: true });
  });
}).listen(8787);
