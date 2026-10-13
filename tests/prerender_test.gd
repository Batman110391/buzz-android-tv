extends Node2D
## Prova P2: fondale pre-renderizzato + 5 personaggi animati (sprite), misura FPS sulla TV.

var _t := 0.0
var _n := 0


func _ready() -> void:
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/prerender_test/bg.png")
	bg.centered = false
	add_child(bg)
	var sf := SpriteFrames.new()
	for i in 10:
		sf.add_frame("default", load("res://assets/prerender_test/sprite_%04d.png" % i))
	sf.set_animation_speed("default", 10.0)
	for x in [440, 770, 1150, 1480, 1700]:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = sf
		s.position = Vector2(x, 700)
		s.frame = randi() % 10
		s.play()
		add_child(s)


func _process(delta: float) -> void:
	_t += delta
	_n += 1
	if _t >= 2.0:
		print("PERF fps=", snappedf(_n / _t, 0.1), " phase=prerender")
		_t = 0.0
		_n = 0
