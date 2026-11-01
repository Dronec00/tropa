class_name BonfireBuilder
extends RefCounted

## Костёр: кольцо камней, брёвна, огонь, дым и тёплый свет.
## Используется и в мире, и в витрине объектов.

static func build(parent: Node3D, pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.30, 0.31, 0.29)
	stone_mat.roughness = 0.95
	if ResourceLoader.exists("res://assets/textures/photo/moss_color.jpg"):
		stone_mat.albedo_texture = load("res://assets/textures/photo/moss_color.jpg")
		stone_mat.normal_enabled = true
		stone_mat.normal_texture = load("res://assets/textures/photo/moss_normal.jpg")
		stone_mat.uv1_scale = Vector3(1.2, 1.2, 1.0)

	for i in 9:
		var stone := MeshInstance3D.new()
		var entry := {
			"seed": 4200 + i * 37,
			"radius": 0.17 + float(i % 3) * 0.03,
			"squash": 0.62 + float(i % 4) * 0.06,
			"yaw": TAU * float(i) / 9.0,
		}
		var stone_mesh: ArrayMesh = ObjectLibrary.make_stone(entry)
		stone.mesh = stone_mesh
		var a := TAU * float(i) / 9.0
		stone.position = Vector3(cos(a) * 0.95, 0.11, sin(a) * 0.95)
		stone.rotation.y = entry["yaw"]
		stone.material_override = stone_mat
		root.add_child(stone)

	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.26, 0.20, 0.15)
	log_mat.roughness = 1.0
	if ResourceLoader.exists("res://assets/textures/photo/bark_color.jpg"):
		log_mat.albedo_texture = load("res://assets/textures/photo/bark_color.jpg")
		log_mat.uv1_scale = Vector3(1.6, 1.0, 1.0)

	var char_mat := StandardMaterial3D.new()
	char_mat.albedo_color = Color(0.07, 0.06, 0.05)
	char_mat.roughness = 1.0

	var cut_mat := StandardMaterial3D.new()
	cut_mat.albedo_color = Color(0.52, 0.40, 0.26)
	cut_mat.roughness = 0.9

	# шалашом: четыре бревна под наклоном
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.35
		var log_root := Node3D.new()
		log_root.position = Vector3(cos(a) * 0.32, 0.08, sin(a) * 0.32)
		log_root.rotation = Vector3(0.0, -a + PI * 0.5, deg_to_rad(62.0))
		root.add_child(log_root)

		var length := 0.95 + float(i % 2) * 0.18
		var radius := 0.055 + float(i % 3) * 0.008

		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius * 0.85
		cyl.bottom_radius = radius
		cyl.height = length
		cyl.radial_segments = 10
		body.mesh = cyl
		body.material_override = log_mat
		log_root.add_child(body)

		# спил с двух сторон — светлое дерево
		for k in 2:
			var cap := MeshInstance3D.new()
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = radius * (0.85 if k == 0 else 1.0)
			cap_mesh.bottom_radius = cap_mesh.top_radius
			cap_mesh.height = 0.015
			cap_mesh.radial_segments = 10
			cap.mesh = cap_mesh
			cap.material_override = cut_mat
			cap.position.y = length * 0.5 * (1.0 if k == 1 else -1.0)
			log_root.add_child(cap)

		# обугленная середина
		var burnt := MeshInstance3D.new()
		var burnt_mesh := CylinderMesh.new()
		burnt_mesh.top_radius = radius * 1.03
		burnt_mesh.bottom_radius = radius * 1.03
		burnt_mesh.height = length * 0.42
		burnt_mesh.radial_segments = 10
		burnt.mesh = burnt_mesh
		burnt.material_override = char_mat
		burnt.position.y = -length * 0.18
		log_root.add_child(burnt)

	# два бревна лежат плашмя
	for i in 2:
		var a := 0.6 + float(i) * 2.1
		var log_root := Node3D.new()
		log_root.position = Vector3(cos(a) * 0.28, 0.09 + float(i) * 0.05, sin(a) * 0.28)
		log_root.rotation = Vector3(0.0, a + 0.4, PI * 0.5)
		root.add_child(log_root)

		var length := 0.8 + float(i) * 0.15
		var radius := 0.05
		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius * 0.9
		cyl.bottom_radius = radius
		cyl.height = length
		cyl.radial_segments = 10
		body.mesh = cyl
		body.material_override = log_mat
		log_root.add_child(body)

		for k in 2:
			var cap := MeshInstance3D.new()
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = radius * (0.9 if k == 0 else 1.0)
			cap_mesh.bottom_radius = cap_mesh.top_radius
			cap_mesh.height = 0.015
			cap_mesh.radial_segments = 10
			cap.mesh = cap_mesh
			cap.material_override = cut_mat
			cap.position.y = length * 0.5 * (1.0 if k == 1 else -1.0)
			log_root.add_child(cap)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.10
	flame_mesh.height = 0.26
	flame.mesh = flame_mesh
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.45, 0.12)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.42, 0.1)
	flame_mat.emission_energy_multiplier = 5.5
	flame.material_override = flame_mat
	flame.position.y = 0.42
	root.add_child(flame)

	var fire := CPUParticles3D.new()
	fire.position = Vector3(0.0, 0.55, 0.0)
	fire.amount = 44
	fire.lifetime = 0.65
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.12
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 14.0
	fire.gravity = Vector3(0, 1.4, 0)
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.85
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.5
	fire.color = Color(1.7, 0.95, 0.3, 0.9)
	var fire_quad := QuadMesh.new()
	fire_quad.size = Vector2(0.34, 0.34)
	fire.mesh = fire_quad
	var fire_mat := StandardMaterial3D.new()
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire_mat.vertex_color_use_as_albedo = true
	fire_mat.albedo_color = Color(2.0, 1.1, 0.35, 0.9)
	fire_mat.albedo_texture = _soft_texture()
	fire.material_override = fire_mat
	root.add_child(fire)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.1, 0)
	light.light_color = Color(1.0, 0.52, 0.20)
	light.light_energy = 2.4
	light.omni_range = 15.0
	light.shadow_enabled = false
	root.add_child(light)

	return {"root": root, "light": light, "flame": flame}

static func _soft_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex
