extends Node2D

const G := [["chef", "Gastone", "FF3B4E"], ["nonna", "Nonna Pina", "3DD6A0"], ["zombi", "Zeb", "A855F7"],
	["gatto", "Brioche", "FFD23D"], ["boss", "Don Ciccio", "3D9BFF"], ["diva", "Vanessa", "FF8A1F"]]

var _l: SchermataLobby
var _n := 0


func _ready() -> void:
	add_child(Palco.new())
	_l = SchermataLobby.new()
	add_child(_l)
	_l.setup("quizzone.tv", "KR7Q")
	var t := Timer.new()
	t.wait_time = 1.5
	t.timeout.connect(_passo)
	add_child(t)
	t.start()


func _passo() -> void:
	if _n < 6:
		_l.aggiungi(_n, G[_n][0], G[_n][1], Color(G[_n][2]))
	elif _n == 6:
		_l.togli(1)
	elif _n == 7:
		_l.togli(4)
	_n += 1
