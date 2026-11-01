class_name HutBuilder
extends RefCounted

## Изба-ориентир: сруб, двускатная крыша, тёплое окно, крыльцо, дым из трубы.
## Свет в окне виден издалека — это и есть цель пути.

static func build(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)

	var wood := _mat(Color(0.15, 0.10, 0.06))
	var wood_dark := _mat(Color(0.08, 0.055, 0.035))
	var stone := _mat(Color(0.19, 0.19, 0.18))
	var cloth := _mat(Color(0.22, 0.12, 0.09))

	# фундамент и пол
	_box(root, Vector3(5.4, 0.5, 5.4), stone, Vector3(0, 0.25, 0))

	# сруб
	_box(root, Vector3(5.0, 2.7, 0.34), wood, Vector3(0, 1.85, -2.35))
	_box(root, Vector3(5.0, 2.7, 0.34), wood, Vector3(0, 1.85, 2.35))
	_box(root, Vector3(0.34, 2.7, 5.0), wood, Vector3(-2.35, 1.85, 0))
	_box(root, Vector3(0.34, 2.7, 5.0), wood, Vector3(2.35, 1.85, 0))

	# брёвна на фасаде — горизонтальные полосы
	for i in 5:
		var y := 0.7 + float(i) * 0.5
		_box(root, Vector3(5.1, 0.06, 0.36), wood_dark, Vector3(0, y, 2.36))

	# крыша двускатная
	var roof_left := _box(root, Vector3(6.2, 0.22, 3.5), wood_dark, Vector3(0, 3.55, -1.45))
	roof_left.rotation.x = deg_to_rad(26)
	var roof_right := _box(root, Vector3(6.2, 0.22, 3.5), wood_dark, Vector3(0, 3.55, 1.45))
	roof_right.rotation.x = deg_to_rad(-26)

	# конёк
	_box(root, Vector3(6.3, 0.16, 0.3), wood_dark, Vector3(0, 4.32, 0))

	# дверь
	_box(root, Vector3(1.05, 1.95, 0.12), wood_dark, Vector3(0, 1.5, 2.44))
	_box(root, Vector3(0.12, 0.12, 0.08), stone, Vector3(0.38, 1.4, 2.52))

	# окно с тёплым светом
	var window := _box(root, Vector3(0.9, 0.8, 0.1), cloth, Vector3(1.45, 2.0, 2.44))
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(1.0, 0.72, 0.35)
	win_mat.emission_enabled = true
	win_mat.emission = Color(1.0, 0.62, 0.25)
	win_mat.emission_energy_multiplier = 2.6
	win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	window.material_override = win_mat

	var window_light := OmniLight3D.new()
	window_light.position = Vector3(1.45, 2.0, 2.1)
	window_light.light_color = Color(1.0, 0.68, 0.35)
	window_light.light_energy = 1.8
	window_light.omni_range = 18.0
	window_light.shadow_enabled = false
	root.add_child(window_light)

	# крыльцо
	_box(root, Vector3(2.6, 0.18, 1.4), wood_dark, Vector3(0, 0.42, 3.0))
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.16, 1.2, 0.16), wood, Vector3(side * 1.15, 0.95, 3.55))
	_box(root, Vector3(2.6, 0.12, 0.16), wood, Vector3(0, 1.5, 3.55))

	# фонарь у двери
	var lantern := MeshInstance3D.new()
	var lantern_mesh := SphereMesh.new()
	lantern_mesh.radius = 0.09
	lantern_mesh.height = 0.18
	lantern.mesh = lantern_mesh
	var lantern_mat := StandardMaterial3D.new()
	lantern_mat.albedo_color = Color(1.0, 0.7, 0.3)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(1.0, 0.6, 0.22)
	lantern_mat.emission_energy_multiplier = 4.0
	lantern_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lantern.material_override = lantern_mat
	lantern.position = Vector3(0.85, 2.35, 2.6)
	root.add_child(lantern)

	var lantern_light := OmniLight3D.new()
	lantern_light.position = Vector3(0.85, 2.35, 2.75)
	lantern_light.light_color = Color(1.0, 0.65, 0.3)
	lantern_light.light_energy = 1.6
	lantern_light.omni_range = 11.0
	root.add_child(lantern_light)

	# труба и дым
	_box(root, Vector3(0.5, 1.7, 0.5), stone, Vector3(-1.4, 4.1, -1.1))

	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(-1.4, 5.0, -1.1)
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
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.9, 0.9)
	smoke.mesh = smoke_quad
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_mat.albedo_texture = _soft_texture()
	smoke.material_override = smoke_mat
	root.add_child(smoke)

	# забор
	for i in 7:
		var x := -3.2 + float(i) * 1.1
		_box(root, Vector3(0.12, 1.0, 0.12), wood, Vector3(x, 0.5, 5.2))
	_box(root, Vector3(7.2, 0.1, 0.08), wood, Vector3(0, 0.75, 5.2))
	_box(root, Vector3(7.2, 0.1, 0.08), wood, Vector3(0, 0.35, 5.2))

	return root

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
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
