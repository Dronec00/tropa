class_name HutBuilder
extends RefCounted

## Изба: сруб с коллизией, дверь на петле, очаг-чекпоинт и оберег на столе.

static func build(parent: Node3D, pos: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)

	var wood := _mat(Color(0.15, 0.10, 0.06))
	var wood_dark := _mat(Color(0.08, 0.055, 0.035))
	var stone := _mat(Color(0.19, 0.19, 0.18))
	var cloth := _mat(Color(0.22, 0.12, 0.09))

	var floor_y := 0.3

	# фундамент и пол
	_solid(root, Vector3(5.4, 0.3, 5.4), stone, Vector3(0, 0.15, 0))
	_solid(root, Vector3(4.8, 0.08, 4.8), wood_dark, Vector3(0, floor_y + 0.02, 0))

	# задняя и боковые стены
	_solid(root, Vector3(5.0, 2.7, 0.34), wood, Vector3(0, 1.85, -2.35))
	_solid(root, Vector3(0.34, 2.7, 5.0), wood, Vector3(-2.35, 1.85, 0))
	_solid(root, Vector3(0.34, 2.7, 5.0), wood, Vector3(2.35, 1.85, 0))

	# передняя стена с проёмом
	_solid(root, Vector3(1.85, 2.7, 0.34), wood, Vector3(-1.42, 1.85, 2.35))
	_solid(root, Vector3(1.85, 2.7, 0.34), wood, Vector3(1.42, 1.85, 2.35))
	_solid(root, Vector3(1.1, 0.78, 0.34), wood, Vector3(0, 2.8, 2.35))

	# брёвна на фасаде
	for i in 5:
		var y := 0.7 + float(i) * 0.5
		_box(root, Vector3(5.1, 0.06, 0.36), wood_dark, Vector3(0, y, 2.36))

	# крыша: двускатный меш
	var roof := MeshInstance3D.new()
	roof.mesh = _roof_mesh()
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.09, 0.06, 0.04)
	roof_mat.roughness = 1.0
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof.material_override = roof_mat
	root.add_child(roof)
	_box(root, Vector3(6.4, 0.18, 0.26), wood_dark, Vector3(0, 4.34, 0))

	# дверь на петле
	var door_pivot := Node3D.new()
	door_pivot.position = Vector3(-0.55, floor_y, 2.35)
	root.add_child(door_pivot)

	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.05, 1.95, 0.12)
	door.mesh = door_mesh
	door.position = Vector3(0.525, 0.975, 0.0)
	door.material_override = wood_dark
	door_pivot.add_child(door)

	var door_body := StaticBody3D.new()
	var door_shape := CollisionShape3D.new()
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(1.05, 1.95, 0.12)
	door_shape.shape = door_box
	door_shape.position = Vector3(0.525, 0.975, 0.0)
	door_body.add_child(door_shape)
	door_pivot.add_child(door_body)

	var handle := MeshInstance3D.new()
	var handle_mesh := SphereMesh.new()
	handle_mesh.radius = 0.05
	handle_mesh.height = 0.1
	handle.mesh = handle_mesh
	handle.position = Vector3(0.92, 0.95, -0.1)
	var iron := _mat(Color(0.22, 0.22, 0.23))
	iron.metallic = 0.8
	handle.material_override = iron
	door_pivot.add_child(handle)

	# окно
	var window := _box(root, Vector3(0.9, 0.8, 0.1), cloth, Vector3(1.45, 2.0, 2.44))
	window.material_override = _glow(Color(1.0, 0.72, 0.35), Color(1.0, 0.62, 0.25), 2.6)

	var window_light := OmniLight3D.new()
	window_light.position = Vector3(1.45, 2.0, 2.1)
	window_light.light_color = Color(1.0, 0.68, 0.35)
	window_light.light_energy = 1.6
	window_light.omni_range = 16.0
	root.add_child(window_light)

	# крыльцо
	_box(root, Vector3(2.6, 0.12, 1.4), wood_dark, Vector3(0, 0.3, 3.0))

	# сходни, чтобы войти без прыжка
	var ramp := _solid(root, Vector3(2.0, 0.1, 1.6), wood, Vector3(0, 0.16, 4.45))
	ramp.rotation.x = deg_to_rad(12)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.16, 1.2, 0.16), wood, Vector3(side * 1.15, 0.95, 3.55))
	_box(root, Vector3(2.6, 0.12, 0.16), wood, Vector3(0, 1.5, 3.55))

	# труба и дым
	_solid(root, Vector3(0.5, 1.7, 0.5), stone, Vector3(-1.4, 4.1, -1.1))
	_smoke(root, Vector3(-1.4, 5.0, -1.1))

	# забор
	for i in 7:
		var x := -3.2 + float(i) * 1.1
		_box(root, Vector3(0.12, 1.0, 0.12), wood, Vector3(x, 0.5, 5.2))
	_box(root, Vector3(7.2, 0.1, 0.08), wood, Vector3(0, 0.75, 5.2))
	_box(root, Vector3(7.2, 0.1, 0.08), wood, Vector3(0, 0.35, 5.2))

	# --- внутри: очаг ---
	var hearth := Node3D.new()
	hearth.position = Vector3(0, floor_y, -1.65)
	root.add_child(hearth)

	for i in 8:
		var stone_i := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.26
		stone_i.mesh = sm
		var a := TAU * float(i) / 8.0
		stone_i.position = Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55)
		stone_i.material_override = stone
		hearth.add_child(stone_i)

	for i in 3:
		var log_i := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.06
		lm.bottom_radius = 0.08
		lm.height = 0.7
		log_i.mesh = lm
		log_i.position = Vector3(0, 0.2, 0)
		log_i.rotation = Vector3(PI * 0.5, TAU * float(i) / 3.0, 0.2)
		log_i.material_override = wood_dark
		hearth.add_child(log_i)

	var fire := MeshInstance3D.new()
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = 0.18
	fire_mesh.height = 0.44
	fire.mesh = fire_mesh
	fire.position = Vector3(0, 0.3, 0)
	fire.material_override = _glow(Color(1.0, 0.45, 0.12), Color(1.0, 0.42, 0.1), 5.0)
	hearth.add_child(fire)

	var embers := CPUParticles3D.new()
	embers.position = Vector3(0, 0.32, 0)
	embers.amount = 16
	embers.lifetime = 0.55
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.12
	embers.direction = Vector3(0, 1, 0)
	embers.spread = 14.0
	embers.gravity = Vector3(0, 1.3, 0)
	embers.initial_velocity_min = 0.2
	embers.initial_velocity_max = 0.6
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.1
	embers.color = Color(1.0, 0.5, 0.12, 0.9)
	var ember_quad := QuadMesh.new()
	ember_quad.size = Vector2(0.24, 0.24)
	embers.mesh = ember_quad
	var ember_mat := StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ember_mat.vertex_color_use_as_albedo = true
	ember_mat.albedo_texture = _soft_texture()
	embers.material_override = ember_mat
	hearth.add_child(embers)

	var hearth_light := OmniLight3D.new()
	hearth_light.position = Vector3(0, 0.7, 0)
	hearth_light.light_color = Color(1.0, 0.6, 0.28)
	hearth_light.light_energy = 2.4
	hearth_light.omni_range = 9.0
	hearth_light.shadow_enabled = true
	hearth.add_child(hearth_light)

	# --- стол с оберегом ---
	var table := Node3D.new()
	table.position = Vector3(1.45, floor_y, -0.25)
	root.add_child(table)
	_box(table, Vector3(1.0, 0.08, 0.7), wood, Vector3(0, 0.72, 0))
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			_box(table, Vector3(0.08, 0.72, 0.08), wood_dark, Vector3(side * 0.4, 0.36, depth * 0.26))

	var amulet := MeshInstance3D.new()
	var amulet_mesh := SphereMesh.new()
	amulet_mesh.radius = 0.09
	amulet_mesh.height = 0.18
	amulet.mesh = amulet_mesh
	amulet.position = Vector3(1.45, floor_y + 0.9, -0.25)
	amulet.material_override = _glow(Color(0.6, 0.85, 1.0), Color(0.45, 0.8, 1.0), 3.5)
	root.add_child(amulet)

	var amulet_light := OmniLight3D.new()
	amulet_light.position = amulet.position + Vector3(0, 0.15, 0)
	amulet_light.light_color = Color(0.5, 0.8, 1.0)
	amulet_light.light_energy = 1.0
	amulet_light.omni_range = 4.0
	root.add_child(amulet_light)

	return {
		"root": root,
		"door": door_pivot,
		"hearth": hearth,
		"amulet": amulet,
		"amulet_light": amulet_light,
		"floor_y": floor_y,
	}

# --- утилиты ---

static func _roof_mesh() -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(-3.15, 3.05, -2.55), Vector3(3.15, 3.05, -2.55),
		Vector3(3.15, 4.3, 0.0), Vector3(-3.15, 4.3, 0.0),
		Vector3(3.15, 3.05, 2.55), Vector3(-3.15, 3.05, 2.55),
	])
	var indices := PackedInt32Array([
		0, 1, 2, 0, 2, 3,
		3, 2, 4, 3, 4, 5,
		0, 3, 5,
		1, 4, 2,
	])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		normals[i] = Vector3.UP

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

static func _glow(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func _box(parent: Node3D, size: Vector3, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _solid(parent: Node3D, size: Vector3, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := _box(parent, size, material, pos)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	mi.add_child(body)
	return mi

static func _smoke(parent: Node3D, pos: Vector3) -> void:
	var smoke := CPUParticles3D.new()
	smoke.position = pos
	smoke.amount = 18
	smoke.lifetime = 4.5
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.18
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.15, 0.5, 0.1)
	smoke.initial_velocity_min = 0.25
	smoke.initial_velocity_max = 0.55
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.6
	smoke.color = Color(0.32, 0.31, 0.30, 0.35)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	smoke.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _soft_texture()
	smoke.material_override = mat
	parent.add_child(smoke)

static func _soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex
