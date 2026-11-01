extends CharacterBody3D

signal died(souls_reward: int, at: Vector3)

enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER, STAGGER }

const GRAVITY := 18.0

var target: Node3D
var max_health := 90.0
var health := 90.0
var damage := 18.0
var speed := 3.3
var aggro_range := 22.0
var attack_range := 2.5
var souls_reward := 45

var state: State = State.IDLE
var _timer := 0.0
var _dead := false

var _model: Node3D
var _body_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _weapon_pivot: Node3D

func _ready() -> void:
	_build_model()
	health = max_health

func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.09, 0.09, 0.10)
	_body_mat.roughness = 1.0

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.3
	body.mesh = body_mesh
	body.position.y = 0.85
	body.rotation.x = 0.18
	body.material_override = _body_mat
	_model.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.26
	head_mesh.height = 0.5
	head.mesh = head_mesh
	head.position = Vector3(0, 1.55, -0.12)
	head.material_override = _body_mat
	_model.add_child(head)

	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.9, 0.15, 0.1)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(1.0, 0.12, 0.08)
	_eye_mat.emission_energy_multiplier = 1.8

	for x in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.045
		eye_mesh.height = 0.09
		eye.mesh = eye_mesh
		eye.position = Vector3(x, 1.6, -0.34)
		eye.material_override = _eye_mat
		_model.add_child(eye)

	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.44, 1.3, -0.2)
	_model.add_child(_weapon_pivot)

	var claw := MeshInstance3D.new()
	var claw_mesh := BoxMesh.new()
	claw_mesh.size = Vector3(0.08, 0.9, 0.16)
	claw.mesh = claw_mesh
	claw.position.y = 0.42
	claw.material_override = _body_mat
	_weapon_pivot.add_child(claw)

func _physics_process(delta: float) -> void:
	if _dead:
		return

	if not is_on_floor():
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
			if dist < aggro_range:
				_set_state(State.CHASE, 0.0)
		State.CHASE:
			if dist > attack_range:
				velocity.x = dir.x * speed
				velocity.z = dir.z * speed
				_face(dir, delta, 7.0)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				_set_state(State.WINDUP, 0.55)
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
				var hit_dist := global_position.distance_to(target.global_position)
				if hit_dist < attack_range + 0.7 and target.has_method("take_damage"):
					target.take_damage(damage, self)
				_set_state(State.RECOVER, 0.7)
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
		_set_state(State.STAGGER, 0.34)

func _flash() -> void:
	var flash := create_tween()
	flash.tween_property(_body_mat, "albedo_color", Color(0.8, 0.15, 0.1), 0.05)
	flash.tween_property(_body_mat, "albedo_color", Color(0.09, 0.09, 0.10), 0.22)
