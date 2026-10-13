class_name SchermataTitolo extends Node2D
## Schermata Titolo (design 1a). Il Palco e il presentatore li mette main; qui niente input.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GOLD := Color("FFC83D")

var _logo: Label
var _opz: Panel
var _sottotitoli := true
var _tw: Tween


class Raggiera extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 440, Color("4B1FA8"))
		for i in 24:
			var a := TAU * i / 24.0
			var pts := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.06) * 440, Vector2.from_angle(a + 0.06) * 440])
			draw_colored_polygon(pts, Color("5A2DBE"))
		draw_arc(Vector2.ZERO, 440, 0, TAU, 96, Color("22E1FF"), 12, true)


func _ready() -> void:
	var raggiera := Raggiera.new()
	raggiera.position = Vector2(1180, 470)
	add_child(raggiera)
	var ls := LabelSettings.new()
	ls.font = Risposta.font_display()
	ls.font_size = 200
	ls.font_color = GOLD
	ls.outline_size = 20
	ls.outline_color = INK
	ls.shadow_color = INK
	ls.shadow_offset = Vector2(0, 16)
	ls.shadow_size = 0
	_logo = Label.new()
	_logo.text = "QUIZZONE!"
	_logo.label_settings = ls
	_logo.size = Vector2(1100, 260)
	_logo.position = Vector2(630, 300)
	_logo.pivot_offset = _logo.size / 2.0
	_logo.rotation = deg_to_rad(-5)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_logo)
	var nastro := _pill("Il quiz più pazzo del salotto", Color("FF3DA8"), 44, Vector2(640, 90))
	nastro.position = Vector2(860, 560)
	nastro.pivot_offset = nastro.size / 2.0
	nastro.rotation = deg_to_rad(-5)
	add_child(nastro)
	var cta := _pill("Premi INVIO per giocare", CREAM, 48, Vector2(560, 100))
	cta.position = Vector2(900, 770)
	cta.pivot_offset = cta.size / 2.0
	add_child(cta)
	var tw := cta.create_tween().set_loops()
	tw.tween_property(cta, "scale", Vector2.ONE * 1.06, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cta, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	var tel := Risposta.etichetta("oppure entra dal telefono: quizzone.tv", Risposta.font_testo(), 36, CREAM, 760, 56)
	tel.position = Vector2(800, 880)
	add_child(tel)
	_aggiorna_opzione()


func _pill(testo: String, bg: Color, dim: int, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Risposta.box(bg, INK, 6, 14, int(sz.y / 2.0)))
	p.size = sz
	p.add_child(Risposta.etichetta(testo, Risposta.font_testo(), dim, INK, sz.x, sz.y - 8))
	return p


func set_sottotitoli(on: bool) -> void:
	_sottotitoli = on
	if _opz:
		_aggiorna_opzione()


func _aggiorna_opzione() -> void:
	if _opz:
		_opz.queue_free()
	_opz = _pill("Sottotitoli: %s  ·  ▼ per cambiare" % ("SÌ" if _sottotitoli else "NO"), GOLD, 36, Vector2(620, 72))
	_opz.position = Vector2(1204, 954)
	add_child(_opz)


func mostra() -> void:
	if _tw:
		_tw.kill()
	visible = true
	modulate.a = 0.0
	_logo.scale = Vector2.ZERO
	_tw = create_tween().set_parallel()
	_tw.tween_property(self, "modulate:a", 1.0, 0.25)
	_tw.tween_property(_logo, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func nascondi() -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 0.0, 0.3)
	_tw.tween_callback(func() -> void: visible = false)
