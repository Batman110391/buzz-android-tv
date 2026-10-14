extends Node2D


func _p(pid: int, nome: String, col: String, pers: String, punti: int) -> Dictionary:
	return {"pid": pid, "nome": nome, "colore": Color(col), "personaggio": pers, "punti": punti}


func _ready() -> void:
	add_child(Palco.new())
	var cl := SchermataClassifica.new()
	add_child(cl)
	var prima := [_p(1, "Gastone", "F2384A", "chef", 900), _p(2, "Nonna Pina", "2F7BFF", "nonna", 700), _p(3, "Ugo", "33C759", "zombi", 500), _p(4, "Brioche", "FFD43B", "gatto", 300), _p(5, "Don Ciccio", "A855F7", "boss", 100)]
	var dopo := [_p(4, "Brioche", "FFD43B", "gatto", 1300), _p(2, "Nonna Pina", "2F7BFF", "nonna", 1100), _p(1, "Gastone", "F2384A", "chef", 1000), _p(5, "Don Ciccio", "A855F7", "boss", 700), _p(3, "Ugo", "33C759", "zombi", 550)]
	cl.mostra(prima, dopo)
	await get_tree().create_timer(4.0).timeout
	cl.nascondi()
	var ca := SchermataCategoria.new()
	add_child(ca)
	ca.mostra("Ugo", Color("33C759"), "zombi", [
		{"id": "geo", "nome": "Geografia", "icona": "🌍"},
		{"id": "cin", "nome": "Cinema e TV", "icona": "🎬"},
		{"id": "cuc", "nome": "Cucina", "icona": "🍝"}])
	for t in range(10, 0, -1):
		ca.set_tempo(t * 0.2, 2.0)
		await get_tree().create_timer(0.2).timeout
	ca.scegli(1)
	await get_tree().create_timer(1.2).timeout
	get_tree().quit()
