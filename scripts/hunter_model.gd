extends RefCounted
## Обёртка сгенерированной модели Охотник_D (Kimi): GLB + риг + огонёк.
## Модель смотрит в +X, поэтому поворачиваем на +90°, чтобы смотрела в -Z.

const GLB_PATH := "res://models/hunter_d.glb"
const AnimatorScript := preload("res://scripts/hunter_animator.gd")

static func build(parent: Node3D) -> Dictionary:
	var packed: PackedScene = load(GLB_PATH) as PackedScene
	if packed == null:
		push_error("Не загрузилась модель: " + GLB_PATH)
		return {}
	var inst: Node3D = packed.instantiate() as Node3D
	inst.name = "HunterD"
	inst.rotation.y = PI * 0.5
	parent.add_child(inst)

	var mesh: MeshInstance3D = _find_mesh(inst)
	if mesh != null:
		var aabb: AABB = mesh.get_aabb()
		inst.position.y = -aabb.position.y
		for s in range(mesh.mesh.get_surface_count()):
			var mat: StandardMaterial3D = mesh.mesh.surface_get_material(s) as StandardMaterial3D
			if mat != null:
				mat.metallic = 0.0
				mat.roughness = 0.60
				mat.cull_mode = BaseMaterial3D.CULL_BACK
				mesh.material_override = mat

	var skel: Skeleton3D = _find_skeleton(inst)
	var animator: Node = null
	if skel != null:
		animator = AnimatorScript.new()
		animator.name = "HunterAnimator"
		parent.add_child(animator)
		animator.setup(skel)

	# подсветка лица под шляпой
	var fill: OmniLight3D = OmniLight3D.new()
	fill.name = "FaceFill"
	fill.light_color = Color(0.95, 0.88, 0.78)
	fill.light_energy = 0.24
	fill.omni_range = 0.90
	fill.omni_attenuation = 1.7
	fill.position = Vector3(0.0, 1.60, -0.34)
	parent.add_child(fill)

	# огонёк в правой руке (правая — свободная, +X)
	var torch: Node3D = Node3D.new()
	torch.name = "HunterEmber"
	torch.position = Vector3(0.30, 1.02, -0.08)
	parent.add_child(torch)

	var flame: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.10
	sphere.radial_segments = 8
	sphere.rings = 5
	flame.mesh = sphere
	var ember: StandardMaterial3D = StandardMaterial3D.new()
	ember.albedo_color = Color(1.0, 0.62, 0.22)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.45, 0.12)
	ember.emission_energy_multiplier = 4.5
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = ember
	flame.visible = false
	torch.add_child(flame)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.22)
	light.light_energy = 0.0
	light.omni_range = 3.5
	light.visible = false
	torch.add_child(light)

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = 10
	particles.lifetime = 0.55
	particles.direction = Vector3.UP
	particles.spread = 18.0
	particles.gravity = Vector3(0.0, 0.6, 0.0)
	particles.initial_velocity_min = 0.10
	particles.initial_velocity_max = 0.28
	particles.scale_amount_min = 0.015
	particles.scale_amount_max = 0.035
	particles.emitting = false
	torch.add_child(particles)

	return {
		"animator": animator,
		"height": 1.9,
		"sword_pivot": Node3D.new(),
		"torch_flame": flame,
		"torch_light": light,
		"torch_particles": particles,
	}

static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var m: MeshInstance3D = _find_mesh(child)
		if m != null:
			return m
	return null

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var s: Skeleton3D = _find_skeleton(child)
		if s != null:
			return s
	return null
