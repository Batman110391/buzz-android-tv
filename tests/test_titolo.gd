extends Node2D

var _t := SchermataTitolo.new()


func _ready() -> void:
	add_child(Palco.new())
	add_child(_t)
	_t.mostra()
	get_tree().create_timer(4.0).timeout.connect(func() -> void: _t.set_sottotitoli(false))
	get_tree().create_timer(7.0).timeout.connect(_t.nascondi)
	get_tree().create_timer(8.5).timeout.connect(_t.mostra)
