extends Node3D

## Витрина одного объекта: дерево, куст, папоротник, камыш, валун, лужа, изба.
## Открывается из меню, чтобы не грузить весь мир ради одного ассета.

const TreeLibScript := preload("res://scripts/tree_lib.gd")
const HutScript := preload("res://scripts/hut.gd")

var _cam: Camera3D
var _yaw := 0.0
var _pitch := -0.12

class FlatGround:
	func height_at(_x: float, _z: float) -> float:
		return 0.0
	func slope_at(_x: float, _z: float) -> float:
		return 0.0

func _ready() -> void:
	_build_environment()
	_build_ground()
	_spawn_objects()
	_build_camera()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.44)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_density = 0.012

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.72, 0.80, 0.95)
	moon.light_energy = 2.2
	moon.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(35.0), 0.0)
	moon.shadow_enabled = true
	add_child(moon)

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.52, 0.38)
	mat.roughness = 1.0
	if ResourceLoader.exists("res://assets/textures/photo/ground_color.jpg"):
		mat.albedo_texture = load("res://assets/textures/photo/ground_color.jpg")
		mat.uv1_scale = Vector3(10.0, 10.0, 1.0)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = mat
	add_child(ground)

func _tree_material(dark: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tree.gdshader")
	var bark_path := "res://assets/textures/birch_bark.png"
	if dark and ResourceLoader.exists("res://assets/textures/photo/bark_color.jpg"):
		bark_path = "res://assets/textures/photo/bark_color.jpg"
	mat.set_shader_parameter("bark_tex", load(bark_path))
	mat.set_shader_parameter("leaf_tex", load("res://assets/textures/leaf_atlas.png"))
	mat.set_shader_parameter("wind", 0.22)
	if dark and ResourceLoader.exists("res://assets/textures/photo/bark_normal.jpg"):
		mat.set_shader_parameter("bark_normal", load("res://assets/textures/photo/bark_normal.jpg"))
		mat.set_shader_parameter("use_normal", 1.0)
	return mat

func _spawn_objects() -> void:
	var kind := LabState.object_name
	if OS.get_environment("OBJECT_KIND") != "":
		kind = OS.get_environment("OBJECT_KIND")
	if kind == "":
		kind = "birch"

	if kind == "rock":
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.42, 0.46, 0.38)
		stone.roughness = 0.9
		if ResourceLoader.exists("res://assets/textures/photo/moss_color.jpg"):
			stone.albedo_texture = load("res://assets/textures/photo/moss_color.jpg")
			stone.normal_enabled = true
			stone.normal_texture = load("res://assets/textures/photo/moss_normal.jpg")
			stone.uv1_scale = Vector3(2.0, 2.0, 1.0)
		for i in 4:
			var sphere := SphereMesh.new()
			sphere.radius = 0.8
			sphere.height = 1.1
			sphere.radial_segments = 14
			sphere.rings = 8
			var node := MeshInstance3D.new()
			node.mesh = sphere
			node.material_override = stone
			node.position = Vector3(-2.4 + i * 1.6, 0.35, 0.0)
			node.scale = Vector3(1.2, 0.8, 1.0)
			add_child(node)
		return

	if kind == "puddle":
		var puddle := MeshInstance3D.new()
		puddle.mesh = _patch(0.0, 0.0, 3.0)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/puddle.gdshader")
		mat.set_shader_parameter("ripple", _ripple_texture())
		puddle.material_override = mat
		add_child(puddle)
		return

	if kind == "hut":
		HutScript.build(self, Vector3(0.0, 0.0, 0.0), 0.0)
		return

	var dark := kind in ["cedar", "spruce", "willow", "bush", "fern", "reed"]
	var mat := _tree_material(dark)
	for i in 5:
		var mesh := TreeLibScript.build(kind, 500 + i * 31, false)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = mat
		node.position = Vector3(-6.0 + i * 3.0, 0.0, 0.0)
		node.rotation.y = float(i) * 0.7
		add_child(node)

func _patch(cx: float, cz: float, radius: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.append(Vector3(cx, 0.02, cz))
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))
	var segs := 28
	for i in segs:
		var a := TAU * float(i) / float(segs)
		verts.append(Vector3(cx + cos(a) * radius, 0.02, cz + sin(a) * radius))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
	for i in segs:
		indices.append(0)
		indices.append(1 + i)
		indices.append(1 + (i + 1) % segs)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _ripple_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.04
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	return tex

func _kind() -> String:
	var k := LabState.object_name
	if OS.get_environment("OBJECT_KIND") != "":
		k = OS.get_environment("OBJECT_KIND")
	if k == "":
		k = "birch"
	return k

func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 65.0
	var span: float = 12.0
	_cam.position = Vector3(0.0, 4.2, span)
	add_child(_cam)
	_cam.look_at(Vector3(0.0, 2.0, 0.0))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "ОБЪЕКТ: " + _kind().to_upper() + "\nWASD — идти  мышь — смотреть  Esc — в меню"
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	layer.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.0025
		_pitch = clampf(_pitch - motion.relative.y * 0.0025, -1.4, 1.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _process(delta: float) -> void:
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	var dir := Vector3.ZERO
	var basis := Basis(Vector3.UP, _yaw)
	if Input.is_key_pressed(KEY_W):
		dir -= basis.z
	if Input.is_key_pressed(KEY_S):
		dir += basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= basis.x
	if Input.is_key_pressed(KEY_D):
		dir += basis.x
	if Input.is_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT):
		dir -= Vector3.UP
	if dir.length_squared() > 0.0:
		_cam.position += dir.normalized() * 6.0 * delta
	_cam.position.y = clampf(_cam.position.y, 0.4, 25.0)
