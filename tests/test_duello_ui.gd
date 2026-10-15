extends Node2D
## Prova schermata Duello: 2 vs 3, testi lunghi; A sbaglia poi indovina, B indovina, rivelazione.

var _s: SchermataDuello
var _t := 0.0
var _passo := 0


func _ready() -> void:
	add_child(Palco.new())
	_s = SchermataDuello.new()
	add_child(_s)
	var cols := [Color("F2384A"), Color("2F7BFF"), Color("33C759"), Color("FFD43B"), Color("A855F7")]
	var nomi := ["Gastone", "Nonna Pina", "Ugo", "Brioche", "Don Ciccio Esposito"]
	var sq: Array = [[], []]
	for i in 5:
		sq[0 if i < 2 else 1].append({"pid": i, "nome": nomi[i], "colore": cols[i], "personaggio": ""})
	_s.setup(sq)
	_s.mostra_domanda(2, "Personaggio storico", [
		"Nacque in una piccola città di provincia e da giovane studiò legge senza mai concluderla",
		"Guidò un esercito attraverso le Alpi con un branco di elefanti, sfidando una potenza che dominava il Mediterraneo da secoli",
		"Fu generale cartaginese e nemico giurato di Roma durante la seconda guerra punica"],
		["Annibale Barca di Cartagine", "Giulio Cesare", "Alessandro Magno, re di Macedonia", "Attila"], [0, 3])
	_s.mostra_indizio(1)


func _process(dt: float) -> void:
	_t += dt
	_s.set_tempo(4.0 - fmod(_t, 4.0), 4.0)
	if _passo == 0 and _t > 4.0:
		_passo = 1
		_s.mostra_indizio(2)
		_s.set_premio(1000)
		_s.esito_squadra(0, false, 300)
	elif _passo == 1 and _t > 8.0:
		_passo = 2
		_s.mostra_indizio(3)
		_s.set_premio(500)
		_s.esito_squadra(0, true, 500)
		_s.esito_squadra(1, true, 500)
	elif _passo == 2 and _t > 11.0:
		_passo = 3
		_s.rivela(0)
