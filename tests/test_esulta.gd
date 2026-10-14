extends SceneTree
# Il vincitore esulta per minuti sul podio: salti e scala del corpo devono restare limitati.

func _init() -> void:
	var p := Personaggio.new()
	p.setup("chef")
	root.add_child(p)
	p.stato("esulta")
	var mx := 0.0
	for i in 60 * 600:  # 10 minuti a 60 FPS
		p._process(1.0 / 60.0)
		mx = maxf(mx, p._corpo.scale.y)
	print("salto_h=", p._salto_h, " max scala y=", mx)
	quit(0 if mx < 1.5 and p._salto_h > 15.0 else 1)
