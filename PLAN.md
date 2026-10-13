# PLAN.md — Quiz Party 3D per Fire TV

> Piano operativo. Nasce da [INITIAL_PLAN.md](INITIAL_PLAN.md) (la visione originale, che resta invariata) e dalle decisioni prese insieme.
> Ultimo aggiornamento: 2026-10-10.

---

## 1. Ruoli

| Chi | Cosa fa |
|---|---|
| **Claude** | Scrive tutto: codice Godot, pagina web per il telefono, domande, script, configurazione, test. |
| **Supervisore (tu)** | Decide, approva ogni milestone, fa le azioni fisiche (TV, telefoni), giudica l'estetica, rivede le domande, fa il playtest. |

Claude **non vede lo schermo**: verifica la grafica con screenshot generati dal gioco, ma il giudizio estetico finale spetta al supervisore.

Come lavora Claude (sessione padre + worker in parallelo, regole anti-spreco): vedi [CLAUDE.md](CLAUDE.md). Stato dei task: [TASKS.md](TASKS.md).

---

## 2. Decisioni prese

| Tema | Decisione | Motivo |
|---|---|---|
| Dispositivo TV | **Fire TV Stick 4K Max 2ª gen** (AFTKRT, Fire OS 8.1 = Android 11, GPU PowerVR GE9215, GLES 3.2, Vulkan 1.1, output 1920×1080, IP 192.168.1.61, già collegata via adb) | Già posseduto; accetta APK installati manualmente |
| Uso | Privato, a casa, con amici | Niente store, niente account, niente pubblicazione |
| Budget | **Solo strumenti e asset gratuiti** | — |
| Motore | **Godot 4.x stabile**, **renderer Compatibility** (OpenGL ES 3) dal primo giorno | Prestazioni native sulla Stick; ciò che si vede sul PC è vicino a ciò che si vedrà sulla TV |
| Linguaggio del gioco | GDScript | Lo scrive Claude |
| Controller dei giocatori | Pagina web (HTML/JS semplice) aperta dal browser del telefono | Nessuna app da installare |
| Rete | **Wi-Fi locale: la Fire TV fa da server** (HTTP per la pagina, WebSocket per i messaggi) | Nessun servizio esterno, nessun costo |
| Modalità di gioco v1 | **Una sola: "Classica"** (tutti rispondono, chi indovina prende punti) | Le altre modalità si costruiscono sopra questa |
| Presentatore | **Mascotte** (es. robot con il volto su uno schermo, o pupazzo): niente lip-sync realistico | È la parte più costosa; una mascotte la rende fattibile |
| Voce | **TTS offline gratuito (Piper, voci italiane)**, battute generate in anticipo | Gratis, nessun cloud |
| Lingua | Italiano | — |

### Alternative scartate
- **Stack web (React + Three.js):** WebGL nel browser della Stick è più lento, il browser non può fare da server locale e manca un editor per la regia. Il vantaggio "conosco JS" decade perché il codice lo scrive Claude.
- **Backend cloud:** non serve per l'uso in casa.
- **Modellare personaggi da zero in Blender:** troppo costoso. Si usano asset CC0; Blender serve solo per ritocchi.
- **Git LFS:** rimandato finché gli asset non pesano davvero.

---

## 3. Regole della modalità "Classica" (v1)

Ispirata al Point Builder di Buzz, con regole e valori nostri:

1. Il presentatore annuncia la domanda (categoria + testo).
2. Compaiono 4 risposte (colori fissi: blu, arancione, verde, giallo) e parte il timer (**15 s**, configurabile).
3. Ogni giocatore risponde **una sola volta**: la prima risposta è definitiva.
4. Il round si chiude allo scadere del timer **oppure** quando hanno risposto tutti.
5. Si rivela la risposta corretta: **+100 punti** a chi ha indovinato, 0 a chi ha sbagliato o non ha risposto.
6. Classifica, battuta del presentatore, domanda successiva.
7. Dopo **N domande** (demo: 3, partita: 10) vengono la classifica finale e la scena di vittoria.

Tutti i valori (punti, timer, numero di domande) stanno in un solo punto del codice.

---

## 4. Architettura

### Principio
La grafica **non contiene regole**. La logica di gioco emette segnali Godot; la regia (scena, HUD, audio) li ascolta e reagisce.

```
Tastiera / Telecomando / Telefoni ──► game.submit_answer(player_id, choice)
                                              │
                                     game.gd (regole pure)
                                              │  segnali: phase_changed, answer_received,
                                              │           answers_revealed, game_over
                                              ▼
                               stage.gd (regia) · hud.gd (testi) · audio
```

Tutti gli input passano dalla **stessa funzione** `submit_answer`. Sostituire la tastiera con i telefoni non tocca le regole.

### Stati della partita
`MENU → LOBBY → INTRO → QUESTION → REVEAL → SCOREBOARD → (QUESTION … ) → FINAL → MENU`

### File (solo quelli necessari: si aggiungono quando servono)

```
BUZZ/
├── project.godot
├── main.tscn / main.gd          # avvio, collega game ↔ regia ↔ input
├── game/
│   ├── game.gd                  # stati, timer, punteggi, validazione (nessun nodo grafico)
│   └── questions.json
├── stage/
│   ├── stage.tscn / stage.gd    # palco, podi, luci, telecamere, presentatore, effetti
├── ui/
│   └── hud.tscn / hud.gd        # domanda, risposte, timer, classifica
├── net/
│   ├── server.gd                # (M2) HTTP + WebSocket sulla Fire TV
│   └── controller.html          # (M2) pagina per il telefono
├── assets/                      # modelli, audio, font (con file LICENSES.md)
└── tests/
    └── test_game.gd             # test delle regole, eseguibile da riga di comando
```

### Contratti M1 (interfacce fisse: i worker in parallelo si basano su queste)

**`game/game.gd`** — `class_name Game extends RefCounted`, nessun nodo, nessun timer di Godot: il tempo avanza solo con `tick(delta)`.
```
enum Phase { MENU, INTRO, QUESTION, REVEAL, SCOREBOARD, FINAL }
signal phase_changed(phase: Phase)
signal question_started(index: int, total: int, q: Dictionary)   # q = {category, question, answers[4] già mescolate, correct}
signal answer_received(player_id: int)
signal question_resolved(correct: int, results: Dictionary, scores: Dictionary)  # results: id→bool, scores: id→int
signal game_over(ranking: Array)                                 # [{id, name, score}] ordinato
func setup(player_names: Array[String], questions: Array, num_questions: int) -> void
func start() -> void              # MENU → INTRO
func advance() -> void            # INTRO→QUESTION, REVEAL→SCOREBOARD, SCOREBOARD→QUESTION|FINAL
func submit_answer(player_id: int, choice: int) -> bool   # false se non valida (vedi §4 validazione)
func tick(delta: float) -> void   # solo in QUESTION: scaduto il tempo o risposto tutti → REVEAL
func time_left() -> float
```
Costanti in cima al file: `QUESTION_TIME := 15.0`, `POINTS_CORRECT := 100`. Player id = indice in `player_names`.

**`stage/stage.tscn` + `stage.gd`** — solo grafica, nessuna regola.
```
func setup_players(names: Array[String]) -> void    # mostra N podi (max 6) con nome e punteggio
func play_intro() -> void                           # transizione di camera verso il palco; emette intro_finished
func focus_question() -> void                       # inquadratura domanda, luci "tensione"
func show_reveal(results: Dictionary) -> void       # podi verdi/rossi
func update_scores(scores: Dictionary) -> void
func celebrate(winner_id: int) -> void              # luci + coriandoli sul vincitore
signal intro_finished
```
Contiene un `Marker3D` chiamato `HostSpot` dove `main` piazza il presentatore.

**`stage/host.tscn` + `host.gd`** — `func play(anim: String) -> void` con almeno `"idle"`, `"talk"`, `"surprise"`, `"celebrate"` (nomi mappati sulle animazioni reali del modello).

**`ui/hud.tscn` + `hud.gd`** — `CanvasLayer`, solo testi/UI.
```
func show_menu() -> void                            # titolo + "Premi OK per iniziare"
func show_question(index: int, total: int, q: Dictionary) -> void   # categoria, testo, 4 risposte (blu, arancione, verde, giallo)
func set_time(left: float, total: float) -> void    # barra/numero del timer
func mark_answered(player_id: int) -> void          # indicatore "ha risposto"
func show_reveal(correct: int) -> void              # evidenzia la giusta, attenua le altre
func show_scoreboard(ranking: Array) -> void
func show_final(ranking: Array) -> void
func hide_all() -> void
```
Testi leggibili da 3 m: domanda ≥ 56 px, risposte ≥ 44 px, margini di sicurezza 5%.

### Formato domande (`questions.json`)
```json
[
  {
    "category": "Geografia",
    "question": "Qual è il fiume più lungo d'Italia?",
    "answers": ["Po", "Tevere", "Adige", "Arno"],
    "correct": 0
  }
]
```
L'ordine delle risposte viene mescolato a ogni partita.

### Contratti prova visiva (V4) — stato reale del codice al 2026-10-13
Le API di M1 restano valide per `game/game.gd` (sopra). Cambiano/si aggiungono:

**`stage/stage.gd`** (stage.tscn): stesse funzioni di M1 (`setup_players(names)`, `play_intro()`→`intro_finished`, `focus_question()`, `show_reveal(results)`, `update_scores(scores)`, `celebrate(winner_id)`), più i `Marker3D` figli diretti `HostSpot` e `PlayerSpot0`…`PlayerSpot5` (+Z verso la camera; `setup_players` riposiziona i primi N in arco). `const GLOW` in cima per spegnere il glow.

**`ui/hud.gd`** (hud.tscn, CanvasLayer): `show_menu()`, `setup_players(names, portraits)` (portraits: Texture2D o null → quadrato colorato con iniziale), `show_question(index, total, q)`, `set_time(left, total)`, `mark_answered(id)`, `show_reveal(correct, results)` (✓/✗ per giocatore), `update_scores(scores)`, `show_scoreboard(ranking)`, `show_final(ranking)`, `hide_all()`. Layout: barra domanda in alto, risposte a sinistra (x 96–600), giocatori a destra (x 1380–1824); il centro è libero per il 3D.

**`stage/character.gd`** (script, niente .tscn): `var c := preload("res://stage/character.gd").new(); add_child(c); c.setup(path, height := 1.8); c.play(anim)`. Animazioni: loop `idle happy talk talk2 think zombie_idle dance_hiphop dance_rumba dance_silly dance_thriller`; una volta e poi idle `cheer victory defeated disappointed clap surprised rally`.

**Personaggi** (`assets/models/characters/`): presentatore `host.fbx` = **Lello Splendore**. Concorrenti (file → nome → chiave voce): `polpetta.fbx` Don Polpetta `polpetta` · `smeralda.fbx` Madame Smeralda `smeralda` · `zippo.fbx` Zippo `zippo` (altezza 1.4) · `lola.fbx` Lola Bigodina `lola` · `zombi.fbx` Zio Zombi `zombi` · `elvio.fbx` Elvio Panzerotto `elvio` · `macho.fbx` El Macho `macho`.

**Voce** (`assets/voice/<id>.mp3`, testi in `lines.json`): gruppi per prefisso, si sceglie a caso evitando l'ultima usata del gruppo. Generali: `menu_ intro_ qfirst_ qnext_ qlast_ firstbuzz_ nobody_ hurry_ allright_ noneright_ someright_ scores_ tie_ final_ outro_ filler_`. Per personaggio: `pres_<chiave>` (presentazione), `solo_<chiave>` (unico che indovina), `last_<chiave>` (ultimo in classifica), `win_<chiave>` (vince). Il presentatore NON legge le domande. Nuove battute: aggiungerle a `lines.json` e lanciare `node tools/gen_voice.mjs --go <id>` (crediti contati: genera solo i file mancanti).

### Contratti regia (R) — 2026-10-13
Giudizio del supervisore su V5: "statico, banale". Si dà vita alla scena prima di tutto il resto.

**`stage/director.gd`** (extends Node, possiede la camera): `var d := preload("res://stage/director.gd").new(); add_child(d); d.setup(stage.cam, stage, host)`. `shot(name: String, focus := -1)` con `name` in `intro wide question host player reveal scores winner`; `shake(strength := 1.0)`. Regole: la camera **non è mai ferma** (carrellata, orbita o avvicinamento lento); dentro uno shot ci sono 2–3 inquadrature con **stacchi netti** ogni 3–6 s; `player`/`winner` usano `focus` (indice concorrente); `host` segue il presentatore mentre cammina; `question` lascia libera la fascia centrale (x 620–1380, y > 240) e mostra i concorrenti. `stage.gd` non muove più la camera (resta `intro_finished` dopo ~3 s).

**`stage/character.gd`** (aggiunte): `walk_to(pos: Vector3, anim := "walk") -> void` (si gira, cammina a velocità realistica, emette `arrived`), `face(pos: Vector3)`. Animazioni nuove: `walk strut` (loop, in place), `point laugh taunt` (una volta).

**`audio/sfx.gd`** (autoload `Sfx`, registrato dal padre): `play(name, vol_db := 0.0)`, `music(name)` (dissolvenza 1 s), `stop_music()`, `duck(on: bool)` (musica −12 dB mentre parla il presentatore). Effetti: `buzz correct wrong tick tick_fast whoosh pop applause aww drumroll fanfare explosion cash boing`. Musiche (loop): `menu question scores final`. File `.ogg` in `assets/audio/sfx|music/`, solo CC0.

**`ui/hud.gd`**: stessa API, ma tutto entra ed esce animato (scivola/rimbalza), i punteggi contano in su, il timer pulsa negli ultimi 5 s, il reveal lampeggia.

**Round (da progettare dopo la regia, tutti approvati):** Furto, Sabotaggio (dispetto privato sul telefono del primo), Patata Bollente, La Talpa, Lello Bugiardo, Più o Meno (cursore sul telefono), La Botola (finale: chi sbaglia sprofonda).

### Protocollo con i telefoni (M2)
Messaggi JSON su WebSocket.

| Direzione | Messaggio | Contenuto |
|---|---|---|
| telefono → TV | `join` | `name`, `avatar`, `player_id` (se si sta riconnettendo) |
| telefono → TV | `answer` | `question_index`, `choice` (0–3) |
| TV → telefono | `welcome` | `player_id`, colore assegnato |
| TV → telefono | `state` | fase corrente, eventuale domanda attiva |
| TV → telefono | `result` | corretta sì/no, punti, posizione |

**Validazione sul lato TV** (la TV è l'unica autorità):
- il giocatore esiste;
- la fase è `QUESTION`;
- la domanda è quella attiva;
- il giocatore non ha già risposto;
- il tempo non è scaduto (misurato sulla TV, non sul telefono);
- tutto il resto viene ignorato.

**Riconnessione:** il telefono salva `player_id` nel `localStorage` e lo rimanda al `join`.

---

## 5. Asset (tutti gratuiti)

| Tipo | Fonte | Licenza |
|---|---|---|
| Personaggi e oggetti 3D | Quaternius, KayKit, Kenney | CC0 |
| Animazioni extra | Mixamo | gratuita, uso nei giochi consentito |
| Palco | primitive Godot + materiali semplici | — |
| Voce del presentatore | Piper TTS (voci italiane) | open source; da verificare la licenza di ogni voce |
| Musica / effetti | Kenney audio, Freesound (solo CC0) | CC0 |
| Font | Google Fonts | OFL |
| Domande | generate da Claude, **riviste dal supervisore** | — |

Ogni asset viene annotato in `assets/LICENSES.md`.
Niente asset, nomi, personaggi o audio di Buzz/Sony.

---

## 6. Roadmap

Ogni milestone si chiude solo con **l'approvazione del supervisore**.

### M0 — Prova tecnica (elimina i rischi) ✅ chiusa 2026-10-10 (60 FPS sulla TV, telefono e telecomando ok)
Obiettivo: dimostrare che le due incognite reali funzionano prima di costruire il gioco.

- [x] Godot installato; progetto con renderer Compatibility, 1920×1080
- [x] Scena di prova: cubo 3D animato + contatore FPS
- [x] Toolchain Android pronta (JDK, Android SDK, keystore di debug), tutto gratuito
- [x] APK installato sulla Fire TV via `adb` in Wi-Fi
- [x] Il tasto centrale del telecomando cambia colore al cubo
- [x] Il telefono apre `http://<IP-TV>:8080`, preme un pulsante, il cubo cambia colore
- [x] FPS misurati sulla TV (obiettivo ≥ 30 stabili); lo schermo non va in screensaver

**Se fallisce:** la rete locale non va → valutiamo l'hotspot del telefono o un relay. Le prestazioni sono scarse → grafica più semplice o risoluzione 3D ridotta.

### M1 — Vertical slice (PC, poi verifica sulla TV)
Una sequenza giocabile di 60–90 secondi che sembri già un quiz televisivo.

- [ ] Il gioco parte dal menu principale
- [ ] La telecamera entra sul palco con una transizione
- [ ] Il presentatore (placeholder CC0) esegue almeno 3 animazioni
- [ ] Domanda + 4 risposte leggibili da 3 metri
- [ ] Giocatore 1 da tastiera (tasti `1`–`4`); gli altri sono bot con risposte casuali
- [ ] Timer → rivelazione della risposta corretta
- [ ] Punteggi aggiornati + classifica
- [ ] Fine con scena di vittoria e coriandoli
- [ ] `tests/test_game.gd` passa (regole, punteggi, risposte doppie/tardive)
- [ ] Gira sulla Fire TV a ≥ 30 FPS

### M2 — Telefoni come controller
- [ ] QR code + indirizzo visibili sulla TV nella lobby
- [ ] Pagina telefono: nome, colore/avatar, 4 pulsanti grandi
- [ ] Da 2 a 6 giocatori reali
- [ ] Risposte doppie, tardive o fuori fase ignorate
- [ ] Riconnessione dopo una disconnessione o dopo aver bloccato il telefono
- [ ] Tastiera e bot restano disponibili per i test

### M3 — Presentatore, audio e rifinitura
- [ ] Mascotte definitiva scelta dal supervisore
- [ ] Battute TTS: intro, domanda, risposte giuste/sbagliate, provocazioni, finale
- [ ] Bocca/espressioni sincronizzate al volume della voce
- [ ] Musica, effetti sonori, luci che cambiano col timer
- [ ] Palette e identità visiva coerenti

### M4 — Contenuti e modalità
- [ ] 100+ domande in categorie, riviste
- [ ] Seconda modalità (da scegliere: es. "Più veloce vince", punti in base alla velocità)
- [ ] Nome e logo definitivi del gioco

---

## 7. Cosa deve fare il supervisore (azioni fisiche)

| Quando | Azione |
|---|---|
| M0 | Sulla Fire TV: *Impostazioni → La mia Fire TV → Informazioni*, cliccare 7 volte sul nome del dispositivo → attivare **Debug ADB** e **App di origine sconosciuta** |
| M0 | Leggere l'IP della TV (*Informazioni → Rete*) |
| M0 | Dire quale generazione di 4K Max è (*Informazioni*) |
| M0+ | Accettare sulla TV la richiesta di debug dal PC |
| Ogni milestone | Provare sulla TV e approvare o chiedere modifiche |
| M1+ | Rivedere le domande generate |

---

## 8. Rischi

| Rischio | Probabilità | Mitigazione |
|---|---|---|
| Prestazioni 3D scarse sulla Stick | Media | Renderer Compatibility da subito, test in M0/M1, risoluzione 3D ridotta, ombre limitate |
| Router che blocca la comunicazione tra dispositivi (rete ospiti, isolamento client) | Bassa a casa | Usare la rete principale; in alternativa l'hotspot del telefono |
| Input del telecomando Fire TV mappato male in Godot | Bassa | Verifica in M0 |
| Screensaver della TV durante la partita | Media | Mantenere lo schermo acceso dal gioco (verifica in M0) |
| Godot non ha un server HTTP pronto | Certa | Server minimale scritto da Claude su `TCPServer` (serve solo una pagina) |
| QR code: Godot non lo genera nativamente | Certa | Addon open source o mostrare solo l'indirizzo IP (da decidere in M2) |
| Qualità delle voci TTS italiane | Media | Provare più voci Piper; il tono può reggersi sulle battute scritte |
| Domande sbagliate | Media | Revisione del supervisore |

---

## 9. Decisioni ancora aperte

- Nome e identità del gioco (per ora: nome di lavoro "BUZZ", **solo interno**).
- Aspetto della mascotte-presentatore (Claude proporrà opzioni in M3).
- Numero di domande per partita e durata del timer definitivi (dopo il playtest).
- Seconda modalità di gioco (M4).

---

## Principio guida

**Prima togliere i rischi (M0), poi una demo piccola e spettacolare (M1), poi i telefoni (M2), infine personalità e contenuti (M3–M4).**
