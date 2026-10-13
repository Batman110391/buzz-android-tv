extends Node3D
## Scena di prova: mini-partita di 3 domande (1 umano + 3 bot). Regole in game/game.gd, grafica in stage/ e ui/.
## Regia: stage/director.gd (camere), il presentatore gira per lo studio, suoni via autoload Sfx.

const CHAR := preload("res://stage/character.gd")
const DIRECTOR := preload("res://stage/director.gd")
const VOICE := "res://assets/voice/%s.mp3"
const MODEL := "res://assets/models/characters/%s.fbx"
const CHARS := {"polpetta": "Don Polpetta", "smeralda": "Madame Smeralda", "zippo": "Zippo",
	"lola": "Lola Bigodina", "zombi": "Zio Zombi", "elvio": "Elvio Panzerotto", "macho": "El Macho"}
const DANCES: Array[String] = ["dance_hiphop", "dance_rumba", "dance_silly", "dance_thriller"]
const DIRS: Array[String] = ["ui_up", "ui_right", "ui_down", "ui_left"]  # risposte 0..3 col telecomando
const N := 4
const HOST_HOME := Vector3(0, 0, 2.6)
const HOST_BACK := Vector3(0, 0, -6.5)  # dietro i podi: entra passando fra i concorrenti
const HOST_SIDES: Array[Vector3] = [Vector3(-3.6, 0, 0.4), Vector3(3.6, 0, 0.4)]  # giro durante la domanda, fuori dalla fascia centrale

var game := Game.new()
var stage: Node3D
var hud: CanvasLayer
var host: Node3D
var director: Node
var chars: Array[Node3D] = []
var keys: Array[String] = []
var names: Array[String] = []
var questions: Array
var demo := false
var scores: Dictionary = {}
var _voice := AudioStreamPlayer.new()
var _voice_phase := -1
var _host_talking := false
var _host_gen := 0  # ogni nuovo giro del presentatore invalida quelli vecchi
var _last: Dictionary = {}
var _phase: Game.Phase = Game.Phase.MENU
var _menu_t := 10.5
var _menu_age := 0.0
var _intro_cam := false
var _can_restart := false
var _q_t := 0.0
var _hurry := false
var _answered: Dictionary = {}
var _bot_t: Dictionary = {}


func _ready() -> void:
	demo = "--demo" in OS.get_cmdline_user_args()
	questions = JSON.parse_string(FileAccess.get_file_as_string("res://game/questions.json"))
	var all: Array = CHARS.keys()
	all.shuffle()
	for i in N:
		keys.append(all[i])
		names.append(CHARS[all[i]])
	stage = (load("res://stage/stage.tscn") as PackedScene).instantiate()
	add_child(stage)
	hud = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	add_child(_voice)
	stage.setup_players(names)
	hud.setup_players(names, [null, null, null, null])
	host = _spawn("host", stage, 1.8)
	host.position = HOST_SIDES[0]
	host.arrived.connect(func() -> void:
		if _voice.playing and _host_talking:
			host.play(["talk", "talk2"].pick_random()))
	for i in N:
		chars.append(_spawn(keys[i], stage.get_node("PlayerSpot%d" % i), 1.4 if keys[i] == "zippo" else 1.8))
	director = DIRECTOR.new()
	add_child(director)
	director.setup(stage.cam, stage, host)
	stage.intro_finished.connect(func() -> void: _intro_cam = true)
	game.phase_changed.connect(_on_phase)
	game.question_started.connect(_on_question)
	game.answer_received.connect(_on_answer)
	game.question_resolved.connect(_on_resolved)
	game.game_over.connect(_on_game_over)
	game.setup(names, questions, 3)
	_menu()


func _spawn(key: String, parent: Node, height: float) -> Node3D:
	var c: Node3D = CHAR.new()
	parent.add_child(c)
	c.setup(MODEL % key, height)
	return c


func _process(delta: float) -> void:
	if not _voice.playing:
		Sfx.duck(false)
		if _host_talking:
			_host_talking = false
			if not host._walking:
				host.play("idle")
	match _phase:
		Game.Phase.MENU:
			_menu_t += delta
			_menu_age += delta
			if _menu_t >= 12.0:
				_menu_t = 0.0
				_say("menu_")
			if demo and _menu_age >= 2.0:
				game.start()
		Game.Phase.QUESTION:
			_q_t += delta
			for id: int in _bot_t:
				if _q_t >= _bot_t[id] and not _answered.has(id):
					game.submit_answer(id, randi() % 4)
			if not _hurry and game.time_left() <= 5.0 and _answered.size() < N:
				_hurry = true
				Sfx.play("tick_fast")
				_say("hurry_")
			hud.set_time(game.time_left(), Game.QUESTION_TIME)
			game.tick(delta)


func _input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_accept"):
		if _phase == Game.Phase.MENU:
			game.start()
		elif _phase == Game.Phase.FINAL and _can_restart:
			_to_menu()
	elif _phase == Game.Phase.QUESTION and not demo:
		var c := -1
		for i in 4:
			if e.is_action_pressed(DIRS[i]):
				c = i
		if e is InputEventKey and e.pressed and not e.echo:
			var k: int = int(e.keycode) - KEY_1
			if k >= 0 and k < 4:
				c = k
		if c >= 0:
			game.submit_answer(0, c)


# ---------- voce ----------

func _pick(group: String) -> String:
	var ids: Array[String] = []
	for n in range(1, 10):
		if ResourceLoader.exists(VOICE % (group + str(n))):
			ids.append(group + str(n))
	if ids.size() > 1:
		ids.erase(_last.get(group, ""))
	if ids.is_empty():
		return ""
	var id: String = ids.pick_random()
	_last[group] = id
	return id


## Non sovrappone due battute della stessa fase; una di fase diversa interrompe. group = prefisso "xxx_" (a caso) o id esatto.
func _say(group: String, host_talks := true) -> void:
	if _voice.playing and _voice_phase == _phase:
		return
	var id := _pick(group) if group.ends_with("_") else group
	if not ResourceLoader.exists(VOICE % id):
		return
	_voice.stream = load(VOICE % id)
	_voice.play()
	Sfx.duck(true)
	_voice_phase = _phase
	_host_talking = host_talks
	if host_talks and not host._walking:
		host.play(["talk", "talk2"].pick_random())


func _wait_voice() -> void:
	while _voice.playing:
		await get_tree().process_frame


func _then_advance() -> void:
	await _wait_voice()
	await get_tree().create_timer(1.0).timeout
	game.advance()


# ---------- presentatore ----------

## Porta il presentatore a `pos`; all'arrivo guarda `look` e fa `anim`. Ritorna false se nel frattempo è partito un altro giro.
func _host_go(pos: Vector3, look: Vector3, anim := "", walk := "walk") -> bool:
	_host_gen += 1
	var gen := _host_gen
	if host.position.distance_to(pos) > 0.2:
		host.walk_to(pos, walk)
		await host.arrived
		if gen != _host_gen:
			return false
	host.face(look)
	if anim != "":
		host.play(anim)
	elif _voice.playing and _host_talking:
		host.play(["talk", "talk2"].pick_random())
	return true


## Posto davanti al podio del concorrente i, di tre quarti verso la camera.
func _by_podium(i: int) -> Vector3:
	var s := (stage.get_node("PlayerSpot%d" % i) as Node3D).position
	return s + Vector3(0.9 if s.x <= 0.0 else -0.9, 0, 1.5)


func _spot(i: int) -> Vector3:
	return (stage.get_node("PlayerSpot%d" % i) as Node3D).position + Vector3(0, 0, 0.1)


## Durante la domanda gira da un lato all'altro dello studio, fuori dalla fascia dei concorrenti.
func _host_patrol() -> void:
	var side := 0 if host.position.x > 0.0 else 1
	while _phase == Game.Phase.QUESTION:
		if not await _host_go(HOST_SIDES[side], Vector3(0, 0, -2.4), "think", "strut"):
			return
		await get_tree().create_timer(randf_range(2.5, 4.0)).timeout
		side = 1 - side


# ---------- fasi ----------

func _menu() -> void:
	hud.show_menu()
	director.shot("wide")
	Sfx.music("menu")
	_host_wander()


## In menu il presentatore passeggia per lo studio.
func _host_wander() -> void:
	var pts: Array[Vector3] = [Vector3(-3.5, 0, 1.5), Vector3(3.5, 0, 1.0), Vector3(0, 0, 3.0), Vector3(-1.5, 0, -0.5)]
	var k := 0
	while _phase == Game.Phase.MENU:
		if not await _host_go(pts[k % pts.size()], Vector3(0, 0, 12), ["clap", "laugh", "point"].pick_random(), "strut"):
			return
		await get_tree().create_timer(2.5).timeout
		k += 1


func _on_phase(p: Game.Phase) -> void:
	_phase = p
	match p:
		Game.Phase.INTRO:
			_intro_cam = false
			hud.hide_all()
			stage.play_intro()
			Sfx.play("whoosh")
			Sfx.play("applause")
			_run_intro()
		Game.Phase.SCOREBOARD:
			_scoreboard()


func _run_intro() -> void:
	if "--quick" in OS.get_cmdline_user_args():  # catture brevi: salta l'intro
		host.position = HOST_HOME
		game.advance()
		return
	# entra da dietro passando fra i podi, mentre la gru scende sullo studio
	_host_gen += 1
	host.position = HOST_BACK
	director.shot("intro")
	_say("intro_")
	_host_go(HOST_HOME, Vector3(0, 0, 12), "", "strut")
	await get_tree().create_timer(3.2).timeout
	director.shot("host")
	await _wait_voice()
	while host._walking:
		await get_tree().process_frame
	for i in N:
		director.shot("player", i)
		_host_go(_by_podium(i), _spot(i), "point")
		chars[i].play(["happy", "clap"].pick_random())
		_say("pres_" + keys[i])
		await _wait_voice()
		chars[i].play("idle")
	_host_go(HOST_HOME, Vector3(0, 0, 12))
	while not _intro_cam:
		await get_tree().process_frame
	game.advance()


func _on_question(index: int, total: int, q: Dictionary) -> void:
	hud.show_question(index, total, q)
	stage.focus_question()
	director.shot("question")
	Sfx.music("question")
	Sfx.play("whoosh")
	for c in chars:
		c.play("think")
	_q_t = 0.0
	_hurry = false
	_answered.clear()
	_bot_t.clear()
	for i in range(0 if demo else 1, N):
		_bot_t[i] = randf_range(2.0, 10.0)
	_say("qfirst_" if index == 0 else ("qlast_" if index == total - 1 else "qnext_"))
	_host_patrol()


func _on_answer(id: int) -> void:
	hud.mark_answered(id)
	if _answered.is_empty():
		Sfx.play("buzz")
		director.shake(0.3)
		if randf() < 0.5:
			_say("firstbuzz_")
	else:
		Sfx.play("pop")
	_answered[id] = true


func _on_resolved(correct: int, results: Dictionary, new_scores: Dictionary) -> void:
	scores = new_scores
	hud.show_reveal(correct, results)
	stage.show_reveal(results)
	director.shot("reveal")
	Sfx.music("scores")
	var right: Array[int] = []
	var wrong: Array[int] = []
	for i in N:
		if results.get(i, false):
			right.append(i)
			chars[i].play(["cheer", "victory"].pick_random())
		else:
			wrong.append(i)
			chars[i].play(["disappointed", "defeated"].pick_random())
	var id: String = "someright_"
	if right.size() == N:
		id = "allright_"
		Sfx.play("applause")
	elif right.is_empty():
		id = "noneright_"
		Sfx.play("aww")
	elif right.size() == 1:
		id = "solo_" + keys[right[0]]
	Sfx.play("correct" if not right.is_empty() else "wrong")
	_say(id, false)
	_then_advance()
	# finiti gli stacchi sui volti, va a sfottere uno che ha sbagliato (o si congratula se hanno indovinato tutti)
	var target: int = wrong.pick_random() if not wrong.is_empty() else right.pick_random()
	await get_tree().create_timer(N * 1.0).timeout
	if _phase == Game.Phase.REVEAL:
		director.shot("host")
		_tease(target, wrong.is_empty())


func _tease(i: int, nice: bool) -> void:
	var arrived: bool = await _host_go(_by_podium(i), _spot(i), "clap" if nice else ["laugh", "taunt"].pick_random())
	if arrived and not nice:
		Sfx.play("boing")


func _ranking() -> Array:
	var r: Array = []
	for i in N:
		r.append({"id": i, "name": names[i], "score": scores.get(i, 0)})
	r.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score or (a.score == b.score and a.id < b.id))
	return r


func _scoreboard() -> void:
	var r := _ranking()
	hud.update_scores(scores)
	stage.update_scores(scores)
	hud.show_scoreboard(r)
	director.shot("scores")
	Sfx.play("cash")
	for c in chars:
		c.play("idle")
	var id: String = "scores_"
	if r[0].score == r[1].score:
		id = "tie_"
	elif randf() < 0.5:
		id = "last_" + keys[r[N - 1].id]
		_tease(r[N - 1].id, false)
	_say(id)
	_then_advance()


func _on_game_over(ranking: Array) -> void:
	Sfx.play("drumroll")
	director.shot("host")
	_host_go(HOST_HOME, Vector3(0, 0, 12))
	_say("final_")
	await _wait_voice()
	var w: int = ranking[0].id
	stage.celebrate(w)
	director.shot("winner", w)
	Sfx.music("final")
	Sfx.play("fanfare")
	Sfx.play("applause")
	for i in N:
		chars[i].play(DANCES.pick_random() if i == w else "clap")
	hud.show_final(ranking)
	_host_go(_by_podium(w), _spot(w), "clap")
	_say("win_" + keys[w])
	await _wait_voice()
	_say("outro_")
	await _wait_voice()
	_can_restart = true


func _to_menu() -> void:
	_can_restart = false
	game.setup(names, questions, 3)
	_phase = Game.Phase.MENU
	_menu_t = 10.5
	var zero: Dictionary = {}
	for i in N:
		zero[i] = 0
	hud.update_scores(zero)
	stage.update_scores(zero)
	for c in chars:
		c.play("idle")
	_menu()
