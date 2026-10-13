extends Node2D
## Prova Q4: titolo con Tony che parla -> 3 domande (giocatore 1 da tastiera/telecomando, altri bot) -> rivelazione
## -> Tony entra e commenta -> ricomincia. Stampa "PERF fps=" se esiste user://perf.txt.

const TOT := 15.0
const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GOLD := Color("FFC83D")
const GIOCATORI := [
	["Gastone", "F2384A", "chef"], ["Nonna Pina", "2F7BFF", "nonna"], ["Ugo", "33C759", "zombi"],
	["Brioche", "FFD43B", "gatto"], ["Don Ciccio", "A855F7", "boss"], ["Vanessa", "FF8A1F", "diva"],
]
const DIRS: Array[String] = ["ui_up", "ui_right", "ui_down", "ui_left"]

var _s: SchermataDomanda
var _titolo: Node2D
var _host: Personaggio
var _fumetto: PanelContainer
var _fumetto_l: Label
var _pers: Array[Personaggio] = []
var _testi: Dictionary
var _domande: Array
var _n := 0
var _fase := "titolo"  # titolo | domanda | rivela
var _t := 0.0
var _quando: Array[float] = []
var _scelta: Array[int] = []
var _hurry := false
var _perf := FileAccess.file_exists("user://perf.txt")
var _pt := 0.0
var _pn := 0
var _sottotitoli := true  # accessibilità: fumetto con le battute di Tony; si cambia dal titolo, salvato in user://
var _opz: Panel


func _ready() -> void:
	add_child(Palco.new())
	_s = SchermataDomanda.new()
	add_child(_s)
	var g: Array = []
	for d in GIOCATORI:
		g.append({"nome": d[0], "colore": Color(d[1]), "punti": 0})
	_s.setup_podi(g)
	for i in GIOCATORI.size():
		var p := Personaggio.new()
		p.setup(GIOCATORI[i][2])
		_s.podio(i).metti_personaggio(p)
		_pers.append(p)
	_s.visible = false
	_titolo = _crea_titolo()
	add_child(_titolo)
	_host = Personaggio.new()
	_host.setup("host")
	add_child(_host)
	_crea_fumetto()
	var cfg := ConfigFile.new()
	if cfg.load("user://impostazioni.cfg") == OK:
		_sottotitoli = cfg.get_value("audio", "sottotitoli", true)
	_aggiorna_opzione()
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/voice/lines.json"))
	var re := RegEx.create_from_string(r"\[[^\]]*\]\s*")
	for k: String in lines:
		_testi[k] = re.sub(str(lines[k]), "", true)
	_domande = JSON.parse_string(FileAccess.get_file_as_string("res://game/questions.json"))
	if "--quick" in OS.get_cmdline_user_args():
		_titolo.visible = false
		_host.position.x = -700.0
		_s.visible = true
		_domanda()
	else:
		_mostra_titolo()


# ---------------------------------------------------------------- titolo
func _crea_titolo() -> Node2D:
	var t := Node2D.new()
	var raggiera := Raggiera.new()
	raggiera.position = Vector2(1180, 470)
	t.add_child(raggiera)
	var ls := LabelSettings.new()
	ls.font = Risposta.font_display()
	ls.font_size = 200
	ls.font_color = GOLD
	ls.outline_size = 20
	ls.outline_color = INK
	ls.shadow_color = INK
	ls.shadow_offset = Vector2(0, 16)
	ls.shadow_size = 0
	var logo := Label.new()
	logo.text = "QUIZZONE!"
	logo.label_settings = ls
	logo.size = Vector2(1100, 260)
	logo.position = Vector2(630, 300)
	logo.pivot_offset = logo.size / 2.0
	logo.rotation = deg_to_rad(-5)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child(logo)
	var nastro := _pill("Il quiz più pazzo del salotto", Color("FF3DA8"), 44, Vector2(640, 90))
	nastro.position = Vector2(860, 560)
	nastro.pivot_offset = nastro.size / 2.0
	nastro.rotation = deg_to_rad(-5)
	t.add_child(nastro)
	var cta := _pill("Premi INVIO per giocare", CREAM, 48, Vector2(560, 100))
	cta.position = Vector2(900, 800)
	cta.pivot_offset = cta.size / 2.0
	t.add_child(cta)
	var tw := cta.create_tween().set_loops()
	tw.tween_property(cta, "scale", Vector2.ONE * 1.06, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cta, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	return t


func _pill(testo: String, bg: Color, dim: int, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Risposta.box(bg, INK, 6, 14, int(sz.y / 2.0)))
	p.size = sz
	var l := Risposta.etichetta(testo, Risposta.font_testo(), dim, INK, sz.x, sz.y - 8)
	p.add_child(l)
	return p


class Raggiera extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 440, Color("4B1FA8"))
		for i in 24:
			var a := TAU * i / 24.0
			var pts := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.06) * 440, Vector2.from_angle(a + 0.06) * 440])
			draw_colored_polygon(pts, Color("5A2DBE"))
		draw_arc(Vector2.ZERO, 440, 0, TAU, 96, Color("22E1FF"), 12, true)


func _mostra_titolo() -> void:
	_fase = "titolo"
	_s.visible = false
	_titolo.visible = true
	_titolo.modulate.a = 1.0
	_host.position = Vector2(60, 300)
	_host.scale = Vector2.ONE * 2.5
	await _dici("menu_1", "saluto")
	if _fase != "titolo":
		return
	await get_tree().create_timer(1.0).timeout
	if _fase != "titolo":
		return
	await _dici("filler_1", "annuncio")
	if _fase == "titolo":
		_inizia_partita()


func _inizia_partita() -> void:
	_fase = "transizione"
	_n = 0
	var tw := create_tween().set_parallel()
	tw.tween_property(_titolo, "modulate:a", 0.0, 0.3)
	tw.tween_property(_host, "position:x", -700.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	_titolo.visible = false
	_fumetto.visible = false
	_s.visible = true
	for i in GIOCATORI.size():
		_s.podio(i).set_punti(0)
	_domanda()


# ---------------------------------------------------------------- domanda
func _domanda() -> void:
	_fase = "domanda"
	_t = TOT
	_hurry = false
	_quando.clear()
	_scelta.clear()
	var q: Dictionary = _domande[randi() % _domande.size()]
	for i in GIOCATORI.size():
		_quando.append(randf_range(2.0, 11.0) if i > 0 else 999.0)
		_scelta.append(-1)
		_s.podio(i).set_stato("")
		_pers[i].stato("pensa")
	_s.set_meta("q", q)
	_s.mostra_domanda(_n + 1, 3, "ACCUMULA PUNTI", q["question"], q["answers"])
	_s.set_tempo(TOT, TOT)


func _risponde(pid: int, scelta: int) -> void:
	if _fase != "domanda" or _scelta[pid] != -1:
		return
	if not _scelta.any(func(x: int) -> bool: return x != -1) and randf() < 0.5:
		_dici("firstbuzz_%d" % (randi() % 2 + 1), "sorpresa", false)
	_scelta[pid] = scelta
	_s.risposto(pid, scelta)


func _input(e: InputEvent) -> void:
	if _fase == "titolo" and e.is_action_pressed("ui_accept"):
		_inizia_partita()
		return
	if _fase == "titolo" and (e.is_action_pressed("ui_down") or (e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_S)):
		_sottotitoli = not _sottotitoli
		var cfg := ConfigFile.new()
		cfg.load("user://impostazioni.cfg")
		cfg.set_value("audio", "sottotitoli", _sottotitoli)
		cfg.save("user://impostazioni.cfg")
		_aggiorna_opzione()
		_fumetto.visible = _sottotitoli and _fumetto.visible
		return
	if _fase != "domanda":
		return
	for i in 4:
		if e.is_action_pressed(DIRS[i]) or (e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_1 + i):
			_risponde(0, i)


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
	_t -= dt
	for i in GIOCATORI.size():
		if _scelta[i] == -1 and TOT - _t >= _quando[i]:
			_risponde(i, randi() % 4)
	_s.set_tempo(maxf(_t, 0.0), TOT)
	if _t <= 5.0 and not _hurry and _scelta.has(-1):
		_hurry = true
		_dici("hurry_%d" % (randi() % 2 + 1), "annuncio", false)
	if _t <= 0.0 or not _scelta.has(-1):
		_rivela()


func _rivela() -> void:
	_fase = "rivela"
	var q: Dictionary = _s.get_meta("q")
	var corr: int = q["correct"]
	var scelte := {}
	var punti: Array = []
	var giusti := 0
	for i in GIOCATORI.size():
		if _scelta[i] != -1:
			scelte[i] = _scelta[i]
		punti.append(500)
		if _scelta[i] == corr:
			giusti += 1
	_s.rivela(corr, scelte, punti)
	await get_tree().create_timer(1.8).timeout
	# Tony entra dal basso a sinistra e commenta
	_host.position = Vector2(-500, 520)
	_host.scale = Vector2.ONE * 1.8
	create_tween().tween_property(_host, "position:x", 20.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var k := "someright_%d" % (randi() % 3 + 1)
	var g := "esulta"
	if giusti == GIOCATORI.size():
		k = "allright_%d" % (randi() % 2 + 1)
	elif giusti == 0:
		k = "noneright_%d" % (randi() % 2 + 1)
		g = "delusione"
	await _dici(k, g)
	await get_tree().create_timer(0.6).timeout
	var tw := create_tween()
	tw.tween_property(_host, "position:x", -600.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_fumetto.visible = false
	await tw.finished
	_n += 1
	if _n < 3:
		_domanda()
	else:
		_mostra_titolo()


# ---------------------------------------------------------------- voce + fumetto
func _crea_fumetto() -> void:
	var sb := Risposta.box(CREAM, INK, 6, 16, 44)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 24
	sb.content_margin_bottom = 34
	_fumetto = PanelContainer.new()
	_fumetto.add_theme_stylebox_override("panel", sb)
	_fumetto.custom_minimum_size = Vector2(900, 0)
	_fumetto_l = Label.new()
	_fumetto_l.add_theme_font_override("font", Risposta.font_testo())
	_fumetto_l.add_theme_font_size_override("font_size", 52)
	_fumetto_l.add_theme_color_override("font_color", INK)
	_fumetto_l.add_theme_constant_override("line_spacing", -12)
	_fumetto_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fumetto_l.custom_minimum_size = Vector2(812, 0)
	_fumetto.add_child(_fumetto_l)
	_fumetto.visible = false
	add_child(_fumetto)


func _aggiorna_opzione() -> void:
	if _opz:
		_opz.queue_free()
	_opz = _pill("Sottotitoli: %s  ·  ▼ per cambiare" % ("SÌ" if _sottotitoli else "NO"), GOLD, 36, Vector2(620, 72))
	_opz.position = Vector2(1204, 954)
	_titolo.add_child(_opz)


## Tony dice la battuta `k`; con `fumetto` (e i sottotitoli attivi) il testo appare nel fumetto. Ritorna a fine battuta.
func _dici(k: String, g: String, fumetto := true) -> void:
	_fumetto.visible = fumetto and _sottotitoli
	if _fumetto.visible:
		_fumetto_l.text = _testi.get(k, "")
		_fumetto.reset_size()
		_fumetto.position = Vector2(560, 40) if _fase == "titolo" else Vector2(420, 470)
		_fumetto.pivot_offset = Vector2(0, 60)
		_fumetto.scale = Vector2.ZERO
		create_tween().tween_property(_fumetto, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var stream := load("res://assets/voice/%s.mp3" % k) as AudioStream
	_host.gesto(g, stream.get_length())
	_host.parla(stream)
	await _host.finito_parlare
