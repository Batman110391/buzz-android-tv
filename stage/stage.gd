extends Node3D
## Palco 3D: solo grafica (contratto T11).

signal intro_finished

const COLORS: Array[Color] = [
	Color("E53935"), Color("1E88E5"), Color("43A047"),
	Color("FDD835"), Color("8E24AA"), Color("FB8C00"),
]
const NEON: Array[Color] = [Color("ff2bd6"), Color("27e0ff"), Color("ffd22b")]
const LOOK_AT := Vector3(0, 1.4, -2)
const CAM_INTRO := Vector3(0, 7, 24)
const CAM_IDLE := Vector3(0, 3.2, 10.5)
const CAM_QUESTION := Vector3(0, 2.0, 11.5)
const LOOK_QUESTION := Vector3(0, -0.6, -2)

@onready var cam: Camera3D = $Camera3D
@onready var host: Marker3D = $HostSpot

var _pods: Array[Dictionary] = []  # {root, mat, label, name}
var _key: OmniLight3D
var _spots: Array[SpotLight3D] = []
var _confetti: CPUParticles3D
var _tween: Tween


func _ready() -> void:
	_build_set()
	_set_cam(CAM_IDLE, LOOK_AT)
	_mood(Color(1, 0.95, 0.9), 1.4)


func _mat(c: Color, emit: float = 0.0, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_set() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	_mesh(floor_mesh, _mat(Color(0.14, 0.1, 0.36), 0.0, 0.15, 0.0), Vector3(0, 0, -2))
	var wall := BoxMesh.new()
	wall.size = Vector3(30, 14, 0.3)
	_mesh(wall, _mat(Color(0.07, 0.05, 0.22), 0.0, 0.9), Vector3(0, 7, -9))
	# archi neon concentrici (toro emissivo, meta' sotto il pavimento)
	for i in 3:
		var t := TorusMesh.new()
		t.inner_radius = 3.6 + i * 1.6
		t.outer_radius = t.inner_radius + 0.12
		t.rings = 32
		t.ring_segments = 6
		var arc := _mesh(t, _mat(NEON[i], 3.0), Vector3(0, 0, -8.7))
		arc.rotation.x = PI / 2
	for s in [-1, 1]:
		var col := BoxMesh.new()
		col.size = Vector3(0.25, 9, 0.25)
		_mesh(col, _mat(NEON[1], 3.0), Vector3(s * 11.0, 4.5, -8.5))
		_mesh(col, _mat(NEON[0], 3.0), Vector3(s * 9.0, 4.5, -8.5))
	var disc := CylinderMesh.new()
	disc.top_radius = 1.4
	disc.bottom_radius = 1.5
	disc.height = 0.2
	_mesh(disc, _mat(Color(0.15, 0.1, 0.4), 1.0, 0.2), host.position + Vector3(0, 0.1, 0))
	# luci: 3 totali, nessuna ombra
	_key = OmniLight3D.new()
	_key.position = Vector3(0, 7, 6)
	_key.omni_range = 30.0
	add_child(_key)
	for i in 2:
		var sp := SpotLight3D.new()
		sp.position = Vector3(-7 + i * 14, 8, 4)
		sp.spot_range = 25.0
		sp.spot_angle = 30.0
		sp.light_color = NEON[i]
		sp.light_energy = 2.0
		add_child(sp)
		sp.look_at(Vector3(0, 0.5, -2))
		_spots.append(sp)
	_confetti = CPUParticles3D.new()
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.explosiveness = 0.9
	_confetti.amount = 250
	_confetti.lifetime = 3.5
	_confetti.direction = Vector3.UP
	_confetti.spread = 40.0
	_confetti.initial_velocity_min = 5.0
	_confetti.initial_velocity_max = 9.0
	_confetti.gravity = Vector3(0, -6, 0)
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	_confetti.scale_amount_min = 0.6
	_confetti.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var cm := _mat(Color.WHITE)
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.vertex_color_use_as_albedo = true
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = cm
	_confetti.mesh = q
	_confetti.color_initial_ramp = _rainbow()
	add_child(_confetti)


func _rainbow() -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.5, 0.67, 0.84])
	g.colors = PackedColorArray(COLORS)
	return g


func _set_cam(pos: Vector3, look: Vector3) -> void:
	cam.position = pos
	cam.look_at(look)


func _tween_cam(pos: Vector3, look: Vector3, dur: float, from_look: Vector3) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	_tween.tween_property(cam, "position", pos, dur)
	_tween.tween_method(func(l: Vector3) -> void: cam.look_at(l), from_look, look, dur)
	return _tween


func _mood(c: Color, e: float) -> void:
	_key.light_color = c
	_key.light_energy = e


func setup_players(names: Array[String]) -> void:
	for p in _pods:
		(p.root as Node).queue_free()
	_pods.clear()
	var n: int = mini(names.size(), 6)
	for i in n:
		var a: float = 0.0 if n == 1 else lerpf(-0.95, 0.95, float(i) / (n - 1))
		var root := Node3D.new()
		root.position = host.position + Vector3(sin(a) * 6.0, 0, 1.5 + cos(a) * 2.5)
		root.rotation.y = a * 0.4
		add_child(root)
		var body := BoxMesh.new()
		body.size = Vector3(1.3, 1.0, 0.9)
		var mat := _mat(COLORS[i], 0.0, 0.35)
		_mesh(body, mat, Vector3(0, 0.5, 0), root)
		var top := BoxMesh.new()
		top.size = Vector3(1.4, 0.08, 1.0)
		_mesh(top, _mat(COLORS[i], 2.0), Vector3(0, 1.04, 0), root)
		var lab := Label3D.new()
		lab.font_size = 96
		lab.pixel_size = 0.0035
		lab.outline_size = 16
		lab.position = Vector3(0, 0.6, 0.46)
		root.add_child(lab)
		_pods.append({"root": root, "mat": mat, "label": lab, "name": names[i]})
		_label(i, 0)


func _label(i: int, pts: int) -> void:
	(_pods[i].label as Label3D).text = "%s\n%d" % [_pods[i].name, pts]


func play_intro() -> void:
	_set_cam(CAM_INTRO, LOOK_AT)
	_mood(Color(1, 0.95, 0.9), 1.4)
	_tween_cam(CAM_IDLE, LOOK_AT, 3.0, LOOK_AT).finished.connect(func() -> void: intro_finished.emit())


func focus_question() -> void:
	_mood(Color(0.35, 0.45, 1.0), 0.8)
	_tween_cam(CAM_QUESTION, LOOK_QUESTION, 1.0, LOOK_AT)


func show_reveal(results: Dictionary) -> void:
	for i in _pods.size():
		var ok: bool = results.get(i, false)
		_tint(i, Color("2ecc40") if ok else Color("d32f2f"))


func update_scores(scores: Dictionary) -> void:
	for i in _pods.size():
		_tint(i, COLORS[i])
		_label(i, int(scores.get(i, 0)))


func celebrate(winner_id: int) -> void:
	_mood(Color(1, 0.9, 0.7), 2.5)
	_tween_cam(CAM_IDLE, LOOK_AT, 1.0, LOOK_QUESTION)
	if winner_id >= 0 and winner_id < _pods.size():
		_confetti.position = (_pods[winner_id].root as Node3D).position + Vector3(0, 1.5, 0)
		_confetti.restart()
		_confetti.emitting = true
		for sp in _spots:
			sp.look_at(_confetti.position)


func _tint(i: int, c: Color) -> void:
	var m: StandardMaterial3D = _pods[i].mat
	m.albedo_color = c
	m.emission_enabled = c != COLORS[i]
	m.emission = c
	m.emission_energy_multiplier = 1.5
