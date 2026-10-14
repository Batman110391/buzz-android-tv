extends SceneTree

var _fail := false

func _check(cond: bool, msg: String) -> void:
	if not cond:
		print("FAIL: ", msg)
		_fail = true

func _domande() -> Array:
	var d: Array = []
	for i in 10:
		d.append({"testo": "Q%d" % i, "risposte": ["giusta", "b", "c", "d"]})
	return d

func _nuova(seed_: int, punti: Dictionary) -> Array:
	var b := Bomba.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var nomi: Array[String] = ["A", "B", "C"]
	b.setup(nomi, _domande(), punti, rng)
	var qs: Array = []
	b.question_started.connect(func(q: Dictionary, chi: int) -> void: qs.append([q, chi]))
	return [b, qs]

## fa scorrere il tempo finche' esplode; ritorna i secondi
func _fino_esplosione(b: Bomba) -> float:
	var t := 0.0
	var boom := [false]
	b.esplosa.connect(func(_p: int, _s: Dictionary) -> void: boom[0] = true)
	while not boom[0] and t < 100.0:
		b.tick(0.1)
		t += 0.1
	return t

func _init() -> void:
	# partenza dall'ultimo (pari -> id piu' basso)
	var r := _nuova(1, {0: 500, 1: 200, 2: 200})
	var b: Bomba = r[0]
	b.start()
	_check(b.chi_ha_bomba() == 1, "parte dall'ultimo (pari -> id basso)")
	_check(r[1].size() == 1, "prima domanda partita")
	var q: Dictionary = r[1][0][0]
	_check(not b.submit_answer(0, q["correct"]), "rifiuta chi non ha la bomba")
	_check(not b.submit_answer(1, 4), "rifiuta scelta fuori 0-3")
	# sbagliata: la tiene, nuova domanda
	var sbagl: int = (q["correct"] + 1) % 4
	_check(b.submit_answer(1, sbagl), "accetta sbagliata")
	_check(b.chi_ha_bomba() == 1 and r[1].size() == 2, "sbagliata: la tiene, nuova domanda")
	# giusta: passa a pid+1 modulo n
	q = r[1][1][0]
	_check(b.submit_answer(1, q["correct"]), "accetta giusta")
	_check(b.chi_ha_bomba() == 2 and r[1].size() == 3, "giusta: passa al successivo")
	q = r[1][2][0]
	b.submit_answer(2, q["correct"])
	_check(b.chi_ha_bomba() == 0, "passa con modulo")

	# esplosione -500, non sotto zero, ripartenza, 3 bombe, fine
	r = _nuova(7, {0: 300, 1: 100, 2: 900})
	b = r[0]
	var over: Array = []
	b.round_finito.connect(func(c: Array) -> void: over.append(c))
	b.start()
	_check(b.chi_ha_bomba() == 1, "start: ultimo = 1")
	for n in 3:
		var chi := b.chi_ha_bomba()
		var prima: int = b.punti()[chi]
		var t := _fino_esplosione(b)
		_check(t >= 19.9 and t <= 40.2, "miccia 20-40 s (%.1f)" % t)
		_check(b.punti()[chi] == maxi(prima - 500, 0), "-500 non sotto zero")
		_check(not b.submit_answer(chi, 0), "niente risposte dopo esplosione")
		b.advance()
		if n < 2:
			_check(b.chi_ha_bomba() == chi, "riparte da chi e' esploso")
			_check(over.is_empty(), "round non finito")
	_check(over.size() == 1, "fine dopo 3 bombe")
	_check(over[0][0]["id"] == 2, "classifica: 2 primo")
	_check(b.punti()[1] == 0, "1 a zero")

	# miccia sempre nel range con molti seed
	for s in 30:
		r = _nuova(s + 100, {})
		b = r[0]
		b.start()
		var t := _fino_esplosione(b)
		_check(t >= 19.9 and t <= 40.2, "miccia seed %d (%.1f)" % [s, t])

	print("FAIL" if _fail else "PASS")
	quit(1 if _fail else 0)
