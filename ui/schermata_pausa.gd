class_name SchermataPausa extends CanvasLayer
## Pausa in partita: il resto dell'albero è fermo (get_tree().paused), qui l'input continua.
## ↑/↓ sceglie, OK conferma ed emette `scelto` (true = esci al titolo).

signal scelto(esci: bool)

const GOLD := Color("FFC83D")

var _voci: Array[Label] = []
var _sel := 0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var velo := ColorRect.new()
	velo.color = Color(Risposta.INK, 0.75)
	velo.size = Vector2(1920, 1080)
	add_child(velo)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Risposta.box(Risposta.INK, Color("FF3DA8"), 10, 10, 40))
	card.size = Vector2(900, 600)
	card.position = Vector2(510, 240)
	add_child(card)
	var t := Risposta.etichetta("PAUSA", Risposta.font_display(), 136, GOLD, 900, 200)
	t.add_theme_color_override("font_outline_color", Color("0A0320"))
	t.add_theme_constant_override("outline_size", 16)
	card.add_child(t)
	for i in 2:
		var l := Risposta.etichetta(["Riprendi", "Esci al titolo"][i], Risposta.font_testo(), 56, Risposta.CREAM, 640, 110)
		l.position = Vector2(130, 240 + i * 150)
		card.add_child(l)
		_voci.append(l)


func mostra() -> void:
	_sel = 0
	_aggiorna()
	visible = true


func _aggiorna() -> void:
	for i in 2:
		var su := i == _sel
		_voci[i].add_theme_stylebox_override("normal", Risposta.box(GOLD if su else Risposta.INK, Risposta.CREAM if su else Color("4B1FA8"), 6, 6, 30))
		_voci[i].add_theme_color_override("font_color", Risposta.INK if su else Risposta.CREAM)


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down"):
		_sel = 1 - _sel
		_aggiorna()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()  # l'OK che chiude la pausa non arriva a main (prima: uscendo la scena si scarica)
		visible = false
		scelto.emit(_sel == 1)
