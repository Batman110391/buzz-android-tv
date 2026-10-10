# INITIAL_PLAN.md — Quiz Party 3D per Fire TV

## 1. Visione del progetto

Realizzare un gioco party originale ispirato all'esperienza dei quiz televisivi come _Buzz: The Mega Quiz_, pensato per essere giocato in compagnia davanti alla TV.

- **Schermo principale:** Amazon Fire TV, collegata al televisore.
- **Giocatori:** da 2 a 6.
- **Controller:** smartphone dei giocatori, senza richiedere inizialmente l'installazione di un'app mobile.
- **Obiettivo:** ricreare il ritmo e l'atmosfera di un quiz televisivo, con presentatore, palco, domande, conto alla rovescia, effetti, punteggi e momenti di vittoria.
- **Identità:** creare nome, personaggi, grafica, audio e contenuti originali; non riutilizzare asset, personaggi o registrazioni di Buzz senza autorizzazione.

La priorità è ottenere prima una demo visivamente convincente e giocabile. Il multiplayer reale e la distribuzione sulla Fire TV verranno dopo.

## 2. Direzione tecnica da pensare e che ho trovato in giro da verificare

### Motore e strumenti

- **Godot 4.x stabile** per il gioco e la grafica 3D.
- **GDScript** per la logica di gioco e gli script.
- **Blender** per creare o modificare modelli 3D e preparare personaggi e oggetti.
- **glTF/GLB** come formato di interscambio per gli asset 3D, verificando materiali, scheletri e animazioni durante l'importazione.
- **Git** per il versionamento.
- **Git LFS** per i file binari pesanti, se necessario.

### Stile grafico

Puntare a un **3D cartoon stilizzato**, espressivo e leggibile sul televisore, anziché al realismo. Lo stile dovrebbe ricordare un programma televisivo giocoso: colori forti, luci scenografiche, personaggi caricaturali e reazioni esagerate.

Per la prima demo:

- un solo palco;
- un presentatore originale;
- un numero limitato di animazioni;
- podi e fondali semplici;
- effetti visivi concentrati sui momenti importanti.

Le immagini di riferimento e i concept generati possono aiutare a definire lo stile, ma non sono automaticamente modelli 3D pronti: i personaggi animabili richiedono geometria, rig, skinning e animazioni.

## 3. Esperienza di gioco prevista

### TV / Fire TV

La TV mostra:

- menu e ingresso nella partita;
- palco 3D e presentatore;
- domanda e quattro risposte;
- conto alla rovescia;
- rivelazione della risposta corretta;
- punteggi e classifica;
- animazioni di vittoria e finale.
- ecc.. tutto quello che faceva BUZZ

### Smartphone

Ogni partecipante, in una fase successiva:

1. inquadra un QR code o inserisce un codice stanza;
2. apre una pagina web sul telefono;
3. sceglie nome e avatar;
4. usa pulsanti grandi e colorati per rispondere.

### Flusso di una domanda

1. Il gioco presenta la domanda. in base alla modalità di gioco
2. Si avvia il timer.
3. I giocatori inviano le risposte.
4. Il controller convalida le risposte e aggiorna i punteggi.
5. La regia mostra l'esito con animazioni e audio.
6. Viene mostrata la classifica e si passa alla domanda successiva.
7. si aggiungino provocazioni ironiche da parte del presentatore ecc.. tutto quello che faceva anche BUZZ

## 4. Architettura prevista

Separare le regole di gioco dalla presentazione visiva e dal sistema di input. In questo modo, durante il prototipo l'input può essere simulato con tastiera o gamepad; successivamente potrà essere sostituito con messaggi provenienti dai telefoni.

### Componenti principali

- **Game Controller/DPAD Telecomando:** gestisce lo stato della partita, round, timer, risposte e transizioni.
- **Score Manager:** calcola e conserva i punteggi.
- **Question Bank:** fornisce domande, categorie, opzioni e risposta corretta.
- **Stage Director:** coordina presentatore, luci, effetti e sequenze sceniche.
- **Camera Director:** gestisce inquadrature e transizioni.
- **Player Input:** astrazione degli input, inizialmente locale e in seguito collegata alla rete.
- **Network Manager:** componente futuro per stanze, connessioni e messaggi.
- **Message Protocol:** definisce la struttura dei messaggi scambiati con i controller mobili.

### Regola architetturale fondamentale

La grafica non deve contenere le regole del gioco. Il controller convalida una risposta, aggiorna il punteggio ed emette un evento; la regia reagisce all'evento con animazioni, audio, luci e movimenti di telecamera.

Esempio concettuale:

- il controller risolve una risposta;
- aggiorna il punteggio;
- emette `answer_resolved`;
- la regia riproduce l'animazione corrispondente.

## 5. Macchina a stati della partita

Flusso iniziale previsto:

`MainMenu → PlayerSetup → Intro → Question → AnswerReveal → Scoreboard → Question ... → Final`

La demo potrà iniziare con un numero fisso di concorrenti simulati, oppure con una configurazione semplice. Non serve implementare subito tutte le regole e le modalità di gioco.

## 6. Struttura iniziale delle cartelle

Questa è la struttura obiettivo indicativa. Non occorre creare tutti i file fin dal primo giorno: iniziare solo con ciò che serve al primo milestone.

```text
quiz-party/
├── project.godot
├── export_presets.cfg
├── README.md
│
├── scenes/
│   ├── app/
│   │   └── main.tscn
│   ├── stage/
│   │   ├── quiz_stage.tscn
│   │   ├── stage_lighting.tscn
│   │   └── podium.tscn
│   ├── characters/
│   │   └── host.tscn
│   ├── ui/
│   │   ├── question_hud.tscn
│   │   ├── scoreboard.tscn
│   │   └── player_join.tscn
│   └── effects/
│       ├── confetti.tscn
│       └── answer_feedback.tscn
│
├── scripts/
│   ├── game/
│   │   ├── game_controller.gd
│   │   ├── game_state.gd
│   │   └── score_manager.gd
│   ├── presentation/
│   │   ├── stage_director.gd
│   │   └── camera_director.gd
│   ├── players/
│   │   ├── player_data.gd
│   │   └── player_input.gd
│   └── network/
│       ├── network_manager.gd
│       └── message_protocol.gd
│
├── data/
│   └── questions.json
│
├── assets/
│   ├── models/
│   ├── animations/
│   ├── materials/
│   ├── textures/
│   ├── audio/
│   ├── fonts/
│   └── ui/
│
└── tests/
    └── test_game_rules.gd
```

## 7. Grafica e pipeline degli asset

### Fase artistica

1. Definire riferimenti visivi e palette cromatica.
2. Bloccare il palco usando primitive geometriche direttamente in Godot.
3. Definire la silhouette e lo stile del presentatore.
4. Procurarsi o creare un primo modello compatibile con Godot.
5. Preparare le animazioni, verificando l'importazione e la compatibilità.
6. Aggiungere luci, particelle, materiali e audio.
7. Provare la scena sul dispositivo target e ottimizzarla.

### Animazioni minime del presentatore

Per la prima versione bastano:

- idle;
- parlare;
- sorpresa;
- celebrazione.

Si potranno aggiungere in seguito risate, delusione, reazioni alle risposte e animazioni specifiche per i round.

### Effetti di regia prioritari

- entrata sul palco;
- presentazione della domanda;
- timer con luci o musica crescente;
- feedback visivo per risposta corretta o sbagliata;
- cambio di inquadratura;
- classifica;
- vittoria con coriandoli ecc.

La regia, il ritmo e l'audio devono contribuire all'atmosfera tanto quanto i modelli 3D.

## 8. Connessione multiplayer: decisione rimandata

La scelta definitiva della rete verrà presa dopo la demo. L'ipotesi preferita al momento è **Wi-Fi locale**, perché il gioco è pensato per essere usato in casa senza dipendere necessariamente da un servizio cloud.

### Opzioni da valutare

- **Wi-Fi locale:** telefoni e Fire TV sulla stessa rete; nessun backend cloud obbligatorio.
- **Backend online:** può semplificare alcune connessioni, ma richiede Internet e un servizio disponibile.
- **Hotspot dedicato:** possibile alternativa da verificare per giocare senza router domestico.

Una possibile architettura locale prevede che la Fire TV ospiti il server di comunicazione e che i telefoni aprano una pagina web come controller. Questa soluzione non è ancora confermata: bisogna verificare modello Fire TV, versione di Fire OS, permessi, raggiungibilità di rete e compatibilità del server sul dispositivo.

### Messaggi previsti, indicativamente

- `join`: ingresso di un giocatore;
- `answer`: risposta a una domanda;
- `buzz`: prenotazione della risposta, se prevista dalle regole;
- messaggi di stato per sincronizzare la partita.

Il server deve convalidare il giocatore, la domanda attiva, il tempo e l'eventuale duplicazione delle risposte. La logica di gioco non deve fidarsi ciecamente dei messaggi ricevuti.

## 9. Roadmap

### Milestone 1 — Vertical slice 3D sul PC

usando asset iniziali o placeholder e senza modellare da zero personaggi professionali.

Obiettivo: una sequenza giocabile di circa 60–90 secondi che sembri già un quiz televisivo.

Criteri di completamento:

- [ ] Il gioco si avvia nel menu principale.
- [ ] La telecamera entra sul palco con una transizione.
- [ ] Il presentatore esegue almeno tre animazioni.
- [ ] Una domanda appare con quattro risposte leggibili da lontano.
- [ ] I tasti `1`–`4` simulano le risposte.
- [ ] Il timer termina e viene rivelata la risposta corretta.
- [ ] Il punteggio si aggiorna e compare una classifica.
- [ ] Il round termina con una scena di vittoria e coriandoli.

### Milestone 2 — Demo grafica rifinita

- migliorare materiali e illuminazione;
- definire la palette e l'identità visiva;
- aggiungere effetti e suoni;
- rendere coerenti animazioni e transizioni;
- mantenere il gioco fluido sul PC.

### Milestone 3 — Prima prova sulla Fire TV

- identificare il modello preciso della Fire TV Stick;
- configurare l'esportazione Android di Godot;
- installare l'APK manualmente per le prove;
- verificare risoluzione, fullscreen, avvio, input e prestazioni;
- ridurre ombre, luci dinamiche, particelle o post-processing quando necessario.

Non si deve presumere che una scena pesante su PC sia adatta al dispositivo TV: la profilazione reale guiderà le scelte grafiche.

### Milestone 4 — Multiplayer locale

- definire protocollo e gestione delle stanze;
- creare la pagina web controller per smartphone;
- collegare due telefoni e poi arrivare a sei;
- gestire disconnessioni, risposte duplicate e timeout;
- sincronizzare la partita e convalidare le risposte sul lato autorevole.

### Milestone 5 — Contenuti e modalità di gioco

- ampliare il catalogo delle domande;
- introdurre categorie;
- aggiungere round e regole speciali;
- valutare nuove animazioni, personaggi e contenuti audio/video.

## 10. Priorità e cose da non fare subito

### Priorità

1. Far funzionare un piccolo ciclo di gioco.
2. Ottenere un palco e una regia visivamente convincenti.
3. Separare input, regole e presentazione.
4. Testare presto sul dispositivo target, appena esiste una scena stabile.
5. Aggiungere il multiplayer dopo aver validato la demo.

### Da rimandare

- sei personaggi completamente modellati e animati;
- multiplayer prima che esista un ciclo di gioco funzionante;
- database remoto e backend complesso;
- un grande catalogo di domande;
- fisica o sistemi 3D non necessari;
- grafica fotorealistica;
- distribuzione pubblica e sistemi di account.

## 11. Prima giornata: checklist operativa

1. Installare Godot 4.x stabile e Blender.
2. Creare il repository Git.
3. Creare il progetto Godot e configurare una finestra 16:9 a 1920×1080 per la demo PC.
4. Creare `scenes/app/main.tscn` e `scenes/stage/quiz_stage.tscn`.
5. Costruire il palco con primitive: pavimento, podio, fondale e luci.
6. Aggiungere una telecamera e un titolo provvisorio.
7. Eseguire il progetto e verificare che la composizione sia leggibile sullo schermo.

## 12. Decisioni ancora aperte

- Stile definitivo del presentatore e dei personaggi.
- Asset 3D da creare e asset da reperire con licenze adatte.
- Soluzione di rete definitiva: locale, cloud o alternativa.
- Regole precise dei round e modalità di risposta.
- Nome e identità originali del gioco.

## Principio guida

**Prima una demo piccola, spettacolare e giocabile; poi il multiplayer; infine la varietà di contenuti.**

La demo iniziale deve dimostrare ritmo, personalità e atmosfera. L'architettura deve consentire di sostituire l'input simulato con gli smartphone senza riscrivere il motore di gioco.
