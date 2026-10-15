// Verifica che i titoli Wikipedia in `fonte` esistano. Lento di proposito (429).
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
const PREFIX = 'https://it.wikipedia.org/wiki/';
const UA = { 'User-Agent': 'Quizzone-check/1.0 (progetto personale)' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const titolo = (u) => decodeURIComponent(u.slice(PREFIX.length)).replace(/_/g, ' ');

const map = new Map(); // titolo -> [id]
for (const t of readdirSync('domande')) for (const f of readdirSync(join('domande', t))) {
  if (!f.endsWith('.json')) continue;
  for (const q of JSON.parse(readFileSync(join('domande', t, f), 'utf8'))) {
    if (!q.fonte?.startsWith(PREFIX)) { console.log('fonte anomala', q.id, q.fonte); process.exitCode = 1; continue; }
    const k = titolo(q.fonte);
    (map.get(k) ?? map.set(k, []).get(k)).push(q.id);
  }
}
const titoli = [...map.keys()];
const mancanti = [];
for (let i = 0; i < titoli.length; i += 50) {
  if (i) await sleep(5500);
  const blocco = titoli.slice(i, i + 50);
  const url = 'https://it.wikipedia.org/w/api.php?action=query&format=json&redirects=1&titles=' + encodeURIComponent(blocco.join('|'));
  let res;
  for (let tentativo = 0; tentativo < 4; tentativo++) { // 429 = limite temporaneo: aspetta (Retry-After o 60 s) e riprova
    res = await fetch(url, { headers: UA, signal: AbortSignal.timeout(15000) });
    if (res.status !== 429 || tentativo === 3) break;
    const attesa = Math.min(Number(res.headers.get('retry-after')) || 60, 300);
    console.error(`429 al blocco ${i / 50 + 1}: riprovo tra ${attesa} s`);
    await sleep(attesa * 1000);
  }
  let j;
  try { if (res.status !== 200) throw 0; j = await res.json(); } catch { console.error('STOP: risposta', res.status, 'non valida'); process.exit(2); }
  const norm = new Map((j.query.normalized ?? []).map((n) => [n.from, n.to]));
  const redir = new Map((j.query.redirects ?? []).map((n) => [n.from, n.to]));
  const miss = new Set(Object.values(j.query.pages).filter((p) => 'missing' in p).map((p) => p.title));
  for (const t of blocco) {
    let x = norm.get(t) ?? t; x = redir.get(x) ?? x;
    if (miss.has(x)) mancanti.push(t);
  }
}
for (const t of mancanti) console.log('MANCANTE', t, map.get(t).join(','));
console.log(`${titoli.length} titoli, ${mancanti.length} mancanti`);
if (mancanti.length) process.exit(1);
