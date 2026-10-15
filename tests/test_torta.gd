extends Node2D
## Cattura: 6 podi, il podio 1 è il lanciatore; mirino che salta (~2 s), lancio, splat, icone torte. Poi quit.

const GIOCATORI := [
	["Gastone", "F2384A"], ["Nonna Pina", "2F7BFF"], ["Ugo", "33C759"],
	["Brioche", "FFD43B"], ["Don Ciccio", "A855F7"], ["Vanessa", "FF8A1F"],
]

## Segnaposto: cerchio colorato con l'iniziale.
class Segnaposto extends Node2D:
	var col := Color.WHITE
	var iniz := ""

	func _draw() -> void:
		draw_circle(Vector2(100, 110), 80, Color("1B0B3A"))
		draw_circle(Vector2(100, 110), 72, col)
		draw_string(Risposta.font_display(), Vector2(0, 110 + 36), iniz, HORIZONTAL_ALIGNMENT_CENTER, 200, 100, Color("1B0B3A"))

var _s: SchermataDomanda
var _torta: TortaUI
var _t := 0.0
var _passo := 0
var _bersaglio := 0
var _pos: Array[Vector2] = []
var _idx: Array[int] = []  # indice podio per ogni posizione del mirino


func _ready() -> void:
	add_child(Palco.new())
	_s = SchermataDomanda.new()
	add_child(_s)
	var g: Array = []
	for d in GIOCATORI:
		g.append({"nome": d[0], "colore": Color(d[1]), "punti": 1250})
	_s.setup_podi(g)
	for i in GIOCATORI.size():
		var sp := Segnaposto.new()
		sp.col = Color(GIOCATORI[i][1])
		sp.iniz = GIOCATORI[i][0][0]
		_s.podio(i).metti_personaggio(sp)
	_s.mostra_domanda(3, 10, "TORTA IN FACCIA", "Quale di questi formaggi si fa con il latte di bufala?", ["Parmigiano", "Mozzarella campana", "Gorgonzola", "Asiago"])
	_s.podio(0).set_stato("ok")
	_s.podio(1).set_torte(1)
	_s.podio(2).set_torte(3)
	_s.podio(3).set_torte(5)
	for i in range(1, 6):
		_pos.append(_s.podio(i).position + Vector2(120, 110))
		_idx.append(i)
	_torta = TortaUI.new()
	add_child(_torta)
	_torta.colpito.connect(func() -> void: _s.podio(_idx[_bersaglio]).splat())
	_torta.mira(_pos)


func _process(dt: float) -> void:
	_t += dt
	if _passo == 0 and _t >= 2.0:
		_passo = 1
		_bersaglio = _torta.ferma()
	elif _passo == 1 and _t >= 2.6:
		_passo = 2
		_torta.lancia(_s.podio(0).position + Vector2(120, 100), _pos[_bersaglio])
	elif _passo == 2 and _t >= 3.5:
		_passo = 3  # splat in corso
	elif _passo == 3 and _t >= 6.0:
		get_tree().quit()
