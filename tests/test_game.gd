extends SceneTree

const GameScript := preload("res://game/game.gd")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		print("FAIL: ", msg)
		quit(1)

func _init() -> void:
	DirAccess.remove_absolute(Domande.USCITE)
	var dom := Domande.new()
	dom.carica()
	var prime: Array = dom.pesca("classica", 5)
	_check(prime.size() == 5, "pesca 5")
	var qs: Array = dom.pesca("classica", 100)
	_check(qs.size() >= 12, "riserva >= 12")
	for q: Dictionary in qs.slice(0, qs.size() - 5):
		_check(not prime.has(q), "prima le mai uscite")
	for q: Dictionary in dom.pesca("classica", 3, 2):
		_check(int(q["difficolta"]) == 2, "filtro difficolta")
	DirAccess.remove_absolute(Domande.USCITE)

	var names: Array[String] = ["A", "B", "C"]
	var g = GameScript.new()
	var resolved: Array = []
	var over: Array = []
	g.question_resolved.connect(func(c: int, r: Dictionary, s: Dictionary, _w: Dictionary) -> void: resolved.append([c, r, s]))
	g.game_over.connect(func(r: Array) -> void: over.append(r))
	g.setup(names, qs, 2)
	_check(not g.submit_answer(0, 0), "risposta fuori fase")
	g.start()
	g.advance()
	_check(g.time_left() == 15.0, "timer iniziale")
	_check(not g.submit_answer(5, 0), "player inesistente")
	_check(not g.submit_answer(-1, 0), "player -1")
	_check(not g.submit_answer(0, -1), "choice -1")
	_check(not g.submit_answer(0, 4), "choice 4")
	_check(g.submit_answer(0, 0), "risposta valida")
	_check(not g.submit_answer(0, 1), "doppia")
	g.tick(1.0)
	_check(resolved.is_empty(), "non ancora REVEAL")
	g.submit_answer(1, 0)
	g.submit_answer(2, 0)
	g.tick(0.1)
	_check(resolved.size() == 1, "REVEAL con tutti risposto")
	g.advance()
	g.advance()
	g.tick(16.0)
	_check(not g.submit_answer(0, 0), "tardiva")
	_check(resolved.size() == 2, "REVEAL a tempo scaduto")
	_check(resolved[1][1][0] == false, "chi non risponde = false")
	g.advance()
	g.advance()
	_check(over.size() == 1, "game_over")
	var rk: Array = over[0]
	_check(rk.size() == 3, "ranking size")
	for i in rk.size() - 1:
		_check(rk[i]["score"] > rk[i + 1]["score"] or (rk[i]["score"] == rk[i + 1]["score"] and rk[i]["id"] < rk[i + 1]["id"]), "ranking ordinato")

	# punteggi e mescolamento: 1 domanda, tutti rispondono giusto/sbagliato
	var g2 = GameScript.new()
	var res2: Array = []
	var q2: Array = []
	g2.question_started.connect(func(i: int, t: int, q: Dictionary) -> void: q2.append(q))
	g2.question_resolved.connect(func(c: int, r: Dictionary, s: Dictionary, _w: Dictionary) -> void: res2.append([c, r, s]))
	g2.setup(names, [qs[0]], 1)
	g2.start()
	g2.advance()
	var q: Dictionary = q2[0]
	var giusta: String = qs[0]["risposte"][0]
	_check(q["risposte"][q["correct"]] == giusta, "mescolamento conserva la giusta")
	_check(qs[0]["risposte"][0] == giusta and not qs[0].has("correct"), "originale intatto")
	g2.submit_answer(0, q["correct"])
	g2.submit_answer(1, (q["correct"] + 1) % 4)
	g2.tick(7.5)
	g2.submit_answer(2, q["correct"])  # giusta a metà tempo
	g2.tick(20.0)
	_check(res2[0][1][0] and not res2[0][1][1] and res2[0][1][2], "risultati")
	_check(res2[0][2][0] == 500 and res2[0][2][1] == 0 and res2[0][2][2] == 380, "punteggi per velocità")
	print("PASS")
	quit(0)
