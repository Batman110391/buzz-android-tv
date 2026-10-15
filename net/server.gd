extends Node
# Server telefoni: HTTP 8080 (controller.html) + WebSocket 8081. Protocollo: PLAN.md §4 (G2).
# Non conosce il gioco: lo pilota main.gd.

signal joined(slot: int, nome: String, avatar: String)
signal left(slot: int)
signal answered(slot: int, q: int, choice: int)
signal stole(slot: int, q: int, victim: int)
signal categoria_scelta(slot: int, r: int, scelta: int)
signal ordered(slot: int, q: int, seq: Array)
signal thrown(slot: int, q: int)

const HTTP_PORT := 8080
const WS_PORT := 8081
const MAX_CONN := 12
const MAX_HTTP := 4096
const MAX_PKT := 1024
const TIMEOUT_MS := 5000
const RILASCIO_MS := 15000
const SLOTS := 6
const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const PERSONAGGI := {
	"chef": {"nome": "Gastone", "colore": "#F2384A"},
	"nonna": {"nome": "Nonna Pina", "colore": "#2F7BFF"},
	"zombi": {"nome": "Ugo", "colore": "#33C759"},
	"gatto": {"nome": "Brioche", "colore": "#FFD43B"},
	"boss": {"nome": "Don Ciccio", "colore": "#A855F7"},
	"diva": {"nome": "Vanessa", "colore": "#FF8A1F"},
}

var codice := ""
var _http := TCPServer.new()
var _ws := TCPServer.new()
var _http_clients: Array[Dictionary] = []  # {peer, buf, t}
var _conns: Array[Dictionary] = []  # {ws, slot, open, t}
var _players := {}  # slot -> {nome, avatar, token, conn (Dictionary o null), disc}
var _bot := {}  # slot -> avatar
var _aperta := false
var _state := {}
var _t_stato := 0  # ms di quando è arrivato _state: "tempo" si accorcia per chi lo riceve dopo
var _sospeso := {}  # stato messo da parte dalla pausa
var _risposte := {}  # slot -> {q, choice}
var _rubato := {}  # slot -> q in cui ha già rubato
var _scelto := {}  # slot -> r in cui ha già scelto la categoria
var _ordinato := {}  # slot -> {q, seq}
var _lanciato := {}  # slot -> q in cui ha già lanciato la torta


func _init() -> void:
	for x in Crypto.new().generate_random_bytes(4):
		codice += CHARS[x % CHARS.length()]


func _ready() -> void:
	_http.listen(HTTP_PORT)
	_ws.listen(WS_PORT)
	print("Controller URL: ", url())


func get_lan_url() -> String:
	# 192.168 prima: 10.x e 172.x sono spesso interfacce VPN (es. tun0 sulla Fire TV)
	var addrs := IP.get_local_addresses()
	for prefix in ["192.168.", "10.", "172."]:
		for a in addrs:
			if a.begins_with(prefix) and a.count(".") == 3:
				return "http://%s:%d" % [a, HTTP_PORT]
	return "http://127.0.0.1:%d" % HTTP_PORT


func url() -> String:
	return "%s/?c=%s" % [get_lan_url(), codice]


func apri_lobby() -> void:
	_aperta = true


func chiudi_lobby() -> void:
	_aperta = false


func set_bot(occupati: Dictionary) -> void:
	_bot = occupati.duplicate()
	_tutti(_msg_lobby())


func giocatori() -> Dictionary:
	var r := {}
	for s in _players:
		r[s] = {"nome": _players[s].nome, "avatar": _players[s].avatar}
	return r


func reset() -> void:
	for s in _players:
		var c = _players[s].conn
		if c != null:
			c.slot = -1
			_send(c, {"t": "state", "fase": "lobby"})
	_players.clear()
	_risposte.clear()
	_rubato.clear()
	_scelto.clear()
	_ordinato.clear()
	_lanciato.clear()
	_state = {}
	_tutti(_msg_lobby())


func invia_stato(d: Dictionary) -> void:
	_state = {}
	_state.merge(d, true)
	_state["t"] = "state"
	_t_stato = Time.get_ticks_msec()
	for c in _conns:
		if c.slot >= 0:
			_send(c, _msg_state(c.slot))


## Pausa: i telefoni aspettano (e non possono rispondere); riprendi() rimanda lo stato di prima, col tempo fermo durante la pausa.
func pausa() -> void:
	_sospeso = {"state": _state, "t": _t_stato, "da": Time.get_ticks_msec()}
	invia_stato({"fase": "attesa"})


func riprendi() -> void:
	_state = _sospeso.state
	_t_stato = _sospeso.t + Time.get_ticks_msec() - _sospeso.da
	for c in _conns:
		if c.slot >= 0:
			_send(c, _msg_state(c.slot))


func invia_esito(slot: int, d: Dictionary) -> void:
	if not _players.has(slot) or _players[slot].conn == null:
		return
	var m := {}
	m.merge(d, true)
	m["t"] = "result"
	_send(_players[slot].conn, m)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	_http_poll(now)

	while _ws.is_connection_available():
		var s := _ws.take_connection()
		if _conns.size() >= MAX_CONN:
			s.disconnect_from_host()
			continue
		var ws := WebSocketPeer.new()
		ws.accept_stream(s)
		_conns.append({"ws": ws, "slot": -1, "open": false, "t": now})
	for c in _conns.duplicate():
		var ws: WebSocketPeer = c.ws
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if not c.open:
					c.open = true
					_send(c, _msg_lobby())
				while ws.get_available_packet_count() > 0:
					var pkt := ws.get_packet()
					if pkt.size() <= MAX_PKT:
						_ricevi(c, pkt.get_string_from_utf8())
			WebSocketPeer.STATE_CONNECTING:
				if now - c.t > TIMEOUT_MS:
					ws.close()
					_conns.erase(c)
			WebSocketPeer.STATE_CLOSED:
				_conns.erase(c)
				_scollega(c, now)

	if _aperta:
		for s in _players.keys():
			var p: Dictionary = _players[s]
			if p.conn == null and now - p.disc >= RILASCIO_MS:
				_players.erase(s)
				_risposte.erase(s)
				left.emit(s)
				_tutti(_msg_lobby())


func _http_poll(now: int) -> void:
	while _http.is_connection_available():
		_http_clients.append({"peer": _http.take_connection(), "buf": "", "t": now})
	for c in _http_clients.duplicate():
		var peer: StreamPeerTCP = c.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or now - c.t > TIMEOUT_MS:
			peer.disconnect_from_host()
			_http_clients.erase(c)
			continue
		var n := mini(peer.get_available_bytes(), MAX_HTTP + 1)
		if n > 0:
			c.buf += peer.get_utf8_string(n)
		if c.buf.length() > MAX_HTTP:
			peer.disconnect_from_host()
			_http_clients.erase(c)
		elif c.buf.contains("\r\n\r\n"):
			var riga: PackedStringArray = c.buf.get_slice("\r\n", 0).split(" ")
			var ok := riga.size() >= 2 and riga[0] == "GET" and (riga[1] == "/" or riga[1].begins_with("/?"))
			var body := FileAccess.get_file_as_bytes("res://net/controller.html") if ok else "Not found".to_utf8_buffer()
			var head := "HTTP/1.1 %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % ["200 OK" if ok else "404 Not Found", body.size()]
			peer.put_data(head.to_utf8_buffer() + body)
			peer.disconnect_from_host()
			_http_clients.erase(c)


func _scollega(c: Dictionary, now: int) -> void:
	if c.slot >= 0 and _players.has(c.slot) and _players[c.slot].conn == c:
		_players[c.slot].conn = null
		_players[c.slot].disc = now


func _ricevi(c: Dictionary, txt: String) -> void:
	var j := JSON.new()
	if j.parse(txt) != OK or not j.data is Dictionary:
		return
	var m: Dictionary = j.data
	match m.get("t"):
		"join":
			_join(c, m)
		"answer":
			_answer(c, m)
		"steal":
			_steal(c, m)
		"cat":
			_cat(c, m)
		"order":
			_order(c, m)
		"throw":
			_throw(c, m)


func _join(c: Dictionary, m: Dictionary) -> void:
	if c.slot >= 0:
		return
	var code = m.get("code")
	var name = m.get("name", "")
	var av = m.get("avatar", "")
	var tok = m.get("token", "")
	if not (code is String and name is String and av is String and tok is String):
		return
	if code.to_upper() != codice:
		_reject(c, "codice")
		return
	if tok != "":
		for s in _players:
			var p: Dictionary = _players[s]
			if p.token == tok:
				if p.conn != null and p.conn != c:
					p.conn.slot = -1
					p.conn.ws.close()
				p.conn = c
				p.disc = 0
				c.slot = s
				_entrato(c)
				return
	if not _aperta:
		_reject(c, "partita")
		return
	if not PERSONAGGI.has(av):
		return
	if av in _presi():
		_reject(c, "preso")
		return
	var slot := -1
	for s in SLOTS:
		if not _players.has(s) and not _bot.has(s):
			slot = s
			break
	if slot < 0:
		_reject(c, "pieno")
		return
	var nome := _pulisci(name)
	if nome == "":
		nome = PERSONAGGI[av].nome
	_players[slot] = {"nome": nome, "avatar": av, "token": Crypto.new().generate_random_bytes(8).hex_encode(), "conn": c, "disc": 0}
	c.slot = slot
	joined.emit(slot, nome, av)
	_entrato(c)
	_tutti(_msg_lobby())


func _entrato(c: Dictionary) -> void:
	var p: Dictionary = _players[c.slot]
	_send(c, {"t": "welcome", "slot": c.slot, "token": p.token, "name": p.nome, "avatar": p.avatar, "color": PERSONAGGI[p.avatar].colore})
	_send(c, _msg_lobby())
	if not _state.is_empty():
		_send(c, _msg_state(c.slot))


func _answer(c: Dictionary, m: Dictionary) -> void:
	if c.slot < 0 or _state.get("fase") != "domanda":
		return
	var q = m.get("q")
	var ch = m.get("choice")
	if not (_es_int(q) and _es_int(ch)) or int(ch) < 0 or int(ch) > 3:
		return
	if not _es_int(_state.get("q")) or int(q) != int(_state.get("q")):
		return
	var r = _risposte.get(c.slot)
	if r != null and r.q == int(q):
		return
	_risposte[c.slot] = {"q": int(q), "choice": int(ch)}
	answered.emit(c.slot, int(q), int(ch))


func _steal(c: Dictionary, m: Dictionary) -> void:
	if c.slot < 0 or _state.get("fase") != "ruba":
		return
	var q = m.get("q")
	var v = m.get("victim")
	if not (_es_int(q) and _es_int(v)) or not _es_int(_state.get("q")) or int(q) != int(_state.get("q")):
		return
	if int(v) == c.slot or _rubato.get(c.slot, -1) == int(q):
		return
	var ok := false
	var vit = _state.get("vittime")
	if vit is Array:
		for x in vit:
			if x is Dictionary and _es_int(x.get("slot")) and int(x.get("slot")) == int(v):
				ok = true
	if not ok:
		return
	_rubato[c.slot] = int(q)
	stole.emit(c.slot, int(q), int(v))


func _cat(c: Dictionary, m: Dictionary) -> void:
	if c.slot < 0 or _state.get("fase") != "categoria":
		return
	var r = m.get("r")
	var sc = m.get("scelta")
	if not (_es_int(r) and _es_int(sc)) or int(sc) < 0 or int(sc) > 2:
		return
	if not _es_int(_state.get("r")) or int(r) != int(_state.get("r")):
		return
	var puo = _state.get("puo")
	if not (puo is Array and c.slot in puo) or _scelto.get(c.slot, -1) == int(r):
		return
	_scelto[c.slot] = int(r)
	categoria_scelta.emit(c.slot, int(r), int(sc))


func _order(c: Dictionary, m: Dictionary) -> void:
	if c.slot < 0 or _state.get("fase") != "domanda" or _state.get("gioco") != "ordine":
		return
	var q = m.get("q")
	var seq = m.get("seq")
	if not _es_int(q) or not seq is Array or seq.size() != 4:
		return
	if not _es_int(_state.get("q")) or int(q) != int(_state.get("q")):
		return
	var s: Array = []
	for x in seq:
		if not _es_int(x) or int(x) < 0 or int(x) > 3 or int(x) in s:
			return
		s.append(int(x))
	var r = _ordinato.get(c.slot)
	if r != null and r.q == int(q):
		return
	_ordinato[c.slot] = {"q": int(q), "seq": s}
	ordered.emit(c.slot, int(q), s)


func _throw(c: Dictionary, m: Dictionary) -> void:
	if c.slot < 0 or _state.get("fase") != "torta":
		return
	var q = m.get("q")
	if not _es_int(q) or not _es_int(_state.get("q")) or int(q) != int(_state.get("q")):
		return
	if not _es_int(_state.get("chi")) or int(_state.get("chi")) != c.slot or _lanciato.get(c.slot, -1) == int(q):
		return
	_lanciato[c.slot] = int(q)
	thrown.emit(c.slot, int(q))


func _es_int(v) -> bool:
	return v is int or (v is float and absf(v) < 1e9 and v == floorf(v))


func _pulisci(s: String) -> String:
	var o := ""
	for ch in s:
		var u := ch.unicode_at(0)
		if u >= 32 and not (u >= 127 and u <= 159):
			o += ch
	return o.strip_edges().substr(0, 12).strip_edges()


func _presi() -> Array:
	var a: Array = _bot.values()
	for s in _players:
		a.append(_players[s].avatar)
	return a


func _msg_lobby() -> Dictionary:
	return {"t": "lobby", "presi": _presi()}


func _msg_state(slot: int) -> Dictionary:
	var d := _state.duplicate()
	if d.has("tempo"):
		d["tempo"] = maxf(0.0, float(d["tempo"]) - (Time.get_ticks_msec() - _t_stato) / 1000.0)
	if d.get("fase") == "domanda":
		var r = _risposte.get(slot)
		d["scelta"] = r.choice if r != null and r.q == int(d.get("q", -1)) else -1
		if d.get("gioco") == "ordine":
			var o = _ordinato.get(slot)
			d["scelta"] = o.seq if o != null and o.q == int(d.get("q", -1)) else []
	if d.get("fase") == "ruba":
		var puo = d.get("puo", [])
		d["puo"] = puo is Array and slot in puo and _rubato.get(slot, -1) != int(d.get("q", -1))
	if d.get("fase") == "torta":
		d["puo"] = _es_int(d.get("chi")) and int(d.get("chi")) == slot and _lanciato.get(slot, -1) != int(d.get("q", -1))
	if d.get("fase") == "categoria":
		var puo = d.get("puo", [])
		d["puo"] = puo is Array and slot in puo and _scelto.get(slot, -1) != int(d.get("r", -1))
	return d


func _reject(c: Dictionary, motivo: String) -> void:
	_send(c, {"t": "reject", "reason": motivo})


func _send(c: Dictionary, d: Dictionary) -> void:
	if c.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		c.ws.send_text(JSON.stringify(d))


func _tutti(d: Dictionary) -> void:
	for c in _conns:
		_send(c, d)
