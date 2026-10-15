class_name Game extends RefCounted

const QUESTION_TIME := 15.0
const POINTS_CORRECT := 500
const DITO_MAX := 1000
const RUBA_PUNTI := 300
const TORTA_PUNTI := 300
const ORDINE_PUNTI := 125
const CONTO_AL_SEC := 50
const CONTO_BONUS := 300  # conto: chi indovina prende anche questi (S 2026-10-15: rimonte possibili, nessuno a zero per forza)
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
var _seq: Dictionary = {}  # pid -> sequenza ordine
var _torte: Dictionary = {}  # pid -> torte subite
var _tortato: bool = false

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
	_torte.clear()
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
	# ordine: risposte = voci mescolate, giusto[k] = posizione giusta (0-3) della voce k mostrata,
	# valori[k] = valore della voce k mostrata
	if q.has("elementi"):
		var perm: Array = [0, 1, 2, 3]
		perm.shuffle()
		var el: Array = q["elementi"]
		var va: Array = q["valori"]
		q["risposte"] = perm.map(func(i: int) -> Variant: return el[i])
		q["valori"] = perm.map(func(i: int) -> Variant: return va[i])
		q["giusto"] = perm
		q["correct"] = -1
		return q
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
	_seq.clear()
	_tortato = false
	_set_phase(Phase.QUESTION)
	question_started.emit(_index, _selected.size(), _selected[_index])

func submit_answer(player_id: int, choice: int) -> bool:
	if player_id < 0 or player_id >= _names.size() or _phase != Phase.QUESTION:
		return false
	if _answers.has(player_id) or time_left() <= 0.0 or choice < 0 or choice > 3 or _selected[_index].has("elementi"):
		return false
	_answers[player_id] = choice
	_tempi[player_id] = tempo_domanda() - _timer
	_presi[player_id] = punti_ora()
	answer_received.emit(player_id)
	return true

## seq = 4 indici distinti delle voci mostrate, nell'ordine scelto dal giocatore
func submit_ordine(player_id: int, seq: Array) -> bool:
	if player_id < 0 or player_id >= _names.size() or _phase != Phase.QUESTION or not _selected[_index].has("elementi"):
		return false
	if _answers.has(player_id) or time_left() <= 0.0 or seq.size() != 4:
		return false
	for v in seq:
		if not (v is int) or v < 0 or v > 3 or seq.count(v) != 1:
			return false
	_answers[player_id] = seq.duplicate()
	_seq[player_id] = seq.duplicate()
	_tempi[player_id] = tempo_domanda() - _timer
	answer_received.emit(player_id)
	return true

## es. "C A B D" (lettere delle voci mostrate)
func sequenza(pid: int) -> String:
	var l: Array = []
	for i: int in _seq.get(pid, []):
		l.append(char(65 + i))
	return " ".join(l)

func tick(delta: float) -> void:
	if _phase != Phase.QUESTION:
		return
	_timer = maxf(_timer - delta, 0.0)
	if _timer > 0.0 and _answers.size() < _names.size():
		return
	var correct: int = _selected[_index]["correct"]
	var results: Dictionary = {}
	for i in _names.size():
		var p := 0
		var ok: bool
		if _selected[_index].has("elementi"):
			var giusto: Array = _selected[_index]["giusto"]
			var s: Array = _seq.get(i, [])
			var n := 0
			for j in s.size():
				if giusto[s[j]] == j:
					n += 1
			ok = n == 4
			p = n * ORDINE_PUNTI
		else:
			ok = _answers.get(i, -1) == correct
		results[i] = ok
		if ok:
			_giusti[i] = true
			match _modo:
				"accumula", "torta": p = POINTS_CORRECT
				"dito": p = int(_presi.get(i, 0))
		if _modo == "conto":
			p = -mini(_perdita_conto(i, ok), _scores[i]) + (CONTO_BONUS if ok else 0)
		_presi[i] = p
		_scores[i] += p
	_set_phase(Phase.REVEAL)
	question_resolved.emit(correct, results, _scores.duplicate())

func tempo_domanda() -> float:
	if _modo == "dito":
		return 10.0
	return 20.0 if _modo == "ordine" else QUESTION_TIME

func _perdita_conto(pid: int, ok: bool) -> int:
	if not ok:
		return CONTO_AL_SEC * int(QUESTION_TIME)
	return int(roundf(CONTO_AL_SEC * float(_tempi.get(pid, QUESTION_TIME))))

## conto: punti da mostrare ora (scendono di 50/s, fermi alla risposta del giocatore)
func punti_visti(pid: int) -> int:
	if _phase != Phase.QUESTION:
		return _scores.get(pid, 0)
	var t: float = _tempi.get(pid, tempo_domanda() - _timer)
	return maxi(_scores.get(pid, 0) - int(roundf(CONTO_AL_SEC * t)), 0)

## torta: primo che ha risposto giusto alla domanda appena risolta (-1 se nessuno)
func lanciatore() -> int:
	if _phase != Phase.REVEAL:
		return -1
	var o := ordine_giusti()
	return o[0]["pid"] if not o.is_empty() else -1

func torta(da: int, a: int) -> int:
	if _modo != "torta" or _tortato or da < 0 or da != lanciatore():
		return 0
	if a == da or a < 0 or a >= _names.size():
		return 0
	var n := mini(TORTA_PUNTI, _scores[a])
	if n <= 0:
		return 0
	_tortato = true
	_scores[a] -= n
	_torte[a] = torte(a) + 1
	return n

func torte(pid: int) -> int:
	return _torte.get(pid, 0)

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
