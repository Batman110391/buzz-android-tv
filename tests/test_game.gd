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
	g.question_resolved.connect(func(c: int, r: Dictionary, s: Dictionary) -> void: resolved.append([c, r, s]))
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
	g2.question_resolved.connect(func(c: int, r: Dictionary, s: Dictionary) -> void: res2.append([c, r, s]))
	g2.setup(names, [qs[0]], 1)
	g2.start()
	g2.advance()
	var q: Dictionary = q2[0]
	var giusta: String = qs[0]["risposte"][0]
	_check(q["risposte"][q["correct"]] == giusta, "mescolamento conserva la giusta")
	_check(qs[0]["risposte"][0] == giusta and not qs[0].has("correct"), "originale intatto")
	g2.submit_answer(0, q["correct"])
	g2.submit_answer(1, (q["correct"] + 1) % 4)
	g2.tick(0.1)
	g2.tick(20.0)
	_check(res2[0][1][0] and not res2[0][1][1] and not res2[0][1][2], "risultati")
	_check(res2[0][2][0] == 500 and res2[0][2][1] == 0, "punteggi")

	# punti iniziali + dito
	var gd = GameScript.new()
	var qd: Array = []
	gd.question_started.connect(func(i: int, t: int, qq: Dictionary) -> void: qd.append(qq))
	gd.setup(names, [qs[0]], 1, "dito", {0: 100, 1: 2000})
	gd.start()
	gd.advance()
	_check(gd.tempo_domanda() == 10.0 and gd.punti_ora() == 1000, "dito: tempo e contatore")
	var ok: int = qd[0]["correct"]
	gd.tick(2.0)
	gd.submit_answer(1, ok)
	gd.tick(3.0)
	gd.submit_answer(0, ok)
	gd.submit_answer(2, (ok + 1) % 4)
	var pp: Dictionary = {}
	gd.question_resolved.connect(func(c: int, r: Dictionary, s: Dictionary) -> void: pp.merge(s))
	gd.tick(0.1)
	var pr: Dictionary = gd.punti_presi()
	_check(pr[1] == 800 and pr[0] == 500 and pr[2] == 0, "dito: punti presi %s" % pr)
	_check(pp[0] == 600 and pp[1] == 2800 and pp[2] == 0, "punti iniziali + dito")
	var og: Array = gd.ordine_giusti()
	_check(og.size() == 2 and og[0]["pid"] == 1 and og[1]["pid"] == 0 and is_equal_approx(og[0]["secondi"], 2.0), "ordine giusti")

	# ruba
	var gr = GameScript.new()
	var qr: Array = []
	gr.question_started.connect(func(i: int, t: int, qq: Dictionary) -> void: qr.append(qq))
	gr.setup(names, [qs[0]], 1, "ruba", {0: 0, 1: 1000, 2: 200})
	gr.start()
	gr.advance()
	var okr: int = qr[0]["correct"]
	_check(gr.ruba(0, 1) == -1, "ruba fuori fase")
	gr.submit_answer(0, okr)
	gr.submit_answer(1, (okr + 1) % 4)
	gr.submit_answer(2, okr)
	gr.tick(0.1)
	_check(gr.punti_presi()[0] == 0, "ruba: giusta senza punti")
	_check(gr.vittima_predefinita(0) == 1 and gr.vittima_predefinita(1) == 2, "vittima predefinita")
	_check(gr.ruba(1, 0) == -1, "ladro sbagliato")
	_check(gr.ruba(0, 0) == -1 and gr.ruba(0, 7) == -1, "ruba se stesso/fuori range")
	_check(gr.ruba(0, 1) == 300, "furto normale")
	_check(gr.ruba(0, 1) == -1, "doppio furto")
	_check(gr.ruba(2, 0) == 300, "furto da chi ha 300")
	gr.advance()
	gr.advance()
	_check(gr.ruba(2, 1) == -1, "ruba fuori fase (scoreboard)")
	var gv = GameScript.new()
	var qv: Array = []
	gv.question_started.connect(func(i: int, t: int, qq: Dictionary) -> void: qv.append(qq))
	gv.setup(names, [qs[0]], 1, "ruba", {0: 0, 1: 100, 2: 0})
	gv.start()
	gv.advance()
	gv.submit_answer(0, qv[0]["correct"])
	gv.tick(20.0)
	_check(gv.ruba(0, 1) == 100, "vittima con meno di 300")
	# torta
	var gt = GameScript.new()
	var qst: Array = []
	gt.question_started.connect(func(i: int, t: int, qq: Dictionary) -> void: qst.append(qq))
	gt.setup(names, [qs[0]], 1, "torta", {0: 0, 1: 200, 2: 0})
	gt.start()
	gt.advance()
	var okt: int = qst[0]["correct"]
	_check(gt.time_left() == 15.0 and gt.lanciatore() == -1, "torta: tempo, lanciatore fuori fase")
	gt.submit_answer(1, okt)
	gt.tick(1.0)
	gt.submit_answer(2, okt)
	gt.submit_answer(0, (okt + 1) % 4)
	gt.tick(0.1)
	_check(gt.lanciatore() == 1 and gt.punti_presi()[2] == 500, "torta: primo giusto, +500")
	_check(gt.torta(2, 0) == 0 and gt.torta(1, 1) == 0, "torta: non lanciatore / se stesso")
	_check(gt.torta(1, 0) == 0, "torta: bersaglio a 0")
	_check(gt.torta(1, 2) == 300 and gt.torte(2) == 1, "torta: -300")
	_check(gt.torta(1, 2) == 0, "torta: una sola")
	var gt2 = GameScript.new()
	var qst2: Array = []
	gt2.question_started.connect(func(i: int, t: int, qq: Dictionary) -> void: qst2.append(qq))
	gt2.setup(names, [qs[0]], 1, "torta", {0: 100, 1: 0, 2: 0})
	gt2.start()
	gt2.advance()
	gt2.submit_answer(1, qst2[0]["correct"])
	gt2.tick(20.0)
	_check(gt2.torta(1, 0) == 100 and gt2.torte(0) == 1, "torta: non sotto zero")
	# ordine
	var qo := {"tipo": "ordine", "criterio": "x", "elementi": ["a", "b", "c", "d"], "valori": [1, 2, 3, 4]}
	var go = GameScript.new()
	var qso: Array = []
	go.question_started.connect(func(i: int, t: int, qq: Dictionary) -> void: qso.append(qq))
	go.setup(names, [qo], 1, "ordine")
	go.start()
	go.advance()
	var gi: Array = qso[0]["giusto"]
	var ris: Array = qso[0]["risposte"]
	_check(go.time_left() == 20.0 and ris.size() == 4, "ordine: tempo, voci")
	for k in 4:
		_check(ris[k] == ["a", "b", "c", "d"][gi[k]] and qso[0]["valori"][k] == gi[k] + 1, "ordine: giusto/valori coerenti")
	var perfetta: Array = []
	for j in 4:
		perfetta.append(gi.find(j))
	_check(not go.submit_ordine(0, [0, 1, 2]) and not go.submit_ordine(0, [0, 1, 1, 2]), "ordine: seq non valide")
	_check(not go.submit_ordine(0, [0, 1, 2, 4]) and not go.submit_ordine(9, perfetta), "ordine: fuori range")
	_check(not go.submit_answer(0, 0), "ordine: submit_answer rifiutato")
	_check(go.submit_ordine(0, perfetta) and not go.submit_ordine(0, perfetta), "ordine: una volta")
	go.submit_ordine(1, [perfetta[1], perfetta[0], perfetta[2], perfetta[3]])
	go.submit_ordine(2, [perfetta[1], perfetta[2], perfetta[0], perfetta[3]])
	go.tick(0.1)
	_check(go.punti_presi()[0] == 500 and go.punti_presi()[1] == 250 and go.punti_presi()[2] == 125, "ordine: 4/2/1 giuste")
	var g0 = GameScript.new()
	g0.setup(names, [qo], 1, "ordine")
	g0.start()
	g0.advance()
	g0.tick(25.0)
	_check(g0.punti_presi()[0] == 0 and g0.sequenza(0) == "", "ordine: 0 giuste, sequenza vuota")
	var gs = GameScript.new()
	gs.setup(names, [qo], 1, "ordine")
	gs.start()
	gs.advance()
	gs.submit_ordine(0, [2, 0, 1, 3])
	_check(gs.sequenza(0) == "C A B D", "ordine: sequenza")
	# conto
	var gc = GameScript.new()
	var qsc: Array = []
	gc.question_started.connect(func(i: int, t: int, qq: Dictionary) -> void: qsc.append(qq))
	gc.setup(names, [qs[0]], 1, "conto", {0: 1000, 1: 1000, 2: 100})
	gc.start()
	gc.advance()
	var okc: int = qsc[0]["correct"]
	_check(gc.punti_visti(0) == 1000, "conto: inizio")
	gc.tick(2.0)
	_check(gc.punti_visti(0) == 900, "conto: scende")
	gc.submit_answer(0, okc)
	gc.submit_answer(1, (okc + 1) % 4)
	gc.tick(3.0)
	_check(gc.punti_visti(0) == 900 and gc.punti_visti(1) == 900 and gc.punti_visti(2) == 0, "conto: fermi dopo risposta, non sotto zero")
	gc.tick(20.0)
	var sc: Dictionary = gc.punti_presi()
	_check(sc[0] == -100 and sc[1] == -750 and sc[2] == -100, "conto: perdite")
	_check(gc.punti_visti(0) == 900 and gc.punti_visti(1) == 250 and gc.punti_visti(2) == 0, "conto: punteggi finali")
	print("PASS")
	quit(0)
