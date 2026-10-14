// Cerca effetti CC0 su Freesound, scarica 3 anteprime per effetto e crea una pagina per ascoltarle.
// Uso: node --env-file=.env tools/sfx_cerca.mjs <cartella di uscita> [nome...]
import fs from 'fs';
import path from 'path';

const CERCHE = {  // nome in assets/audio/sfx -> [ricerca, durata minima, durata massima]
  buzz: ['game show buzzer', 0.2, 2], correct: ['correct answer quiz', 0.2, 2.5], wrong: ['wrong answer buzzer', 0.2, 2.5],
  tick: ['clock tick', 0.1, 1.5], tick_fast: ['ticking', 0.5, 4], whoosh: ['whoosh', 0.2, 1.5],
  pop: ['pop ui', 0.05, 1], applause: ['audience applause cheer', 2, 7], aww: ['aww crowd', 0.5, 5],
  drumroll: ['drum roll', 1.5, 5], fanfare: ['fanfare victory', 1, 6], explosion: ['cartoon explosion', 0.5, 3],
  cash: ['cash register', 0.3, 2.5], boing: ['cartoon boing', 0.2, 2], lock: ['button click lock', 0.05, 1],
  rise: ['riser whoosh up', 0.8, 3],
};
const k = process.env.FREESOUND_API_KEY;
const out = process.argv[2];
if (!k || !out) { console.log('uso: node --env-file=.env tools/sfx_cerca.mjs <cartella> [nome...]'); process.exit(1); }
const nomi = process.argv.length > 3 ? process.argv.slice(3) : Object.keys(CERCHE);
fs.mkdirSync(out, { recursive: true });
const righe = [];
for (const n of nomi) {
  const [q, dmin, dmax] = CERCHE[n];
  const u = `https://freesound.org/apiv2/search/text/?query=${encodeURIComponent(q)}&filter=${encodeURIComponent(`license:"Creative Commons 0" duration:[${dmin} TO ${dmax}]`)}&sort=downloads_desc&fields=id,name,username,duration,url,previews&page_size=3&token=${k}`;
  const r = await fetch(u, { signal: AbortSignal.timeout(20000) });
  if (!r.ok) { console.log(n, 'HTTP', r.status); continue; }
  const celle = [];
  for (const [i, s] of (await r.json()).results.entries()) {
    const f = `${n}_${i + 1}.mp3`;
    const a = await fetch(s.previews['preview-hq-mp3'], { signal: AbortSignal.timeout(20000) });
    fs.writeFileSync(path.join(out, f), Buffer.from(await a.arrayBuffer()));
    fs.appendFileSync(path.join(out, 'fonti.tsv'), `${f}\t${s.id}\t${s.name}\t${s.username}\t${s.url}\n`);
    celle.push(`<td><b>${i + 1}</b> ${s.duration.toFixed(1)} s<br><audio controls src="${f}"></audio><br><small>${s.name}</small></td>`);
  }
  const att = path.resolve('assets/audio/sfx', n + '.ogg');
  const ora = fs.existsSync(att) ? `<audio controls src="file:///${att.replace(/\\/g, '/')}"></audio>` : '(nuovo)';
  righe.push(`<tr><th>${n}</th><td>${ora}</td>${celle.join('')}</tr>`);
  console.log(n, celle.length);
  await new Promise((ok) => setTimeout(ok, 1100));  // limite Freesound: 60 richieste al minuto
}
fs.writeFileSync(path.join(out, 'index.html'), `<!doctype html><meta charset="utf-8"><title>Effetti</title>
<style>body{font-family:sans-serif;background:#1B0B3A;color:#FFF4DC}td,th{padding:8px;vertical-align:top}audio{width:220px}</style>
<table><tr><th>effetto</th><th>attuale</th><th colspan="3">Freesound (CC0)</th></tr>${righe.join('')}</table>`);
