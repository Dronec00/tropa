extends Node3D

## Витрина модели главного героя.
##
##   ./run.sh model
##
## ЛКМ — вращать, колесо — зум, ПКМ — сдвинуть кадр.
## 1/2/3 — стойка/шаг/бег, 4/5/6 — удары, 7 — блок, 8 — меч в руке,
## C — ракурс, L — свет, T — автоповорот, W — сетка, H — снять шляпу,
## F12 — скриншот, E — экспорт .glb, Esc — в меню.
##
## Автоскриншоты для проверки:
##   godot --path . res://scenes/model_viewer.tscn --resolution 900x1200 -- \
##       --shot docs/shot.png --angle 0 --dist 3.6 --pose idle --clean

const DhampirScript := preload("res://scripts/dhampir_model.gd")

const SHOTS := [
	{"name": "весь рост", "dist": 3.55, "pitch": 0.06, "target": 1.03},
	{"name": "лицо", "dist": 1.28, "pitch": 0.10, "target": 1.62},
	{"name": "спина и меч", "dist": 3.15, "pitch": 0.16, "target": 1.15},
	{"name": "снизу", "dist": 3.05, "pitch": -0.30, "target": 1.22},
]

const LIGHTS := ["студия", "луна", "огонь"]

var _model: Node3D
var _parts: Dictionary
var _animator: Node
var _camera: Camera3D
var _env: Environment
var _world: WorldEnvironment

var _orbit := 0.55
var _pitch := 0.05
var _dist := 3.55
var _target := 1.03
var _pan := Vector3.ZERO
var _dragging := false
var _panning := false
var _auto := false
var _light_index := 0
var _shot_index := 0
var _walk := 0.0
var _drawn := false
var _block := false
var _hat_off := false
var _ui: Control
var _hint: Label
var _stats: Label

var _key: DirectionalLight3D
var _fill: OmniLight3D
var _rim: OmniLight3D
var _face: OmniLight3D

var _args: Dictionary = {}
var _shot_done := false

func _ready() -> void:
	_parse_args()
	_setup_world()
	_setup_model()
	_setup_ui()
	_apply_light()
	_apply_shot()
	if _args.has("angle"):
		_orbit = deg_to_rad(float(_args["angle"]))
	if _args.has("pitch"):
		_pitch = float(_args["pitch"])
	if _args.has("dist"):
		_dist = float(_args["dist"])
	if _args.has("target"):
		_target = float(_args["target"])
	if _args.has("pose"):
		_apply_pose(String(_args["pose"]))
	_update_camera()
	if _args.has("shot"):
		_capture.call_deferred()

func _parse_args() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < argv.size():
		var a: String = argv[i]
		if a.begins_with("--"):
			var key: String = a.substr(2)
			if key == "clean" or key == "turntable":
				_args[key] = true
			elif i + 1 < argv.size():
				_args[key] = argv[i + 1]
				i += 1
		i += 1

# =========================================================================

func _setup_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.030, 0.034, 0.042)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.28, 0.32, 0.40)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.05
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_bloom = 0.10
	_env.ssao_enabled = true
	_env.ssao_radius = 0.7
	_env.ssao_intensity = 1.6
	_world = WorldEnvironment.new()
	_world.environment = _env
	add_child(_world)

	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-32.0, 205.0, 0.0)
	_key.light_color = Color(0.86, 0.90, 1.0)
	_key.light_energy = 3.8
	_key.shadow_enabled = true
	_key.directional_shadow_max_distance = 18.0
	_key.shadow_blur = 1.2
	add_child(_key)

	_fill = OmniLight3D.new()
	_fill.position = Vector3(1.5, 1.55, -2.0)
	_fill.light_color = Color(0.62, 0.74, 1.0)
	_fill.light_energy = 2.6
	_fill.omni_range = 7.0
	_fill.omni_attenuation = 1.2
	add_child(_fill)

	_rim = OmniLight3D.new()
	_rim.position = Vector3(-1.2, 2.1, 2.3)
	_rim.light_color = Color(1.0, 0.66, 0.38)
	_rim.light_energy = 4.2
	_rim.omni_range = 6.0
	_rim.omni_attenuation = 1.4
	add_child(_rim)

	_face = OmniLight3D.new()
	_face.position = Vector3(0.0, 1.66, -1.15)
	_face.light_color = Color(0.86, 0.89, 1.0)
	_face.light_energy = 0.85
	_face.omni_range = 2.1
	_face.omni_attenuation = 1.6
	_face.shadow_enabled = false
	add_child(_face)

	var ground: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 2.6
	disc.bottom_radius = 2.6
	disc.height = 0.05
	disc.radial_segments = 64
	ground.mesh = disc
	ground.position = Vector3(0.0, -0.03, 0.0)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.075, 0.080, 0.092)
	gm.roughness = 0.88
	gm.metallic = 0.05
	ground.material_override = gm
	add_child(ground)

	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 2.52
	torus.outer_radius = 2.58
	torus.rings = 96
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.005, 0.0)
	var rm: StandardMaterial3D = StandardMaterial3D.new()
	rm.albedo_color = Color(0.30, 0.24, 0.15)
	rm.metallic = 0.85
	rm.roughness = 0.38
	ring.material_override = rm
	add_child(ring)

	_camera = Camera3D.new()
	_camera.fov = 46.0
	_camera.current = true
	_camera.near = 0.05
	add_child(_camera)

func _setup_model() -> void:
	_model = Node3D.new()
	_model.name = "Hero"
	add_child(_model)
	_parts = DhampirScript.build(_model)
	_animator = _parts.get("animator") as Node
	_apply_pose("idle")

func _setup_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)

	var title: Label = Label.new()
	title.position = Vector2(26, 20)
	title.size = Vector2(760, 40)
	title.text = "ДАМПИР · модель главного героя"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	_ui.add_child(title)

	_hint = Label.new()
	_hint.position = Vector2(26, 52)
	_hint.size = Vector2(900, 80)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.68, 0.67, 0.62, 0.85))
	_hint.text = ("ЛКМ — вращать · колесо — зум · ПКМ — сдвинуть\n"
			+ "1 стойка · 2 шаг · 3 бег · 4-6 удары · 7 блок · 8 меч\n"
			+ "C ракурс · L свет · T автоповорот · W сетка · H шляпа · F12 скрин · E .glb")
	_ui.add_child(_hint)

	_stats = Label.new()
	_stats.position = Vector2(26, 0)
	_stats.size = Vector2(520, 120)
	_stats.add_theme_font_size_override("font_size", 13)
	_stats.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70, 0.9))
	_stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_stats.offset_left = 26
	_stats.offset_top = -112
	_ui.add_child(_stats)
	_update_stats()

	if _args.has("clean"):
		_ui.visible = false

func _update_stats() -> void:
	var meshes: int = 0
	var tris: int = 0
	var mats: Dictionary = {}
	_count(_model, mats)
	meshes = int(mats.get("meshes", 0))
	tris = int(mats.get("tris", 0))
	_stats.text = "мешей: %d · треугольников: %d · материалов: %d\nвысота: %.2f м · ракурс: %s · свет: %s" % [
		meshes, tris, int(mats.get("materials", 0)), float(_parts.get("height", 1.93)),
		SHOTS[_shot_index]["name"], LIGHTS[_light_index]]

func _count(node: Node, acc: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		acc["meshes"] = int(acc.get("meshes", 0)) + 1
		if mi.mesh != null:
			acc["tris"] = int(acc.get("tris", 0)) + mi.mesh.get_faces().size() / 3
		if mi.material_override != null:
			acc["materials"] = acc.get("materials", 0)
			acc["_mat_ids"] = acc.get("_mat_ids", {})
			acc["_mat_ids"][mi.material_override.get_instance_id()] = true
			acc["materials"] = acc["_mat_ids"].size()
	for child in node.get_children():
		_count(child, acc)

func _apply_light() -> void:
	match _light_index:
		0:
			_env.background_color = Color(0.030, 0.034, 0.042)
			_env.ambient_light_color = Color(0.28, 0.32, 0.40)
			_env.ambient_light_energy = 0.55
			_key.light_color = Color(0.82, 0.87, 1.0)
			_key.light_energy = 3.8
			_fill.light_color = Color(0.62, 0.74, 1.0)
			_fill.light_energy = 2.6
			_rim.light_color = Color(1.0, 0.66, 0.38)
			_rim.light_energy = 3.2
		1:
			_env.background_color = Color(0.012, 0.020, 0.038)
			_env.ambient_light_color = Color(0.16, 0.24, 0.42)
			_env.ambient_light_energy = 0.35
			_key.light_color = Color(0.52, 0.66, 1.0)
			_key.light_energy = 1.5
			_fill.light_color = Color(0.30, 0.44, 0.85)
			_fill.light_energy = 1.0
			_rim.light_color = Color(0.55, 0.72, 1.0)
			_rim.light_energy = 2.5
		_:
			_env.background_color = Color(0.035, 0.020, 0.014)
			_env.ambient_light_color = Color(0.30, 0.16, 0.08)
			_env.ambient_light_energy = 0.40
			_key.light_color = Color(1.0, 0.62, 0.30)
			_key.light_energy = 1.9
			_fill.light_color = Color(0.90, 0.36, 0.12)
			_fill.light_energy = 2.4
			_rim.light_color = Color(1.0, 0.80, 0.45)
			_rim.light_energy = 4.0

func _apply_shot() -> void:
	_shot_index = _shot_index % SHOTS.size()
	var s: Dictionary = SHOTS[_shot_index]
	_dist = float(s["dist"])
	_pitch = float(s["pitch"])
	_target = float(s["target"])
	_pan = Vector3.ZERO

func _apply_pose(name: String) -> void:
	if _animator == null:
		return
	match name:
		"idle":
			_walk = 0.0
			_set_locomotion(0.0)
		"walk":
			_walk = 2.6
			_set_locomotion(2.6)
		"run":
			_walk = 6.2
			_set_locomotion(6.2)
		"attack1", "attack":
			_animator.call("play_attack", 0)
		"attack2":
			_animator.call("play_attack", 1)
		"attack3":
			_animator.call("play_attack", 2)
		"block":
			_block = true
			_animator.call("set_block", true)
		"draw":
			_drawn = true
			_animator.call("set_drawn", true)
		"sheathe":
			_drawn = false
			_animator.call("set_drawn", false)

func _set_locomotion(speed: float) -> void:
	if _animator != null and _animator.has_method("set_locomotion"):
		_animator.call("set_locomotion", speed)

# =========================================================================

func _process(delta: float) -> void:
	if _auto:
		_orbit += delta * 0.45
	_update_camera()
	if _args.has("turntable"):
		_model.rotate_y(delta * 0.35)

func _update_camera() -> void:
	if _camera == null:
		return
	var focus: Vector3 = _pan + Vector3(0.0, _target, 0.0)
	var dir: Vector3 = Vector3(sin(_orbit), 0.0, -cos(_orbit))
	var pos: Vector3 = focus + dir * _dist * cos(_pitch) + Vector3.UP * sin(_pitch) * _dist
	_camera.position = pos
	_camera.look_at(focus, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(0.55, _dist - 0.22)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = minf(9.0, _dist + 0.22)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging:
			_orbit -= mm.relative.x * 0.008
			_pitch = clampf(_pitch + mm.relative.y * 0.006, -0.9, 1.0)
		elif _panning:
			var right: Vector3 = _camera.global_transform.basis.x
			var up: Vector3 = _camera.global_transform.basis.y
			_pan -= right * mm.relative.x * 0.0016 * _dist
			_pan += up * mm.relative.y * 0.0016 * _dist
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_apply_pose("idle")
			KEY_2:
				_apply_pose("walk")
			KEY_3:
				_apply_pose("run")
			KEY_4:
				_apply_pose("attack1")
			KEY_5:
				_apply_pose("attack2")
			KEY_6:
				_apply_pose("attack3")
			KEY_7:
				_block = not _block
				_animator.call("set_block", _block)
			KEY_8:
				if _block:
					_block = false
					_animator.call("set_block", false)
				else:
					_drawn = not _drawn
					_animator.call("set_drawn", _drawn)
			KEY_C:
				_shot_index = (_shot_index + 1) % SHOTS.size()
				_apply_shot()
				_update_stats()
			KEY_L:
				_light_index = (_light_index + 1) % LIGHTS.size()
				_apply_light()
				_update_stats()
			KEY_T:
				_auto = not _auto
			KEY_W:
				var vp: Viewport = get_viewport()
				vp.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if vp.debug_draw == Viewport.DEBUG_DRAW_DISABLED else Viewport.DEBUG_DRAW_DISABLED
			KEY_H:
				_hat_off = not _hat_off
				var hat: Node3D = _find_hat()
				if hat != null:
					hat.visible = not _hat_off
			KEY_R:
				_orbit = 0.55
				_pitch = 0.05
				_dist = 3.55
				_target = 1.03
				_pan = Vector3.ZERO
			KEY_F12:
				_save_shot("user://screenshot_%d.png" % Time.get_ticks_msec(), true)
			KEY_E:
				_export_glb()
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _find_hat() -> Node3D:
	for child in _model.get_children():
		var found: Node3D = _search_node(child, "Hat")
		if found != null:
			return found
	return null

func _search_node(node: Node, target: String) -> Node3D:
	if node.name == target and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found: Node3D = _search_node(child, target)
		if found != null:
			return found
	return null

# =========================================================================

func _capture() -> void:
	var size: Vector2i = Vector2i(900, 1200)
	if _args.has("shot-size"):
		var parts: PackedStringArray = String(_args["shot-size"]).split("x")
		if parts.size() == 2:
			size = Vector2i(int(parts[0]), int(parts[1]))
	var vp: SubViewport = SubViewport.new()
	vp.size = size
	vp.world_3d = get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam: Camera3D = Camera3D.new()
	cam.fov = _camera.fov
	cam.near = _camera.near
	cam.current = true
	vp.add_child(cam)
	cam.global_transform = _camera.global_transform
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = String(_args.get("shot", "user://model.png"))
	_save_image(img, path)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _save_image(img: Image, path: String) -> void:
	var abs_path: String = path
	if path.begins_with("user://"):
		abs_path = ProjectSettings.globalize_path(path)
	elif not path.begins_with("/"):
		abs_path = ProjectSettings.globalize_path("res://" + path)
	var err: Error = img.save_png(abs_path)
	print("[viewer] screenshot %s -> %s" % [abs_path, error_string(err)])

func _save_shot(path: String, notify: bool) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	_save_image(img, path)
	if notify:
		_hint.text = "Скриншот: %s" % ProjectSettings.globalize_path(path)

func _export_glb() -> void:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var root: Node3D = _model
	var err: Error = doc.append_from_scene(root, state)
	if err != OK:
		_hint.text = "Экспорт не удался: %s" % error_string(err)
		return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://models")):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://models"))
	var path: String = ProjectSettings.globalize_path("res://models/dhampir.glb")
	var werr: Error = doc.write_to_filesystem(state, path)
	_hint.text = "Экспорт: %s (%s)" % [path, error_string(werr)]
	print("[viewer] glb %s -> %s" % [path, error_string(werr)])
