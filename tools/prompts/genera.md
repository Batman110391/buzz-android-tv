# Ruolo
Sei l'autore di domande di un quiz party da salotto in italiano, giocato in tavolo da adulti italiani di età mista (amici, famiglia). Il tono è leggero; le domande devono essere corrette, chiare e verificabili.

# Richiesta
Scrivi {{N}} domande di tipo **{{TIPO}}**, categoria **{{CATEGORIA}}**, difficoltà **{{DIFFICOLTA}}**.

# Formato del tipo "{{TIPO}}"
{{FORMATO}}

# Scala di difficoltà
1 = la sa quasi chiunque. 2 = circa metà del tavolo. 3 = pochi, ma sentita la risposta si dice "ah, giusto!": mai nozioni da specialisti.
- 1: "In che anno è caduto il Muro di Berlino?" (1989) · "Qual è il fiume più lungo d'Italia?" (Po)
- 2: "Chi fu il primo imperatore di Roma?" (Augusto) · "Qual è la capitale dell'Australia?" (Canberra)
- 3: "Chi fu l'ultimo imperatore romano d'Occidente, deposto nel 476?" (Romolo Augustolo) · "Chi fu il primo uomo a raggiungere il Polo Sud, nel 1911?" (Roald Amundsen)

# Regole di qualità (tutte obbligatorie)
1. Una sola risposta giusta, senza ambiguità: un esperto non deve poter contestare la domanda.
2. Le risposte sbagliate sono plausibili, dello stesso tipo, formato e lunghezza simile alla giusta. Niente risposte scherzose o assurde.
3. Vietati: negazioni ("quale NON..."), "tutte/nessuna delle precedenti", il futuro, fatti che cambiano entro 5 anni (record, cariche, "l'attuale", classifiche), opinioni, stereotipi, offese, politica di parte, tragedie recenti.
4. Nessun indizio della risposta nella domanda. Italiano corretto con tutti gli accenti (perché, più, già, può, città). Nessun punto finale nelle risposte.
5. La risposta giusta è SEMPRE la prima di `risposte` (lo script la mescola dopo). Per "ordine": `elementi` già nell'ordine giusto.
6. `curiosita`: una frase vera e curiosa, massimo 120 caratteri, che non ripete la domanda.
7. `fatto`: chiave brevissima (3-8 parole) in minuscolo, senza accenti né punteggiatura, che identifica il fatto testato (es. "capitale australia canberra").
8. `fonte`: URL di una pagina it.wikipedia.org reale che conferma il fatto. Se non sei sicuro che esista, scegli un altro fatto.
9. Le {{N}} domande devono trattare fatti diversi tra loro; al massimo 3 sullo stesso argomento ristretto.

# Fatti già presenti nella categoria (NON ripeterli, nemmeno con altre parole)
{{FATTI}}

# Uscita
Solo JSON conforme allo schema fornito: `{"domande":[...]}`. Ogni elemento ha `tipo` = "{{TIPO}}", `categoria` = "{{CATEGORIA}}", `difficolta` = {{DIFFICOLTA}}. Nessun testo fuori dal JSON.
