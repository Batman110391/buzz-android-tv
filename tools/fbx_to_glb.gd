extends SceneTree
## Converte gli FBX dei concorrenti (FBX 6100, Blender 5.2 non li legge) in .glb per Blender.
## Uso: godot --headless --path . --script res://tools/fbx_to_glb.gd


func _init() -> void:
	for key in ["polpetta", "smeralda", "zippo", "lola", "zombi", "elvio", "macho"]:
		var root: Node = (load("res://assets/models/characters/%s.fbx" % key) as PackedScene).instantiate()
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_scene(root, state)
		if err == OK:
			err = doc.write_to_filesystem(state, ProjectSettings.globalize_path("res://art/characters/%s.glb" % key))
		print(key, " -> ", error_string(err))
		root.free()
	quit()
