class_name SchermataRound
extends Node2D

const GOLD := Color("FFC83D")
const MAGENTA := Color("FF3DA8")

var _carta: Node2D
var _pill: Label
var _icona: Label
var _titolo: Label
var _regola: Label


func _ready() -> void:
	visible = false
	_carta = Node2D.new()
	_carta.position = Vector2(960, 540)
	_carta.rotation = deg_to_rad(-2)
	add_child(_carta)
	var ombra := Panel.new()
	ombra.add_theme_stylebox_override("panel", Risposta.box(Color("0A0320"), Color("0A0320"), 10, 10, 40))
	ombra.size = Vector2(1240, 640)
	ombra.position = Vector2(-620, -320 + 14)
	_carta.add_child(ombra)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Risposta.box(Risposta.INK, MAGENTA, 10, 10, 40))
	card.size = Vector2(1240, 640)
	card.position = Vector2(-620, -320)
	_carta.add_child(card)
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", Risposta.box(GOLD, Risposta.INK, 6, 6, 30))
	pill.size = Vector2(380, 64)
	pill.position = Vector2(-190, -320 - 32)
	_carta.add_child(pill)
	_pill = Risposta.etichetta("", Risposta.font_display(), 32, Risposta.INK, 380, 56)
	pill.add_child(_pill)
	_icona = Risposta.etichetta("", Risposta.font_testo(), 120, Risposta.CREAM, 300, 150)
	_icona.position = Vector2(-150, -270)
	_carta.add_child(_icona)
	_titolo = Risposta.etichetta("", Risposta.font_display(), 136, GOLD, 1160, 170)
	_titolo.add_theme_color_override("font_outline_color", Risposta.INK)
	_titolo.add_theme_constant_override("outline_size", 16)
	_titolo.position = Vector2(-580, -90)
	_carta.add_child(_titolo)
	_regola = Risposta.etichetta("", Risposta.font_testo(), 44, Risposta.CREAM, 1040, 140)
	_regola.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_regola.position = Vector2(-520, 100)
	_carta.add_child(_regola)


func mostra(n: int, tot: int, titolo: String, regola: String, icona: String) -> void:
	_pill.text = "SFIDA SPECIALE" if n == 0 else "ROUND %d DI %d" % [n, tot]  # n = 0: Duello degli indizi
	_titolo.text = titolo
	Risposta.adatta(_titolo, 136, 72)
	_regola.text = regola
	Risposta.adatta(_regola, 44)
	_icona.text = icona
	_carta.scale = Vector2.ZERO
	visible = true
	create_tween().tween_property(_carta, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func nascondi() -> void:
	var tw := create_tween()
	tw.tween_property(_carta, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: visible = false)
