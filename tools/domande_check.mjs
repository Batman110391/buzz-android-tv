// Valida domande/<tipo>/<categoria>.json. Uso: node tools/domande_check.mjs [cartella]
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const CATEGORIE = ["geografia","storia","scienza","natura","cinema_tv","musica","sport","cucina","arte_letteratura","lingua","tecnologia","costume","videogiochi","mitologia","citazioni","strano_ma_vero","corpo_umano","tradizioni"];
const PREFISSI = { classica: "cl", lampo: "la", ordine: "or", foto: "fo", indizi: "in" };
const LIM = { classica: { domanda: 90, risposta: 26 }, lampo: { domanda: 55, risposta: 16 } };
const SENZA_ACCENTO = /\b(perche|poiche|cioe|piu|gia|puo|citta)\b/i;

export const norm = (s) => String(s).toLowerCase().normalize("NFD").replace(/\p{M}/gu, "")
  .replace(/[^\p{L}\p{N}\s]/gu, "").replace(/\s+/g, " ").trim();

const isStr = (v) => typeof v === "string" && v.trim() !== "";
const arr4 = (v) => Array.isArray(v) && v.length === 4 && v.every(isStr);

export function carica(dir) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const tipo of readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory())) {
    for (const f of readdirSync(join(dir, tipo.name)).filter((f) => f.endsWith(".json"))) {
      out.push({ tipo: tipo.name, categoria: f.slice(0, -5), file: `${tipo.name}/${f}`, path: join(dir, tipo.name, f) });
    }
  }
  return out;
}

function valida(q, tipo, cat, err) {
  const e = (codice, m) => err(q.id ?? "?", `[${codice}] ${m}`);
  if (!isStr(q.id) || !/^(cl|la|or|fo|in)-[a-z0-9]{3}-\d{4}$/.test(q.id)) e("schema", "id non nel formato <cl|la|or|fo|in>-<cat3>-<NNNN>");
  else if (!q.id.startsWith(PREFISSI[tipo] + "-") || q.id.slice(3, 6) !== cat.slice(0, 3)) e("schema", `id incoerente con tipo/categoria (${tipo}/${cat})`);
  if (q.tipo !== tipo) e("schema", `tipo "${q.tipo}" diverso dalla cartella "${tipo}"`);
  if (q.categoria !== cat) e("schema", `categoria "${q.categoria}" diversa dal file "${cat}"`);
  if (!CATEGORIE.includes(q.categoria)) e("schema", `categoria sconosciuta "${q.categoria}"`);
  if (![1, 2, 3].includes(q.difficolta)) e("schema", "difficolta deve essere 1, 2 o 3");
  if (!isStr(q.fatto) || norm(q.fatto) !== q.fatto) e("schema", "fatto mancante o non normalizzato (minuscole, senza accenti/punteggiatura)");
  if (!isStr(q.curiosita)) e("schema", "curiosita mancante");
  else if (q.curiosita.trim().length > 120) e("lunghezza", `curiosita ${q.curiosita.trim().length} > 120`);
  if (!isStr(q.fonte) || !/^https?:\/\//.test(q.fonte)) e("schema", "fonte non è un URL");
  if (!["claude", "gemini"].includes(q.origine)) e("schema", "origine deve essere claude|gemini");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(q.creata ?? "")) e("schema", "creata non è YYYY-MM-DD");
  if (!PREFISSI[tipo]) return e("schema", `tipo sconosciuto "${tipo}"`);

  const testi = [];
  if (tipo === "classica" || tipo === "lampo") {
    if (!isStr(q.domanda)) e("schema", "domanda mancante");
    else { testi.push(q.domanda); if (q.domanda.trim().length > LIM[tipo].domanda) e("lunghezza", `domanda ${q.domanda.trim().length} > ${LIM[tipo].domanda}`); }
    if (!arr4(q.risposte)) e("schema", "risposte deve avere esattamente 4 stringhe");
    else {
      testi.push(...q.risposte);
      q.risposte.forEach((r) => { if (r.trim().length > LIM[tipo].risposta) e("lunghezza", `risposta "${r}" ${r.trim().length} > ${LIM[tipo].risposta}`); });
      if (new Set(q.risposte.map(norm)).size < 4) e("regola", "risposte duplicate");
    }
  } else if (tipo === "ordine") {
    if (!isStr(q.criterio)) e("schema", "criterio mancante");
    else if (q.criterio.trim().length > 50) e("lunghezza", `criterio ${q.criterio.trim().length} > 50`);
    if (!arr4(q.elementi)) e("schema", "elementi deve avere esattamente 4 stringhe");
    else {
      q.elementi.forEach((x) => { if (x.trim().length > 22) e("lunghezza", `elemento "${x}" > 22`); });
      if (new Set(q.elementi.map(norm)).size < 4) e("regola", "elementi duplicati");
    }
    const v = Array.isArray(q.valori) ? q.valori.map((x) => (typeof x === "number" ? String(x) : x)) : null;
    if (!v || v.length !== 4 || !v.every(isStr)) e("schema", "valori deve avere esattamente 4 valori");
    else v.forEach((x) => { if (x.trim().length > 14) e("lunghezza", `valore "${x}" > 14`); });
    testi.push(q.criterio ?? "", ...(Array.isArray(q.elementi) ? q.elementi : []));
  } else if (tipo === "indizi") {
    if (!isStr(q.categoria_indizi)) e("schema", "categoria_indizi mancante");
    else if (q.categoria_indizi.trim().length > 30) e("lunghezza", `categoria_indizi ${q.categoria_indizi.trim().length} > 30`);
    const okI = Array.isArray(q.indizi) && q.indizi.length === 3 && q.indizi.every(isStr);
    if (!okI) e("schema", "indizi deve avere esattamente 3 stringhe");
    else {
      testi.push(...q.indizi);
      q.indizi.forEach((x) => { if (x.trim().length > 70) e("lunghezza", `indizio "${x}" ${x.trim().length} > 70`); if (/\bnon\b/i.test(x)) e("regola", `negazione nell'indizio "${x}"`); });
    }
    if (!arr4(q.risposte)) e("schema", "risposte deve avere esattamente 4 stringhe");
    else {
      testi.push(...q.risposte);
      q.risposte.forEach((r) => { if (r.trim().length > 26) e("lunghezza", `risposta "${r}" ${r.trim().length} > 26`); });
      if (new Set(q.risposte.map(norm)).size < 4) e("regola", "risposte duplicate");
      if (okI) {
        // la giusta (prima) non deve comparire negli indizi, né intera né con una parola di >= 4 lettere
        const ind = norm(q.indizi.join(" ")), giusta = norm(q.risposte[0]);
        if (ind.includes(giusta)) e("regola", `la risposta "${q.risposte[0]}" compare negli indizi`);
        else for (const w of giusta.split(" ").filter((w) => w.length >= 4)) if (ind.split(" ").includes(w)) e("regola", `parola "${w}" della risposta compare negli indizi`);
      }
    }
  } else if (tipo === "foto") {
    // ponytail: lunghezze foto in G3
    if (!isStr(q.immagine) || !isStr(q.autore) || !isStr(q.pagina) || !arr4(q.risposte)) e("schema", "foto: servono immagine, autore, pagina, risposte[4]");
  }

  if (isStr(q.domanda) && /\bnon\b/i.test(q.domanda)) e("regola", "negazione nella domanda");
  for (const t of testi) {
    if (/\b(tutte|nessuna)\b.*\bprecedent/i.test(t)) e("regola", `"tutte/nessuna delle precedenti" in "${t}"`);
    if (SENZA_ACCENTO.test(t)) e("regola", `accento mancante in "${t}"`);
  }
  if (Array.isArray(q.risposte)) q.risposte.forEach((r) => { if (typeof r === "string" && /[.!?]\s*$/.test(r)) e("regola", `punto finale nella risposta "${r}"`); });
}

export function controlla(dir) {
  const errori = [];
  const conteggi = { categoria: {}, tipo: {}, difficolta: {} };
  const ids = new Map(), fatti = new Map(), testi = new Map();
  const inc = (o, k) => (o[k] = (o[k] ?? 0) + 1);
  for (const f of carica(dir)) {
    let dati;
    try { dati = JSON.parse(readFileSync(f.path, "utf8")); } catch (x) { errori.push(`${f.file}: JSON non valido (${x.message})`); continue; }
    if (!Array.isArray(dati)) { errori.push(`${f.file}: deve essere un array`); continue; }
    for (const q of dati) {
      const err = (id, m) => errori.push(`${f.file} ${id}: ${m}`);
      if (!q || typeof q !== "object") { err("?", "[schema] non è un oggetto"); continue; }
      valida(q, f.tipo, f.categoria, err);
      inc(conteggi.categoria, f.categoria); inc(conteggi.tipo, f.tipo); inc(conteggi.difficolta, q.difficolta);
      if (ids.has(q.id)) err(q.id, `[id-doppio] già in ${ids.get(q.id)}`); else ids.set(q.id, f.file);
      if (isStr(q.fatto)) { const k = norm(q.fatto); if (fatti.has(k)) err(q.id, `[fatto-doppio] come ${fatti.get(k)}`); else fatti.set(k, q.id); }
      const t = norm(testoChiave(q));
      if (t) { if (testi.has(t)) err(q.id, `[testo-doppio] come ${testi.get(t)}`); else testi.set(t, q.id); }
    }
  }
  return { errori, conteggi };
}

// testo per i doppioni: in "ordine" il criterio si ripete per natura, contano anche le voci
export const testoChiave = (q) => q.domanda ?? (q.indizi ? [q.categoria_indizi ?? "", ...(Array.isArray(q.indizi) ? q.indizi : [])].join(" ") : [q.criterio ?? "", ...(Array.isArray(q.elementi) ? q.elementi : [])].join(" "));

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const { errori, conteggi } = controlla(process.argv[2] ?? "domande");
  errori.forEach((x) => console.log("ERRORE", x));
  for (const [k, v] of Object.entries(conteggi)) console.log(k + ":", JSON.stringify(v));
  console.log(errori.length ? `${errori.length} errori` : "ok");
  process.exit(errori.length ? 1 : 0);
}
