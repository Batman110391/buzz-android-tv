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
| **Minigiochi** (2026-10-14) | Ogni minigioco è un round. Prima della partita chi ha il telecomando sceglie quali giocare (tutti selezionati di default, minimo 4): così decide la durata. Primo rilascio, 7 selezionabili: Accumula Punti, Dito Veloce, Passa la Bomba, Ruba Punti, Torta in Faccia, Metti in Ordine, La risposta più vicina (Foto Misteriosa tolta il 2026-10-14: forse in un aggiornamento). **Conto alla Rovescia** chiude sempre la partita (non si toglie). **Duello degli indizi** parte da solo (recupero, sotto). Nuovi minigiochi arrivano con gli aggiornamenti dell'APK | Durata scelta senza menu complicati |
| **Regole dei round** (G3, proposta P 2026-10-14, numeri da tarare col playtest) | Ordine fisso dei round scelti, punti che si sommano tra i round. **Accumula Punti** 5 `classica`, 15 s, +500. **Dito Veloce** 5 `lampo`, 10 s: un contatore scende da 1000 a 0, chi risponde giusto prende il valore del momento (arrotondato a 10), sbagliata 0. **Passa la Bomba** `lampo`, 3 bombe con miccia nascosta casuale 20–40 s; la prima parte dall'ultimo in classifica; risponde solo chi ha la bomba: giusta → passa al giocatore dopo, sbagliata → nuova domanda e la tiene; se esplode −500 (non sotto zero) e la bomba dopo riparte da lui. **Ruba Punti** 5 `classica`, 15 s: solo il **primo** che risponde giusto (S 2026-10-15) sceglie una vittima sul telefono (10 s, il telefono vibra; bot e chi non sceglie → il primo in classifica tra gli altri) e le ruba 300 punti (al massimo quelli che ha), niente +500. **Torta in Faccia** (S 2026-10-15) 5 `classica`, 15 s, giocano tutti, giusta +500; il **primo** che risponde giusto lancia una torta: un mirino salta da un podio all'altro (gli altri giocatori, ~0,35 s per podio) e lui preme LANCIA sul telefono (6 s; bot a caso; tempo scaduto → dove si trova): il colpito prende −300 (non sotto zero), splat sul volto e un'icona torta sul podio (colpi subiti). **Metti in Ordine** 5 `ordine`, 20 s: si toccano le 4 voci in sequenza sul telefono, +125 per ogni voce al posto giusto; la sequenza compare sul podio ("C A B D") solo alla rivelazione. **Conto alla Rovescia** (finale) 5 `classica`, 15 s: le barre di tutti scendono di 50 punti/s; chi risponde (giusto o sbagliato) si ferma, così non si scopre chi ha indovinato; alla rivelazione chi ha sbagliato o non ha risposto perde fino alla fine (−750 in tutto), chi ha indovinato perde solo i secondi impiegati **e prende +300** (S 2026-10-15: senza bonus tutti finivano a zero); mai sotto zero. Mirino della torta oro e grande | Ritmo vario senza regole difficili |
| **Tra un round e l'altro** (approvato 2026-10-14) | ~20 s: (1) **classifica intermedia** (4 s, barre che si riordinano, commento su primo/ultimo); (2) il **fanalino di coda sceglie la categoria** del round dopo fra 3 pescate a caso (telefono, 10 s; bot o tempo scaduto → a caso; al 1° round a caso); (3) carta del round. Battute nuove di Gilda (2° account). **Musica: una per minigioco** (Accumula allegra, Dito frenetica, Bomba tensione, Ruba furtiva, Torta comica, Ordine curiosa, Conto drammatica, intermezzo, titolo, finale): sintetizzata da zero nello stile dei loop attuali (S ha scartato Freesound e Kevin MacLeod, 2026-10-14) | Più interazione e ritmo tra i round, meno statico |
| **Duello degli indizi** | A metà partita, se tra primo e ultimo ci sono ≥ 3 risposte giuste di distanza (1.500 punti; soglia da tarare col playtest). Due squadre dalla classifica (3: 1°+3° / 2° · 4: 1°+4° / 2°+3° · 5: 1°+5° / 2°+3°+4° · 6: 1°+6°+5° / 2°+3°+4°; con 2 giocatori non c'è). Indizi uno alla volta, poi 4 risposte: il premio parte alto e **scende a ogni indizio sbloccato** (nessuno perde punti già fatti) | Dà una possibilità a chi è indietro senza annullare la partita |
| **Si guarda la TV** (S 2026-10-15) | Domanda, risposte, timer, esiti e classifica solo in TV. Il telefono è un telecomando: 4 tasti con le forme delle carte (◆A ●B ▲C ■D), niente testi da leggere; quando tocca a te (bomba, lancio della torta, furto, categoria) **vibra** e si colora; esito = verde/rosso pieno + vibrazione; in attesa "📺 Guarda la TV" | Prima era caotico: non si sapeva se guardare il telefono o la TV (stesso principio di Kahoot e Jackbox) |
| Controller | Si gioca **solo dal telefono** (pagina web, WebSocket verso la TV). Il telecomando serve a preparare la partita (lobby, scelta dei giochi, OK) e in partita apre la **pausa** (OK: riprendi · esci al titolo); bot per i test (2026-10-14) | Nessuna app da installare |
| Lingua | Italiano | — |
| **Domande** | Servite da un **Cloudflare Worker + D1** (piano gratuito); la TV le scarica all'avvio e le tiene in cache; aggiornate da un cron del Worker che genera con **Gemini** e verifica con un modello **OpenRouter** diverso (§4 "Domande") | Domande nuove senza aggiornare l'app, costo zero |
| Dotazione iniziale | ~1.600 domande scritte da Claude (worker), incluse anche nell'APK come riserva offline | Si gioca anche senza rete; fanno da "set buono" per tarare i prompt |
| Segreti | Solo in `.env` sul PC (da `.env.example`, escluso da git) e nei segreti del Worker; mai nell'APK | Repo pubblico |
| Repository | Pubblico con licenza; gestisce le release dell'APK quando serve | — |

---

## 3. Regole
**Accumula Punti (base):** 4 risposte (A rombo, B cerchio, C triangolo, D quadrato), timer 15 s, una risposta per giocatore (definitiva), il round finisce allo scadere o quando hanno risposto tutti; **+500** a chi indovina (la velocità conta solo in Dito Veloce). Durante la domanda si accende solo il podio di chi ha risposto: le scelte si vedono alla rivelazione. Valori in un solo punto (`game/game.gd`).

**Mini-giochi** (README del design, sezione "Mini-giochi"): Dito Veloce (punti che scendono col tempo), Passa la Bomba (chi ha la bomba quando esplode −500), Ruba Punti (chi indovina ruba a una vittima), Torta in Faccia (duello 1 contro 1), Metti in Ordine, **Conto alla Rovescia** (finale: −50 punti/s finché non rispondi giusto).

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

**Categorie (18, chiavi fisse):** `geografia` `storia` `scienza` `natura` (natura e animali) `cinema_tv` `musica` `sport` `cucina` `arte_letteratura` `lingua` (lingua italiana e modi di dire) `tecnologia` (tecnologia e invenzioni) `costume` (costume, giochi, vita quotidiana, curiosità); **particolari** (2026-10-14, per non essere il solito quiz): `videogiochi` · `mitologia` (mitologia e leggende) · `citazioni` ("Chi l'ha detto?": frasi celebri di film, canzoni, storia) · `strano_ma_vero` (curiosità incredibili ma vere e verificabili) · `corpo_umano` · `tradizioni` (superstizioni e tradizioni). Prefissi `cat3` degli id: geo sto sci nat cin mus spo cuc art lin tec cos vid mit cit str cor tra.

**Difficoltà** (per un gruppo di amici adulti italiani, età miste): **1** la sa quasi chiunque · **2** circa metà del tavolo · **3** pochi, ma sentita la risposta si dice "ah, giusto!" (mai nozioni da specialisti). Dopo 20 uscite la difficoltà si ricalcola dai dati reali: ≥ 75% giuste → 1, 35–75% → 2, < 35% → 3; < 5% dopo 20 uscite → `sospesa` (probabilmente sbagliata).

**Regole di qualità** (stesse per Claude, Gemini e il verificatore):
1. Una sola risposta giusta, senza ambiguità né interpretazioni.
2. Sbagliate plausibili, dello stesso tipo e formato della giusta (tutte città, tutti anni…), di lunghezza simile; niente risposte-scherzo.
3. Vietati: negazioni ("quale NON…"), "tutte/nessuna delle precedenti", domande sul futuro, fatti che possono cambiare entro 5 anni (record, cariche, "l'attuale…"), opinioni, stereotipi, contenuti offensivi, politica di parte, tragedie recenti.
4. La domanda non contiene indizi della risposta; italiano corretto con accenti (È, perché); niente punto finale nelle risposte.
5. Varietà: niente due domande sullo stesso `fatto`; non più di 3 domande sullo stesso argomento ristretto per categoria.

#### Dotazione iniziale (D2, scritta da Claude)
Per categoria: 90 `classica` (30 per difficoltà) + 30 `lampo` + 15 `ordine` → **~1.620** domande in `domande/<tipo>/<categoria>.json` (array JSON). **D6 (approvato 2026-10-14, "come Buzz"):** si sale a 180 `classica` (60 per difficoltà) + 60 `lampo` + 25 `ordine` per ognuna delle 18 categorie → **~4.770**, più `stima`/`indizi` con i loro minigiochi → ~5.000. Domande meno scontate: niente quiz da sussidiario, curiosità che fanno dire "davvero?". `tools/domande_check.mjs` valida tutto (schema, lunghezze, regole meccaniche, doppioni di `fatto` e di testo) ed esce con codice ≠ 0 se trova errori.

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

### Protocollo con i telefoni (G2, definito 2026-10-14)
**Rete.** HTTP 8080 serve solo `GET /` (anche `/?c=XXXX`) = `net/controller.html`, tutto il resto 404; richiesta max 4 KB. WebSocket 8081, max 12 connessioni, messaggi max 1 KB. Ogni sessione ha un **codice** di 4 caratteri (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`) che sta nell'URL del QR (`http://<ip>:8080/?c=KR7Q`); chi scrive l'URL a mano lo inserisce sul telefono. Il codice tiene fuori i dispositivi della LAN che non vedono la TV.

**Giocatori.** 6 slot (0–5). Il personaggio decide colore e nome predefinito (`GIOCATORI` in main: chef/rosso, nonna/blu, zombi/verde, gatto/giallo, boss/viola, diva/arancio). Lo slot lo sceglie la TV (il primo libero). I bot (←/→ nella lobby) occupano slot e personaggi come i telefoni. Il telecomando non è un giocatore: senza telefoni giocano solo i bot.

Messaggi JSON con il campo `t`:
| Direzione | `t` | Campi |
|---|---|---|
| tel → TV | `join` | `code`, `name` (trim, senza caratteri di controllo, max 12; vuoto = nome del personaggio), `avatar` (id personaggio), `token` (solo per rientrare) |
| tel → TV | `leave` | nessun campo: solo in lobby aperta, libera lo slot per cambiare personaggio (tasto "Cambia personaggio", S 2026-10-15) |
| tel → TV | `answer` | `q` (indice domanda, int), `choice` (0–3) |
| TV → tel | `welcome` | `slot`, `token` (16 hex casuali), `name`, `avatar`, `color` ("#F2384A") |
| TV → tel | `reject` | `reason`: `codice` · `pieno` · `preso` (personaggio occupato) · `partita` (partita in corso e token sconosciuto) |
| TV → tutti | `lobby` | `presi` (personaggi occupati, bot compresi), `aperta` (bool: lobby aperta = nuova partita) — anche a chi non è ancora entrato |
| TV → tutti | `state` | `fase`: `lobby` · `domanda` · `rivela` · `attesa` · `finale`; con `domanda`: `q`, `tot`, `domanda`, `risposte[4]` (nell'ordine mostrato in TV) e, per ciascun telefono, `scelta` (-1 se non ha risposto) |
| TV → tel | `result` | `giusta` (bool), `punti` (guadagnati), `totale`, `posizione` |
| tel → TV | `steal` (G3) | `q` (indice della domanda appena rivelata), `victim` (slot) |
| TV → tutti | `state` minigiochi (G3) | con `domanda` anche `gioco` (`accumula` `dito` `bomba` `ruba`); con `bomba` anche `bomba` (slot che ce l'ha: solo lui ha i tasti) e `bomba_nome` (gli altri vedono "<nome> ha la bomba!"), senza `tempo` (miccia nascosta). Fase `ruba`: `q`, `punti` (300), `tempo` (10), `vittime` [{`slot`,`name`,`color`,`avatar`,`punti`}] e, per ciascun telefono, `puo` (bool: ha indovinato e non ha ancora rubato) |
| TV → tel | `result` (G3) | campo facoltativo `testo` ("Hai rubato 300 punti a Ugo!", "BOOM! −500"), mostrato nell'esito |
| tel → TV | `cat` (G3) | `r` (indice del round), `scelta` (0–2) |
| TV → tutti | `state` fase `categoria` (G3) | `r`, `tempo` (10), `opzioni` [{`id`,`nome`,`icona`}] ×3, `chi` (slot del fanalino), `chi_nome`; per ciascun telefono `puo` (true solo per il fanalino) |
| TV → tutti | `state` G3f | `gioco` anche `torta` `ordine` `conto`. Con `ordine` anche `criterio`; `risposte[4]` = le voci nell'ordine mostrato in TV; per ciascun telefono `scelta` = `[]` o la sequenza inviata. Fase `torta`: `q`, `tempo` (6), `chi` (slot del lanciatore), `chi_nome`; per ciascun telefono `puo` (true solo per il lanciatore, finché non ha lanciato) |
| tel → TV | `order` (G3f) | `q`, `seq` (4 interi 0–3 tutti diversi = indici delle voci mostrate, nell'ordine scelto) |
| tel → TV | `throw` (G3f) | `q` (il bersaglio è dove si trova il mirino in TV in quel momento) |

**Validazione sul lato TV** (la TV è l'unica autorità; tutto il resto si ignora in silenzio): JSON valido e oggetto, tipi esatti; `join` una sola volta per connessione, codice giusto, personaggio esistente e libero; `answer` solo da connessione entrata, fase `domanda`, `q` = domanda attiva, `choice` intero 0–3; `steal` solo da connessione entrata, fase `ruba`, `q` = domanda attiva, `victim` tra le `vittime` e diverso dal proprio slot, una volta per domanda (il resto lo controlla `Game.ruba`); `cat` solo dal fanalino (`puo`), fase `categoria`, `r` = round attivo, `scelta` intero 0–2, una volta sola; `order` come `answer` ma con `seq` (array di 4 interi 0–3 distinti) e solo se `gioco` = `ordine`; `throw` solo dal lanciatore (`puo`), fase `torta`, `q` = domanda attiva, una volta sola; "non ha già risposto" e "tempo non scaduto" li controlla `Game.submit_answer` (tempo misurato sulla TV).

**Riconnessione.** Il telefono salva `token`, personaggio e nome nel `localStorage`. Con `aperta` = true (nuova partita) mostra sempre la scelta, con personaggio e nome dell'ultima volta preselezionati, e fa il `join` solo al tocco di "Entra": il token in lobby vale come join nuovo e libera il suo vecchio slot se scollegato (S 2026-10-15). Con `aperta` = false (partita in corso) rientra da solo con il token, riprende il suo slot e riceve subito l'ultimo `state`. Nella lobby uno slot disconnesso si libera dopo 15 s; in partita resta suo fino al ritorno al titolo.

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
- [x] D2 dotazione iniziale ~1.620 domande (12 categorie), check verde
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
- [x] Lobby con QR + indirizzo + codice; il telefono sceglie personaggio e nome (1l)
- [x] 4 tasti con forma e testo (1m), risposta bloccata (1n), esito sul telefono
- [ ] 2–6 giocatori reali, riconnessione, input non validi ignorati

### G3 — Mini-giochi
- [x] Dito Veloce · Passa la Bomba · Ruba Punti (+ schermata vittime sul telefono 1o) — da provare sulla TV
- [x] Torta in Faccia · Metti in Ordine — da provare sulla TV
- [x] Conto alla Rovescia come finale — da provare sulla TV
- [x] Schermata di scelta dei minigiochi prima della partita (telecomando; tutti accesi, minimo 4)
- [ ] La risposta più vicina (stima dal telefono, vince chi si avvicina di più)
- [ ] Duello degli indizi (recupero automatico a metà partita, squadre dalla classifica)

### G4 — Contenuti e rifinitura
- [ ] 200+ domande in categorie, riviste dal supervisore
- [ ] Musica e effetti coerenti con lo stile
- [ ] Icona e banner del launcher rifiniti
- [ ] Playtest con amici veri
- [x] Repo pubblico con licenza e README (2026-10-15) · [ ] release dell'APK firmato

---

## 6. Rischi
| Rischio | Mitigazione |
|---|---|
| OpenRouter gratuito: **50 richieste al giorno** (1.000 con almeno 10 $ di credito caricati una volta); un lancio di `prompt_test --n 8` ne usa ~30. Gemini a volte risponde 503 | Prova reale una volta al giorno; il cron del Worker (D4) verifica al massimo ~40 domande al giorno, oppure S carica 10 $ (decisione di S) |
| Router che isola i dispositivi (rete ospiti) | Rete principale o hotspot del telefono |
| QR code: Godot non lo genera | Generatore QR in GDScript (algoritmo pubblico) o solo indirizzo + codice |
| Crediti ElevenLabs | Generare solo i file mancanti (`--go <id>`), testi rivisti prima |
| Domande sbagliate | Revisione del supervisore |
| Effetti sonori | Solo CC0 da Freesound (`FREESOUND_API_KEY`), annotati in LICENSES.md |

## 7. Decisioni aperte
- Numero di round e domande per partita (dopo il playtest).
- Ordine dei minigiochi scelti (fisso o casuale). Punti del premio del Duello e soglia esatta (playtest).
- Licenza del repo pubblico (codice) e note per gli asset: voci ElevenLabs piano Free = attribuzione e uso non commerciale.
