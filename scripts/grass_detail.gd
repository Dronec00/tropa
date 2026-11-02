class_name GrassDetail
extends Node3D

## Ближняя трава настоящими травинками. Ячейки 3x3 м вокруг игрока,
## каждая — один MultiMesh с одним draw call. Дальше работают карточки
## GrassStream: геометрия дорогая, поэтому живёт только под ногами.

const NEAR_CELL := 8.0

var terrain
var paths: Array = []
var bushes: Array = []
var puddles: Array = []
var player: Node3D

var radius := 6.0
var inner_radius := 0.0
var density := 190
var cell := 3.0

var _mesh: ArrayMesh
var _material: ShaderMaterial
var _cells: Dictionary = {}
var _pending: Array = []
var _last_pos := Vector3(INF, 0.0, 0.0)
var _path_hash: Dictionary = {}
var _bush_hash: Dictionary = {}

func setup(terrain_ref, paths_data: Array, bush_data: Array, puddle_data: Array, blades_per_m2: int) -> void:
	terrain = terrain_ref
	paths = paths_data
	bushes = bush_data
	puddles = puddle_data
	density = blades_per_m2

	_mesh = _make_blade_mesh(5)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/grass_blade.gdshader")
	_build_near_indexes()

func _build_near_indexes() -> void:
	_path_hash.clear()
	_bush_hash.clear()
	for path in paths:
		for p in path["points"]:
			_hash_add(_path_hash, p.x, p.z, Vector2(p.x, p.z))
	for b in bushes:
		_hash_add(_bush_hash, b.x, b.z, Vector2(b.x, b.z))

func _hash_add(target: Dictionary, x: float, z: float, value: Vector2) -> void:
	var key := Vector2i(int(floor(x / NEAR_CELL)), int(floor(z / NEAR_CELL)))
	if not target.has(key):
		target[key] = []
	(target[key] as Array).append(value)

func _nearest_in_hash(target: Dictionary, x: float, z: float) -> float:
	var best := 9999.0
	var cx := int(floor(x / NEAR_CELL))
	var cz := int(floor(z / NEAR_CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var bucket = target.get(Vector2i(cx + dx, cz + dz))
			if bucket == null:
				continue
			for p in bucket:
				var d: float = Vector2(p.x - x, p.y - z).length()
				if d < best:
					best = d
	return best

func _process(_delta: float) -> void:
	if player == null or terrain == null:
		return
	_ensure_pending(1)
	var p := player.global_position
	if p.distance_to(_last_pos) < 1.2:
		return
	_last_pos = p
	_rebuild(p)

func _rebuild(p: Vector3) -> void:
	var c0 := Vector2i(int(floor(p.x / cell)), int(floor(p.z / cell)))
	var r := int(ceil(radius / cell))

	for key in _cells.keys():
		var k: Vector2i = key
		var c := Vector3((float(k.x) + 0.5) * cell, 0.0, (float(k.y) + 0.5) * cell)
		var d := Vector2(c.x - p.x, c.z - p.z).length()
		if d > radius + cell * 1.5 or d < inner_radius - cell * 1.5:
			var node = _cells[key]
			if is_instance_valid(node):
				node.queue_free()
			_cells.erase(key)

	_pending.clear()
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var key := Vector2i(c0.x + dx, c0.y + dz)
			if _cells.has(key):
				continue
			var center := Vector3((float(key.x) + 0.5) * cell, 0.0, (float(key.y) + 0.5) * cell)
			var dist := Vector2(center.x - p.x, center.z - p.z).length()
			if dist > radius + cell * 0.5 or dist < inner_radius - cell * 0.5:
				continue
			_pending.append(key)
	_pending.sort_custom(func(a, b):
		var ca := Vector3((float(a.x) + 0.5) * cell, 0.0, (float(a.y) + 0.5) * cell)
		var cb := Vector3((float(b.x) + 0.5) * cell, 0.0, (float(b.y) + 0.5) * cell)
		return ca.distance_squared_to(p) < cb.distance_squared_to(p))

func _ensure_pending(budget: int) -> void:
	var made := 0
	while made < budget and not _pending.is_empty():
		var key: Vector2i = _pending.pop_front()
		if _cells.has(key):
			continue
		_build_cell(key)
		made += 1

func _build_cell(key: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(key)) & 0x7fffffff

	var origin := Vector3(float(key.x) * cell, 0.0, float(key.y) * cell)
	var attempts := int(float(density) * cell * cell)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for i in attempts:
		var x := origin.x + rng.randf() * cell
		var z := origin.z + rng.randf() * cell
		var h: float = terrain.height_at(x, z)
		if h < Terrain.WATER_LEVEL + 0.45:
			continue
		if terrain.slope_at(x, z) > 0.75:
			continue
		if _near_path(x, z, 2.0):
			continue
		if _in_puddle(x, z):
			continue
		if not _near_bush(x, z, 4.5) and rng.randf() > 0.55:
			continue

		var tilt_axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		var basis := (Basis(tilt_axis, rng.randf_range(0.0, 0.25)) * Basis(Vector3.UP, rng.randf() * TAU)).scaled(Vector3(
			rng.randf_range(0.8, 1.3),
			rng.randf_range(0.30, 0.60),
			rng.randf_range(0.8, 1.3)
		))
		transforms.append(Transform3D(basis, Vector3(x, h - 0.02, z) - origin))
		colors.append(Color(rng.randf(), rng.randf(), 0.0))

	if transforms.is_empty():
		_cells[key] = null
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])

	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _material
	node.position = origin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_cells[key] = node

func _near_path(x: float, z: float, radius_check: float) -> bool:
	if _path_hash.is_empty():
		return false
	return _nearest_in_hash(_path_hash, x, z) < radius_check

func _in_puddle(x: float, z: float) -> bool:
	for pd in puddles:
		var pp: Vector3 = pd["pos"]
		if Vector2(pp.x - x, pp.z - z).length() < float(pd["radius"]) * 1.25:
			return true
	return false

func _near_bush(x: float, z: float, r: float) -> bool:
	if _bush_hash.is_empty():
		return false
	return _nearest_in_hash(_bush_hash, x, z) < r

static func _make_blade_mesh(segments: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in segments + 1:
		var t := float(i) / float(segments)
		var z := 0.30 * t * t
		var w := 0.009 * pow(1.0 - t, 0.7) + 0.0015
		verts.append(Vector3(-w, t, z))
		verts.append(Vector3(w, t, z))
		normals.append(Vector3(0.0, 0.35, 1.0).normalized())
		normals.append(Vector3(0.0, 0.35, 1.0).normalized())
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))

	for i in segments:
		var a := i * 2
		indices.append(a)
		indices.append(a + 1)
		indices.append(a + 3)
		indices.append(a)
		indices.append(a + 3)
		indices.append(a + 2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
