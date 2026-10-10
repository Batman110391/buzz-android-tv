# CLAUDE.md — BUZZ (quiz party 3D, Godot 4 → Fire TV)

Caricato in ogni sessione: tenerlo corto.

## Fonti di verità
- `PLAN.md`: decisioni, architettura, roadmap. Leggere **solo la sezione che serve**.
- `TASKS.md`: bacheca dei task. È la memoria tra sessioni: leggerla all'avvio.
- `INITIAL_PLAN.md`: visione originale, superata da PLAN.md. Non leggerla salvo richiesta.

## Ruoli
- **Supervisore (utente):** decide, approva, fa le azioni fisiche (TV, telefoni). Non scrive codice. Risposte in italiano, brevi.
- **Sessione padre (Opus 5.5, effort high):** pianifica, divide i task, lancia i worker in parallelo, **verifica** il loro lavoro, aggiorna la documentazione. Scrive codice solo per task banali (un file, pochi minuti) o per i file condivisi.
- **Worker (`.claude/agents/worker.md`, Sonnet 5.5, effort low):** esegue un solo task, senza decisioni di design.

## Ciclo di lavoro
1. Sessione nuova e pulita (`/clear` tra un blocco e l'altro). Niente affidamento sulla chat precedente.
2. Il padre legge `TASKS.md`, sceglie i task `todo` con dipendenze soddisfatte.
3. Task indipendenti → worker **in parallelo** (max 3-4). Ogni worker tocca **solo i file elencati nel suo task**.
4. I file condivisi (`project.godot`, `main.tscn`, `main.gd`) li modifica **solo il padre**, che collega i pezzi.
5. Il padre verifica con il comando di check del task (test headless, avvio, screenshot) e `git diff`, **non rileggendo tutto**.
6. Il padre aggiorna `TASKS.md` (stato + una riga di log) e le checkbox in `PLAN.md`, poi fa il commit.
7. Fine milestone → approvazione del supervisore.

## Prompt ai worker (formato fisso)
`Task Txx — <titolo>`, file consentiti, criteri di accettazione, comando di check, contesto minimo (solo le righe di PLAN.md necessarie). Il worker non deve leggere altro.

## Regole anti-spreco di token
- Niente worker per task banali: costa di più spiegarlo che farlo.
- Leggere solo i file e le sezioni necessari; niente esplorazioni "per sicurezza".
- Report dei worker: max 10 righe (file toccati, esito del check, problemi). Niente codice incollato.
- Non rifare il lavoro di un worker: se il check fallisce, rimandarlo con l'errore preciso.
- Web: ricerca `standard`; Context7 solo per le API Godot di cui non si è sicuri.
- Nessun riassunto finale ridondante; nessuna documentazione oltre a PLAN.md, TASKS.md e commenti essenziali.
- Effort più alto per un worker (`medium`) solo se un task è fallito due volte o è chiaramente difficile.

## Toolchain (verificata)
- Godot 4.7.2 console: `C:\Users\simon\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` (GUI: stessa cartella, senza `_console`)
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot` (nel PATH c'è il JDK 11: non usarlo)
- Android SDK: `C:\Users\simon\AppData\Local\Android\Sdk` · keystore debug: `C:\Users\simon\.android\debug.keystore`
- Fire TV: `192.168.1.61:5555` (AFTKRT). **ABI solo `armeabi-v7a`** (userland 32 bit). Ha una VPN (tun0 172.16.0.2).
- **Usare SOLO l'adb dell'SDK** (`...AndroidSdkplatform-toolsdb.exe`): quello in `C:platform-tools` è vecchio e i due si chiudono il daemon a vicenda.
- Export + install: `godot --headless --path . --export-debug "Android" export/buzz-debug.apk` → `adb install -r` → `adb shell monkey -p com.buzz.quizparty 1`. Gli FPS bassi nei primi secondi sono normali (avvio).
- Screenshot senza editor: avvio non headless con `--write-movie <dir>/shot.png --quit-after 30`

## Convenzioni tecniche
- Godot 4.x stabile, renderer **Compatibility**, 1920×1080, GDScript con tipi statici.
- Regole in `game/game.gd` senza nodi grafici; la grafica reagisce ai segnali.
- Test: `godot --headless --script tests/test_game.gd` (esce con codice ≠ 0 se fallisce).
- Asset solo gratuiti, annotati in `assets/LICENSES.md`. Niente asset, nomi o audio di Buzz/Sony.
- Mai lasciare il server della TV aperto a input non validati (vedi PLAN.md §4).
