extends Node

signal button_pressed(player_id: int)

const HTTP_PORT := 8080
const WS_PORT := 8081

var _http := TCPServer.new()
var _ws := TCPServer.new()
var _http_clients: Array[Dictionary] = []  # {peer: StreamPeerTCP, buf: String}
var _ws_peers: Array[Dictionary] = []  # {ws: WebSocketPeer, id: int}
var _next_id := 0


func _ready() -> void:
	_http.listen(HTTP_PORT)
	_ws.listen(WS_PORT)
	print("Controller URL: ", get_lan_url())


func get_lan_url() -> String:
	# 192.168 prima: 10.x e 172.x sono spesso interfacce VPN (es. tun0 sulla Fire TV)
	var addrs := IP.get_local_addresses()
	for prefix in ["192.168.", "10.", "172."]:
		for a in addrs:
			if a.begins_with(prefix) and a.count(".") == 3:
				return "http://%s:%d" % [a, HTTP_PORT]
	return "http://127.0.0.1:%d" % HTTP_PORT


func _process(_delta: float) -> void:
	while _http.is_connection_available():
		_http_clients.append({"peer": _http.take_connection(), "buf": ""})
	for c in _http_clients.duplicate():
		var peer: StreamPeerTCP = c.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_http_clients.erase(c)
			continue
		var n := peer.get_available_bytes()
		if n > 0:
			c.buf += peer.get_utf8_string(n)
		if c.buf.contains("\r\n\r\n"):
			var body := FileAccess.get_file_as_bytes("res://net/controller.html")
			var head := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
			peer.put_data(head.to_utf8_buffer() + body)
			peer.disconnect_from_host()
			_http_clients.erase(c)

	while _ws.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(_ws.take_connection())
		_ws_peers.append({"ws": ws, "id": _next_id})
		_next_id += 1
	for c in _ws_peers.duplicate():
		var ws: WebSocketPeer = c.ws
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while ws.get_available_packet_count() > 0:
					var json := JSON.new()
					if json.parse(ws.get_packet().get_string_from_utf8()) != OK:
						continue
					var msg = json.data
					if msg is Dictionary and msg.get("t") == "press":
						button_pressed.emit(c.id)
			WebSocketPeer.STATE_CLOSED:
				_ws_peers.erase(c)
