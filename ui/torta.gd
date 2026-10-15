class_name TortaUI
extends Control
## Torta in Faccia: mirino che salta da un punto all'altro + torta in volo (schermo intero, sopra i podi).

signal colpito

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GOLD := Color("FFC83D")
const MAGENTA := Color("FF3DA8")
const CROSTA := Color("C98A4B")
const PASSO := 0.35
const VOLO := 0.6

var _pos: Array[Vector2] = []
var _idx := 0
var _mira := false
var _acc := 0.0
var _t := 0.0
var _vola := false
var _da := Vector2.ZERO
var _a := Vector2.ZERO
var _k := 0.0
var _tw: Tween


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func mira(posizioni: Array[Vector2]) -> void:
	nascondi()
	_pos = posizioni
	_idx = 0
	_acc = 0.0
	_mira = not _pos.is_empty()


## Ferma il mirino e ritorna l'indice in `posizioni` (resta disegnato fino al lancio).
func ferma() -> int:
	_mira = false
	_t = 1.0
	return _idx


func lancia(da: Vector2, a: Vector2) -> void:
	_da = da
	_a = a
	_k = 0.0
	_vola = true
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "_k", 1.0, VOLO)
	_tw.tween_callback(func() -> void:
		_vola = false
		_pos.clear()
		colpito.emit())


func nascondi() -> void:
	if _tw:
		_tw.kill()
	_mira = false
	_vola = false
	_pos.clear()


func _process(dt: float) -> void:
	_t += dt
	if _mira:
		_acc += dt
		if _acc >= PASSO:
			_acc -= PASSO
			_idx = (_idx + 1) % _pos.size()
	queue_redraw()


func _draw() -> void:
	if not _pos.is_empty() and not _vola:
		var c := _pos[_idx]
		var r := 70.0 + (4.0 * sin(_t * 20.0) if _mira else 0.0)
		draw_arc(c, r, 0, TAU, 48, INK, 14.0, true)
		draw_arc(c, r, 0, TAU, 48, MAGENTA, 6.0, true)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * (r - 26.0), c + d * (r + 18.0), INK, 16.0)
			draw_line(c + d * (r - 24.0), c + d * (r + 16.0), MAGENTA, 6.0)
	if _vola:
		var p := _da.lerp(_a, _k) + Vector2(0, -260.0 * 4.0 * _k * (1.0 - _k))
		disegna(self, p, 54.0, _k * TAU * 2.0)


## Torta vista dall'alto: piatto, crosta, panna con ciliegia. Usata anche dal Podio per le icone.
static func disegna(ci: CanvasItem, c: Vector2, r: float, rot := 0.0) -> void:
	ci.draw_circle(c, r, INK)
	ci.draw_circle(c, r * 0.86, CROSTA)
	ci.draw_circle(c, r * 0.68, CREAM)
	for i in 6:
		ci.draw_circle(c + Vector2.from_angle(rot + i * TAU / 6.0) * r * 0.45, r * 0.16, Color.WHITE)
	ci.draw_circle(c, r * 0.24, INK)
	ci.draw_circle(c, r * 0.17, MAGENTA)
