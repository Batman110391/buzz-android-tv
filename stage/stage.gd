extends Node3D
## Studio 3D stile quiz show: solo grafica. Contratto in PLAN.md (V2).

signal intro_finished

const GLOW := true

# Mood = [tono (fascia/scale/schermi/luci), puntini pavimento, accento (anello/arco)]
const M_QUESTION: Array[Color] = [Color(1.0, 0.45, 0.03), Color(1.0, 0.1, 0.08), Color(0.12, 0.45, 1.0)]
const M_BLUE: Array[Color] = [Color(0.1, 0.45, 1.0), Color(0.95, 0.1, 0.12), Color(0.2, 0.6, 1.0)]
const M_GOLD: Array[Color] = [Color(0.8, 0.55, 0.1), Color(1.0, 0.6, 0.1), Color(1.0, 0.85, 0.4)]

const R_FLOOR := 4.8
const R_STAGE := 6.0
const CAM_Q := Vector3(0, 1.9, 6.4)
const LOOK_Q := Vector3(0, 1.2, 0)
const FOV_Q := 36.0
const GREEN := Color(0.15, 0.95, 0.25)
const RED := Color(0.95, 0.08, 0.08)
const PLATE_BLUE := Color(0.2, 0.5, 1.0)

@onready var cam: Camera3D = $Camera3D
@onready var host: Marker3D = $HostSpot

var _mood: Array[Color] = M_BLUE.duplicate()
var _look := LOOK_Q
var _ctw: Tween
var _mtw: Tween
var _m_band: StandardMaterial3D
var _m_dots: StandardMaterial3D
var _m_ring: StandardMaterial3D
var _m_stairs: StandardMaterial3D
var _m_screen: StandardMaterial3D
var _m_stand: StandardMaterial3D
var _m_cone_a: ShaderMaterial
var _m_cone_b: ShaderMaterial
var _m_arch: StandardMaterial3D
var _lights: Array[Light3D] = []  # 0 dir, 1-2 rim, 3 fill
var _mirror: Node3D
var _pods: Array[Dictionary] = []  # {root, mirror, dome, border, label, name}
var _confetti: CPUParticles3D
var _sparkles: Array[StandardMaterial3D] = []
var _glow_tex: GradientTexture2D


func _ready() -> void:
	_build_env()
	_build_set()
	_place_spots(6)
	_apply(M_BLUE)
	cam.position = Vector3(0, 3.2, 12)
	_look = Vector3(0, 1.4, 0)
	cam.fov = 40.0
	cam.look_at(_look)


# ---------- helpers ----------

func _mat(c: Color, add: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _k(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


func _add(mesh: Mesh, mat: Material, pos: Vector3, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _mm(mesh: Mesh, mat: Material, xf: Array[Transform3D], cols: Array[Color], parent: Node) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _pol(r: float, a: float, y: float) -> Vector3:
	return Vector3(sin(a) * r, y, -cos(a) * r)


func _quad(st: SurfaceTool, p: Array[Vector3], c: Array[Color]) -> void:
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(c[i])
		st.set_uv(Vector2(p[i].x, p[i].z) * 10.0)
		st.add_vertex(p[i])


func _ring(r0: float, r1: float, y: float, c0: Color, c1: Color, segs: int = 64) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		_quad(st, [_pol(r0, a0, y), _pol(r1, a0, y), _pol(r1, a1, y), _pol(r0, a1, y)], [c0, c1, c1, c0])
	return st.commit()


func _face(n: Node3D) -> void:
	n.rotation.y = atan2(-n.position.x, -n.position.z)


func _dot_tex() -> ImageTexture:
	var img := Image.create(32, 32, true, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(16, 16))
			img.set_pixel(x, y, Color(0.05, 0.05, 0.05, 0.5).lerp(Color.WHITE, 1.0 - smoothstep(4.5, 7.0, d)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _sil_tex() -> ImageTexture:
	var img := Image.create(64, 96, true, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 64:
			var head := Vector2(x, y).distance_to(Vector2(32, 26)) < 11.0
			var body := y > 46 and pow((x - 32) / 27.0, 2) + pow((y - 92) / 44.0, 2) < 1.0
			img.set_pixel(x, y, Color.WHITE if head or body else Color(1, 1, 1, 0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _radial(inner: Color, mid: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([inner, mid, outer])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.22)
	t.width = 128
	t.height = 128
	return t


# ---------- costruzione ----------

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.4, 0.5)
	env.ambient_light_energy = 0.7
	if GLOW:
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_bloom = 0.1
		env.glow_hdr_threshold = 0.9
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	$WorldEnvironment.environment = env


func _build_set() -> void:
	_glow_tex = _radial(Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0))
	_mirror = Node3D.new()
	_mirror.scale = Vector3(1, -1, 1)
	add_child(_mirror)

	# pavimento: dischetto trasparente con puntini LED (sopra le copie specchiate)
	_m_dots = _mat(Color.WHITE)
	_m_dots.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_dots.albedo_texture = _dot_tex()
	_m_dots.vertex_color_use_as_albedo = true
	_m_dots.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_add(_ring(0.0, R_FLOOR, 0.0, Color(0.12, 0.12, 0.12), Color(1, 1, 1), 48), _m_dots, Vector3.ZERO, self)
	# fascia esterna arancione (sfumata)
	_m_band = _mat(Color.WHITE)
	_m_band.vertex_color_use_as_albedo = true
	_add(_ring(R_FLOOR, R_STAGE, 0.004, Color(0.55, 0.55, 0.55), Color(1, 1, 1)), _m_band, Vector3.ZERO, self)
	# bordo scuro lucido + terreno nero
	var rim_m := _mat(Color.WHITE)
	rim_m.vertex_color_use_as_albedo = true
	_add(_ring(R_STAGE, 6.7, 0.0, Color(0.04, 0.04, 0.07), Color(0.01, 0.01, 0.02), 64), rim_m, Vector3.ZERO, self)
	var ground := _mat(Color(0.005, 0.005, 0.012))
	_add(_ring(6.7, 60.0, -0.01, Color.WHITE, Color.WHITE, 32), ground, Vector3.ZERO, self)

	# anello neon blu (parete bassa + toro) e sua copia specchiata
	_m_ring = _mat(Color.WHITE)
	var wall_m := _mat(Color(0.03, 0.03, 0.08))
	for parent in [self, _mirror]:
		var wall := CylinderMesh.new()
		wall.top_radius = R_STAGE + 0.05
		wall.bottom_radius = R_STAGE + 0.05
		wall.height = 0.5
		wall.cap_top = false
		wall.cap_bottom = false
		wall.radial_segments = 64
		_add(wall, wall_m, Vector3(0, 0.25, 0), parent)
		var t := TorusMesh.new()
		t.inner_radius = R_STAGE - 0.04
		t.outer_radius = R_STAGE + 0.14
		t.rings = 64
		t.ring_segments = 8
		_add(t, _m_ring, Vector3(0, 0.5, 0), parent)

	_build_stands()
	_build_screens_stairs()
	_build_trusses_cones()
	_build_lights()
	_build_confetti()


func _build_stands() -> void:
	# gradinate: risalite + pedate a semicerchio con sfumatura verso l'alto
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 40
	var a_max := deg_to_rad(115.0)
	var tiers := 8
	var rows: Array[Dictionary] = []
	for i in tiers:
		var r := 9.0 + i * 1.5
		var y := 0.6 + i * 0.9
		var y_prev := 0.0 if i == 0 else 0.6 + (i - 1) * 0.9
		var f := 1.0 - 0.75 * float(i) / tiers
		for s in segs:
			var a0 := lerpf(-a_max, a_max, float(s) / segs)
			var a1 := lerpf(-a_max, a_max, float(s + 1) / segs)
			var rc := Color(f * 0.55, f * 0.55, f * 0.55)
			var tc := Color(f, f, f)
			_quad(st, [_pol(r, a0, y_prev), _pol(r, a0, y), _pol(r, a1, y), _pol(r, a1, y_prev)], [rc, rc, rc, rc])
			_quad(st, [_pol(r, a0, y), _pol(r + 1.5, a0, y), _pol(r + 1.5, a1, y), _pol(r, a1, y)], [tc, tc, tc, tc])
		rows.append({"r": r + 0.75, "y": y})
	_m_stand = _mat(Color.WHITE)
	_m_stand.vertex_color_use_as_albedo = true
	var sm := MeshInstance3D.new()
	sm.mesh = st.commit()
	sm.material_override = _m_stand
	add_child(sm)

	# pubblico: sagome nere (un solo MultiMesh) + lucine sparse
	var sil := _mat(Color(0.012, 0.008, 0.016))
	sil.albedo_texture = _sil_tex()
	sil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sil.alpha_scissor_threshold = 0.5
	sil.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 1.05)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var xf: Array[Transform3D] = []
	var spark: Array[Transform3D] = []
	var spark_c: Array[Color] = []
	var pal: Array[Color] = [Color(1, 1, 1), Color(0.5, 0.75, 1.0), Color(1, 0.7, 0.35)]
	for row in rows:
		var r: float = row.r
		var y: float = row.y
		var n := int(r * a_max * 2.0 / 0.8)
		for k in n:
			var a := lerpf(-a_max, a_max, (k + rng.randf() * 0.6) / n)
			var p := _pol(r + rng.randf_range(-0.3, 0.3), a, y)
			if rng.randf() < 0.12:
				continue
			var d := Vector3(-p.x, 0, -p.z).normalized()
			var b := Basis.looking_at(-d).scaled(Vector3(rng.randf_range(0.85, 1.15), rng.randf_range(0.9, 1.2), 1.0))
			xf.append(Transform3D(b, p + Vector3(0, 0.5, 0)))
			if rng.randf() < 0.1:
				spark.append(Transform3D(Basis.IDENTITY, p + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.2, 1.0), 0.3)))
				spark_c.append(pal[rng.randi() % 3])
	_mm(q, sil, xf, [], self)
	var sq := QuadMesh.new()
	sq.size = Vector2(0.28, 0.28)
	var half := spark.size() / 2
	for g in 2:
		var sm2 := _mat(Color(1, 1, 1, 0.9), true)
		sm2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sm2.vertex_color_use_as_albedo = true
		sm2.albedo_texture = _glow_tex
		_sparkles.append(sm2)
		_mm(sq, sm2, spark.slice(g * half, (g + 1) * half if g == 0 else spark.size()),
				spark_c.slice(g * half, (g + 1) * half if g == 0 else spark_c.size()), self)
		# lampeggio: i due gruppi si alternano
		var tw := create_tween().set_loops()
		tw.tween_property(sm2, "albedo_color:a", 0.15 if g == 0 else 1.0, 0.7 + g * 0.3)
		tw.tween_property(sm2, "albedo_color:a", 1.0 if g == 0 else 0.15, 0.7 + g * 0.3)


func _build_screens_stairs() -> void:
	# scalinate luminose
	_m_stairs = _mat(Color.WHITE)
	var glow: Array[Transform3D] = []
	var blocks: Array[Transform3D] = []
	for sx in [-3.3, 3.3]:
		var rot := Basis(Vector3.UP, -signf(sx) * 0.4)
		for k in 9:
			var h := 0.38 * (k + 1)
			var o := Vector3(sx, 0, -4.6) + rot * Vector3(0, 0, -k * 0.5)
			blocks.append(Transform3D(rot.scaled_local(Vector3(1, h, 1)), o + Vector3(0, h / 2.0, 0)))
			glow.append(Transform3D(rot, o + rot * Vector3(0, h - 0.15, 0.26)))
	var blk := BoxMesh.new()
	blk.size = Vector3(1.7, 1.0, 0.5)
	var blk_m := StandardMaterial3D.new()
	blk_m.albedo_color = Color(0.14, 0.12, 0.14)
	blk_m.roughness = 1.0
	_mm(blk, blk_m, blocks, [], self)
	var fc := BoxMesh.new()
	fc.size = Vector3(1.7, 0.2, 0.03)
	_mm(fc, _m_stairs, glow, [], self)
	# maxischermi con logo segnaposto
	_m_screen = _mat(Color.WHITE)
	_m_screen.albedo_texture = _radial(Color(1, 1, 1), Color(0.7, 0.7, 0.7), Color(0.28, 0.28, 0.28))
	var frame_m := _mat(Color(0.03, 0.03, 0.05))
	var spec: Array[Array] = [
		[Vector3(0, 3.0, -11.0), Vector2(4.8, 2.5), 0.0052],
		[Vector3(-10.0, 4.2, -7.5), Vector2(4.2, 2.6), 0.0048],
		[Vector3(10.0, 4.2, -7.5), Vector2(4.2, 2.6), 0.0048],
	]
	for s in spec:
		var root := Node3D.new()
		root.position = s[0]
		add_child(root)
		_face(root)
		var sz: Vector2 = s[1]
		var fr := QuadMesh.new()
		fr.size = sz + Vector2(0.5, 0.5)
		_add(fr, frame_m, Vector3(0, 0, -0.03), root)
		var pn := QuadMesh.new()
		pn.size = sz
		_add(pn, _m_screen, Vector3.ZERO, root)
		var lab := Label3D.new()
		lab.text = "QUIZ PARTY!"
		lab.font_size = 160
		lab.pixel_size = s[2]
		lab.outline_size = 28
		lab.outline_modulate = Color(0.45, 0.05, 0.0)
		lab.modulate = Color(1, 0.97, 0.7)
		lab.shaded = false
		lab.position = Vector3(0, 0, 0.03)
		root.add_child(lab)


func _build_trusses_cones() -> void:
	var dark := _mat(Color(0.03, 0.03, 0.05))
	var dot := QuadMesh.new()
	dot.size = Vector2(0.3, 0.3)
	var dm := _mat(Color(1, 1, 1, 1), true)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.vertex_color_use_as_albedo = true
	dm.albedo_texture = _glow_tex
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	# americane orizzontali con lucine
	for row in [[5.1, -8.5, 16.0], [6.6, -11.0, 20.0]]:
		var bar := BoxMesh.new()
		bar.size = Vector3(row[2], 0.18, 0.18)
		_add(bar, dark, Vector3(0, row[0], row[1]), self)
		for i in 26:
			xf.append(Transform3D(Basis.IDENTITY, Vector3(lerpf(-row[2] / 2.0, row[2] / 2.0, i / 25.0), row[0] - 0.2, row[1] + 0.1)))
			cols.append(Color(1, 1, 1) if i % 3 != 0 else Color(0.4, 0.7, 1.0))
	# grande arco dietro, con lucine
	_m_arch = _mat(Color.WHITE)
	var arch := TorusMesh.new()
	arch.inner_radius = 8.0
	arch.outer_radius = 8.15
	arch.rings = 64
	arch.ring_segments = 6
	var am := _add(arch, _m_arch, Vector3(0, 1.5, -14.5), self)
	am.rotation.x = PI / 2.0
	for i in 40:
		var a := lerpf(-1.9, 1.9, i / 39.0)
		xf.append(Transform3D(Basis.IDENTITY, Vector3(sin(a) * 8.1, 1.5 + cos(a) * 8.1, -14.4)))
		cols.append(Color(1, 0.85, 0.5) if i % 2 == 0 else Color(1, 1, 1))
	_mm(dot, dm, xf, cols, self)
	# coni di luce additivi finti
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 col : source_color = vec4(1.0);
void fragment() {
	float f = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	ALBEDO = col.rgb;
	ALPHA = col.a * f * (1.0 - UV.y);
}"""
	_m_cone_a = ShaderMaterial.new()
	_m_cone_a.shader = sh
	_m_cone_b = ShaderMaterial.new()
	_m_cone_b.shader = sh
	var srcs: Array[Vector3] = [Vector3(-7, 5.1, -8.5), Vector3(-3.5, 5.1, -8.5), Vector3(3.5, 5.1, -8.5), Vector3(7, 5.1, -8.5), Vector3(-5, 6.6, -11), Vector3(5, 6.6, -11)]
	var tgts: Array[Vector3] = [Vector3(2, 0, 0), Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(-2, 0, 0), Vector3(3, 0, -1), Vector3(-3, 0, -1)]
	for i in srcs.size():
		var len := srcs[i].distance_to(tgts[i])
		var piv := Node3D.new()
		piv.position = srcs[i]
		add_child(piv)
		piv.look_at(tgts[i])
		var c := CylinderMesh.new()
		c.top_radius = 0.08
		c.bottom_radius = 1.5
		c.height = len
		c.radial_segments = 16
		c.cap_top = false
		c.cap_bottom = false
		var mi := _add(c, _m_cone_a if i % 2 == 0 else _m_cone_b, Vector3(0, 0, -len / 2.0), piv)
		mi.rotation.x = PI / 2.0


func _build_lights() -> void:
	var d := DirectionalLight3D.new()
	d.light_energy = 0.8
	d.light_color = Color(1.0, 0.93, 0.85)
	d.rotation_degrees = Vector3(-30, 0, 0)
	d.shadow_enabled = false
	add_child(d)
	_lights.append(d)
	for sx in [-1.0, 1.0]:
		var o := OmniLight3D.new()
		o.position = Vector3(sx * 6.0, 3.0, -3.5)
		o.omni_range = 14.0
		o.light_energy = 2.0
		add_child(o)
		_lights.append(o)
	var f := OmniLight3D.new()
	f.position = Vector3(0, 3.5, 5.0)
	f.omni_range = 12.0
	f.light_energy = 0.7
	add_child(f)
	_lights.append(f)


func _build_confetti() -> void:
	_confetti = CPUParticles3D.new()
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.explosiveness = 0.85
	_confetti.amount = 280
	_confetti.lifetime = 3.2
	_confetti.direction = Vector3.UP
	_confetti.spread = 55.0
	_confetti.initial_velocity_min = 4.0
	_confetti.initial_velocity_max = 8.0
	_confetti.gravity = Vector3(0, -5, 0)
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var cm := _mat(Color.WHITE)
	cm.vertex_color_use_as_albedo = true
	q.material = cm
	_confetti.mesh = q
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.5, 0.67, 0.84])
	g.colors = PackedColorArray([Color("E53935"), Color("1E88E5"), Color("43A047"), Color("FDD835"), Color("8E24AA"), Color("FFFFFF")])
	_confetti.color_initial_ramp = g
	add_child(_confetti)


# ---------- mood e camera ----------

func _apply(m: Array[Color]) -> void:
	_mood = m
	_m_band.albedo_color = _k(m[0], 1.4)
	_m_dots.albedo_color = _k(m[1], 1.4)
	_m_ring.albedo_color = _k(m[2], 2.2)
	_m_arch.albedo_color = _k(m[2], 1.8)
	_m_stairs.albedo_color = _k(m[0], 1.05)
	_m_screen.albedo_color = _k(m[0], 1.2)
	_m_stand.albedo_color = _k(m[0], 0.16)
	_m_cone_a.set_shader_parameter("col", Color(m[0].r, m[0].g, m[0].b, 0.2))
	_m_cone_b.set_shader_parameter("col", Color(m[2].r, m[2].g, m[2].b, 0.16))
	_lights[1].light_color = m[0]
	_lights[2].light_color = m[2]
	_lights[3].light_color = m[0].lerp(Color.WHITE, 0.5)


func _set_mood(m: Array[Color], dur: float) -> void:
	if _mtw:
		_mtw.kill()
	var from := _mood.duplicate()
	_mtw = create_tween()
	_mtw.tween_method(func(t: float) -> void:
		var c: Array[Color] = []
		for i in 3:
			c.append(from[i].lerp(m[i], t))
		_apply(c), 0.0, 1.0, dur)


func _cam_to(pos: Vector3, look: Vector3, fov: float, dur: float) -> Tween:
	if _ctw:
		_ctw.kill()
	var p0 := cam.position
	var l0 := _look
	var f0 := cam.fov
	_ctw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ctw.tween_method(func(t: float) -> void:
		cam.position = p0.lerp(pos, t)
		_look = l0.lerp(look, t)
		cam.fov = lerpf(f0, fov, t)
		cam.look_at(_look), 0.0, 1.0, dur)
	return _ctw


# ---------- podi ----------

func _place_spots(n: int) -> void:
	var sp := 0.0 if n < 2 else minf(1.7, 6.0 / (n - 1))
	for i in n:
		var s: Marker3D = get_node("PlayerSpot%d" % i)
		var x := (i - (n - 1) / 2.0) * sp
		s.position = Vector3(x, 0, -2.4 + 0.03 * x * x)
		s.rotation.y = atan2(-x, CAM_Q.z - s.position.z)


func _pod_body(parent: Node3D, silver: Material, dome_m: Material) -> void:
	var col := BoxMesh.new()
	col.size = Vector3(0.55, 1.05, 0.4)
	_add(col, silver, Vector3(0, 0.525, 0), parent)
	var top := BoxMesh.new()
	top.size = Vector3(0.6, 0.05, 0.45)
	_add(top, silver, Vector3(0, 1.075, 0), parent)
	var dome := SphereMesh.new()
	dome.radius = 0.14
	dome.height = 0.14
	dome.is_hemisphere = true
	_add(dome, dome_m, Vector3(0, 1.1, 0), parent)


func setup_players(names: Array[String]) -> void:
	for p in _pods:
		(p.root as Node).queue_free()
		(p.mirror as Node).queue_free()
	_pods.clear()
	var n := mini(names.size(), 6)
	_place_spots(n)
	for i in n:
		var spot: Marker3D = get_node("PlayerSpot%d" % i)
		var silver := StandardMaterial3D.new()
		silver.albedo_color = Color(0.95, 0.96, 1.0)
		silver.metallic = 0.1
		silver.roughness = 0.4
		var dome_m := StandardMaterial3D.new()
		dome_m.albedo_color = RED
		dome_m.emission_enabled = true
		dome_m.emission = RED
		dome_m.emission_energy_multiplier = 1.8
		var root := Node3D.new()
		root.position = spot.position + spot.basis * Vector3(0, 0, 0.45)
		root.rotation.y = spot.rotation.y
		add_child(root)
		_pod_body(root, silver, dome_m)
		var mir := Node3D.new()
		mir.position = root.position
		mir.rotation.y = root.rotation.y
		_mirror.add_child(mir)
		_pod_body(mir, silver, dome_m)
		# targhetta: bordo colorato + pannello scuro + testo
		var border := _mat(PLATE_BLUE)
		var bq := QuadMesh.new()
		bq.size = Vector2(0.54, 0.26)
		_add(bq, border, Vector3(0, 0.84, 0.202), root)
		var pq := QuadMesh.new()
		pq.size = Vector2(0.5, 0.22)
		_add(pq, _mat(Color(0.03, 0.04, 0.1)), Vector3(0, 0.84, 0.205), root)
		var lab := Label3D.new()
		lab.font_size = 36
		lab.pixel_size = 0.0026
		lab.outline_size = 8
		lab.shaded = false
		lab.position = Vector3(0, 0.84, 0.21)
		root.add_child(lab)
		_pods.append({"root": root, "mirror": mir, "dome": dome_m, "border": border, "label": lab, "name": names[i]})
		_label(i, 0)


func _label(i: int, pts: int) -> void:
	(_pods[i].label as Label3D).text = "%s\n%d" % [_pods[i].name, pts]


func _tint(i: int, c: Color, plate: Color) -> void:
	var d: StandardMaterial3D = _pods[i].dome
	d.albedo_color = c
	d.emission = c
	(_pods[i].border as StandardMaterial3D).albedo_color = plate


# ---------- contratto ----------

func play_intro() -> void:
	_set_mood(M_BLUE, 0.3)
	cam.position = Vector3(0, 10, 17)
	_look = Vector3(0, 1.0, 0)
	cam.fov = 45.0
	cam.look_at(_look)
	_cam_to(Vector3(0, 3.2, 12), Vector3(0, 1.4, 0), 40.0, 3.0).finished.connect(func() -> void: intro_finished.emit())


func focus_question() -> void:
	_set_mood(M_QUESTION, 1.0)
	_cam_to(CAM_Q, LOOK_Q, FOV_Q, 1.0)


func show_reveal(results: Dictionary) -> void:
	for i in _pods.size():
		var ok: bool = results.get(i, false)
		_tint(i, GREEN if ok else RED, GREEN if ok else RED)


func update_scores(scores: Dictionary) -> void:
	for i in _pods.size():
		_tint(i, RED, PLATE_BLUE)
		_label(i, int(scores.get(i, 0)))


func celebrate(winner_id: int) -> void:
	_set_mood(M_GOLD, 0.8)
	if winner_id < 0 or winner_id >= _pods.size():
		_cam_to(Vector3(0, 3.2, 12), Vector3(0, 1.4, 0), 40.0, 1.5)
		return
	var p := (get_node("PlayerSpot%d" % winner_id) as Node3D).position
	_cam_to(Vector3(p.x * 0.6, 2.2, p.z + 8.0), p * 0.8 + Vector3(0, 1.0, 0), 40.0, 1.5)
	_confetti.position = p + Vector3(0, 3.0, 1.0)
	_confetti.restart()
	_confetti.emitting = true
