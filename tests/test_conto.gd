extends Node2D
## Prova Conto alla Rovescia: 3 s di domanda (barre -50/s accelerato, alcuni rispondono), poi rivelazione.

const TOT := 3.0
const NOMI := ["Gastone", "Nonna Pina", "Ugo", "Brioche", "Don Ciccio", "Vanessa"]
const COLORI := ["F2384A", "2F7BFF", "33C759", "FFD43B", "A855F7", "FF8A1F"]
const PUNTI := [1250, 900, 1000, 700, 1100, 400]
const SCELTE := [1, 1, 0, -1, 2, 1]  # corretta = 1

var _s: SchermataConto
var _t := TOT
var _p: Array[float] = []
var _bloccato: Array[bool] = []
var _rivelato := false


func _ready() -> void:
	add_child(Palco.new())
	_s = SchermataConto.new()
	add_child(_s)
	var g: Array = []
	for i in 6:
		g.append({"nome": NOMI[i], "colore": Color(COLORI[i]), "punti": PUNTI[i]})
		_p.append(PUNTI[i])
		_bloccato.append(false)
	_s.setup(g)
	_s.mostra_domanda(3, 5, "Quale di questi formaggi si fa con il latte di bufala?", ["Parmigiano", "Mozzarella campana", "Gorgonzola", "Asiago"])
	_s.set_tempo(TOT, TOT)


func _process(dt: float) -> void:
	if _rivelato:
		return
	_t -= dt
	for i in 6:
		if not _bloccato[i]:
			_p[i] = maxf(_p[i] - 50.0 * dt * 15.0 / TOT, 0.0)
			_s.set_punti(i, roundi(_p[i]))
			if i in [0, 2, 4, 1] and TOT - _t > 1.0 + i * 0.5:
				_bloccato[i] = true
				_s.risposto(i)
	_s.set_tempo(maxf(_t, 0.0), TOT)
	if _t <= 0.0:
		_rivelato = true
		var scelte := {}
		var finali: Array = []
		for i in 6:
			scelte[i] = SCELTE[i]
			finali.append(roundi(_p[i]) if SCELTE[i] == 1 else 0)
		_s.rivela(1, scelte, finali)
