extends Node3D

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const HudScript := preload("res://scripts/hud.gd")
const TerrainScript := preload("res://scripts/terrain.gd")
const GrassScript := preload("res://scripts/grass.gd")

const TREE_COUNT := 240
const WORLD_LIMIT := 92.0

var player
var hud
var terrain
var bonfire_pos := Vector3.ZERO

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _fire_light: OmniLight3D
var _enemies: Array = []
var _spawn_points: Array[Vector2] = []
var _soul_orb: Node3D
var _orb_base_y := 0.0
var _dropped_souls := 0

func _enter_tree() -> void:
	_register_input()

func _ready() -> void:
	_rng.seed = 20261101
	_build_environment()
	_build_terrain()
	_build_forest()
	_build_bonfire()
	_spawn_player()
	_spawn_enemies()
	_build_hud()
	hud.show_notice("Костёр гаснет. Лес ждёт.", 4.0)


func _process(delta: float) -> void:
	_time += delta
	if _fire_light:
		_fire_light.light_energy = 2.3 + sin(_time * 9.0) * 0.35 + sin(_time * 23.0) * 0.12

	if _soul_orb and is_instance_valid(_soul_orb):
		_soul_orb.rotate_y(delta * 1.6)
		_soul_orb.position.y = _orb_base_y + sin(_time * 2.0) * 0.15

	if player == null or player.is_dead():
		return

	if Input.is_action_just_pressed("interact") and player.global_position.distance_to(bonfire_pos) < 3.6:
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
	_add_mouse("attack", MOUSE_BUTTON_LEFT)

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
	env.fog_density = 0.021
	env.fog_sky_affect = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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
	grass.populate(terrain, 22000, 44.0)

# --- лес ---

func _build_forest() -> void:
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.15, 0.14, 0.13)

	var birch_bark := StandardMaterial3D.new()
	birch_bark.albedo_color = Color(0.62, 0.62, 0.57)

	var needles := StandardMaterial3D.new()
	needles.albedo_color = Color(0.035, 0.075, 0.045)

	var leaves := StandardMaterial3D.new()
	leaves.albedo_color = Color(0.10, 0.16, 0.07)

	var placed := 0
	var attempts := 0
	while placed < TREE_COUNT and attempts < TREE_COUNT * 6:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var dist := sqrt(_rng.randf()) * WORLD_LIMIT
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		if Vector2(x, z).length() < 13.0:
			continue
		var h: float = terrain.height_at(x, z)
		if h < TerrainScript.WATER_LEVEL + 1.2:
			continue
		if terrain.slope_at(x, z) > 0.55:
			continue

		var pos := Vector3(x, h, z)
		if _rng.randf() < 0.6:
			_birch(pos, birch_bark, leaves)
		else:
			_spruce(pos, bark, needles)
		placed += 1

func _birch(pos: Vector3, bark_mat: Material, leaf_mat: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(root)

	var h := _rng.randf_range(5.0, 8.0)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.16
	cyl.height = h
	trunk.mesh = cyl
	trunk.position.y = h * 0.5
	trunk.material_override = bark_mat
	root.add_child(trunk)

	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _rng.randf_range(1.3, 2.1)
	sphere.height = sphere.radius * 2.0
	crown.mesh = sphere
	crown.position.y = h + sphere.radius * 0.3
	crown.material_override = leaf_mat
	root.add_child(crown)

	_add_tree_collision(root, 0.3, h)

func _spruce(pos: Vector3, bark_mat: Material, needle_mat: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(root)

	var h := _rng.randf_range(6.0, 10.0)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.2
	cyl.height = h
	trunk.mesh = cyl
	trunk.position.y = h * 0.5
	trunk.material_override = bark_mat
	root.add_child(trunk)

	for tier in 3:
		var cone := MeshInstance3D.new()
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = 2.2 - float(tier) * 0.55
		cone_mesh.height = 3.0
		cone.mesh = cone_mesh
		cone.position.y = h * 0.55 + float(tier) * 1.5
		cone.material_override = needle_mat
		root.add_child(cone)

	_add_tree_collision(root, 0.34, h)

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

# --- спавн ---

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	var spawn := Vector3(2.8, 0.0, 5.4)
	spawn.y = terrain.height_at(spawn.x, spawn.z) + 0.25
	player.global_position = spawn
	player.notice.connect(_on_notice)
	player.died.connect(_on_player_died)

func _spawn_enemies() -> void:
	_spawn_points = [
		Vector2(10.0, -9.0),
		Vector2(-20.0, -16.0),
		Vector2(26.0, 12.0),
		Vector2(-16.0, 22.0),
		Vector2(9.0, -32.0),
	]
	for point in _spawn_points:
		_spawn_enemy(point)

func _spawn_enemy(point: Vector2) -> void:
	var enemy = EnemyScene.instantiate()
	add_child(enemy)
	var y: float = terrain.height_at(point.x, point.y) + 0.3
	enemy.global_position = Vector3(point.x, y, point.y)
	enemy.target = player
	enemy.died.connect(_on_enemy_died)
	_enemies.append(enemy)

func _respawn_enemies() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	_spawn_enemies()

func _build_hud() -> void:
	hud = HudScript.new()
	add_child(hud)
	hud.bind(player)

# --- события ---

func _rest() -> void:
	var at := Vector3(2.8, terrain.height_at(2.8, 5.4) + 0.25, 5.4)
	player.revive(at)
	player.flasks = 3
	player.refill_torch()
	_respawn_enemies()
	hud.show_notice("Костёр принял тебя. Лес снова полон.", 3.5)

func _on_enemy_died(reward: int, at: Vector3) -> void:
	player.add_souls(reward)
	hud.show_notice("Души +%d" % reward, 1.5)

func _on_player_died() -> void:
	_dropped_souls = player.souls
	player.souls = 0
	player.souls_changed.emit(0)
	_spawn_soul_orb(player.global_position)
	await get_tree().create_timer(1.4).timeout
	var at := Vector3(2.8, terrain.height_at(2.8, 5.4) + 0.25, 5.4)
	player.revive(at)
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
