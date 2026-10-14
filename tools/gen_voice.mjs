// Genera le battute dei conduttori con ElevenLabs v3. Ogni file viene creato UNA volta sola:
// se l'mp3 esiste già lo salta (i crediti sono contati). Senza --go stampa solo la lista e i caratteri.
// Uso: node --env-file=.env tools/gen_voice.mjs [--go] [id ...]  (con degli id genera solo quelli)
// Ogni conduttore ha voce e account suoi: le voci Voice Design non si condividono tra account.
import { readFileSync, writeFileSync, existsSync } from "node:fs";

const DIR = "assets/voice/";
const STABILITY = 0.0; // v3: 0 = Creative (più espressiva), 0.5 = Natural, 1 = Robust
const CONDUTTORI = [
  // Tony Scintilla: voce "Showman" (Voice Design, it-IT, acuta, buffa) sul 1° account
  { testi: "lines.json", voce: "3VzNnwkFFVwgyrMZQoCZ", chiave: "ELEVENLABS_API_KEY" },
  // Gilda Lampo: voce "Showoman" (Voice Design, lucida e ironica) sul 2° account
  { testi: "gilda.json", voce: "T873QAvlWY1Yvb7OiSO8", chiave: "ELEVENLABS_API_KEY2" },
];

const lines = CONDUTTORI.flatMap((c) =>
  existsSync(DIR + c.testi) ? Object.entries(JSON.parse(readFileSync(DIR + c.testi, "utf8"))).map(([id, t]) => [id, t, c]) : []);
const doppi = lines.map(([id]) => id).filter((id, i, a) => a.indexOf(id) !== i);
if (doppi.length) throw new Error("id ripetuti tra i file dei conduttori: " + doppi.join(" ")); // gli mp3 stanno nella stessa cartella

const only = process.argv.slice(2).filter((a) => !a.startsWith("--"));
const todo = lines.filter(([id]) => !existsSync(DIR + id + ".mp3") && (!only.length || only.includes(id)));
for (const c of CONDUTTORI) {
  const mie = todo.filter(([, , x]) => x === c);
  for (const [id, t] of mie) console.log(id.padEnd(12), t);
  if (mie.length) console.log(`  → ${c.testi}: ${mie.length} da generare, ${mie.reduce((n, [, t]) => n + t.length, 0)} caratteri (${c.chiave})\n`);
}
console.log(`${todo.length} da generare in totale (${lines.length - todo.length} già fatti)`);
if (!process.argv.includes("--go")) process.exit(0);

for (const [id, text, c] of todo) {
  const key = process.env[c.chiave];
  if (!key) throw new Error(c.chiave + " mancante");
  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${c.voce}?output_format=mp3_44100_64`, {
    method: "POST",
    headers: { "xi-api-key": key, "Content-Type": "application/json" },
    body: JSON.stringify({ text, model_id: "eleven_v3", voice_settings: { stability: STABILITY } }),
  });
  if (!res.ok) { console.error(id, res.status, await res.text()); process.exit(1); } // si ferma al primo errore
  writeFileSync(DIR + id + ".mp3", Buffer.from(await res.arrayBuffer()));
  console.log("ok", id);
}
