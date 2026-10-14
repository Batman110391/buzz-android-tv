extends Node2D
## Flusso della partita (G1): Titolo -> Lobby (←/→ numero di giocatori, OK) -> Round -> 10 domande (Game) -> Finale -> Titolo.
## Giocatore 1 da telecomando/tastiera, gli altri sono bot. `-- --demo`: tutto automatico, anche il giocatore 1.

const DOMANDE := 10
const ROUND := "ACCUMULA PUNTI"
const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GIOCATORI := [
	["Gastone", "F2384A", "chef"], ["Nonna Pina", "2F7BFF", "nonna"], ["Ugo", "33C759", "zombi"],
	["Brioche", "FFD43B", "gatto"], ["Don Ciccio", "A855F7", "boss"], ["Vanessa", "FF8A1F", "diva"],
]
const DIRS: Array[String] = ["ui_up", "ui_right", "ui_down", "ui_left"]
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
var _s: SchermataDomanda
var _finale: SchermataFinale
var _cond: Array[Personaggio] = []  # 0 = Tony (entra da sinistra), 1 = Gilda (entra da destra)
var _fumetti: Array[PanelContainer] = []  # uno per conduttore
var _testi: Dictionary
var _sottotitoli := true  # fumetti con le battute dei conduttori; si cambia dal titolo, salvato in user://
var _domande := Domande.new()
var _game: Game
var _n := 4  # giocatori scelti nella lobby
var _pers: Array[Personaggio] = []
var _q: Dictionary
var _i := 0  # indice della domanda in corso
var _parla := false  # un conduttore sta parlando
var _quando: Array[float] = []
var _scelte := {}  # pid -> risposta
var _hurry := false
# battute di Tony e Gilda: ogni situazione è un mazzo (nessuna frase torna finché non sono uscite tutte) + pause tra i commenti
var _mazzi := {}  # prefisso -> chiavi ancora da pescare
var _ultima := {}  # prefisso -> ultima chiave uscita
var _presentati := {}  # personaggi già presentati da Tony in questa sessione
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
	_s = SchermataDomanda.new()
	_finale = SchermataFinale.new()
	for sc: CanvasItem in [_titolo, _lobby, _round, _s, _finale]:
		sc.visible = false
		add_child(sc)
	_round.position.y = -70.0  # lascia spazio al fumetto di Tony sotto la carta
	_lobby.setup("quizzone.tv", "KR7Q")  # ponytail: codice fisso finché non ci sono i telefoni (G2)
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
	for i in 6:
		_lobby.togli(i)
	for i in _n:
		_lobby.aggiungi(i, GIOCATORI[i][2], GIOCATORI[i][0], Color(GIOCATORI[i][1]))
	_lobby.visible = true
	if _demo:
		await get_tree().create_timer(1.5).timeout
		await _cambia_giocatori(1)
		await get_tree().create_timer(1.0).timeout
		_vai_round()


## ←/→ nella lobby: aggiunge (Tony presenta il nuovo arrivato) o toglie l'ultimo giocatore (minimo 2).
func _cambia_giocatori(d: int) -> void:
	var n := clampi(_n + d, 2, 6)
	if n == _n:
		return
	if d > 0:
		_lobby.aggiungi(_n, GIOCATORI[_n][2], GIOCATORI[_n][0], Color(GIOCATORI[_n][1]))
		Sfx.play("pop")
		var id: String = GIOCATORI[_n][2]
		_n = n
		if not _parla and not _presentati.has(id):  # ognuno si presenta una volta sola
			_presentati[id] = true
			await _commenta(_pesca("pres_" + id), "annuncio", FUMETTO_BASSO)
	else:
		_n = n
		_lobby.togli(_n)


# ---------------------------------------------------------------- round + domande
func _vai_round() -> void:
	_fase = "round"
	_lobby.visible = false
	await _commenta(_pesca("intro"), "saluto", FUMETTO_BASSO, false)
	_round.mostra(1, 1, ROUND, "Rispondi giusto per fare 500 punti. Hai 15 secondi per ogni domanda!", "💰")
	await get_tree().create_timer(0.6).timeout
	await _commenta(["round_1", "gilda_round_1"].pick_random(), "annuncio", FUMETTO_BASSO)
	_round.nascondi()
	_inizia_partita()


func _inizia_partita() -> void:
	var g: Array = []
	var nomi: Array[String] = []
	for i in _n:
		g.append({"nome": GIOCATORI[i][0], "colore": Color(GIOCATORI[i][1]), "punti": 0})
		nomi.append(GIOCATORI[i][0])
	_s.setup_podi(g)
	_pers.clear()
	for i in _n:
		var p := Personaggio.new()
		p.setup(GIOCATORI[i][2])
		_s.podio(i).metti_personaggio(p)
		_pers.append(p)
	_s.visible = true
	Sfx.music("question")
	_game = Game.new()
	_game.question_started.connect(_domanda)
	_game.question_resolved.connect(_rivela)
	_game.game_over.connect(_fine)
	_capo = -1
	_ult_commento = -9
	_ult_buzz = -9
	_ult_hurry = -9
	_game.setup(nomi, _domande.pesca("classica", DOMANDE), DOMANDE)
	_game.start()
	_game.advance()


func _domanda(i: int, tot: int, q: Dictionary) -> void:
	_fase = "domanda"
	_q = q
	_i = i
	_hurry = false
	_scelte.clear()
	_quando.clear()
	for pid in _n:
		_quando.append(randf_range(2.0, 11.0) if pid > 0 or _demo else INF)
		_pers[pid].stato("pensa")
	_s.mostra_domanda(i + 1, tot, ROUND, q["domanda"], q["risposte"])
	_s.set_tempo(Game.QUESTION_TIME, Game.QUESTION_TIME)
	if i == 0:
		_dici(_pesca("qfirst"), "annuncio")
	elif i == tot - 1:
		_dici(_pesca("qlast"), "annuncio")
	elif _ult_commento < i - 1 and randf() < 0.5:  # se dopo l'ultima domanda è stato zitto
		_dici(_pesca("qnext"), "annuncio")


func _risponde(pid: int, scelta: int) -> void:
	if _fase != "domanda" or not _game.submit_answer(pid, scelta):
		return
	if _scelte.is_empty() and _i - _ult_buzz >= 3 and randf() < 0.5 and not _parla:
		_ult_buzz = _i
		_dici(_pesca("firstbuzz"), "sorpresa")
	_scelte[pid] = scelta
	_s.risposto(pid)


func _process(dt: float) -> void:
	if _perf:
		_pt += dt
		_pn += 1
		if _pt >= 2.0:
			print("PERF fps=", snappedf(_pn / _pt, 0.1), " phase=", _fase)
			_pt = 0.0
			_pn = 0
	if _fase != "domanda":
		return
	var trascorso := Game.QUESTION_TIME - _game.time_left()
	for pid in _n:
		if not _scelte.has(pid) and trascorso >= _quando[pid]:
			# bot: indovina poco più di una volta su due
			_risponde(pid, _q["correct"] if randf() < 0.55 else randi() % 4)
	_s.set_tempo(_game.time_left(), Game.QUESTION_TIME)
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
	for pid in _n:
		punti.append(Game.POINTS_CORRECT)
		if risultati[pid]:
			giusti.append(pid)
	_s.rivela(corretta, _scelte, punti)
	Sfx.play("correct" if not giusti.is_empty() else "wrong")
	await get_tree().create_timer(1.8).timeout
	while _parla:  # una battuta (o un duetto) della domanda non è ancora finita
		await get_tree().process_frame
	var capo := _primo(punteggi)
	var nuovo_capo := capo != -1 and capo != _capo and _i > 0
	_capo = capo
	# i conduttori commentano solo se c'è qualcosa da dire, e mai due domande di fila (salvo metà partita)
	var k := ""
	var g := "esulta"
	if _i == DOMANDE / 2 - 1:  # a metà partita punzecchia l'ultimo
		k = _pesca("last_" + GIOCATORI[_ultimo(punteggi)][2])
		g = "delusione"
	elif _i - _ult_commento >= 2:
		if giusti.size() == 1 and _n >= 3:
			k = _pesca("solo_" + GIOCATORI[giusti[0]][2])
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
	_game.advance()  # -> domanda successiva oppure FINAL (game_over)


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
		var d: Array = GIOCATORI[r["id"]]
		c.append({"nome": d[0], "colore": Color(d[1]), "personaggio": d[2], "punti": r["score"]})
	Sfx.music("final")
	Sfx.play("fanfare")
	_finale.mostra(c)
	await get_tree().create_timer(2.5).timeout
	Sfx.play("applause")
	await _commenta(_pesca("final"), "annuncio", FUMETTO_FINALE, false)
	var pari: bool = classifica.size() > 1 and classifica[0]["score"] == classifica[1]["score"]
	await _commenta(_pesca("tie" if pari else "win_" + GIOCATORI[classifica[0]["id"]][2]), "esulta", FUMETTO_FINALE, false)
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
			if ok and not _parla:  # aspetta che Tony finisca la presentazione
				_vai_round()
			elif e.is_action_pressed("ui_right"):
				_cambia_giocatori(1)
			elif e.is_action_pressed("ui_left"):
				_cambia_giocatori(-1)
		"domanda":
			if _demo:
				return
			for i in 4:
				if e.is_action_pressed(DIRS[i]) or _tasto(e, KEY_1 + i):
					_risponde(0, i)
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
