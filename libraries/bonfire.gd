class_name BonfireBuilder
extends RefCounted

## Костёр: кольцо камней, брёвна, огонь, дым и тёплый свет.
## Используется и в мире, и в витрине объектов.

static func build(parent: Node3D, pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.17, 0.17, 0.18)
	for i in 9:
		var stone := MeshInstance3D.new()
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.16
		stone_mesh.height = 0.3
		stone.mesh = stone_mesh
		var a := TAU * float(i) / 9.0
		stone.position = Vector3(cos(a) * 0.95, 0.1, sin(a) * 0.95)
		stone.material_override = stone_mat
		root.add_child(stone)

	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.11, 0.07, 0.05)
	for i in 4:
		var log_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.1
		cyl.height = 1.15
		log_mesh.mesh = cyl
		log_mesh.position = Vector3(0, 0.3, 0)
		log_mesh.rotation = Vector3(PI * 0.5, TAU * float(i) / 4.0, 0.18)
		log_mesh.material_override = log_mat
		root.add_child(log_mesh)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.17
	flame_mesh.height = 0.42
	flame.mesh = flame_mesh
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.45, 0.12)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.42, 0.1)
	flame_mat.emission_energy_multiplier = 9.0
	flame.material_override = flame_mat
	flame.position.y = 0.55
	root.add_child(flame)

	var fire := CPUParticles3D.new()
	fire.position = Vector3(0.0, 0.55, 0.0)
	fire.amount = 26
	fire.lifetime = 0.65
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.16
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 14.0
	fire.gravity = Vector3(0, 1.4, 0)
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.85
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.5
	fire.color = Color(2.6, 1.3, 0.35, 0.9)
	var fire_quad := QuadMesh.new()
	fire_quad.size = Vector2(0.5, 0.5)
	fire.mesh = fire_quad
	var fire_mat := StandardMaterial3D.new()
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire_mat.vertex_color_use_as_albedo = true
	fire_mat.albedo_color = Color(3.4, 1.7, 0.5, 0.9)
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
