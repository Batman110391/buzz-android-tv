extends SceneTree

var presses := 0


func _initialize() -> void:
	var server: Node = load("res://net/server.gd").new()
	root.add_child(server)
	server.button_pressed.connect(func(_id: int) -> void: presses += 1)
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	await _wait(0.3)
	var ws := WebSocketPeer.new()
	ws.connect_to_url("ws://127.0.0.1:8081")
	var t := 0.0
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN and t < 3.0:
		ws.poll()
		await _wait(0.05)
		t += 0.05
	ws.send_text("garbage")
	ws.send_text('{"t":"other"}')
	await _wait(0.5)
	var invalid_ok := presses == 0
	ws.send_text('{"t":"press"}')
	t = 0.0
	while presses == 0 and t < 3.0:
		ws.poll()
		await _wait(0.05)
		t += 0.05
	var press_ok := presses == 1

	var tcp := StreamPeerTCP.new()
	tcp.connect_to_host("127.0.0.1", 8080)
	var resp := ""
	var sent := false
	t = 0.0
	while t < 3.0 and not resp.contains("PREMI"):
		tcp.poll()
		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if not sent:
				tcp.put_data("GET / HTTP/1.1\r\nHost: x\r\n\r\n".to_utf8_buffer())
				sent = true
			var n := tcp.get_available_bytes()
			if n > 0:
				resp += tcp.get_utf8_string(n)
		await _wait(0.05)
		t += 0.05
	var http_ok := resp.contains("PREMI")

	var ok := invalid_ok and press_ok and http_ok
	print("invalid_ignored=%s press=%s http=%s" % [invalid_ok, press_ok, http_ok])
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
