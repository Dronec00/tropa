class_name Terrain
extends Node3D

## Холмистая местность с руслом реки.
## Высоты считаются один раз в массив, меш и коллизия строятся из него же,
## поэтому визуал и физика всегда совпадают.

const SIZE := 200.0
const HALF := 100.0
const STEP := 1.0
const GRID := 201

const WATER_LEVEL := -1.7

var STREAMS := [
	PackedVector2Array([
		Vector2(-30, -70), Vector2(-18, -48), Vector2(-4, -28),
		Vector2(10, -12), Vector2(24, -2), Vector2(33, 3),
	]),
	PackedVector2Array([
		Vector2(-55, -8), Vector2(-38, -2), Vector2(-20, 8),
		Vector2(-2, 18), Vector2(16, 28), Vector2(31, 37), Vector2(38, 41),
	]),
]
const RIVER_BED := -4.2

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.13, 0.21, 0.22, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.06, 0.07, 1.0);
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float flow = 0.035;

void fragment() {
	vec2 uv_a = UV * vec2(5.0, 1.6) + vec2(TIME * flow, TIME * flow * 2.0);
	vec2 uv_b = UV * vec2(2.4, 0.9) - vec2(TIME * flow * 0.7, TIME * flow * 1.3);
	vec3 n_a = texture(ripple, uv_a).xyz * 2.0 - 1.0;
	vec3 n_b = texture(ripple, uv_b).xyz * 2.0 - 1.0;
	NORMAL = normalize(vec3((n_a.x + n_b.x) * 0.55, 1.0, (n_a.y + n_b.y) * 0.55));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, fres * 0.8 + 0.15);
	ALPHA = 0.92;
	ROUGHNESS = 0.04;
	SPECULAR = 0.8;
	EMISSION = shallow_color.rgb * fres * 0.35;
}
"""

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
	_build_water()
	_build_streams()

# --- высоты ---

func river_center(z: float) -> float:
	return 30.0 + 7.0 * sin(z * 0.015 + 0.6) + 3.0 * sin(z * 0.05)

func river_influence(x: float, z: float) -> float:
	var d := absf(x - river_center(z))
	return 1.0 - smoothstep(7.0, 15.0, d)

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
	if absf(x - river_center(z)) > 16.0:
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

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.uv1_scale = Vector3(4.0, 4.0, 1.0)

	if ResourceLoader.exists("res://assets/textures/ground_albedo.png"):
		material.albedo_texture = load("res://assets/textures/ground_albedo.png")
		material.roughness_texture = load("res://assets/textures/ground_rough.png")
		material.normal_enabled = true
		material.normal_texture = load("res://assets/textures/ground_normal.png")
		material.normal_scale = 0.9
	material.metallic_specular = 0.0
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

	var shader := Shader.new()
	shader.code = WATER_SHADER

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ripple", _make_ripple_texture())

	var water := MeshInstance3D.new()
	water.mesh = water_mesh
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _build_streams() -> void:
	var shader := Shader.new()
	shader.code = WATER_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ripple", _make_ripple_texture())
	material.set_shader_parameter("shallow_color", Color(0.17, 0.23, 0.23, 1.0))
	material.set_shader_parameter("deep_color", Color(0.03, 0.07, 0.08, 1.0))
	material.set_shader_parameter("flow", 0.09)

	for stream in STREAMS:
		var samples := _resample(stream, 1.6)
		if samples.size() < 2:
			continue
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		var half := 1.25

		for i in samples.size():
			var p: Vector2 = samples[i]
			var prev: Vector2 = samples[maxi(i - 1, 0)]
			var next: Vector2 = samples[mini(i + 1, samples.size() - 1)]
			var dir := (next - prev).normalized()
			var side := Vector2(-dir.y, dir.x)
			var y := height_at(p.x, p.y) + 0.5
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
