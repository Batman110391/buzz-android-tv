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
| **Co-conduttrice** | **Gilda Lampo** (approvata 2026-10-14): alla pari con Tony, lucida e ironica; tiene il ritmo, presenta round e classifica, smonta Tony con battute secche. Le situazioni pescano battute di entrambi + duetti (Tony → Gilda). Voce Voice Design sul 2° account ElevenLabs (`ELEVENLABS_API_KEY2`), Tony resta sul 1° | Meno ripetizioni, più "show", inclusività; raddoppia i crediti voce |
| Sottotitoli | Fumetto con il testo di Tony, attivabile/disattivabile dal titolo (salvato in `user://impostazioni.cfg`) | Accessibilità |
| **Minigiochi** (2026-10-14) | Ogni minigioco è un round. Prima della partita chi ha il telecomando sceglie quali giocare (tutti selezionati di default, minimo 4): così decide la durata. Primo rilascio, 8 selezionabili: Accumula Punti, Dito Veloce, Passa la Bomba, Ruba Punti, Torta in Faccia, Metti in Ordine, Foto Misteriosa, La risposta più vicina. **Conto alla Rovescia** chiude sempre la partita (non si toglie). **Duello degli indizi** parte da solo (recupero, sotto). Nuovi minigiochi arrivano con gli aggiornamenti dell'APK | Durata scelta senza menu complicati |
| **Duello degli indizi** | A metà partita, se tra primo e ultimo ci sono ≥ 3 risposte giuste di distanza (1.500 punti; soglia da tarare col playtest). Due squadre dalla classifica (3: 1°+3° / 2° · 4: 1°+4° / 2°+3° · 5: 1°+5° / 2°+3°+4° · 6: 1°+6°+5° / 2°+3°+4°; con 2 giocatori non c'è). Indizi uno alla volta, poi 4 risposte: il premio parte alto e **scende a ogni indizio sbloccato** (nessuno perde punti già fatti) | Dà una possibilità a chi è indietro senza annullare la partita |
| Controller | Pagina web sul telefono (WebSocket verso la TV); tastiera/telecomando + bot per i test | Nessuna app da installare |
| Lingua | Italiano | — |
| **Domande** | Servite da un **Cloudflare Worker + D1** (piano gratuito); la TV le scarica all'avvio e le tiene in cache; aggiornate da un cron del Worker che genera con **Gemini** e verifica con un modello **OpenRouter** diverso (§4 "Domande") | Domande nuove senza aggiornare l'app, costo zero |
| Dotazione iniziale | ~1.600 domande scritte da Claude (worker), incluse anche nell'APK come riserva offline | Si gioca anche senza rete; fanno da "set buono" per tarare i prompt |
| Foto Misteriosa | Immagini da **Pixabay** (API gratuita), scelte dal Worker | G3 |
| Segreti | Solo in `.env` sul PC (da `.env.example`, escluso da git) e nei segreti del Worker; mai nell'APK | Repo pubblico |
| Repository | Pubblico con licenza; gestisce le release dell'APK quando serve | — |

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
├── game/game.gd                            # regole pure (nessun nodo grafico)
├── game/domande.gd                         # (D5) carica le domande: cache → server → riserva; ricorda le uscite
├── domande/<tipo>/<categoria>.json         # (D2) dotazione iniziale = riserva offline nell'APK
├── ui/                                     # schermate e componenti (costruiti da codice)
│   ├── palco.gd · risposta.gd · podio.gd · schermata_domanda.gd · personaggio.gd
├── net/server.gd · controller.html        # HTTP 8080 + WebSocket 8081 sulla TV
├── audio/sfx.gd                            # autoload Sfx (effetti + musica)
├── assets/ personaggi/ palco/ fonts/ voice/ audio/   (licenze: assets/LICENSES.md)
├── design/quizzone/                        # design system (con .gdignore): README, .dc.html, SVG sorgente
├── server/                                 # (D4, con .gdignore) Cloudflare Worker: src/, schema.sql, wrangler.toml
├── tools/ svg_to_png.gd · palco.html · gen_voice.mjs · perf.sh
│   ├── domande_check.mjs · prompt_test.mjs · mock_api.mjs · prompts/ · fixtures/   # (D1–D3)
├── .env.example                            # variabili per gli script (copiare in .env, escluso da git)
└── tests/ test_game.gd · test_server.gd · test_personaggi.* · test_domanda.* · quizzone_test.* (prova completa)
```

### Contratti dei componenti (già fatti)
- `Personaggio` (`ui/personaggio.gd`, Node2D, coordinate = tela del design 200×200, host 240×300): `setup(id)`, `espressione(e)` (neutro felice triste sorpreso arrabbiato), `stato(s)` (attesa pensa risposto esulta sconfitta sorpreso), `gesto(g, durata)` solo host (saluto annuncio esulta delusione sorpresa), `parla(stream)` → `finito_parlare`. Pezzi generati da `tools/svg_to_png.gd` in `assets/personaggi/<id>/` + `pezzi.json`.
- `Palco` (`ui/palco.gd`): fondale `assets/palco/palco.png` (da `tools/palco.html` con Chrome headless) + lampadine.
- `Risposta`: `setup(lettera, testo)`, `set_stato(normale|giusta|sbagliata)`, `aggiungi_gettone(colore, num)`, `set_gettoni(lista)`, `entra(ritardo)`; statiche `font_display()`, `font_testo()`, `etichetta(...)`, `box(...)`.
- `Podio`: `setup(nome, colore, numero, punti)`, `metti_personaggio(p)`, `set_stato(''|ok|ko|risposto|bomba|mira)` (imposta anche lo stato del personaggio), `badge(testo, scuro)`, `set_punti(n)`.
- `SchermataDomanda`: `setup_podi(giocatori)`, `podio(i)`, `mostra_domanda(n, tot, titolo_round, testo, risposte)`, `set_tempo(left, total)`, `risposto(pid, scelta)`, `rivela(corretta, scelte, punti)`.

### Domande — contenuti, server, aggiornamento automatico (approvato 2026-10-13)

**Perché così.** Le domande cambiano spesso, l'app no: la TV le scarica da un server gratuito e le mette in cache. Un'IA genera, un'IA *diversa* verifica alla cieca, regole automatiche scartano il resto; le statistiche reali delle partite correggono la difficoltà e sospendono le domande sbagliate. Finché il server non c'è si lavora con i **mock** (sotto).

#### Tipi (divisi per *come si gioca*, non per gioco: molti giochi usano la stessa forma)
| Tipo | Giochi | Campi specifici | Lunghezze massime |
|---|---|---|---|
| `classica` | Accumula Punti, Ruba Punti, Torta in Faccia, Conto alla Rovescia | `risposte[4]` (la **giusta è sempre la prima**: il gioco mescola) | domanda 90, risposta 26 |
| `lampo` | Dito Veloce, Passa la Bomba | come `classica`, ma si capisce in 2 s | domanda 55, risposta 16 |
| `ordine` | Metti in Ordine | `criterio` ("Dal più antico al più recente"), `elementi[4]` **nell'ordine giusto**, `valori[4]` (1492, 1789…: si mostrano alla rivelazione e rendono l'ordine verificabile) | criterio 50, elemento 22, valore 14 |
| `foto` | Foto Misteriosa | `immagine` (URL Pixabay), `autore`, `pagina`, `risposte[4]` | (G3) |
| `stima` | La risposta più vicina | `valore` (numero esatto), `unita` ("km", "abitanti"); la stima si scrive sul telefono | (G3) |
| `indizi` | Duello degli indizi | `categoria_indizi` ("Personaggio storico"), `indizi[3]` dal più vago al più chiaro, `risposte[4]` | (G3) |

Le lunghezze vengono dal design: pannello domanda 1540 px a 60 px = 2 righe; carta risposta 848 px a 48 px. Contano i caratteri dopo il trim.

#### Campi comuni
```json
{"id":"cl-geo-0001","tipo":"classica","categoria":"geografia","difficolta":2,
 "domanda":"Qual è la capitale dell'Australia?",
 "risposte":["Canberra","Sydney","Melbourne","Perth"],
 "curiosita":"Fu costruita apposta per mettere d'accordo Sydney e Melbourne.",
 "fatto":"capitale australia canberra",
 "fonte":"https://it.wikipedia.org/wiki/Canberra",
 "origine":"claude","creata":"2026-10-13"}
```
- `id`: `<cl|la|or|fo>-<cat3>-<NNNN>`, unico e mai riusato.
- `fatto`: chiave breve del fatto chiesto, minuscole senza accenti né punteggiatura; due domande sullo stesso fatto = doppione (anche se scritte diversamente).
- `curiosita` (≤ 120): si mostra alla rivelazione ("Lo sapevi?").
- `fonte`: pagina dove il fatto si verifica (preferibilmente Wikipedia italiana).
- `origine`: `claude` | `gemini`; sul server si aggiungono `stato` (`attiva` | `sospesa`), `uscite`, `giuste`.

**Categorie (12, chiavi fisse):** `geografia` `storia` `scienza` `natura` (natura e animali) `cinema_tv` `musica` `sport` `cucina` `arte_letteratura` `lingua` (lingua italiana e modi di dire) `tecnologia` (tecnologia e invenzioni) `costume` (costume, giochi, vita quotidiana, curiosità).

**Difficoltà** (per un gruppo di amici adulti italiani, età miste): **1** la sa quasi chiunque · **2** circa metà del tavolo · **3** pochi, ma sentita la risposta si dice "ah, giusto!" (mai nozioni da specialisti). Dopo 20 uscite la difficoltà si ricalcola dai dati reali: ≥ 75% giuste → 1, 35–75% → 2, < 35% → 3; < 5% dopo 20 uscite → `sospesa` (probabilmente sbagliata).

**Regole di qualità** (stesse per Claude, Gemini e il verificatore):
1. Una sola risposta giusta, senza ambiguità né interpretazioni.
2. Sbagliate plausibili, dello stesso tipo e formato della giusta (tutte città, tutti anni…), di lunghezza simile; niente risposte-scherzo.
3. Vietati: negazioni ("quale NON…"), "tutte/nessuna delle precedenti", domande sul futuro, fatti che possono cambiare entro 5 anni (record, cariche, "l'attuale…"), opinioni, stereotipi, contenuti offensivi, politica di parte, tragedie recenti.
4. La domanda non contiene indizi della risposta; italiano corretto con accenti (È, perché); niente punto finale nelle risposte.
5. Varietà: niente due domande sullo stesso `fatto`; non più di 3 domande sullo stesso argomento ristretto per categoria.

#### Dotazione iniziale (D2, scritta da Claude)
Per categoria: 90 `classica` (30 per difficoltà) + 30 `lampo` + 15 `ordine` → **~1.620** domande in `domande/<tipo>/<categoria>.json` (array JSON). Una partita ne usa ~30 → ~50 partite senza ripetizioni. `tools/domande_check.mjs` valida tutto (schema, lunghezze, regole meccaniche, doppioni di `fatto` e di testo) ed esce con codice ≠ 0 se trova errori.

#### Prompt e banco di prova (D3)
- `tools/prompts/genera.md` (Gemini): ruolo, pubblico, regole di qualità, scala di difficoltà con 2 esempi per livello presi dalla dotazione, elenco dei `fatto` già presenti nella categoria, richiesta di N domande di un `tipo`/`categoria`/`difficolta`; uscita JSON con schema obbligato (`responseSchema`).
- `tools/prompts/verifica.md` (OpenRouter): riceve la domanda con le risposte **mescolate e senza indicare la giusta**; restituisce `scelta`, `sicurezza` 0–100, `difficolta` stimata, `problemi[]` (`ambigua` `piu_giuste` `errata` `superata` `indizio` `troppo_lunga` `offensiva` `noiosa`). **Accettata** se `scelta` = giusta, `sicurezza` ≥ 80 e `problemi` vuoto.
- `tools/prompt_test.mjs`: (a) set **buono** = campione della dotazione → il verificatore ne deve accettare ≥ 90%; (b) set **rotto** `tools/fixtures/rotte.json` (~60 domande sbagliate apposta: giusta errata, due giuste, superate, negazioni, indizi) → deve scartarne ≥ 90%; (c) generatore: ≥ 70% delle domande prodotte accettate, 0 errori di schema, 0 doppioni. Si ritoccano i prompt finché tutte e tre le soglie passano; i risultati si annotano in TASKS.md.
- Con `QUIZZONE_MOCK=1` (default) gli script leggono risposte finte da `tools/fixtures/` invece di chiamare le IA: si sviluppa e si testa tutto senza chiavi e senza consumare quote.

#### Server (D4): Cloudflare Worker + D1 in `server/`
| Endpoint | Chi | Cosa |
|---|---|---|
| `GET /v1/versione` | TV | `{"versione": 12, "totale": 1620}` — numero che sale a ogni inserimento/modifica |
| `GET /v1/domande` | TV | `{"versione": 12, "domande": [...]}` solo `attiva`, senza campi interni (compresso dal CDN) |
| `POST /v1/esiti` | TV a fine partita | `{"partita": "<uuid>", "esiti": [{"id": "...", "giocatori": 4, "giuste": 2}]}` — max 64 KB, max 60 esiti, id esistenti, numeri plausibili, altrimenti 400 |
| `POST /v1/segnala` | telefono (G2) | `{"id": "...", "motivo": "errata|ambigua|altro"}` — limite per IP |
| `POST /v1/admin/*` | supervisore | `Authorization: Bearer QUIZZONE_ADMIN_TOKEN`: sospendi/riattiva, lancia il cron a mano |
| cron (settimanale) | Worker | sceglie le combinazioni tipo/categoria/difficoltà più scarse → Gemini genera → regole meccaniche → OpenRouter verifica → inserisce le accettate (`origine: gemini`) → `versione`+1 |

Modelli in variabili del Worker (`GEMINI_MODEL`, `OPENROUTER_MODEL`): i modelli gratuiti cambiano, si sostituiscono senza toccare il codice. Chiavi con `wrangler secret put`. Limiti del piano gratuito (CPU per richiesta, sotto-richieste, scritture D1, cron) da ricontrollare sulla documentazione Cloudflare prima di scrivere il Worker.

#### Mock (finché il Worker non c'è)
`tools/mock_api.mjs` (Node, nessuna dipendenza): stesso contratto del Worker su `http://<IP del PC>:8787` (la porta di `wrangler dev`), serve la dotazione di `domande/` e scrive gli esiti ricevuti in un file nello scratchpad. Così il gioco (D5) si sviluppa contro l'API vera; passare al Worker = cambiare l'URL.

#### Client nel gioco (D5): `game/domande.gd`
All'avvio: `GET /v1/versione` (timeout 3 s) → se più nuova della cache scarica `/v1/domande` → **valida ogni domanda** come dato non fidato (tipo, categoria, lunghezze, 4 risposte, scarta il resto) → salva `user://domande.json`. Senza rete o con errori: cache, altrimenti la riserva `res://domande/`. Ricorda gli id usciti (`user://uscite.json`) e pesca prima i mai usciti. Sceglie per tipo/difficoltà secondo il round. A fine partita invia gli esiti (se fallisce, li ritenta la volta dopo). URL del server in `project.godot` (`quizzone/api_url`).

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
Domande: dalla riserva `domande/` (o dal mock) attraverso `game/domande.gd`; il Worker non serve ancora.

- [x] Titolo (1a) con opzione sottotitoli
- [x] Lobby (1b): giocatore 1 da telecomando + bot, scelta del numero di giocatori (2–6)
- [x] Presentazione round (1c)
- [x] 10 domande Accumula Punti con Tony che commenta (entra/esce, battute per situazione)
- [x] Classifica finale (1f) con coriandoli e vincitore che esulta
- [x] Battute nuove con i nomi di Tony e dei 6 concorrenti (ElevenLabs)
- [ ] App avviabile dal launcher della Fire TV (icona, leanback)

### D — Domande dal server (§4 "Domande"; può procedere in parallelo a G1)
- [x] D1 schema + `tools/domande_check.mjs` + `tools/mock_api.mjs`
- [ ] D2 dotazione iniziale ~1.620 domande (12 categorie), check verde
- [ ] D3 prompt `genera.md`/`verifica.md` + `prompt_test.mjs`: soglie passate prima in mock, poi con le chiavi vere
- [ ] D4 Worker + D1 + cron + endpoint, dotazione caricata, URL pubblico
- [ ] D5 `game/domande.gd`: cache, validazione, riserva, uscite, esiti; prova sulla TV senza rete e con rete

### C — Co-conduttrice Gilda Lampo (dopo G1h)
- [x] Voce (Voice Design, 3 anteprime, sceglie S)
- [x] Personaggio cutout nello stile del design (SVG a pezzi + rig come Tony), approvato da S
- [x] Due conduttori in `main`: mazzi con battute di entrambi, duetti, Gilda entra da destra con il suo fumetto
- [x] ~40 battute di Gilda + ~10 duetti (testi approvati da S)
- [ ] Dopo il 2026-11-10 le battute di Tony che diventano duetti

### G2 — Telefoni come controller
- [ ] Lobby con QR + indirizzo + codice; il telefono sceglie personaggio e nome (1l)
- [ ] 4 tasti con forma e testo (1m), risposta bloccata (1n), esito sul telefono
- [ ] 2–6 giocatori reali, riconnessione, input non validi ignorati

### G3 — Mini-giochi
- [ ] Dito Veloce · Passa la Bomba · Ruba Punti (+ schermata vittime sul telefono 1o)
- [ ] Torta in Faccia · Metti in Ordine · Foto Misteriosa (immagini Pixabay via API, scelte dal Worker; autore e pagina mostrati)
- [ ] Conto alla Rovescia come finale
- [ ] Schermata di scelta dei minigiochi prima della partita (telecomando; tutti accesi, minimo 4)
- [ ] La risposta più vicina (stima dal telefono, vince chi si avvicina di più)
- [ ] Duello degli indizi (recupero automatico a metà partita, squadre dalla classifica)

### G4 — Contenuti e rifinitura
- [ ] 200+ domande in categorie, riviste dal supervisore
- [ ] Musica e effetti coerenti con lo stile
- [ ] Playtest con amici veri
- [ ] Repo pubblico con licenza, README, release dell'APK firmato

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
- Ordine dei minigiochi scelti (fisso o casuale). Punti del premio del Duello e soglia esatta (playtest).
- Licenza del repo pubblico (codice) e note per gli asset: voci ElevenLabs piano Free = attribuzione e uso non commerciale.
