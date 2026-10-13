extends Node2D

var _r: SchermataRound
var _f: SchermataFinale


func _ready() -> void:
	add_child(Palco.new())
	_r = SchermataRound.new()
	add_child(_r)
	_f = SchermataFinale.new()
	add_child(_f)
	_r.mostra(3, 6, "PASSA LA BOMBA", "Rispondi giusto per passare la bomba. Chi ce l'ha quando esplode perde 500 punti.", "💣")
	get_tree().create_timer(4.0).timeout.connect(_r.nascondi)
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		_f.mostra([
			{"nome": "Don Ciccio", "colore": Color("A855F7"), "personaggio": "boss", "punti": 3400},
			{"nome": "Ugo", "colore": Color("3DDC84"), "personaggio": "zombi", "punti": 2950},
			{"nome": "Vanessa", "colore": Color("FF8A3D"), "personaggio": "diva", "punti": 2300},
			{"nome": "Gastone", "colore": Color("FF4D5E"), "personaggio": "chef", "punti": 1900},
			{"nome": "Nonna Pina", "colore": Color("3D7BFF"), "personaggio": "nonna", "punti": 1450},
			{"nome": "Brioche", "colore": Color("FFC83D"), "personaggio": "gatto", "punti": 800},
		]))
