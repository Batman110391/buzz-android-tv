class_name SchermataConto
extends Control
## Finale "Conto alla Rovescia" (1k): barre verticali per giocatore a sinistra, domanda + 4 risposte a destra.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const MAGENTA := Color("FF3DA8")
const GOLD := Color("FFC83D")
const DIM_BG := Color("3A2A6E")
const OMBRA := Color("0A0320")
const BASE_Y := 960.0
const ALTEZZA := 640.0
const LARG := 116.0
const PASSO := 140.0
const X0 := 100.0

var _giocatori: Array = []
var _punti: Array[int] = []
var _bloccato: Array[bool] = []
var _scala := 1.0
var _barre: Control
var _tab: Panel
var _tab_lbl: Label
var _domanda: Label
var _timer: Control
var _frazione := 1.0
var _ultimo_sec := -1
var _carte: Array[Risposta] = []


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barre = Control.new()
	_barre.size = size
	_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barre.draw.connect(_disegna_barre)
	add_child(_barre)
	var ombra := Panel.new()
	ombra.position = Vector2(1016, 126)
	ombra.size = Vector2(852, 230)
	ombra.add_theme_stylebox_override("panel", Risposta.box(OMBRA, OMBRA, 0, 0, 32))
	ombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ombra)
	var pannello := Panel.new()
	pannello.position = Vector2(1016, 112)
	pannello.size = Vector2(852, 230)
	pannello.add_theme_stylebox_override("panel", Risposta.box(INK, MAGENTA, 8, 8, 32))
	pannello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pannello)
	_domanda = Risposta.etichetta("", Risposta.font_testo(), 52, CREAM, 852 - 80, 230 - 48)
	_domanda.position = Vector2(40, 20)
	_domanda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_domanda.add_theme_constant_override("line_spacing", -12)
	pannello.add_child(_domanda)
	_tab = Panel.new()
	_tab.position = Vector2(1060, 78)
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.add_theme_stylebox_override("panel", Risposta.box(MAGENTA, INK, 6, 6, 30))
	add_child(_tab)
	_tab_lbl = Risposta.etichetta("", Risposta.font_display(), 32, INK, 100, 56)
	_tab.add_child(_tab_lbl)
	_timer = Control.new()
	_timer.position = Vector2(60, 40)
	_timer.size = Vector2(160, 160)
	_timer.pivot_offset = Vector2(80, 80)
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer.draw.connect(_disegna_timer)
	add_child(_timer)
	for i in 4:
		var r := Risposta.new()
		r.position = Vector2(1016, 370 + i * 164)
		add_child(r)
		r.setup("ABCD"[i], "")
		_carte.append(r)


func setup(giocatori: Array) -> void:
	_giocatori = giocatori
	_punti.clear()
	_bloccato.clear()
	var m := 1
	for g in giocatori:
		_punti.append(g["punti"])
		_bloccato.append(false)
		m = maxi(m, g["punti"])
	_scala = ALTEZZA / m
	_barre.queue_redraw()


func mostra_domanda(n: int, tot: int, testo: String, risposte: Array) -> void:
	_tab_lbl.text = "DOMANDA %d/%d · CONTO ALLA ROVESCIA" % [n, tot]
	var w := Risposta.font_display().get_string_size(_tab_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x + 56.0 + 12.0
	_tab.size = Vector2(w, 60)
	_tab_lbl.size.x = w - 12.0
	_domanda.text = testo
	for i in 4:
		_carte[i].reset()
		_carte[i]._testo.text = risposte[i]
		_carte[i]._layout_testo()
		_carte[i].entra(0.2 + 0.08 * i)
	for i in _bloccato.size():
		_bloccato[i] = false
	_barre.queue_redraw()


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


func set_punti(pid: int, punti: int) -> void:
	_punti[pid] = maxi(punti, 0)
	_scala = minf(_scala, ALTEZZA / maxf(punti, 1.0))  # con il +300 si può superare il massimo iniziale
	_barre.queue_redraw()


func risposto(pid: int) -> void:
	_bloccato[pid] = true
	_barre.queue_redraw()


## scelte: {pid: indice}; punti_finali: punti per pid dopo la rivelazione.
func rivela(corretta: int, scelte: Dictionary, punti_finali: Array) -> void:
	set_tempo(0.0, 1.0)
	for i in 4:
		var g: Array = []
		for pid in _giocatori.size():
			if scelte.get(pid, -1) == i:
				g.append({"colore": _giocatori[pid]["colore"], "num": pid + 1})
		_carte[i].set_gettoni(g)
		_carte[i].set_stato("giusta" if i == corretta else "sbagliata")
	for pid in _giocatori.size():
		_bloccato[pid] = scelte.get(pid, -1) == corretta
		var da := _punti[pid]
		create_tween().tween_method(func(v: float) -> void: set_punti(pid, roundi(v)), float(da), float(punti_finali[pid]), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _disegna_timer() -> void:
	var c := Vector2(80, 80)
	_timer.draw_circle(c, 80, INK)
	_timer.draw_circle(c, 72, DIM_BG)
	if _frazione > 0.0:
		_timer.draw_arc(c, 64, -PI / 2, -PI / 2 + TAU * _frazione, 96, GOLD, 16.0, true)
	_timer.draw_circle(c, 56, INK)
	_timer.draw_string(Risposta.font_display(), Vector2(0, 102), str(maxi(_ultimo_sec, 0)), HORIZONTAL_ALIGNMENT_CENTER, 160, 64, CREAM)


func _disegna_barre() -> void:
	var fd := Risposta.font_display()
	_barre.draw_rect(Rect2(X0 - 20, BASE_Y, PASSO * 6 - 24 + 40, 10), INK)
	for i in _giocatori.size():
		var col: Color = _giocatori[i]["colore"]
		var x := X0 + i * PASSO
		var h := _punti[i] * _scala
		var cx := x + LARG / 2.0
		if h > 0.0:
			var r := Rect2(x, BASE_Y - maxf(h, 12.0), LARG, maxf(h, 12.0))
			_barre.draw_style_box(Risposta.box(col, GOLD if _bloccato[i] else INK, 6, 6, 18), r)
			if _bloccato[i] and h > 60.0:  # lucchetto
				var ly := r.position.y + 24.0
				_barre.draw_arc(Vector2(cx, ly + 4), 14, PI, TAU, 16, INK, 6.0)
				_barre.draw_rect(Rect2(cx - 20, ly + 4, 40, 32), INK)
		_barre.draw_string(fd, Vector2(x - 12, BASE_Y - maxf(h, 12.0) - 14), str(_punti[i]), HORIZONTAL_ALIGNMENT_CENTER, LARG + 24, 40, CREAM)
		_barre.draw_circle(Vector2(cx, BASE_Y + 40), 24, col)
		_barre.draw_string(fd, Vector2(cx - 24, BASE_Y + 52), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 48, 32, INK)
		_barre.draw_string(fd, Vector2(x - 12, BASE_Y + 92), _giocatori[i]["nome"], HORIZONTAL_ALIGNMENT_CENTER, LARG + 24, 26, CREAM)
