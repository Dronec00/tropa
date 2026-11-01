extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal souls_changed(total: int)
signal notice(text: String)
signal died
signal stats_changed
signal lock_changed(target)

const MOVE_SPEED := 4.4
const ROLL_SPEED := 10.5
const ROLL_TIME := 0.42
const ROLL_COST := 24.0
const ATTACK_COST := 20.0
const ATTACK_DAMAGE := 34.0
const ATTACK_RANGE := 2.9
const ATTACK_COOLDOWN := 0.62
const JUMP_VELOCITY := 4.2
const MOUSE_SENSITIVITY := 0.0024
const GRAVITY := 18.0
const INVULN_TIME := 0.30
const KnightModelScript := preload("res://scripts/knight_model.gd")
const CapeScript := preload("res://scripts/cape.gd")

var max_health := 100.0
var health := 100.0
var max_stamina := 100.0
var stamina := 100.0
var souls := 0
var flasks := 3
var damage_bonus := 0.0
var flask_heal := 45.0

var soul_level := 1
var strength := 0
var endurance := 0
var perception := 0
var craft := 0

var lock_target: Node3D
var lock_range := 20.0
var _lock_marker: MeshInstance3D
var _impulse := Vector3.ZERO

var _dead := false
var _roll_timer := 0.0
var _roll_dir := Vector3.ZERO
var _invuln := 0.0
var _attack_cd := 0.0
var _heal_cd := 0.0
var _skip_first_motion := true

var torch_max := 80.0
var torch_fuel := 80.0
var torch_lit := false

var _torch_time := 0.0
var _sword_pivot: Node3D
var _torch_flame: Node3D
var _torch_light: OmniLight3D
var _torch_particles: CPUParticles3D

const SWORD_BACK_POS := Vector3(0.02, 1.22, 0.19)
const SWORD_BACK_ROT := Vector3(0.10, 0.0, -0.55)
const SWORD_HAND_POS := Vector3(0.30, 1.14, -0.16)

@onready var rig: Node3D = $Rig
@onready var arm: SpringArm3D = $Rig/SpringArm3D
@onready var camera: Camera3D = $Rig/SpringArm3D/Camera3D
@onready var model: Node3D = $Model

func _ready() -> void:
	_build_model()
	_build_cape()
	_build_lock_marker()
	arm.add_excluded_object(get_rid())
	arm.rotation.x = -0.14
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	souls_changed.emit(souls)

func _build_cape() -> void:
	var cape = CapeScript.new()
	model.add_child(cape)
	cape.body = self

func _build_lock_marker() -> void:
	_lock_marker = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.34
	torus.rings = 16
	torus.ring_segments = 8
	_lock_marker.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.25)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lock_marker.material_override = mat
	_lock_marker.visible = false
	add_child(_lock_marker)

func _build_model() -> void:
	var parts := KnightModelScript.build(model)
	_sword_pivot = parts["sword_pivot"]
	_torch_flame = parts["torch_flame"]
	_torch_light = parts["torch_light"]
	_torch_particles = parts["torch_particles"]

func _process(delta: float) -> void:
	if _lock_marker.visible:
		_lock_marker.rotate_y(0.04)
	model.visible = arm.get_hit_length() > 0.9
	if torch_lit:
		_torch_time += delta
		torch_fuel = maxf(0.0, torch_fuel - delta)
		_torch_light.light_energy = 2.2 + sin(_torch_time * 11.0) * 0.28 + sin(_torch_time * 23.0) * 0.12
		if torch_fuel <= 0.0:
			_set_torch(false)
			notice.emit("Факел погас — нечем гореть")

func toggle_torch() -> void:
	if _dead:
		return
	if torch_lit:
		_set_torch(false)
		return
	if torch_fuel <= 0.5:
		notice.emit("Факел пуст — нужно к костру")
		return
	_set_torch(true)
	notice.emit("Факел зажжён")

func _set_torch(on: bool) -> void:
	torch_lit = on
	_torch_flame.visible = on
	_torch_particles.emitting = on
	_torch_light.visible = on
	_torch_light.light_energy = 2.2 if on else 0.0

func refill_torch() -> void:
	torch_fuel = torch_max
	_set_torch(false)

func torch_is_lit() -> bool:
	return torch_lit

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _dead:
		# первый событийный сдвиг после захвата курсора на macOS бывает огромным — пропускаем
		if _skip_first_motion:
			_skip_first_motion = false
			return
		rig.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		arm.rotation.x = clampf(arm.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.05, 0.45)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if _dead:
		return

	_invuln = maxf(0.0, _invuln - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_heal_cd = maxf(0.0, _heal_cd - delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := rig.global_transform.basis * Vector3(input.x, 0.0, input.y)
	move_dir.y = 0.0
	move_dir = move_dir.normalized()

	if _roll_timer > 0.0:
		_roll_timer -= delta
		velocity.x = _roll_dir.x * ROLL_SPEED
		velocity.z = _roll_dir.z * ROLL_SPEED
	else:
		velocity.x = move_dir.x * MOVE_SPEED
		velocity.z = move_dir.z * MOVE_SPEED
		if move_dir.length() > 0.1:
			var target_yaw := atan2(-move_dir.x, -move_dir.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 14.0 * delta)

	velocity.x += _impulse.x
	velocity.z += _impulse.z
	_impulse = _impulse.move_toward(Vector3.ZERO, 30.0 * delta)

	if lock_target and is_instance_valid(lock_target):
		_update_lock_camera(delta)

	move_and_slide()

	var regen := 12.0 if _roll_timer <= 0.0 and _attack_cd <= 0.0 else 4.0
	stamina = minf(max_stamina, stamina + regen * delta)
	stamina_changed.emit(stamina, max_stamina)

	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if Input.is_action_just_pressed("dodge"):
		_try_roll(move_dir)
	if Input.is_action_just_pressed("heal"):
		_try_heal()
	if Input.is_action_just_pressed("torch"):
		toggle_torch()
	if Input.is_action_just_pressed("lock"):
		toggle_lock()

	if lock_target and (not is_instance_valid(lock_target) or not lock_target.is_alive()
			or global_position.distance_to(lock_target.global_position) > lock_range * 1.4):
		release_lock()

# --- лок-он ---

func toggle_lock() -> void:
	if lock_target and is_instance_valid(lock_target):
		release_lock()
		return
	var best: Node3D = null
	var best_score := 1e9
	var forward := -camera.global_transform.basis.z
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist > lock_range:
			continue
		var to: Vector3 = (enemy.global_position - global_position).normalized()
		var facing: float = forward.dot(to)
		if facing < 0.15:
			continue
		var score: float = dist * (1.7 - facing)
		if score < best_score:
			best_score = score
			best = enemy
	if best:
		lock_target = best
		_lock_marker.reparent(best)
		_lock_marker.position = Vector3(0, best.marker_height(), 0)
		_lock_marker.visible = true
		lock_changed.emit(best)

func release_lock() -> void:
	if _lock_marker.get_parent() != self:
		_lock_marker.reparent(self)
	_lock_marker.position = Vector3.ZERO
	_lock_marker.visible = false
	lock_target = null
	lock_changed.emit(null)

func _update_lock_camera(delta: float) -> void:
	var aim := lock_target.global_position + Vector3.UP * 1.1
	var to_aim := aim - (global_position + Vector3.UP * 1.5)
	var yaw := atan2(-to_aim.x, -to_aim.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, yaw, 7.0 * delta)
	var flat := Vector2(to_aim.x, to_aim.z).length()
	var pitch := clampf(atan2(to_aim.y, flat), -0.75, 0.45)
	arm.rotation.x = lerp_angle(arm.rotation.x, pitch, 5.0 * delta)

# --- прокачка ---

func level_cost() -> int:
	return 45 + 40 * (soul_level - 1)

func spend_souls(branch: String) -> bool:
	var cost := level_cost()
	if souls < cost:
		notice.emit("Не хватает душ: нужно %d" % cost)
		return false
	souls -= cost
	soul_level += 1
	match branch:
		"strength":
			strength += 1
			damage_bonus += 6.0
			notice.emit("Сила +1 — урон меча вырос")
		"endurance":
			endurance += 1
			max_health += 15.0
			max_stamina += 12.0
			health = minf(max_health, health + 15.0)
			notice.emit("Выносливость +1 — здоровья и сил больше")
		"perception":
			perception += 1
			lock_range += 3.0
			notice.emit("Чутьё +1 — лок-он дальше")
		"craft":
			craft += 1
			flask_heal += 15.0
			torch_max += 15.0
			notice.emit("Ремесло +1 — фляга и факел крепче")
	souls_changed.emit(souls)
	stats_changed.emit()
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	return true

func apply_impulse(force: Vector3) -> void:
	force.y = 0.0
	_impulse += force

func _try_roll(move_dir: Vector3) -> void:
	if _roll_timer > 0.0 or _attack_cd > 0.0 or stamina < ROLL_COST:
		return
	stamina -= ROLL_COST
	stamina_changed.emit(stamina, max_stamina)
	_roll_timer = ROLL_TIME
	_invuln = INVULN_TIME
	_roll_dir = move_dir if move_dir.length() > 0.1 else -model.global_transform.basis.z
	_roll_dir.y = 0.0
	_roll_dir = _roll_dir.normalized()

func _try_attack() -> void:
	if _attack_cd > 0.0 or _roll_timer > 0.0 or stamina < ATTACK_COST:
		return
	_attack_cd = ATTACK_COOLDOWN
	stamina -= ATTACK_COST
	stamina_changed.emit(stamina, max_stamina)
	_swing()
	await get_tree().create_timer(0.16).timeout
	if not _dead:
		_apply_hit()

func _swing() -> void:
	var pivot := _sword_pivot

	var draw := create_tween().set_parallel(true)
	draw.tween_property(pivot, "position", SWORD_HAND_POS, 0.09)
	draw.tween_property(pivot, "rotation", Vector3.ZERO, 0.09)
	await draw.finished

	var slash := create_tween()
	slash.tween_property(pivot, "rotation:x", -1.45, 0.09)
	slash.tween_property(pivot, "rotation:x", 1.15, 0.12)
	await slash.finished

	var back := create_tween().set_parallel(true)
	back.tween_property(pivot, "position", SWORD_BACK_POS, 0.22)
	back.tween_property(pivot, "rotation", SWORD_BACK_ROT, 0.22)

func _apply_hit() -> void:
	var origin := global_position + Vector3.UP * 1.2
	var forward := -model.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for angle in [-0.4, 0.0, 0.4]:
		var dir: Vector3 = forward.rotated(Vector3.UP, angle)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * ATTACK_RANGE)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(ATTACK_DAMAGE + damage_bonus, self)
			return

func _try_heal() -> void:
	if flasks <= 0 or _heal_cd > 0.0 or health >= max_health:
		return
	flasks -= 1
	_heal_cd = 1.0
	health = minf(max_health, health + flask_heal)
	health_changed.emit(health, max_health)
	notice.emit("Фляга: осталось %d" % flasks)

func take_damage(amount: float, source: Node = null) -> void:
	if _dead or _invuln > 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_dead = true
		velocity = Vector3.ZERO
		died.emit()

func add_souls(amount: int) -> void:
	souls += amount
	souls_changed.emit(souls)

func revive(at: Vector3) -> void:
	_dead = false
	global_position = at
	velocity = Vector3.ZERO
	health = max_health
	stamina = max_stamina
	_roll_timer = 0.0
	_invuln = 1.2
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_skip_first_motion = true

func is_dead() -> bool:
	return _dead
