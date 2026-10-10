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
| Dispositivo TV | **Fire TV Stick 4K Max** (Fire OS, basato su Android, non Vega OS) | Già posseduto; accetta APK installati manualmente |
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

### M0 — Prova tecnica (elimina i rischi)
Obiettivo: dimostrare che le due incognite reali funzionano prima di costruire il gioco.

- [ ] Godot installato; progetto con renderer Compatibility, 1920×1080
- [ ] Scena di prova: cubo 3D animato + contatore FPS
- [ ] Toolchain Android pronta (JDK, Android SDK, keystore di debug), tutto gratuito
- [ ] APK installato sulla Fire TV via `adb` in Wi-Fi
- [ ] Il tasto centrale del telecomando cambia colore al cubo
- [ ] Il telefono apre `http://<IP-TV>:8080`, preme un pulsante, il cubo cambia colore
- [ ] FPS misurati sulla TV (obiettivo ≥ 30 stabili); lo schermo non va in screensaver

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
