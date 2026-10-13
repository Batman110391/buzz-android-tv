extends Node3D
## Personaggio (presentatore o concorrente) con le animazioni Mixamo condivise di assets/animations/.
## Tutti i modelli hanno uno scheletro Mixamo: le tracce vengono solo ripuntate sullo scheletro del modello.
## Uso: var c := preload("res://stage/character.gd").new(); add_child(c); c.setup("res://.../lola.fbx"); c.play("cheer")

const ANIM_DIR := "res://assets/animations/"
const ANIMS: Array[String] = ["idle", "happy", "talk", "talk2", "think", "cheer", "victory", "defeated", "disappointed",
	"clap", "surprised", "rally", "zombie_idle", "dance_hiphop", "dance_rumba", "dance_silly", "dance_thriller",
	"walk", "strut", "point", "laugh", "taunt"]
const LOOPS: Array[String] = ["idle", "happy", "talk", "talk2", "think", "zombie_idle",
	"dance_hiphop", "dance_rumba", "dance_silly", "dance_thriller", "walk", "strut"]
## Velocita' al suolo (m/s) delle animazioni in place, per un personaggio con scheletro alto quanto quello Mixamo (anche a 0.777 m). Valori stampati da tools/make_anims.py.
const WALK_SPEED := {"walk": 1.104, "strut": 0.655}
const SRC_HIPS := 0.777

signal arrived

var _ap: AnimationPlayer
var _skel: Skeleton3D
var _dest := Vector3.ZERO
var _speed := 0.0
var _anim := "walk"
var _walking := false
var _started := false
var _turn: Tween

func setup(model_path: String, height: float = 1.8) -> void:
	var model: Node3D = load(model_path).instantiate()
	add_child(model)
	_skel = model.find_children("*", "Skeleton3D", true, false)[0]
	var aabb := AABB()
	for m in model.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge((m as MeshInstance3D).get_aabb())
	model.scale = Vector3.ONE * (height / aabb.size.y)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var bm := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if bm == null:
				continue
			bm = bm.duplicate()
			bm.roughness = 0.7
			bm.metallic = 0.0
			bm.rim_enabled = true
			bm.rim = 0.3
			bm.rim_tint = 0.5
			bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mi.set_surface_override_material(i, bm)
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

# Si gira (0.25 s) verso `pos` (stesso spazio di `position`, y ignorata), cammina con `anim` a velocita' coerente col passo,
# poi idle + `arrived`. Una nuova chiamata annulla la precedente.
func walk_to(pos: Vector3, anim: String = "walk") -> void:
	_dest = Vector3(pos.x, position.y, pos.z)
	var hips_h := (global_transform.affine_inverse() * _skel.global_transform * _skel.get_bone_global_rest(0)).origin.y
	_speed = WALK_SPEED.get(anim, 1.0) * hips_h / SRC_HIPS
	_anim = anim
	_started = false
	_walking = true
	face(_dest)

# Rotazione morbida sul posto verso `pos`.
func face(pos: Vector3) -> void:
	var d := pos - position
	d.y = 0.0
	if d.length() < 0.001:
		return
	if _turn != null:
		_turn.kill()
	_turn = create_tween()
	_turn.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, atan2(d.x, d.z)), 0.25)

func _process(delta: float) -> void:
	if not _walking or (_turn != null and _turn.is_running()):
		return
	if not _started:
		_started = true
		play(_anim)
	var left := _dest - position
	var step := _speed * delta
	if left.length() <= step:
		position = _dest
		_walking = false
		play("idle")
		arrived.emit()
	else:
		position += left.normalized() * step
