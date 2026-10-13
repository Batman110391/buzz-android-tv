// Genera le battute del presentatore con ElevenLabs v3. Ogni file viene creato UNA volta sola:
// se l'mp3 esiste già lo salta (i crediti sono contati). Senza --go stampa solo la lista e i caratteri.
// Uso: node tools/gen_voice.mjs [--go] [id ...]  (con degli id genera solo quelli)   (chiave in ELEVENLABS_API_KEY)
import { readFileSync, writeFileSync, existsSync } from "node:fs";

const VOICE = "3VzNnwkFFVwgyrMZQoCZ"; // "Lello Splendore": voce creata con Voice Design (it-IT, acuta, buffa)
const DIR = "assets/voice/";
const STABILITY = 0.0; // v3: 0 = Creative (più espressiva), 0.5 = Natural, 1 = Robust

const lines = Object.entries(JSON.parse(readFileSync(DIR + "lines.json", "utf8")));

const only = process.argv.slice(2).filter((a) => !a.startsWith("--"));
const todo = lines.filter(([id]) => !existsSync(DIR + id + ".mp3") && (!only.length || only.includes(id)));
const chars = todo.reduce((n, [, t]) => n + t.length, 0);
for (const [id, t] of todo) console.log(id.padEnd(12), t);
console.log(`\n${todo.length} da generare, ${chars} caratteri (${lines.filter(([id]) => existsSync(DIR + id + ".mp3")).length} già fatti)`);
if (!process.argv.includes("--go")) process.exit(0);

const key = process.env.ELEVENLABS_API_KEY;
if (!key) throw new Error("ELEVENLABS_API_KEY mancante");
for (const [id, text] of todo) {
  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${VOICE}?output_format=mp3_44100_64`, {
    method: "POST",
    headers: { "xi-api-key": key, "Content-Type": "application/json" },
    body: JSON.stringify({ text, model_id: "eleven_v3", voice_settings: { stability: STABILITY } }),
  });
  if (!res.ok) { console.error(id, res.status, await res.text()); process.exit(1); } // si ferma al primo errore
  writeFileSync(DIR + id + ".mp3", Buffer.from(await res.arrayBuffer()));
  console.log("ok", id);
}
