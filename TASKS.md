# TASKS.md — Bacheca dei task

Stati: `todo` · `doing` · `review` (fatto, da verificare) · `done` · `blocked`
Esecutore: **P** = sessione padre · **W** = worker Sonnet · **S** = supervisore

## M0 — Prova tecnica

| ID | Task | Esec. | Dipende da | File consentiti | Check | Stato |
|---|---|---|---|---|---|---|
| T01 | `git init`, `.gitignore` per Godot, primo commit dei documenti | P | — | `.gitignore` | `git status` pulito | todo |
| T02 | Installare Godot 4.x stabile, OpenJDK 17, Android SDK (cmdline-tools, platform-tools, build-tools, platform), export template Godot; creare il keystore di debug | W | approvazione S | nessun file del progetto | `godot --version`, `adb --version`, `java -version` | todo |
| T03 | Sulla Fire TV: attivare Opzioni sviluppatore → Debug ADB + App di origine sconosciuta; comunicare IP e generazione della 4K Max | S | — | — | IP ricevuto | todo |
| T04 | Progetto Godot: `project.godot` (Compatibility, 1920×1080, schermo sempre acceso) + scena di prova: cubo che ruota, etichetta FPS, il tasto centrale del telecomando / `Invio` cambia colore | W | T01, T02 | `project.godot`, `main.tscn`, `main.gd` | avvio headless senza errori + screenshot | todo |
| T05 | `net/server.gd`: HTTP su 8080 che serve `net/controller.html`, WebSocket su 8081; segnale `button_pressed(player_id)`. `controller.html`: un pulsante grande | W | T02 | `net/server.gd`, `net/controller.html` | dal browser del PC su `localhost:8080` il pulsante produce il segnale (log) | todo |
| T06 | Collegare `server.gd` alla scena di prova (pulsante del telefono → colore del cubo) | P | T04, T05 | `main.gd` | prova da PC | todo |
| T07 | Preset di esportazione Android (permesso INTERNET), `adb connect`, installazione e avvio sulla TV | W | T03, T06 | `export_presets.cfg` | l'app si avvia sulla TV | todo |
| T08 | Prova sulla TV: FPS, telecomando, pulsante dal telefono, nessun screensaver | S + P | T07 | — | checklist M0 in PLAN.md | todo |

**Parallelo possibile:** T03 subito, in qualsiasi momento · T04 ∥ T05 dopo T02.

## Log
- 2026-10-10 — Piano scritto (PLAN.md), flusso di lavoro definito (CLAUDE.md, worker). In attesa dell'approvazione del supervisore.
