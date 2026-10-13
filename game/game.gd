class_name Game extends RefCounted

const QUESTION_TIME := 15.0
const POINTS_CORRECT := 500
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

func setup(player_names: Array[String], questions: Array, num_questions: int) -> void:
	_names = player_names.duplicate()
	_pool = questions
	_num = num_questions
	_phase = Phase.MENU

func start() -> void:
	if _phase != Phase.MENU and _phase != Phase.FINAL:
		return
	_scores.clear()
	for i in _names.size():
		_scores[i] = 0
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
	_timer = QUESTION_TIME
	_answers.clear()
	_set_phase(Phase.QUESTION)
	question_started.emit(_index, _selected.size(), _selected[_index])

func submit_answer(player_id: int, choice: int) -> bool:
	if player_id < 0 or player_id >= _names.size() or _phase != Phase.QUESTION:
		return false
	if _answers.has(player_id) or time_left() <= 0.0 or choice < 0 or choice > 3:
		return false
	_answers[player_id] = choice
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
		if ok:
			_scores[i] += POINTS_CORRECT
	_set_phase(Phase.REVEAL)
	question_resolved.emit(correct, results, _scores.duplicate())

func time_left() -> float:
	return _timer if _phase == Phase.QUESTION else 0.0

func _ranking() -> Array:
	var r: Array = []
	for i in _names.size():
		r.append({"id": i, "name": _names[i], "score": _scores[i]})
	r.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"] or (a["score"] == b["score"] and a["id"] < b["id"]))
	return r
