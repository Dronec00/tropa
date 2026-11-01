class_name GrassField
extends MultiMeshInstance3D

## Трава из пучков: три скрещённые плоскости с текстурой пучка.
## Инстансы разбиты на чанки, дальние отсекаются по расстоянию.

const TerrainScript := preload("res://scripts/terrain.gd")
const GrassShader := preload("res://shaders/grass.gdshader")
const TuftPath := "res://assets/textures/grass_tuft.png"

func populate(terrain: Object, amount: int = 40000, radius: float = 42.0, paths: Array = [], bushes: Array = []) -> void:
	var tuft_mesh := make_tuft_mesh()

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

		# густота: реже на тропе
		if not paths.is_empty():
			var near := 999.0
			for path in paths:
				var pts: Array = path["points"]
				for k in range(0, pts.size(), 5):
					var pp: Vector3 = pts[k]
					var d2 := Vector2(pp.x - x, pp.z - z).length()
					if d2 < near:
						near = d2
			if near < 2.0:
				continue
			if near < 4.0 and rng.randf() > 0.45:
				continue

		# гуще у кустов: вне кустов часть кандидатов отбрасываем
		if not bushes.is_empty():
			var near_bush := false
			for b in bushes:
				if Vector2(b.x - x, b.z - z).length() < 4.5:
					near_bush = true
					break
			if not near_bush and rng.randf() > 0.55:
				continue

		# наклон по нормали склона
		var e := 0.6
		var hx1: float = terrain.height_at(x - e, z)
		var hx2: float = terrain.height_at(x + e, z)
		var hz1: float = terrain.height_at(x, z - e)
		var hz2: float = terrain.height_at(x, z + e)
		var normal := Vector3(hx1 - hx2, 2.0 * e, hz1 - hz2).normalized()

		var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(
			rng.randf_range(0.8, 1.2),
			rng.randf_range(0.20, 0.42),
			rng.randf_range(0.8, 1.2)
		))
		var key := Vector2i(int(floor(x / chunk_size)), int(floor(z / chunk_size)))
		if not chunks.has(key):
			chunks[key] = []
		var tint := rng.randf()
		var hue := rng.randf()
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
		(chunks[key] as Array).append([Transform3D(basis, Vector3(x, h - 0.03, z)), tint, hue, variant])
		placed += 1

	for key in chunks:
		var transforms: Array = chunks[key]
		var origin := Vector3(float(key.x) * chunk_size, 0.0, float(key.y) * chunk_size)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = tuft_mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			var entry: Array = transforms[i]
			var t: Transform3D = entry[0]
			mm.set_instance_transform(i, Transform3D(t.basis, t.origin - origin))
			mm.set_instance_color(i, Color(entry[1], entry[2], entry[3]))
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = material
		node.position = origin
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = minf(radius + 18.0, 46.0)
		node.visibility_range_end_margin = 16.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(node)

	multimesh = null
	print("[grass] tufts: ", placed, " chunks: ", chunks.size())

static func make_tuft_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var half_w := 0.26

	for k in 3:
		var a := PI * float(k) / 3.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var base := verts.size()

		verts.append(dir * -half_w)
		verts.append(dir * half_w)
		verts.append(dir * half_w + Vector3(0.0, 0.70, 0.0))
		verts.append(dir * -half_w + Vector3(0.0, 0.70, 0.0))

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
