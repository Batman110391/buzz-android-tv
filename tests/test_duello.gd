extends SceneTree

var _fail := false

func _check(cond: bool, msg: String) -> void:
	if not cond:
		print("FAIL: ", msg)
		_fail = true

func _domande() -> Array:
	var d: Array = []
	for i in 10:
		d.append({"categoria_indizi": "C", "indizi": ["i1", "i2", "i3"], "risposte": ["giusta", "b", "c", "d"]})
	return d

func _nuovo(n: int, punti: Dictionary) -> Array:
	var d := Duello.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var nomi: Array[String] = []
	for i in n:
		nomi.append("P%d" % i)
	d.setup(nomi, _domande(), punti, rng)
	var ev := {"qs": [], "fine_d": [], "fine_q": [], "ind": [], "ris": []}
	d.domanda_iniziata.connect(func(q: Dictionary, chi: Array, k: int) -> void: ev["qs"].append([q, chi, k]))
	d.domanda_finita.connect(func(_p: Dictionary) -> void: ev["fine_q"].append(1))
	d.duello_finito.connect(func(p: Dictionary) -> void: ev["fine_d"].append(p))
	d.nuovo_indizio.connect(func(i: int) -> void: ev["ind"].append(i))
	d.risposta.connect(func(s: int, g: bool, pm: int, _p: Dictionary) -> void: ev["ris"].append([s, g, pm]))
	return [d, ev]

func _giusta(ev: Dictionary) -> int:
	return ev["qs"][-1][0]["correct"]

func _sbagliata(ev: Dictionary) -> int:
	return (ev["qs"][-1][0]["correct"] + 1) % 4

func _init() -> void:
	# squadre
	_check(Duello.squadre({0: 5, 1: 4, 2: 3}) == [[0, 2], [1]], "squadre 3")
	_check(Duello.squadre({0: 1, 1: 4, 2: 3, 3: 9}) == [[3, 0], [1, 2]], "squadre 4")
	_check(Duello.squadre({0: 5, 1: 4, 2: 3, 3: 2, 4: 1}) == [[0, 4], [1, 2, 3]], "squadre 5")
	_check(Duello.squadre({0: 6, 1: 5, 2: 4, 3: 3, 4: 2, 5: 1}) == [[0, 5, 4], [1, 2, 3]], "squadre 6")
	_check(Duello.squadre({0: 5, 1: 5, 2: 5}) == [[0, 2], [1]], "pari: pid basso prima")
	# serve
	_check(Duello.serve({0: 1500, 1: 0, 2: 700}), "serve a 1500")
	_check(not Duello.serve({0: 1499, 1: 0, 2: 700}), "non serve a 1499")
	_check(not Duello.serve({0: 5000, 1: 0}), "non serve con 2 giocatori")

	# premi 1500/1000/500, turno, rifiuti (squadre: [0,2] vs [1])
	var r := _nuovo(3, {0: 3000, 1: 2000, 2: 1000})
	var d: Duello = r[0]
	var ev: Dictionary = r[1]
	d.start()
	_check(ev["qs"][0][1] == [0, 1], "turno domanda 0")
	_check(d.premio() == 1500, "premio 1500")
	_check(not d.submit_answer(2, _giusta(ev)), "rifiuta membro non di turno")
	_check(not d.submit_answer(0, 4), "rifiuta scelta fuori range")
	d.tick(10.1)
	_check(d.indizi_visibili() == 2 and d.premio() == 1000 and ev["ind"] == [2], "indizio 2 a 10 s")
	_check(d.submit_answer(0, _giusta(ev)), "squadra A giusta")
	_check(d.punti()[0] == 4000 and d.punti()[2] == 2000, "1000 a ogni membro")
	_check(not d.submit_answer(0, _giusta(ev)), "A non risponde due volte")
	# B sbagliata: -300, bloccata fino al prossimo indizio
	_check(d.submit_answer(1, _sbagliata(ev)), "B sbagliata accettata")
	_check(d.punti()[1] == 1700, "-300")
	_check(not d.submit_answer(1, _giusta(ev)), "B bloccata")
	d.tick(10.0)
	_check(d.premio() == 500, "premio 500")
	_check(d.submit_answer(1, _giusta(ev)), "B sblocca al prossimo indizio")
	_check(d.punti()[1] == 2200, "500")
	_check(ev["fine_q"].size() == 1, "fine domanda quando entrambe indovinano")
	_check(not d.submit_answer(1, 0), "niente risposte a domanda chiusa")
	# turno ruota
	d.advance()
	_check(ev["qs"][1][1] == [2, 1], "turno domanda 1: membro successivo")
	_check(d.premio() == 1500, "premio riparte da 1500")

	# tempo: 3 indizi + 10 s, sbagliata dopo il 3 = fuori; -300 non sotto zero
	r = _nuovo(3, {0: 1600, 1: 100, 2: 0})
	d = r[0]
	ev = r[1]
	d.start()
	d.submit_answer(1, _sbagliata(ev))
	_check(d.punti()[1] == 0, "non sotto zero")
	d.tick(20.1)
	_check(ev["ind"] == [2, 3], "tre indizi")
	d.submit_answer(1, _sbagliata(ev))
	d.tick(5.0)
	_check(not d.submit_answer(1, _giusta(ev)), "dopo il 3 e fuori")
	_check(ev["fine_q"].is_empty(), "ancora in tempo")
	d.tick(5.0)
	_check(ev["fine_q"].size() == 1, "fine per tempo")
	# 3 domande poi fine
	d.advance()
	d.tick(31.0)
	_check(ev["fine_d"].is_empty(), "dopo 2 domande non e finito")
	d.advance()
	_check(ev["qs"].size() == 3 and ev["qs"][2][1] == [0, 1], "terza domanda, turno k%n")
	d.tick(31.0)
	d.advance()
	_check(ev["fine_d"].size() == 1 and ev["qs"].size() == 3, "fine dopo 3 domande")

	print("FAIL" if _fail else "PASS")
	quit(1 if _fail else 0)
