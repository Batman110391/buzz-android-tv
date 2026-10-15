# Quizzone!

Quiz party in italiano per la TV di casa, fatto con Godot 4 e pensato per la **Fire TV Stick 4K Max**.
Si gioca da 2 a 6 giocatori usando il telefono come controller (pagina web, niente app da installare), con i
conduttori Tony Scintilla e Gilda Lampo e minigiochi come Dito Veloce, Passa la Bomba, Ruba Punti, Torta in Faccia,
Metti in Ordine e il finale Conto alla Rovescia.

## Avvio
- Godot 4.7, renderer Compatibility. Aprire la cartella del progetto ed eseguire `main.tscn`.
- Partita automatica con soli bot: `godot --path . -- --demo`.
- Test: `godot --headless --script tests/test_game.gd` (e gli altri in `tests/`).
- Controllo delle domande: `node tools/domande_check.mjs`.

## Licenze
- **Codice:** MIT (vedi `LICENSE`).
- **Asset:** ognuno con la sua licenza, elencata in `assets/LICENSES.md`.
- **Voci:** generate con [ElevenLabs](https://elevenlabs.io) (elevenlabs.io), piano gratuito: solo uso non commerciale.
