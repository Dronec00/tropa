class_name BonfireBuilder
extends RefCounted

## Костёр: кольцо камней, шалаш из брёвен, зола, угли, многослойное пламя,
## искры, дым и мерцающий свет. Один и тот же в мире и в витрине.

const FlickerScript := preload("res://libraries/bonfire_flicker.gd")

static func build(parent: Node3D, pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	_add_ash(root)
	_add_stones(root)
	_add_logs(root)
	var embers := _add_embers(root)
	var flame := _add_flames(root)
	var light := _add_light(root)

	var flicker = FlickerScript.new()
	flicker.light = light
	flicker.embers = embers
	root.add_child(flicker)

	return {"root": root, "light": light, "flame": flame}

# --- зола ---

static func _add_ash(root: Node3D) -> void:
	var ash_mat := StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.30, 0.285, 0.27, 0.62)
	ash_mat.roughness = 1.0
	ash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ash_mat.albedo_texture = _soft_texture()
	ash_mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	ash_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.92
	cyl.bottom_radius = 0.85
	cyl.height = 0.02
	cyl.radial_segments = 32
	disc.mesh = cyl
	disc.material_override = ash_mat
	disc.position.y = 0.012
	root.add_child(disc)

	var char_mat := StandardMaterial3D.new()
	char_mat.albedo_color = Color(0.055, 0.05, 0.045)
	char_mat.roughness = 1.0
	for i in 5:
		var patch := MeshInstance3D.new()
		var p := CylinderMesh.new()
		p.top_radius = 0.22 + float(i % 3) * 0.06
		p.bottom_radius = p.top_radius
		p.height = 0.02
		patch.mesh = p
		patch.material_override = char_mat
		var a := TAU * float(i) / 5.0 + 0.4
		patch.position = Vector3(cos(a) * 0.35, 0.03, sin(a) * 0.35)
		root.add_child(patch)

# --- камни ---

static func _add_stones(root: Node3D) -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.32, 0.33, 0.31)
	stone_mat.roughness = 0.95
	if ResourceLoader.exists("res://assets/textures/photo/moss_color.jpg"):
		stone_mat.albedo_texture = load("res://assets/textures/photo/moss_color.jpg")
		stone_mat.normal_enabled = true
		stone_mat.normal_texture = load("res://assets/textures/photo/moss_normal.jpg")
		stone_mat.uv1_scale = Vector3(1.2, 1.2, 1.0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for i in 11:
		var a := TAU * float(i) / 11.0 + 0.2
		var r := 0.92 + float(i % 3) * 0.05
		var entry := {
			"seed": 5100 + i * 53,
			"radius": 0.13 + float(i % 4) * 0.025,
			"squash": 0.55 + float(i % 3) * 0.08,
			"yaw": a,
		}
		var mesh := ObjectLibrary.make_stone(entry)
		var basis := Basis(Vector3.UP, a)
		st.append_from(mesh, 0, Transform3D(basis, Vector3(cos(a) * r, 0.055, sin(a) * r)))
		count += 1
	if count > 0:
		var node := MeshInstance3D.new()
		node.mesh = st.commit()
		node.material_override = stone_mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)

static func _add_logs(root: Node3D) -> void:
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.30, 0.24, 0.18)
	bark_mat.roughness = 1.0
	if ResourceLoader.exists("res://assets/textures/photo/bark_color.jpg"):
		bark_mat.albedo_texture = load("res://assets/textures/photo/bark_color.jpg")
		bark_mat.uv1_scale = Vector3(1.4, 1.0, 1.0)

	var cut_mat := StandardMaterial3D.new()
	cut_mat.albedo_color = Color(0.56, 0.43, 0.27)
	cut_mat.roughness = 0.9

	var char_mat := StandardMaterial3D.new()
	char_mat.albedo_color = Color(0.05, 0.045, 0.04)
	char_mat.roughness = 1.0

	var parts := {"bark": [], "cut": [], "char": []}

	# шалаш: вершинами к центру
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.25
		var length := 0.36 + float(i % 3) * 0.04
		var radius := 0.055 + float(i % 2) * 0.01
		var base := Vector3(cos(a) * 0.34, 0.012, sin(a) * 0.34)
		var top := Vector3(cos(a) * 0.09, length * 0.82, sin(a) * 0.09)
		var dir := (top - base).normalized()
		var basis := Basis(Quaternion(Vector3.UP, dir))
		_collect_log(parts, Transform3D(basis, base + dir * (length * 0.5)), length, radius)

	# плашмя: комлями наружу
	for i in 4:
		var a := 0.4 + float(i) * 1.55
		var length := 0.32 + float(i % 2) * 0.07
		var dir := Vector3(-cos(a), 0.12, -sin(a)).normalized()
		var base := Vector3(cos(a) * 0.46, 0.05 + float(i) * 0.02, sin(a) * 0.46)
		var basis := Basis(Quaternion(Vector3.UP, dir))
		_collect_log(parts, Transform3D(basis, base + dir * (length * 0.5)), length, 0.05)

	for key in ["bark", "cut", "char"]:
		var items: Array = parts[key]
		if items.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item in items:
			st.append_from(item[0], 0, item[1])
		var node := MeshInstance3D.new()
		node.mesh = st.commit()
		node.material_override = bark_mat if key == "bark" else (cut_mat if key == "cut" else char_mat)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)

static func _collect_log(parts: Dictionary, xform: Transform3D, length: float, radius: float) -> void:
	var seg := 3
	var seg_len := length / float(seg)

	for s in seg:
		var cyl := CylinderMesh.new()
		var t := float(s) / float(seg)
		cyl.top_radius = radius * lerpf(1.0, 0.78, t + 0.34)
		cyl.bottom_radius = radius * lerpf(1.0, 0.78, t)
		cyl.height = seg_len * 1.02
		cyl.radial_segments = 10
		var local := Transform3D(Basis(), Vector3(0, -length * 0.5 + seg_len * (float(s) + 0.5), 0))
		(parts["bark"] as Array).append([cyl, xform * local])

	var burnt := CylinderMesh.new()
	burnt.top_radius = radius * 0.9
	burnt.bottom_radius = radius * 1.02
	burnt.height = length * 0.34
	burnt.radial_segments = 10
	(parts["char"] as Array).append([burnt, xform * Transform3D(Basis(), Vector3(0, -length * 0.5 + length * 0.17, 0))])

	var cap := CylinderMesh.new()
	cap.top_radius = radius * 0.78
	cap.bottom_radius = radius * 0.78
	cap.height = 0.018
	cap.radial_segments = 10
	(parts["cut"] as Array).append([cap, xform * Transform3D(Basis(), Vector3(0, length * 0.5, 0))])

static func _make_log(bark_mat: Material, cut_mat: Material, char_mat: Material, length: float, radius: float) -> Node3D:
	var node := Node3D.new()

	var seg := 3
	var seg_len := length / float(seg)
	for s in seg:
		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var t := float(s) / float(seg)
		cyl.top_radius = radius * lerpf(1.0, 0.78, t + 0.34)
		cyl.bottom_radius = radius * lerpf(1.0, 0.78, t)
		cyl.height = seg_len * 1.02
		cyl.radial_segments = 14
		body.mesh = cyl
		body.material_override = bark_mat
		body.position.y = -length * 0.5 + seg_len * (float(s) + 0.5)
		body.rotation.z = deg_to_rad(-1.5 + float(s) * 1.4)
		node.add_child(body)

	# обугливание у комля
	var burnt := MeshInstance3D.new()
	var burnt_mesh := CylinderMesh.new()
	burnt_mesh.top_radius = radius * 0.9
	burnt_mesh.bottom_radius = radius * 1.02
	burnt_mesh.height = length * 0.34
	burnt_mesh.radial_segments = 14
	burnt.mesh = burnt_mesh
	burnt.material_override = char_mat
	burnt.position.y = -length * 0.5 + length * 0.17
	node.add_child(burnt)

	# спил на дальнем конце
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = radius * 0.78
	cap_mesh.bottom_radius = radius * 0.78
	cap_mesh.height = 0.018
	cap_mesh.radial_segments = 14
	cap.mesh = cap_mesh
	cap.material_override = cut_mat
	cap.position.y = length * 0.5
	node.add_child(cap)

	return node

# --- угли ---

static func _add_embers(root: Node3D) -> Array:
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color(0.35, 0.08, 0.02)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.28, 0.04)
	ember_mat.emission_energy_multiplier = 2.6
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var sphere := SphereMesh.new()
	sphere.radius = 0.016
	sphere.height = 0.032
	sphere.radial_segments = 6
	sphere.rings = 4

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = 18
	for i in 18:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.04, 0.34)
		var pos := Vector3(cos(a) * d, rng.randf_range(0.03, 0.10), sin(a) * d)
		var sc := rng.randf_range(0.7, 1.4)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sc), pos))

	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = ember_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return []

# --- пламя ---

static func _add_flames(root: Node3D) -> Node3D:
	var holder := Node3D.new()
	root.add_child(holder)

	var soft := _soft_texture()
	var flame_tex: Texture2D = load("res://assets/textures/flame_sprite.png")

	# языки пламени
	var core := _make_fire(flame_tex, 22, 0.42, Vector2(0.13, 0.30), 0.22, 0.46, 8.0, Color(1.0, 0.88, 0.55, 0.95))
	core.position.y = 0.30
	holder.add_child(core)

	var outer := _make_fire(flame_tex, 14, 0.6, Vector2(0.20, 0.42), 0.2, 0.4, 12.0, Color(1.0, 0.55, 0.18, 0.55))
	outer.position.y = 0.34
	holder.add_child(outer)

	# тлеющее ложе под брёвнами
	var bed_mat := StandardMaterial3D.new()
	bed_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bed_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bed_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bed_mat.albedo_texture = soft
	bed_mat.albedo_color = Color(1.6, 0.55, 0.12, 0.55)
	var bed := MeshInstance3D.new()
	var bed_mesh := CylinderMesh.new()
	bed_mesh.top_radius = 0.42
	bed_mesh.bottom_radius = 0.42
	bed_mesh.height = 0.01
	bed_mesh.radial_segments = 20
	bed.mesh = bed_mesh
	bed.material_override = bed_mat
	bed.position.y = 0.05
	holder.add_child(bed)

	# искры
	var sparks := CPUParticles3D.new()
	sparks.amount = 12
	sparks.lifetime = 1.7
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.18
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 35.0
	sparks.gravity = Vector3(0, 1.1, 0)
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.4
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.2
	sparks.color = Color(1.0, 0.72, 0.28, 1.0)
	var spark_quad := QuadMesh.new()
	spark_quad.size = Vector2(0.028, 0.028)
	sparks.mesh = spark_quad
	var spark_mat := _fire_material(soft, false)
	spark_mat.albedo_color = Color(1.9, 1.2, 0.45, 0.9)
	sparks.material_override = spark_mat
	sparks.position.y = 0.3
	holder.add_child(sparks)

	# дым
	var smoke := CPUParticles3D.new()
	smoke.amount = 8
	smoke.lifetime = 2.8
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.2
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 18.0
	smoke.gravity = Vector3(0.15, 0.35, 0.0)
	smoke.initial_velocity_min = 0.35
	smoke.initial_velocity_max = 0.7
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 1.6
	smoke.color = Color(0.5, 0.48, 0.45, 0.1)
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.9, 0.9)
	smoke.mesh = smoke_quad
	var smoke_mat := _fire_material(soft, true)
	smoke.material_override = smoke_mat
	smoke.position.y = 0.6
	holder.add_child(smoke)

	return holder

static func _make_fire(soft: Texture2D, amount: int, lifetime: float, quad: Vector2, vmin: float, vmax: float, spread: float, tint: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.14
	p.direction = Vector3(0, 1, 0)
	p.spread = spread
	p.gravity = Vector3(0, 1.3, 0)
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.angle_min = -22.0
	p.angle_max = 22.0
	p.hue_variation_min = -0.035
	p.hue_variation_max = 0.035
	p.scale_amount_min = 0.45
	p.scale_amount_max = 1.0
	p.color = tint

	var q := QuadMesh.new()
	q.size = quad
	p.mesh = q
	p.material_override = _fire_material(soft, false)

	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint.r * 1.6, tint.g * 1.4, tint.b * 1.1, tint.a))
	ramp.set_color(1, Color(tint.r * 0.6, tint.g * 0.25, tint.b * 0.1, 0.0))
	ramp.add_point(0.45, Color(tint.r * 1.1, tint.g * 0.55, tint.b * 0.18, tint.a * 0.8))
	p.color_ramp = ramp
	return p

static func _fire_material(soft: Texture2D, smoke: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if not smoke else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = soft
	mat.albedo_color = Color(1.35, 0.72, 0.24, 0.85) if not smoke else Color(0.34, 0.33, 0.31, 0.10)
	mat.vertex_color_use_as_albedo = false
	mat.disable_receive_shadows = true
	return mat

static func _add_light(root: Node3D) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.9, 0)
	light.light_color = Color(1.0, 0.55, 0.22)
	light.light_energy = 2.4
	light.omni_range = 15.0
	light.shadow_enabled = false
	root.add_child(light)
	return light

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
