class_name GrassStream
extends Node3D

## Потоковая трава: чанки 12x12 м создаются вокруг игрока и выгружаются позади.
## Плотность внутри чанка задаётся числом пучков, детерминированно по координатам.

const CHUNK := 12.0
const NEAR_CELL := 8.0

var terrain
var paths: Array = []
var bushes: Array = []
var puddles: Array = []
var player: Node3D

var radius := 46.0
var per_chunk := 800
var cells := {}

var _mesh: ArrayMesh
var _material: ShaderMaterial
var _last_pos := Vector3(INF, 0, 0)
var _pending: Array = []
var _path_hash := {}
var _bush_hash := {}

func setup(terrain_ref, paths_data: Array, bush_data: Array, puddle_data: Array, density: int) -> void:
	terrain = terrain_ref
	paths = paths_data
	bushes = bush_data
	puddles = puddle_data
	per_chunk = density

	_mesh = GrassField.make_tuft_mesh()
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/grass.gdshader")
	_material.set_shader_parameter("tuft", load("res://assets/textures/grass_tuft.png"))
	_build_near_indexes()

func _build_near_indexes() -> void:
	# Индекс по клеткам 8 м: пучок травы ищет тропы и кусты только рядом,
	# а не перебирает тысячи точек на каждый из 800 пучков в чанке.
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
	_ensure_pending(2)
	var p := player.global_position
	if p.distance_to(_last_pos) < 2.0:
		return
	_last_pos = p
	_rebuild_around(p)

func _rebuild_around(p: Vector3) -> void:
	var c0 := Vector2i(int(floor(p.x / CHUNK)), int(floor(p.z / CHUNK)))
	var r_chunks := int(ceil(radius / CHUNK))

	# сначала выгружаем далёкие
	for key in cells.keys():
		var k: Vector2i = key
		if absi(k.x - c0.x) > r_chunks + 1 or absi(k.y - c0.y) > r_chunks + 1:
			var node = cells[key]
			if is_instance_valid(node):
				node.queue_free()
			cells.erase(key)

	# затем ставим в очередь ближние
	_pending.clear()
	for dz in range(-r_chunks, r_chunks + 1):
		for dx in range(-r_chunks, r_chunks + 1):
			var key := Vector2i(c0.x + dx, c0.y + dz)
			if cells.has(key):
				continue
			var center := Vector3((float(key.x) + 0.5) * CHUNK, 0.0, (float(key.y) + 0.5) * CHUNK)
			if Vector2(center.x - p.x, center.z - p.z).length() > radius:
				continue
			_pending.append(key)
	_pending.sort_custom(func(a, b):
		var ca := Vector3((float(a.x) + 0.5) * CHUNK, 0.0, (float(a.y) + 0.5) * CHUNK)
		var cb := Vector3((float(b.x) + 0.5) * CHUNK, 0.0, (float(b.y) + 0.5) * CHUNK)
		return ca.distance_squared_to(p) < cb.distance_squared_to(p))

func _ensure_pending(budget: int) -> void:
	var made := 0
	while made < budget and not _pending.is_empty():
		var key: Vector2i = _pending.pop_front()
		if cells.has(key):
			continue
		_build_chunk(key)
		made += 1

func _build_chunk(key: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(key)) & 0x7fffffff

	var origin := Vector3(float(key.x) * CHUNK, 0.0, float(key.y) * CHUNK)
	var transforms: Array = []
	var colors: Array = []
	# чанк целиком вдали от ручьёв — не гоняем stream_distance на каждый пучок
	var near_stream: bool = terrain.stream_distance(
		origin.x + CHUNK * 0.5, origin.z + CHUNK * 0.5
	) < CHUNK + 3.0

	for i in per_chunk:
		var x := origin.x + rng.randf() * CHUNK
		var z := origin.z + rng.randf() * CHUNK
		var h: float = terrain.height_at(x, z)
		if h < Terrain.WATER_LEVEL + 0.45:
			continue
		if near_stream and terrain.stream_distance(x, z) < 2.1:
			continue
		if terrain.slope_at(x, z) > 0.75:
			continue
		if _near_path(x, z, 2.0):
			continue
		if _near_path(x, z, 4.0) and rng.randf() > 0.45:
			continue
		if _in_puddle(x, z):
			continue
		var near_bush := _near_bush(x, z, 4.5)
		if not near_bush and rng.randf() > 0.55:
			continue

		var e := 0.6
		var normal := Vector3(
			terrain.height_at(x - e, z) - terrain.height_at(x + e, z),
			2.0 * e,
			terrain.height_at(x, z - e) - terrain.height_at(x, z + e)
		).normalized()
		var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.20, 0.42), rng.randf_range(0.8, 1.2)))
		transforms.append(Transform3D(basis, Vector3(x, h - 0.03, z)))

		var roll := rng.randf()
		var variant := 0.0
		if roll < 0.50:
			variant = 0.0
		elif roll < 0.75:
			variant = 0.25
		elif roll < 0.90:
			variant = 0.50
		else:
			variant = 0.75
		colors.append(Color(rng.randf(), rng.randf(), variant))

	if transforms.is_empty():
		cells[key] = null
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		mm.set_instance_transform(i, Transform3D(t.basis, t.origin - origin))
		mm.set_instance_color(i, colors[i])

	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _material
	node.position = origin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	cells[key] = node

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
