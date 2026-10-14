extends SceneTree

const URL := "ws://127.0.0.1:8081"

var server: Node
var fails := 0
var clients: Array[Dictionary] = []
var joined_log: Array = []
var answered_log: Array = []
var left_log: Array = []
var stole_log: Array = []
var cat_log: Array = []


func _check(nome: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nome)
	if not cond:
		fails += 1


func _nuovo() -> Dictionary:
	var ws := WebSocketPeer.new()
	ws.connect_to_url(URL)
	var c := {"ws": ws, "box": []}
	clients.append(c)
	return c


func _apri(c: Dictionary) -> void:
	for i in 100:
		await _pump(1)
		if c.ws.get_ready_state() == WebSocketPeer.STATE_OPEN and not c.box.is_empty():
			return


func _pump(frames := 20) -> void:
	for i in frames:
		await process_frame
		OS.delay_msec(10)
		for c in clients:
			c.ws.poll()
			while c.ws.get_available_packet_count() > 0:
				c.box.append(JSON.parse_string(c.ws.get_packet().get_string_from_utf8()))


func _take(c: Dictionary, t: String) -> Dictionary:
	for m in c.box:
		if m is Dictionary and m.get("t") == t:
			c.box.erase(m)
			return m
	return {}


func _vuota(c: Dictionary) -> void:
	c.box = c.box.filter(func(m): return not (m is Dictionary and m.get("t") == "state"))


func _tx(c: Dictionary, d) -> void:
	c.ws.send_text(d if d is String else JSON.stringify(d))


func _join(code: String, avatar: String, nome := "", token := "") -> Dictionary:
	return {"t": "join", "code": code, "name": nome, "avatar": avatar, "token": token}


func _http(req: String) -> String:
	var tcp := StreamPeerTCP.new()
	tcp.connect_to_host("127.0.0.1", 8080)
	var out := ""
	var sent := false
	for i in 80:
		await process_frame
		OS.delay_msec(10)
		tcp.poll()
		if not sent and tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			tcp.put_data(req.to_utf8_buffer())
			sent = true
		var n := tcp.get_available_bytes() if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED else 0
		if n > 0:
			out += tcp.get_utf8_string(n)
		if sent and out != "" and tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
	return out


func _initialize() -> void:
	server = load("res://net/server.gd").new()
	root.add_child(server)
	server.joined.connect(func(s: int, n: String, a: String): joined_log.append([s, n, a]))
	server.left.connect(func(s: int): left_log.append(s))
	server.answered.connect(func(s: int, q: int, ch: int): answered_log.append([s, q, ch]))
	server.stole.connect(func(s: int, q: int, v: int): stole_log.append([s, q, v]))
	server.categoria_scelta.connect(func(s: int, r: int, sc: int): cat_log.append([s, r, sc]))
	server.apri_lobby()
	var code: String = server.codice

	var a := _nuovo()
	await _apri(a)
	_check("lobby inviata a chi si collega", not _take(a, "lobby").is_empty())

	_tx(a, _join("ZZZZ", "chef"))
	await _pump()
	_check("codice sbagliato -> reject codice", _take(a, "reject").get("reason") == "codice")

	_tx(a, _join(code, "chef", "  Mario\u0001Rossi123456789 "))
	await _pump()
	var w := _take(a, "welcome")
	_check("join ok -> welcome slot 0, nome ripulito", w.get("slot") == 0 and w.get("name") == "MarioRossi12" and w.get("color") == "#F2384A")
	_check("join ok -> lobby con presi", _take(a, "lobby").get("presi") == ["chef"])
	_check("signal joined", joined_log == [[0, "MarioRossi12", "chef"]])
	var token: String = w.get("token", "")
	_check("token 16 hex", token.length() == 16)

	var b := _nuovo()
	await _apri(b)
	_tx(b, _join(code, "chef"))
	await _pump()
	_check("stesso personaggio -> preso", _take(b, "reject").get("reason") == "preso")

	server.set_bot({1: "nonna"})
	await _pump()
	_tx(b, _join(code, "nonna"))
	await _pump()
	_check("personaggio di un bot -> preso", _take(b, "reject").get("reason") == "preso")

	_tx(b, _join(code, "gatto"))
	await _pump()
	w = _take(b, "welcome")
	_check("slot del bot saltato, nome predefinito", w.get("slot") == 2 and w.get("name") == "Brioche")

	var c := _nuovo()
	await _apri(c)

	server.invia_stato({"fase": "lobby"})
	await _pump()
	_tx(a, {"t": "answer", "q": 3, "choice": 0})
	await _pump()
	_check("answer fuori fase ignorata", answered_log.is_empty())

	_take(a, "state")
	server.invia_stato({"fase": "domanda", "q": 3, "tot": 10, "domanda": "?", "risposte": ["a", "b", "c", "d"]})
	await _pump()
	_check("state domanda con scelta -1", _take(a, "state").get("scelta") == -1)
	for m in [{"t": "answer", "q": 4, "choice": 1}, {"t": "answer", "q": 3, "choice": 7}, '{"t":"answer","q":3,"choice":1.5}',
			{"t": "answer", "q": "3", "choice": 1}, "non json", "[1,2]", "{\"t\":5}", {"t": "answer"}]:
		_tx(a, m)
	_tx(c, {"t": "answer", "q": 3, "choice": 1})
	await _pump()
	_check("answer q sbagliato/choice 7/float/spazzatura/non entrato ignorate", answered_log.is_empty())

	_tx(a, {"t": "answer", "q": 3, "choice": 2})
	await _pump()
	_check("answer valida -> answered", answered_log == [[0, 3, 2]])
	_tx(a, {"t": "answer", "q": 3, "choice": 1})
	await _pump()
	_check("doppia answer ignorata", answered_log.size() == 1)

	server.invia_esito(0, {"giusta": true, "punti": 500, "totale": 500, "posizione": 1})
	await _pump()
	_check("result al telefono", _take(a, "result").get("punti") == 500)

	server.chiudi_lobby()
	a.ws.close()
	await _pump()
	var a2 := _nuovo()
	await _apri(a2)
	_tx(a2, _join(code, "chef", "", token))
	await _pump()
	_check("rientro col token -> stesso slot", _take(a2, "welcome").get("slot") == 0)
	_check("rientro -> ultimo state con scelta", _take(a2, "state").get("scelta") == 2)
	_check("rientro non rimette joined", joined_log.size() == 2)

	_tx(a2, {"t": "steal", "q": 5, "victim": 2})
	await _pump()
	_check("steal fuori fase ignorata", stole_log.is_empty())
	_vuota(a2)
	_vuota(b)
	server.invia_stato({"fase": "ruba", "q": 5, "punti": 300, "tempo": 10, "puo": [0],
			"vittime": [{"slot": 0}, {"slot": 1}, {"slot": 2}]})
	await _pump()
	_check("puo per telefono (true/false)", _take(a2, "state").get("puo") == true and _take(b, "state").get("puo") == false)
	for m in [{"t": "steal", "q": 4, "victim": 2}, {"t": "steal", "q": 5, "victim": 4}, {"t": "steal", "q": 5, "victim": 0},
			{"t": "steal", "q": "5", "victim": 2}, {"t": "steal", "q": 5, "victim": "2"}, '{"t":"steal","q":5,"victim":1.5}', {"t": "steal"}]:
		_tx(a2, m)
	_tx(c, {"t": "steal", "q": 5, "victim": 2})
	await _pump()
	_check("steal q sbagliata/vittima fuori lista/se stesso/tipi/non entrato ignorate", stole_log.is_empty())
	_tx(a2, {"t": "steal", "q": 5, "victim": 2})
	await _pump()
	_check("steal valida -> stole", stole_log == [[0, 5, 2]])
	_tx(a2, {"t": "steal", "q": 5, "victim": 1})
	await _pump()
	_check("doppio steal ignorato", stole_log.size() == 1)
	_vuota(a2)
	server.invia_stato({"fase": "ruba", "q": 5, "punti": 300, "tempo": 10, "puo": [0, 2], "vittime": [{"slot": 0}, {"slot": 2}]})
	await _pump()
	_check("dopo aver rubato puo false", _take(a2, "state").get("puo") == false)

	_tx(a2, {"t": "cat", "r": 1, "scelta": 0})
	await _pump()
	_check("cat fuori fase ignorata", cat_log.is_empty())
	_vuota(a2)
	_vuota(b)
	server.invia_stato({"fase": "categoria", "r": 1, "tempo": 10, "opzioni": [], "chi": 0, "puo": [0]})
	await _pump()
	_check("categoria puo per telefono", _take(a2, "state").get("puo") == true and _take(b, "state").get("puo") == false)
	for m in [{"t": "cat", "r": 2, "scelta": 0}, {"t": "cat", "r": 1, "scelta": 3}, {"t": "cat", "r": 1, "scelta": -1},
			{"t": "cat", "r": 1, "scelta": "1"}, {"t": "cat", "r": "1", "scelta": 1}, {"t": "cat", "r": 1}]:
		_tx(a2, m)
	_tx(b, {"t": "cat", "r": 1, "scelta": 1})
	_tx(c, {"t": "cat", "r": 1, "scelta": 1})
	await _pump()
	_check("cat r/scelta/tipi sbagliati, slot non autorizzato, non entrato ignorate", cat_log.is_empty())
	_tx(a2, {"t": "cat", "r": 1, "scelta": 2})
	await _pump()
	_check("cat valida -> categoria_scelta", cat_log == [[0, 1, 2]])
	_tx(a2, {"t": "cat", "r": 1, "scelta": 1})
	await _pump()
	_check("doppia cat ignorata", cat_log.size() == 1)
	_vuota(a2)
	server.invia_stato({"fase": "categoria", "r": 1, "tempo": 10, "opzioni": [], "chi": 0, "puo": [0]})
	await _pump()
	_check("dopo la scelta puo false", _take(a2, "state").get("puo") == false)

	var d := _nuovo()
	await _apri(d)
	_tx(d, _join(code, "diva"))
	await _pump()
	_check("join senza token a lobby chiusa -> partita", _take(d, "reject").get("reason") == "partita")

	var r := await _http("GET / HTTP/1.1\r\nHost: x\r\n\r\n")
	_check("HTTP / -> 200", r.begins_with("HTTP/1.1 200"))
	r = await _http("GET /x HTTP/1.1\r\nHost: x\r\n\r\n")
	_check("HTTP /x -> 404", r.begins_with("HTTP/1.1 404"))

	print("RISULTATO: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
