extends Node2D
## Flusso della partita: Titolo -> Lobby (←/→ numero di giocatori, OK) -> Scelta dei giochi -> un round per gioco
## (Game, o Bomba per Passa la Bomba) -> Finale -> Titolo. Regole dei round: PLAN.md §2.
## Si gioca dal telefono (+ bot); il telecomando serve solo a preparare la partita. `-- --demo`: tutto automatico.

const DOMANDE := 5  # per round
const GIOCHI := [  # solo quelli già fatti (G3f aggiunge gli altri e Conto alla Rovescia)
	{"id": "accumula", "titolo": "Accumula Punti", "icona": "💰", "tipo": "classica", "breve": "Più rispondi, più incassi.",
		"regola": "Rispondi giusto per fare 500 punti. Hai 15 secondi per ogni domanda!"},
	{"id": "dito", "titolo": "Dito Veloce", "icona": "⚡", "tipo": "lampo", "breve": "Il più rapido incassa di più.",
		"regola": "I punti scendono da 1000 a zero: rispondi giusto e prendi quelli che restano!"},
	{"id": "bomba", "titolo": "Passa la Bomba", "icona": "💣", "tipo": "lampo", "breve": "Non farla esplodere in mano.",
		"regola": "Rispondi giusto per passare la bomba. Se ti esplode in mano perdi 500 punti!"},
	{"id": "ruba", "titolo": "Ruba Punti", "icona": "🦝", "tipo": "classica", "breve": "Sfila i punti agli altri.",
		"regola": "Chi risponde giusto ruba 300 punti a un avversario a scelta!"},
]
const RUBA_TEMPO := 10.0
const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GIOCATORI := [
	["Gastone", "F2384A", "chef"], ["Nonna Pina", "2F7BFF", "nonna"], ["Ugo", "33C759", "zombi"],
	["Brioche", "FFD43B", "gatto"], ["Don Ciccio", "A855F7", "boss"], ["Vanessa", "FF8A1F", "diva"],
]
const FUMETTO_TITOLO := Vector2(560, 40)
const FUMETTO_DOMANDA := Vector2(420, 470)
const FUMETTO_BASSO := Vector2(420, 1026)  # y = bordo basso: il fumetto sale quanto serve
const FUMETTO_FINALE := Vector2(96, 190)
const DENTRO := [20.0, 1468.0]  # x dei conduttori in scena (Tony a sinistra, Gilda a destra)
const FUORI := [-700.0, 2500.0]

var _demo := "--demo" in OS.get_cmdline_user_args()
var _fase := ""  # titolo | lobby | round | domanda | rivela | finale | (transizione)
var _titolo: SchermataTitolo
var _lobby: SchermataLobby
var _round: SchermataRound
var _scelta: SchermataScelta
var _s: SchermataDomanda
var _bomba_ui: BombaUI
var _bomba: Bomba
var _giochi: Array[String] = []  # id dei giochi scelti, nell'ordine di GIOCHI
var _r := 0  # round in corso (indice in _giochi)
var _punti := {}  # pid -> punti totali della partita
var _ruba_da: Array = []  # Ruba Punti: chi ha indovinato e non ha ancora rubato
var _t := 0.0  # Bomba: secondi dall'inizio della domanda
var _quando_b := INF  # Bomba: quando risponde il bot che ce l'ha
var _finale: SchermataFinale
var _cond: Array[Personaggio] = []  # 0 = Tony (entra da sinistra), 1 = Gilda (entra da destra)
var _fumetti: Array[PanelContainer] = []  # uno per conduttore
var _testi: Dictionary
var _sottotitoli := true  # fumetti con le battute dei conduttori; si cambia dal titolo, salvato in user://
var _domande := Domande.new()
var _game: Game
var _n := 0  # giocatori in partita (= _g.size())
var _g: Array[Dictionary] = []  # giocatori in partita, per pid: {nome, id, colore, slot, bot}
var _bot := {}  # slot della lobby -> personaggio dei bot (restano tra una partita e l'altra)
var _pid_di := {}  # slot -> pid dei telefoni in partita
var _server: Node
var _pers: Array[Personaggio] = []
var _q: Dictionary
var _i := 0  # indice della domanda in corso
var _parla := false  # un conduttore sta parlando
var _quando: Array[float] = []
var _scelte := {}  # pid -> risposta
var _hurry := false
var _ult_sec := 0  # ultimo secondo del timer che ha fatto tic
# battute di Tony e Gilda: ogni situazione è un mazzo (nessuna frase torna finché non sono uscite tutte) + pause tra i commenti
var _mazzi := {}  # prefisso -> chiavi ancora da pescare
var _ultima := {}  # prefisso -> ultima chiave uscita
var _presentati := {}  # personaggi già presentati da Tony in questa sessione
var _salta := false  # OK durante le presentazioni
var _ult_commento := -9  # domanda dell'ultimo commento dopo la rivelazione
var _ult_buzz := -9
var _ult_hurry := -9
var _capo := -1  # chi è primo da solo in classifica (-1 = nessuno o pari)
var _perf := FileAccess.file_exists("user://perf.txt")
var _pt := 0.0
var _pn := 0


func _ready() -> void:
	add_child(Palco.new())
	_titolo = SchermataTitolo.new()
	_lobby = SchermataLobby.new()
	_round = SchermataRound.new()
	_scelta = SchermataScelta.new()
	_s = SchermataDomanda.new()
	_finale = SchermataFinale.new()
	for sc: CanvasItem in [_titolo, _lobby, _scelta, _round, _s, _finale]:
		sc.visible = false
		add_child(sc)
	_scelta.confermato.connect(_scelti)
	_bomba_ui = BombaUI.new()
	_bomba_ui.position = Vector2(1664, 88)  # al posto del timer
	_bomba_ui.visible = false
	_s.add_child(_bomba_ui)
	_round.position.y = -70.0  # lascia spazio al fumetto di Tony sotto la carta
	_server = preload("res://net/server.gd").new()
	add_child(_server)
	_server.joined.connect(_tel_entra)
	_server.left.connect(_tel_esce)
	_server.answered.connect(func(slot: int, q: int, scelta: int) -> void:
		if _pid_di.has(slot) and q == _i:
			_risponde(_pid_di[slot], scelta))
	_server.stole.connect(func(slot: int, q: int, vittima: int) -> void:
		if _fase == "ruba" and _pid_di.has(slot) and q == _i:
			for pid in _n:
				if _g[pid]["slot"] == vittima:
					_furto(_pid_di[slot], pid))
	_lobby.setup(_server.url(), _server.codice)
	for id: String in ["host", "gilda"]:
		var c := Personaggio.new()
		c.setup(id)
		c.position.x = FUORI[_cond.size()]
		add_child(c)
		_cond.append(c)
	_fumetti = [_crea_fumetto(INK), _crea_fumetto(Color("FF3DA8"))]
	var cfg := ConfigFile.new()
	if cfg.load("user://impostazioni.cfg") == OK:
		_sottotitoli = cfg.get_value("audio", "sottotitoli", true)
	_titolo.set_sottotitoli(_sottotitoli)
	var re := RegEx.create_from_string(r"\[[^\]]*\]\s*")
	for f in ["lines", "gilda"]:
		var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/voice/%s.json" % f))
		for k: String in lines:
			if ResourceLoader.exists("res://assets/voice/%s.mp3" % k):  # solo le battute già generate
				_testi[k] = re.sub(str(lines[k]), "", true)
	_domande.carica()
	_mostra_titolo()


# ---------------------------------------------------------------- titolo
func _mostra_titolo() -> void:
	_fase = "titolo"
	Sfx.music("menu")
	_titolo.mostra()
	_cond[0].position = Vector2(60, 300)  # sul titolo c'è posto per Tony; Gilda entra solo quando parla
	_cond[0].scale = Vector2.ONE * 2.5
	await _dici(_pesca("menu"), "saluto", FUMETTO_TITOLO)
	_esci([1])
	if _demo and _fase == "titolo":
		_vai_lobby()
	for _volta in 2:  # poi i conduttori richiamano l'attenzione al massimo due volte, con calma, e tacciono
		await get_tree().create_timer(28.0).timeout
		if _fase != "titolo":
			return
		if not _parla:
			await _dici(_pesca("filler"), "annuncio", FUMETTO_TITOLO)
			_esci([1])


func _vai_lobby() -> void:
	_fase = "transizione"
	_titolo.nascondi()
	_nascondi_fumetti()
	await _esci()
	_fase = "lobby"
	_pid_di.clear()
	var tel: Dictionary = _server.giocatori()
	for i in 6:
		_lobby.togli(i)
		if tel.has(i):
			_lobby.aggiungi(i, tel[i]["avatar"], tel[i]["nome"], _colore(tel[i]["avatar"]))
		elif _bot.has(i):
			_lobby.aggiungi(i, _bot[i], _dati(_bot[i])[0], _colore(_bot[i]))
	_lobby.visible = true
	_server.apri_lobby()
	_server.invia_stato({"fase": "lobby"})
	if _demo:
		for _k in 5:
			await get_tree().create_timer(0.5).timeout
			_cambia_giocatori(1)
		await get_tree().create_timer(1.0).timeout
		_vai_scelta()


func _dati(id: String) -> Array:
	for d: Array in GIOCATORI:
		if d[2] == id:
			return d
	return GIOCATORI[0]


func _colore(id: String) -> Color:
	return Color(_dati(id)[1])


## Telefono entrato nella lobby (il server ha già controllato posto e personaggio liberi).
func _tel_entra(slot: int, nome: String, avatar: String) -> void:
	if _fase == "lobby":
		_lobby.aggiungi(slot, avatar, nome, _colore(avatar))
		Sfx.play("pop")


func _tel_esce(slot: int) -> void:
	if _fase == "lobby":
		_lobby.togli(slot)


## ←/→ nella lobby: aggiunge un bot (primo posto e primo personaggio liberi) o toglie l'ultimo. Niente voce: si presentano a inizio partita.
func _cambia_giocatori(d: int) -> void:
	var tel: Dictionary = _server.giocatori()
	if d > 0:
		var presi: Array = _bot.values()
		for s in tel:
			presi.append(tel[s]["avatar"])
		for slot in 6:
			if tel.has(slot) or _bot.has(slot):
				continue
			for g: Array in GIOCATORI:
				if not g[2] in presi:
					_bot[slot] = g[2]
					_lobby.aggiungi(slot, g[2], g[0], Color(g[1]))
					Sfx.play("pop")
					_server.set_bot(_bot)
					return
			return
	elif not _bot.is_empty():
		var slot: int = _bot.keys().max()
		_bot.erase(slot)
		_lobby.togli(slot)
		_server.set_bot(_bot)


# ---------------------------------------------------------------- scelta dei giochi
## Chi ha il telecomando sceglie i giochi (la lobby resta aperta: i telefoni possono ancora entrare).
func _vai_scelta() -> void:
	if _server.giocatori().size() + _bot.size() < 2:
		return
	_fase = "scelta"
	_lobby.visible = false
	var g: Array = []
	for d: Dictionary in GIOCHI:
		g.append({"id": d["id"], "titolo": d["titolo"], "icona": d["icona"], "regola": d["breve"], "fisso": false})
	_scelta.visible = true
	_scelta.mostra(g)
	if _demo:
		await get_tree().create_timer(1.5).timeout
		var tutti: Array[String] = []
		for d: Dictionary in GIOCHI:
			tutti.append(d["id"])
		_scelti(tutti)


func _scelti(ids: Array[String]) -> void:
	if _fase != "scelta":
		return
	_giochi = ids
	_scelta.nascondi()
	_vai_round()


# ---------------------------------------------------------------- presentazioni + round + domande
func _vai_round() -> void:
	var tel: Dictionary = _server.giocatori()
	if tel.size() + _bot.size() < 2:  # i telefoni sono usciti durante la scelta
		_fase = "lobby"
		_scelta.visible = false
		_lobby.visible = true
		return
	_server.chiudi_lobby()
	_g.clear()
	for slot in 6:  # pid in ordine di posto nella lobby
		if tel.has(slot):
			_pid_di[slot] = _g.size()
			_g.append({"nome": tel[slot]["nome"], "id": tel[slot]["avatar"], "slot": slot, "bot": false})
		elif _bot.has(slot):
			_g.append({"nome": _dati(_bot[slot])[0], "id": _bot[slot], "slot": slot, "bot": true})
	for p in _g:
		p["colore"] = _colore(p["id"])
	_n = _g.size()
	_server.invia_stato({"fase": "attesa"})
	_fase = "round"
	_lobby.visible = false
	await _commenta(_pesca("intro"), "saluto", FUMETTO_BASSO, false)
	await _presenta_giocatori()
	_inizia_partita()
	_r = 0
	_prossimo_round()


## Primo piano di ogni giocatore non ancora presentato in questa sessione, con la battuta di Tony; OK salta tutto.
## ponytail: qui andrà il caricamento in background delle domande dal server quando ci sarà (D5).
func _presenta_giocatori() -> void:
	_fase = "presentazioni"
	_salta = false
	for i in _n:
		var id: String = _g[i]["id"]
		if _salta:
			break
		if _presentati.has(id):
			continue
		_presentati[id] = true
		var pp := _primo_piano(i)
		await _dici(_pesca("pres_" + id), "annuncio", FUMETTO_BASSO)
		pp.queue_free()


## Personaggio grande al centro che entra dal basso + nome nella striscia del suo colore che entra da destra.
func _primo_piano(i: int) -> Node2D:
	var n := Node2D.new()
	add_child(n)
	move_child(n, _cond[0].get_index())  # sotto i conduttori e i fumetti
	var p := Personaggio.new()
	p.setup(_g[i]["id"])
	p.scale = Vector2.ONE * 3.6
	p.position = Vector2(328, 1100)
	n.add_child(p)
	var piedistallo := Panel.new()  # copre il taglio del busto (coordinate della tela, scalate con il personaggio)
	piedistallo.add_theme_stylebox_override("panel", Risposta.box(_g[i]["colore"], INK, 2, 4, 6))
	piedistallo.position = Vector2(28, 168)
	piedistallo.size = Vector2(184, 60)
	p.add_child(piedistallo)
	p.stato("esulta")
	var striscia := Panel.new()
	striscia.add_theme_stylebox_override("panel", Risposta.box(_g[i]["colore"], INK, 8, 16, 40))
	striscia.size = Vector2(700, 150)
	striscia.position = Vector2(1920, 220)
	striscia.rotation_degrees = -3
	striscia.add_child(Risposta.etichetta(_g[i]["nome"], Risposta.font_display(), 96, INK, 700, 140))
	var pers: String = _dati(_g[i]["id"])[0]
	if pers != _g[i]["nome"]:  # nome scelto sul telefono: sotto, in piccolo, il nome del personaggio
		striscia.size.y = 200
		var sotto := Risposta.etichetta(pers, Risposta.font_display(), 48, INK, 700, 60)
		sotto.position.y = 122
		striscia.add_child(sotto)
	n.add_child(striscia)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "position:y", 120.0, 0.45)
	tw.tween_property(striscia, "position:x", 1120.0, 0.45).set_delay(0.15)
	Sfx.play("pop")
	return n


## Podi e punti della partita (una volta sola: i round li riusano).
func _inizia_partita() -> void:
	var g: Array = []
	_punti.clear()
	for i in _n:
		g.append({"nome": _g[i]["nome"], "colore": _g[i]["colore"], "punti": 0})
		_punti[i] = 0
	_s.setup_podi(g)
	_pers.clear()
	for i in _n:
		var p := Personaggio.new()
		p.setup(_g[i]["id"])
		_s.podio(i).metti_personaggio(p)
		_pers.append(p)
	_capo = -1


func _gioco() -> Dictionary:
	for d: Dictionary in GIOCHI:
		if d["id"] == _giochi[_r]:
			return d
	return GIOCHI[0]


func _nomi() -> Array[String]:
	var nomi: Array[String] = []
	for p in _g:
		nomi.append(p["nome"])
	return nomi


## Carta del round + battuta, poi il gioco; dopo l'ultimo round il finale.
func _prossimo_round() -> void:
	if _r >= _giochi.size():
		_fine(_classifica())
		return
	var gi := _gioco()
	_fase = "round"
	_s.visible = false
	_server.invia_stato({"fase": "attesa"})
	_round.mostra(_r + 1, _giochi.size(), gi["titolo"].to_upper(), gi["regola"], gi["icona"])
	await get_tree().create_timer(0.6).timeout
	var k: String = ["round_1", "gilda_round_1"].pick_random() if _r == 0 and gi["id"] == "accumula" \
			else ["round_2", "gilda_round_2", "gilda_round_3"][_r % 3]  # le battute generiche, a turno
	await _commenta(k, "annuncio", FUMETTO_BASSO)
	_round.nascondi()
	for i in _n:
		_s.podio(i).set_punti(_punti[i])
	_s.visible = true
	Sfx.music("question")
	_ult_commento = -9
	_ult_buzz = -9
	_ult_hurry = -9
	if gi["id"] == "bomba":
		_inizia_bomba()
		return
	_game = Game.new()
	_game.question_started.connect(_domanda)
	_game.question_resolved.connect(_rivela)
	_game.game_over.connect(_fine_round)
	_game.setup(_nomi(), _domande.pesca(gi["tipo"], DOMANDE), DOMANDE, gi["id"], _punti)
	_game.start()
	_game.advance()


func _fine_round(classifica: Array) -> void:
	for r: Dictionary in classifica:
		_punti[r["id"]] = r["score"]
	_s.mostra_timer(true)
	_bomba_ui.visible = false
	_r += 1
	_prossimo_round()


## Stesso formato di Game._ranking().
func _classifica() -> Array:
	var r: Array = []
	for i in _n:
		r.append({"id": i, "name": _g[i]["nome"], "score": _punti[i]})
	r.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"] or (a["score"] == b["score"] and a["id"] < b["id"]))
	return r


# ---------------------------------------------------------------- Passa la Bomba
func _inizia_bomba() -> void:
	_bomba = Bomba.new()
	_bomba.question_started.connect(_b_domanda)
	_bomba.passata.connect(func(_da: int, _a: int) -> void: Sfx.play("correct"))
	_bomba.sbagliata.connect(func(_pid: int) -> void: Sfx.play("wrong"))
	_bomba.esplosa.connect(_b_esplosa)
	_bomba.round_finito.connect(_fine_round)
	_bomba.setup(_nomi(), _domande.pesca("lampo", 40), _punti)
	_i = -1
	_s.mostra_timer(false)
	_bomba_ui.visible = true
	_bomba_ui.nuova()
	_bomba_ui.dondola()
	_bomba.start()


func _b_domanda(q: Dictionary, chi: int) -> void:
	_fase = "bomba"
	_q = q
	_i += 1
	_t = 0.0
	_scelte.clear()
	var umano: bool = not _demo and not _g[chi]["bot"]
	_quando_b = INF if umano else randf_range(1.5, 4.5)
	_s.mostra_domanda(_i + 1, 0, _gioco()["titolo"].to_upper(), q["domanda"], q["risposte"])
	for pid in _n:
		_pers[pid].stato("attesa")
	_s.podio(chi).set_stato("bomba")
	_s.podio(chi).badge("Tocca a te!")
	_server.invia_stato({"fase": "domanda", "gioco": "bomba", "q": _i, "tot": 0, "domanda": q["domanda"], "risposte": q["risposte"],
			"bomba": _g[chi]["slot"], "bomba_nome": _g[chi]["nome"]})


func _b_esplosa(pid: int, punti: Dictionary) -> void:
	_fase = "esplosione"
	var persi: int = _punti[pid] - punti[pid]
	_punti = punti
	_bomba_ui.esplodi()
	Sfx.play("explosion")
	_s.podio(pid).set_stato("ko")
	_s.podio(pid).badge("−%d" % persi)
	_s.podio(pid).set_punti(punti[pid])
	_server.invia_stato({"fase": "rivela"})
	for slot in _pid_di:
		if _pid_di[slot] == pid:
			_server.invia_esito(slot, {"giusta": false, "punti": -persi, "totale": punti[pid], "posizione": _posizione(pid), "testo": "BOOM! −%d" % persi})
	await get_tree().create_timer(3.0).timeout
	_bomba.advance()  # bomba successiva (-> _b_domanda) oppure fine round (-> _fine_round)
	if _fase == "bomba":
		_bomba_ui.nuova()
		_bomba_ui.dondola()


func _posizione(pid: int) -> int:
	var pos := 1
	for altro in _n:
		if _punti[altro] > _punti[pid]:
			pos += 1
	return pos


func _domanda(i: int, tot: int, q: Dictionary) -> void:
	_fase = "domanda"
	_q = q
	_i = i
	_hurry = false
	_scelte.clear()
	_quando.clear()
	for pid in _n:
		var umano: bool = not _demo and not _g[pid]["bot"]  # si gioca solo dal telefono: il telecomando non è un giocatore
		_quando.append(INF if umano else randf_range(2.0, _game.tempo_domanda() * 0.75))
		_pers[pid].stato("pensa")
	var gi := _gioco()
	_s.mostra_domanda(i + 1, tot, gi["titolo"].to_upper(), q["domanda"], q["risposte"])
	_server.invia_stato({"fase": "domanda", "gioco": gi["id"], "q": i, "tot": tot, "domanda": q["domanda"], "risposte": q["risposte"], "tempo": _game.tempo_domanda()})
	_s.set_tempo(_game.tempo_domanda(), _game.tempo_domanda())
	if i == 0 and _r == 0:
		_dici(_pesca("qfirst"), "annuncio")
	elif i == tot - 1 and _r == _giochi.size() - 1:
		_dici(_pesca("qlast"), "annuncio")
	elif _ult_commento < i - 1 and randf() < 0.5:  # se dopo l'ultima domanda è stato zitto
		_dici(_pesca("qnext"), "annuncio")


func _risponde(pid: int, scelta: int) -> void:
	if _fase == "bomba":
		_bomba.submit_answer(pid, scelta)  # giusta o sbagliata, parte subito la domanda dopo (_b_domanda)
		return
	if _fase != "domanda" or not _game.submit_answer(pid, scelta):
		return
	if _scelte.is_empty() and _i - _ult_buzz >= 3 and randf() < 0.5 and not _parla:
		_ult_buzz = _i
		_dici(_pesca("firstbuzz"), "sorpresa")
	_scelte[pid] = scelta
	_s.risposto(pid)
	Sfx.play("lock")


func _process(dt: float) -> void:
	if _perf:
		_pt += dt
		_pn += 1
		if _pt >= 2.0:
			print("PERF fps=", snappedf(_pn / _pt, 0.1), " phase=", _fase)
			_pt = 0.0
			_pn = 0
	if _fase == "bomba":
		_t += dt
		if _t >= _quando_b:  # bot con la bomba: le lampo le indovina più spesso
			_risponde(_bomba.chi_ha_bomba(), _q["correct"] if randf() < 0.7 else randi() % 4)
		_bomba.tick(dt)  # può emettere esplosa -> _b_esplosa
		return
	if _fase == "ruba":
		_t += dt
		return
	if _fase != "domanda":
		return
	var trascorso := _game.tempo_domanda() - _game.time_left()
	for pid in _n:
		if not _scelte.has(pid) and trascorso >= _quando[pid]:
			# bot: indovina poco più di una volta su due
			_risponde(pid, _q["correct"] if randf() < 0.55 else randi() % 4)
	if _gioco()["id"] == "dito":
		_s.set_contatore(_game.punti_ora())
	else:
		_s.set_tempo(_game.time_left(), _game.tempo_domanda())
	var sec := ceili(_game.time_left())
	if sec != _ult_sec and sec <= 5 and sec >= 3 and _scelte.size() < _n:  # tic a 5 e 4, da 3 il ticchettio veloce (dura 2 s)
		Sfx.play("tick_fast" if sec == 3 else "tick")
	_ult_sec = sec
	if _game.time_left() <= 5.0 and not _hurry and _scelte.size() < _n:
		_hurry = true
		if not _parla and _i - _ult_hurry >= 3:
			_ult_hurry = _i
			_dici(_pesca("hurry"), "annuncio")
	_game.tick(dt)  # può emettere question_resolved -> _rivela


func _rivela(corretta: int, risultati: Dictionary, punteggi: Dictionary) -> void:
	_fase = "rivela"
	var punti: Array = []
	var giusti: Array = []
	var presi := _game.punti_presi()
	_punti = punteggi.duplicate()
	for pid in _n:
		punti.append(presi.get(pid, 0))
		if risultati[pid]:
			giusti.append(pid)
	var ultimo_round := _r == _giochi.size() - 1
	if _i == DOMANDE - 1 and ultimo_round:  # ultima domanda della partita: rullo di tamburi prima della rivelazione
		Sfx.play("drumroll")
		await get_tree().create_timer(2.0).timeout
	_s.rivela(corretta, _scelte, punti)
	var gioco: String = _gioco()["id"]
	if gioco == "dito":  # al posto di "+740": ordine di arrivo e tempo
		var n := 1
		for d: Dictionary in _game.ordine_giusti():
			_s.podio(d["pid"]).badge("%d° %s s" % [n, str(snappedf(d["secondi"], 0.1)).replace(".", ",")])
			n += 1
	elif gioco == "ruba":
		for pid in _n:
			_s.podio(pid).badge("")
	_server.invia_stato({"fase": "rivela"})
	for slot in _pid_di:
		var pid: int = _pid_di[slot]
		_server.invia_esito(slot, {"giusta": risultati[pid], "punti": punti[pid], "totale": punteggi[pid], "posizione": _posizione(pid)})
	Sfx.play("correct" if not giusti.is_empty() else "wrong")
	if giusti.is_empty():
		Sfx.play("aww")
	elif giusti.size() == _n:
		Sfx.play("applause")
	await get_tree().create_timer(1.8).timeout
	if gioco == "ruba" and not giusti.is_empty():
		await _fase_ruba(giusti)
		punteggi = _punti.duplicate()
	while _parla:  # una battuta (o un duetto) della domanda non è ancora finita
		await get_tree().process_frame
	var capo := _primo(punteggi)
	var nuovo_capo := capo != -1 and capo != _capo and _i > 0
	_capo = capo
	# i conduttori commentano solo se c'è qualcosa da dire, e mai due domande di fila (salvo metà partita)
	var k := ""
	var g := "esulta"
	if _i == DOMANDE - 1 and _r == (_giochi.size() - 1) / 2:  # a metà partita punzecchia l'ultimo
		k = _pesca("last_" + _g[_ultimo(punteggi)]["id"])
		g = "delusione"
	elif _i - _ult_commento >= 2:
		if giusti.size() == 1 and _n >= 3:
			k = _pesca("solo_" + _g[giusti[0]]["id"])
		elif giusti.is_empty():
			k = _pesca("noneright")
			g = "delusione"
		elif giusti.size() == _n:
			k = _pesca("allright")
		elif nuovo_capo:
			k = _pesca("lead")
		elif randf() < 0.4:
			k = _pesca("someright")
	if k == "":
		await get_tree().create_timer(1.2).timeout
	else:
		_ult_commento = _i
		await _commenta(k, g, FUMETTO_DOMANDA)
	_game.advance()  # REVEAL -> SCOREBOARD
	_game.advance()  # -> domanda successiva oppure FINAL (game_over -> _fine_round)


## Ruba Punti: chi ha indovinato sceglie una vittima sul telefono; i bot e chi non sceglie in tempo
## rubano al primo in classifica tra gli altri.
func _fase_ruba(giusti: Array) -> void:
	_fase = "ruba"
	_t = 0.0
	_ruba_da = giusti.duplicate()
	_s.mostra_ruba(Game.RUBA_PUNTI)
	var vittime: Array = []
	var puo: Array[int] = []
	for pid in _n:
		if not giusti.has(pid):
			_s.podio(pid).set_stato("mira")
		vittime.append({"slot": _g[pid]["slot"], "name": _g[pid]["nome"], "color": "#" + (_g[pid]["colore"] as Color).to_html(false),
				"avatar": _g[pid]["id"], "punti": _punti[pid]})
	for slot in _pid_di:
		if giusti.has(_pid_di[slot]):
			puo.append(slot)
	_server.invia_stato({"fase": "ruba", "q": _i, "punti": Game.RUBA_PUNTI, "tempo": RUBA_TEMPO, "vittime": vittime, "puo": puo})
	await get_tree().create_timer(1.5).timeout
	for pid in giusti:  # i bot rubano subito
		if _g[pid]["bot"] or _demo or not _pid_di.values().has(pid):
			_furto(pid, _game.vittima_predefinita(pid))
	while not _ruba_da.is_empty() and _t < RUBA_TEMPO:
		await get_tree().process_frame
	for pid in _ruba_da.duplicate():
		_furto(pid, _game.vittima_predefinita(pid))
	await get_tree().create_timer(1.5).timeout
	_s.nascondi_ruba()
	_server.invia_stato({"fase": "rivela"})
	_fase = "rivela"


func _furto(ladro: int, vittima: int) -> void:
	var n := _game.ruba(ladro, vittima)
	if n < 0:
		return
	_ruba_da.erase(ladro)
	_punti[ladro] += n
	_punti[vittima] -= n
	_s.podio(ladro).badge("+%d" % n)
	_s.podio(ladro).set_punti(_punti[ladro])
	_s.podio(vittima).badge("−%d" % n)
	_s.podio(vittima).set_punti(_punti[vittima])
	Sfx.play("cash")
	for slot in _pid_di:
		var pid: int = _pid_di[slot]
		if pid == ladro:
			_server.invia_esito(slot, {"giusta": true, "punti": n, "totale": _punti[pid], "posizione": _posizione(pid),
					"testo": "Hai rubato %d punti a %s!" % [n, _g[vittima]["nome"]]})
		elif pid == vittima:
			_server.invia_esito(slot, {"giusta": false, "punti": -n, "totale": _punti[pid], "posizione": _posizione(pid),
					"testo": "%s ti ha rubato %d punti!" % [_g[ladro]["nome"], n]})


## Chi è primo da solo (-1 se a pari merito in testa).
func _primo(punteggi: Dictionary) -> int:
	var p := 0
	var pari := false
	for pid in range(1, _n):
		if punteggi[pid] > punteggi[p]:
			p = pid
			pari = false
		elif punteggi[pid] == punteggi[p]:
			pari = true
	return -1 if pari else p


func _ultimo(punteggi: Dictionary) -> int:
	var u := 0
	for pid in _n:
		if punteggi[pid] < punteggi[u]:
			u = pid
	return u


# ---------------------------------------------------------------- finale
func _fine(classifica: Array) -> void:
	_fase = "finale"
	_s.visible = false
	var c: Array = []
	for r: Dictionary in classifica:
		var d: Dictionary = _g[r["id"]]
		c.append({"nome": d["nome"], "colore": d["colore"], "personaggio": d["id"], "punti": r["score"]})
	Sfx.music("final")
	Sfx.play("fanfare")
	_finale.mostra(c)
	_server.invia_stato({"fase": "finale"})
	Sfx.play("rise")
	await get_tree().create_timer(2.5).timeout
	Sfx.play("applause")
	await _commenta(_pesca("final"), "annuncio", FUMETTO_FINALE, false)
	var pari: bool = classifica.size() > 1 and classifica[0]["score"] == classifica[1]["score"]
	await _commenta(_pesca("tie" if pari else "win_" + _g[classifica[0]["id"]]["id"]), "esulta", FUMETTO_FINALE, false)
	await _commenta(_pesca("outro"), "saluto", FUMETTO_FINALE)
	if _demo:
		await get_tree().create_timer(2.0).timeout
		_torna_al_titolo()


func _torna_al_titolo() -> void:
	if _fase != "finale":
		return
	_fase = "transizione"
	_finale.nascondi()
	await get_tree().create_timer(0.4).timeout
	_mostra_titolo()


# ---------------------------------------------------------------- input
func _input(e: InputEvent) -> void:
	var ok := e.is_action_pressed("ui_accept")
	match _fase:
		"titolo":
			if ok:
				_vai_lobby()
			elif e.is_action_pressed("ui_down") or _tasto(e, KEY_S):
				_sottotitoli = not _sottotitoli
				var cfg := ConfigFile.new()
				cfg.load("user://impostazioni.cfg")
				cfg.set_value("audio", "sottotitoli", _sottotitoli)
				cfg.save("user://impostazioni.cfg")
				_titolo.set_sottotitoli(_sottotitoli)
				for f in _fumetti:
					f.visible = _sottotitoli and f.visible
		"lobby":
			if ok:
				_vai_scelta()
			elif e.is_action_pressed("ui_right"):
				_cambia_giocatori(1)
			elif e.is_action_pressed("ui_left"):
				_cambia_giocatori(-1)
		"presentazioni":
			if ok:
				_salta = true
				for c in _cond:
					c.zitto()
		"scelta":
			if ok:
				_scelta.premi()
			else:
				for d: Array in [["ui_up", Vector2i.UP], ["ui_down", Vector2i.DOWN], ["ui_left", Vector2i.LEFT], ["ui_right", Vector2i.RIGHT]]:
					if e.is_action_pressed(d[0]):
						_scelta.muovi(d[1])
		"finale":
			if ok:
				_torna_al_titolo()


func _tasto(e: InputEvent, k: Key) -> bool:
	return e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == k


# ---------------------------------------------------------------- conduttori: voce + fumetti
func _crea_fumetto(bordo: Color) -> PanelContainer:
	var sb := Risposta.box(CREAM, bordo, 6, 16, 44)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 24
	sb.content_margin_bottom = 34
	var f := PanelContainer.new()
	f.add_theme_stylebox_override("panel", sb)
	f.custom_minimum_size = Vector2(900, 0)
	var l := Label.new()
	l.add_theme_font_override("font", Risposta.font_testo())
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("line_spacing", -12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(812, 0)
	f.add_child(l)
	f.visible = false
	add_child(f)
	return f


func _nascondi_fumetti() -> void:
	for f in _fumetti:
		f.visible = false


## Il conduttore della battuta `k` dice la sua (con l'eventuale risposta di Gilda) e, con `esce`, se ne vanno.
func _commenta(k: String, g: String, pos_fumetto: Vector2, esce := true) -> void:
	await _dici(k, g, pos_fumetto)
	if esce:
		await get_tree().create_timer(0.5).timeout
		_nascondi_fumetti()
		await _esci()


## 0 = Tony, 1 = Gilda (le sue battute e le risposte dei duetti).
func _chi(k: String) -> int:
	return 1 if k.begins_with("gilda_") or k.begins_with("duo_") else 0


## Il conduttore `c` entra dal suo lato, se non è già in scena.
func _entra(c: int) -> void:
	var p := _cond[c]
	if p.position.x > -300.0 and p.position.x < 1920.0:
		return
	p.position = Vector2([-500.0, 2000.0][c], 520)
	p.scale = Vector2.ONE * 1.8
	Sfx.play("whoosh")
	create_tween().tween_property(p, "position:x", DENTRO[c], 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _esci(chi: Array[int] = [0, 1]) -> void:
	var tw := create_tween().set_parallel()
	for c in chi:
		_fumetti[c].visible = false
		tw.tween_property(_cond[c], "position:x", FUORI[c], 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished


## Pesca dal mazzo `p` (chiavi "p", "p_<numero>" e le stesse con "gilda_" davanti); rimescola quando è vuoto, senza ripetere subito l'ultima.
func _pesca(p: String) -> String:
	var m: Array = _mazzi.get(p, [])
	if m.is_empty():
		for k: String in _testi:
			var b := k.trim_prefix("gilda_")
			if b == p or (b.begins_with(p + "_") and b.trim_prefix(p + "_").is_valid_int()):
				m.append(k)
		if m.is_empty():
			push_warning("nessuna battuta per '%s'" % p)
			return ""
		m.shuffle()
		if m.size() > 1 and m[-1] == _ultima.get(p, ""):
			m.reverse()
		_mazzi[p] = m
	_ultima[p] = m.pop_back()
	return _ultima[p]


## Il conduttore della battuta `k` la dice; con `pos` (lato di Tony, specchiato per Gilda) entra in scena e,
## coi sottotitoli, il testo appare nel suo fumetto (INF = solo voce). Se esiste `duo_k`, Gilda risponde.
func _dici(k: String, g: String, pos := Vector2.INF) -> void:
	if k == "":
		return
	var c := _chi(k)
	var f := _fumetti[c]
	_nascondi_fumetti()
	if pos != Vector2.INF:
		_entra(c)
	f.visible = _sottotitoli and pos != Vector2.INF
	if f.visible:
		var w := 1380.0 if pos.y > 540.0 else 900.0  # in basso largo: meno righe, copre meno
		var l := f.get_child(0) as Label
		f.custom_minimum_size.x = w
		l.custom_minimum_size.x = w - 88.0
		l.text = _testi.get(k, "")
		f.reset_size()
		f.position = Vector2(pos.x if c == 0 else 1920.0 - pos.x - w, minf(pos.y, 1026.0 - f.size.y))  # mai sotto l'area sicura
		f.pivot_offset = Vector2(0.0 if c == 0 else w, 60)
		f.scale = Vector2.ZERO
		create_tween().tween_property(f, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var stream := load("res://assets/voice/%s.mp3" % k) as AudioStream
	Sfx.duck(true)
	_cond[c].gesto(g, stream.get_length())
	_cond[c].parla(stream)
	_parla = true
	await _cond[c].finito_parlare
	_parla = false
	Sfx.duck(false)
	if _testi.has("duo_" + k):
		await _dici("duo_" + k, "annuncio", pos)
