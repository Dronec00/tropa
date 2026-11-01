extends CharacterBody3D

signal died(souls_reward: int, at: Vector3)

enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER, STAGGER }

const GRAVITY := 18.0
const BoltScript := preload("res://scripts/bolt.gd")
const RobeBuilderScript := preload("res://scripts/robe.gd")

var kind := "wolf"
var target: Node3D
var max_health := 90.0
var health := 90.0
var damage := 18.0
var speed := 3.3
var aggro_range := 22.0
var attack_range := 2.5
var souls_reward := 45
var ranged := false
var min_range := 5.0
var _bob := 0.0

var state: State = State.IDLE
var _timer := 0.0
var _dead := false
var _torch_bonus := 1.0

var _model: Node3D
var _body_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _weapon_pivot: Node3D

func setup(new_kind: String) -> void:
	kind = new_kind
	match kind:
		"leshy":
			max_health = 240.0
			damage = 30.0
			speed = 1.9
			aggro_range = 20.0
			attack_range = 3.2
			souls_reward = 120
		"kikimora":
			max_health = 70.0
			damage = 15.0
			speed = 2.7
			aggro_range = 24.0
			attack_range = 11.0
			souls_reward = 90
			ranged = true
			min_range = 5.0
		"cultist":
			max_health = 120.0
			damage = 22.0
			speed = 2.4
			aggro_range = 21.0
			attack_range = 2.4
			souls_reward = 70
		"wailer":
			max_health = 85.0
			damage = 16.0
			speed = 1.7
			aggro_range = 24.0
			attack_range = 10.0
			souls_reward = 95
			ranged = true
			min_range = 6.0
		_:
			kind = "wolf"
			max_health = 90.0
			damage = 18.0
			speed = 3.3
			aggro_range = 22.0
			attack_range = 2.5
			souls_reward = 45
	health = max_health

func _ready() -> void:
	_build_model()
	health = max_health
	add_to_group("enemies")

func is_alive() -> bool:
	return not _dead

func marker_height() -> float:
	match kind:
		"leshy":
			return 3.2
		"kikimora":
			return 2.2
		"cultist":
			return 2.1
		"wailer":
			return 2.5
		_:
			return 2.1

# --- модель ---

func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.emission_enabled = true
	_eye_mat.emission_energy_multiplier = 1.8

	match kind:
		"leshy":
			_build_leshy()
		"kikimora":
			_build_kikimora()
		"cultist":
			_build_robe(Color(0.075, 0.065, 0.085), 1.6, Color(0.55, 0.9, 1.0), false)
		"wailer":
			_build_robe(Color(0.34, 0.35, 0.32), 1.9, Color(0.85, 1.0, 0.95), true)
		_:
			_build_wolf()

func _build_wolf() -> void:
	_body_mat = _mat(Color(0.09, 0.09, 0.10))
	_eye_mat.albedo_color = Color(0.9, 0.15, 0.1)
	_eye_mat.emission = Color(1.0, 0.12, 0.08)

	var body := _add(_capsule(0.42, 1.3), _body_mat, Vector3(0, 0.85, 0))
	body.rotation.x = 0.18
	_add(_sphere(0.26), _body_mat, Vector3(0, 1.55, -0.12))
	for x in [-0.09, 0.09]:
		_add(_sphere(0.045), _eye_mat, Vector3(x, 1.6, -0.34))

	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.44, 1.3, -0.2)
	_model.add_child(_weapon_pivot)
	var claw := _add(_box(Vector3(0.08, 0.9, 0.16)), _body_mat, Vector3(0, 0.42, 0))
	claw.rotation.x = 0.1

func _build_leshy() -> void:
	_body_mat = _mat(Color(0.12, 0.10, 0.06))
	_eye_mat.albedo_color = Color(1.0, 0.55, 0.1)
	_eye_mat.emission = Color(1.0, 0.45, 0.06)

	var trunk := _add(_cyl(0.34, 0.46, 1.9), _body_mat, Vector3(0, 1.55, 0))
	trunk.rotation.x = 0.06
	_add(_sphere(0.31), _body_mat, Vector3(0, 2.65, -0.05))

	# рога
	for side in [-1.0, 1.0]:
		var antler := _add(_cyl(0.03, 0.06, 0.75), _body_mat, Vector3(side * 0.2, 2.95, 0.0))
		antler.rotation = Vector3(-0.25, 0.0, side * -0.55)
		var tip := _add(_cyl(0.02, 0.03, 0.4), _body_mat, Vector3(side * 0.42, 3.2, 0.0))
		tip.rotation = Vector3(-0.5, 0.0, side * -0.9)

	for x in [-0.11, 0.11]:
		_add(_sphere(0.055), _eye_mat, Vector3(x, 2.7, -0.27))

	# руки-ветки
	for side in [-1.0, 1.0]:
		var arm := _add(_cyl(0.06, 0.09, 1.1), _body_mat, Vector3(side * 0.46, 1.7, 0.0))
		arm.rotation.z = side * 0.18

	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.55, 1.5, -0.1)
	_model.add_child(_weapon_pivot)
	var club := _add(_cyl(0.10, 0.16, 1.3), _body_mat, Vector3(0, 0.6, 0))
	club.rotation.x = 0.15

func _build_robe(color: Color, height: float, eye_color: Color, pale: bool) -> void:
	_body_mat = _mat(color)
	RobeBuilderScript.build(_model, color, height, eye_color, pale)
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.0, height - 0.5, 0.0)
	_model.add_child(_weapon_pivot)

func _build_kikimora() -> void:
	_body_mat = _mat(Color(0.16, 0.20, 0.17))
	_eye_mat.albedo_color = Color(0.4, 0.95, 0.9)
	_eye_mat.emission = Color(0.3, 0.9, 0.85)

	var robe := _add(_cyl(0.16, 0.42, 1.15), _body_mat, Vector3(0, 0.6, 0))
	robe.rotation.x = 0.0
	_add(_capsule(0.17, 0.6), _body_mat, Vector3(0, 1.35, 0))
	_add(_sphere(0.18), _body_mat, Vector3(0, 1.75, -0.02))
	for x in [-0.07, 0.07]:
		_add(_sphere(0.04), _eye_mat, Vector3(x, 1.78, -0.15))

	for side in [-1.0, 1.0]:
		var arm := _add(_cyl(0.035, 0.05, 0.85), _body_mat, Vector3(side * 0.26, 1.35, 0.0))
		arm.rotation.z = side * 0.35

	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(-0.3, 1.6, -0.1)
	_model.add_child(_weapon_pivot)
	_add(_sphere(0.08), _eye_mat, Vector3(0, 0.0, 0))

# --- поведение ---

func _physics_process(delta: float) -> void:
	if _dead:
		return

	_bob += delta
	if kind == "wailer":
		_model.position.y = 0.18 + sin(_bob * 1.8) * 0.06
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta

	if target == null or not is_instance_valid(target):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
	_timer -= delta

	match state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			if dist < aggro_range * _torch_bonus:
				_set_state(State.CHASE, 0.0)
		State.CHASE:
			_chase(dist, dir, delta)
		State.WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			_face(dir, delta, 3.0)
			if _timer <= 0.0:
				_set_state(State.STRIKE, 0.14)
		State.STRIKE:
			velocity.x = 0.0
			velocity.z = 0.0
			if _timer <= 0.0:
				_strike(dist)
				_set_state(State.RECOVER, 0.7 if kind != "kikimora" else 1.1)
		State.RECOVER:
			velocity.x = 0.0
			velocity.z = 0.0
			if _timer <= 0.0:
				_set_state(State.CHASE, 0.0)
		State.STAGGER:
			velocity.x = 0.0
			velocity.z = 0.0
			if _timer <= 0.0:
				_set_state(State.CHASE, 0.0)

	move_and_slide()

func _chase(dist: float, dir: Vector3, delta: float) -> void:
	if ranged:
		if dist < min_range:
			velocity.x = -dir.x * speed
			velocity.z = -dir.z * speed
			_face(dir, delta, 6.0)
		elif dist > attack_range:
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_face(dir, delta, 6.0)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_face(dir, delta, 5.0)
			_set_state(State.WINDUP, 0.85)
		return

	if dist > attack_range:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face(dir, delta, 7.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_state(State.WINDUP, 0.55 if kind == "wolf" else 0.9)

func _strike(dist: float) -> void:
	if kind == "kikimora":
		_cast_bolt()
		return
	if kind == "wailer":
		if dist < attack_range + 1.5 and target.has_method("take_damage"):
			target.take_damage(damage, self)
			if target.has_method("apply_impulse"):
				target.apply_impulse((target.global_position - global_position).normalized() * 4.0)
		return

	var reach := attack_range + (0.7 if kind == "wolf" else 0.6)
	if dist < reach and target.has_method("take_damage"):
		target.take_damage(damage, self)

func _cast_bolt() -> void:
	if target == null or not is_instance_valid(target):
		return
	var bolt = BoltScript.new()
	bolt.target = target
	bolt.damage = damage
	get_parent().add_child(bolt)
	var forward := -_model.global_transform.basis.z
	bolt.global_position = global_position + Vector3.UP * 1.5 + forward * 0.7

func _face(dir: Vector3, delta: float, speed_factor: float) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, speed_factor * delta)

func _set_state(next: State, duration: float) -> void:
	state = next
	_timer = duration
	match next:
		State.WINDUP:
			_eye_mat.emission_energy_multiplier = 4.5
			var wind := create_tween()
			wind.tween_property(_weapon_pivot, "rotation:x", -1.6, maxf(duration, 0.1))
		State.STRIKE:
			_eye_mat.emission_energy_multiplier = 6.5
			var strike := create_tween()
			strike.tween_property(_weapon_pivot, "rotation:x", 1.2, 0.1)
		State.RECOVER:
			_eye_mat.emission_energy_multiplier = 1.8
		State.STAGGER:
			_eye_mat.emission_energy_multiplier = 0.4
		_:
			_eye_mat.emission_energy_multiplier = 1.8

func take_damage(amount: float, source: Node = null) -> void:
	if _dead:
		return
	health -= amount
	_flash()
	if health <= 0.0:
		_dead = true
		velocity = Vector3.ZERO
		died.emit(souls_reward, global_position)
		queue_free()
	else:
		if state != State.STRIKE:
			_set_state(State.STAGGER, 0.30)

func set_torch_bonus(multiplier: float) -> void:
	_torch_bonus = multiplier

func _flash() -> void:
	var flash := create_tween()
	flash.tween_property(_body_mat, "albedo_color", Color(0.8, 0.15, 0.1), 0.05)
	flash.tween_property(_body_mat, "albedo_color", _base_color(), 0.22)

func _base_color() -> Color:
	match kind:
		"leshy":
			return Color(0.12, 0.10, 0.06)
		"kikimora":
			return Color(0.16, 0.20, 0.17)
		_:
			return Color(0.09, 0.09, 0.10)

# --- мелочи ---

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _add(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	_model.add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	return m

func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m
