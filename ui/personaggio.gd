class_name Personaggio
extends Node2D
# Rig cutout 2D (design Quizzone). Coordinate locali = tela del design, origine in alto a sinistra.
# Animazione procedurale: molle (overshoot), squash & stretch, anticipazione, movimento secondario.

signal finito_parlare

const CONDUTTORI: Array[String] = ["host", "gilda"]
const BASE := "res://assets/personaggi/"
const ESPR: Array[String] = ["neutro", "felice", "triste", "sorpreso", "arrabbiato"]
const BOCCHE: Array[String] = ["socchiusa", "A", "E", "O"]
const GRAVITA := 1700.0
const GAIN_VOLUME := 4.0  # magnitudo dello spettro (100-4000 Hz) -> 0..1
const GESTO_ESPR := {"saluto": "felice", "annuncio": "neutro", "esulta": "felice", "delusione": "triste", "sorpresa": "sorpreso"}
const MOLLE := {  # nome: [frequenza Hz, smorzamento]
	"body_x": [6.0, 0.5], "body_rot": [5.0, 0.35], "sx": [7.0, 0.3], "sy": [7.0, 0.3],
	"head_rot": [5.5, 0.4], "head_x": [6.0, 0.5], "head_y": [6.0, 0.4], "head_lag": [4.0, 0.3], "head_s": [7.0, 0.5],
	"brow": [9.0, 0.5], "eyes_s": [9.0, 0.45], "eye_x": [12.0, 0.8], "eye_y": [12.0, 0.8],
	"arm": [8.0, 0.35], "hair": [3.5, 0.2], "sopra": [4.0, 0.22], "dietro": [3.0, 0.25],
}

class Molla:
	var x := 0.0
	var v := 0.0
	var f := 6.0
	var z := 0.5
	func _init(freq: float, smorz: float) -> void:
		f = freq
		z = smorz
	func passo(target: float, dt: float) -> void:
		var w := TAU * f
		var n := ceili(dt * 120.0)
		var h := dt / n
		for i in n:
			v += (w * w * (target - x) - 2.0 * z * w * v) * h
			x += v * h

var id := ""
var tela := Vector2(200, 200)
var _s := 2.0
var _pezzi: Dictionary
var _rig: Dictionary
var _pc: Vector2  # perno del corpo (centro-basso della tela)
var _ptesta: Vector2
var _corpo: Node2D
var _testa: Node2D
var _dietro: Node2D
var _occhi: Node2D
var _sopr: Node2D
var _bocca: Node2D
var _capelli: Node2D
var _sopra: Node2D
var _braccio: Node2D
var _pos_occhi: Vector2
var _spr_occhi := {}
var _spr_sopr := {}
var _spr_bocca := {}
var _molle := {}
var _tg := {}
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _per := 1.7
var _fase := 0.0
var _ampl_respiro := 0.03

var _stato := "attesa"
var _espr := "neutro"
var _bocca_cur := ""
var _override := false
var _hold := 0.0
var _timer_stato := 0.0
# salto
var _y := 0.0
var _vy := 0.0
var _salto_fase := 0  # 0 a terra, 1 anticipazione, 2 in aria
var _salto_h := 30.0
var _salto_ant := 0.0
var _salta_fino := 0.0
# gesto
var _g := ""
var _g_t0 := 0.0
var _g_dur := 1.2
# sguardi / ciglia
var _look_t := 2.0
var _look_hold := 0.0
var _look := Vector3.ZERO  # rotazione testa, x testa, x occhi
var _look_tilt := 0.0
var _blink_t := 2.0
# voce
var _player: AudioStreamPlayer
var _an: AudioEffectSpectrumAnalyzerInstance
var _parlando := false
var _vol := 0.0


func setup(p_id: String) -> void:
	id = p_id
	_rng.randomize()
	_rig = JSON.parse_string(FileAccess.get_file_as_string(BASE + "rig.json"))[id]
	_pezzi = JSON.parse_string(FileAccess.get_file_as_string(BASE + id + "/pezzi.json"))
	_s = _pezzi["scala"]
	tela = Vector2(_rig["tela"][0], _rig["tela"][1])
	_pc = Vector2(tela.x / 2.0, tela.y)
	var perni: Dictionary = _rig["perni"]
	_ptesta = _v2(perni["testa"])
	_per = _rng.randf_range(1.6, 1.8)
	_fase = _rng.randf() * TAU
	_ampl_respiro = 0.018 if id in CONDUTTORI else 0.03
	_look_t = _rng.randf_range(0.5, 3.0)
	_blink_t = _rng.randf_range(0.5, 3.0)
	for k: String in MOLLE:
		_molle[k] = Molla.new(MOLLE[k][0], MOLLE[k][1])
		_tg[k] = 0.0
	_molle["sx"].x = 1.0
	_molle["sy"].x = 1.0
	_molle["head_s"].x = 1.0
	_molle["eyes_s"].x = 1.0

	_corpo = _nodo(self, _pc, Vector2.ZERO)
	var figli: Array = _rig["figli_di_testa"]
	if figli.has("dietro"):
		_dietro = _nodo(_corpo, _ptesta, _pc)
		_sprite(_dietro, "dietro", _ptesta)
	_sprite(_corpo, "corpo", _pc)
	_testa = _nodo(_corpo, _ptesta, _pc)
	for p: String in figli:
		match p:
			"testa", "baffi":
				_sprite(_testa, p, _ptesta)
			"occhi":
				_pos_occhi = _v2(perni["occhi"]) if perni.has("occhi") else _centro("occhi_neutro")
				_occhi = _nodo(_testa, _pos_occhi, _ptesta)
				for e in ESPR:
					_spr_occhi[e] = _sprite(_occhi, "occhi_" + e, _pos_occhi)
			"sopracciglia":
				_sopr = _nodo(_testa, _ptesta, _ptesta)
				for e in ESPR:
					_spr_sopr[e] = _sprite(_sopr, "sopracciglia_" + e, _ptesta)
			"bocca":
				_bocca = _nodo(_testa, _ptesta, _ptesta)
				for e in ESPR + BOCCHE:
					_spr_bocca[e] = _sprite(_bocca, "bocca_" + e, _ptesta)
			"capelli":
				_capelli = _nodo(_testa, _v2(perni["capelli"]), _ptesta)
				_sprite(_capelli, "capelli", _v2(perni["capelli"]))
			"sopra":
				var r := _rect("sopra")
				var perno := Vector2(r.position.x + r.size.x / 2.0, r.end.y)
				_sopra = _nodo(_testa, perno, _ptesta)
				_sprite(_sopra, "sopra", perno)
	if perni.has("braccio"):
		_braccio = _nodo(_corpo, _v2(perni["braccio"]), _pc)
		_sprite(_braccio, "braccio", _v2(perni["braccio"]))
	espressione("neutro")


func espressione(e: String) -> void:
	_espr = e
	for k: String in _spr_occhi:
		(_spr_occhi[k] as Sprite2D).visible = k == e
		(_spr_sopr[k] as Sprite2D).visible = k == e
	if not _parlando:
		_set_bocca(e)


func stato(s: String) -> void:
	_stato = s
	_timer_stato = 0.0
	_salta_fino = 0.0
	if not _g.is_empty() and s != "attesa":
		_g = ""
	var e := _espr_base()
	match s:
		"risposto":
			_salta(26.0)
			_timer_stato = 1.0
		"esulta":
			_salta_fino = INF
			_salta(34.0)
		"sorpreso":
			(_molle["body_rot"] as Molla).x = 16.0
			_salta(10.0)
		"sconfitta":
			(_molle["head_rot"] as Molla).v = 40.0
			(_molle["sy"] as Molla).x = 1.1
	if s != "attesa" or not (_parlando or _hold > 0.0):
		_override = false
		espressione(e)


func gesto(g: String, durata := 1.4) -> void:
	_g = g
	_g_t0 = _t
	_g_dur = maxf(durata, 1.0)
	_override = true
	_hold = _g_dur + 0.5 + 1.8
	espressione(GESTO_ESPR.get(g, "neutro"))
	match g:
		"esulta":
			_salta_fino = _t + _g_dur
			_salta(30.0)
		"sorpresa":
			_salta(10.0)


func parla(stream: AudioStream) -> void:
	_assicura_bus()
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.bus = "Voce"
		_player.finished.connect(_fine_parla)
		add_child(_player)
	var bus := AudioServer.get_bus_index("Voce")
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectSpectrumAnalyzer:
			_an = AudioServer.get_bus_effect_instance(bus, i) as AudioEffectSpectrumAnalyzerInstance
	_player.stream = stream
	_player.play()
	_parlando = true


func _exit_tree() -> void:
	if _player:
		_player.stop()
		_player.stream = null


func _fine_parla() -> void:
	_parlando = false
	_vol = 0.0
	_hold = 1.8
	_set_bocca(_espr)
	finito_parlare.emit()


static func _assicura_bus() -> void:
	var bus := AudioServer.get_bus_index("Voce")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Voce")
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectSpectrumAnalyzer:
			return
	var e := AudioEffectSpectrumAnalyzer.new()
	e.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	e.buffer_length = 0.1
	AudioServer.add_bus_effect(bus, e)


# ---------- costruzione ----------
func _v2(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


func _rect(nome: String) -> Rect2:
	var tex := load("%s%s/%s.png" % [BASE, id, nome]) as Texture2D
	return Rect2(_v2(_pezzi["pezzi"][nome]), tex.get_size() / _s)


func _centro(nome: String) -> Vector2:
	var r := _rect(nome)
	return r.position + r.size / 2.0


func _nodo(parent: Node2D, pivot: Vector2, origine_parent: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pivot - origine_parent
	parent.add_child(n)
	return n


func _sprite(parent: Node2D, nome: String, origine: Vector2) -> Sprite2D:
	if not _pezzi["pezzi"].has(nome):
		return null
	var sp := Sprite2D.new()
	sp.texture = load("%s%s/%s.png" % [BASE, id, nome])
	sp.centered = false
	sp.scale = Vector2.ONE / _s
	sp.position = _v2(_pezzi["pezzi"][nome]) - origine
	parent.add_child(sp)
	return sp


func _set_bocca(nome: String) -> void:
	if nome == _bocca_cur or _spr_bocca.is_empty():
		return
	_bocca_cur = nome
	for k: String in _spr_bocca:
		(_spr_bocca[k] as Sprite2D).visible = k == nome


func _espr_base() -> String:
	match _stato:
		"risposto", "esulta":
			return "felice"
		"sconfitta":
			return "triste"
		"sorpreso":
			return "sorpreso"
	return "neutro"


# ---------- salto con anticipazione, stretch, squash all'atterraggio ----------
func _salta(h: float) -> void:
	if _salto_fase != 0:
		return
	_salto_h = h
	_salto_fase = 1
	_salto_ant = 0.11


func _passo_salto(dt: float) -> void:
	var v0 := sqrt(2.0 * GRAVITA * _salto_h)
	match _salto_fase:
		1:
			_tg["sx"] = 1.14
			_tg["sy"] = 0.82
			_salto_ant -= dt
			if _salto_ant <= 0.0:
				_salto_fase = 2
				_vy = -v0
				(_molle["sx"] as Molla).x = 0.88
				(_molle["sy"] as Molla).x = 1.2
		2:
			_vy += GRAVITA * dt
			_y += _vy * dt
			var k := absf(_vy) / v0
			_tg["sx"] = 1.0 - 0.1 * k
			_tg["sy"] = 1.0 + 0.16 * k
			if _y >= 0.0:
				_y = 0.0
				_vy = 0.0
				_salto_fase = 0
				var sx := _molle["sx"] as Molla
				var sy := _molle["sy"] as Molla
				sx.x = 1.22
				sx.v = 0.0
				sy.x = 0.78
				sy.v = 0.0
				if _t < _salta_fino:
					_salto_fase = 1
					_salto_ant = 0.06
					_salto_h = _rng.randf_range(0.85, 1.1) * _salto_h


# ---------- ciclo ----------
func _process(dt: float) -> void:
	if _corpo == null:
		return
	var n := ceili(dt / 0.034)
	for i in n:
		_passo(dt / n)
	_applica()


func _passo(dt: float) -> void:
	_t += dt
	for k: String in _tg:
		_tg[k] = 1.0 if k in ["sx", "sy", "head_s", "eyes_s"] else 0.0
	var peso_look := 1.0 if _stato == "attesa" else 0.35 if _stato == "pensa" else 0.0
	var f := _fase

	# stato
	match _stato:
		"pensa":
			_tg["head_rot"] = 9.0 + 2.0 * sin(_t * 1.1 + f)
			_tg["head_x"] = 3.0
			_tg["brow"] = -3.5 + 3.5 * sin(_t * 2.3 + f)
			_tg["eye_x"] = 3.0
			_tg["eye_y"] = -2.0
			_tg["body_rot"] = 1.8 * sin(_t * 1.4 + f)
		"sconfitta":
			_tg["head_rot"] = 10.0
			_tg["head_y"] = 12.0
			_tg["brow"] = 3.0
			_tg["sy"] = 0.94
			_tg["sx"] = 1.04
			_tg["arm"] = 12.0
			_tg["body_x"] = 1.3 * sin(_t * 34.0) * (0.5 + 0.5 * sin(_t * 1.7 + f))
		"sorpreso":
			_tg["eyes_s"] = 1.22
			_tg["brow"] = -9.0
			_tg["body_rot"] = 5.0
			_tg["body_x"] = 4.0
			_tg["head_s"] = 1.04
		"esulta":
			_tg["arm"] = -32.0
			_tg["brow"] = -5.0
		"risposto":
			_tg["brow"] = -4.0
	if _stato == "risposto":
		_timer_stato -= dt
		if _timer_stato <= 0.0:
			stato("attesa")
	_passo_salto(dt)

	# gesto (host): peso con anticipazione + rampa
	if not _g.is_empty():
		var p := _t - _g_t0
		var d := _g_dur
		var ant := -0.3 * sin(PI * clampf(p / 0.2, 0.0, 1.0))
		var w := ant + (smoothstep(0.1, 0.35, p) if p < d else maxf(0.0, 1.0 - (p - d) / 0.5))
		if p > d + 0.5:
			_g = ""
		match _g:
			"saluto":
				_tg["arm"] += w * (-28.0 + 14.0 * sin(p * 11.0))
				_tg["head_rot"] += -4.0 * w
			"annuncio":
				_tg["head_s"] += 0.05 * w
				_tg["head_rot"] += -5.0 * w
				_tg["arm"] += -12.0 * w
			"esulta":
				_tg["arm"] += -32.0 * w
				_tg["brow"] += -6.0 * w
			"delusione":
				_tg["head_rot"] += 7.0 * w
				_tg["head_y"] += 10.0 * w
				_tg["brow"] += 4.0 * w
				_tg["arm"] += 12.0 * w
				_tg["sy"] -= 0.04 * w
			"sorpresa":
				_tg["eyes_s"] += 0.25 * w
				_tg["brow"] += -12.0 * w
				_tg["arm"] += -8.0 * w
				_tg["body_rot"] += 6.0 * w

	# sguardi e inclinazioni casuali
	if _look_hold > 0.0:
		_look_hold -= dt
		_tg["head_rot"] += (_look.x + _look_tilt) * peso_look
		_tg["head_x"] += _look.y * peso_look
		_tg["eye_x"] += _look.z * peso_look
		if _look_hold <= 0.0:
			_look = Vector3.ZERO
			_look_tilt = 0.0
			_look_t = _rng.randf_range(1.2, 4.0)
	else:
		_look_t -= dt
		if _look_t <= 0.0:
			var sg := 1.0 if _rng.randf() < 0.5 else -1.0
			_look_hold = _rng.randf_range(0.8, 1.8)
			match _rng.randi() % 3:
				0:
					_look = Vector3(4.0 * sg, 3.0 * sg, 3.0 * sg)
				1:
					_look_tilt = 9.0 * sg
				2:
					_look = Vector3(-3.0 * sg, 2.0 * sg, 3.0 * sg)
					_look_tilt = 5.0 * sg

	# voce: volume e bocca
	var vol_t := 0.0
	var ricalco := 1.0 - exp(-dt * 18.0)
	if _parlando and _an != null:
		var m := _an.get_magnitude_for_frequency_range(100.0, 4000.0).length()
		vol_t = clampf(m * GAIN_VOLUME, 0.0, 1.0)
		_vol += (vol_t - _vol) * ricalco
		var b := "neutro"
		if _vol >= 0.4:
			b = "A"
		elif _vol >= 0.18:
			var lo := _an.get_magnitude_for_frequency_range(100.0, 700.0).length()
			var hi := _an.get_magnitude_for_frequency_range(1200.0, 4000.0).length()
			b = "E" if hi > lo * 0.5 else "O"
		elif _vol >= 0.06:
			b = "socchiusa"
		_set_bocca(b)
	else:
		_vol += (0.0 - _vol) * ricalco
	_tg["head_rot"] += 3.0 * _vol * sin(_t * 9.0)
	_tg["head_y"] += -4.0 * _vol
	_tg["brow"] += -3.0 * _vol

	# espressione tenuta dopo la battuta / il gesto
	if not _parlando and _override:
		_hold -= dt
		if _hold <= 0.0:
			_override = false
			espressione(_espr_base())

	# la testa segue il corpo con ritardo nei salti
	_tg["head_lag"] = -_vy * 0.025

	for k: String in _molle:
		(_molle[k] as Molla).passo(_tg[k], dt)
	# movimento secondario: capelli / cappello / dietro seguono la testa in ritardo
	var hr := (_molle["head_rot"] as Molla).x
	(_molle["hair"] as Molla).passo(-hr * 0.6 + 1.5 * sin(_t * 1.3 - 0.6 + f), dt)
	(_molle["sopra"] as Molla).passo(-hr * 0.5 + (_molle["head_lag"] as Molla).x * 0.5, dt)
	(_molle["dietro"] as Molla).passo(-hr * 0.35, dt)

	# ciglia
	if _t >= _blink_t + 0.14:
		_blink_t = _t + (0.2 if _rng.randf() < 0.18 else _rng.randf_range(2.4, 4.6))


func _m(k: String) -> float:
	return (_molle[k] as Molla).x


func _applica() -> void:
	var resp := sin(TAU * _t / _per + _fase)
	_corpo.position = _pc + Vector2(_m("body_x"), _y)
	_corpo.rotation_degrees = _m("body_rot")
	_corpo.scale = Vector2(_m("sx") * (1.0 - 0.4 * _ampl_respiro * resp), _m("sy") * (1.0 + _ampl_respiro * resp))
	_testa.position = _ptesta - _pc + Vector2(_m("head_x"), _m("head_y") + _m("head_lag") - resp)
	_testa.rotation_degrees = _m("head_rot")
	_testa.scale = Vector2.ONE * _m("head_s")
	if _dietro:
		_dietro.position = _testa.position
		_dietro.rotation_degrees = _m("head_rot") + _m("dietro")
		_dietro.scale = _testa.scale
	if _capelli:
		_capelli.rotation_degrees = _m("hair")
	if _sopra:
		_sopra.rotation_degrees = _m("sopra")
	if _braccio:
		_braccio.rotation_degrees = _m("arm")
	var u := (_t - _blink_t) / 0.14
	var blink := 1.0 - 0.9 * sin(PI * u) if u >= 0.0 and u <= 1.0 else 1.0
	_occhi.position = _pos_occhi - _ptesta + Vector2(_m("eye_x"), _m("eye_y"))
	_occhi.scale = Vector2(_m("eyes_s"), _m("eyes_s") * blink)
	_sopr.position = Vector2(0, _m("brow"))
