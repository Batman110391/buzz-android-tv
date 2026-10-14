class_name Game extends RefCounted

const QUESTION_TIME := 15.0
const POINTS_CORRECT := 500
const DITO_MAX := 1000
const RUBA_PUNTI := 300
enum Phase { MENU, INTRO, QUESTION, REVEAL, SCOREBOARD, FINAL }

signal phase_changed(phase: Phase)
signal question_started(index: int, total: int, q: Dictionary)
signal answer_received(player_id: int)
signal question_resolved(correct: int, results: Dictionary, scores: Dictionary)
signal game_over(ranking: Array)

var _names: Array[String] = []
var _pool: Array = []
var _num: int = 0
var _selected: Array = []
var _index: int = -1
var _phase: Phase = Phase.MENU
var _timer: float = 0.0
var _answers: Dictionary = {}
var _scores: Dictionary = {}
var _modo: String = "accumula"
var _iniziali: Dictionary = {}
var _tempi: Dictionary = {}  # pid -> secondi impiegati
var _presi: Dictionary = {}
var _giusti: Dictionary = {}
var _rubato: Dictionary = {}

func setup(player_names: Array[String], questions: Array, num_questions: int, modo: String = "accumula", punti_iniziali: Dictionary = {}) -> void:
	_modo = modo
	_iniziali = punti_iniziali
	_names = player_names.duplicate()
	_pool = questions
	_num = num_questions
	_phase = Phase.MENU

func start() -> void:
	if _phase != Phase.MENU and _phase != Phase.FINAL:
		return
	_scores.clear()
	for i in _names.size():
		_scores[i] = int(_iniziali.get(i, 0))
	var shuffled: Array = _pool.duplicate()
	shuffled.shuffle()
	_selected.clear()
	for i in mini(_num, shuffled.size()):
		_selected.append(_shuffle_answers(shuffled[i]))
	_index = -1
	_set_phase(Phase.INTRO)

# formato di domande/ (game/domande.gd): la giusta è risposte[0]; qui si mescola e si aggiunge "correct"
func _shuffle_answers(src: Dictionary) -> Dictionary:
	var q: Dictionary = src.duplicate(true)
	var right: String = q["risposte"][0]
	var answers: Array = q["risposte"]
	answers.shuffle()
	q["correct"] = answers.find(right)
	return q

func _set_phase(p: Phase) -> void:
	_phase = p
	phase_changed.emit(p)

func advance() -> void:
	match _phase:
		Phase.INTRO:
			_next_question()
		Phase.REVEAL:
			_set_phase(Phase.SCOREBOARD)
		Phase.SCOREBOARD:
			if _index + 1 >= _selected.size():
				_set_phase(Phase.FINAL)
				game_over.emit(_ranking())
			else:
				_next_question()

func _next_question() -> void:
	_index += 1
	_timer = tempo_domanda()
	_answers.clear()
	_tempi.clear()
	_presi.clear()
	_giusti.clear()
	_rubato.clear()
	_set_phase(Phase.QUESTION)
	question_started.emit(_index, _selected.size(), _selected[_index])

func submit_answer(player_id: int, choice: int) -> bool:
	if player_id < 0 or player_id >= _names.size() or _phase != Phase.QUESTION:
		return false
	if _answers.has(player_id) or time_left() <= 0.0 or choice < 0 or choice > 3:
		return false
	_answers[player_id] = choice
	_tempi[player_id] = tempo_domanda() - _timer
	_presi[player_id] = punti_ora()
	answer_received.emit(player_id)
	return true

func tick(delta: float) -> void:
	if _phase != Phase.QUESTION:
		return
	_timer = maxf(_timer - delta, 0.0)
	if _timer > 0.0 and _answers.size() < _names.size():
		return
	var correct: int = _selected[_index]["correct"]
	var results: Dictionary = {}
	for i in _names.size():
		var ok: bool = _answers.get(i, -1) == correct
		results[i] = ok
		var p := 0
		if ok:
			_giusti[i] = true
			match _modo:
				"accumula": p = POINTS_CORRECT
				"dito": p = int(_presi.get(i, 0))
		_presi[i] = p
		_scores[i] += p
	_set_phase(Phase.REVEAL)
	question_resolved.emit(correct, results, _scores.duplicate())

func tempo_domanda() -> float:
	return 10.0 if _modo == "dito" else QUESTION_TIME

## valore attuale del contatore del Dito Veloce (1000 -> 0, a passi di 10)
func punti_ora() -> int:
	return int(roundf(DITO_MAX * clampf(_timer / tempo_domanda(), 0.0, 1.0) / 10.0)) * 10

func punti_presi() -> Dictionary:
	return _presi.duplicate()

## [{pid, secondi}] dei giusti, dal più veloce
func ordine_giusti() -> Array:
	var r: Array = []
	for pid in _giusti:
		r.append({"pid": pid, "secondi": _tempi.get(pid, tempo_domanda())})
	r.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["secondi"] < b["secondi"])
	return r

func vittima_predefinita(ladro: int) -> int:
	for e: Dictionary in _ranking():
		if e["id"] != ladro:
			return e["id"]
	return -1

func ruba(ladro: int, vittima: int) -> int:
	if _phase != Phase.REVEAL or not _giusti.has(ladro) or _rubato.has(ladro):
		return -1
	if vittima == ladro or vittima < 0 or vittima >= _names.size():
		return -1
	_rubato[ladro] = true
	var n := mini(RUBA_PUNTI, _scores[vittima])
	_scores[vittima] -= n
	_scores[ladro] += n
	return n

func time_left() -> float:
	return _timer if _phase == Phase.QUESTION else 0.0

func _ranking() -> Array:
	var r: Array = []
	for i in _names.size():
		r.append({"id": i, "name": _names[i], "score": _scores[i]})
	r.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"] or (a["score"] == b["score"] and a["id"] < b["id"]))
	return r
