extends Node2D
## Cattura: bomba che dondola, esplode a ~4 s, ricompare a ~7 s, esplode ancora, poi quit.

var _b: BombaUI
var _t := 0.0
var _passo := 0


func _ready() -> void:
	add_child(Palco.new())
	_b = BombaUI.new()
	_b.position = Vector2(880, 460)
	add_child(_b)
	_b.dondola()


func _process(dt: float) -> void:
	_t += dt
	if _passo == 0 and _t >= 4.0:
		_passo = 1
		_b.esplodi()
	elif _passo == 1 and _t >= 7.0:
		_passo = 2
		_b.nuova()
		_b.dondola()
	elif _passo == 2 and _t >= 10.0:
		_passo = 3
		_b.esplodi()
	elif _passo == 3 and _t >= 12.0:
		get_tree().quit()
