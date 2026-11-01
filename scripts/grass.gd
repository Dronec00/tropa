class_name GrassField
extends MultiMeshInstance3D

## Трава из пучков: три скрещённые плоскости с текстурой пучка.
## Инстансы разбиты на чанки, дальние отсекаются по расстоянию.

const TerrainScript := preload("res://scripts/terrain.gd")
const GrassShader := preload("res://shaders/grass.gdshader")
const TuftPath := "res://assets/textures/grass_tuft.png"

func populate(terrain: Node3D, amount: int = 40000, radius: float = 42.0) -> void:
	var tuft_mesh := _make_tuft_mesh()

	var material := ShaderMaterial.new()
	material.shader = GrassShader
	if ResourceLoader.exists(TuftPath):
		material.set_shader_parameter("tuft", load(TuftPath))

	var rng := RandomNumberGenerator.new()
	rng.seed = 1907

	var chunks: Dictionary = {}
	var chunk_size := 14.0
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
			rng.randf_range(0.75, 1.25),
			rng.randf_range(0.30, 0.62),
			rng.randf_range(0.75, 1.25)
		))
		var key := Vector2i(int(floor(x / chunk_size)), int(floor(z / chunk_size)))
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(Transform3D(basis, Vector3(x, h - 0.03, z)))
		placed += 1

	for key in chunks:
		var transforms: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tuft_mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = radius + 18.0
		node.visibility_range_end_margin = 8.0
		add_child(node)

	multimesh = null
	print("[grass] tufts: ", placed, " chunks: ", chunks.size())

func _make_tuft_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var half_w := 0.55

	for k in 3:
		var a := PI * float(k) / 3.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var base := verts.size()

		verts.append(dir * -half_w)
		verts.append(dir * half_w)
		verts.append(dir * half_w + Vector3(0.0, 1.0, 0.0))
		verts.append(dir * -half_w + Vector3(0.0, 1.0, 0.0))

		for i in 4:
			normals.append(Vector3.UP)

		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(1.0, 0.0))
		uvs.append(Vector2(1.0, 1.0))
		uvs.append(Vector2(0.0, 1.0))

		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base)
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
