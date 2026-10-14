extends Node2D

const GIOCHI := [
	{"id": "accumula", "titolo": "Accumula Punti", "icona": "💰", "regola": "Più rispondi, più incassi.", "fisso": false},
	{"id": "dito", "titolo": "Dito Veloce", "icona": "⚡", "regola": "Il più rapido vince.", "fisso": false},
	{"id": "bomba", "titolo": "Passa la Bomba", "icona": "💣", "regola": "Non farla esplodere in mano.", "fisso": false},
	{"id": "ruba", "titolo": "Ruba Punti", "icona": "🦝", "regola": "Sfila i punti agli altri.", "fisso": false},
	{"id": "torta", "titolo": "Torta in Faccia", "icona": "🥧", "regola": "Sbaglia e arriva la torta.", "fisso": false},
	{"id": "ordine", "titolo": "Metti in Ordine", "icona": "🔢", "regola": "Ordina le risposte giuste.", "fisso": false},
	{"id": "vicina", "titolo": "La risposta più vicina", "icona": "🎯", "regola": "Vince chi si avvicina di più.", "fisso": false},
	{"id": "conto", "titolo": "Conto alla Rovescia", "icona": "⏳", "regola": "Il gran finale.", "fisso": true},
]

var _s: SchermataScelta


func _ready() -> void:
	add_child(Palco.new())
	_s = SchermataScelta.new()
	add_child(_s)
	_s.confermato.connect(func(ids: Array[String]) -> void: print("CONFERMATI: ", ids))
	_s.mostra(GIOCHI)
	await get_tree().create_timer(1.0).timeout
	_s.muovi(Vector2i(1, 0))
	_s.premi() # spegne "dito"
	_s.muovi(Vector2i(1, 0))
	_s.premi() # spegne "bomba"
	_s.muovi(Vector2i(1, 0))
	_s.premi() # spegne "ruba": 5 accesi
	await get_tree().create_timer(0.5).timeout
	_s.muovi(Vector2i(0, 1))
	_s.premi() # fissa: scossa
	_s.muovi(Vector2i(-1, 0))
	_s.premi() # spegne "vicina": 4 accesi
	_s.muovi(Vector2i(-1, 0))
	_s.premi() # sotto il minimo: scossa
	await get_tree().create_timer(0.5).timeout
	_s.muovi(Vector2i(0, 1))
	await get_tree().create_timer(0.3).timeout
	_s.premi()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
