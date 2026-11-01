extends Node3D

## Снаряд кикиморы: светящийся сгусток, который летит в игрока и тянет его к себе.

var target: Node3D
var damage := 15.0
var speed := 11.0
var pull := 4.5
var _life := 4.0

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 1.0, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 0.85)
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.95, 0.9)
	light.light_energy = 1.2
	light.omni_range = 4.0
	add_child(light)

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or target == null or not is_instance_valid(target):
		queue_free()
		return

	var aim := target.global_position + Vector3.UP * 1.0
	var to := aim - global_position
	var step := speed * delta

	if to.length() <= step + 0.45:
		if target.has_method("take_damage"):
			target.take_damage(damage, self)
		if target.has_method("apply_impulse"):
			target.apply_impulse(to.normalized() * pull)
		queue_free()
		return

	global_position += to.normalized() * step
