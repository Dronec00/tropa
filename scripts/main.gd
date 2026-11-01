extends Node3D

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const HudScript := preload("res://scripts/hud.gd")
const TerrainScript := preload("res://scripts/terrain.gd")
const GrassScript := preload("res://scripts/grass.gd")
const WindScript := preload("res://scripts/wind.gd")
const HutScript := preload("res://scripts/hut.gd")
const LabStateScript := preload("res://scripts/lab_state.gd")

const TREE_COUNT := 380
const WORLD_LIMIT := 92.0
const WORLD_EDGE := 82.0
const HUT_POS := Vector3(-34.0, 0.0, -52.0)

const TREE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D bark_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float wind = 0.22;

global uniform vec3 player_pos;

varying float v_height;
varying float v_leaf;
varying vec3 v_world;

void vertex() {
	v_height = UV2.x;
	v_leaf = UV2.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world = world;

	float phase = world.x * 0.22 + world.z * 0.19;
	float gust = 0.62 + 0.38 * sin(TIME * 0.33 + world.x * 0.02);
	float sway = (sin(TIME * 0.9 + phase) + 0.4 * sin(TIME * 2.3 + phase * 1.7)) * gust;
	float amount = v_height * v_height;
	VERTEX.x += sway * wind * amount;
	VERTEX.z += sway * wind * 0.55 * amount;

	vec3 to_player = world - player_pos;
	float d = length(to_player.xz);
	float push = smoothstep(2.8, 0.6, d);
	vec2 dir = normalize(to_player.xz + vec2(0.001));
	VERTEX.x += dir.x * push * 0.2 * v_height;
	VERTEX.z += dir.y * push * 0.2 * v_height;
}

void fragment() {
	vec3 albedo;
	if (v_leaf > 0.5) {
		vec4 c = texture(leaf_tex, UV);
		if (c.a < 0.35) {
			discard;
		}
		albedo = COLOR.rgb * c.rgb * 2.2;
	} else {
		albedo = COLOR.rgb * texture(bark_tex, UV * vec2(1.0, 3.0)).rgb * 1.5;
	}
	float variation = 0.88 + 0.12 * sin(v_world.x * 0.7 + v_world.z * 0.6);
	ALBEDO = albedo * variation;
	ROUGHNESS = 1.0;
	BACKLIGHT = COLOR.rgb * 0.4;
}
"""

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
var _edge_cooldown := 0.0
var _hut_parts: Dictionary = {}
var _hut_door: Node3D
var _hut_hearth_pos := Vector3.ZERO
var _amulet: Node3D
var _amulet_taken := false
var _door_open := false
var _checkpoint := Vector3(2.8, 0.0, 5.4)
const TreeLibScript := preload("res://scripts/tree_lib.gd")
const SPECIES := ["birch", "birch_multi", "oak", "ash", "cedar", "spruce", "willow"]

var _tree_shader: Shader
var _mat_light: ShaderMaterial
var _mat_dark: ShaderMaterial
var _tree_variants: Array = []
var _tree_instances: Array = []
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
	_build_boundary()
	_build_forest()
	_build_bonfire()
	_build_undergrowth()
	_build_rocks()
	_spawn_player()
	_build_hud()
	hud.show_notice("Костёр гаснет. Лес ждёт.", 4.0)


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
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.035, 0.045, 0.06)
	sky_mat.sky_horizon_color = Color(0.16, 0.17, 0.19)
	sky_mat.ground_bottom_color = Color(0.02, 0.022, 0.025)
	sky_mat.ground_horizon_color = Color(0.10, 0.11, 0.13)
	sky_mat.sky_energy_multiplier = 0.65

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.45)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.11, 0.13)
	env.fog_density = 0.034
	env.fog_sky_affect = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.35, 0.39, 0.44)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 0.97

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-46, 28, 0)
	moon.light_color = Color(0.62, 0.70, 0.88)
	moon.light_energy = 1.3
	moon.shadow_enabled = true
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
	grass.populate(terrain, 60000, 40.0)

# --- лес ---

func _create_tree_materials() -> void:
	_tree_shader = Shader.new()
	_tree_shader.code = TREE_SHADER

	var bark_light: Texture2D = null
	var bark_dark: Texture2D = null
	var leaf: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/birch_bark.png"):
		bark_light = load("res://assets/textures/birch_bark.png")
	if ResourceLoader.exists("res://assets/textures/spruce_bark.png"):
		bark_dark = load("res://assets/textures/spruce_bark.png")
	if ResourceLoader.exists("res://assets/textures/leaf_atlas.png"):
		leaf = load("res://assets/textures/leaf_atlas.png")

	_mat_light = _make_tree_material(bark_light, leaf)
	_mat_dark = _make_tree_material(bark_dark, leaf)

	for i in SPECIES.size():
		for v in 2:
			var mesh := TreeLibScript.build(SPECIES[i], 1000 + i * 17 + v * 5)
			var material := _mat_dark if SPECIES[i] in ["cedar", "spruce", "willow"] else _mat_light
			_tree_variants.append({"mesh": mesh, "species": SPECIES[i], "material": material})
			_tree_instances.append([])

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
		return {"birch": 0.30, "birch_multi": 0.16, "willow": 0.28, "ash": 0.14, "oak": 0.08, "cedar": 0.02, "spruce": 0.02}
	if h < 2.6:
		return {"birch": 0.38, "birch_multi": 0.16, "ash": 0.20, "oak": 0.14, "cedar": 0.06, "spruce": 0.06, "willow": 0.0}
	if h > 6.0:
		return {"birch": 0.18, "birch_multi": 0.08, "ash": 0.12, "oak": 0.14, "cedar": 0.26, "spruce": 0.22, "willow": 0.0}
	return {"birch": 0.30, "birch_multi": 0.14, "ash": 0.18, "oak": 0.16, "cedar": 0.12, "spruce": 0.10, "willow": 0.0}

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
		(_tree_instances[variant] as Array).append(Transform3D(basis, Vector3(x, h - 0.1, z)))

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

func _add_rock(list: Array, x: float, z: float) -> void:
	var h: float = terrain.height_at(x, z)
	if h < TerrainScript.WATER_LEVEL - 0.4:
		return
	var s := _rng.randf_range(0.35, 0.95)
	var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(
		s * _rng.randf_range(0.9, 1.5),
		s * _rng.randf_range(0.5, 0.8),
		s * _rng.randf_range(0.9, 1.5)
	))
	list.append(Transform3D(basis, Vector3(x, h + 0.02, z)))

func _build_rocks() -> void:
	var transforms: Array = []

	# берега реки
	for z in range(-90, 91, 5):
		var c: float = terrain.river_center(float(z))
		for side in [-1.0, 1.0]:
			if _rng.randf() < 0.45:
				continue
			_add_rock(transforms, c + side * _rng.randf_range(8.5, 12.0), float(z))

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
	for i in range(0, _path_points.size(), 3):
		var p: Vector3 = _path_points[i]
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

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.17, 0.17, 0.16)
	stone.roughness = 1.0

	_spawn_multimesh(rock, stone, transforms)
	print("[rocks] ", transforms.size())

func _finish_trees() -> void:
	for i in _tree_variants.size():
		var transforms: Array = _tree_instances[i]
		if transforms.is_empty():
			continue
		var variant: Dictionary = _tree_variants[i]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = variant["mesh"]
		multimesh.instance_count = transforms.size()
		for j in transforms.size():
			multimesh.set_instance_transform(j, transforms[j])

		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.material_override = variant["material"]
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

func _marker_birch(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(root)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = TreeLibScript.build("birch", int(absf(pos.x) * 13.0 + absf(pos.z) * 7.0))
	mesh_instance.material_override = _mat_light
	root.add_child(mesh_instance)

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
	wreath.position = Vector3(0.0, 1.75, 0.0)
	wreath.rotation.x = PI * 0.5
	wreath.scale = Vector3(0.85, 0.85, 0.85)
	root.add_child(wreath)

	var berry_mat := StandardMaterial3D.new()
	berry_mat.albedo_color = Color(0.55, 0.06, 0.05)
	berry_mat.emission_enabled = true
	berry_mat.emission = Color(0.6, 0.05, 0.04)
	berry_mat.emission_energy_multiplier = 1.2
	for i in 5:
		var berry := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.045
		bm.height = 0.09
		berry.mesh = bm
		berry.material_override = berry_mat
		var a := TAU * float(i) / 5.0
		berry.position = Vector3(cos(a) * 0.32, 1.75, sin(a) * 0.32)
		root.add_child(berry)

	_add_tree_collision(root, 0.24, 7.0)

func _near_path(x: float, z: float, radius: float) -> bool:
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

func _build_bonfire() -> void:
	bonfire_pos = Vector3(0, terrain.height_at(0, 0), 0)

	var root := Node3D.new()
	root.position = bonfire_pos
	add_child(root)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.17, 0.17, 0.18)

	for i in 9:
		var stone := MeshInstance3D.new()
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.16
		stone_mesh.height = 0.3
		stone.mesh = stone_mesh
		var a := TAU * float(i) / 9.0
		stone.position = Vector3(cos(a) * 0.95, 0.1, sin(a) * 0.95)
		stone.material_override = stone_mat
		root.add_child(stone)

	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.11, 0.07, 0.05)
	for i in 4:
		var log_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.1
		cyl.height = 1.15
		log_mesh.mesh = cyl
		log_mesh.position = Vector3(0, 0.3, 0)
		log_mesh.rotation = Vector3(PI * 0.5, TAU * float(i) / 4.0, 0.18)
		log_mesh.material_override = log_mat
		root.add_child(log_mesh)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.17
	flame_mesh.height = 0.42
	flame.mesh = flame_mesh
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.45, 0.12)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.42, 0.1)
	flame_mat.emission_energy_multiplier = 4.0
	flame.material_override = flame_mat
	flame.position.y = 0.55
	root.add_child(flame)

	var fire := CPUParticles3D.new()
	fire.position = Vector3(0.0, 0.55, 0.0)
	fire.amount = 26
	fire.lifetime = 0.65
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.16
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 14.0
	fire.gravity = Vector3(0, 1.4, 0)
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.85
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.5
	fire.color = Color(1.0, 0.5, 0.12, 0.9)
	var fire_quad := QuadMesh.new()
	fire_quad.size = Vector2(0.5, 0.5)
	fire.mesh = fire_quad
	var fire_mat := StandardMaterial3D.new()
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire_mat.vertex_color_use_as_albedo = true
	fire_mat.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	fire_mat.albedo_texture = _soft_particle_texture()
	fire.material_override = fire_mat
	root.add_child(fire)

	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(0, 1.1, 0)
	_fire_light.light_color = Color(1.0, 0.6, 0.28)
	_fire_light.light_energy = 2.4
	_fire_light.omni_range = 15.0
	_fire_light.shadow_enabled = true
	root.add_child(_fire_light)

# --- тропа, изба, тьма по краю ---

func _build_path() -> void:
	var start := Vector3.ZERO
	var control := Vector3(-6.0, 0.0, -26.0)
	var end := Vector3(HUT_POS.x, 0.0, HUT_POS.z)
	var count := 46
	for i in count + 1:
		var t := float(i) / float(count)
		var p := start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + end * t * t
		p.y = terrain.height_at(p.x, p.z)
		_path_points.append(p)

	for i in range(4, _path_points.size() - 3, 3):
		var p := _path_points[i]
		var dir := _path_points[i + 1] - _path_points[i - 1]
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		for s in [-1.0, 1.0]:
			var pos: Vector3 = p + side * (2.3 * s)
			pos.y = terrain.height_at(pos.x, pos.z)
			if Vector2(pos.x - HUT_POS.x, pos.z - HUT_POS.z).length() < 9.0:
				continue
			_marker_birch(pos)

func _build_hut() -> void:
	var pos := Vector3(HUT_POS.x, terrain.height_at(HUT_POS.x, HUT_POS.z), HUT_POS.z)
	_hut_parts = HutScript.build(self, pos, deg_to_rad(35.0))
	_hut_door = _hut_parts["door"]
	_hut_hearth_pos = _hut_parts["hearth"].global_position
	_amulet = _hut_parts["amulet"]
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

