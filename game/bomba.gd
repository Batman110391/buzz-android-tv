class_name Bomba extends RefCounted
## Passa la Bomba: regole senza grafica. Miccia nascosta 20-40 s per bomba, 3 bombe per round.

const BOMBE := 3
const MICCIA_MIN := 20.0
const MICCIA_MAX := 40.0
const PENALITA := 500
enum Fase { FERMO, DOMANDA, ESPLOSA, FINE }

signal question_started(q: Dictionary, chi: int)
signal passata(da: int, a: int)
signal sbagliata(pid: int)
signal esplosa(pid: int, punti: Dictionary)
signal round_finito(classifica: Array)

var _names: Array[String] = []
var _pool: Array = []
var _mazzo: Array = []
var _punti: Dictionary = {}
var _rng: RandomNumberGenerator
var _fase: Fase = Fase.FERMO
var _chi := 0
var _miccia := 0.0
var _esplose := 0
var _q: Dictionary = {}


func setup(nomi: Array[String], domande: Array, punti_iniziali: Dictionary, rng: RandomNumberGenerator = null) -> void:
	_names = nomi.duplicate()
	_pool = domande
	_punti = punti_iniziali.duplicate()
	for i in _names.size():
		if not _punti.has(i):
			_punti[i] = 0
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	_fase = Fase.FERMO


func start() -> void:
	if _fase != Fase.FERMO or _names.is_empty() or _pool.is_empty():
		return
	_esplose = 0
	_mazzo.clear()
	_chi = 0
	for i in _names.size():
		if _punti[i] < _punti[_chi]:
			_chi = i
	_nuova_bomba()


func _nuova_bomba() -> void:
	_miccia = _rng.randf_range(MICCIA_MIN, MICCIA_MAX)
	_domanda()


func _domanda() -> void:
	if _mazzo.is_empty():
		_mazzo = _pool.duplicate()
		_rng_shuffle(_mazzo)
	_q = _mescola(_mazzo.pop_back())
	_fase = Fase.DOMANDA
	question_started.emit(_q, _chi)


func _rng_shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


# la giusta è risposte[0]; qui si mescola e si aggiunge "correct"
func _mescola(src: Dictionary) -> Dictionary:
	var q: Dictionary = src.duplicate(true)
	var right: String = q["risposte"][0]
	var answers: Array = q["risposte"]
	_rng_shuffle(answers)
	q["correct"] = answers.find(right)
	return q


func tick(dt: float) -> void:
	if _fase != Fase.DOMANDA:
		return
	_miccia -= dt
	if _miccia > 0.0:
		return
	_fase = Fase.ESPLOSA
	_esplose += 1
	_punti[_chi] = maxi(_punti[_chi] - PENALITA, 0)
	esplosa.emit(_chi, _punti.duplicate())


func submit_answer(pid: int, choice: int) -> bool:
	if _fase != Fase.DOMANDA or pid != _chi or choice < 0 or choice > 3:
		return false
	if choice == _q["correct"]:
		var prossimo := (_chi + 1) % _names.size()
		passata.emit(_chi, prossimo)
		_chi = prossimo
	else:
		sbagliata.emit(_chi)
	_domanda()
	return true


## Dopo l'esplosione: bomba successiva (riparte da chi è esploso) o fine round.
func advance() -> void:
	if _fase != Fase.ESPLOSA:
		return
	if _esplose >= BOMBE:
		_fase = Fase.FINE
		round_finito.emit(_ranking())
	else:
		_nuova_bomba()


func chi_ha_bomba() -> int:
	return _chi


func punti() -> Dictionary:
	return _punti.duplicate()


func _ranking() -> Array:
	var r: Array = []
	for i in _names.size():
		r.append({"id": i, "name": _names[i], "score": _punti[i]})
	r.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"] or (a["score"] == b["score"] and a["id"] < b["id"]))
	return r
