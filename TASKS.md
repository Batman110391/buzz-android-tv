# TASKS.md — Bacheca dei task

Stati: `todo` · `doing` · `review` (fatto, da verificare) · `done` · `blocked`
Esecutore: **P** = sessione padre · **W** = worker Sonnet · **S** = supervisore

## M0 — Prova tecnica

| ID | Task | Esec. | Dipende da | File consentiti | Check | Stato |
|---|---|---|---|---|---|---|
| T01 | `git init`, `.gitignore` per Godot, primo commit dei documenti | P | — | `.gitignore` | `git status` pulito | done |
| T02 | Installare Godot 4.x stabile, OpenJDK 17, Android SDK (cmdline-tools, platform-tools, build-tools, platform), export template Godot; creare il keystore di debug | W | approvazione S | nessun file del progetto | `godot --version`, `adb --version`, `java -version` | done |
| T03 | Sulla Fire TV: attivare Opzioni sviluppatore → Debug ADB + App di origine sconosciuta; comunicare IP e generazione della 4K Max | S | — | — | IP ricevuto | done |
| T04 | Progetto Godot: `project.godot` (Compatibility, 1920×1080, schermo sempre acceso) + scena di prova: cubo che ruota, etichetta FPS, il tasto centrale del telecomando / `Invio` cambia colore | W | T01, T02 | `project.godot`, `main.tscn`, `main.gd` | avvio headless senza errori + screenshot | done |
| T05 | `net/server.gd`: HTTP su 8080 che serve `net/controller.html`, WebSocket su 8081; segnale `button_pressed(player_id)`. `controller.html`: un pulsante grande | W | T02 | `net/server.gd`, `net/controller.html` | dal browser del PC su `localhost:8080` il pulsante produce il segnale (log) | done |
| T06 | Collegare `server.gd` alla scena di prova (pulsante del telefono → colore del cubo) | P | T04, T05 | `main.gd` | prova da PC | done |
| T07 | Preset di esportazione Android (permesso INTERNET), `adb connect`, installazione e avvio sulla TV | W | T03, T06 | `export_presets.cfg` | l'app si avvia sulla TV | done |
| T08 | Prova sulla TV: FPS, telecomando, pulsante dal telefono, nessun screensaver | S + P | T07 | — | checklist M0 in PLAN.md | done |

**Parallelo possibile:** T03 subito, in qualsiasi momento · T04 ∥ T05 dopo T02.


## M1 — Vertical slice

Contratti delle interfacce: PLAN.md §4 "Contratti M1". Ogni worker legge **solo** quella sezione + il proprio task.

| ID | Task | Esec. | Dipende da | File consentiti | Check | Stato |
|---|---|---|---|---|---|---|
| T10 | Regole: `Game` secondo il contratto + test (risposta valida, doppia, fuori fase, tardiva, indice errato, fine anticipata se rispondono tutti, punteggi, classifica, FINAL dopo N domande). + 12 domande italiane di cultura generale nel formato di PLAN.md | W | — | `game/game.gd`, `game/questions.json`, `tests/test_game.gd` | `--headless --script res://tests/test_game.gd` → PASS, exit 0 | done |
| T11 | Palco con primitive (pavimento lucido, fondale con archi/luci, 6 podi colorati con Label3D nome+punti, luci scenografiche, camere) + coriandoli (`CPUParticles3D`, compatibile GLES3) secondo il contratto | W | — | `stage/stage.tscn`, `stage/stage.gd` | screenshot `--write-movie` di una scena di prova temporanea fuori dal repo | done (provvisorio) |
| T12 | Presentatore placeholder: modello **CC0** animato (Quaternius / KayKit / Kenney, es. via poly.pizza), glb in `assets/models/host/`, `host.tscn` + `host.gd` secondo il contratto, licenza in `assets/LICENSES.md` | W | — | `assets/models/host/*`, `assets/LICENSES.md`, `stage/host.tscn`, `stage/host.gd` | import senza errori + screenshot con le 4 animazioni | done (provvisorio) |
| T13 | HUD secondo il contratto, stile "quiz TV" (pannelli arrotondati, colori forti), font OFL da Google Fonts in `assets/fonts/` | W | — | `ui/hud.tscn`, `ui/hud.gd`, `assets/fonts/*` | screenshot di menu, domanda, reveal, classifica | done (provvisorio) |
| T14 | `main`: collega Game ↔ stage ↔ host ↔ hud; giocatore 1 da tastiera `1`–`4` e telecomando; 3 bot con risposte casuali; tempi di regia; battute del presentatore come testo a schermo (voce in M3) | P | T10–T13 | `main.tscn`, `main.gd`, `project.godot` | partita completa da PC (60–90 s) | todo |
| T15 | Export sulla TV + misura FPS durante la partita; se < 30: ridurre ombre/luci/particelle | W | T14 | `project.godot` (solo impostazioni grafiche), file di stage indicati dal padre | screenshot TV + FPS | todo |
| T16 | Playtest e approvazione estetica | S | T15 | — | ok del supervisore | todo |

**Parallelo:** T10 ∥ T11 ∥ T12 ∥ T13 (4 worker), poi T14 (padre), poi T15.
**Nota T14:** il server di M0 resta in `net/`, ma la scena di prova (cubo) viene sostituita.

## Prova visiva (prima di T14) — obiettivo: livello dei riferimenti in `ref/` (screenshot Buzz PS3, non nel repo)
Si copia lo **stile** (studio al neon, layout HUD, personaggi caricaturali), mai asset, nomi o personaggi di Buzz/Sony. Se il supervisore non è convinto → si ferma il progetto.

| ID | Task | Esec. | Dipende da | File consentiti | Check | Stato |
|---|---|---|---|---|---|---|
| V1 | Personaggi cartoon caricaturali (presentatore + 4-6 concorrenti): S li genera su Meshy con i prompt del padre, scarica i glb rigged + animati | S + P | — | `assets/models/characters/*` | glb importati, animazioni mappate | doing |
| V2 | Studio stile quiz TV (rif. `ref/5.jpg`, `6.jpg`, `1.jpg`) + slot per personaggi | W | — | `stage/stage.tscn`, `stage/stage.gd` | screenshot | done |
| V3 | HUD stile quiz TV: barra domanda in alto + orologio, risposte a sinistra, giocatori a destra con ritratto, ✓/✗ (rif. `ref/5.jpg`, `4.jpg`) | W | — | `ui/hud.tscn`, `ui/hud.gd`, `assets/fonts/*` | screenshot | done |
| V4 | Scena di prova: studio + personaggi + HUD come `ref/5.jpg`; FPS sulla TV | P | V1–V3 | `main.*`, `project.godot` | screenshot PC + TV, ok S | todo |

## Log
- 2026-10-10 — Piano scritto (PLAN.md), flusso di lavoro definito (CLAUDE.md, worker). In attesa dell'approvazione del supervisore.
- 2026-10-10 — T01 done. T02 done: Godot 4.7.2, JDK 17, SDK (build-tools 35.0.1, android-35, NDK 28.1), template 4.7.2 (percorsi in CLAUDE.md). T03 done: TV AFTKRT già su adb. T04 ∥ T05 avviati.
- 2026-10-10 — T04 done (screenshot ok). T05 done (test_server PASS). T06 done: server in main.gd, URL LAN sulla Label, parse JSON senza log d'errore. Nota T07: includere `*.html` nel filtro di esportazione.
- 2026-10-10 — T07 done: APK armeabi-v7a sulla TV, 60 FPS a regime (11 all'avvio). Fix: IP LAN con priorità 192.168 (la TV ha una VPN su tun0); usare solo l'adb dell'SDK. Da sistemare più avanti: icona del progetto; app non visibile nel launcher (serve Gradle + leanback).
- 2026-10-10 — T08 done: M0 CHIUSA (telecomando, telefono, screensaver ok). Task M1 e contratti scritti. Prossimo: nuova sessione → T10–T13 in parallelo.
- 2026-10-10 — T10 done. T11–T13 fatti ma provvisori: il supervisore vuole il livello di Buzz PS3 (rif. in `ref/`). Aperta la "Prova visiva" V1–V4 prima di T14.
- 2026-10-10 — V2 (studio neon, 4 luci, MultiMesh) e V3 (HUD stile ref 5/4) done, verificati insieme su screenshot. Da sistemare in V4: inquadratura (presentatore e pannelli coprono i concorrenti). V1: supervisore su Meshy (3D Model → Text to 3D, Meshy 6, Smart Topology, Rigging, GLB).
- 2026-10-13 — Voce del presentatore "Lello Splendore" (showman provocatore, non legge le domande): 56 battute in `assets/voice/` generate con `tools/gen_voice.mjs` (ElevenLabs v3, voce Voice Design, Creative). Chiave in variabile utente ELEVENLABS_API_KEY. Personaggi: modelli Mixamo in `3dmodel/` (non ancora nel repo), nomi fissi: Don Polpetta, Madame Smeralda, Zippo, Lola Bigodina, Zio Zombi, Elvio Panzerotto, El Macho.
