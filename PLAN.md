# PLAN.md — Quizzone! (quiz party 2D per Fire TV)

> Piano operativo. Ultimo aggiornamento: 2026-10-13 (passaggio al design "Quizzone!", 3D abbandonato).
> Storia delle prove 3D / pre-render: nella cronologia git (commit fino a `128fb16`).

---

## 1. Ruoli
| Chi | Cosa fa |
|---|---|
| **Claude** | Scrive tutto: codice Godot, pagina del telefono, domande, battute, script, test. |
| **Supervisore** | Decide, approva ogni milestone, prova sulla TV, giudica estetica e battute, fa il playtest. |

Come lavora Claude (padre + worker, regole anti-spreco): [CLAUDE.md](CLAUDE.md). Stato dei task: [TASKS.md](TASKS.md).

---

## 2. Decisioni prese
| Tema | Decisione | Motivo |
|---|---|---|
| Dispositivo | Fire TV Stick 4K Max 2ª gen (AFTKRT, PowerVR GE9215, GLES 3.2, 1920×1080, adb in Wi-Fi) | Già posseduta |
| Uso | Privato, a casa, con amici. Solo strumenti/asset gratuiti | — |
| Motore | Godot 4.x, renderer Compatibility, GDScript tipizzato | Nativo sulla Stick |
| **Grafica** | **2D vettoriale "Quizzone!"** (design system in `design/quizzone/`, README = fonte di verità visiva): pannelli piatti, contorni spessi, ombre dure, personaggi cutout animati da codice. Niente shader/blur | Prova sulla TV: **60 FPS fissi, ~65 MB GL** (il 3D faceva 30–35 FPS, 180 MB) |
| Personaggi | Presentatore **Tony Scintilla**; concorrenti Gastone (chef), Nonna Pina (nonna), Ugo (zombi), Brioche (gatto), Don Ciccio (boss), Vanessa (diva) | Dal design |
| Voce | ElevenLabs v3, battute pre-generate (`tools/gen_voice.mjs`, testi in `assets/voice/lines.json`); lip-sync dal volume | Già funzionante |
| Sottotitoli | Fumetto con il testo di Tony, attivabile/disattivabile dal titolo (salvato in `user://impostazioni.cfg`) | Accessibilità |
| Controller | Pagina web sul telefono (WebSocket verso la TV); tastiera/telecomando + bot per i test | Nessuna app da installare |
| Lingua | Italiano | — |

---

## 3. Regole
**Accumula Punti (base):** 4 risposte (A rombo, B cerchio, C triangolo, D quadrato), timer 15 s, una risposta per giocatore (definitiva), il round finisce allo scadere o quando hanno risposto tutti, **+500** a chi indovina. Valori in un solo punto (`game/game.gd`).

**Mini-giochi** (README del design, sezione "Mini-giochi"): Dito Veloce (punti che scendono col tempo), Passa la Bomba (chi ha la bomba quando esplode −500), Ruba Punti (chi indovina ruba a una vittima), Torta in Faccia (duello 1 contro 1), Metti in Ordine, Foto Misteriosa (tasselli che si scoprono), **Conto alla Rovescia** (finale: −50 punti/s finché non rispondi giusto).

**Partita:** Titolo → Lobby → N round (presentazione del round + domande) → Conto alla Rovescia → Classifica finale → Titolo.

---

## 4. Architettura
La logica non contiene grafica: `game/game.gd` emette segnali, le schermate li ascoltano. Tutti gli input (tastiera, telecomando, telefoni, bot) passano da `submit_answer(player_id, choice)`.

```
BUZZ/
├── project.godot · main.tscn/main.gd      # flusso della partita, collega game ↔ schermate ↔ input ↔ voce
├── game/game.gd · questions.json          # regole pure + domande
├── ui/                                     # schermate e componenti (costruiti da codice)
│   ├── palco.gd · risposta.gd · podio.gd · schermata_domanda.gd · personaggio.gd
├── net/server.gd · controller.html        # HTTP 8080 + WebSocket 8081 sulla TV
├── audio/sfx.gd                            # autoload Sfx (effetti + musica)
├── assets/ personaggi/ palco/ fonts/ voice/ audio/   (licenze: assets/LICENSES.md)
├── design/quizzone/                        # design system (con .gdignore): README, .dc.html, SVG sorgente
├── tools/ svg_to_png.gd · palco.html · gen_voice.mjs · perf.sh
└── tests/ test_game.gd · test_server.gd · test_personaggi.* · test_domanda.* · quizzone_test.* (prova completa)
```

### Contratti dei componenti (già fatti)
- `Personaggio` (`ui/personaggio.gd`, Node2D, coordinate = tela del design 200×200, host 240×300): `setup(id)`, `espressione(e)` (neutro felice triste sorpreso arrabbiato), `stato(s)` (attesa pensa risposto esulta sconfitta sorpreso), `gesto(g, durata)` solo host (saluto annuncio esulta delusione sorpresa), `parla(stream)` → `finito_parlare`. Pezzi generati da `tools/svg_to_png.gd` in `assets/personaggi/<id>/` + `pezzi.json`.
- `Palco` (`ui/palco.gd`): fondale `assets/palco/palco.png` (da `tools/palco.html` con Chrome headless) + lampadine.
- `Risposta`: `setup(lettera, testo)`, `set_stato(normale|giusta|sbagliata)`, `aggiungi_gettone(colore, num)`, `set_gettoni(lista)`, `entra(ritardo)`; statiche `font_display()`, `font_testo()`, `etichetta(...)`, `box(...)`.
- `Podio`: `setup(nome, colore, numero, punti)`, `metti_personaggio(p)`, `set_stato(''|ok|ko|risposto|bomba|mira)` (imposta anche lo stato del personaggio), `badge(testo, scuro)`, `set_punti(n)`.
- `SchermataDomanda`: `setup_podi(giocatori)`, `podio(i)`, `mostra_domanda(n, tot, titolo_round, testo, risposte)`, `set_tempo(left, total)`, `risposto(pid, scelta)`, `rivela(corretta, scelte, punti)`.

### Formato domande (`questions.json`)
`{"category": "...", "question": "...", "answers": ["...", "...", "...", "..."], "correct": 0}`

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

## 5. Roadmap
Ogni milestone si chiude con l'approvazione del supervisore sulla TV.

### M0 — Prova tecnica ✅ (2026-10-10) · Prova Quizzone ✅ (2026-10-13: 60 FPS, approvata)

### G1 — Partita completa da telecomando (bot al posto degli amici)
- [ ] Titolo (1a) con opzione sottotitoli
- [ ] Lobby (1b): giocatore 1 da telecomando + bot, scelta del numero di giocatori (2–6)
- [ ] Presentazione round (1c)
- [ ] 10 domande Accumula Punti con Tony che commenta (entra/esce, battute per situazione)
- [ ] Classifica finale (1f) con coriandoli e vincitore che esulta
- [ ] Battute nuove con i nomi di Tony e dei 6 concorrenti (ElevenLabs)
- [ ] App avviabile dal launcher della Fire TV (icona, leanback)

### G2 — Telefoni come controller
- [ ] Lobby con QR + indirizzo + codice; il telefono sceglie personaggio e nome (1l)
- [ ] 4 tasti con forma e testo (1m), risposta bloccata (1n), esito sul telefono
- [ ] 2–6 giocatori reali, riconnessione, input non validi ignorati

### G3 — Mini-giochi
- [ ] Dito Veloce · Passa la Bomba · Ruba Punti (+ schermata vittime sul telefono 1o)
- [ ] Torta in Faccia · Metti in Ordine · Foto Misteriosa (servono foto libere)
- [ ] Conto alla Rovescia come finale

### G4 — Contenuti e rifinitura
- [ ] 200+ domande in categorie, riviste dal supervisore
- [ ] Musica e effetti coerenti con lo stile
- [ ] Playtest con amici veri

---

## 6. Rischi
| Rischio | Mitigazione |
|---|---|
| Router che isola i dispositivi (rete ospiti) | Rete principale o hotspot del telefono |
| QR code: Godot non lo genera | Generatore QR in GDScript (algoritmo pubblico) o solo indirizzo + codice |
| Crediti ElevenLabs | Generare solo i file mancanti (`--go <id>`), testi rivisti prima |
| Domande sbagliate | Revisione del supervisore |
| Foto Misteriosa: immagini | Solo CC0 / pubblico dominio, in LICENSES.md |

## 7. Decisioni aperte
- Numero di round e domande per partita (dopo il playtest).
- Ordine e scelta dei mini-giochi in una partita (fissa o casuale).
