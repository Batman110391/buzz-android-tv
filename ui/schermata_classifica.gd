class_name SchermataClassifica
extends Control
## Intermezzo: classifica con barre orizzontali; le barre crescono ai punti nuovi e le righe si riordinano.

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GOLD := Color("FFC83D")
const X0 := 600.0
const LARG := 1100.0
const RIGA_H := 100.0
const Y0 := 190.0

var _titolo: Label
var _righe: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titolo = Risposta.etichetta("Classifica", Risposta.font_display(), 90, GOLD, 1920, 120)
	_titolo.add_theme_color_override("font_outline_color", INK)
	_titolo.add_theme_constant_override("outline_size", 16)
	_titolo.position = Vector2(0, 30)
	add_child(_titolo)


func mostra(prima: Array, dopo: Array) -> void:
	for r in _righe:
		r["nodo"].queue_free()
	_righe.clear()
	var massimo := 1
	var pos_dopo := {}
	var val_dopo := {}
	for i in dopo.size():
		massimo = maxi(massimo, dopo[i]["punti"])
		pos_dopo[dopo[i]["pid"]] = i
		val_dopo[dopo[i]["pid"]] = dopo[i]["punti"]
	for i in prima.size():
		var d: Dictionary = prima[i]
		var n := Control.new()
		n.size = Vector2(1920, 80)
		add_child(n)
		var nome := Risposta.etichetta(d["nome"], Risposta.font_display(), 40, CREAM, 360, 80, HORIZONTAL_ALIGNMENT_RIGHT)
		nome.add_theme_color_override("font_outline_color", INK)
		nome.add_theme_constant_override("outline_size", 10)
		nome.position = Vector2(X0 - 380, 0)
		n.add_child(nome)
		var pan := Panel.new()
		pan.add_theme_stylebox_override("panel", Risposta.box(Color("2A1560"), INK, 6, 6, 40))
		pan.size = Vector2(LARG, 80)
		pan.position = Vector2(X0, 0)
		n.add_child(pan)
		var barra := Panel.new()
		barra.add_theme_stylebox_override("panel", Risposta.box(d["colore"], INK, 6, 10, 40))
		barra.size = Vector2(80, 80)
		barra.position = Vector2(X0, 0)
		n.add_child(barra)
		var pers := Personaggio.new()
		pers.setup(d["personaggio"])
		var sc := 80.0 / pers.tela.y
		pers.scale = Vector2(sc, sc)
		var lnome := Risposta.font_display().get_string_size(d["nome"], HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		pers.position = Vector2(X0 - 20 - lnome - 16 - pers.tela.x * sc, 0)
		n.add_child(pers)
		var val := Risposta.etichetta(str(d["punti"]), Risposta.font_display(), 44, INK, 140, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		n.add_child(val)
		var badge := Risposta.etichetta("", Risposta.font_display(), 56, GOLD, 100, 70)
		badge.add_theme_color_override("font_outline_color", INK)
		badge.add_theme_constant_override("outline_size", 10)
		badge.position = Vector2(X0 + LARG + 20, 5)
		n.add_child(badge)
		_righe.append({"nodo": n, "barra": barra, "val": val, "da": d["punti"], "a": val_dopo.get(d["pid"], d["punti"]), "i": pos_dopo.get(d["pid"], i), "badge": badge, "j": i})
	_aggiorna(0.0, massimo)
	visible = true
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_method(func(k: float) -> void: _aggiorna(k, massimo), 0.0, 1.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_badge)
	for r in _righe:
		r["nodo"].modulate.a = 0.0
		create_tween().tween_property(r["nodo"], "modulate:a", 1.0, 0.3)


func _aggiorna(k: float, massimo: int) -> void:
	for r in _righe:
		var p: float = lerpf(r["da"], r["a"], k)
		var w: float = maxf(80.0, LARG * p / massimo)
		r["barra"].size.x = w
		r["val"].text = str(roundi(p))
		r["val"].position = Vector2(X0 + w - 160, 5)
		r["nodo"].position = Vector2(0, Y0 + lerpf(r["j"], r["i"], k) * RIGA_H)


func _badge() -> void:
	var n := _righe.size()
	for r in _righe:
		var pos: int = r["i"]
		r["badge"].text = "1°" if pos == 0 else ("🐌" if pos == n - 1 else "")


func nascondi() -> void:
	var tw := create_tween().set_parallel()
	for r in _righe:
		tw.tween_property(r["nodo"], "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void: visible = false)
