class_name SchermataDomanda
extends Control
## Schermata domanda (layout standard del design, 1920x1080): linguetta, pannello, timer, 4 risposte, podi.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const MAGENTA := Color("FF3DA8")
const GOLD := Color("FFC83D")
const DIM_BG := Color("3A2A6E")
const OMBRA := Color("0A0320")

var _tab: Panel
var _tab_lbl: Label
var _domanda: Label
var _timer: Control
var _frazione := 1.0
var _numero := 0
var _ultimo_sec := -1
var _carte: Array[Risposta] = []
var _podi: Array[Podio] = []


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# pannello domanda con ombra dura (pannello duplicato sfalsato)
	var ombra := Panel.new()
	ombra.position = Vector2(96, 102)
	ombra.size = Vector2(1540, 214)
	ombra.add_theme_stylebox_override("panel", Risposta.box(OMBRA, OMBRA, 0, 0, 32))
	ombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ombra)
	var pannello := Panel.new()
	pannello.position = Vector2(96, 88)
	pannello.size = Vector2(1540, 214)
	pannello.add_theme_stylebox_override("panel", Risposta.box(INK, MAGENTA, 8, 8, 32))
	pannello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pannello)
	_domanda = Risposta.etichetta("", Risposta.font_testo(), 60, CREAM, 1540 - 112, 214 - 48)
	_domanda.position = Vector2(56, 28)
	_domanda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_domanda.add_theme_constant_override("line_spacing", -16)
	pannello.add_child(_domanda)
	# linguetta
	_tab = Panel.new()
	_tab.position = Vector2(140, 54)
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.add_theme_stylebox_override("panel", Risposta.box(MAGENTA, INK, 6, 6, 30))
	add_child(_tab)
	_tab_lbl = Risposta.etichetta("", Risposta.font_display(), 32, INK, 100, 56)
	_tab.add_child(_tab_lbl)
	# timer
	_timer = Control.new()
	_timer.position = Vector2(1664, 88)
	_timer.size = Vector2(160, 160)
	_timer.pivot_offset = Vector2(80, 80)
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer.draw.connect(_disegna_timer)
	add_child(_timer)
	# risposte 2x2
	for i in 4:
		var r := Risposta.new()
		r.position = Vector2(96 + (i % 2) * 876, 336 + (i / 2) * 158)
		add_child(r)
		r.setup("ABCD"[i], "")
		_carte.append(r)


## giocatori: [{nome, colore: Color, punti}] -> podi in riga (space-between).
func setup_podi(giocatori: Array) -> void:
	for p in _podi:
		p.queue_free()
	_podi.clear()
	var n := giocatori.size()
	for i in n:
		var p := Podio.new()
		p.position = Vector2(96.0 + i * (1728.0 - 240.0) / maxf(n - 1, 1), 650)
		add_child(p)
		p.setup(giocatori[i]["nome"], giocatori[i]["colore"], i + 1, giocatori[i]["punti"])
		_podi.append(p)


func podio(i: int) -> Podio:
	return _podi[i]


func mostra_domanda(n: int, tot: int, titolo_round: String, testo: String, risposte: Array) -> void:
	_numero = n
	_tab_lbl.text = "DOMANDA %d/%d · %s" % [n, tot, titolo_round]
	var w := Risposta.font_display().get_string_size(_tab_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x + 56.0 + 12.0
	_tab.size = Vector2(w, 60)
	_tab_lbl.size.x = w - 12.0
	_tab_lbl.position = Vector2(0, 0)
	_domanda.text = testo
	for i in 4:
		_carte[i].reset()
		_carte[i]._testo.text = risposte[i]
		_carte[i]._layout_testo()
		_carte[i].entra(0.2 + 0.08 * i)
	for p in _podi:
		p.set_stato("")
		p.badge("")


func set_tempo(left: float, total: float) -> void:
	_frazione = clampf(left / total, 0.0, 1.0)
	var sec := ceili(left)
	if sec != _ultimo_sec:
		_ultimo_sec = sec
		if left > 0.0 and sec <= 5:
			var t := create_tween()
			t.tween_property(_timer, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(_timer, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_timer.queue_redraw()


func _disegna_timer() -> void:
	var c := Vector2(80, 80)
	_timer.draw_circle(c, 80, INK)
	_timer.draw_circle(c, 72, DIM_BG)
	if _frazione > 0.0:
		_timer.draw_arc(c, 64, -PI / 2, -PI / 2 + TAU * _frazione, 96, GOLD, 16.0, true)
	_timer.draw_circle(c, 56, INK)
	_timer.draw_string(Risposta.font_display(), Vector2(0, 80 + 22), str(maxi(_ultimo_sec, 0)), HORIZONTAL_ALIGNMENT_CENTER, 160, 64, CREAM)


## Si accende solo il podio: quale risposta ha dato si vede alla rivelazione (niente copiature).
func risposto(pid: int) -> void:
	_podi[pid].set_stato("risposto")


## scelte: {pid: indice risposta}; punti: punti guadagnati per pid.
func rivela(corretta: int, scelte: Dictionary, punti: Array) -> void:
	set_tempo(0.0, 1.0)
	for i in 4:
		var g: Array = []
		for pid in _podi.size():
			if scelte.get(pid, -1) == i:
				g.append({"colore": _podi[pid].colore, "num": pid + 1})
		_carte[i].set_gettoni(g)
		_carte[i].set_stato("giusta" if i == corretta else "sbagliata")
	for pid in _podi.size():
		if scelte.get(pid, -1) == corretta:
			_podi[pid].set_stato("ok")
			_podi[pid].badge("+%d" % punti[pid])
			_podi[pid].set_punti(_podi[pid].punti + punti[pid])
		else:
			_podi[pid].set_stato("ko")
