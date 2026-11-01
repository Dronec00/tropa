extends Node3D

## Лаборатория травы: ровное поле, ночь, свободная камера.
## Нужна, чтобы смотреть траву вблизи, не грузя весь мир.

class FlatGround:
	func height_at(_x: float, _z: float) -> float:
		return 0.0
	func slope_at(_x: float, _z: float) -> float:
		return 0.0

var _cam: Camera3D
var _yaw := 0.0
var _pitch := -0.32
var _label: Label

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_grass()
	_build_camera()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.34)
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_density = 0.018

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var fill := OmniLight3D.new()
	fill.light_energy = 2.0
	fill.omni_range = 30.0
	fill.position = Vector3(0.0, 6.0, 4.0)
	add_child(fill)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.65, 0.75, 0.95)
	moon.light_energy = 1.6
	moon.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(28.0), 0.0)
	moon.shadow_enabled = true
	add_child(moon)

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(140.0, 140.0)
	plane.subdivide_width = 2
	plane.subdivide_depth = 2

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.60, 0.44)
	mat.roughness = 1.0
	if ResourceLoader.exists("res://assets/textures/photo/ground_color.jpg"):
		mat.albedo_texture = load("res://assets/textures/photo/ground_color.jpg")
		mat.uv1_scale = Vector3(14.0, 14.0, 1.0)
		if ResourceLoader.exists("res://assets/textures/photo/ground_normal.jpg"):
			mat.normal_enabled = true
			mat.normal_texture = load("res://assets/textures/photo/ground_normal.jpg")
			mat.uv1_scale = Vector3(14.0, 14.0, 1.0)

	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = mat
	add_child(ground)

func _build_grass() -> void:
	var grass := GrassField.new()
	add_child(grass)
	grass.populate(FlatGround.new(), 60000, 46.0)

func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.position = Vector3(0.0, 2.4, 6.0)
	add_child(_cam)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "РЕЖИМ: ТРАВА\nWASD — идти  мышь — смотреть  Esc — в меню"
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
			_cam.position += -_cam.global_transform.basis.z * 1.2
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.position -= -_cam.global_transform.basis.z * 1.2
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

	var speed := 5.0
	if dir.length_squared() > 0.0:
		_cam.position += dir.normalized() * speed * delta
	_cam.position.y = clampf(_cam.position.y, 0.35, 12.0)
