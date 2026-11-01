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
	{"name": "весь рост", "dist": 3.40, "pitch": 0.14, "target": 1.02, "angle": 0.42},
	{"name": "лицо", "dist": 1.12, "pitch": 0.07, "target": 1.66, "angle": 0.00},
	{"name": "кисти", "dist": 1.05, "pitch": 0.03, "target": 0.86, "angle": 0.30},
	{"name": "спина и меч", "dist": 3.15, "pitch": 0.20, "target": 1.10, "angle": 3.14},
	{"name": "снизу", "dist": 3.05, "pitch": -0.26, "target": 1.20, "angle": 0.42},
]

const LIGHTS := ["студия", "луна", "огонь"]

var _model: Node3D
var _parts: Dictionary
var _animator: Node
var _camera: Camera3D
var _env: Environment
var _world: WorldEnvironment

var _orbit := 0.42
var _pitch := 0.14
var _dist := 3.40
var _dist_target := 3.40
var _target := 1.02
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

var _ground: MeshInstance3D
var _ring: MeshInstance3D
var _silhouette := false
var _sil_mat: StandardMaterial3D
var _saved_mats: Dictionary = {}

var _args: Dictionary = {}
var _shot_done := false

func _ready() -> void:
	_parse_args()
	_setup_world()
	_setup_model()
	_setup_ui()
	_apply_light()
	if _args.has("light"):
		var want: String = String(_args["light"]).to_lower()
		for i in range(LIGHTS.size()):
			if String(LIGHTS[i]).to_lower() == want:
				_light_index = i
		_apply_light()
	_apply_shot()
	if _args.has("angle"):
		_orbit = deg_to_rad(float(_args["angle"]))
	if _args.has("pitch"):
		_pitch = float(_args["pitch"])
	if _args.has("dist"):
		_dist = float(_args["dist"])
		_dist_target = _dist
	if _args.has("target"):
		_target = float(_args["target"])
	if _args.has("pose"):
		_apply_pose(String(_args["pose"]))
	if _args.has("silhouette"):
		_toggle_silhouette()
	_update_camera()
	if _args.has("shot"):
		_capture.call_deferred()
	if _args.has("dump"):
		_dump_meshes.call_deferred()
	if _args.has("cape-test"):
		_cape_test.call_deferred()
	if _args.has("ui-shot"):
		_capture_ui.call_deferred()
	if _args.has("zoom-test"):
		_zoom_test.call_deferred()

## Проверка жестов тачпада без железа: щипок и прокрутка.
func _zoom_test() -> void:
	await get_tree().process_frame
	var mg: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	mg.factor = 1.25
	_unhandled_input(mg)
	print("[zoom] pinch target=", _dist_target)
	await get_tree().create_timer(0.4).timeout
	print("[zoom] pinch dist=", _dist)
	var pg: InputEventPanGesture = InputEventPanGesture.new()
	pg.delta = Vector2(0.0, -2.0)
	_unhandled_input(pg)
	print("[zoom] pan target=", _dist_target)
	await get_tree().create_timer(0.4).timeout
	print("[zoom] pan dist=", _dist)
	get_tree().quit()

func _capture_ui() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_save_image(img, String(_args["ui-shot"]))
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

## Проверка S0-02: углы плаща на трёх скоростях.
func _cape_test() -> void:
	if _animator == null:
		get_tree().quit(1)
		return
	for speed in [0.0, 2.6, 6.2]:
		_set_locomotion(speed)
		await get_tree().create_timer(1.8).timeout
		print("[cape] ", _animator.call("cape_report"))
	get_tree().quit(0)

func _dump_meshes() -> void:
	await get_tree().process_frame
	var sword: Node3D = _parts.get("sword_pivot") as Node3D
	print("[dump] sword visible=", sword.visible, " xf=", sword.global_transform)
	_dump_node(_model, 0)

func _dump_node(node: Node, depth: int) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		if aabb.end.y > 1.55 or aabb.size.x > 0.42:
			print("[dump] %s%s  y[%.2f..%.2f] x[%.2f..%.2f] z[%.2f..%.2f] vis=%s" % [
				"  ".repeat(depth), mi.name, aabb.position.y, aabb.end.y,
				aabb.position.x, aabb.end.x, aabb.position.z, aabb.end.z, mi.visible])
	for child in node.get_children():
		_dump_node(child, depth + 1)

func _parse_args() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < argv.size():
		var a: String = argv[i]
		if a.begins_with("--"):
			var key: String = a.substr(2)
			if key == "clean" or key == "turntable" or key == "dump" or key == "cape-test" or key == "silhouette" or key == "zoom-test":
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
	_env.ambient_light_color = Color(0.16, 0.19, 0.27)
	_env.ambient_light_energy = 0.25
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
	_key.light_color = Color(0.88, 0.92, 1.0)
	_key.light_energy = 3.6
	_key.shadow_enabled = true
	_key.directional_shadow_max_distance = 18.0
	_key.shadow_blur = 1.2
	add_child(_key)

	_fill = OmniLight3D.new()
	_fill.position = Vector3(1.5, 1.55, -2.0)
	_fill.light_color = Color(0.30, 0.42, 0.85)
	_fill.light_energy = 0.55
	_fill.omni_range = 7.0
	_fill.omni_attenuation = 1.2
	add_child(_fill)

	_rim = OmniLight3D.new()
	_rim.position = Vector3(-1.2, 2.1, 2.3)
	_rim.light_color = Color(1.0, 0.60, 0.28)
	_rim.light_energy = 3.0
	_rim.omni_range = 6.0
	_rim.omni_attenuation = 1.4
	add_child(_rim)

	_face = OmniLight3D.new()
	_face.position = Vector3(0.0, 1.66, -1.15)
	_face.light_color = Color(0.86, 0.89, 1.0)
	_face.light_energy = 0.50
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
	_ground = ground
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
	_ring = ring
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
	_hint.text = ("ЛКМ — вращать · колесо/щипок — зум · ПКМ — сдвинуть\n"
			+ "1 стойка · 2 шаг · 3 бег · 4-6 удары · 7 блок · 8 меч · 0 сброс\n"
			+ "C ракурс · L свет · T автоповорот · W сетка · B силуэт · H шляпа · F12 скрин · E .glb")
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

	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	col.offset_left = -176.0
	col.offset_right = -20.0
	col.offset_top = 18.0
	col.add_theme_constant_override("separation", 4)
	_ui.add_child(col)
	for i in range(SHOTS.size()):
		var idx: int = i
		var b: Button = Button.new()
		b.text = String(SHOTS[i]["name"])
		b.custom_minimum_size = Vector2(156, 26)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Color(0.82, 0.80, 0.74))
		b.pressed.connect(func() -> void: _goto_shot(idx))
		col.add_child(b)
	var reset_btn: Button = Button.new()
	reset_btn.text = "сброс позы"
	reset_btn.custom_minimum_size = Vector2(156, 26)
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.add_theme_color_override("font_color", Color(0.90, 0.78, 0.55))
	reset_btn.pressed.connect(_reset_pose)
	col.add_child(reset_btn)

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
	if _args.has("dump"):
		print("[stats] ", _stats.text.replace("\n", " | "))

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
			_env.ambient_light_color = Color(0.16, 0.19, 0.27)
			_env.ambient_light_energy = 0.25
			_key.light_color = Color(0.88, 0.92, 1.0)
			_key.light_energy = 3.6
			_fill.light_color = Color(0.30, 0.42, 0.85)
			_fill.light_energy = 0.55
			_rim.light_color = Color(1.0, 0.60, 0.28)
			_rim.light_energy = 3.0
		1:
			_env.background_color = Color(0.012, 0.020, 0.038)
			_env.ambient_light_color = Color(0.16, 0.24, 0.42)
			_env.ambient_light_energy = 0.35
			_key.light_color = Color(0.52, 0.66, 1.0)
			_key.light_energy = 1.5
			_fill.light_color = Color(0.30, 0.44, 0.85)
			_fill.light_energy = 1.0
			_rim.light_color = Color(0.55, 0.72, 1.0)
			_rim.light_energy = 2.0
		_:
			_env.background_color = Color(0.035, 0.020, 0.014)
			_env.ambient_light_color = Color(0.30, 0.16, 0.08)
			_env.ambient_light_energy = 0.40
			_key.light_color = Color(1.0, 0.62, 0.30)
			_key.light_energy = 1.9
			_fill.light_color = Color(0.90, 0.36, 0.12)
			_fill.light_energy = 2.4
			_rim.light_color = Color(1.0, 0.78, 0.45)
			_rim.light_energy = 3.0

func _apply_shot() -> void:
	_shot_index = _shot_index % SHOTS.size()
	var s: Dictionary = SHOTS[_shot_index]
	_dist = float(s["dist"])
	_dist_target = _dist
	_pitch = float(s["pitch"])
	_target = float(s["target"])
	_orbit = float(s.get("angle", _orbit))
	_pan = Vector3.ZERO

func _goto_shot(index: int) -> void:
	_shot_index = clampi(index, 0, SHOTS.size() - 1)
	_apply_shot()
	_update_stats()

## Силуэт-тест S1-06: всё чёрным, фон светлый, земля скрыта.
func _toggle_silhouette() -> void:
	_silhouette = not _silhouette
	if _silhouette:
		_sil_mat = StandardMaterial3D.new()
		_sil_mat.albedo_color = Color(0.015, 0.015, 0.018)
		_sil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sil_mat.cull_mode = BaseMaterial3D.CULL_BACK
		_saved_mats.clear()
		_paint_black(_model)
		_ground.visible = false
		_ring.visible = false
		_env.background_color = Color(0.84, 0.84, 0.84)
		_env.ambient_light_energy = 0.0
	else:
		for node in _saved_mats.keys():
			if is_instance_valid(node):
				(node as MeshInstance3D).material_override = _saved_mats[node]
		_saved_mats.clear()
		_ground.visible = true
		_ring.visible = true
		_apply_light()

func _paint_black(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		_saved_mats[mi] = mi.material_override
		mi.material_override = _sil_mat
	for child in node.get_children():
		_paint_black(child)

func _reset_pose() -> void:
	_walk = 0.0
	_drawn = false
	_block = false
	if _animator != null:
		_animator.call("set_locomotion", 0.0)
		_animator.call("set_block", false)
		_animator.call("set_drawn", false)
	_apply_pose("idle")
	_hint.text = "Поза сброшена · 1 стойка · 2 шаг · 3 бег · 4-6 удары"

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
		"reset":
			_reset_pose()

## Зум колесом/тачпадом: цель сглаживается в _process.
func _zoom_add(amount: float) -> void:
	_dist_target = clampf(_dist_target + amount, 0.55, 9.0)

func _set_locomotion(speed: float) -> void:
	if _animator != null and _animator.has_method("set_locomotion"):
		_animator.call("set_locomotion", speed)

# =========================================================================

func _process(delta: float) -> void:
	if _auto:
		_orbit += delta * 0.45
	# плавный зум: колесо/щипок задают цель, камера догоняет
	_dist = lerpf(_dist, _dist_target, 1.0 - exp(-delta * 16.0))
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
			_zoom_add(-0.22)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_add(0.22)
	elif event is InputEventMagnifyGesture:
		# щипок двумя пальцами на тачпаде
		var mg: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		_dist_target = clampf(_dist_target / maxf(0.02, mg.factor), 0.55, 9.0)
	elif event is InputEventPanGesture:
		# жест прокрутки тачпада (если драйвер отдаёт его вместо колеса)
		var pg: InputEventPanGesture = event as InputEventPanGesture
		_dist_target = clampf(_dist_target * (1.0 + pg.delta.y * 0.06), 0.55, 9.0)
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
			KEY_0:
				_reset_pose()
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
			KEY_B:
				_toggle_silhouette()
			KEY_H:
				_hat_off = not _hat_off
				var hat: Node3D = _find_hat()
				if hat != null:
					hat.visible = not _hat_off
			KEY_R:
				_orbit = 0.42
				_pitch = 0.14
				_dist = 3.40
				_dist_target = 3.40
				_target = 1.02
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
	if _args.has("wait"):
		await get_tree().create_timer(float(_args["wait"])).timeout
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
	var root: Node3D = _model.duplicate() as Node3D
	_strip_for_export(root)
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: Error = doc.append_from_scene(root, state)
	if err != OK:
		_hint.text = "Экспорт не удался: %s" % error_string(err)
		root.free()
		return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://models")):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://models"))
	var path: String = ProjectSettings.globalize_path("res://models/dhampir.glb")
	var werr: Error = doc.write_to_filesystem(state, path)
	_hint.text = "Экспорт: %s (%s)" % [path, error_string(werr)]
	print("[viewer] glb %s -> %s" % [path, error_string(werr)])
	root.free()

func _strip_for_export(node: Node) -> void:
	for child in node.get_children():
		if child.name == "Sword" or child.name == "Animator" or child.name == "Ember":
			node.remove_child(child)
			child.free()
		else:
			_strip_for_export(child)
