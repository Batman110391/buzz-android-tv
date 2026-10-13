class_name SchermataFinale
extends Node2D

const GOLD := Color("FFC83D")
const BLOCCHI := [
	{"x": 960, "h": 440, "c": "FFC83D"},
	{"x": 670, "h": 330, "c": "D9D4EC"},
	{"x": 1250, "h": 250, "c": "C98A4B"},
]
const BASE := 1000.0
const SC := 1.3  # scala personaggi sul podio

var _titolo: Label
var _cont: Node2D
var _coriandoli: CPUParticles2D


func _ready() -> void:
	visible = false
	_titolo = Risposta.etichetta("CLASSIFICA FINALE!", Risposta.font_display(), 120, GOLD, 1200, 150)
	_titolo.add_theme_color_override("font_outline_color", Risposta.INK)
	_titolo.add_theme_constant_override("outline_size", 14)
	_titolo.position = Vector2(360, 40)
	add_child(_titolo)
	_cont = Node2D.new()
	add_child(_cont)
	_coriandoli = CPUParticles2D.new()
	_coriandoli.amount = 120
	_coriandoli.lifetime = 5.0
	_coriandoli.preprocess = 5.0
	_coriandoli.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_coriandoli.emission_rect_extents = Vector2(960, 10)
	_coriandoli.position = Vector2(960, -20)
	_coriandoli.direction = Vector2.DOWN
	_coriandoli.spread = 15.0
	_coriandoli.gravity = Vector2(0, 120)
	_coriandoli.initial_velocity_min = 80.0
	_coriandoli.initial_velocity_max = 180.0
	_coriandoli.angular_velocity_min = -240.0
	_coriandoli.angular_velocity_max = 240.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([Color("FF3DA8"), Color("22E1FF"), GOLD, Color("A855F7"), Color("3DDC84")])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	_coriandoli.color_initial_ramp = g
	var im := Image.create(20, 12, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	_coriandoli.texture = ImageTexture.create_from_image(im)
	add_child(_coriandoli)
	_coriandoli.emitting = false


func mostra(classifica: Array) -> void:
	for c in _cont.get_children():
		c.queue_free()
	var k := 0
	for i: int in [2, 1, 0]:  # sale prima il 3°
		if i >= classifica.size():
			continue
		_blocco(classifica[i], i, 0.3 + 0.6 * k)
		k += 1
	for i in range(3, classifica.size()):
		_riga(classifica[i], i, 2.0 + 0.2 * (i - 3))
	_coriandoli.restart()
	_coriandoli.emitting = true
	visible = true


func nascondi() -> void:
	_coriandoli.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0)


func _blocco(d: Dictionary, i: int, ritardo: float) -> void:
	var b: Dictionary = BLOCCHI[i]
	var h: float = b["h"]
	var col: Color = d["colore"]
	var n := Node2D.new()
	n.position = Vector2(b["x"], BASE + h + 40.0)  # parte sotto lo schermo
	_cont.add_child(n)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Risposta.box(Color(b["c"]), Risposta.INK, 8, 8, 14))
	p.size = Vector2(280, h)
	p.position = Vector2(-140, -h)
	n.add_child(p)
	p.add_child(_et(str(i + 1), Risposta.font_display(), 120, Risposta.INK, 280, 130, 0))
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", Risposta.box(col, Risposta.INK, 5, 5, 20))
	pill.size = Vector2(250, 48)
	pill.position = Vector2(15, 140)
	p.add_child(pill)
	pill.add_child(_et(d["nome"], Risposta.font_testo(), 32, Risposta.INK, 250, 44, 0))
	p.add_child(_et(str(d["punti"]), Risposta.font_display(), 40, Risposta.INK, 280, 50, 195))
	var pe := Personaggio.new()
	pe.setup(d["personaggio"])
	pe.scale = Vector2.ONE * SC
	pe.position = Vector2(-100 * SC, -h - 170 * SC)
	n.add_child(pe)
	pe.stato("esulta" if i == 0 else "attesa")
	var tw := create_tween()
	tw.tween_interval(ritardo)
	tw.tween_property(n, "position:y", BASE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _riga(d: Dictionary, i: int, ritardo: float) -> void:
	var r := Panel.new()
	r.add_theme_stylebox_override("panel", Risposta.box(Risposta.CREAM, Risposta.INK, 5, 5, 20))
	r.size = Vector2(460, 100)
	r.position = Vector2(1364, 230 + 120 * (i - 3))
	r.modulate.a = 0.0
	_cont.add_child(r)
	var pe := Personaggio.new()
	pe.setup(d["personaggio"])
	pe.scale = Vector2.ONE * 0.4
	pe.position = Vector2(8, 10)
	r.add_child(pe)
	r.add_child(_et("%d. %s" % [i + 1, d["nome"]], Risposta.font_testo(), 32, Risposta.INK, 230, 100, 0, HORIZONTAL_ALIGNMENT_LEFT, 96))
	r.add_child(_et(str(d["punti"]), Risposta.font_display(), 36, Risposta.INK, 100, 100, 0, HORIZONTAL_ALIGNMENT_RIGHT, 336))
	var tw := create_tween()
	tw.tween_interval(ritardo)
	tw.tween_property(r, "modulate:a", 1.0, 0.3)


func _et(t: String, f: Font, dim: int, c: Color, w: float, h: float, y: float, al := HORIZONTAL_ALIGNMENT_CENTER, x := 0.0) -> Label:
	var l := Risposta.etichetta(t, f, dim, c, w, h, al)
	l.position = Vector2(x, y)
	return l
