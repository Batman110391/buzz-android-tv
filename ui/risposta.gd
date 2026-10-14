class_name Risposta
extends Control
## Carta risposta 852x134. Stati: normale / giusta / sbagliata. Contiene anche i font e gli helper condivisi dell'UI.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const DIM_BG := Color("3A2A6E")
const DIM_TEXT := Color("B8ACE0")
const DIM_BADGE := Color("5B4A93")

static var _fd: Font
static var _ft: Font


static func font_display() -> Font:
	if _fd == null:
		var f: FontFile = load("res://assets/fonts/LilitaOne-Regular.ttf")
		f.multichannel_signed_distance_field = true
		_fd = f
	return _fd


static func font_testo() -> Font:
	if _ft == null:
		var f: FontFile = load("res://assets/fonts/Baloo2.ttf")  # senza MSDF: i contorni sovrapposti del variabile creano macchie
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): 800}
		_ft = v
	return _ft


static func etichetta(testo: String, font: Font, dim: int, col: Color, w: float, h: float, allinea := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = testo
	l.size = Vector2(w, h)
	l.horizontal_alignment = allinea
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", col)
	return l


static func box(bg: Color, bordo: Color, b: int, b_basso: int, raggio: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(b)
	s.border_width_bottom = b_basso
	s.set_corner_radius_all(raggio)
	return s


var lettera := "A"
var _sb: StyleBoxFlat
var _forma: Control
var _testo: Label
var _gettoni: Array[Control] = []
var _anello: Panel
var _timbro: Panel
var _col_bf := INK
var _col_lf := CREAM


func _init() -> void:
	size = Vector2(852, 134)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(l: String, testo: String) -> void:
	lettera = l
	_sb = box(CREAM, INK, 6, 16, 28)
	var card := Panel.new()
	card.size = size
	card.add_theme_stylebox_override("panel", _sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	_forma = Control.new()
	_forma.position = Vector2(22, 16)
	_forma.size = Vector2(92, 92)
	_forma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forma.draw.connect(_disegna_forma)
	add_child(_forma)
	_testo = etichetta(testo, font_testo(), 48, INK, 700, 112, HORIZONTAL_ALIGNMENT_LEFT)
	_testo.position = Vector2(136, 6)
	_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_testo.add_theme_constant_override("line_spacing", -8)
	add_child(_testo)
	_anello = Panel.new()
	var sa := StyleBoxFlat.new()
	sa.draw_center = false
	sa.border_color = Color.WHITE
	sa.set_border_width_all(6)
	sa.set_corner_radius_all(44)
	_anello.add_theme_stylebox_override("panel", sa)
	_anello.position = Vector2(-12, -12)
	_anello.size = Vector2(876, 148)
	_anello.visible = false
	_anello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_anello)
	_timbro = Panel.new()
	_timbro.add_theme_stylebox_override("panel", box(INK, Color.WHITE, 6, 6, 42))
	_timbro.size = Vector2(84, 84)
	_timbro.position = Vector2(788, -28)
	_timbro.pivot_offset = Vector2(42, 42)
	_timbro.rotation_degrees = -8
	_timbro.visible = false
	_timbro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spunta := Line2D.new()
	spunta.points = PackedVector2Array([Vector2(9.2, 24.2), Vector2(19.6, 34.5), Vector2(38, 11.5)])
	spunta.position = Vector2(19, 19)
	spunta.width = 8
	spunta.default_color = CREAM
	spunta.begin_cap_mode = Line2D.LINE_CAP_ROUND
	spunta.end_cap_mode = Line2D.LINE_CAP_ROUND
	spunta.joint_mode = Line2D.LINE_JOINT_ROUND
	_timbro.add_child(spunta)
	add_child(_timbro)
	_layout_testo()


func _disegna_forma() -> void:
	var s := 0.92
	var c := _col_bf
	var base := 66.0
	var dim := 44
	match lettera:
		"A":
			_forma.draw_colored_polygon(PackedVector2Array([Vector2(50, 3) * s, Vector2(97, 50) * s, Vector2(50, 97) * s, Vector2(3, 50) * s]), c)
		"B":
			_forma.draw_circle(Vector2(50, 50) * s, 46 * s, c)
		"C":
			_forma.draw_colored_polygon(PackedVector2Array([Vector2(50, 4) * s, Vector2(98, 94) * s, Vector2(2, 94) * s]), c)
			base = 84.0
			dim = 40
		"D":
			_forma.draw_style_box(box(c, c, 0, 0, int(12 * s)), Rect2(Vector2(7, 7) * s, Vector2(86, 86) * s))
	_forma.draw_string(font_display(), Vector2(0, base * s), lettera, HORIZONTAL_ALIGNMENT_CENTER, 92, int(dim * s), _col_lf)


func _layout_testo() -> void:
	var w := 852.0 - 136.0 - 28.0
	if not _gettoni.is_empty():
		w -= _gettoni.size() * 68.0 - 8.0 + 22.0
	_testo.size.x = w
	# rimpicciolisce finché il testo sta nell'etichetta (i gettoni gli tolgono spazio)
	var f := font_testo()
	var max_h := _testo.size.y
	var dim := 48
	while dim > 26:
		var righe := roundi(f.get_multiline_string_size(_testo.text, HORIZONTAL_ALIGNMENT_LEFT, w, dim).y / f.get_height(dim))
		if righe * f.get_height(dim) - 8.0 * (righe - 1) <= max_h:
			break
		dim -= 2
	_testo.add_theme_font_size_override("font_size", dim)
	var x := 852.0 - 28.0
	for i in range(_gettoni.size() - 1, -1, -1):
		x -= 60.0
		_gettoni[i].position = Vector2(x, 32)
		x -= 8.0


func _crea_gettone(colore: Color, num: int) -> Control:
	var g := Panel.new()
	g.size = Vector2(60, 60)
	g.pivot_offset = Vector2(30, 30)
	g.add_theme_stylebox_override("panel", box(colore, INK, 5, 5, 30))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(etichetta(str(num), font_display(), 34, INK, 60, 56))
	return g


func set_gettoni(lista: Array) -> void:
	for g in _gettoni:
		g.queue_free()
	_gettoni.clear()
	for d in lista:
		var g := _crea_gettone(d["colore"], d["num"])
		add_child(g)
		_gettoni.append(g)
	_layout_testo()


## Entrata: scale 0 -> 1 (con rimbalzo) dopo `ritardo`.
func entra(ritardo: float) -> void:
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(ritardo)
	t.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func reset() -> void:
	set_stato("normale", false)
	set_gettoni([])


func set_stato(s: String, anima := true) -> void:
	_anello.visible = s == "giusta"
	_timbro.visible = s == "giusta"
	if s == "giusta":
		_applica(Color.WHITE, INK, INK, CREAM)
		scale = Vector2(1.03, 1.03)
		if anima:
			scale = Vector2(1.08, 1.08)
			create_tween().tween_property(self, "scale", Vector2(1.03, 1.03), 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	elif s == "sbagliata":
		if anima:
			var t := create_tween().set_parallel()
			t.tween_method(_mescola, 0.0, 1.0, 0.2)
			t.tween_property(self, "scale", Vector2(0.97, 0.97), 0.2)
		else:
			_mescola(1.0)
			scale = Vector2(0.97, 0.97)
	else:
		_mescola(0.0)
		scale = Vector2.ONE


func _mescola(k: float) -> void:
	_applica(CREAM.lerp(DIM_BG, k), INK.lerp(DIM_TEXT, k), INK.lerp(DIM_BADGE, k), CREAM.lerp(DIM_TEXT, k))


func _applica(bg: Color, fg: Color, bf: Color, lf: Color) -> void:
	_sb.bg_color = bg
	_testo.add_theme_color_override("font_color", fg)
	_col_bf = bf
	_col_lf = lf
	_forma.queue_redraw()
