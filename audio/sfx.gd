extends Node
## Autoload "Sfx": effetti (pool), musica con dissolvenza, ducking.

const SFX := ["buzz", "correct", "wrong", "tick", "tick_fast", "whoosh", "pop", "applause", "aww", "drumroll", "fanfare", "explosion", "cash", "boing", "lock", "rise"]
const VARIANTI := {"applause": 2, "aww": 2}  # effetti con più versioni (nome.ogg, nome_2.ogg…): si alternano
const MUSIC := ["menu", "question", "scores", "final"]
const POOL := 8
const SILENT := -60.0

var _pool: Array[AudioStreamPlayer] = []
var _mus: Array[AudioStreamPlayer] = []
var _cur := -1  # indice del player musicale attivo
var _duck_db := 0.0
var _volta := {}  # effetto -> prossima versione da suonare


func _ready() -> void:
	for i in POOL:
		_pool.append(_new_player())
	for i in 2:
		var p := _new_player()
		p.volume_db = SILENT
		_mus.append(p)


func _new_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


func play(sound: String, vol_db := 0.0) -> void:
	if not SFX.has(sound):
		push_warning("Sfx.play: effetto sconosciuto '%s'" % sound)
		return
	var f := sound
	if VARIANTI.has(sound):
		var i: int = _volta.get(sound, 0)
		_volta[sound] = (i + 1) % VARIANTI[sound]
		if i > 0:
			f = "%s_%d" % [sound, i + 1]
	var s := load("res://assets/audio/sfx/%s.ogg" % f) as AudioStream
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[0]
	for q in _pool:
		if not q.playing:
			p = q
			break
	p.stream = s
	p.volume_db = vol_db
	p.play()


func music(sound: String) -> void:
	if not MUSIC.has(sound):
		push_warning("Sfx.music: musica sconosciuta '%s'" % sound)
		return
	var s := load("res://assets/audio/music/%s.ogg" % sound) as AudioStreamOggVorbis
	if s == null:
		return
	if _cur >= 0 and _mus[_cur].playing and _mus[_cur].stream == s:
		return
	s.loop = true
	var old := _cur
	_cur = 1 - old if old >= 0 else 0
	var np := _mus[_cur]
	np.stream = s
	np.volume_db = SILENT
	np.play()
	_fade(np, _duck_db, 1.0)
	if old >= 0:
		_fade(_mus[old], SILENT, 1.0, true)


func stop_music() -> void:
	for p in _mus:
		if p.playing:
			_fade(p, SILENT, 1.0, true)
	_cur = -1


func duck(on: bool) -> void:
	_duck_db = -12.0 if on else 0.0
	if _cur >= 0:
		_fade(_mus[_cur], _duck_db, 0.3)


func _fade(p: AudioStreamPlayer, db: float, t: float, stop_after := false) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, t)
	if stop_after:
		tw.tween_callback(p.stop)
