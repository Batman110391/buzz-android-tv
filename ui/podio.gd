class_name Podio
extends Control
## Podio 240x376: personaggio (slot), lid, fronte con nome e punti, numero, icona di stato, badge.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const DIM_BG := Color("3A2A6E")
const STATO_PERSONAGGIO := {"": "attesa", "ok": "esulta", "ko": "sconfitta", "risposto": "risposto", "bomba": "sorpreso", "mira": "sorpreso"}

var colore := Color.WHITE
var punti := 0
var _stato := ""
var _cont: Control
var _slot: Node2D
var _personaggio: Node2D
var _punti_box: Panel
var _punti_lbl: Label
var _icona: Control
var _icona_stato := ""
var _badge: Panel
var _tween_hop: Tween


func _init() -> void:
	size = Vector2(240, 376)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(nome: String, col: Color, numero: int, p: int) -> void:
	colore = col
	punti = p
	_cont = Control.new()
	_cont.size = size
	_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cont)
	_slot = Node2D.new()
	_slot.position = Vector2(6, 0)
	_cont.add_child(_slot)
	# fronte
	var fronte := Panel.new()
	fronte.position = Vector2(14, 232)
	fronte.size = Vector2(212, 144)
	var sf := Risposta.box(col, INK, 6, 14, 0)
	sf.corner_radius_bottom_left = 22
	sf.corner_radius_bottom_right = 22
	fronte.add_theme_stylebox_override("panel", sf)
	fronte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cont.add_child(fronte)
	var n := Risposta.etichetta(nome, Risposta.font_testo(), 32, INK, 212, 40)
	n.position = Vector2(14, 242)
	_cont.add_child(n)
	_punti_box = Panel.new()
	_punti_box.add_theme_stylebox_override("panel", Risposta.box(INK, INK, 0, 0, 14))
	_punti_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cont.add_child(_punti_box)
	_punti_lbl = Risposta.etichetta("", Risposta.font_display(), 46, CREAM, 150, 60)
	_punti_box.add_child(_punti_lbl)
	_aggiorna_punti(p)
	# coperchio (colore + 40% bianco, opaco)
	var lid := Panel.new()
	lid.position = Vector2(4, 204)
	lid.size = Vector2(232, 40)
	lid.add_theme_stylebox_override("panel", Risposta.box(col.lerp(Color.WHITE, 0.4), INK, 6, 6, 20))
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cont.add_child(lid)
	# numero
	var num := Panel.new()
	num.position = Vector2(-6, 322)
	num.size = Vector2(52, 52)
	num.add_theme_stylebox_override("panel", Risposta.box(INK, col, 4, 4, 26))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.add_child(Risposta.etichetta(str(numero), Risposta.font_display(), 32, col, 52, 50))
	_cont.add_child(num)
	# icona di stato / badge
	_icona = Control.new()
	_icona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icona.draw.connect(_disegna_icona)
	_icona.visible = false
	_cont.add_child(_icona)
	_badge = Panel.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	_cont.add_child(_badge)


func _aggiorna_punti(p: int) -> void:
	var s := str(p)
	if p >= 1000:
		s = "%d.%03d" % [p / 1000, p % 1000]
	_punti_lbl.text = s
	var w := maxf(150.0, Risposta.font_display().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x + 28.0)
	_punti_box.size = Vector2(w, 60)
	_punti_box.position = Vector2(120.0 - w / 2.0, 291)
	_punti_lbl.size.x = w


func metti_personaggio(p: Node2D) -> void:
	if _personaggio != null:
		_personaggio.queue_free()
	_personaggio = p
	p.scale = Vector2(1.14, 1.14)  # tela 200 -> slot 228
	_slot.add_child(p)
	set_stato(_stato)


func set_stato(s: String) -> void:
	_stato = s
	if _personaggio != null and _personaggio.has_method("stato"):
		_personaggio.stato(STATO_PERSONAGGIO.get(s, "attesa"))
	_icona_stato = s
	_icona.visible = s != ""
	if s == "bomba":
		_icona.position = Vector2(140, 10)
		_icona.size = Vector2(130, 130)
	elif s == "mira":
		_icona.position = Vector2(44, 30)
		_icona.size = Vector2(150, 150)
	else:
		_icona.position = Vector2(162, 36)
		_icona.size = Vector2(84, 84)
	_icona.queue_redraw()
	if s == "risposto":
		_icona.pivot_offset = _icona.size / 2.0
		_icona.scale = Vector2.ZERO
		create_tween().tween_property(_icona, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _tween_hop:
			_tween_hop.kill()
		_tween_hop = create_tween()
		_tween_hop.tween_property(_cont, "position:y", -24.0, 0.125).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween_hop.tween_property(_cont, "position:y", 0.0, 0.125).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		_icona.scale = Vector2.ONE


func badge(testo: String, scuro := false) -> void:
	_badge.visible = testo != ""
	if testo == "":
		return
	var f := Risposta.font_display()
	var w := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 40.0 + 12.0
	_badge.size = Vector2(w, 40 * 1.1 + 8 + 12)
	_badge.pivot_offset = _badge.size / 2.0
	_badge.rotation_degrees = -4
	_badge.position = Vector2(120.0 - w / 2.0, -14)
	_badge.add_theme_stylebox_override("panel", Risposta.box(DIM_BG if scuro else CREAM, INK, 6, 6, 30))
	for c in _badge.get_children():
		c.queue_free()
	_badge.add_child(Risposta.etichetta(testo, f, 40, CREAM if scuro else INK, w, _badge.size.y - 2))
	# il +500 sale di 40 px
	_badge.position.y += 40
	create_tween().tween_property(_badge, "position:y", -14.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Conta fino a `n` in 0,8 s.
func set_punti(n: int) -> void:
	var da := punti
	punti = n
	create_tween().tween_method(func(v: float) -> void: _aggiorna_punti(int(round(v))), float(da), float(n), 0.8)


func _disegna_icona() -> void:
	match _icona_stato:
		"ok":
			_disco(CREAM, INK)
			_icona.draw_polyline(PackedVector2Array([Vector2(28.2, 43.2), Vector2(38.6, 53.5), Vector2(57, 30.5)]), INK, 8.0, true)
		"ko":
			_disco(DIM_BG, INK)
			_icona.draw_line(Vector2(27, 27), Vector2(57, 57), CREAM, 7.0, true)
			_icona.draw_line(Vector2(57, 27), Vector2(27, 57), CREAM, 7.0, true)
		"risposto":
			_disco(INK, colore)
			_icona.draw_style_box(Risposta.box(CREAM, CREAM, 0, 0, 4), Rect2(Vector2(30, 40), Vector2(24, 17)))
			var pts := PackedVector2Array([Vector2(35, 40), Vector2(35, 35)])
			for k in range(0, 9):
				var a := PI + PI * k / 8.0
				pts.append(Vector2(42 + cos(a) * 7.0, 35 + sin(a) * 7.0))
			pts.append(Vector2(49, 40))
			_icona.draw_polyline(pts, CREAM, 5.0, true)
		"bomba":
			_icona.draw_circle(Vector2(56, 70), 40, CREAM)
			_icona.draw_circle(Vector2(56, 70), 34, INK)
			_icona.draw_polyline(PackedVector2Array([Vector2(80, 22), Vector2(90, 6), Vector2(104, 14)]), Color("C9A36A"), 6.0, true)
			_icona.draw_colored_polygon(PackedVector2Array([Vector2(106, 0), Vector2(110, 10), Vector2(120, 12), Vector2(112, 18), Vector2(114, 28), Vector2(106, 22), Vector2(98, 28), Vector2(100, 18), Vector2(92, 12), Vector2(102, 10)]), Color("FFC83D"))
		"mira":
			_icona.draw_arc(Vector2(75, 75), 60, 0, TAU, 48, INK, 12.0, true)
			_icona.draw_arc(Vector2(75, 75), 60, 0, TAU, 48, CREAM, 5.0, true)
			for d in [[Vector2(75, 3), Vector2(75, 39)], [Vector2(75, 111), Vector2(75, 147)], [Vector2(3, 75), Vector2(39, 75)], [Vector2(111, 75), Vector2(147, 75)]]:
				_icona.draw_line(d[0], d[1], INK, 16.0)
				_icona.draw_line(d[0], d[1], CREAM, 6.0)


func _disco(bg: Color, bordo: Color) -> void:
	_icona.draw_circle(Vector2(42, 42), 42, bordo)
	_icona.draw_circle(Vector2(42, 42), 36, bg)
