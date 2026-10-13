extends Node
## Regista TV: camera sempre in movimento, stacchi netti. Contratto in PLAN.md (R).

const FACE := 1.5  # altezza dei volti

var _cam: Camera3D
var _stage: Node3D
var _host: Node3D
var _angles: Array[Dictionary] = []
var _i := 0
var _t := 0.0
var _clock := 0.0
var _shake := 0.0


func setup(cam: Camera3D, stage: Node3D, host: Node3D) -> void:
	_cam = cam
	_stage = stage
	_host = host


func shake(strength: float = 1.0) -> void:
	_shake = maxf(_shake, strength)


func shot(shot_name: String, focus: int = -1) -> void:
	_angles.clear()
	_i = 0
	_t = 0.0
	var f := clampi(focus, 0, maxi(_n() - 1, 0))
	var mid := func() -> Vector3: return _mid()
	var hp := func() -> Vector3: return _host.global_position
	var sp := func() -> Vector3: return _spot(f)
	var org := func() -> Vector3: return Vector3.ZERO
	match shot_name:
		"intro":
			_a(org, Vector3(0, 10, 17), Vector3(0, 3.4, 12), Vector3(0, 1, 0), Vector3(0, 1.4, 0), 46, 40, 3.2)
			_a(mid, Vector3(-4.5, 0.7, 5.5), Vector3(-2, 1.0, 4.2), Vector3(0, 1.6, -1), Vector3(0, 1.6, -1), 40, 36, 3.0)
			_a(mid, Vector3(-4, 1.3, 1.2), Vector3(4, 1.3, 1.2), Vector3(0, 1.6, -3), Vector3(0, 1.6, -3), 42, 42, 3.5)
			_o(org, 11.0, 3.5, 3.0, 0.6, -0.4, 1.4, 42, 4.0)
		"wide":
			_o(org, 11.0, 3.5, 3.0, -0.5, 0.3, 1.4, 42, 5.0)
			_a(org, Vector3(-6, 2.0, 10), Vector3(6, 2.2, 10), Vector3(0, 1.5, -2), Vector3(0, 1.5, -2), 42, 42, 4.5)
			_a(org, Vector3(0, 8, 10), Vector3(0, 5.5, 12), Vector3(0, 1, 0), Vector3(0, 1, 0), 44, 40, 4.0)
		"question":
			var fv := 40.0
			var d := _qd(fv)
			_a(mid, Vector3(0, 1.6, d * 1.1), Vector3(0, 1.9, d * 0.95), Vector3(0, 2.1, 0), Vector3(0, 2.1, 0), fv, fv, 4.5)
			_a(mid, Vector3(-1.5, 1.0, d), Vector3(1.5, 1.1, d), Vector3(0, 1.9, 0), Vector3(0, 1.9, 0), fv, fv, 4.0)
			_a(mid, Vector3(0.5, 3.6, d), Vector3(-0.5, 3.0, d * 0.95), Vector3(0, 1.1, 0), Vector3(0, 1.1, 0), fv, fv, 4.0)
		"host":
			_a(hp, Vector3(0.4, 0.6, 3.4), Vector3(0.2, 0.9, 2.2), Vector3(0, 1.5, 0), Vector3(0, 1.6, 0), 34, 34, 3.8)
			_o(hp, 2.8, 1.5, 1.5, 0.9, 0.2, 1.5, 32, 4.0)
			_a(hp, Vector3(-3.2, 1.4, 1.2), Vector3(-2.4, 1.5, 1.9), Vector3(0, 1.55, 0), Vector3(0, 1.55, 0), 30, 30, 3.5)
		"player":
			_a(sp, Vector3(0.3, 0.5, 3.0), Vector3(0, 0.8, 2.2), Vector3(0, 1.4, 0), Vector3(0, 1.4, 0), 30, 30, 3.5)
			_o(sp, 2.4, 1.6, 1.4, -0.7, -0.1, 1.4, 32, 4.0)
			_a(sp, Vector3(0.8, 3.0, 2.6), Vector3(0.4, 2.6, 2.1), Vector3(0, 1.2, 0), Vector3(0, 1.2, 0), 32, 32, 3.2)
		"reveal":
			for k in maxi(_n(), 1):
				var s := func() -> Vector3: return _spot(k)
				var sx := 1.0 if k % 2 == 0 else -1.0
				_a(s, Vector3(0.3 * sx, 1.5, 2.8), Vector3(0.1 * sx, 1.5, 1.9), Vector3(0, FACE, 0), Vector3(0, FACE, 0), 30, 28, 1.0)
		"scores":
			_a(mid, Vector3(-5, 1.2, 8), Vector3(5, 1.4, 8), Vector3(0, 1.2, 0), Vector3(0, 1.2, 0), 38, 38, 5.0)
			_a(mid, Vector3(0, 5, 8), Vector3(0, 3.4, 9), Vector3(0, 1, 0), Vector3(0, 1, 0), 38, 38, 4.0)
			_a(mid, Vector3(0, 0.6, 7), Vector3(0, 1.0, 5.5), Vector3(0, 1.6, 0), Vector3(0, 1.6, 0), 36, 36, 4.0)
		"winner":
			_o(sp, 3.2, 0.8, 1.2, -0.9, 0.9, 1.4, 38, 4.5)
			_o(sp, 2.2, 0.5, 0.9, 0.6, -0.6, 1.5, 32, 4.0)
			_a(sp, Vector3(0, 3.5, 4), Vector3(0, 2.6, 3), Vector3(0, 1.2, 0), Vector3(0, 1.2, 0), 38, 38, 3.5)


func _process(delta: float) -> void:
	if _cam == null or _angles.is_empty():
		return
	_t += delta
	var a := _angles[_i]
	if _t >= a.dur:
		_t = 0.0
		_i = (_i + 1) % _angles.size()
		a = _angles[_i]
	var k: float = _t / a.dur
	var e := lerpf(k, smoothstep(0.0, 1.0, k), 0.5)
	var c: Vector3 = a.s.call()
	var pos: Vector3
	if a.has("orb"):
		var ang := lerpf(a.a0, a.a1, e)
		pos = c + Vector3(sin(ang) * a.r, lerpf(a.h0, a.h1, e), cos(ang) * a.r)
	else:
		pos = c + (a.p0 as Vector3).lerp(a.p1, e)
	var look: Vector3 = c + (a.l0 as Vector3).lerp(a.l1, e)
	# handheld leggero
	_clock += delta
	var hh := Vector3(sin(_clock * 1.3) + 0.5 * sin(_clock * 2.9), sin(_clock * 1.7 + 1.0), sin(_clock * 1.1 + 2.0)) * 0.012
	pos += hh
	look += hh * 3.0
	if _shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.12 * _shake
	_cam.global_position = pos
	_cam.fov = lerpf(a.f0, a.f1, e)
	_cam.look_at(look)
	if _shake > 0.0:
		_cam.rotate_object_local(Vector3(0, 0, 1), randf_range(-1, 1) * 0.03 * _shake)
		_shake = move_toward(_shake, 0.0, delta * 2.5)


# ---------- helpers ----------

func _a(s: Callable, p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3, f0: float, f1: float, dur: float) -> void:
	_angles.append({"s": s, "p0": p0, "p1": p1, "l0": l0, "l1": l1, "f0": f0, "f1": f1, "dur": dur})


func _o(s: Callable, r: float, h0: float, h1: float, a0: float, a1: float, lk: float, fov: float, dur: float) -> void:
	_angles.append({"s": s, "orb": true, "r": r, "h0": h0, "h1": h1, "a0": a0, "a1": a1,
			"l0": Vector3(0, lk, 0), "l1": Vector3(0, lk, 0), "f0": fov, "f1": fov, "dur": dur})


func _n() -> int:
	var p: Variant = _stage.get("_pods")
	return (p as Array).size() if p != null else 6


func _spot(i: int) -> Vector3:
	return (_stage.get_node("PlayerSpot%d" % i) as Node3D).global_position


func _mid() -> Vector3:
	var lo := INF
	var hi := -INF
	for i in maxi(_n(), 1):
		lo = minf(lo, _spot(i).x)
		hi = maxf(hi, _spot(i).x)
	return Vector3((lo + hi) / 2.0, 0, _spot(0).z)


## distanza a cui tutti i concorrenti stanno nella fascia centrale (40% della larghezza)
func _qd(fov: float) -> float:
	var lo := INF
	var hi := -INF
	for i in maxi(_n(), 1):
		lo = minf(lo, _spot(i).x)
		hi = maxf(hi, _spot(i).x)
	var w := 2.0 * tan(deg_to_rad(fov) / 2.0) * 16.0 / 9.0
	return clampf((hi - lo + 1.4) / 0.4 / w, 5.0, 14.0)
