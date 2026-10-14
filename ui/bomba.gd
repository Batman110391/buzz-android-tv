class_name BombaUI
extends Control
## Bomba nera con "?" (160x160), al posto del timer: la miccia è nascosta. dondola / esplodi / nuova.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GOLD := Color("FFC83D")
const MAGENTA := Color("FF3DA8")
const CORPO := Color("2A1A55")

var _t := 0.0
var _dondola := false
var _viva := true
var _flash := 0.0
var _pop: Tween
var _schegge: CPUParticles2D
var _fumo: CPUParticles2D


func _ready() -> void:
	size = Vector2(160, 160)
	pivot_offset = Vector2(80, 80)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_schegge = _particelle(INK, 28, 0.7, 700.0, 4.0)
	_fumo = _particelle(Color("6B5A9E"), 14, 1.2, 220.0, 7.0)
	_fumo.gravity = Vector2(0, -120)


func _particelle(col: Color, n: int, vita: float, vel: float, scala: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(80, 90)
	p.emitting = false
	p.one_shot = true
	p.amount = n
	p.lifetime = vita
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = scala
	p.scale_amount_max = scala * 2.0
	p.color = col
	add_child(p)
	return p


func dondola() -> void:
	_dondola = true


func _process(dt: float) -> void:
	_t += dt
	if _dondola and _viva:
		rotation = sin(_t * 3.0) * 0.09
	queue_redraw()


func esplodi() -> void:
	if not _viva:
		return
	_viva = false
	_dondola = false
	rotation = 0.0
	_fumo.restart()
	_schegge.restart()
	_flash = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_flash", 0.0, 0.5)
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void: scale = Vector2.ONE)


func nuova() -> void:
	_viva = true
	_flash = 0.0
	scale = Vector2.ZERO
	if _pop:
		_pop.kill()
	_pop = create_tween()
	_pop.tween_property(self, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _draw() -> void:
	if _flash > 0.0:
		var a := _flash
		draw_circle(Vector2(80, 90), 80.0 + 60.0 * (1.0 - a), Color(GOLD, a))
		draw_circle(Vector2(80, 90), 50.0 + 40.0 * (1.0 - a), Color(CREAM, a))
	if not _viva:
		return
	var c := Vector2(80, 98)
	# miccia
	var base := Vector2(106, 38)
	var punta := Vector2(122, 14)
	draw_line(base, Vector2(114, 22), INK, 12.0, true)
	draw_line(Vector2(114, 22), punta, INK, 12.0, true)
	draw_line(base, Vector2(114, 22), CREAM, 5.0, true)
	draw_line(Vector2(114, 22), punta, CREAM, 5.0, true)
	# scintilla animata
	var k := 0.5 + 0.5 * sin(_t * 18.0)
	draw_circle(punta, 11.0 + 4.0 * k, MAGENTA)
	draw_circle(punta, 7.0 + 3.0 * k, GOLD)
	draw_circle(punta, 3.5, CREAM)
	for i in 5:
		var an := _t * 6.0 + i * TAU / 5.0
		draw_line(punta + Vector2.from_angle(an) * 12.0, punta + Vector2.from_angle(an) * (18.0 + 6.0 * k), GOLD, 3.0, true)
	# corpo
	draw_circle(c, 62.0, INK)
	draw_circle(c, 52.0, CORPO)
	draw_rect(Rect2(62, 38, 36, 14), INK)  # colletto
	draw_rect(Rect2(66, 42, 28, 6), CORPO)
	# riflesso
	draw_arc(c, 40.0, deg_to_rad(200), deg_to_rad(250), 12, Color(CREAM, 0.55), 7.0, true)
	draw_circle(Vector2(48, 78), 5.0, Color(CREAM, 0.7))
	draw_string(Risposta.font_display(), Vector2(0, 98 + 24), "?", HORIZONTAL_ALIGNMENT_CENTER, 160, 76, CREAM)
