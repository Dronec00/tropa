extends Node3D

## Витрина врагов: все типы в ряд, медленно вращаются.
## ./run.sh enemies

const EnemyScene := preload("res://scenes/enemy.tscn")
const LabStateScript := preload("res://scripts/lab_state.gd")

var _turntable: Node3D
var _camera: Camera3D
var _dragging := false
var _orbit := 0.0
var _distance := 10.0

const KINDS := ["wolf", "cultist", "wailer", "leshy", "kikimora"]
const NAMES := ["волк", "послушник", "плакальщица", "леший", "кикимора"]

func _ready() -> void:
	_setup_world()
	_setup_showcase()
	_setup_ui()
	_update_camera()

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.33, 0.36, 0.42)
	env.ambient_light_energy = 1.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 30, 0)
	key.light_color = Color(0.68, 0.76, 0.95)
	key.light_energy = 2.2
	key.shadow_enabled = true
	add_child(key)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.10, 0.09)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 1.0, 30.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)

	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.current = true
	add_child(_camera)

func _setup_showcase() -> void:
	_turntable = Node3D.new()
	add_child(_turntable)

	var only: String = LabStateScript.enemy
	var kinds: Array = KINDS
	var names: Array = NAMES
	if only != "" and KINDS.has(only):
		var idx := KINDS.find(only)
		kinds = [only]
		names = [NAMES[idx]]
		_distance = 6.0

	for i in kinds.size():
		var enemy = EnemyScene.instantiate()
		enemy.setup(kinds[i])
		_turntable.add_child(enemy)
		var x := 0.0 if kinds.size() == 1 else (float(i) - float(kinds.size() - 1) * 0.5) * 2.6
		enemy.global_position = Vector3(x, 0.2, 0.0)

		var label := Label3D.new()
		label.text = names[i]
		label.font_size = 48
		label.pixel_size = 0.006
		label.modulate = Color(0.85, 0.83, 0.78)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 3.6, 0.0)
		enemy.add_child(label)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(28, 24)
	label.size = Vector2(900, 40)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	label.text = "РЕЖИМ: ВРАГИ    ЛКМ тащить — поворот   колесо — зум"
	layer.add_child(label)

func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		LabStateScript.enemy = ""
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_distance = maxf(4.0, _distance - 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_distance = minf(16.0, _distance + 0.6)
	elif event is InputEventMouseMotion and _dragging:
		_orbit -= event.relative.x * 0.008
	_update_camera()

func _update_camera() -> void:
	if _camera == null:
		return
	var target := Vector3(0.0, 1.1, 0.0)
	_camera.position = target + Vector3(sin(_orbit) * _distance, 1.4, cos(_orbit) * _distance)
	_camera.look_at(target)
