class_name GrassField
extends MultiMeshInstance3D

## Трава на MultiMesh: один меш-лепесток, тысячи инстансов, ветер в шейдере.

const TerrainScript := preload("res://scripts/terrain.gd")

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec3 grass_base : source_color = vec3(0.12, 0.16, 0.07);
uniform vec3 grass_tip : source_color = vec3(0.42, 0.50, 0.22);
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.35;

varying float v_height;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.42 + world.z * 0.35;
	float sway = sin(TIME * wind_speed + phase) * 0.65
		+ sin(TIME * wind_speed * 2.6 + phase * 1.7) * 0.25;
	float h = clamp(VERTEX.y, 0.0, 1.0);
	VERTEX.x += sway * wind_strength * h * h;
	VERTEX.z += sway * wind_strength * 0.55 * h * h;
	v_height = h;
}

void fragment() {
	ALBEDO = mix(grass_base, grass_tip, v_height * v_height);
	ROUGHNESS = 0.95;
	BACKLIGHT = vec3(0.10, 0.13, 0.05);
}
"""

func populate(terrain: Node3D, amount: int = 12000, radius: float = 55.0) -> void:
	var blade := _make_blade_mesh()

	var shader := Shader.new()
	shader.code = GRASS_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade
	multimesh.instance_count = amount

	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = radius + 25.0
	visibility_range_end_margin = 10.0

	var rng := RandomNumberGenerator.new()
	rng.seed = 1907

	var placed := 0
	var attempts := 0
	var max_attempts := amount * 4

	while placed < amount and attempts < max_attempts:
		attempts += 1
		var angle := rng.randf() * TAU
		var dist := radius * pow(rng.randf(), 0.62)
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		var h: float = terrain.height_at(x, z)
		if h < TerrainScript.WATER_LEVEL + 0.45:
			continue
		if terrain.slope_at(x, z) > 0.75:
			continue

		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(
			rng.randf_range(0.7, 1.15),
			rng.randf_range(0.28, 0.6),
			rng.randf_range(0.7, 1.15)
		))
		multimesh.set_instance_transform(placed, Transform3D(basis, Vector3(x, h - 0.05, z)))
		placed += 1

	multimesh.instance_count = placed
	print("[grass] blades: ", placed)

func _make_blade_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var half_w := 0.045
	var tip_w := 0.008

	# два скрещённых лепестка
	for axis in 2:
		var base := verts.size()
		for side in [-1.0, 1.0]:
			verts.append(Vector3(side * half_w, 0.0, 0.0) if axis == 0 else Vector3(0.0, 0.0, side * half_w))
		for side in [-1.0, 1.0]:
			verts.append(Vector3(side * tip_w, 1.0, 0.0) if axis == 0 else Vector3(0.0, 1.0, side * tip_w))

		for k in 4:
			normals.append(Vector3.BACK if axis == 0 else Vector3.RIGHT)

		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(1.0, 0.0))
		uvs.append(Vector2(0.0, 1.0))
		uvs.append(Vector2(1.0, 1.0))

		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
