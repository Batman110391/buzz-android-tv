# Handoff: Quizzone! — quiz party TV per Godot 4

## Overview
Quiz party 2D per 2–6 giocatori, in italiano, su TV (1920×1080, visto da 3 m). Ispirato al genere dei quiz show per console anni 2000, stile originale. Motore: **Godot 4.x, renderer Compatibility (GLES3)**, target **Amazon Fire TV Stick 4K Max** (GPU debole). I giocatori rispondono da telefono (pagina web) o tastiera. Presentatore animato con audio preregistrati ElevenLabs.

## About the Design Files
I file in `design/` sono **riferimenti di design creati in HTML** (prototipi che mostrano aspetto e comportamento), **non codice da portare così com'è**. Il compito è ricreare queste schermate in **Godot** (scene `.tscn`, Control/Node2D, Theme, Tween, AnimationPlayer). Il controller da telefono va realizzato come pagina web statica servita/collegata al gioco (es. WebSocket).
Per vederli: aprire `design/Quizzone Design System.dc.html` in un browser (servire la cartella via HTTP locale, es. `python3 -m http.server`, perché i file si importano a vicenda).

## Fidelity
**High-fidelity** per layout, colori, tipografia, misure e stati UI: ricreare fedelmente.
**Personaggi**: vettoriali di direzione, utilizzabili come asset provvisori/definitivi (SVG in `assets/personaggi/`); potranno essere sostituiti da un illustratore mantenendo la stessa tela e gli stessi nomi file.

## Vincoli globali
- Risoluzione di riferimento 1920×1080, stretch mode `canvas_items`, aspect `keep`.
- Area sicura: **96 px ai lati, 54 px sopra/sotto**. Il testo non esce mai dall'area sicura; sfondo e personaggi sì.
- Testo: domanda ≥ 56 px (standard 60), risposte ≥ 44 px (standard 48), **nessun testo < 32 px**.
- **Niente blur, glow, shader complessi, WorldEnvironment.** Profondità = bordi spessi + ombre dure (pannello duplicato sfalsato). Neon = due Line2D (36 px α 0.2 + 8 px pieno).
- Max 2 gradienti per schermata (GradientTexture2D). Sfondo palco pre-renderizzato in un PNG 1920×1080.
- Evitare grandi superfici semitrasparenti sovrapposte (overdraw).

## Design Tokens
Valori completi in `design-tokens.json`.

**Colori interfaccia**
| Nome | Hex | Uso |
|---|---|---|
| ink | #1B0B3A | contorni, testo su chiaro/colori giocatore |
| cream | #FFF4DC | carte risposta, testo su scuro |
| white | #FFFFFF | risposta giusta, anello |
| stage_dark | #12052E | bordi sfondo |
| stage | #25095E | sfondo medio, telefono |
| stage_light | #4B1FA8 | centro sfondo |
| neon_magenta | #FF3DA8 | bordo pannello domanda, linguette |
| neon_cyan | #22E1FF | archi neon, area sicura debug |
| gold | #FFC83D | timer, premi, CTA, lampadine |
| dim_bg | #3A2A6E | risposta sbagliata (sfondo) |
| dim_text | #B8ACE0 | risposta sbagliata (testo) |
| dim_badge | #5B4A93 | risposta sbagliata (forma) |
| shadow_hard | #0A0320 | ombra dura pannelli |

**Colori giocatori** (testo sopra sempre #1B0B3A; ogni giocatore ha anche numero + personaggio)
1 #F2384A Gastone (chef) · 2 #2F7BFF Nonna Pina (nonna) · 3 #33C759 Ugo (zombi) · 4 #FFD43B Brioche (gatto) · 5 #A855F7 Don Ciccio (boss) · 6 #FF8A1F Vanessa (diva). Presentatore: Tony Scintilla (host).

**Regola chiave colori**: le risposte NON sono colorate. Carte crema con forma + lettera: A rombo, B cerchio, C triangolo, D quadrato (forma piena #1B0B3A, lettera crema). Chi risponde aggiunge un gettone (cerchio 60 px colore giocatore, numero 34 px) sulla carta. Giusta/sbagliata si distinguono per luminosità, non per tinta.

**Font** (entrambi OFL, Google Fonts, includere i .ttf; FontFile con MSDF attivo)
- Display: **Lilita One** — logo 200, titolo round 136, titolo schermata 88–100, numeri/etichette 40–64, linguette 32.
- Testo: **Baloo 2 ExtraBold (800)** — domanda 60, risposta 48, nomi podio 32, fumetti 44–56. line-height ≈ 1.05–1.15.
- Titoli su sfondo scuro: LabelSettings outline_size 14–20 colore ink, shadow_offset (0,10–18), shadow_size 0.

**Forme (StyleBoxFlat)**
- Carta risposta: bg cream, border 6 ink, **border_bottom 16**, corner_radius 28.
- Pannello domanda: bg ink, border 8 neon_magenta, corner_radius 32, ombra dura = StyleBox/Panel #0A0320 sfalsato y+14 (non usare shadow_size: è sfumata).
- Linguetta: bg magenta (o gold), border 6 ink, altezza 60, raggio pieno, testo Lilita 32 ink.
- Podio fronte: 212×144, bg colore giocatore, border 6 ink, border_bottom 14, raggio inferiore 22. Coperchio: 232×40 raggio 20, colore giocatore + overlay bianco α 0.4.
- Timer: cerchio 160, bordo 8 ink, anello progress gold su #3A2A6E (TextureProgressBar radiale), centro ink 112 con numero Lilita 64 cream.

## Layout standard domanda (coordinate reali 1920×1080)
| Elemento | x | y | w | h |
|---|---|---|---|---|
| Linguetta round | 140 | 54 | auto | 60 |
| Pannello domanda | 96 | 88 | 1540 | 214 |
| Timer | 1664 | 88 | 160 | 160 |
| Griglia risposte 2×2 (gap 24, righe 134) | 96 | 336 | 1728 | 292 |
| Riga 6 podi (240×376, space-between) | 96 | 650 | 1728 | 376 |

Tutte le schermate in `Quizzone Design System.dc.html` sono scritte con `position:absolute` in pixel reali dentro un artboard 1920×1080 (mostrato al 50%): le coordinate nel sorgente si copiano 1:1.

## Screens / Views
(id tra parentesi = badge nel file di design)
1. **Titolo (1a)** — logo "QUIZZONE!" Lilita 200 gold, contorno 20 ink, ruotato −5°, su raggiera (cerchio 880, bordo 12 cyan); nastro "Il quiz più pazzo del salotto"; presentatore a sinistra 600×750; CTA "Premi INVIO per giocare" + "oppure entra dal telefono: quizzone.tv".
2. **Lobby (1b)** — titolo "Entrate in studio!"; card join 620×826 (QR 380, URL Lilita 64, codice 4 caratteri in box 100×112 gold su ink); griglia 3×2 slot (1044×826, gap 28): slot pieno = carta colore giocatore + personaggio 290 + nome su barra ink; vuoto = bordo tratteggiato crema α .55, "?" e "In attesa…". Pill "4/6 · INVIO per iniziare".
3. **Presentazione round (1c)** — card 1240×640 ruotata −2°, bg ink, bordo 10 magenta; pill "ROUND 3 DI 6"; icona; titolo Lilita 136 gold; regola 44 px; presentatore + fumetto.
4. **Domanda – Accumula Punti (1d)** — layout standard. Podi in stato "risposto" per chi ha risposto (lucchetto).
5. **Rivelazione (1e)** — giusta: bg bianco, scala 1.03, anello bianco 6 px a −18 px, timbro ✓; sbagliate: dim; gettoni sulle risposte scelte; podi ok/ko con badge "+500".
6. **Classifica finale (1f)** — podio 1/2/3 (blocchi 280 di larghezza, altezze 440/330/250, oro #FFC83D / argento #D9D4EC / bronzo #C98A4B), 4°–6° in lista a destra, coriandoli, presentatore con fumetto.

**Mini-giochi** (stesso layout salvo indicato)
- **Dito Veloce (1g)** — timer sostituito da contatore punti che scende (cerchio gold "740 PUNTI"); badge podio "1° 0,8 s".
- **Passa la Bomba (1h)** — timer = bomba con "?" (miccia nascosta); chi ha la bomba: stato "bomba" + badge "Tocca a te!". Se esplode: −500.
- **Ruba Punti (1i)** — chi indovina sceglie una vittima; card centrale gold "300 punti da rubare"; podi altrui in stato "mira".
- **Torta in Faccia (1j)** — duello 2 giocatori (podi ×1.5 ai lati), risposte 2×2 al centro (920 di larghezza), 3 icone torta per giocatore (colpi subiti); colpito = splat sul volto + espressione arrabbiata.
- **Conto alla Rovescia (1k)** — finale: barre verticali per giocatore (116 di larghezza, altezza ∝ punti) a sinistra; domanda + 4 risposte in colonna a destra (884 di larghezza); −50 punti/s finché non rispondi giusto.
- **Metti in Ordine (1q)** — tocca le 4 risposte nella sequenza corretta; la sequenza del giocatore appare come badge sul podio ("C A B D").
- **Foto Misteriosa (1r)** — foto 1000×640 coperta da 6×4 tasselli che si scoprono (−25 punti per tassello); risposte in colonna a destra; riga di 6 giocatori sotto (chi sbaglia è bloccato, α .55).

**Telefono (390×844)** — (1l) scelta personaggio (griglia 2×3, presi α .35, selezionato con anello), nome, "ENTRA!"; (1m) 4 tasti a tutta larghezza con forma + testo, header nel colore del giocatore; (1n) risposta bloccata; (1o) Ruba Punti: lista vittime.

## Componenti (scene Godot consigliate)
- **Risposta.tscn** — props: lettera A–D, testo, stato (normale/giusta/sbagliata), gettoni[]. Vedi `design/Risposta.dc.html`.
- **Podio.tscn** — props: personaggio, nome, colore, numero, punti, stato (''/ok/ko/risposto/bomba/mira), badge (testo, chiaro/scuro), spento, splat. Lo stato imposta anche l'espressione: ok→felice, ko→triste, mira/bomba→sorpreso, splat→arrabbiato. Vedi `design/Podio.dc.html`.
- **Personaggio.tscn** — rig cutout (vedi sotto).
- **Palco** — sfondo; vedi `design/Palco.dc.html` (gradiente radiale, 3 raggi di luce, archi ellittici neon, lampadine, pavimento ellittico, torri laterali).

## Interazioni e animazioni (Tween, nessuno shader)
- Entrata carte: scale 0 → 1.1 → 1, 0.35 s, TRANS_BACK EASE_OUT, ritardo 0.08 s tra le risposte.
- Respiro idle personaggi: scale.y 1 ↔ 1.03 (presentatore 1.018), 1.6–1.8 s, TRANS_SINE, sfasato per giocatore.
- Risposto: salto podio y −24 px e ritorno 0.25 s TRANS_QUAD; lucchetto pop-in.
- Rivelazione: sbagliate → colori dim in 0.2 s; giusta scale 1.08 → 1.03 TRANS_ELASTIC 0.6 s.
- Punti: badge "+500" sale di 40 px; contatore conta in 0.8 s.
- Lampadine palco: modulate alfa alternata su due gruppi ogni 0.4 s.
- Input: tastiera 1–4 o A–D per rispondere, INVIO per avanzare. Telefono via WebSocket.

## Presentatore animato (vedi `design/Presentatore Animato.dc.html`)
Demo interattiva funzionante: battute preimpostate e caricamento di un mp3 con lip-sync da volume.
- **Albero**: Presentatore → Corpo (respiro, salto) → [Testa (perno 120,195) → Occhi (perno 123,134; ciglia), Sopracciglia, Bocca (6 sprite), Baffi, Capelli (perno 120,112; segue la testa con ritardo)] + Braccio (perno 186,300; gesti). AudioStreamPlayer sul bus "Voce".
- **Ciglia**: chiusura 0.14 s (scale.y 0.1) ogni 2.4–4.6 s casuali.
- **Durante il parlato**: testa ±3° × volume a ~9 rad/s, testa −4 px × volume, sopracciglia −3 px × volume.
- **Gesti** (peso con rampa 0.25 s in / 0.5 s out): saluto (braccio −28° ± 14° sin 11t, testa −4°), annuncio (testa scala 1.05, −5°, braccio −12°), esulta (salto 38 px |sin|, braccio −32°, sopracciglia −6), delusione (testa +7° e +10 px, sopracciglia +4, braccio +12°), sorpresa (occhi ×1.25, sopracciglia −12, molla capelli).
- **Lip-sync A (consigliato, audio preimpostati)**: pre-calcolare per ogni .mp3 un .json [secondi, bocca] (es. dai timestamp per carattere di ElevenLabs: a→A, e/i→E, o/u→O, con "socchiusa" in transizione, pause → riposo). In `_process` leggere `get_playback_position()`.
- **Lip-sync B (tempo reale)**: AudioEffectSpectrumAnalyzer sul bus Voce, magnitudo 100–4000 Hz → soglie (riposo < 0.06, socchiusa < 0.18, E/I oppure O/U < 0.4, A oltre).
- Gesto scelto dal nome del file audio (es. `giusta_03.mp3` → esulta). A fine battuta l'espressione resta 1.8 s.
- Sottotitolo nel fumetto (56 px) per ogni battuta.

## Assets
- `assets/personaggi/<id>/` — SVG per pezzo, **tutti sulla stessa tela** (200×200; host 240×300; esportati a ×4). Pezzi statici: `dietro`, `corpo`, `testa`, `sopra` (host: `baffi`, `capelli`, `braccio`). Pezzi per espressione: `occhi_<e>`, `sopracciglia_<e>`, `bocca_<e>` con e ∈ neutro, felice, triste, sorpreso, arrabbiato. Bocche parlato: `bocca_socchiusa|A|E|O`.
- `assets/personaggi/rig.json` — ordine livelli (dal basso), perni, pezzi figli della testa, scala di import.
- `assets/personaggi/_anteprime/` — personaggi composti per espressione (solo riferimento).
- In Godot: importare gli SVG con scala 4, metterli in un atlante, Sprite2D `centered=false` a (0,0); Node2D "Testa" posizionato sul perno con figli spostati di −perno; `dietro` con z_index −1.
- QR code e foto di Foto Misteriosa sono segnaposto.
- Font: Lilita One, Baloo 2 (Google Fonts, OFL).

## Files
- `design/Quizzone Design System.dc.html` — documento principale: fondamenta, componenti, personaggi, tutte le schermate e note Godot.
- `design/Presentatore Animato.dc.html` — demo animazioni + lip-sync.
- `design/Personaggi v2.dc.html` — tavola personaggi, espressioni, pezzi.
- `design/Risposta.dc.html`, `Podio.dc.html`, `Personaggio.dc.html`, `Palco.dc.html` — componenti.
- `design/personaggi-v2.js` — sorgente unica dei disegni (genera tutti gli SVG).
- `design/support.js` — runtime necessario solo per aprire i file HTML.
- `design-tokens.json` — token numerici.
