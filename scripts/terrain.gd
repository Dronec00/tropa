class_name Terrain
extends Node3D

## Холмистая местность с руслом реки.
## Высоты считаются один раз в массив, меш и коллизия строятся из него же,
## поэтому визуал и физика всегда совпадают.

const SIZE := 340.0
const HALF := 170.0
const STEP := 1.0
const GRID := 341

const WATER_LEVEL := -1.7
const EDGE_RIVER_IN := 143.0
const EDGE_RIVER_OUT := 165.0
const EDGE_HILL_TOP := 178.0

var STREAMS := [
	PackedVector2Array([
		Vector2(-44, -102), Vector2(-26, -70), Vector2(-6, -41),
		Vector2(15, -17), Vector2(35, -3), Vector2(48, 4),
	]),
	PackedVector2Array([
		Vector2(-80, -12), Vector2(-55, -3), Vector2(-29, 12),
		Vector2(-3, 26), Vector2(23, 41), Vector2(45, 54), Vector2(55, 59),
	]),
]
const RIVER_BED := -4.2

const WATER_SHADER := preload("res://shaders/water.gdshader")

var _heights := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _mesh: ArrayMesh

func _ready() -> void:
	_noise.seed = 4815
	_noise.frequency = 0.011
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.5

	_detail.seed = 991
	_detail.frequency = 0.09
	_detail.fractal_octaves = 2

	_generate_heights()
	_build_mesh()
	pass
	_build_streams()
	_build_edge_river()

# --- высоты ---

func river_center(z: float) -> float:
	return 30.0 + 7.0 * sin(z * 0.015 + 0.6) + 3.0 * sin(z * 0.05)

func river_influence(_x: float, _z: float) -> float:
	# Большая река убрана: остались только ручьи и кольцевая река по краю мира.
	return 0.0

func _raw_height(x: float, z: float) -> float:
	var h := 2.5 + _noise.get_noise_2d(x, z) * 9.0
	h += _detail.get_noise_2d(x, z) * 0.5
	h = maxf(h, 0.3)

	# поляна у костра — ровная
	var dist := Vector2(x, z).length()
	h = lerpf(h, 0.0, 1.0 - smoothstep(7.0, 15.0, dist))

	# ручьи: неглубокие промоины
	var sd := stream_distance(x, z)
	if sd < 5.0:
		h -= (1.0 - smoothstep(1.1, 4.5, sd)) * 1.3

	# кольцевая река по краю мира
	var r := Vector2(x, z).length()
	var ring := smoothstep(EDGE_RIVER_IN - 3.0, EDGE_RIVER_IN, r) * (1.0 - smoothstep(EDGE_RIVER_OUT - 3.0, EDGE_RIVER_OUT, r))
	if ring > 0.001:
		h = lerpf(h, WATER_LEVEL - 2.8, ring)

	# низкие холмы за рекой
	if r > EDGE_RIVER_OUT - 2.0:
		var hill := smoothstep(EDGE_RIVER_OUT - 2.0, EDGE_HILL_TOP, r)
		h = lerpf(h, 3.4 + _noise.get_noise_2d(x * 0.5, z * 0.5) * 1.4, hill)

	# русло реки
	var influence := river_influence(x, z)
	if influence > 0.001:
		var bed := RIVER_BED + _detail.get_noise_2d(x * 0.6, z * 0.6) * 0.4
		h = lerpf(h, bed, influence)

	return h

func _generate_heights() -> void:
	_heights.resize(GRID * GRID)
	for j in GRID:
		var z := -HALF + float(j) * STEP
		for i in GRID:
			var x := -HALF + float(i) * STEP
			_heights[j * GRID + i] = _raw_height(x, z)

func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var fx := clampf((x + HALF) / STEP, 0.0, float(GRID - 1) - 0.001)
	var fz := clampf((z + HALF) / STEP, 0.0, float(GRID - 1) - 0.001)
	var i := int(floor(fx))
	var j := int(floor(fz))
	var tx := fx - float(i)
	var tz := fz - float(j)
	var h00 := _heights[j * GRID + i]
	var h10 := _heights[j * GRID + i + 1]
	var h01 := _heights[(j + 1) * GRID + i]
	var h11 := _heights[(j + 1) * GRID + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func stream_points() -> Array:
	return STREAMS

func stream_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 999.0
	for stream in STREAMS:
		for i in stream.size() - 1:
			var a: Vector2 = stream[i]
			var b: Vector2 = stream[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best

func is_water(x: float, z: float) -> bool:
	var r := Vector2(x, z).length()
	if r > EDGE_RIVER_IN - 1.0 and r < EDGE_RIVER_OUT:
		return true
	if stream_distance(x, z) > 5.0:
		return false
	return height_at(x, z) < WATER_LEVEL

func slope_at(x: float, z: float) -> float:
	var h := height_at(x, z)
	var hx := height_at(x + STEP, z)
	var hz := height_at(x, z + STEP)
	return Vector2(hx - h, hz - h).length()

# --- меш ---

func _build_mesh() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var total := GRID * GRID
	verts.resize(total)
	normals.resize(total)
	uvs.resize(total)
	colors.resize(total)

	var grass := Color(0.11, 0.15, 0.07)
	var dry_grass := Color(0.17, 0.16, 0.10)
	var rock := Color(0.16, 0.16, 0.15)
	var mud := Color(0.10, 0.09, 0.07)
	var litter := Color(0.19, 0.15, 0.09)

	for j in GRID:
		var z := -HALF + float(j) * STEP
		for i in GRID:
			var x := -HALF + float(i) * STEP
			var idx := j * GRID + i
			var h := _heights[idx]
			verts[idx] = Vector3(x, h, z)

			var hl := _heights[j * GRID + maxi(i - 1, 0)]
			var hr := _heights[j * GRID + mini(i + 1, GRID - 1)]
			var hd := _heights[maxi(j - 1, 0) * GRID + i]
			var hu := _heights[mini(j + 1, GRID - 1) * GRID + i]
			var n := Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
			normals[idx] = n
			uvs[idx] = Vector2(x, z) * 0.12

			var slope := 1.0 - n.y
			var base := grass.lerp(dry_grass, clampf(_detail.get_noise_2d(x * 0.7, z * 0.7) * 0.5 + 0.5, 0.0, 1.0))
			base = base.lerp(litter, clampf(_detail.get_noise_2d(x * 0.35 + 11.0, z * 0.35) * 0.5 + 0.3, 0.0, 1.0) * 0.55)
			base = base.lerp(rock, smoothstep(0.16, 0.44, slope))
			base = base.lerp(mud, 1.0 - smoothstep(WATER_LEVEL + 0.1, WATER_LEVEL + 1.5, h))
			var shade := 0.85 + _detail.get_noise_2d(x * 2.3, z * 2.3) * 0.15
			colors[idx] = Color(base.r * shade, base.g * shade, base.b * shade)

	for j in GRID - 1:
		for i in GRID - 1:
			var v00 := j * GRID + i
			var v10 := v00 + 1
			var v01 := (j + 1) * GRID + i
			var v11 := v01 + 1
			indices.append(v00)
			indices.append(v10)
			indices.append(v01)
			indices.append(v10)
			indices.append(v11)
			indices.append(v01)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material: Material
	if ResourceLoader.exists("res://assets/textures/photo4k/ground_a_color.jpg"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/ground.gdshader")
		mat.set_shader_parameter("albedo_a", load("res://assets/textures/photo4k/ground_a_color.jpg"))
		mat.set_shader_parameter("albedo_b", load("res://assets/textures/photo4k/ground_b_color.jpg"))
		mat.set_shader_parameter("normal_a", load("res://assets/textures/photo4k/ground_a_normal.jpg"))
		mat.set_shader_parameter("normal_b", load("res://assets/textures/photo4k/ground_b_normal.jpg"))
		mat.set_shader_parameter("rough_a", load("res://assets/textures/photo4k/ground_a_rough.jpg"))
		mat.set_shader_parameter("rough_b", load("res://assets/textures/photo4k/ground_b_rough.jpg"))
		mat.set_shader_parameter("tint", Color(0.85, 0.71, 0.52))
		material = mat
	else:
		var std := StandardMaterial3D.new()
		std.vertex_color_use_as_albedo = true
		std.roughness = 1.0
		std.uv1_scale = Vector3(4.0, 4.0, 1.0)
		if ResourceLoader.exists("res://assets/textures/photo/ground_color.jpg"):
			std.albedo_color = Color(0.95, 0.66, 0.44)
			std.albedo_texture = load("res://assets/textures/photo/ground_color.jpg")
			std.roughness_texture = load("res://assets/textures/photo/ground_rough.jpg")
			std.normal_enabled = true
			std.normal_texture = load("res://assets/textures/photo/ground_normal.jpg")
		material = std
	_mesh.surface_set_material(0, material)

	var view := MeshInstance3D.new()
	view.mesh = _mesh
	add_child(view)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = _mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)

# --- вода ---

func _build_water() -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var half_width := 8.0
	var z := -HALF
	var row := 0
	while z <= HALF:
		var center := river_center(z)
		verts.append(Vector3(center - half_width, WATER_LEVEL, z))
		verts.append(Vector3(center + half_width, WATER_LEVEL, z))
		uvs.append(Vector2(0.0, z * 0.05))
		uvs.append(Vector2(1.0, z * 0.05))
		if row > 0:
			var a := (row - 1) * 2
			var b := a + 1
			var c := row * 2
			var d := c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)
		row += 1
		z += 2.0

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var water_mesh := ArrayMesh.new()
	water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var shader: Shader = WATER_SHADER

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ripple", _make_ripple_texture())

	var water := MeshInstance3D.new()
	water.mesh = water_mesh
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _build_streams() -> void:
	var shader: Shader = WATER_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ripple", _make_ripple_texture())
	material.set_shader_parameter("shallow_color", Color(0.17, 0.23, 0.23, 1.0))
	material.set_shader_parameter("deep_color", Color(0.03, 0.07, 0.08, 1.0))
	material.set_shader_parameter("flow", 0.09)
	material.set_shader_parameter("deep_color", Color(0.02, 0.05, 0.06, 1.0))

	for stream in STREAMS:
		var samples := _resample(stream, 1.6)
		if samples.size() < 2:
			continue
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		var half := 1.95

		for i in samples.size():
			var p: Vector2 = samples[i]
			var prev: Vector2 = samples[maxi(i - 1, 0)]
			var next: Vector2 = samples[mini(i + 1, samples.size() - 1)]
			var dir := (next - prev).normalized()
			var side := Vector2(-dir.y, dir.x)
			var y := height_at(p.x, p.y) + 0.26
			verts.append(Vector3(p.x + side.x * half, y, p.y + side.y * half))
			verts.append(Vector3(p.x - side.x * half, y, p.y - side.y * half))
			uvs.append(Vector2(0.0, float(i) * 0.3))
			uvs.append(Vector2(1.0, float(i) * 0.3))

			if i > 0:
				var a := (i - 1) * 2
				var b := a + 1
				var c := i * 2
				var d := c + 1
				indices.append(a)
				indices.append(c)
				indices.append(b)
				indices.append(b)
				indices.append(c)
				indices.append(d)

		if indices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices

		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var water := MeshInstance3D.new()
		water.mesh = mesh
		water.material_override = material
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)


func _build_edge_river() -> void:
	var segs := 160
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var r_in := EDGE_RIVER_IN + 1.0
	var r_out := EDGE_RIVER_OUT - 2.0

	for i in segs + 1:
		var a := TAU * float(i) / float(segs)
		var dir := Vector2(cos(a), sin(a))
		for k in 2:
			var rr := r_in if k == 0 else r_out
			var p := dir * rr
			verts.append(Vector3(p.x, WATER_LEVEL, p.y))
			uvs.append(Vector2(float(k), float(i) / float(segs) * 8.0))
		if i > 0:
			var a0 := (i - 1) * 2
			indices.append(a0)
			indices.append(a0 + 2)
			indices.append(a0 + 1)
			indices.append(a0 + 1)
			indices.append(a0 + 2)
			indices.append(a0 + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("ripple", _make_ripple_texture())
	mat.set_shader_parameter("shallow_color", Color(0.10, 0.16, 0.17, 1.0))
	mat.set_shader_parameter("deep_color", Color(0.02, 0.05, 0.06, 1.0))
	mat.set_shader_parameter("flow", 0.05)

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)

func _resample(points: PackedVector2Array, step: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if points.size() < 2:
		return result
	var acc := 0.0
	result.append(points[0])
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		var t := step
		while t < seg:
			result.append(a.lerp(b, t / seg))
			t += step
	return result

func _make_ripple_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.04
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	return tex
