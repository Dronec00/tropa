extends Node3D

## Витрина объекта: 8 вариантов в ряд, чтобы видеть разброс и общий стиль.

const TreeLibScript := preload("res://scripts/tree_lib.gd")
const HutScript := preload("res://scripts/hut.gd")
const LibScript := preload("res://libraries/object_library.gd")

var _cam: Camera3D
var _yaw := 0.0
var _pitch := -0.145
var _span := 24.0

func _ready() -> void:
	_build_environment()
	_build_ground()
	_spawn_objects()
	_build_camera()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _kind() -> String:
	var k := LabState.object_name
	if OS.get_environment("OBJECT_KIND") != "":
		k = OS.get_environment("OBJECT_KIND")
	if k == "":
		k = "birch"
	return k

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.44)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_density = 0.008

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.74, 0.82, 0.96)
	moon.light_energy = 2.4
	moon.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(32.0), 0.0)
	moon.shadow_enabled = true
	add_child(moon)

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(160.0, 160.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.60, 0.50, 0.37)
	mat.roughness = 1.0
	if ResourceLoader.exists("res://assets/textures/photo/ground_color.jpg"):
		mat.albedo_texture = load("res://assets/textures/photo/ground_color.jpg")
		mat.uv1_scale = Vector3(12.0, 12.0, 1.0)
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

func _stone_material() -> StandardMaterial3D:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.45, 0.38)
	stone.roughness = 0.85
	if ResourceLoader.exists("res://assets/textures/photo/moss_color.jpg"):
		stone.albedo_texture = load("res://assets/textures/photo/moss_color.jpg")
		stone.normal_enabled = true
		stone.normal_texture = load("res://assets/textures/photo/moss_normal.jpg")
		stone.uv1_scale = Vector3(1.6, 1.6, 1.0)
	return stone

func _moss_material(amount: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/moss_rock.gdshader")
	if ResourceLoader.exists("res://assets/textures/photo/ground_color.jpg"):
		mat.set_shader_parameter("stone_albedo", load("res://assets/textures/photo/ground_color.jpg"))
		mat.set_shader_parameter("stone_normal", load("res://assets/textures/photo/ground_normal.jpg"))
	if ResourceLoader.exists("res://assets/textures/photo/moss_color.jpg"):
		mat.set_shader_parameter("moss_albedo", load("res://assets/textures/photo/moss_color.jpg"))
		mat.set_shader_parameter("moss_normal", load("res://assets/textures/photo/moss_normal.jpg"))
	mat.set_shader_parameter("moss_amount", amount)
	return mat

func _puddle_material(rough: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/puddle.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.04
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	mat.set_shader_parameter("ripple", tex)
	mat.set_shader_parameter("ripple_scale", 7.0)
	mat.set_shader_parameter("edge_softness", 0.34)
	return mat

func _spawn_objects() -> void:
	var kind := _kind()
	var count := 8
	var entries: Array = LibScript.variants(kind, count)
	var spacing: float = LibScript.spacing(kind)
	_span = maxf(10.0, spacing * float(count) + 4.0)

	if kind == "hut":
		HutScript.build(self, Vector3(0.0, 0.0, 0.0), 0.0)
		return

	if kind == "moss_rock" or kind == "rock":
		var stone: Material = _moss_material(0.95) if kind == "moss_rock" else _stone_material()
		for e in entries:
			var node := MeshInstance3D.new()
			node.mesh = LibScript.make_stone(e)
			node.material_override = stone
			var x := (float(e["index"]) - float(count - 1) * 0.5) * spacing
			node.position = Vector3(x, float(e["radius"]) * 0.75, 0.0)
			node.rotation.y = float(e["yaw"])
			add_child(node)
			_label(x, 0.0, "#" + str(e["index"]))
		return

	if kind == "puddle":
		for e in entries:
			var node := MeshInstance3D.new()
			node.mesh = _patch(0.0, 0.0, float(e["radius"]) * 2.2)
			node.material_override = _puddle_material(float(e["rough"]))
			var x := (float(e["index"]) - float(count - 1) * 0.5) * spacing
			node.position = Vector3(x, 0.02, 0.0)
			add_child(node)
			_label(x, 0.0, "#" + str(e["index"]))
		return

	var dark := kind in ["cedar", "spruce", "willow", "bush", "fern", "reed"]
	var mat := _tree_material(dark)
	var base_y := 0.0
	if kind in ["fern", "reed", "bush"]:
		base_y = 0.0

	for e in entries:
		var mesh := TreeLibScript.build(kind, int(e["seed"]), false)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = mat
		var x := (float(e["index"]) - float(count - 1) * 0.5) * spacing
		node.position = Vector3(x, base_y, 0.0)
		node.rotation.y = float(e["yaw"])
		node.rotation.z = float(e["lean"])
		node.scale = Vector3.ONE * float(e["scale"])
		add_child(node)
		_label(x, TreeLibScript.height_of(kind) * float(e["scale"]) + 0.6, "#" + str(e["index"]))

func _label(x: float, y: float, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.85, 0.9, 0.8)
	label.position = Vector3(x, maxf(y, 0.8), 0.0)
	add_child(label)

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

func _build_camera() -> void:
	if _kind() == "hut":
		_cam = Camera3D.new()
		_cam.fov = 62.0
		_cam.position = Vector3(0.0, 7.0, 17.0)
		_pitch = -0.22
		_yaw = 0.0
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
		add_child(_cam)
		return
	var row_half := _span * 0.5
	var cam_z := row_half * 2.4
	var cam_y := row_half * 1.2 + 2.0
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.position = Vector3(0.0, cam_y, cam_z)
	_pitch = -0.45
	_yaw = 0.0
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	add_child(_cam)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "ОБЪЕКТ: " + _kind().to_upper() + "  —  8 вариантов\nWASD — идти  мышь — смотреть  Esc — в меню"
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	layer.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.0025
		_pitch = clampf(_pitch - motion.relative.y * 0.0025, -1.4, 1.0)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.position += -_cam.global_transform.basis.z * 1.4
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.position -= -_cam.global_transform.basis.z * 1.4
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
		_cam.position += dir.normalized() * 7.0 * delta
	_cam.position.y = clampf(_cam.position.y, 0.4, 40.0)
