extends SceneTree
# godot --headless --path . --script res://tools/svg_to_png.gd   (poi: godot --headless --path . --import)

const SRC := "res://design/quizzone/assets/personaggi/"
const DST := "res://assets/personaggi/"

func _init() -> void:
	var rig_txt := FileAccess.get_file_as_string(SRC + "rig.json")
	var rig: Dictionary = JSON.parse_string(rig_txt)
	DirAccess.make_dir_recursive_absolute(DST)
	var f := FileAccess.open(DST + "rig.json", FileAccess.WRITE)
	f.store_string(rig_txt)
	f.close()
	var tot := 0
	for id: String in rig:
		var s: int = 3 if id in ["host", "gilda"] else 2
		var tela: Array = rig[id]["tela"]
		DirAccess.make_dir_recursive_absolute(DST + id)
		var pezzi := {}
		for fn in DirAccess.get_files_at(SRC + id):
			if not fn.ends_with(".svg"):
				continue
			var img := Image.new()
			# gli SVG dichiarano width = tela*4
			img.load_svg_from_string(FileAccess.get_file_as_string(SRC + id + "/" + fn), s / 4.0)
			if img.get_width() != int(tela[0]) * s or img.get_height() != int(tela[1]) * s:
				push_error("%s/%s: dimensione %s inattesa" % [id, fn, img.get_size()])
			var r := img.get_used_rect()
			if r.size == Vector2i.ZERO:
				r = Rect2i(0, 0, 1, 1)
			var nome := fn.get_basename()
			img.get_region(r).save_png(DST + id + "/" + nome + ".png")
			pezzi[nome] = [float(r.position.x) / s, float(r.position.y) / s]
			tot += 1
		var j := FileAccess.open(DST + id + "/pezzi.json", FileAccess.WRITE)
		j.store_string(JSON.stringify({"scala": s, "pezzi": pezzi}))
		j.close()
	print("PNG scritti: ", tot)
	quit()
