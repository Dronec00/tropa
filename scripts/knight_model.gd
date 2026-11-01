class_name KnightModel
extends RefCounted

## Рыцарь из примитивов: кольчуга, чёрные сапоги, меч за спиной, факел в левой руке.
## Возвращает узлы, которые нужны игроку: меч (анимация удара) и факел.

static func build(parent: Node3D) -> Dictionary:
	var mail := _mat(Color(0.33, 0.34, 0.36), 0.85, 0.44)
	var plate := _mat(Color(0.24, 0.25, 0.27), 0.9, 0.34)
	var leather := _mat(Color(0.10, 0.08, 0.06), 0.05, 0.85)
	var black := _mat(Color(0.025, 0.025, 0.03), 0.15, 0.65)
	var steel := _mat(Color(0.50, 0.52, 0.55), 0.95, 0.24)
	var wood := _mat(Color(0.13, 0.09, 0.06), 0.0, 0.9)

	# сапоги
	for side in [-1.0, 1.0]:
		_add(parent, _box(Vector3(0.17, 0.22, 0.30)), black, Vector3(side * 0.13, 0.11, -0.02))
		_add(parent, _box(Vector3(0.19, 0.06, 0.34)), black, Vector3(side * 0.13, 0.03, -0.03))

	# ноги
	for side in [-1.0, 1.0]:
		_add(parent, _cyl(0.085, 0.085, 0.5), black, Vector3(side * 0.13, 0.44, 0.0))

	# кольчужная юбка
	_add(parent, _cyl(0.24, 0.35, 0.44), mail, Vector3(0.0, 0.84, 0.0))

	# торс
	_add(parent, _capsule(0.23, 0.52), mail, Vector3(0.0, 1.16, 0.0))
	_add(parent, _cyl(0.245, 0.245, 0.07), leather, Vector3(0.0, 0.98, 0.0))

	# наплечники
	for side in [-1.0, 1.0]:
		var pauldron := _add(parent, _sphere(0.13), plate, Vector3(side * 0.28, 1.40, 0.0))
		pauldron.scale = Vector3(1.1, 0.8, 1.1)

	# руки
	for side in [-1.0, 1.0]:
		var arm := _add(parent, _capsule(0.065, 0.40), mail, Vector3(side * 0.30, 1.12, 0.0))
		arm.rotation.z = side * -0.12
		_add(parent, _sphere(0.07), leather, Vector3(side * 0.33, 0.90, -0.02))

	# шея и шлем
	_add(parent, _cyl(0.07, 0.07, 0.10), mail, Vector3(0.0, 1.45, 0.0))
	_add(parent, _cyl(0.14, 0.145, 0.26), plate, Vector3(0.0, 1.60, 0.0))
	var dome := _add(parent, _sphere(0.145), plate, Vector3(0.0, 1.73, 0.0))
	dome.scale = Vector3(1.0, 0.75, 1.0)
	_add(parent, _box(Vector3(0.20, 0.025, 0.03)), black, Vector3(0.0, 1.605, -0.135))
	_add(parent, _box(Vector3(0.03, 0.16, 0.03)), plate, Vector3(0.0, 1.60, -0.145))

	# меч за спиной
	var sword_pivot := Node3D.new()
	sword_pivot.name = "SwordPivot"
	sword_pivot.position = Vector3(0.02, 1.22, 0.19)
	sword_pivot.rotation = Vector3(0.10, 0.0, -0.55)
	parent.add_child(sword_pivot)
	_add(sword_pivot, _box(Vector3(0.055, 1.05, 0.014)), steel, Vector3(0.0, 0.58, 0.0))
	_add(sword_pivot, _box(Vector3(0.24, 0.035, 0.035)), plate, Vector3(0.0, 0.05, 0.0))
	_add(sword_pivot, _cyl(0.024, 0.024, 0.22), leather, Vector3(0.0, -0.08, 0.0))
	_add(sword_pivot, _sphere(0.042), steel, Vector3(0.0, -0.20, 0.0))

	# факел в левой руке
	var torch_pivot := Node3D.new()
	torch_pivot.name = "TorchPivot"
	torch_pivot.position = Vector3(-0.34, 0.92, -0.04)
	torch_pivot.rotation = Vector3(-0.12, 0.0, 0.12)
	parent.add_child(torch_pivot)
	_add(torch_pivot, _cyl(0.022, 0.026, 0.52), wood, Vector3(0.0, 0.26, 0.0))
	_add(torch_pivot, _cyl(0.05, 0.045, 0.11), leather, Vector3(0.0, 0.54, 0.0))

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.06
	flame_mesh.height = 0.14
	flame.mesh = flame_mesh
	flame.position = Vector3(0.0, 0.64, 0.0)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.15)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.45, 0.08)
	flame_mat.emission_energy_multiplier = 6.0
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = flame_mat
	flame.visible = false
	torch_pivot.add_child(flame)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.66, 0.0)
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 0.0
	light.omni_range = 11.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	torch_pivot.add_child(light)

	var particles := CPUParticles3D.new()
	particles.position = Vector3(0.0, 0.66, 0.0)
	particles.amount = 26
	particles.lifetime = 0.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.04
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 16.0
	particles.gravity = Vector3(0, 1.1, 0)
	particles.initial_velocity_min = 0.12
	particles.initial_velocity_max = 0.4
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 0.9
	particles.color = Color(1.0, 0.55, 0.16, 0.85)
	particles.emitting = false

	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	particles.mesh = quad

	var particle_mat := StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	particle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_mat.vertex_color_use_as_albedo = true
	particle_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.9)
	particle_mat.albedo_texture = _soft_particle_texture()
	particles.material_override = particle_mat
	torch_pivot.add_child(particles)

	return {
		"sword_pivot": sword_pivot,
		"torch_pivot": torch_pivot,
		"torch_flame": flame,
		"torch_light": light,
		"torch_particles": particles,
	}

static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	return m

static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m

static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m

static func _soft_particle_texture() -> GradientTexture2D:
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
