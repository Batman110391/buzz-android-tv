class_name SchermataScelta
extends Control
## Scelta minigiochi: griglia 4x2 di carte, bottone INIZIA!, cursore pilotato da main (muovi/premi).

signal confermato(ids: Array[String])

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GOLD := Color("FFC83D")
const COLORI: Array[Color] = [Color("3D9BFF"), Color("FF8A1F"), Color("FF3B4E"), Color("A855F7"),
	Color("3DD6A0"), Color("FF3DA8"), Color("FFD23D"), Color("8A6BFF")]
const CARTA := Vector2(400, 330)
const GAP := 28.0
const ORIGINE := Vector2(118, 180)
const MIN_ACCESI := 1  # S 2026-10-15: minimo 3 giochi, Accumula e finale (fissi) compresi

var _giochi: Array = []
var _on: Array[bool] = []
var _corpo: Array[Node2D] = []
var _pan: Array[Panel] = []
var _anelli: Array[Panel] = []
var _spunte: Array[Control] = []
var _cur := 0
var _titolo: Label
var _bottone: Panel
var _anello_b: Panel
var _pill: Label
var _carte: Node2D


func _ready() -> void:
	visible = false
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titolo = Risposta.etichetta("Scegliete i giochi!", Risposta.font_display(), 100, GOLD, 1920, 130)
	_titolo.add_theme_color_override("font_outline_color", INK)
	_titolo.add_theme_constant_override("outline_size", 18)
	_titolo.add_theme_color_override("font_shadow_color", INK)
	_titolo.add_theme_constant_override("shadow_offset_y", 8)
	_titolo.position = Vector2(0, 30)
	add_child(_titolo)
	_carte = Node2D.new()
	add_child(_carte)
	_bottone = Panel.new()
	_bottone.add_theme_stylebox_override("panel", Risposta.box(GOLD, INK, 6, 14, 40))
	_bottone.size = Vector2(460, 110)
	_bottone.position = Vector2(440, 925)
	_bottone.pivot_offset = _bottone.size / 2.0
	add_child(_bottone)
	_bottone.add_child(Risposta.etichetta("INIZIA!", Risposta.font_display(), 72, INK, 460, 96))
	_anello_b = _anello(_bottone.size, 40)
	_bottone.add_child(_anello_b)
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", Risposta.box(INK, CREAM, 5, 5, 36))
	pill.size = Vector2(560, 72)
	pill.position = Vector2(960, 944)
	add_child(pill)
	_pill = Risposta.etichetta("", Risposta.font_testo(), 38, CREAM, 560, 66)
	pill.add_child(_pill)


func _anello(sz: Vector2, raggio: int) -> Panel:
	var a := Panel.new()
	var s := Risposta.box(Color(0, 0, 0, 0), CREAM, 12, 12, raggio + 10)
	s.set_expand_margin_all(10)
	a.add_theme_stylebox_override("panel", s)
	a.size = sz
	a.visible = false
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


func mostra(giochi: Array) -> void:
	for c in _carte.get_children():
		c.queue_free()
	_giochi = giochi
	_on.clear()
	_corpo.clear()
	_pan.clear()
	_anelli.clear()
	_spunte.clear()
	_cur = 0
	var tw := create_tween().set_parallel(true)
	for i in giochi.size():
		var g: Dictionary = giochi[i]
		var fisso: bool = g.get("fisso", false)
		_on.append(true)
		var outer := Node2D.new()
		outer.position = ORIGINE + Vector2(i % 4, i / 4) * (CARTA + Vector2(GAP, GAP)) + CARTA / 2.0
		outer.scale = Vector2.ZERO
		_carte.add_child(outer)
		var corpo := Node2D.new()
		outer.add_child(corpo)
		var ombra := Panel.new()
		ombra.add_theme_stylebox_override("panel", Risposta.box(Color("0A0320"), Color("0A0320"), 6, 6, 32))
		ombra.size = CARTA
		ombra.position = -CARTA / 2.0 + Vector2(0, 12)
		corpo.add_child(ombra)
		var p := Panel.new()
		p.size = CARTA
		p.position = -CARTA / 2.0
		corpo.add_child(p)
		var chiaro: bool = COLORI[i % 8].get_luminance() > 0.55
		var col_t := INK if chiaro else CREAM
		var ic := Risposta.etichetta(g.icona, Risposta.font_testo(), 100, CREAM, CARTA.x, 130)
		ic.position = Vector2(0, 18)
		p.add_child(ic)
		var ti := Risposta.etichetta(g.titolo, Risposta.font_display(), 40, col_t, CARTA.x - 24, 56)
		ti.position = Vector2(12, 150)
		ti.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(ti)
		var re := Risposta.etichetta(g.regola, Risposta.font_testo(), 26, col_t, CARTA.x - 40, 90)
		re.position = Vector2(20, 214)
		re.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(re)
		var badge := Panel.new()
		badge.add_theme_stylebox_override("panel", Risposta.box(INK, CREAM, 4, 4, 28))
		badge.size = Vector2(56, 56)
		badge.position = Vector2(CARTA.x - 68, 12)
		p.add_child(badge)
		badge.add_child(Risposta.etichetta("🔒" if fisso else "✔", Risposta.font_testo(), 30, GOLD, 56, 52))
		var an := _anello(CARTA, 32)
		an.position = -CARTA / 2.0
		corpo.add_child(an)
		_corpo.append(corpo)
		_pan.append(p)
		_anelli.append(an)
		_spunte.append(badge)
		_aspetto(i)
		tw.tween_property(outer, "scale", Vector2.ONE * 1.1, 0.2).set_delay(i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(outer, "scale", Vector2.ONE, 0.15).set_delay(i * 0.08 + 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_aggiorna()
	modulate.a = 1.0
	visible = true


func nascondi() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: visible = false)


func _aspetto(i: int) -> void:
	var acceso := _on[i]
	var fisso: bool = _giochi[i].get("fisso", false)
	_pan[i].add_theme_stylebox_override("panel", Risposta.box(COLORI[i % 8] if acceso else Risposta.DIM_BG, INK, 6, 14, 32))
	_pan[i].modulate = Color.WHITE if acceso else Color(1, 1, 1, 0.55)
	_spunte[i].visible = acceso or fisso
	var col_t := (INK if COLORI[i % 8].get_luminance() > 0.55 else CREAM) if acceso else Risposta.DIM_TEXT
	for k in [1, 2]:
		_pan[i].get_child(k).add_theme_color_override("font_color", col_t)


func _aggiorna() -> void:
	var n := _corpo.size()
	for i in n:
		_anelli[i].visible = _cur == i
		create_tween().tween_property(_corpo[i], "scale", Vector2.ONE * (1.06 if _cur == i else 1.0), 0.1)
	_anello_b.visible = _cur == n
	create_tween().tween_property(_bottone, "scale", Vector2.ONE * (1.08 if _cur == n else 1.0), 0.1)
	var acc := _on.count(true)
	_pill.text = "%d giochi · circa %d min" % [acc, acc * 3]


func muovi(d: Vector2i) -> void:
	var n := _corpo.size()
	if n == 0:
		return
	if _cur == n:
		if d.y < 0:
			_cur = maxi(n - 3, 0)
	else:
		var col := clampi(_cur % 4 + d.x, 0, 3)
		var riga := _cur / 4 + d.y
		if riga > (n - 1) / 4:
			_cur = n
		else:
			_cur = mini(maxi(riga, 0) * 4 + col, n - 1)
	_aggiorna()


func premi() -> void:
	var n := _corpo.size()
	if _cur == n:
		var ids: Array[String] = []
		for i in n:
			if _on[i]:
				ids.append(_giochi[i].id)
		confermato.emit(ids)
		return
	var scelti := 0  # il minimo conta solo i selezionabili (non i fissi)
	for i in n:
		if _on[i] and not _giochi[i].get("fisso", false):
			scelti += 1
	if _giochi[_cur].get("fisso", false) or (_on[_cur] and scelti <= MIN_ACCESI):
		_scossa(_cur)
		return
	_on[_cur] = not _on[_cur]
	_aspetto(_cur)
	_aggiorna()


func _scossa(i: int) -> void:
	var c := _corpo[i]
	var tw := create_tween()
	for dx in [-14, 14, -10, 10, 0]:
		tw.tween_property(c, "position:x", float(dx), 0.05)
