extends SceneTree
## Demo fino alla prima domanda -> OK (pausa: tempo fermo) -> OK (riprende) -> OK ↓ OK (esce: titolo, stesso server).
## godot --headless --script tests/test_pausa.gd -- --demo

var _t := 0.0
var _passo := 0
var _main: Node
var _tl := 0.0


func _initialize() -> void:
	change_scene_to_file("res://main.tscn")


func _premi(a: String) -> void:
	for p in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = p
		Input.parse_input_event(e)


func _server_n() -> int:
	return root.get_children().filter(func(n: Node) -> bool: return n.get_script() == preload("res://net/server.gd")).size()


func _fallisci(m: String) -> void:
	printerr("FAIL: ", m)
	quit(1)


func _process(dt: float) -> bool:
	_t += dt
	if _t > 150.0:
		_fallisci("timeout al passo %d" % _passo)
	match _passo:
		0:
			if current_scene and current_scene.get("_fase") == "domanda" and _t > 1.0:
				_main = current_scene
				_premi("ui_accept")
				_passo = 1
				_t = 0.0
		1:
			if _t > 0.3:
				if not paused: _fallisci("non in pausa")
				_tl = _main.get("_game").time_left()
				_passo = 2
				_t = 0.0
		2:
			if _t > 2.0:
				if _main.get("_game").time_left() != _tl: _fallisci("il tempo scorre in pausa")
				_premi("ui_accept")
				_passo = 3
				_t = 0.0
		3:
			if _t > 1.0:
				if paused: _fallisci("non riprende")
				if _main.get("_game").time_left() >= _tl: _fallisci("il tempo non riparte")
				if _main.get("_fase") in ["domanda", "rivela", "round", "intermezzo", "categoria", "ruba", "bomba", "esplosione"]:
					_premi("ui_accept")
					_passo = 4
					_t = 0.0
		4:
			if _t > 0.3:
				if not paused: _fallisci("seconda pausa mancata")
				_premi("ui_down")
				_premi("ui_accept")
				_passo = 5
				_t = 0.0
		5:
			if _t > 2.0:
				if current_scene == _main or current_scene.get("_fase") != "titolo": _fallisci("non è tornato al titolo")
				if _server_n() != 1: _fallisci("server: %d" % _server_n())
				var s: Node = root.get_children().filter(func(n: Node) -> bool: return n.get_script() == preload("res://net/server.gd"))[0]
				s.answered.emit(0, 0, 0)  # le lambda della scena vecchia devono essere scollegate
				s.stole.emit(0, 0, 0)
				_passo = 6
				_t = 0.0
		6:
			if _t > 3.0:
				print("OK pausa")
				quit(0)
	return false
