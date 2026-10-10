extends Node3D

const COLORS: Array[Color] = [Color.BLUE, Color.ORANGE, Color.GREEN, Color.YELLOW]

@onready var cube: MeshInstance3D = $Cube
@onready var label: Label = $CanvasLayer/Label
var idx := 0
var last_event := "-"
var server := preload("res://net/server.gd").new()

func _ready() -> void:
	_apply_color()
	add_child(server)
	server.button_pressed.connect(func(id: int) -> void:
		last_event = "Telefono %d" % id
		next_color())

func _process(delta: float) -> void:
	cube.rotate_y(delta)
	cube.rotate_x(delta * 0.5)
	label.text = "FPS: %d\n%s\n%s" % [Engine.get_frames_per_second(), last_event, server.get_lan_url()]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		last_event = "Key: %s (%d)" % [OS.get_keycode_string(event.keycode), event.keycode]
	elif event is InputEventJoypadButton and event.pressed:
		last_event = "Joy button: %d" % event.button_index
	if event.is_action_pressed("ui_accept"):
		next_color()

func next_color() -> void:
	idx = (idx + 1) % COLORS.size()
	_apply_color()

func _apply_color() -> void:
	(cube.get_surface_override_material(0) as StandardMaterial3D).albedo_color = COLORS[idx]
