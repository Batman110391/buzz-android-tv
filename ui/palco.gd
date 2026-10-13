class_name Palco
extends Node2D
## Sfondo palco: PNG 1920x1080 + lampadine (nodi) in due gruppi che alternano l'alfa ogni 0,4 s.

const PASSO := 44.1
var _gruppi: Array[Node2D] = []
var _acceso := 0


func _ready() -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/palco/palco.png")
	s.centered = false
	add_child(s)
	for i in 2:
		var g := Node2D.new()
		add_child(g)
		_gruppi.append(g)
	var tex := _texture_lampadina()
	var pos: Array[Vector2] = _punti_ellisse(Vector2(960, 930), 690.0, 550.0)
	for y in range(170, 851, 42):
		pos.append(Vector2(18, y))
	for y in range(170, 851, 42):
		pos.append(Vector2(1902, y))
	for i in pos.size():
		var b := Sprite2D.new()
		b.texture = tex
		b.position = pos[i]
		_gruppi[i % 2].add_child(b)
	_alterna()
	var t := create_tween().set_loops()
	t.tween_interval(0.4)
	t.tween_callback(_alterna)


func _alterna() -> void:
	_acceso = 1 - _acceso
	_gruppi[_acceso].modulate.a = 1.0
	_gruppi[1 - _acceso].modulate.a = 0.35


# Punti a distanza PASSO lungo l'ellisse (da ore 3, in senso orario), solo quelli visibili.
func _punti_ellisse(c: Vector2, rx: float, ry: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var prec := c + Vector2(rx, 0)
	var acc := 0.0
	for k in range(1, 8001):
		var a := TAU * k / 8000.0
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		acc += p.distance_to(prec)
		prec = p
		if acc >= PASSO:
			acc -= PASSO
			if p.y < 1087.0:
				out.append(p)
	return out


func _texture_lampadina() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			img.set_pixel(x, y, Color(1.0, 0.784, 0.239, clampf(7.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
