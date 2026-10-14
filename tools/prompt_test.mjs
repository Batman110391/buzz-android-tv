// Banco di prova dei prompt di generazione/verifica domande (PLAN.md §4).
// Mock (default):  QUIZZONE_MOCK=1 node tools/prompt_test.mjs
// Reale:           node --env-file=.env tools/prompt_test.mjs --n 8   (con QUIZZONE_MOCK=0 nel .env)
import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { carica, controlla, norm } from "./domande_check.mjs";

const qui = (p) => fileURLToPath(new URL(p, import.meta.url));
const leggi = (p) => readFileSync(qui(p), "utf8");
const MOCK = process.env.QUIZZONE_MOCK !== "0";
const ia = process.argv.indexOf("--n");
const N = ia > 0 ? Number(process.argv[ia + 1]) : MOCK ? 40 : 8;
const TIMEOUT_MS = 90_000;
const PREF = { classica: "cl", lampo: "la", ordine: "or" };
const COMBO = [["classica", "natura", 2], ["lampo", "cucina", 1], ["ordine", "scienza", 2]];
const PER_COMBO = Math.max(1, Math.round(N / 10));

// PRNG con seme: il mock è riproducibile
let seme = 20261014;
const rnd = () => { seme = (seme + 0x6d2b79f5) | 0; let t = Math.imul(seme ^ (seme >>> 15), 1 | seme); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const mescola = (a) => { const r = [...a]; for (let i = r.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [r[i], r[j]] = [r[j], r[i]]; } return r; };

// ---------- dotazione ----------
const dotazione = carica("domande").flatMap((f) => JSON.parse(readFileSync(f.path, "utf8")));
const fattiEsistenti = new Set(dotazione.map((q) => norm(q.fatto)));
const testiEsistenti = new Set(dotazione.map((q) => norm(q.domanda ?? q.criterio)));

// ---------- IA reali ----------
async function http(nome, url, opts) {
  const r = await fetch(url, { ...opts, signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (r.status === 429 || r.status >= 500) throw new Error(`${nome}: HTTP ${r.status} (limite o errore del servizio): mi fermo, riprova più tardi.\n${(await r.text()).slice(0, 300)}`);
  if (!r.ok) throw new Error(`${nome}: HTTP ${r.status}\n${(await r.text()).slice(0, 300)}`);
  return r.json();
}
const jsonDa = (testo) => { const m = String(testo).match(/\{[\s\S]*\}/); if (!m) throw new Error(`risposta senza JSON: "${String(testo).slice(0, 200)}"`); return JSON.parse(m[0]); };
const richiedi = (v) => { if (!process.env[v]) throw new Error(`manca ${v} (node --env-file=.env ... e QUIZZONE_MOCK=0)`); return process.env[v]; };

const S = (type, extra = {}) => ({ type, ...extra });
function schemaGemini(tipo) {
  const testo = S("STRING"), lista = S("ARRAY", { items: testo });
  const props = { tipo: testo, categoria: testo, difficolta: S("INTEGER"), curiosita: testo, fatto: testo, fonte: testo };
  const req = ["tipo", "categoria", "difficolta", "curiosita", "fatto", "fonte"];
  if (tipo === "ordine") { Object.assign(props, { criterio: testo, elementi: lista, valori: lista }); req.push("criterio", "elementi", "valori"); }
  else { Object.assign(props, { domanda: testo, risposte: lista }); req.push("domanda", "risposte"); }
  return S("OBJECT", { properties: { domande: S("ARRAY", { items: S("OBJECT", { properties: props, required: req }) }) }, required: ["domande"] });
}
const FORMATO = {
  classica: "`domanda` (max 90 caratteri), `risposte`: 4 stringhe (max 26 caratteri ciascuna), la giusta per prima.",
  lampo: "Domanda che si capisce in 2 secondi: `domanda` max 55 caratteri, `risposte`: 4 stringhe max 16 caratteri, la giusta per prima.",
  ordine: "`criterio` (max 50 caratteri, es. \"Eventi, dal più antico al più recente\"), `elementi`: 4 stringhe max 22 caratteri GIÀ nell'ordine giusto, `valori`: 4 stringhe max 14 caratteri (il dato per ciascun elemento, nello stesso ordine).",
};

async function generaReale(tipo, cat, diff, n) {
  const fatti = [...new Set(dotazione.filter((q) => q.categoria === cat).map((q) => q.fatto))].join("; ");
  const prompt = leggi("prompts/genera.md").replaceAll("{{N}}", n).replaceAll("{{TIPO}}", tipo).replaceAll("{{CATEGORIA}}", cat)
    .replaceAll("{{DIFFICOLTA}}", diff).replaceAll("{{FORMATO}}", FORMATO[tipo]).replaceAll("{{FATTI}}", fatti);
  const modello = process.env.GEMINI_MODEL || "gemini-2.5-flash";
  const r = await http("Gemini", `https://generativelanguage.googleapis.com/v1beta/models/${modello}:generateContent`, {
    method: "POST",
    headers: { "content-type": "application/json", "x-goog-api-key": richiedi("GEMINI_API_KEY") },
    body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { responseMimeType: "application/json", responseSchema: schemaGemini(tipo), temperature: 0.8 } }),
  });
  return jsonDa(r.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}").domande ?? [];
}

function generaMock(tipo, cat, diff, n) {
  return (JSON.parse(leggi("fixtures/mock_genera.json"))[`${tipo}/${cat}/${diff}`] ?? []).slice(0, n);
}

// ---------- verificatore ----------
// presentazione senza la giusta: perm[i] = indice originale dell'elemento mostrato in posizione i
function presenta(q) {
  const perm = mescola([0, 1, 2, 3]);
  const lista = q.tipo === "ordine" ? q.elementi : q.risposte;
  const mostrate = perm.map((i) => lista[i]);
  const corpo = q.tipo === "ordine" ? `Tipo: ordine\nCriterio: ${q.criterio}\nElementi:` : `Tipo: ${q.tipo}\nDomanda: ${q.domanda}\nRisposte:`;
  return { perm, testo: `${corpo}\n${mostrate.map((x, i) => `${i}. ${x}`).join("\n")}` };
}

async function verificaReale(q, p) {
  const prompt = leggi("prompts/verifica.md").replace("{{DOMANDA}}", p.testo);
  for (let t = 0; t < 3; t++) { // il modello free a volte risponde con contenuto vuoto: riprova
    const r = await http("OpenRouter", "https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${richiedi("OPENROUTER_API_KEY")}` },
      body: JSON.stringify({ model: richiedi("OPENROUTER_MODEL"), messages: [{ role: "user", content: prompt }], temperature: 0 }),
    });
    const c = r.choices?.[0]?.message?.content;
    if (c && c.trim()) return jsonDa(c);
  }
  throw new Error("OpenRouter: risposta vuota per 3 volte di fila");
}

const mockV = JSON.parse(leggi("fixtures/mock_verifica.json"));
const hash = (s) => [...s].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7);
function verificaMock(q, p) {
  const giusta = p.perm.indexOf(0);
  const ordineGiusto = [0, 1, 2, 3].map((k) => p.perm.indexOf(k));
  let t = mockV.pulita, vera = null;
  if (q._difetto && !q._sfugge) { t = mockV.per_difetto[q._difetto]; vera = q._vera; }
  else if (mockV.respinte_gen.includes(q.fatto) || (!q._difetto && hash(q.id) % mockV.ogni_n === 0)) t = mockV.dubbia;
  const out = { scelta: t.scelta_vera && vera != null ? p.perm.indexOf(vera) : giusta, sicurezza: t.sicurezza, difficolta: q.difficolta, problemi: t.problemi };
  if (q.tipo === "ordine") { out.ordine = [...ordineGiusto]; if (t.scelta_vera) [out.ordine[0], out.ordine[1]] = [out.ordine[1], out.ordine[0]]; out.scelta = out.ordine[0]; }
  return out;
}

// ---------- valutazione: regole meccaniche (domande_check) + verificatore ----------
function riempi(q, i) {
  const base = { id: `${PREF[q.tipo]}-${q.categoria.slice(0, 3)}-${9000 + i}`, curiosita: "Curiosità di prova.", fonte: "https://it.wikipedia.org/wiki/Prova", origine: "gemini", creata: "2026-10-14" };
  return { ...base, fatto: norm(`${q.domanda ?? q.criterio} ${i}`), ...q, id: base.id };
}
async function valuta(items) {
  const completi = items.map((q, i) => riempi(q, i));
  const tmp = mkdtempSync(join(tmpdir(), "prompt_test_"));
  try {
    const gruppi = {};
    for (const q of completi) (gruppi[`${q.tipo}/${q.categoria}`] ??= []).push(Object.fromEntries(Object.entries(q).filter(([k]) => !k.startsWith("_") && !["difetto", "vera", "sfugge"].includes(k))));
    for (const [k, v] of Object.entries(gruppi)) { mkdirSync(join(tmp, k.split("/")[0]), { recursive: true }); writeFileSync(join(tmp, `${k}.json`), JSON.stringify(v)); }
    const errori = controlla(tmp).errori;
    const esiti = [];
    for (const q of completi) {
      const mecc = errori.filter((e) => e.includes(` ${q.id}:`));
      if (mecc.length) { esiti.push({ q, ok: false, schema: mecc.length, motivo: "regole: " + mecc[0].split("]")[1]?.trim() }); continue; }
      const p = presenta(q);
      const v = MOCK ? verificaMock(q, p) : await verificaReale(q, p);
      const corretta = q.tipo === "ordine" ? JSON.stringify(v.ordine) === JSON.stringify([0, 1, 2, 3].map((k) => p.perm.indexOf(k))) : v.scelta === p.perm.indexOf(0);
      const ok = corretta && v.sicurezza >= 80 && (v.problemi ?? []).length === 0;
      esiti.push({ q, ok, schema: 0, motivo: ok ? "" : !corretta ? "scelta diversa dalla giusta" : `sicurezza ${v.sicurezza} problemi [${(v.problemi ?? []).join(",")}]`, dett: ok || corretta || MOCK ? "" : `
${p.testo}
    atteso: ${q.tipo === "ordine" ? JSON.stringify([0, 1, 2, 3].map((k) => p.perm.indexOf(k))) : p.perm.indexOf(0)}  grezza: ${JSON.stringify(v)}` });
    }
    return esiti;
  } finally { rmSync(tmp, { recursive: true, force: true }); }
}

// ---------- prove ----------
const pct = (a, b) => (b ? Math.round((100 * a) / b) : 0);
const righe = [], falliti = [];
const mostraScarti = (titolo, esiti) => esiti.filter((e) => !e.ok).forEach((e) => console.log(`  ${titolo} scartata: ${e.q.id ?? e.q.fatto} (${e.motivo})${e.dett ?? ""}`));

try {
  const buoni = mescola(dotazione).slice(0, N);
  const eA = await valuta(buoni);
  const a = pct(eA.filter((e) => e.ok).length, eA.length);
  mostraScarti("(a)", eA);
  righe.push(`(a) buone accettate:   ${a}% (${eA.filter((e) => e.ok).length}/${eA.length})  soglia >= 90`); if (a < 90) falliti.push("a");

  const rotte = JSON.parse(leggi("fixtures/rotte.json"));
  const sel = mescola(rotte).slice(0, N).map((r) => ({ ...r, tipo: r.tipo, _difetto: r.difetto, _vera: r.vera, _sfugge: r.sfugge }));
  const eB = await valuta(sel);
  const b = pct(eB.filter((e) => !e.ok).length, eB.length);
  eB.filter((e) => e.ok).forEach((e) => console.log(`  (b) sfuggita: ${e.q.id} [${e.q._difetto}]`));
  righe.push(`(b) rotte scartate:    ${b}% (${eB.filter((e) => !e.ok).length}/${eB.length})  soglia >= 90`); if (b < 90) falliti.push("b");

  const prodotte = [];
  for (const [tipo, cat, diff] of COMBO) for (const q of await (MOCK ? generaMock : generaReale)(tipo, cat, diff, PER_COMBO)) prodotte.push({ ...q, tipo, categoria: cat, difficolta: diff });
  const eC = await valuta(prodotte);
  const c = pct(eC.filter((e) => e.ok).length, eC.length);
  const schema = eC.reduce((s, e) => s + e.schema, 0);
  const doppioni = prodotte.filter((q) => fattiEsistenti.has(norm(q.fatto ?? "")) || testiEsistenti.has(norm(q.domanda ?? q.criterio ?? ""))).length;
  mostraScarti("(c)", eC);
  righe.push(`(c) generate accettate: ${c}% (${eC.filter((e) => e.ok).length}/${eC.length})  soglia >= 70`);
  righe.push(`    errori di schema:  ${schema}  soglia 0`, `    doppioni:          ${doppioni}  soglia 0`);
  if (c < 70 || !prodotte.length) falliti.push("c"); if (schema) falliti.push("schema"); if (doppioni) falliti.push("doppioni");
} catch (e) {
  console.error("ERRORE:", e.message);
  process.exit(2);
}

console.log(`\nprompt_test (${MOCK ? "MOCK" : "REALE"}, n=${N})\n` + righe.join("\n"));
console.log(falliti.length ? `FALLITO: ${falliti.join(", ")}` : "ok");
process.exit(falliti.length ? 1 : 0);
