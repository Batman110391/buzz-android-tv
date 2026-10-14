// Musiche di sottofondo: compone MIDI (SMF tipo 1 scritto a mano), li rende con FluidSynth + soundfont GM,
// poi ffmpeg: taglio loop perfetto, -18 LUFS, .ogg stereo q4.
// Uso: node tools/musica_midi.mjs <cartellaUscita> [nome...]   (nomi: accumula, ruba)
// Env o argomenti: FLUIDSYNTH / --fluidsynth=<exe>, SOUNDFONT / --sf2=<file.sf2>. ffmpeg nel PATH.
import { spawnSync } from 'node:child_process';
import { writeFileSync, mkdirSync, existsSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';

const args = process.argv.slice(2);
const opt = (k) => args.find((a) => a.startsWith(`--${k}=`))?.slice(k.length + 3);
const pos = args.filter((a) => !a.startsWith('--'));
const FLUID = opt('fluidsynth') ?? process.env.FLUIDSYNTH;
const SF2 = opt('sf2') ?? process.env.SOUNDFONT;
const OUT = pos[0];
if (!OUT || !FLUID || !SF2) { console.error('uso: node musica_midi.mjs <out> [nome...] con FLUIDSYNTH e SOUNDFONT (env o --fluidsynth= --sf2=)'); process.exit(1); }
mkdirSync(OUT, { recursive: true });

const PPQ = 480, SR = 44100, COPIES = 3;

// ---------- utilità ----------
function rng(seed) { return () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const PC = { C: 0, 'C#': 1, Db: 1, D: 2, 'D#': 3, Eb: 3, E: 4, F: 5, 'F#': 6, Gb: 6, G: 7, 'G#': 8, Ab: 8, A: 9, 'A#': 10, Bb: 10, B: 11 };
const midi = (s) => { const m = /^([A-G][#b]?)(-?\d)$/.exec(s); return PC[m[1]] + 12 * (Number(m[2]) + 1); };
const TYPES = { maj7: [0, 4, 7, 11], m7: [0, 3, 7, 10], 7: [0, 4, 7, 10], 6: [0, 4, 7, 9], '7sus': [0, 5, 7, 10], mMaj7: [0, 3, 7, 11], m6: [0, 3, 7, 9], m7b5: [0, 3, 6, 10], '7b9': [0, 4, 7, 10, 1] };
const chord = (s) => { const [r, t] = s.split(':'); return { name: s, root: PC[r], iv: TYPES[t], pcs: TYPES[t].map((i) => (PC[r] + i) % 12) }; };
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
// pitch con la classe `pc` più vicino a `near`, dentro [lo,hi]
function nearest(pc, near, lo, hi) { let best = null; for (let p = lo; p <= hi; p++) if (p % 12 === pc && (best === null || Math.abs(p - near) < Math.abs(best - near))) best = p; return best; }
// voicing compatto: una nota per ogni intervallo (primi `k`), attorno a `center`
function voice(ch, center, lo, hi, k = 4) { return [...new Set(ch.pcs.slice(0, k).map((pc) => nearest(pc, center, lo, hi)))].sort((a, b) => a - b); }

// ---------- scrittura SMF ----------
const vl = (n) => { const b = [n & 127]; while ((n >>= 7)) b.unshift((n & 127) | 128); return b; };
const u32 = (n) => [(n >>> 24) & 255, (n >>> 16) & 255, (n >>> 8) & 255, n & 255];
function trackChunk(evs) {
  evs.sort((a, b) => a.t - b.t || a.o - b.o);
  const out = []; let last = 0;
  for (const e of evs) { out.push(...vl(e.t - last), ...e.b); last = e.t; }
  return [...Buffer.from('MTrk'), ...u32(out.length), ...out];
}
const meta = (type, data) => [0xFF, type, ...vl(data.length), ...data];

// Strumento: canale, programma, CC (7 volume, 10 pan, 91 riverbero, 93 chorus). notes: {t,d,n,v} in tick, nel giro di L tick.
function makeSong({ bpm, bars, swing, seed }) {
  const r = rng(seed), L = bars * 4 * PPQ;
  const sw = (b) => { if (!swing) return b; const f = Math.floor(b + 1e-9), x = b - f; return f + (x < 0.5 ? x * 4 / 3 : 2 / 3 + (x - 0.5) * 2 / 3); };
  const tr = [];
  const song = {
    L, bars, bpm, r,
    track(name, ch, prog, cc) { const t = { name, ch, prog, cc, notes: [] }; tr.push(t); return t; },
    // beat assoluto (0 = inizio battuta 1), durata in beat, jit = umanizzazione in tick
    add(t, beat, dur, n, v, jit = 5) {
      let t0 = Math.round(sw(beat) * PPQ) + Math.round((r() * 2 - 1) * jit);
      let t1 = Math.round(sw(beat + dur) * PPQ) + Math.round((r() * 2 - 1) * jit);
      t0 = Math.max(0, t0); t1 = Math.max(t0 + 20, t1);
      t.notes.push({ t: t0, d: t1 - t0, n, v: clamp(Math.round(v + (r() * 2 - 1) * 6), 1, 127) });
    },
    build() {
      const tempo = [];
      tempo.push({ t: 0, o: 0, b: meta(0x51, [(60e6 / bpm >> 16) & 255, (60e6 / bpm >> 8) & 255, (60e6 / bpm) & 255]) });
      tempo.push({ t: 0, o: 0, b: meta(0x58, [4, 2, 24, 8]) });
      tempo.push({ t: L * COPIES + 4 * PPQ, o: 9, b: meta(0x2F, []) });
      const chunks = [trackChunk(tempo)];
      for (const t of tr) {
        const ev = [{ t: 0, o: 0, b: meta(0x03, [...Buffer.from(t.name)]) }];
        const c = 0xB0 | t.ch;
        if (t.ch === 9) ev.push({ t: 0, o: 1, b: [0xC0 | 9, t.prog] }); else ev.push({ t: 0, o: 1, b: [0xC0 | t.ch, t.prog] });
        for (const [k, v] of Object.entries(t.cc)) ev.push({ t: 0, o: 1, b: [c, Number(k), v] });
        for (let k = 0; k < COPIES; k++) for (const n of t.notes) {
          ev.push({ t: n.t + k * L, o: 3, b: [0x90 | t.ch, n.n, n.v] });
          ev.push({ t: n.t + n.d + k * L, o: 2, b: [0x80 | t.ch, n.n, 0] });
        }
        ev.push({ t: L * COPIES + 4 * PPQ, o: 9, b: meta(0x2F, []) });
        chunks.push(trackChunk(ev));
      }
      const head = [...Buffer.from('MThd'), ...u32(6), 0, 1, 0, chunks.length, (PPQ >> 8) & 255, PPQ & 255];
      return Buffer.from([...head, ...chunks.flat()]);
    },
  };
  return song;
}

// controllo armonico: note melodiche sul battere o lunghe devono essere note dell'accordo (+9a)
function checkMelody(label, notes, chordAtBeat) {
  let bad = 0;
  for (const { beat, dur, n } of notes) {
    const onBeat = Math.abs(beat - Math.round(beat)) < 1e-6;
    if (!onBeat && dur < 1) continue;
    const c = chordAtBeat(beat), pc = n % 12;
    if (!c.pcs.includes(pc) && pc !== (c.root + 2) % 12) { bad++; console.warn(`  [armonia] ${label} beat ${beat} ${c.name}: nota ${n} (pc ${pc}) fuori accordo`); }
  }
  return bad;
}

// ---------- brano 1: accumula ----------
function accumula() {
  const bpm = 120, bars = 16;
  const s = makeSong({ bpm, bars, swing: false, seed: 11 });
  const C = chord;
  // 16 battute, 2 accordi per battuta (mezze battute)
  const prog = [
    ['C:maj7'], ['A:m7'], ['F:maj7'], ['G:7'], ['C:maj7'], ['E:m7', 'A:7'], ['D:m7'], ['G:7'],
    ['F:maj7'], ['G:6'], ['E:m7'], ['A:m7'], ['F:maj7'], ['G:7sus', 'G:7'], ['C:maj7', 'A:m7'], ['D:m7', 'G:7'],
  ].map((b) => (b.length === 1 ? [C(b[0]), C(b[0])] : [C(b[0]), C(b[1])]));
  const at = (bar, half) => prog[((bar % bars) + bars) % bars][half];
  const chordAtBeat = (beat) => at(Math.floor(beat / 4), (beat % 4) >= 2 ? 1 : 0);
  const B = (bar, step) => bar * 4 + step / 4; // beat assoluto da battuta + sedicesimo
  const half = (step) => (step >= 8 ? 1 : 0);

  const drums = s.track('Batteria', 9, 8, { 7: 108, 10: 64, 91: 28, 93: 0 });
  const bass = s.track('Basso', 0, 33, { 7: 112, 10: 64, 91: 6, 93: 0 });
  const ep = s.track('Piano elettrico', 1, 4, { 7: 82, 10: 42, 91: 45, 93: 55 });
  const brass = s.track('Ottoni', 2, 61, { 7: 92, 10: 84, 91: 55, 93: 15 });
  const trp = s.track('Tromba', 3, 56, { 7: 100, 10: 60, 91: 60, 93: 10 });
  const vib = s.track('Vibrafono', 4, 11, { 7: 62, 10: 98, 91: 70, 93: 30 });
  const str = s.track('Archi', 5, 48, { 7: 62, 10: 64, 91: 75, 93: 45 });
  const gtr = s.track('Chitarra muta', 6, 28, { 7: 66, 10: 28, 91: 25, 93: 25 });
  const saw = s.track('Lead synth', 7, 81, { 7: 70, 10: 72, 91: 55, 93: 35 });

  // --- batteria ---
  const isFillStart = (bar) => (bar === 15 ? 8 : bar === 7 ? 12 : 99);
  for (let bar = 0; bar < bars; bar++) {
    const secB = bar >= 8, odd = bar % 2 === 1, fill = isFillStart(bar);
    const D = (step, note, v, jit = 4) => { if (step < fill) s.add(drums, B(bar, step), 0.2, note, v, jit); };
    if (bar === 0 || bar === 8) s.add(drums, B(bar, 0), 1, 49, 112, 3);
    for (const k of odd ? [0, 6, 10, 13] : [0, 6, 10]) D(k, 36, k === 0 ? 112 : 96);
    D(4, 38, 108); D(12, 38, 110);
    if (secB) { D(4, 39, 70); D(12, 39, 72); }
    if (bar % 4 !== 3 || secB) { D(7, 38, 34); D(15, 38, 38); if (odd) D(9, 38, 30); }
    for (let st = 0; st < 16; st += 2) {
      const acc = [96, 62, 82, 62, 92, 62, 82, 66][st / 2];
      if (st === 14 && odd) D(14, 46, 82); else D(st, 42, acc, 3);
    }
    if (secB) for (let st = 1; st < 16; st += 2) D(st, 42, 36, 3);
    if (secB) for (const st of [2, 6, 10, 14]) D(st, 54, 56);
    else for (let st = 1; st < 16; st += 2) D(st, 70, 30 + (st % 4 === 1 ? 8 : 0));
    // riempimenti
    if (bar === 7) [70, 80, 92, 106].forEach((v, i) => s.add(drums, B(bar, 12 + i), 0.2, 38, v, 3));
    if (bar === 15) {
      [64, 74, 84, 94].forEach((v, i) => s.add(drums, B(bar, 8 + i), 0.2, 38, v, 3));
      [50, 48, 45, 43].forEach((n, i) => s.add(drums, B(bar, 12 + i), 0.25, n, 100 + i * 4, 3));
      s.add(drums, B(bar, 8), 0.2, 36, 100); s.add(drums, B(bar, 12), 0.2, 36, 104);
    }
  }

  // --- basso ---
  const bassA = [[0, 'r', 3, 106], [3, 'r', 1, 60], [4, '5', 2, 88], [6, 'o', 1, 86], [7, 'ap', 1, 78], [8, 'r', 3, 100], [11, 'r', 1, 60], [12, '3', 2, 86], [14, '5', 1, 86], [15, 'ap', 1, 78]];
  const bassB = [[0, 'r', 2, 108], [2, 'o', 1, 80], [3, '5', 1, 76], [4, 'r', 2, 96], [6, '3', 1, 82], [7, 'ap', 1, 80], [8, 'r', 2, 102], [10, 'o', 1, 82], [12, '5', 2, 92], [14, '7', 1, 84], [15, 'ap', 1, 80]];
  for (let bar = 0; bar < bars; bar++) for (const [st, deg, d, v] of bar >= 8 ? bassB : bassA) {
    const c = at(bar, half(st)); let root = nearest(c.root, 41, 36, 47);
    let p;
    if (deg === 'r') p = root; else if (deg === 'o') p = root + 12; else if (deg === '5') p = root + c.iv[2]; else if (deg === '3') p = root + c.iv[1];
    else if (deg === '7') p = root + c.iv[3] - 12 < 33 ? root + c.iv[3] : root + c.iv[3] - 12;
    else { // approccio cromatico dal basso alla fondamentale successiva (mezza battuta dopo)
      const nxt = st === 15 ? at(bar + 1, 0) : at(bar, 1);
      p = nxt.root !== c.root ? nearest(nxt.root, root, 36, 47) - 1 : root + c.iv[2] - 12;
    }
    s.add(bass, B(bar, st), d / 4 * 0.9, p, v, 4);
  }

  // --- piano elettrico (comping sincopato), chitarra muta, ottoni, archi ---
  const compA = [[0, 3, 98], [6, 2, 84], [10, 2, 80]], compB = [[0, 2, 100], [3, 2, 74], [6, 3, 90], [10, 2, 82], [13, 2, 70]];
  let cEP = 60;
  for (let bar = 0; bar < bars; bar++) for (const [st, d, v] of bar >= 8 ? compB : compA) {
    const v4 = voice(at(bar, half(st)), cEP, 52, 69); cEP = v4.reduce((a, b) => a + b) / v4.length;
    v4.forEach((p) => s.add(ep, B(bar, st), d / 4 * 0.85, p, v - 8, 6));
  }
  for (let bar = 0; bar < bars; bar++) for (const st of bar >= 8 ? [2, 3, 5, 7, 10, 11, 13, 15] : [2, 5, 7, 10, 13, 15]) {
    const c = at(bar, half(st)); const t3 = nearest((c.root + c.iv[1]) % 12, 58, 52, 64), t7 = nearest((c.root + c.iv[3]) % 12, 64, 58, 70);
    [t3, t7].forEach((p) => s.add(gtr, B(bar, st), 0.18, p, 52 + (st % 4 === 3 ? 14 : 0), 5));
  }
  let cBr = 69;
  const stab = (bar, st, d, v) => { const v4 = voice(at(bar, half(st)), cBr, 60, 79); cBr = v4.reduce((a, b) => a + b) / v4.length; v4.forEach((p) => s.add(brass, B(bar, st), d / 4, p, v, 4)); };
  for (let bar = 0; bar < bars; bar++) {
    if (bar < 8) { if (bar % 2 === 1) stab(bar, 14, 1.5, 100); }
    else { stab(bar, 6, 1.5, 96); stab(bar, 14, 1.5, 104); if (bar === 8) stab(bar, 0, 2, 108); }
  }
  let cSt = 66;
  for (let bar = 8; bar < bars; bar++) for (const h of [0, 1]) {
    const v4 = voice(at(bar, h), cSt, 55, 76); cSt = v4.reduce((a, b) => a + b) / v4.length;
    v4.forEach((p) => s.add(str, B(bar, h * 8), 1.95, p, 62, 4));
  }

  // --- melodia (passi in sedicesimi: [step, durata, nota]) ---
  const mel = [
    [[0, 2, 'G4'], [2, 2, 'C5'], [4, 3, 'E5'], [8, 2, 'E5'], [10, 2, 'D5'], [12, 4, 'E5']],
    [[0, 3, 'C5'], [3, 1, 'A4'], [4, 4, 'C5'], [8, 2, 'E5'], [10, 2, 'D5'], [12, 4, 'C5']],
    [[0, 3, 'A4'], [3, 1, 'C5'], [4, 2, 'F5'], [6, 2, 'E5'], [8, 4, 'C5'], [12, 4, 'A4']],
    [[0, 2, 'B4'], [2, 2, 'D5'], [4, 3, 'G5'], [8, 2, 'F5'], [10, 2, 'D5'], [12, 2, 'B4']],
    [[0, 3, 'E5'], [3, 1, 'G5'], [4, 4, 'G5'], [8, 3, 'E5'], [11, 1, 'D5'], [12, 4, 'C5']],
    [[0, 3, 'G4'], [3, 1, 'B4'], [4, 4, 'E5'], [8, 3, 'E5'], [11, 1, 'C#5'], [12, 4, 'A4']],
    [[0, 3, 'F5'], [3, 1, 'E5'], [4, 3, 'D5'], [7, 1, 'F5'], [8, 2, 'F5'], [10, 2, 'A4'], [12, 4, 'D5']],
    [[0, 3, 'D5'], [3, 1, 'F5'], [4, 2, 'G5'], [6, 2, 'F5'], [8, 2, 'D5'], [10, 2, 'B4'], [12, 2, 'G4']],
    [[0, 3, 'A5'], [3, 1, 'C6'], [4, 4, 'A5'], [8, 2, 'F5'], [10, 2, 'A5'], [12, 4, 'C6']],
    [[0, 3, 'B5'], [3, 1, 'A5'], [4, 4, 'G5'], [8, 2, 'D5'], [10, 2, 'E5'], [12, 4, 'G5']],
    [[0, 3, 'G5'], [3, 1, 'B5'], [4, 3, 'B5'], [7, 1, 'A5'], [8, 4, 'G5'], [12, 4, 'E5']],
    [[0, 3, 'E5'], [3, 1, 'G5'], [4, 4, 'A5'], [8, 2, 'G5'], [10, 2, 'E5'], [12, 4, 'C5']],
    [[0, 3, 'A5'], [3, 1, 'C6'], [4, 2, 'C6'], [6, 2, 'A5'], [8, 4, 'F5'], [12, 4, 'A5']],
    [[0, 3, 'C5'], [3, 1, 'D5'], [4, 4, 'F5'], [8, 2, 'G5'], [10, 2, 'F5'], [12, 4, 'D5']],
    [[0, 3, 'E5'], [3, 1, 'G5'], [4, 3, 'E5'], [7, 1, 'D5'], [8, 4, 'C5'], [12, 4, 'E5']],
    [[0, 3, 'F5'], [3, 1, 'A5'], [4, 3, 'F5'], [7, 1, 'E5'], [8, 2, 'D5'], [10, 2, 'B4'], [12, 2, 'B4'], [14, 2, 'D5']],
  ];
  const flat = [];
  mel.forEach((bm, bar) => bm.forEach(([st, d, name]) => {
    const n = midi(name), beat = B(bar, st), dur = d / 4;
    flat.push({ beat, dur, n });
    const len = Math.max(dur * 0.9, 0.2);
    s.add(trp, beat, len, n, bar >= 8 ? 96 : 100, 6);
    if (bar < 8) s.add(vib, beat, len, n + 12, 70, 6); else s.add(saw, beat, len, n, 78, 6);
  }));
  const bad = checkMelody('accumula', flat, chordAtBeat);
  return { s, bad };
}

// ---------- brano 2: ruba ----------
function ruba() {
  const bpm = 100, bars = 16;
  const s = makeSong({ bpm, bars, swing: true, seed: 23 });
  const C = chord;
  const prog = [
    ['C:mMaj7'], ['C:m6'], ['F:m7'], ['Bb:7'], ['Eb:maj7'], ['D:m7b5', 'G:7b9'], ['C:m6'], ['D:m7b5', 'G:7b9'],
    ['F:m7'], ['Bb:7'], ['Eb:maj7'], ['Ab:maj7'], ['D:m7b5'], ['G:7b9'], ['C:m6'], ['Ab:7', 'G:7b9'],
  ].map((b) => (b.length === 1 ? [C(b[0]), C(b[0])] : [C(b[0]), C(b[1])]));
  const at = (bar, h) => prog[((bar % bars) + bars) % bars][h];
  const chordAtBeat = (beat) => at(Math.floor(beat / 4), (beat % 4) >= 2 ? 1 : 0);

  const drums = s.track('Spazzole', 9, 40, { 7: 100, 10: 64, 91: 35, 93: 0 });
  const bass = s.track('Contrabbasso', 0, 32, { 7: 118, 10: 56, 91: 8, 93: 0 });
  const pizz = s.track('Archi pizzicati', 1, 45, { 7: 92, 10: 38, 91: 50, 93: 25 });
  const sax = s.track('Sax tenore', 2, 66, { 7: 104, 10: 78, 91: 55, 93: 15 });
  const clar = s.track('Clarinetto', 3, 71, { 7: 100, 10: 84, 91: 60, 93: 20 });
  const vib = s.track('Vibrafono', 4, 11, { 7: 70, 10: 100, 91: 70, 93: 30 });
  const mute = s.track('Tromba con sordina', 5, 59, { 7: 90, 10: 90, 91: 55, 93: 10 });

  // batteria con le spazzole
  for (let bar = 0; bar < bars; bar++) {
    const b0 = bar * 4, secB = bar >= 8;
    for (let k = 0; k < 4; k++) {
      s.add(drums, b0 + k, 0.2, 36, 28, 6);                              // cassa sussurrata
      if (k % 2 === 1) s.add(drums, b0 + k, 0.2, 44, 72, 4);             // charleston a pedale su 2 e 4
    }
    for (const [bt, v] of [[0, 66], [1, 70], [1.5, 46], [2, 66], [3, 70], [3.5, 46]]) s.add(drums, b0 + bt, 0.3, 51, v, 5); // ride swing
    if (bar % 2 === 1) s.add(drums, b0 + 3.5, 0.2, 38, 30, 4);           // spazzola fantasma
    if (secB) for (const [bt, n, v] of [[0.5, 60, 52], [1.5, 61, 56], [2.5, 60, 50], [3, 61, 58], [3.5, 60, 48]]) s.add(drums, b0 + bt, 0.2, n, v, 5);
    if (bar === 7 || bar === 15) [40, 48, 56, 64, 74, 86].forEach((v, i) => s.add(drums, b0 + 2 + i * 0.33, 0.2, 38, v, 3));
    if (bar === 0 || bar === 8) s.add(drums, b0, 1, 53, 60, 3);
  }

  // contrabbasso che cammina
  let prev = 36;
  for (let bar = 0; bar < bars; bar++) {
    const near = (pc, from) => nearest(pc, from, 31, 46);
    const picks = [];
    const c1 = at(bar, 0), c2 = at(bar, 1), nxtRoot = at(bar + 1, 0).root;
    const toApproach = (target, from) => { const t = near(target, from); return from <= t ? t - 1 : t + 1; };
    if (c1 === c2) {
      const [a, b] = bar % 2 ? [2, 1] : [1, 2];
      const p0 = near(c1.root, prev), p1 = near((c1.root + c1.iv[a]) % 12, p0), p2 = near((c1.root + c1.iv[b]) % 12, p1);
      picks.push(p0, p1, p2, toApproach(nxtRoot, p2));
    } else {
      const p0 = near(c1.root, prev), p1 = toApproach(c2.root, p0), p2 = near(c2.root, p1), p3 = toApproach(nxtRoot, near((c2.root + c2.iv[2]) % 12, p2));
      picks.push(p0, p1, p2, p3);
    }
    picks.forEach((p, k) => { s.add(bass, bar * 4 + k, 0.92, p, [96, 82, 88, 90][k], 5); });
    prev = picks[3];
  }

  // archi pizzicati (controtempo), vibrafono (B), sordina (accenti)
  let cP = 62, cM = 66;
  for (let bar = 0; bar < bars; bar++) for (const bt of bar >= 8 ? [0.5, 1.5, 2.5, 3.5] : [1.5, 3.5]) {
    const v3 = voice(at(bar, bt >= 2 ? 1 : 0), cP, 54, 70, 4).slice(1); cP = v3.reduce((a, b) => a + b) / v3.length; // senza fondamentale
    v3.forEach((p) => s.add(pizz, bar * 4 + bt, 0.3, p, bt % 1 ? 74 : 66, 6));
  }
  for (let bar = 8; bar < bars; bar++) for (const h of [0, 1]) {
    const c = at(bar, h), pr = nearest(c.root, 60, 55, 66), p5 = pr + c.iv[2];
    [pr, p5].forEach((p) => s.add(vib, bar * 4 + h * 2, 1.9, p, 52, 5));
  }
  for (const bar of [3, 7, 11, 15]) {
    const v3 = voice(at(bar, 1), cM, 60, 76, 4).slice(1);
    v3.forEach((p) => s.add(mute, bar * 4 + 3.5, 0.3, p, 100, 4));
    v3.forEach((p) => s.add(mute, bar * 4 + 3, 0.2, p, 70, 4));
  }

  // melodia: [beat nella battuta, durata, nota]
  const S = 0.4;
  const melA = [
    [[0.5, S, 'C4'], [1, S, 'D4'], [1.5, S, 'Eb4'], [2, 0.8, 'G4'], [3, S, 'B3'], [3.5, S, 'C4']],
    [[0.5, S, 'Eb4'], [1, S, 'G4'], [1.5, S, 'A4'], [2, S, 'G4'], [2.5, S, 'F#4'], [3, 0.8, 'G4']],
    [[0.5, S, 'F4'], [1, S, 'Ab4'], [1.5, S, 'G4'], [2, S, 'F4'], [2.5, S, 'E4'], [3, 0.8, 'Eb4']],
    [[0.5, S, 'D4'], [1, S, 'F4'], [1.5, S, 'Ab4'], [2, S, 'F4'], [2.5, S, 'D4'], [3, 1, 'Bb3']],
    [[0.5, S, 'G4'], [1, S, 'Bb4'], [1.5, S, 'D5'], [2, S, 'Bb4'], [3, S, 'G4'], [3.5, S, 'F4']],
    [[0.5, S, 'F4'], [1, S, 'Ab4'], [1.5, S, 'C5'], [2, S, 'B4'], [2.5, S, 'Ab4'], [3, S, 'G4'], [3.5, S, 'F4']],
    [[0.5, S, 'Eb4'], [1, S, 'G4'], [2, S, 'A4'], [2.5, S, 'G4'], [3, 0.8, 'Eb4']],
    [[0.5, S, 'F4'], [1, S, 'Ab4'], [2, S, 'B4'], [2.5, S, 'D5'], [3, 1, 'Ab4']],
  ];
  const melB = [
    [[0, 1, 'C5'], [1, 0.5, 'Eb5'], [1.5, 0.5, 'F5'], [2, 1.5, 'Ab5'], [3.5, 0.5, 'G5']],
    [[0, 1, 'F5'], [1, 0.5, 'D5'], [1.5, 0.5, 'F5'], [2, 2, 'Ab5']],
    [[0, 1.5, 'G5'], [1.5, 0.5, 'F5'], [2, 1, 'Eb5'], [3, 1, 'D5']],
    [[0, 1, 'C5'], [1, 0.5, 'Eb5'], [1.5, 0.5, 'G5'], [2, 2, 'C6']],
    [[0, 1, 'F5'], [1, 0.5, 'Ab5'], [1.5, 0.5, 'F5'], [2, 1, 'D5'], [3, 1, 'C5']],
    [[0, 1, 'B4'], [1, 0.5, 'D5'], [1.5, 0.5, 'F5'], [2, 1, 'Ab5'], [3, 1, 'G5']],
    [[0, 2, 'G5'], [2, 1, 'Eb5'], [3, 1, 'C5']],
    [[0, 1, 'Eb5'], [1, 0.5, 'C5'], [1.5, 0.5, 'Eb5'], [2, 1, 'D5'], [3, 0.5, 'B4'], [3.5, 0.5, 'Ab4']],
  ];
  const flat = [];
  [...melA, ...melB].forEach((bm, bar) => bm.forEach(([bt, d, name]) => {
    const n = midi(name), beat = bar * 4 + bt;
    flat.push({ beat, dur: d, n });
    if (bar < 8) s.add(sax, beat, d, n, bt % 1 ? 92 : 100, 6); else s.add(clar, beat, d * 0.95, n, 92, 6);
  }));
  const bad = checkMelody('ruba', flat, chordAtBeat);
  return { s, bad };
}

// ---------- rendering ----------
function run(cmd, a) {
  const r = spawnSync(cmd, a, { encoding: 'utf8', maxBuffer: 1 << 28 });
  if (r.status !== 0) { console.error(`${cmd} fallito:\n${r.stderr?.slice(-1500)}`); process.exit(2); }
  return (r.stdout ?? '') + (r.stderr ?? '');
}
function measure(file) {
  const o = run('ffmpeg', ['-hide_banner', '-nostats', '-i', file, '-af', 'ebur128=peak=true', '-f', 'null', '-']);
  const sum = o.slice(o.lastIndexOf('Summary:'));
  return { lufs: Number(/I:\s+(-?[\d.]+) LUFS/.exec(sum)[1]), peak: Number(/Peak:\s+(-?[\d.]+) dBFS/.exec(sum)[1]) };
}
function verify(file) {
  const r = spawnSync('ffmpeg', ['-v', 'error', '-i', file, '-f', 'f32le', '-ac', '2', '-ar', String(SR), '-'], { maxBuffer: 1 << 29 });
  const f = new Float32Array(r.stdout.buffer, r.stdout.byteOffset, r.stdout.length >> 2), N = f.length >> 1;
  const diffs = new Float32Array(2 * (N - 1)); let k = 0, seam = 0;
  for (let ch = 0; ch < 2; ch++) {
    for (let i = 0; i < N - 1; i++) diffs[k++] = Math.abs(f[(i + 1) * 2 + ch] - f[i * 2 + ch]);
    seam = Math.max(seam, Math.abs(f[ch] - f[(N - 1) * 2 + ch]));
  }
  diffs.sort(); const p999 = diffs[Math.floor(diffs.length * 0.999)], mx = diffs[diffs.length - 1];
  const rms = (a, b) => { let s = 0; for (let i = a * 2; i < b * 2; i++) s += f[i] * f[i]; return 20 * Math.log10(Math.sqrt(s / ((b - a) * 2)) + 1e-9); };
  const w = Math.round(SR * 0.05);
  return { sec: N / SR, seam, p999, mx, head: rms(0, w), tail: rms(N - w, N) };
}

const SONGS = { accumula, ruba };
const todo = pos.slice(1).length ? pos.slice(1) : Object.keys(SONGS);
for (const name of todo) {
  console.log(`== ${name}`);
  const { s, bad } = SONGS[name]();
  const mid = join(OUT, `${name}.mid`), raw = join(OUT, `${name}.raw.wav`), cut = join(OUT, `${name}.cut.wav`), ogg = join(OUT, `${name}.ogg`);
  writeFileSync(mid, s.build());
  run(FLUID, ['-ni', '-F', raw, '-r', String(SR), '-g', '0.6', '-o', 'synth.reverb.room-size=0.6', '-o', 'synth.reverb.level=0.55', '-o', 'synth.polyphony=512', SF2, mid]);
  const sec = s.L / PPQ * 60 / s.bpm, n = Math.round(sec * SR);
  // 3 giri renderizzati, si prende l'ultimo: la coda di riverbero dei giri precedenti riempie l'inizio, l'unione è continua
  run('ffmpeg', ['-y', '-v', 'error', '-i', raw, '-af', `atrim=start_sample=${2 * n}:end_sample=${3 * n},asetpts=PTS-STARTPTS`, '-ar', String(SR), '-ac', '2', cut]);
  const m0 = measure(cut);
  let gain = -18 - m0.lufs;
  if (m0.peak + gain > -1) gain = -1 - m0.peak; // niente clip
  run('ffmpeg', ['-y', '-v', 'error', '-i', cut, '-af', `volume=${gain.toFixed(2)}dB`, '-c:a', 'libvorbis', '-q:a', '4', '-ac', '2', ogg]);
  for (const f of [raw, cut]) if (existsSync(f)) unlinkSync(f);
  const m = measure(ogg), v = verify(ogg);
  console.log(`${name}.ogg: ${v.sec.toFixed(3)} s (attese ${sec.toFixed(3)}), ${m.lufs} LUFS, picco ${m.peak} dBFS, note fuori armonia: ${bad}`);
  console.log(`  unione: salto ${v.seam.toFixed(4)} | passo normale p99.9 ${v.p999.toFixed(4)} max ${v.mx.toFixed(4)} | primi 50ms ${v.head.toFixed(1)} dB, ultimi 50ms ${v.tail.toFixed(1)} dB`);
}
