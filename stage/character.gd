extends Node3D
## Personaggio (presentatore o concorrente) con le animazioni Mixamo condivise di assets/animations/.
## Tutti i modelli hanno uno scheletro Mixamo: le tracce vengono solo ripuntate sullo scheletro del modello.
## Uso: var c := preload("res://stage/character.gd").new(); add_child(c); c.setup("res://.../lola.fbx"); c.play("cheer")

const ANIM_DIR := "res://assets/animations/"
const ANIMS: Array[String] = ["idle", "happy", "talk", "talk2", "think", "cheer", "victory", "defeated", "disappointed",
	"clap", "surprised", "rally", "zombie_idle", "dance_hiphop", "dance_rumba", "dance_silly", "dance_thriller"]
const LOOPS: Array[String] = ["idle", "happy", "talk", "talk2", "think", "zombie_idle",
	"dance_hiphop", "dance_rumba", "dance_silly", "dance_thriller"]

var _ap: AnimationPlayer
var _skel: Skeleton3D

func setup(model_path: String, height: float = 1.8) -> void:
	var model: Node3D = load(model_path).instantiate()
	add_child(model)
	_skel = model.find_children("*", "Skeleton3D", true, false)[0]
	var aabb := AABB()
	for m in model.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge((m as MeshInstance3D).get_aabb())
	model.scale = Vector3.ONE * (height / aabb.size.y)
	_ap = AnimationPlayer.new()
	model.add_child(_ap)
	var lib := AnimationLibrary.new()
	var skel_path := String(model.get_path_to(_skel))
	for a in ANIMS:
		lib.add_animation(a, _retarget(ANIM_DIR + a + ".fbx", skel_path))
	_ap.add_animation_library("", lib)
	_ap.animation_finished.connect(func(_n: StringName) -> void: play("idle"))
	play("idle")

func play(anim: String) -> void:
	if not _ap.has_animation(anim):
		push_warning("Character: animazione sconosciuta '%s'" % anim)
		anim = "idle"
	_ap.play(anim, 0.3)

# Copia l'animazione del file Mixamo e la ripunta sulle ossa di questo modello (prefisso "mixamorig_" o "mixamorig1_").
# Le ossa che il modello non ha vengono scartate; dello spostamento si tiene solo quello delle anche, in scala.
func _retarget(path: String, skel_path: String) -> Animation:
	var src: Node = load(path).instantiate()
	var src_ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	var src_skel: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var a: Animation = src_ap.get_animation(src_ap.get_animation_list()[0]).duplicate()
	var src_prefix := src_skel.get_bone_name(0).trim_suffix("Hips")
	var prefix := _skel.get_bone_name(0).trim_suffix("Hips")
	var hip_ratio := _skel.get_bone_rest(0).origin.y / src_skel.get_bone_rest(0).origin.y
	for t in range(a.get_track_count() - 1, -1, -1):
		var bone := String(a.track_get_path(t).get_concatenated_subnames()).trim_prefix(src_prefix)
		var type := a.track_get_type(t)
		if _skel.find_bone(prefix + bone) == -1 or type == Animation.TYPE_SCALE_3D \
				or (type == Animation.TYPE_POSITION_3D and bone != "Hips"):
			a.remove_track(t)
			continue
		a.track_set_path(t, NodePath(skel_path + ":" + prefix + bone))
		if type == Animation.TYPE_POSITION_3D:
			for k in a.track_get_key_count(t):
				a.track_set_key_value(t, k, a.track_get_key_value(t, k) * hip_ratio)
	a.loop_mode = Animation.LOOP_LINEAR if path.get_file().get_basename() in LOOPS else Animation.LOOP_NONE
	src.free()
	return a
