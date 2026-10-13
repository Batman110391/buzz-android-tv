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
| V1 | Personaggi cartoon caricaturali (presentatore + 4-6 concorrenti): S li genera su Meshy con i prompt del padre, scarica i glb rigged + animati | S + P | — | `assets/models/characters/*` | glb importati, animazioni mappate | done |
| V2 | Studio stile quiz TV (rif. `ref/5.jpg`, `6.jpg`, `1.jpg`) + slot per personaggi | W | — | `stage/stage.tscn`, `stage/stage.gd` | screenshot | done |
| V3 | HUD stile quiz TV: barra domanda in alto + orologio, risposte a sinistra, giocatori a destra con ritratto, ✓/✗ (rif. `ref/5.jpg`, `4.jpg`) | W | — | `ui/hud.tscn`, `ui/hud.gd`, `assets/fonts/*` | screenshot | done |
| V4 | Scena di prova: studio + personaggi + HUD come `ref/5.jpg`; FPS sulla TV | W | V1–V3 | vedi prompt sotto | screenshot PC + TV, ok S | todo |

**Prompt pronto per il worker V4** (effort `medium`; il padre lo lancia così com'è, poi verifica i frame):
> Task V4 — Scena di prova completa (mini-partita di 3 domande, livello quiz TV)
> Progetto Godot 4.7.2 in C:\react\BUZZ, renderer Compatibility, 1920×1080, GDScript tipizzato. Godot console: vedi CLAUDE.md "Toolchain".
> LEGGI SOLO: PLAN.md sezioni "Contratti M1" (solo la parte `game/game.gd`) e "Contratti prova visiva (V4)". Non esplorare altro.
> FILE CONSENTITI: `main.tscn`, `main.gd` (sostituisci la scena del cubo; non usare `net/`), `project.godot` (solo azioni di input), `export_presets.cfg` (solo `include_filter`: aggiungi `*.json`), `stage/stage.gd` (solo posizioni/fov delle camere), ELIMINA `stage/host.tscn`, `stage/host.gd`, `assets/models/host/` e la riga KayKit in `assets/LICENSES.md`.
> FLUSSO: 4 giocatori = giocatore 1 umano + 3 bot, personaggi diversi scelti a caso fra i 7; nomi = nomi dei personaggi; `Game.setup(nomi, questions.json, 3)`. Presentatore (`character.gd` con `host.fbx`) su `HostSpot`, concorrenti su `PlayerSpotN`. Voce con un `AudioStreamPlayer`; mentre parla il presentatore fa `talk`/`talk2`, poi `idle`.
> MENU: `hud.show_menu()`, voce `menu_` ogni ~12 s; OK/Invio/tasto centrale → `game.start()`.
> INTRO: `stage.play_intro()` + voce `intro_`; poi `pres_<chiave>` di ogni concorrente (il presentato fa `happy`/`clap`); quando voce e intro sono finite → `advance()`.
> QUESTION: `hud.show_question`, `stage.focus_question()`, voce `qfirst_`/`qnext_`/`qlast_`, concorrenti `think`; `game.tick(delta)` in `_process`, `hud.set_time`. Giocatore 1: tasti `1`–`4` e telecomando (su=0, destra=1, giù=2, sinistra=3). Bot: rispondono a caso dopo 2–10 s. Prima risposta della domanda → 50% voce `firstbuzz_`; a 5 s dalla fine se qualcuno non ha risposto → `hurry_`. `answer_received` → `hud.mark_answered`.
> REVEAL (`question_resolved`): `hud.show_reveal`, `stage.show_reveal`; chi ha indovinato `cheer`/`victory`, gli altri `disappointed`/`defeated`; voce: tutti → `allright_`, nessuno → `noneright_`, uno solo → `solo_<chiave>`, altrimenti `someright_`; presentatore `surprised` o `clap`. Fine voce + 1 s → `advance()`.
> SCOREBOARD: `hud.update_scores` + `stage.update_scores` + `hud.show_scoreboard`; voce: pareggio in testa → `tie_`, altrimenti 50% `last_<chiave dell'ultimo>` / 50% `scores_`. Fine voce + 1 s → `advance()`.
> FINAL (`game_over`): voce `final_` → poi `win_<chiave>`, `stage.celebrate(vincitore)`, vincitore `dance_*` a caso, altri `clap`; `hud.show_final`; voce `outro_`; OK → MENU.
> Mai sovrapporre due battute: una nuova interrompe solo se è di fase diversa.
> DEMO: con l'argomento `-- --demo` anche il giocatore 1 è un bot e il MENU parte da solo dopo 2 s (serve per i test).
> INQUADRATURA domanda: presentatore in primo piano al centro, i 4 concorrenti visibili dietro nella fascia x 620–1380 (stile `ref/5.jpg`, guardalo).
> CHECK: `godot --path C:\react\BUZZ --write-movie <scratchpad>\V4\shot.png --quit-after 3600 -- --demo` (non headless), nessun ERROR/WARNING nell'output; guarda i frame di intro, domanda, reveal, classifica, finale e correggi. Report max 10 righe con i nomi dei frame migliori.

| V5 | Look più cartoon (luci, podi, pavimento, label) | W | V4 | `stage/*` | screenshot | done |

## Regia — la scena deve vivere (contratti: PLAN.md §4 "Contratti regia")

| ID | Task | Esec. | Dipende da | File consentiti | Check | Stato |
|---|---|---|---|---|---|---|
| R1 | Scaricare da Mixamo le animazioni `walk strut point laugh taunt` | S | — | `assets/animations/*` | file presenti | done |
| R2 | `director.gd`: regista con camere sempre in movimento e stacchi | W | — | `stage/director.gd`, `stage/stage.gd` (solo camera) | cattura 30 s di una scena di prova fuori dal repo | done |
| R3 | `walk_to`/`face` in character.gd + nuove animazioni | W | R1 | `stage/character.gd` | cattura 30 s | done |
| R4 | Musica + effetti CC0 e `audio/sfx.gd` | W | — | `audio/sfx.gd`, `assets/audio/**`, `assets/LICENSES.md` | test headless che carica tutti i suoni | done |
| R5 | HUD animato (entrate, punteggi che contano, timer che pulsa) | W | — | `ui/hud.gd` | cattura 30 s | done |
| R6 | Collegare tutto in main: presentatore che gira per lo studio e sfotte, shot per fase, suoni | P | R2–R5 | `main.gd`, `main.tscn`, `project.godot` | `-- --demo --quick` 30 s | done |
| R7 | FPS sulla TV: trovato e tolto il crash (env.adjustment = perdita di memoria su PowerVR), luce per vertice, misura con `tools/perf.sh` | P | R6 | impostazioni grafiche | app stabile | done |
| R8 | **Studio rifatto per la TV**: tutto opaco e unshaded (luce dipinta nei colori/texture), niente riflesso specchiato, niente strati trasparenti grandi (pubblico, coni, bagliori, puntini del pavimento); stessa estetica neon. Obiettivo ≥ 50 FPS in tutte le fasi | P/W | R7 | `stage/stage.gd` | `bash tools/perf.sh build` + `run 60` | done |

**Regola catture:** massimo 30 s di gioco (`--fixed-fps 10 --quit-after 300`), `-- --demo --quick` salta l'intro.

## M1-2D — grafica pre-renderizzata (contratti: PLAN.md §4 "Architettura 2D pre-renderizzata")

| ID | Task | Esec. | Dipende da | File consentiti | Check | Stato |
|---|---|---|---|---|---|---|
| P3 | Memoria/caricamento sulla TV di 5 set di sprite sintetici (4×225 frame ~300×330 + 250 frame ~400×750), import VRAM compresso | W | — | `tests/prerender_test.*`, `assets/p3_test/` (temporanea, non nel commit), `project.godot` (solo main_scene, da ripristinare) | GL MB + secondi di caricamento + FPS dalla TV | todo |
| D1 | `.glb` dei 7 concorrenti in `art/characters/` (Godot headless, non in git: `godot --headless --path . --script res://tools/fbx_to_glb.gd`), `art/.gdignore` | P | — | `tools/fbx_to_glb.gd`, `art/**` | Blender importa ogni glb con l'armatura | done |
| D2 | `tools/render_studio.py`: 4 fondali, 6 podi, `layout.json`, provino | W (medium) | — | `tools/render_studio.py`, `assets/studio/**` | provino ok del supervisore | todo |
| D3 | `tools/render_sprites.py`: sprite + manifest + ritratto; prima il presentatore | W (medium) | — (concorrenti: D1) | `tools/render_sprites.py`, `assets/sprites/**` | sheet.png ok | todo |
| D4 | Runtime 2D: `studio.gd`, `sprite_char.gd`, `director2d.gd` + scena di prova | W | D2, D3 | `stage/studio.gd`, `stage/sprite_char.gd`, `stage/director2d.gd`, `tests/test_2d.tscn/.gd` | cattura 30 s | todo |
| D5 | HUD opaco + ritratti da `portrait.png` | W | D3 | `ui/hud.gd`, `ui/hud.tscn` | cattura 30 s | todo |
| D6 | `main` in 2D; eliminare stage.gd/director.gd/character.gd/stage.tscn, prerender_preview.py, prerender_test; FBX → `art/` | P | D4, D5 | `main.*`, `project.godot` | `-- --demo` completo senza errori | todo |
| D7 | TV: FPS per fase, memoria, tempo di avvio | P | D6 | impostazioni | `tools/perf.sh` | todo |

**Parallelo:** P3 ∥ D1 ∥ D2 ∥ D3 subito; D4 ∥ D5 dopo i primi asset; poi D6, D7.
**M1-2D SOSPESA (2026-10-13):** il supervisore ha portato il design system "Quizzone!" (Claude Design, in `design/quizzone/`, leggere `README.md`): 2D vettoriale cutout, molto più leggero. Si prova prima quello (sotto). Se approvato, M1-2D si cancella.

## Prova Quizzone (Q) — design: `design/quizzone/README.md` (+ i `.dc.html` citati nel task)
Obiettivo: sulla TV, titolo con Tony che parla + una domanda con 6 podi animati + rivelazione. Il supervisore giudica se è "vivo e divertente". Nomi e personaggi del design (Tony Scintilla, Gastone, Nonna Pina, Ugo, Brioche, Don Ciccio, Vanessa).

**Contratti:**
- `tools/svg_to_png.gd` (Godot headless): rasterizza ogni SVG di `design/quizzone/assets/personaggi/<id>/` a scala 2 (host 3), ritaglia all'area usata → `assets/personaggi/<id>/<pezzo>.png` + `assets/personaggi/<id>/pezzi.json` `{"scala":S, "pezzi":{"<pezzo>":[x,y]}}` (angolo alto-sx del ritaglio in px della tela originale). Copia anche `rig.json` in `assets/personaggi/`.
- `ui/personaggio.gd` (`class_name Personaggio`, Node2D): coordinate locali = tela del design (200×200, host 240×300), origine in alto a sinistra. `setup(id)`, `espressione(e)` (neutro felice triste sorpreso arrabbiato), `stato(s)` (attesa pensa risposto esulta sconfitta sorpreso: espressione + movimento), `gesto(g)` solo host (saluto annuncio esulta delusione sorpresa), `parla(stream: AudioStream)` con lip-sync dal volume (bus "Voce" creato da codice se manca) → segnale `finito_parlare`. Respiro, ciglia e micro-movimenti sempre attivi.
- `ui/palco.gd` (Node2D): `assets/palco/palco.png` 1920×1080 (renderizzato da HTML con Chrome headless, senza lampadine) + lampadine come nodi che lampeggiano a due gruppi.
- `ui/risposta.gd`, `ui/podio.gd`, `ui/schermata_domanda.gd` (Control/Node2D costruiti da codice, niente .tscn obbligatori): misure e stati del README. Podio: `setup(nome, colore, numero, punti)`, `metti_personaggio(p: Node2D)`, `set_stato(s)` (''/ok/ko/risposto/bomba/mira; chiama `p.stato(...)` se esiste), `badge(testo)`, `set_punti(n)` animato. Schermata: `mostra_domanda(n, tot, titolo_round, testo, risposte)`, `set_tempo(left, total)`, `risposto(pid, scelta)`, `rivela(corretta, scelte: Dictionary, punti: Array)`, `podio(i) -> Podio`.

| ID | Task | Esec. | Dipende da | File consentiti | Check | Stato |
|---|---|---|---|---|---|---|
| Q1 | Design in `design/quizzone/` (`.gdignore`), font Baloo 2 in `assets/fonts/`, LICENSES | P | — | `design/**`, `assets/fonts/*`, `assets/LICENSES.md` | file presenti | done |
| Q2 | Personaggi cutout: svg_to_png + personaggio.gd + scena di prova (Tony grande che parla con fumetto + 6 concorrenti che ciclano gli stati) | W (medium) | Q1 | `tools/svg_to_png.gd`, `assets/personaggi/**`, `ui/personaggio.gd`, `tests/test_personaggi.gd/.tscn` | cattura 30 s | done |
| Q3 | Palco PNG + palco.gd + risposta/podio/schermata_domanda + scena di prova (con personaggi segnaposto) | W (medium) | Q1 | `tools/palco.html`, `assets/palco/**`, `ui/palco.gd`, `ui/risposta.gd`, `ui/podio.gd`, `ui/schermata_domanda.gd`, `tests/test_domanda.gd/.tscn` | cattura 30 s confrontata con `1d`/`1e` del design | done |
| Q4 | Scena di prova completa (titolo → domanda con bot → rivelazione → Tony che commenta) + TV: FPS e memoria | P | Q2, Q3 | `tests/quizzone_test.*`, `project.godot` (main_scene temporanea) | `tools/perf.sh`, ok del supervisore | todo |

## Log
- 2026-10-10 — Piano scritto (PLAN.md), flusso di lavoro definito (CLAUDE.md, worker). In attesa dell'approvazione del supervisore.
- 2026-10-10 — T01 done. T02 done: Godot 4.7.2, JDK 17, SDK (build-tools 35.0.1, android-35, NDK 28.1), template 4.7.2 (percorsi in CLAUDE.md). T03 done: TV AFTKRT già su adb. T04 ∥ T05 avviati.
- 2026-10-10 — T04 done (screenshot ok). T05 done (test_server PASS). T06 done: server in main.gd, URL LAN sulla Label, parse JSON senza log d'errore. Nota T07: includere `*.html` nel filtro di esportazione.
- 2026-10-10 — T07 done: APK armeabi-v7a sulla TV, 60 FPS a regime (11 all'avvio). Fix: IP LAN con priorità 192.168 (la TV ha una VPN su tun0); usare solo l'adb dell'SDK. Da sistemare più avanti: icona del progetto; app non visibile nel launcher (serve Gradle + leanback).
- 2026-10-10 — T08 done: M0 CHIUSA (telecomando, telefono, screensaver ok). Task M1 e contratti scritti. Prossimo: nuova sessione → T10–T13 in parallelo.
- 2026-10-10 — T10 done. T11–T13 fatti ma provvisori: il supervisore vuole il livello di Buzz PS3 (rif. in `ref/`). Aperta la "Prova visiva" V1–V4 prima di T14.
- 2026-10-10 — V2 (studio neon, 4 luci, MultiMesh) e V3 (HUD stile ref 5/4) done, verificati insieme su screenshot. Da sistemare in V4: inquadratura (presentatore e pannelli coprono i concorrenti). V1: supervisore su Meshy (3D Model → Text to 3D, Meshy 6, Smart Topology, Rigging, GLB).
- 2026-10-13 — Voce del presentatore "Lello Splendore" (showman provocatore, non legge le domande): 56 battute in `assets/voice/` generate con `tools/gen_voice.mjs` (ElevenLabs v3, voce Voice Design, Creative). Chiave in variabile utente ELEVENLABS_API_KEY. Personaggi: modelli Mixamo in `3dmodel/` (non ancora nel repo), nomi fissi: Don Polpetta, Madame Smeralda, Zippo, Lola Bigodina, Zio Zombi, Elvio Panzerotto, El Macho.
- 2026-10-13 — Personaggi Mixamo in `assets/models/characters/` (polpetta, smeralda, zippo, lola, zombi, elvio, macho) + 17 animazioni Mixamo in `assets/animations/`; `stage/character.gd` le ripunta sullo scheletro di ogni modello (ok sui 7 Mixamo). Presentatore Meshy: rig incompatibile (assi diversi, 31 ossa, pesi difettosi) → da ririggare con l'auto-rigger di Mixamo.
- 2026-10-13 — Nuovo presentatore `host.fbx` (Meshy in T-pose → Blender: 1 mesh, 20k tris, OBJ zip → auto-rigger Mixamo): tutte le animazioni ok. Per altri modelli Meshy: `blender -b --python tools/meshy_to_mixamo.py -- <fbx> <albedo.png> <cartella>` → caricare lo zip su Mixamo.
- 2026-10-13 — Contratti V4 in PLAN.md ("Contratti prova visiva"). V4 pronto con prompt del worker in TASKS.md. Prossimo: nuova sessione → lanciare V4 (worker, medium) → verificare i frame → misura FPS sulla TV.
- 2026-10-13 — host.fbx ririggato (piedi a z=0, cm). V4 base + V5 look fatti. Supervisore: "statico, banale, lontano anni luce". Deciso: prima la regia (R1–R7), poi i round (tutti approvati, PLAN.md §4 "Contratti regia"), poi lo studio 3D vero.
- 2026-10-13 — R1–R6 done: animazioni walk/strut/point/laugh/taunt fatte in Blender (`tools/make_anims.py`, keyframe a mano), director.gd (camere mobili + stacchi), Sfx autoload (Kenney CC0 + suoni sintetizzati: da far ascoltare al supervisore), HUD animato, main collegato (presentatore entra da dietro i podi, gira durante la domanda, sfotte chi sbaglia). Prossimo: R7 FPS sulla TV.
- 2026-10-13 — R7: sulla TV l'app moriva per memoria (GL 610 MB, lowmemorykiller) → causa `env.adjustment_*` (LUT RGBAFloat che perde memoria ogni frame su PowerVR GE9215): tolto. Ora stabile (~180 MB GL). FPS 11–27: bisezione sulla TV → personaggi + HUD + logica ≈ 60 FPS da soli; **lo studio è il collo di bottiglia** (overdraw: pavimento trasparente sopra copie specchiate, pubblico/coni/bagliori trasparenti), non le luci né i triangoli. Attivati `force_vertex_shading` (+40%), MSAA 2x, glow off, texture personaggi max 1024. Strumento: `bash tools/perf.sh build|run [s]` (log `PERF fps=` attivo solo con user://perf.txt). Prossimo: R8.
- 2026-10-13 — R8 done (obiettivo cambiato): studio opaco (via specchio, coni, bagliori, sagome trasparenti; gradinate 4 gradini) → da ~13 a ~40 FPS, ma HUD+personaggi tengono la domanda a ~32. Strategia: **30 FPS fissi** (`run/max_fps=30`) + MSAA off → 30 stabili in tutte le fasi. `scaling_3d/scale` <1 sulla TV fa ripartire il leak RGBAFloat: non usarlo.
- 2026-10-13 — **CAMBIO DI STRATEGIA (approvato dal supervisore): grafica 2D pre-renderizzata**, come Jackbox (2D) ma con look da render. Il 3D dal vivo su GE9215 a 1080p non regge (max ~32–40 FPS anche con lo studio spogliato). Nuovo metodo: studio renderizzato in Blender (EEVEE) come fondale per inquadratura + personaggi renderizzati come sequenze di sprite RGBA (~10 fps, holdout dei podi già nel render) + HUD sopra. Prova P1 (`tools/prerender_preview.py`, anteprima "moltissimo bello") e P2 (`tests/prerender_test.tscn`: fondale + 5 sprite animati) sulla TV: **60 FPS fissi, GL 50 MB** (prima 180). Sprite ~300×540 px ≈ 0,6 MB RGBA8 (da comprimere). Note: gli FBX dei concorrenti sono FBX 6100 (Blender 5.2 non li legge) → convertiti in .glb con Godot headless, finiti nello scratchpad: vanno rigenerati nel repo. Da migliorare nello studio: pubblico (birilli), podi (scatole), schermi laterali troppo accesi, meno viola/più notte neon. **Prossimo:** nuova sessione → il padre riscrive in PLAN.md l'architettura 2D (inquadrature, lista animazioni per personaggio, maschere luci per i mood, budget memoria, HUD opaco, regia a stacchi/zoom) e i task della milestone; il codice 3D (stage.gd, director.gd, character.gd) verrà sostituito.
- 2026-10-13 — Scritta l'architettura M1-2D (pre-render Blender) e fatto D1 (glb), poi **sospesa**: il supervisore ha portato il design system "Quizzone!" di Claude Design (2D vettoriale cutout, già pensato per Godot e GE9215). Approvato di provarlo con i nomi del design (le battute con i nomi andranno rigenerate su ElevenLabs). Q1 fatto, Q2 ∥ Q3 lanciati.
