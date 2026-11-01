extends Node3D

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const HudScript := preload("res://scripts/hud.gd")
const TerrainScript := preload("res://scripts/terrain.gd")
const GrassScript := preload("res://scripts/grass.gd")
const WindScript := preload("res://scripts/wind.gd")
const HutScript := preload("res://scripts/hut.gd")
const LabStateScript := preload("res://scripts/lab_state.gd")
const PauseScript := preload("res://scripts/pause_menu.gd")
const BonfireScript := preload("res://libraries/bonfire.gd")
const TimeOfDayScript := preload("res://libraries/time_of_day.gd")
const QualityScript := preload("res://libraries/quality.gd")
const PerfOverlay := preload("res://scripts/perf_overlay.gd")
const PostFXScript := preload("res://scripts/post_fx.gd")

const TREE_COUNT := 2600
const WORLD_LIMIT := 152.0
const WORLD_EDGE := 140.0
const HUT_POS := Vector3(-58.0, 0.0, -88.0)
const HUTS := [
	{"pos": Vector3(-58.0, 0.0, -88.0), "main": true},
	{"pos": Vector3(56.0, 0.0, -34.0), "main": false},
	{"pos": Vector3(-22.0, 0.0, 92.0), "main": false},
]

const TREE_SHADER := preload("res://shaders/tree.gdshader")

var player
var hud
var terrain
var bonfire_pos := Vector3.ZERO

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _fire_light: OmniLight3D
var _enemies: Array = []
var _encounters := [
	{"at": 14.0, "kind": "wolf"},
	{"at": 27.0, "kind": "cultist"},
	{"at": 39.0, "kind": "wolf"},
	{"at": 51.0, "kind": "leshy"},
	{"at": 63.0, "kind": "wailer"},
]
var _encounter_index := 0
var _encounter_enemy = null
var _path_points: Array[Vector3] = []
var _paths: Array = []
var _edge_cooldown := 0.0
var _hut_parts: Dictionary = {}
var _hut_door: Node3D
var _hut_hearth_pos := Vector3.ZERO
var _amulet: Node3D
var _amulet_taken := false
var _door_open := false
var _checkpoint := Vector3(2.8, 0.0, 5.4)
const TreeLibScript := preload("res://scripts/tree_lib.gd")
const SPECIES := ["birch", "birch_multi", "oak", "ash", "cedar", "spruce", "willow", "pine"]

var _tree_shader: Shader
var _mat_light: ShaderMaterial
var _mat_dark: ShaderMaterial
var _mat_fern: ShaderMaterial
var _tree_variants: Array = []
var _tree_chunks: Dictionary = {}
var _rock_wet: Array = []
var _rock_dry: Array = []
var _wreaths: Array = []
var _time_wreath := 0.0
var _env: Environment
var _underwater := false
var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _tod := "night"
var _rain: CPUParticles3D
var _rain_on := false
var _wet := 0.0
var _terrain_mat: Material
var _tod_fog := 0.035
const TREE_CHUNK := 80.0
var _soul_orb: Node3D
var _orb_base_y := 0.0
var _dropped_souls := 0

func _enter_tree() -> void:
	_register_input()

func _ready() -> void:
	_rng.seed = 20261101
	RenderingServer.global_shader_parameter_add("player_pos", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
	_build_environment()
	_build_terrain()
	_create_tree_materials()
	_build_path()
	_build_hut()
	_build_forest()
	_build_camp_trees()
	_build_bonfire()
	_build_undergrowth()
	_build_ferns()
	_build_bog()
	_build_path_strips()
	_build_bridges()
	_build_stream_fog()
	_build_puddles()
	_build_rocks()
	_spawn_player()
	_build_hud()
	_tod = LabStateScript.time_of_day
	_terrain_mat = terrain.ground_material
	if OS.get_environment("TROPA_TOD") != "":
		_tod = OS.get_environment("TROPA_TOD")
	TimeOfDayScript.apply(_tod, _env, _sun, _sky_mat)
	_tod_fog = _env.fog_density
	if OS.get_environment("TROPA_NO_POST") != "1":
		var post := PostFXScript.new()
		add_child(post)
	_build_rain()
	var perf := PerfOverlay.new()
	add_child(perf)
	var pause = PauseScript.new()
	add_child(pause)
	pause.game = self
	hud.show_notice("Костёр гаснет. Лес ждёт.", 4.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_T:
		_tod = TimeOfDayScript.next_key(_tod)
		TimeOfDayScript.apply(_tod, _env, _sun, _sky_mat)
		_tod_fog = _env.fog_density
		hud.show_notice("Время суток: " + TimeOfDayScript.label(_tod), 2.5)
	elif key.keycode == KEY_R:
		_toggle_rain()

func _build_rain() -> void:
	_rain = CPUParticles3D.new()
	_rain.amount = 900
	_rain.lifetime = 1.1
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(26.0, 1.0, 26.0)
	_rain.direction = Vector3(0.08, -1.0, 0.04)
	_rain.spread = 4.0
	_rain.gravity = Vector3(0.0, -18.0, 0.0)
	_rain.initial_velocity_min = 9.0
	_rain.initial_velocity_max = 14.0
	_rain.scale_amount_min = 0.6
	_rain.scale_amount_max = 1.2
	_rain.color = Color(0.55, 0.62, 0.75, 0.45)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.45)
	_rain.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	_rain.material_override = mat
	_rain.emitting = false
	add_child(_rain)
	if OS.get_environment("TROPA_RAIN") == "1":
		_rain_on = true
		_rain.emitting = true
		_wet = 1.0

func _toggle_rain() -> void:
	_rain_on = not _rain_on
	if _rain != null:
		_rain.emitting = _rain_on
	hud.show_notice("Дождь" if _rain_on else "Дождь стих", 2.0)

func _update_rain(delta: float) -> void:
	var target := 1.0 if _rain_on else 0.0
	_wet = move_toward(_wet, target, delta * 0.25)
	if _rain != null and player != null:
		_rain.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
	if _terrain_mat is ShaderMaterial:
		(_terrain_mat as ShaderMaterial).set_shader_parameter("wet", _wet)
	if _env != null:
		_env.fog_density = _tod_fog + _wet * 0.012

func _process(delta: float) -> void:
	_time += delta
	if _fire_light:
		_fire_light.light_energy = 2.3 + sin(_time * 9.0) * 0.35 + sin(_time * 23.0) * 0.12

	if player:
		RenderingServer.global_shader_parameter_set("player_pos", player.global_position)

	WindScript.strength = 0.75 + sin(_time * 0.4) * 0.25 + sin(_time * 1.9) * 0.1
	WindScript.direction = Vector3(0.8, 0.0, 0.6).normalized().rotated(Vector3.UP, sin(_time * 0.11) * 0.5)

	if _soul_orb and is_instance_valid(_soul_orb):
		_soul_orb.rotate_y(delta * 1.6)
		_soul_orb.position.y = _orb_base_y + sin(_time * 2.0) * 0.15

	if player == null or player.is_dead():
		return

	_clamp_to_world(delta)
	_update_encounters(delta)
	_update_underwater()
	_update_rain(delta)
	_time_wreath += delta
	for w in _wreaths:
		var node: Node3D = w["node"]
		var ph: float = w["phase"]
		node.rotation.z = sin(_time_wreath * 1.1 + ph) * 0.06
		node.rotation.x = sin(_time_wreath * 0.8 + ph * 1.7) * 0.04

	var inside_hut := false
	if not _hut_parts.is_empty():
		inside_hut = player.global_position.distance_to(_hut_parts["root"].global_position) < 3.3
	var target_arm := 2.0 if inside_hut else 4.3
	player.arm.spring_length = lerpf(player.arm.spring_length, target_arm, 4.0 * delta)

	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.set_torch_bonus(1.4 if player.torch_lit else 1.0)

	if hud.levels_visible:
		if Input.is_action_just_pressed("upgrade_1"):
			player.spend_souls("strength")
		elif Input.is_action_just_pressed("upgrade_2"):
			player.spend_souls("endurance")
		elif Input.is_action_just_pressed("upgrade_3"):
			player.spend_souls("perception")
		elif Input.is_action_just_pressed("upgrade_4"):
			player.spend_souls("craft")
		elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
			hud.hide_levels()
		return

	if Input.is_action_just_pressed("interact"):
		if not _try_hut_interaction() and player.global_position.distance_to(bonfire_pos) < 3.6:
			_rest()

	if _soul_orb and is_instance_valid(_soul_orb):
		if player.global_position.distance_to(_soul_orb.global_position) < 2.0:
			_collect_souls()

# --- ввод ---

func _register_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("dodge", KEY_SPACE)
	_add_key("jump", KEY_SPACE)
	_add_key("interact", KEY_E)
	_add_key("heal", KEY_Q)
	_add_key("torch", KEY_F)
	_add_key("lock", KEY_TAB)
	_add_key("upgrade_1", KEY_1)
	_add_key("upgrade_2", KEY_2)
	_add_key("upgrade_3", KEY_3)
	_add_key("upgrade_4", KEY_4)
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_mouse("block", MOUSE_BUTTON_RIGHT)

func _add_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _add_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

# --- атмосфера ---

func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")

	var sky := Sky.new()
	sky.sky_material = sky_mat
	_sky_mat = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.31, 0.44)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.11)
	env.fog_density = 0.032
	env.fog_height = 1.6
	env.fog_height_density = 0.38
	env.fog_sky_affect = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.98
	env.ssao_enabled = true
	env.ssao_intensity = 1.1
	env.ssao_radius = 1.4
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.60
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.15
	env.glow_hdr_scale = 2.0
	env.glow_strength = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set("glow_levels/3", 0.4)
	env.set("glow_levels/4", 0.7)
	env.set("glow_levels/5", 0.5)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.014
	env.volumetric_fog_albedo = Color(0.52, 0.60, 0.74)
	env.volumetric_fog_emission = Color(0.012, 0.018, 0.030)
	env.volumetric_fog_length = 72.0
	env.volumetric_fog_ambient_inject = 0.38
	env.volumetric_fog_gi_inject = 0.25
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_detail_spread = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.88
	env.adjustment_contrast = 1.18
	env.adjustment_brightness = 0.96

	# SDFGI: мягкий отражённый свет. Энергию держим низкой, иначе ночь пересвечивает.
	var sdfgi_mode := OS.get_environment("TROPA_SDFGI")
	env.sdfgi_enabled = sdfgi_mode != "off"
	env.sdfgi_cascades = 1
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = 0.22
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = false
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_50_PERCENT

	_env = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-46, 28, 0)
	moon.light_color = Color(0.50, 0.64, 0.92)
	moon.light_energy = 1.3
	_sun = moon
	QualityScript.apply(env, moon)
	moon.shadow_enabled = OS.get_environment("TROPA_NO_SHADOWS") != "1"
	moon.directional_shadow_max_distance = 55.0
	moon.shadow_blur = 1.4
	moon.directional_shadow_max_distance = 80.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(moon)

# --- земля ---

func _build_terrain() -> void:
	terrain = TerrainScript.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var grass = GrassScript.new()
	grass.name = "Grass"
	add_child(grass)
	if OS.get_environment("TROPA_NO_GRASS") != "1":
		grass.populate(terrain, QualityScript.grass_amount(), QualityScript.grass_radius(), _paths)

# --- лес ---

func _create_tree_materials() -> void:
	_tree_shader = TREE_SHADER

	var bark_light: Texture2D = null
	var bark_dark: Texture2D = null
	var leaf: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/birch_bark.png"):
		bark_light = load("res://assets/textures/birch_bark.png")
	if ResourceLoader.exists("res://assets/textures/photo/bark_color.jpg"):
		bark_dark = load("res://assets/textures/photo/bark_color.jpg")
	elif ResourceLoader.exists("res://assets/textures/spruce_bark.png"):
		bark_dark = load("res://assets/textures/spruce_bark.png")
	if ResourceLoader.exists("res://assets/textures/leaf_atlas.png"):
		leaf = load("res://assets/textures/leaf_atlas.png")

	_mat_light = _make_tree_material(bark_light, leaf)
	if ResourceLoader.exists("res://assets/textures/photo/moss_color.jpg"):
		var moss_tex2 = load("res://assets/textures/photo/moss_color.jpg")
		_mat_light.set_shader_parameter("moss_tex", moss_tex2)
		_mat_light.set_shader_parameter("trunk_moss", 0.55)
	_mat_dark = _make_tree_material(bark_dark, leaf)
	if ResourceLoader.exists("res://assets/textures/photo/moss_color.jpg"):
		var moss_tex = load("res://assets/textures/photo/moss_color.jpg")
		_mat_dark.set_shader_parameter("moss_tex", moss_tex)
		_mat_dark.set_shader_parameter("trunk_moss", 0.8)
	if ResourceLoader.exists("res://assets/textures/photo/bark_normal.jpg"):
		_mat_dark.set_shader_parameter("bark_normal", load("res://assets/textures/photo/bark_normal.jpg"))
		_mat_dark.set_shader_parameter("use_normal", 1.0)
	_mat_fern = _make_tree_material(bark_dark, leaf)
	_mat_fern.set_shader_parameter("wind", 0.42)

	for i in SPECIES.size():
		for v in 2:
			var mesh := TreeLibScript.build(SPECIES[i], 1000 + i * 17 + v * 5, false)
			var simple_mesh := mesh
			var material := _mat_dark if SPECIES[i] in ["cedar", "spruce", "willow"] else _mat_light
			_tree_variants.append({
				"mesh": mesh,
				"simple_mesh": simple_mesh,
				"species": SPECIES[i],
				"material": material,
			})

func _make_tree_material(bark: Texture2D, leaf: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _tree_shader
	if bark:
		mat.set_shader_parameter("bark_tex", bark)
	if leaf:
		mat.set_shader_parameter("leaf_tex", leaf)
	return mat

func _pick_species(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := _rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return "birch"

func _species_index(species: String) -> int:
	return SPECIES.find(species) if SPECIES.has(species) else 0

func _habitat_weights(h: float, stream_d: float) -> Dictionary:
	if stream_d < 8.0:
		return {"birch": 0.28, "birch_multi": 0.15, "willow": 0.26, "ash": 0.13, "oak": 0.08, "cedar": 0.02, "spruce": 0.02, "pine": 0.06}
	if h < 2.6:
		return {"birch": 0.34, "birch_multi": 0.15, "ash": 0.19, "oak": 0.13, "cedar": 0.06, "spruce": 0.06, "willow": 0.0, "pine": 0.07}
	if h > 6.0:
		return {"birch": 0.14, "birch_multi": 0.06, "ash": 0.08, "oak": 0.10, "cedar": 0.22, "spruce": 0.18, "willow": 0.0, "pine": 0.22}
	return {"birch": 0.26, "birch_multi": 0.12, "ash": 0.15, "oak": 0.14, "cedar": 0.11, "spruce": 0.10, "willow": 0.0, "pine": 0.12}

func _build_forest() -> void:
	var density := FastNoiseLite.new()
	density.seed = 77
	density.frequency = 0.02
	density.fractal_octaves = 3

	var placed := 0
	var attempts := 0
	while placed < TREE_COUNT and attempts < TREE_COUNT * 14:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var dist := sqrt(_rng.randf()) * WORLD_LIMIT
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		if Vector2(x, z).length() < 13.0:
			continue
		if Vector2(x - HUT_POS.x, z - HUT_POS.z).length() < 16.0:
			continue
		if _near_path(x, z, 4.5):
			continue
		if terrain.is_water(x, z):
			continue
		var stream_d: float = terrain.stream_distance(x, z)
		if stream_d < 3.0:
			continue
		if density.get_noise_2d(x, z) * 0.5 + 0.5 < 0.38:
			continue
		var h: float = terrain.height_at(x, z)
		if h < TerrainScript.WATER_LEVEL + 1.2:
			continue
		if terrain.slope_at(x, z) > 0.55:
			continue

		var species := _pick_species(_habitat_weights(h, stream_d))
		var variant := _species_index(species) * 2 + (0 if _rng.randf() < 0.5 else 1)
		var scale := _rng.randf_range(0.85, 1.2)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale, scale))
		var key := Vector2i(int(floor(x / TREE_CHUNK)), int(floor(z / TREE_CHUNK)))
		if not _tree_chunks.has(key):
			var lists: Array = []
			lists.resize(_tree_variants.size())
			for q in lists.size():
				lists[q] = []
			_tree_chunks[key] = lists
		var lists = _tree_chunks[key]
		(lists[variant] as Array).append(Transform3D(basis, Vector3(x, h - 0.1, z)))

		_add_tree_collision_at(Vector3(x, h, z), TreeLibScript.trunk_radius(species), TreeLibScript.height_of(species) * scale)
		placed += 1

	_finish_trees()
	print("[trees] ", placed, " шт, пород: ", SPECIES.size())

func _spawn_multimesh(mesh: Mesh, material: Material, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = material
	add_child(node)

func _build_undergrowth() -> void:
	var bush_meshes: Array = [TreeLibScript.build("bush", 501), TreeLibScript.build("bush", 733)]
	var bush_lists: Array = [[], []]
	var attempts := 0
	while bush_lists[0].size() + bush_lists[1].size() < 420 and attempts < 9000:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var dist := sqrt(_rng.randf()) * WORLD_LIMIT
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		if Vector2(x, z).length() < 8.0:
			continue
		if terrain.is_water(x, z):
			continue
		if _near_path(x, z, 1.6):
			continue
		var h: float = terrain.height_at(x, z)
		if h < TerrainScript.WATER_LEVEL + 0.5:
			continue
		if terrain.slope_at(x, z) > 0.8:
			continue
		var idx := _rng.randi_range(0, 1)
		var s := _rng.randf_range(0.8, 1.5)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
		(bush_lists[idx] as Array).append(Transform3D(basis, Vector3(x, h, z)))

	for i in 2:
		_spawn_multimesh(bush_meshes[i], _mat_dark, bush_lists[i])
	print("[bushes] ", bush_lists[0].size() + bush_lists[1].size())

func _build_ferns() -> void:
	var meshes: Array = [TreeLibScript.build("fern", 301), TreeLibScript.build("fern", 907)]
	var lists: Array = [[], []]
	var attempts := 0
	while lists[0].size() + lists[1].size() < 1200 and attempts < 16000:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var dist := sqrt(_rng.randf()) * WORLD_LIMIT
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		if terrain.is_water(x, z) or _near_path(x, z, 1.2):
			continue
		var h: float = terrain.height_at(x, z)
		if h < TerrainScript.WATER_LEVEL + 0.5:
			continue
		if terrain.slope_at(x, z) > 0.9:
			continue
		var idx := _rng.randi_range(0, 1)
		var sc := _rng.randf_range(0.8, 1.5)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc, sc))
		(lists[idx] as Array).append(Transform3D(basis, Vector3(x, h, z)))

	for i in 2:
		_spawn_multimesh(meshes[i], _mat_fern, lists[i])
	print("[ferns] ", lists[0].size() + lists[1].size())

func _build_bog() -> void:
	var center := Vector2(-42.0, 30.0)
	var base: float = terrain.height_at(center.x, center.y)

	var water_mat := _make_puddle_material(3.0, 0.35)
	water_mat.set_shader_parameter("water_color", Color(0.025, 0.05, 0.045, 1.0))
	water_mat.set_shader_parameter("sky_color", Color(0.09, 0.12, 0.14, 1.0))

	for i in 7:
		var angle := TAU * float(i) / 7.0 + _rng.randf_range(-0.2, 0.2)
		var r := _rng.randf_range(1.0, 7.5)
		var px := center.x + cos(angle) * r
		var pz := center.y + sin(angle) * r
		var water := MeshInstance3D.new()
		water.mesh = _puddle_patch(px, pz, _rng.randf_range(1.6, 3.4), 28)
		water.material_override = water_mat
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)

	# камыш по краям
	var reeds: Array = [TreeLibScript.build("reed", 401), TreeLibScript.build("reed", 555)]
	var reed_lists: Array = [[], []]
	for i in 260:
		var angle := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(2.0, 13.0)
		var px := center.x + cos(angle) * r
		var pz := center.y + sin(angle) * r
		var h: float = terrain.height_at(px, pz)
		if h < TerrainScript.WATER_LEVEL + 0.3:
			continue
		var sc := _rng.randf_range(0.8, 1.3)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc, sc))
		(reed_lists[i % 2] as Array).append(Transform3D(basis, Vector3(px, h, pz)))

	for i in 2:
		_spawn_multimesh(reeds[i], _mat_dark, reed_lists[i])

	# сухостой
	for i in 9:
		var angle := TAU * float(i) / 9.0
		var r := _rng.randf_range(3.0, 11.0)
		var px := center.x + cos(angle) * r
		var pz := center.y + sin(angle) * r
		_dead_tree(Vector3(px, terrain.height_at(px, pz), pz))
	print("[bog] вода и камыш")

func _dead_tree(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(root)

	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.16, 0.15, 0.14)
	bark.roughness = 1.0

	var h := _rng.randf_range(4.0, 7.0)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.16
	cyl.height = h
	trunk.mesh = cyl
	trunk.material_override = bark
	trunk.position.y = h * 0.5
	trunk.rotation.z = _rng.randf_range(-0.12, 0.12)
	root.add_child(trunk)

	for i in 4:
		var branch := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.01
		bm.bottom_radius = 0.045
		bm.height = _rng.randf_range(1.0, 1.8)
		branch.mesh = bm
		branch.material_override = bark
		var a := _rng.randf_range(0.0, TAU)
		var y := h * _rng.randf_range(0.45, 0.85)
		branch.position = Vector3(0.0, y, 0.0)
		branch.rotation = Vector3(_rng.randf_range(0.7, 1.2), a, 0.0)
		root.add_child(branch)

	_add_tree_collision(root, 0.2, h)

func _build_path_strips() -> void:
	for path in _paths:
		_build_single_strip(path["points"])

func _build_single_strip(_path_points: Array) -> void:
	if _path_points.size() < 3:
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in _path_points.size():
		var p: Vector3 = _path_points[i]
		var prev: Vector3 = _path_points[maxi(i - 1, 0)]
		var next: Vector3 = _path_points[mini(i + 1, _path_points.size() - 1)]
		var dir := next - prev
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		for s in [-1.0, 1.0]:
			var q: Vector3 = p + side * 2.9 * s
			q.y = terrain.height_at(q.x, q.z) + 0.04
			verts.append(q)
			uvs.append(Vector2(0.0 if s < 0.0 else 1.0, float(i) * 0.22))

		if i > 0:
			var a := (i - 1) * 2
			var b := a + 1
			var c := i * 2
			var d := c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var noise := FastNoiseLite.new()
	noise.seed = 12
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	noise_tex.width = 256
	noise_tex.height = 256

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/trail.gdshader")
	if ResourceLoader.exists("res://assets/textures/photo/ground_color.jpg"):
		mat.set_shader_parameter("ground_tex", load("res://assets/textures/photo/ground_color.jpg"))
	mat.set_shader_parameter("noise_tex", noise_tex)

	var strip := MeshInstance3D.new()
	strip.mesh = mesh
	strip.material_override = mat
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)

func _add_rock(list: Array, x: float, z: float) -> void:
	var h: float = terrain.height_at(x, z)
	if h < TerrainScript.WATER_LEVEL - 0.4:
		return
	var wet := h < TerrainScript.WATER_LEVEL + 1.4
	var s := _rng.randf_range(0.35, 0.95)
	var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(
		s * _rng.randf_range(0.9, 1.5),
		s * _rng.randf_range(0.5, 0.8),
		s * _rng.randf_range(0.9, 1.5)
	))
	if wet:
		_rock_wet.append(Transform3D(basis, Vector3(x, h + 0.02, z)))
	else:
		_rock_dry.append(Transform3D(basis, Vector3(x, h + 0.02, z)))

func _make_moss_material(amount: float) -> ShaderMaterial:
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

func _make_puddle_material(scale: float, soft: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/puddle.gdshader")
	mat.set_shader_parameter("ripple", terrain._make_ripple_texture())
	mat.set_shader_parameter("ripple_scale", scale)
	mat.set_shader_parameter("edge_softness", soft)
	return mat

func _puddle_patch(cx: float, cz: float, radius: float, segs: int = 20, elongation: float = 1.0, yaw: float = 0.0) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var cy: float = terrain.height_at(cx, cz) + 0.02
	verts.append(Vector3(cx, cy, cz))
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))

	for i in segs:
		var a := TAU * float(i) / float(segs)
		var wobble := 0.86 + 0.10 * sin(a * 3.1 + 1.7) + 0.07 * sin(a * 5.7 + 0.4) + 0.04 * sin(a * 8.3 + 2.9)
		var local := Vector2(cos(a) * radius * wobble * elongation, sin(a) * radius * wobble)
		local = local.rotated(yaw)
		var px := cx + local.x
		var pz := cz + local.y
		var py: float = terrain.height_at(px, pz) + 0.02
		verts.append(Vector3(px, py, pz))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.5 + local.x / maxf(radius * 2.0, 0.1), 0.5 + local.y / maxf(radius * 2.0, 0.1)))

	for i in segs:
		var a := 1 + i
		var b := 1 + (i + 1) % segs
		indices.append(0)
		indices.append(a)
		indices.append(b)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_bridges() -> void:
	var built: Array[Vector3] = []
	for path in _paths:
		var pts: Array = path["points"]
		var i := 2
		while i < pts.size() - 2:
			var p: Vector3 = pts[i]
			if terrain.stream_distance(p.x, p.z) < 3.0:
				var too_close := false
				for b in built:
					if Vector2(b.x - p.x, b.z - p.z).length() < 6.0:
						too_close = true
				if not too_close:
					var prev: Vector3 = pts[i - 1]
					var nxt: Vector3 = pts[i + 1]
					var dir: Vector3 = (nxt - prev)
					dir.y = 0.0
					dir = dir.normalized()
					_build_bridge(p, dir)
					built.append(p)
				i += 8
			else:
				i += 1
	print("[bridges] ", built.size())

func _build_bridge(center: Vector3, dir: Vector3) -> void:
	var root := Node3D.new()
	root.rotation.y = atan2(dir.x, dir.z)
	add_child(root)

	var half_len := 3.2
	var end_a := center - dir * half_len
	var end_b := center + dir * half_len
	var ha: float = terrain.height_at(end_a.x, end_a.z)
	var hb: float = terrain.height_at(end_b.x, end_b.z)
	var deck_y := maxf(ha, hb) + 0.22
	root.position = Vector3(center.x, deck_y, center.z)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.33, 0.23)
	wood_mat.roughness = 0.95
	if ResourceLoader.exists("res://assets/textures/photo/bark_color.jpg"):
		wood_mat.albedo_texture = load("res://assets/textures/photo/bark_color.jpg")
		wood_mat.uv1_scale = Vector3(2.0, 2.0, 1.0)

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.24, 0.19, 0.14)
	dark_mat.roughness = 1.0

	# настил: доски поперёк движения
	var plank_count := 15
	var step := (half_len * 2.0) / float(plank_count)
	for i in plank_count:
		var plank := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.1, 0.07, step * 0.82)
		plank.mesh = box
		plank.material_override = wood_mat
		var z := -half_len + step * (float(i) + 0.5)
		var arch := 0.10 * (1.0 - pow(z / half_len, 2.0))
		plank.position = Vector3(_rng.randf_range(-0.03, 0.03), arch, z)
		plank.rotation.z = _rng.randf_range(-0.012, 0.012)
		root.add_child(plank)

	# два продольных бревна под настилом
	for side in [-1.0, 1.0]:
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(0.16, 0.18, half_len * 2.0 + 0.2)
		beam.mesh = beam_mesh
		beam.material_override = dark_mat
		beam.position = Vector3(side * 0.92, -0.10, 0.0)
		root.add_child(beam)

	# столбы по углам
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.16, 1.4, 0.16)
			post.mesh = post_mesh
			post.material_override = dark_mat
			post.position = Vector3(sx * 0.92, -0.75, sz * (half_len - 0.35))
			root.add_child(post)

	# коллизия: плоская коробка по настилу
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.3, 0.3, half_len * 2.0)
	shape.shape = box_shape
	body.add_child(shape)
	body.position = Vector3(0.0, -0.05, 0.0)
	root.add_child(body)

func _build_stream_fog() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/stream_fog.gdshader")

	var made := 0
	for stream in terrain.stream_points():
		var pts: PackedVector2Array = stream
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var steps := maxi(1, int(a.distance_to(b) / 12.0))
			for k in steps:
				var t := (float(k) + 0.5) / float(steps)
				var p := a.lerp(b, t)
				var ground: float = terrain.height_at(p.x, p.y)
				var volume := FogVolume.new()
				volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
				volume.extents = Vector3(11.0, 4.5, 11.0)
				var vm := mat.duplicate() as ShaderMaterial
				vm.set_shader_parameter("base_height", ground)
				vm.set_shader_parameter("density", 0.22)
				volume.material = vm
				volume.position = Vector3(p.x, ground + 3.6, p.y)
				add_child(volume)
				made += 1
	print("[stream fog] ", made)

func _build_puddles() -> void:
	var water_mat := _make_puddle_material(7.0, 0.34)

	var mud_mat := StandardMaterial3D.new()
	mud_mat.albedo_color = Color(0.09, 0.068, 0.045, 0.85)
	mud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mud_mat.roughness = 0.45
	mud_mat.metallic_specular = 0.6

	var made := 0
	var attempts := 0
	while made < 14 and attempts < 900:
		attempts += 1
		var use_path := _rng.randf() < 0.75 and _path_points.size() > 4
		var x := 0.0
		var z := 0.0
		if use_path and not _paths.is_empty():
			var path: Dictionary = _paths[_rng.randi_range(0, _paths.size() - 1)]
			var pts: Array = path["points"]
			var p: Vector3 = pts[_rng.randi_range(0, pts.size() - 1)]
			x = p.x + _rng.randf_range(-2.2, 2.2)
			z = p.z + _rng.randf_range(-1.4, 1.4)
		else:
			var angle := _rng.randf_range(0.0, TAU)
			var dist := sqrt(_rng.randf()) * 55.0
			x = cos(angle) * dist
			z = sin(angle) * dist
		if Vector2(x, z).length() < 4.0:
			continue
		var h: float = terrain.height_at(x, z)
		if h < TerrainScript.WATER_LEVEL + 0.3:
			continue
		if terrain.slope_at(x, z) > 0.30:
			continue

		var is_water := _rng.randf() < 0.72
		var radius := _rng.randf_range(0.8, 2.1)
		var elongation := _rng.randf_range(1.25, 2.0)
		var yaw := _rng.randf_range(0.0, TAU)
		var node := MeshInstance3D.new()
		if is_water:
			node.mesh = _puddle_patch(x, z, radius, 24, elongation, yaw)
			node.material_override = water_mat
		else:
			var disc := CylinderMesh.new()
			disc.top_radius = radius * 1.25
			disc.bottom_radius = disc.top_radius
			disc.height = 0.04
			node.mesh = disc
			node.material_override = mud_mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.global_position = Vector3(x, h + 0.015, z) if not is_water else Vector3.ZERO
		if is_water:
			node.position = Vector3.ZERO
		made += 1
		if made <= 3:
			print("[puddle] ", made, " at ", x, ", ", z)

	print("[puddles] ", made)

func _build_rocks() -> void:
	var transforms: Array = []

	# берега ручьёв
	for stream in terrain.stream_points():
		for i in stream.size() - 1:
			var a: Vector2 = stream[i]
			var b: Vector2 = stream[i + 1]
			var steps := maxi(1, int(a.distance_to(b) / 5.0))
			for s in steps:
				var t := float(s) / float(steps)
				var p := a.lerp(b, t)
				var dir := (b - a).normalized()
				var side := Vector2(-dir.y, dir.x)
				for k in [-1.0, 1.0]:
					if _rng.randf() < 0.5:
						continue
					var q: Vector2 = p + side * k * _rng.randf_range(1.7, 2.9)
					_add_rock(transforms, q.x, q.y)

	# тропа к избе
	for path in _paths:
		var pts: Array = path["points"]
		for i in range(0, pts.size(), 4):
			var p: Vector3 = pts[i]
			for k in [-1.0, 1.0]:
				if _rng.randf() < 0.5:
					continue
				_add_rock(transforms, p.x + k * _rng.randf_range(2.0, 3.6), p.z)

	# просто по лесу
	for i in 150:
		var angle := _rng.randf_range(0.0, TAU)
		var dist := sqrt(_rng.randf()) * WORLD_LIMIT
		_add_rock(transforms, cos(angle) * dist, sin(angle) * dist)

	var rock := SphereMesh.new()
	rock.radius = 0.55
	rock.height = 0.85
	rock.radial_segments = 10
	rock.rings = 6

	var stone := _make_moss_material(0.95)

	var stone_wet := _make_moss_material(0.45)
	stone_wet.set_shader_parameter("stone_tint", Color(0.20, 0.22, 0.21))
	stone_wet.set_shader_parameter("moss_tint", Color(0.20, 0.28, 0.14))

	_spawn_multimesh(rock, stone, _rock_dry)
	_spawn_multimesh(rock, stone_wet, _rock_wet)
	print("[rocks] dry: ", _rock_dry.size(), " wet: ", _rock_wet.size())

func _finish_trees() -> void:
	var t0 := Time.get_ticks_msec()
	var merged := 0
	for key in _tree_chunks:
		var lists: Array = _tree_chunks[key]
		var origin := Vector3(float(key.x) * TREE_CHUNK, 0.0, float(key.y) * TREE_CHUNK)

		# группируем по материалу: светлая кора и тёмная
		var groups := {0: [], 1: []}
		for i in lists.size():
			var transforms: Array = lists[i]
			if transforms.is_empty():
				continue
			var variant: Dictionary = _tree_variants[i]
			var g := 0 if variant["material"] == _mat_light else 1
			for t in transforms:
				(groups[g] as Array).append([variant["mesh"], t])

		for g in [0, 1]:
			var items: Array = groups[g]
			if items.is_empty():
				continue
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for item in items:
				var mesh: Mesh = item[0]
				var tr: Transform3D = item[1]
				st.append_from(mesh, 0, Transform3D(tr.basis, tr.origin - origin))
			var merged_mesh := st.commit()
			var node := MeshInstance3D.new()
			node.mesh = merged_mesh
			node.material_override = _mat_light if g == 0 else _mat_dark
			node.position = origin
			node.visibility_range_end = 0.0
			add_child(node)
			merged += 1
	print("[trees] merged nodes: ", merged, " за ", Time.get_ticks_msec() - t0, " мс")

func _spawn_mm(mesh: Mesh, material: Material, transforms: Array, origin: Vector3, begin: float, end: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for j in transforms.size():
		var t: Transform3D = transforms[j]
		mm.set_instance_transform(j, Transform3D(t.basis, t.origin - origin))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	node.position = origin
	if end > 0.0:
		node.visibility_range_end = end
		node.visibility_range_end_margin = 6.0
	if begin > 0.0:
		node.visibility_range_begin = begin
		node.visibility_range_begin_margin = 6.0
	add_child(node)

func _add_tree_collision_at(pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position = pos + Vector3(0.0, height * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)

func _marker_birch(pos: Vector3, index: int = 0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(root)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = TreeLibScript.build("birch", int(absf(pos.x) * 13.0 + absf(pos.z) * 7.0))
	mesh_instance.material_override = _mat_light
	root.add_child(mesh_instance)

	if index % 5 < 3:
		var branch := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.012
		bm.bottom_radius = 0.035
		bm.height = 0.62
		branch.mesh = bm
		var branch_mat := StandardMaterial3D.new()
		branch_mat.albedo_color = Color(0.36, 0.34, 0.30)
		branch_mat.roughness = 1.0
		branch.material_override = branch_mat
		branch.position = Vector3(0.0, 1.82, 0.0)
		branch.rotation.z = deg_to_rad(-62.0)
		root.add_child(branch)

		var hang := Node3D.new()
		hang.position = Vector3(0.52, 1.54, 0.0)
		root.add_child(hang)
		_wreaths.append({"node": hang, "phase": _rng.randf_range(0.0, TAU)})

		var wreath := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.26
		torus.outer_radius = 0.38
		torus.rings = 16
		torus.ring_segments = 8
		wreath.mesh = torus
		var wreath_mat := StandardMaterial3D.new()
		wreath_mat.albedo_color = Color(0.16, 0.20, 0.09)
		wreath_mat.emission_enabled = true
		wreath_mat.emission = Color(0.35, 0.10, 0.07)
		wreath_mat.emission_energy_multiplier = 0.18
		wreath.material_override = wreath_mat
		wreath.rotation.x = PI * 0.5
		wreath.scale = Vector3(0.48, 0.48, 0.48)
		hang.add_child(wreath)

		var berry_mat := StandardMaterial3D.new()
		berry_mat.albedo_color = Color(0.55, 0.06, 0.05)
		berry_mat.emission_enabled = true
		berry_mat.emission = Color(0.6, 0.05, 0.04)
		berry_mat.emission_energy_multiplier = 1.2
		for i in 5:
			var berry := MeshInstance3D.new()
			var bm2 := SphereMesh.new()
			bm2.radius = 0.026
			bm2.height = 0.052
			berry.mesh = bm2
			berry.material_override = berry_mat
			var a := TAU * float(i) / 5.0
			berry.position = Vector3(cos(a) * 0.26, 0.0, sin(a) * 0.26)
			hang.add_child(berry)

	_add_tree_collision(root, 0.24, 7.0)

func _near_path(x: float, z: float, radius: float) -> bool:
	for path in _paths:
		for i in range(0, (path["points"] as Array).size(), 6):
			var p: Vector3 = path["points"][i]
			if absf(p.x - x) < radius and absf(p.z - z) < radius:
				return true
	return _near_path_legacy(x, z, radius)

func _near_path_legacy(x: float, z: float, radius: float) -> bool:
	var step := 2
	for i in range(0, _path_points.size(), step):
		var p := _path_points[i]
		if Vector2(p.x - x, p.z - z).length() < radius:
			return true
	return false

func _add_tree_collision(parent: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height * 0.5
	body.add_child(shape)
	parent.add_child(body)

# --- костёр ---

func _build_camp_trees() -> void:
	var placed := 0
	var attempts := 0
	while placed < 11 and attempts < 200:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(13.0, 22.0)
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		if _near_path(x, z, 3.0):
			continue
		var h: float = terrain.height_at(x, z)
		if h < TerrainScript.WATER_LEVEL + 0.6:
			continue
		if terrain.slope_at(x, z) > 0.55:
			continue

		var species: String = ["birch", "birch_multi", "spruce", "oak", "pine"][placed % 5]
		var variant: int = _rng.randi_range(0, 1)
		var mesh := TreeLibScript.build(species, 7000 + placed * 13, false)
		var mat := _mat_dark if species in ["cedar", "spruce", "willow"] else _mat_light
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = mat
		node.position = Vector3(x, h - 0.1, z)
		node.rotation.y = _rng.randf_range(0.0, TAU)
		node.scale = Vector3.ONE * _rng.randf_range(0.9, 1.15)
		add_child(node)
		_add_tree_collision_at(Vector3(x, h, z), TreeLibScript.trunk_radius(species), TreeLibScript.height_of(species))
		placed += 1
	print("[camp trees] ", placed)

func _build_bonfire() -> void:
	bonfire_pos = Vector3(0, terrain.height_at(0, 0), 0)
	var parts := BonfireScript.build(self, bonfire_pos)
	_fire_light = parts["light"]

# --- тропа, изба, тьма по краю ---

func _build_path() -> void:
	_paths = [
		{"from": Vector3(0.0, 0.0, 0.0), "control": Vector3(-14.0, 0.0, -46.0), "to": HUTS[0]["pos"], "count": 78},
		{"from": Vector3(2.0, 0.0, 4.0), "control": Vector3(26.0, 0.0, -26.0), "to": HUTS[1]["pos"], "count": 60},
		{"from": Vector3(-3.0, 0.0, 2.0), "control": Vector3(-32.0, 0.0, 42.0), "to": HUTS[2]["pos"], "count": 60},
	]

	for path in _paths:
		var points: Array[Vector3] = []
		var a: Vector3 = path["from"]
		var control: Vector3 = path["control"]
		var b: Vector3 = path["to"]
		var count: int = path["count"]
		for i in count + 1:
			var t := float(i) / float(count)
			var p := a * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + b * t * t
			p.y = terrain.height_at(p.x, p.z)
			points.append(p)
		path["points"] = points
		if _path_points.is_empty():
			_path_points = points

	# маркерные берёзы вдоль каждой тропы
	var marker := 0
	for path in _paths:
		var points: Array = path["points"]
		for i in range(4, points.size() - 3, 9):
			var p: Vector3 = points[i]
			var prev_p: Vector3 = points[i - 1]
			var next_p: Vector3 = points[i + 1]
			var dir: Vector3 = next_p - prev_p
			dir.y = 0.0
			dir = dir.normalized()
			var side := Vector3(-dir.z, 0.0, dir.x)
			for sgn in [-1.0, 1.0]:
				var pos: Vector3 = p + side * (2.3 * sgn)
				pos.y = terrain.height_at(pos.x, pos.z)
				var near_hut := false
				for hut in HUTS:
					if Vector2(pos.x - hut["pos"].x, pos.z - hut["pos"].z).length() < 10.0:
						near_hut = true
				if near_hut:
					continue
				_marker_birch(pos, marker)
				marker += 1

func _build_hut() -> void:
	for hut in HUTS:
		var hp: Vector3 = hut["pos"]
		var hpos := Vector3(hp.x, terrain.height_at(hp.x, hp.z), hp.z)
		var parts := HutScript.build(self, hpos, deg_to_rad(35.0 + float(hut["main"]) * 0.0))
		if hut["main"]:
			_hut_parts = parts
			_hut_door = parts["door"]
			_hut_hearth_pos = parts["hearth"].global_position
			_amulet = parts["amulet"]
	_checkpoint = Vector3(2.8, terrain.height_at(2.8, 5.4) + 0.25, 5.4)

func _build_boundary() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = WORLD_EDGE
	mesh.bottom_radius = WORLD_EDGE
	mesh.height = 60.0
	mesh.radial_segments = 64
	mesh.rings = 1

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

void fragment() {
	float v = clamp(UV.y, 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.35, 0.95, v)) * 0.985;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader

	var wall := MeshInstance3D.new()
	wall.mesh = mesh
	wall.material_override = material
	wall.position.y = 20.0
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)

func _path_point_at(dist: float) -> Vector3:
	var acc := 0.0
	for i in _path_points.size() - 1:
		var seg := _path_points[i].distance_to(_path_points[i + 1])
		if acc + seg >= dist:
			var t := (dist - acc) / seg
			return _path_points[i].lerp(_path_points[i + 1], t)
		acc += seg
	return _path_points[_path_points.size() - 1]

func _update_underwater() -> void:
	if _env == null or player == null:
		return
	var cam_y: float = player.camera.global_position.y
	var under := cam_y < TerrainScript.WATER_LEVEL - 0.05
	if under == _underwater:
		return
	_underwater = under
	if under:
		_env.fog_density = 0.16
		_env.fog_light_color = Color(0.02, 0.06, 0.08)
		_env.ambient_light_energy = 0.12
		_env.background_color = Color(0.01, 0.03, 0.04)
	else:
		_env.fog_density = 0.052
		_env.fog_light_color = Color(0.035, 0.04, 0.055)
		_env.ambient_light_energy = 0.34
	hud.set_underwater(under)

func _update_encounters(delta: float) -> void:
	if _encounter_index >= _encounters.size():
		return
	var travelled := Vector2(player.global_position.x, player.global_position.z).length()
	if _encounter_enemy != null and is_instance_valid(_encounter_enemy) and _encounter_enemy.is_alive():
		var previous: float = 0.0
		if _encounter_index > 0:
			previous = float(_encounters[_encounter_index - 1]["at"])
		if travelled < previous + 20.0:
			return
	var entry = _encounters[_encounter_index]
	if travelled < entry["at"]:
		return
	var point := _path_point_at(entry["at"] + 9.0)
	_encounter_enemy = _spawn_enemy(Vector2(point.x, point.z), entry["kind"])
	_encounter_index += 1
	var names := {
		"wolf": "волк", "cultist": "послушник", "leshy": "леший",
		"wailer": "плакальщица", "kikimora": "кикимора",
	}
	hud.show_notice("Из тьмы выходит %s" % names.get(entry["kind"], entry["kind"]), 2.6)

func _clamp_to_world(delta: float) -> void:
	_edge_cooldown = maxf(0.0, _edge_cooldown - delta)
	var flat := Vector2(player.global_position.x, player.global_position.z)
	if flat.length() <= WORLD_EDGE - 3.0:
		return
	var dir := flat.normalized()
	player.global_position.x = dir.x * (WORLD_EDGE - 3.0)
	player.global_position.z = dir.y * (WORLD_EDGE - 3.0)
	player.apply_impulse(-Vector3(dir.x, 0.0, dir.y) * 5.0)
	if _edge_cooldown <= 0.0:
		_edge_cooldown = 3.0
		hud.show_notice("Тьма сгущается. Дальше не пройти.", 2.0)

# --- спавн ---

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	var spawn := Vector3(2.8, 0.0, 5.4)
	if LabStateScript.spawn_at.is_finite():
		spawn = Vector3(LabStateScript.spawn_at.x, 0.0, LabStateScript.spawn_at.z)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--at" and i + 1 < args.size():
			var parts := args[i + 1].split(",")
			if parts.size() == 2:
				spawn = Vector3(float(parts[0]), 0.0, float(parts[1]))
	spawn.y = terrain.height_at(spawn.x, spawn.z) + 0.25
	player.global_position = spawn
	player.notice.connect(_on_notice)
	player.died.connect(_on_player_died)

func _spawn_enemy(point: Vector2, kind: String = "wolf"):
	var enemy = EnemyScene.instantiate()
	enemy.setup(kind)
	add_child(enemy)
	var y: float = terrain.height_at(point.x, point.y) + 0.3
	enemy.global_position = Vector3(point.x, y, point.y)
	enemy.target = player
	enemy.died.connect(_on_enemy_died)
	_enemies.append(enemy)
	return enemy

func _respawn_enemies() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	_encounter_index = 0
	_encounter_enemy = null

func _build_hud() -> void:
	hud = HudScript.new()
	add_child(hud)
	hud.bind(player)

# --- события ---

func _try_hut_interaction() -> bool:
	if _amulet != null and is_instance_valid(_amulet) and not _amulet_taken:
		if player.global_position.distance_to(_amulet.global_position) < 1.3:
			_take_amulet()
			return true
	if _hut_hearth_pos != Vector3.ZERO and player.global_position.distance_to(_hut_hearth_pos) < 2.6:
		_rest_at_hut()
		return true
	if not _door_open and _hut_door != null and is_instance_valid(_hut_door):
		if player.global_position.distance_to(_hut_door.global_position) < 3.4:
			_open_hut_door()
			return true
	return false

func _open_hut_door() -> void:
	_door_open = true
	var tween := create_tween()
	tween.tween_property(_hut_door, "rotation:y", deg_to_rad(-108.0), 0.9).set_trans(Tween.TRANS_SINE)
	hud.show_notice("Дверь поддалась. Внутри пахнет дымом.", 3.0)

func _rest_at_hut() -> void:
	var at: Vector3 = _hut_parts["root"].to_global(Vector3(0.0, 0.25, 0.9))
	_checkpoint = at
	player.revive(at)
	player.flasks = 3
	player.refill_torch()
	_respawn_enemies()
	hud.show_notice("Очаг принял тебя. Теперь смерть вернёт сюда.", 3.5)

func _take_amulet() -> void:
	_amulet_taken = true
	player.max_health += 25.0
	player.health = player.max_health
	player.flasks += 1
	player.health_changed.emit(player.health, player.max_health)
	player.stats_changed.emit()
	if _amulet and is_instance_valid(_amulet):
		_amulet.queue_free()
	_amulet = null
	var light = _hut_parts.get("amulet_light")
	if light and is_instance_valid(light):
		light.queue_free()
	hud.show_notice("Оберег матери: +25 к здоровью, +1 фляга. Лес стал тише.", 5.0)

func _rest() -> void:
	var at := Vector3(2.8, terrain.height_at(2.8, 5.4) + 0.25, 5.4)
	_checkpoint = at
	player.revive(at)
	player.flasks = 3
	player.refill_torch()
	_respawn_enemies()
	hud.show_notice("Костёр принял тебя. Лес снова полон.", 3.5)
	hud.show_levels(player)

func _on_enemy_died(reward: int, at: Vector3) -> void:
	var gained := int(round(reward * (1.0 + player.perception * 0.1)))
	player.add_souls(gained)
	hud.show_notice("Души +%d" % gained, 1.5)

func _on_player_died() -> void:
	_dropped_souls = player.souls
	player.souls = 0
	player.souls_changed.emit(0)
	_spawn_soul_orb(player.global_position)
	await get_tree().create_timer(1.4).timeout
	player.revive(_checkpoint)
	_respawn_enemies()
	hud.show_notice("Ты очнулся у костра. Души остались в лесу.", 4.0)

func _on_notice(text: String) -> void:
	hud.show_notice(text, 1.6)

func _spawn_soul_orb(at: Vector3) -> void:
	if _soul_orb and is_instance_valid(_soul_orb):
		_soul_orb.queue_free()

	var orb := Node3D.new()
	add_child(orb)
	_orb_base_y = terrain.height_at(at.x, at.z) + 0.8
	orb.global_position = Vector3(at.x, _orb_base_y, at.z)

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.85, 1.0)
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	orb.add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.85, 1.0)
	light.light_energy = 1.4
	light.omni_range = 5.0
	orb.add_child(light)

	_soul_orb = orb

func _collect_souls() -> void:
	if _dropped_souls <= 0:
		return
	player.add_souls(_dropped_souls)
	hud.show_notice("Души возвращены: %d" % _dropped_souls, 2.5)
	_dropped_souls = 0
	if _soul_orb and is_instance_valid(_soul_orb):
		_soul_orb.queue_free()
	_soul_orb = null

static func _soft_particle_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex

