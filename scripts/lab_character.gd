extends Node3D

## Верстак персонажа: только рыцарь, свет и камера. Никакого леса и врагов.
## ./run.sh character

const KnightModelScript := preload("res://scripts/knight_model.gd")
const KnightV2Path := "res://scripts/knight_model_v2.gd"

var _camera: Camera3D
var _model: Node3D
var _animator: Node
var _label: Label

var _orbit := 0.55
var _distance := 3.6
var _pitch := -0.12
var _dragging := false
var _walk_speed := 0.0

func _ready() -> void:
	_setup_world()
	_setup_model()
	_setup_ui()
	_update_camera()

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.45)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 38, 0)
	key.light_color = Color(0.7, 0.78, 0.95)
	key.light_energy = 1.6
	key.shadow_enabled = true
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.6, 1.9, -1.8)
	rim.light_color = Color(1.0, 0.72, 0.45)
	rim.light_energy = 2.2
	rim.omni_range = 6.0
	add_child(rim)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 24.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.11, 0.10)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24.0, 1.0, 24.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)

	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.current = true
	add_child(_camera)

func _setup_model() -> void:
	_model = Node3D.new()
	add_child(_model)

	var parts: Dictionary
	if ResourceLoader.exists(KnightV2Path):
		var script: Script = load(KnightV2Path)
		parts = script.build(_model)
		print("[lab] knight v2 loaded")
	else:
		parts = KnightModelScript.build(_model)
		print("[lab] knight v1")

	_animator = parts.get("animator")
	if _animator == null:
		print("[lab] animator отсутствует — анимации недоступны")

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_label = Label.new()
	_label.position = Vector2(28, 24)
	_label.size = Vector2(900, 60)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	_label.text = "РЕЖИМ: ПЕРСОНАЖ\n1 — стойка   2 — ходьба   3 — удар   ЛКМ тащить — поворот   колесо — зум"
	root.add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_distance = maxf(1.6, _distance - 0.35)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_distance = minf(9.0, _distance + 0.35)
	elif event is InputEventMouseMotion and _dragging:
		_orbit -= event.relative.x * 0.01
		_pitch = clampf(_pitch - event.relative.y * 0.006, -0.9, 0.6)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_walk_speed = 0.0
				_set_locomotion(0.0)
			KEY_2:
				_walk_speed = 2.6
				_set_locomotion(2.6)
			KEY_3:
				_play_attack()

	_update_camera()

func _set_locomotion(speed: float) -> void:
	if _animator and _animator.has_method("set_locomotion"):
		_animator.set_locomotion(speed)

func _play_attack() -> void:
	if _animator and _animator.has_method("play_attack"):
		_animator.play_attack()
	else:
		print("[lab] у модели нет аниматора — удар не проиграть")

func _update_camera() -> void:
	if _camera == null:
		return
	var target := Vector3(0.0, 1.05, 0.0)
	var offset := Vector3(sin(_orbit) * cos(_pitch), sin(_pitch) + 0.15, cos(_orbit) * cos(_pitch)) * _distance
	_camera.position = target + offset
	_camera.look_at(target + Vector3(0.0, 0.06, 0.0))
