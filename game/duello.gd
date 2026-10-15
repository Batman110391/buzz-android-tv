class_name Duello extends RefCounted
## Duello degli indizi: regole senza grafica. 2 squadre dalla classifica, 3 domande `indizi`,
## un indizio ogni INDIZIO_SEC (max 3), poi altri INDIZIO_SEC e la domanda si chiude.
## main chiama tick(dt) e, dopo domanda_finita, advance().

const DOMANDE := 3
const INDIZIO_SEC := 10.0
const SOGLIA := 1500
const PREMI: Array[int] = [1500, 1000, 500] # per membro, con 1/2/3 indizi visibili
const PENALITA := 300
enum Fase { FERMO, DOMANDA, CHIUSA, FINE }

## domanda mescolata (con "correct"), chi risponde per ciascuna squadra [pid_sq0, pid_sq1], numero domanda (0-based)
signal domanda_iniziata(q: Dictionary, chi: Array, k: int)
## compare l'indizio n (1-3)
signal nuovo_indizio(n: int)
## squadra (0/1), giusta, punti per membro (+premio se giusta, -PENALITA se sbagliata), punteggi aggiornati
signal risposta(squadra: int, giusta: bool, per_membro: int, punti: Dictionary)
signal domanda_finita(punti: Dictionary)
signal duello_finito(punti: Dictionary)

var _names: Array[String] = []
var _pool: Array = []
var _mazzo: Array = []
var _punti: Dictionary = {}
var _rng: RandomNumberGenerator
var _fase: Fase = Fase.FERMO
var _squadre: Array = []
var _k := -1
var _q: Dictionary = {}
var _t := 0.0
var _vis := 1
var _fatta: Array[bool] = [false, false]
var _blocco: Array[bool] = [false, false]


## vero se >= 3 giocatori e primo - ultimo >= SOGLIA
static func serve(punti: Dictionary) -> bool:
	if punti.size() < 3:
		return false
	var v: Array = punti.values()
	return v.max() - v.min() >= SOGLIA


## due array di pid, in ordine di classifica (punti decrescenti, pari -> pid basso)
static func squadre(punti: Dictionary) -> Array:
	var r: Array = punti.keys()
	r.sort_custom(func(a: int, b: int) -> bool:
		return punti[a] > punti[b] or (punti[a] == punti[b] and a < b))
	match r.size():
		3: return [[r[0], r[2]], [r[1]]]
		4: return [[r[0], r[3]], [r[1], r[2]]]
		5: return [[r[0], r[4]], [r[1], r[2], r[3]]]
		6: return [[r[0], r[5], r[4]], [r[1], r[2], r[3]]]
	return []


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
	if _fase != Fase.FERMO or _pool.is_empty():
		return
	_squadre = squadre(_punti)
	if _squadre.is_empty():
		return
	_mazzo.clear()
	_k = -1
	_prossima()


func _prossima() -> void:
	_k += 1
	if _mazzo.is_empty():
		_mazzo = _pool.duplicate()
		_rng_shuffle(_mazzo)
	_q = _mescola(_mazzo.pop_back())
	_t = 0.0
	_vis = 1
	_fatta = [false, false]
	_blocco = [false, false]
	_fase = Fase.DOMANDA
	domanda_iniziata.emit(_q, chi_risponde(), _k)


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
	_t += dt
	while _vis < 3 and _t >= _vis * INDIZIO_SEC:
		_vis += 1
		_blocco = [false, false]
		nuovo_indizio.emit(_vis)
	if _t >= 3 * INDIZIO_SEC:
		_chiudi()


func submit_answer(pid: int, choice: int) -> bool:
	if _fase != Fase.DOMANDA or choice < 0 or choice > 3:
		return false
	var s := chi_risponde().find(pid)
	if s < 0 or _fatta[s] or _blocco[s]:
		return false
	var giusta: bool = choice == _q["correct"]
	var delta: int = PREMI[_vis - 1] if giusta else -PENALITA
	for m: int in _squadre[s]:
		_punti[m] = maxi(_punti[m] + delta, 0)
	if giusta:
		_fatta[s] = true
	else:
		_blocco[s] = true
	risposta.emit(s, giusta, delta, _punti.duplicate())
	if _fatta[0] and _fatta[1]:
		_chiudi()
	return true


func _chiudi() -> void:
	_fase = Fase.CHIUSA
	domanda_finita.emit(_punti.duplicate())


## Dopo domanda_finita: domanda successiva o fine duello.
func advance() -> void:
	if _fase != Fase.CHIUSA:
		return
	if _k + 1 >= DOMANDE:
		_fase = Fase.FINE
		duello_finito.emit(_punti.duplicate())
	else:
		_prossima()


## pid di turno per ciascuna squadra nella domanda corrente
func chi_risponde() -> Array:
	var r: Array = []
	for sq: Array in _squadre:
		r.append(sq[maxi(_k, 0) % sq.size()])
	return r


## premio per membro adesso (con gli indizi visibili)
func premio() -> int:
	return PREMI[_vis - 1]


func indizi_visibili() -> int:
	return _vis


## secondi al prossimo indizio (dopo il 3°: alla chiusura della domanda)
func secondi_al_prossimo() -> float:
	return maxf(_vis * INDIZIO_SEC - _t, 0.0)


func squadre_attive() -> Array:
	return _squadre.duplicate(true)


func punti() -> Dictionary:
	return _punti.duplicate()
