extends Node2D
## Prova schermata domanda: 15 s, i 6 rispondono a caso tra 2 e 10 s, poi rivelazione e riparte.

const TOT := 15.0
const GIOCATORI := [
	["Gastone", "F2384A"], ["Nonna Pina", "2F7BFF"], ["Ugo", "33C759"],
	["Brioche", "FFD43B"], ["Don Ciccio", "A855F7"], ["Vanessa", "FF8A1F"],
]

## Segnaposto: cerchio colorato con l'iniziale (arriva poi il vero Personaggio).
class Segnaposto extends Node2D:
	var col := Color.WHITE
	var iniz := ""

	func _draw() -> void:
		draw_circle(Vector2(100, 110), 80, Color("1B0B3A"))
		draw_circle(Vector2(100, 110), 72, col)
		draw_string(Risposta.font_display(), Vector2(0, 110 + 36), iniz, HORIZONTAL_ALIGNMENT_CENTER, 200, 100, Color("1B0B3A"))

var _s: SchermataDomanda
var _t := 0.0
var _fase := 0  # 0 domanda, 1 rivelazione
var _quando: Array[float] = []
var _scelta: Array[int] = []
var _fatto: Array[bool] = []


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
	_inizia()


func _inizia() -> void:
	_fase = 0
	_t = TOT
	_quando.clear()
	_scelta.clear()
	_fatto.clear()
	for i in 6:
		_quando.append(randf_range(2.0, 10.0))
		_scelta.append(randi() % 4)
		_fatto.append(false)
	_s.mostra_domanda(3, 10, "ACCUMULA PUNTI", "Quale di questi formaggi si fa con il latte di bufala?",
		["Parmigiano", "Mozzarella campana", "Gorgonzola", "Asiago"])
	_s.set_tempo(TOT, TOT)


func _process(dt: float) -> void:
	if _fase == 0:
		_t -= dt
		for i in 6:
			if not _fatto[i] and TOT - _t >= _quando[i]:
				_fatto[i] = true
				_s.risposto(i, _scelta[i])
		_s.set_tempo(maxf(_t, 0.0), TOT)
		if _t <= 0.0:
			_fase = 1
			var scelte := {}
			var punti: Array = []
			for i in 6:
				scelte[i] = _scelta[i]
				punti.append(500)
			_s.rivela(1, scelte, punti)
			_t = 5.0
	else:
		_t -= dt
		if _t <= 0.0:
			_inizia()
