class_name SchermataCategoria
extends Control
## Intermezzo: il fanalino di coda sceglie la categoria del prossimo round (3 carte).

const INK := Color("1B0B3A")
const CREAM := Color("FFF4DC")
const GOLD := Color("FFC83D")
const CARTA := Vector2(440, 440)
const Y_CARTE := 330.0

var _striscia: Panel
var _titolo: Label
var _pers: Personaggio
var _tempo: Label
var _carte: Array[Control] = []


func _ready() -> void:
	visible = false
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_striscia = Panel.new()
	_striscia.size = Vector2(1500, 130)
	_striscia.position = Vector2(210, 50)
	_striscia.pivot_offset = _striscia.size / 2.0
	add_child(_striscia)
	_titolo = Risposta.etichetta("", Risposta.font_display(), 60, INK, 1180, 110)
	_titolo.position = Vector2(290, 10)
	_striscia.add_child(_titolo)
	_tempo = Risposta.etichetta("", Risposta.font_display(), 54, GOLD, 200, 70)
	_tempo.add_theme_color_override("font_outline_color", INK)
	_tempo.add_theme_constant_override("outline_size", 12)
	_tempo.position = Vector2(860, 200)
	add_child(_tempo)


func mostra(chi_nome: String, chi_colore: Color, chi_personaggio: String, opzioni: Array, titolo := "") -> void:
	for c in _carte:
		c.queue_free()
	_carte.clear()
	if _pers:
		_pers.queue_free()
	_striscia.add_theme_stylebox_override("panel", Risposta.box(chi_colore, INK, 8, 14, 40))
	_titolo.text = titolo if titolo != "" else "%s, fanalino di coda: scegli tu!" % chi_nome
	_pers = Personaggio.new()
	_pers.setup(chi_personaggio)
	_pers.scale = Vector2(0.5, 0.5)
	_pers.position = Vector2(30, 130 - _pers.tela.y * 0.5 - 6)
	_striscia.add_child(_pers)
	_pers.stato("attesa")
	_pers.espressione("triste")
	_tempo.text = ""
	var x0 := (1920.0 - 3 * CARTA.x - 2 * 50.0) / 2.0
	for i in opzioni.size():
		var c := _crea_carta(opzioni[i])
		c.position = Vector2(x0 + i * (CARTA.x + 50.0), Y_CARTE)
		add_child(c)
		_carte.append(c)
		c.scale = Vector2.ZERO
		var tw := create_tween()
		tw.tween_interval(0.15 * i)
		tw.tween_property(c, "scale", Vector2(1.1, 1.1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.15)
	_striscia.scale = Vector2.ZERO
	visible = true
	create_tween().tween_property(_striscia, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _crea_carta(o: Dictionary) -> Control:
	var c := Control.new()
	c.size = CARTA
	c.pivot_offset = CARTA / 2.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ombra := Panel.new()
	ombra.add_theme_stylebox_override("panel", Risposta.box(Color("0A0320"), Color("0A0320"), 8, 8, 36))
	ombra.size = CARTA
	ombra.position = Vector2(0, 14)
	c.add_child(ombra)
	var p := Panel.new()
	p.name = "p"
	p.add_theme_stylebox_override("panel", Risposta.box(CREAM, INK, 8, 16, 36))
	p.size = CARTA
	c.add_child(p)
	var ic := Risposta.etichetta(o["icona"], Risposta.font_testo(), 190, INK, CARTA.x, 230)
	ic.position = Vector2(0, 30)
	c.add_child(ic)
	var nome := Risposta.etichetta(o["nome"], Risposta.font_display(), 50, INK, CARTA.x - 40, 130)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.position = Vector2(20, 270)
	c.add_child(nome)
	return c


func set_tempo(left: float, total: float) -> void:
	_tempo.text = str(ceili(left))
	_tempo.add_theme_color_override("font_color", Color("FF3B4E") if left <= total * 0.25 else GOLD)


func scegli(i: int) -> void:
	_tempo.text = ""
	for k in _carte.size():
		var c := _carte[k]
		if k == i:
			create_tween().tween_property(c, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var lamp := create_tween().set_loops(4)
			lamp.tween_property(c.get_node("p"), "modulate", Color(1.5, 1.5, 1.2), 0.1)
			lamp.tween_property(c.get_node("p"), "modulate", Color.WHITE, 0.1)
		else:
			c.get_node("p").add_theme_stylebox_override("panel", Risposta.box(Risposta.DIM_BG, INK, 8, 16, 36))
			var tw := create_tween().set_parallel()
			tw.tween_property(c, "position:y", Y_CARTE + 90, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "modulate", Color(0.7, 0.7, 0.8), 0.3)
			tw.tween_property(c, "scale", Vector2(0.9, 0.9), 0.3)


func nascondi() -> void:
	var tw := create_tween().set_parallel()
	for c in _carte:
		tw.tween_property(c, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_striscia, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tempo.text = ""
	tw.chain().tween_callback(func() -> void: visible = false)
