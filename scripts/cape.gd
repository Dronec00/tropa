class_name Cape
extends MeshInstance3D

const WindScript := preload("res://scripts/wind.gd")

## Накидка рыцаря: сетка точек на верёвочной симуляции.
## Реагирует на бег (поток воздуха относителен тела) и на глобальный ветер.

const COLS := 6
const ROWS := 8
const STEP := 1.0 / 60.0

var body: CharacterBody3D

var width := 0.56
var length := 1.02
var top_y := 1.44
var top_z := 0.22
var body_radius := 0.29

var _pts := PackedVector3Array()
var _prev := PackedVector3Array()
var _accum := 0.0
var _immediate := ImmediateMesh.new()

func _ready() -> void:
	_init_points()
	mesh = _immediate

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.095, 0.09)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.metallic_specular = 0.1
	material_override = mat

func _init_points() -> void:
	_pts.resize(COLS * ROWS)
	_prev.resize(COLS * ROWS)
	for r in ROWS:
		for c in COLS:
			var u := float(c) / float(COLS - 1)
			var v := float(r) / float(ROWS - 1)
			var p := Vector3(lerpf(-width * 0.5, width * 0.5, u), top_y - length * v, top_z)
			var i := r * COLS + c
			_pts[i] = p
			_prev[i] = p

func _process(delta: float) -> void:
	_accum += minf(delta, 0.08)
	var guard := 0
	while _accum >= STEP and guard < 4:
		_accum -= STEP
		guard += 1
		_simulate(STEP)
	_rebuild()

func _simulate(dt: float) -> void:
	var basis := global_transform.basis
	var local_vel := basis.inverse() * (body.velocity if body and is_instance_valid(body) else Vector3.ZERO)
	local_vel.y = 0.0

	# поток воздуха от бега + ветер
	var drag := -local_vel * 1.15
	var wind_vector: Vector3 = WindScript.direction * WindScript.strength * 2.4
	var wind_local := basis.inverse() * wind_vector
	var accel: Vector3 = Vector3(0, -9.5, 0) + drag + wind_local

	for i in _pts.size():
		if i < COLS:
			continue
		var p := _pts[i]
		var velocity := (p - _prev[i]) * 0.965
		_prev[i] = p
		_pts[i] = p + velocity + accel * dt * dt

	for _iteration in 3:
		for r in ROWS:
			for c in COLS:
				var i := r * COLS + c
				if r > 0:
					_constrain(i, i - COLS, length / float(ROWS - 1))
				if c > 0:
					_constrain(i, i - 1, width / float(COLS - 1))

	# не проваливаться в тело и в землю
	for i in _pts.size():
		if i < COLS:
			continue
		var p := _pts[i]
		var flat := Vector2(p.x, p.z)
		if p.y < top_y - 0.28 and flat.length() < body_radius:
			var dir: Vector2 = flat.normalized() if flat.length() > 0.001 else Vector2(0.0, 1.0)
			p.x = dir.x * body_radius
			p.z = dir.y * body_radius
		p.y = maxf(p.y, 0.12)
		_pts[i] = p

func _constrain(a: int, b: int, rest: float) -> void:
	var delta := _pts[b] - _pts[a]
	var dist := delta.length()
	if dist < 0.0001:
		return
	var correction := delta * (1.0 - rest / dist)
	if a < COLS:
		_pts[b] -= correction
	elif b < COLS:
		_pts[a] += correction
	else:
		_pts[a] += correction * 0.5
		_pts[b] -= correction * 0.5

func _rebuild() -> void:
	_immediate.clear_surfaces()
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material_override)

	for r in ROWS - 1:
		for c in COLS - 1:
			var a := _pts[r * COLS + c]
			var b := _pts[r * COLS + c + 1]
			var d := _pts[(r + 1) * COLS + c]
			var e := _pts[(r + 1) * COLS + c + 1]
			var normal := (b - a).cross(d - a).normalized()
			_add_tri(a, d, b, normal)
			_add_tri(b, d, e, normal)

	_immediate.surface_end()

func _add_tri(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	_immediate.surface_set_normal(normal)
	_immediate.surface_add_vertex(a)
	_immediate.surface_set_normal(normal)
	_immediate.surface_add_vertex(b)
	_immediate.surface_set_normal(normal)
	_immediate.surface_add_vertex(c)
