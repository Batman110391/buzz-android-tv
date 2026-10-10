extends Node3D

const ANIMS: Dictionary = {
	"idle": "Idle",
	"talk": "Spellcasting",
	"surprise": "Hit_B",
	"celebrate": "Cheer",
}
const LOOPING: Array[String] = ["idle", "talk"]

@onready var _ap: AnimationPlayer = find_child("AnimationPlayer", true, false)

func _ready() -> void:
	for k in LOOPING:
		_ap.get_animation(ANIMS[k]).loop_mode = Animation.LOOP_LINEAR
	_ap.animation_finished.connect(_on_finished)
	play("idle")

func play(anim: String) -> void:
	if not ANIMS.has(anim):
		push_warning("Host: animazione sconosciuta '%s'" % anim)
		anim = "idle"
	_ap.play(ANIMS[anim], 0.2)

func _on_finished(name: StringName) -> void:
	if name != ANIMS["idle"] and name != ANIMS["talk"]:
		play("idle")
