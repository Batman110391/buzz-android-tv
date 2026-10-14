extends Node2D
# Prova C2: Tony e Gilda sul palco; Gilda cicla le espressioni, i gesti e parla.

const ESPR: Array[String] = ["neutro", "felice", "triste", "sorpreso", "arrabbiato"]
const GESTI: Array[String] = ["saluto", "annuncio", "esulta"]

var _gilda: Personaggio


func _ready() -> void:
	add_child(Palco.new())
	var tony := Personaggio.new()
	tony.setup("host")
	tony.position = Vector2(380, 400)
	tony.scale = Vector2.ONE * 1.8
	add_child(tony)
	_gilda = Personaggio.new()
	_gilda.setup("gilda")
	_gilda.position = Vector2(1110, 400)
	_gilda.scale = Vector2.ONE * 1.8
	add_child(_gilda)
	for e in ESPR:
		_gilda.espressione(e)
		await get_tree().create_timer(1.0).timeout
	_gilda.espressione("neutro")
	for g in GESTI:
		_gilda.gesto(g, 1.4)
		await get_tree().create_timer(1.6).timeout
	var s := load("res://assets/voice/gilda_prova.mp3") as AudioStream
	_gilda.parla(s)
