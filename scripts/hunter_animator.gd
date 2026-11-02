extends Node
## Процедурная анимация для 22-костного рига модели Кимы.
## Клипов в GLB нет, поэтому idle/walk/attack считаются кодом.

var sk: Skeleton3D
var ids: Dictionary = {}
var rests: Dictionary = {}
var speed: float = 0.0
var speed_target: float = 0.0
var phase: float = 0.0
var attack_t: float = -1.0
var attack_variant: int = 0
var block: bool = false
var two_handed: bool = false
var drawn: bool = false

# Временно 0: оси ног L/R не откалиброваны, иначе ноги разъезжаются.
# Вернуть 1.0 после теста осей; см. TODO_ANIMATIONS.md, раздел 2.1.
const LEG_SWING := 0.0

const BONES: Array = [
	"root", "pelvis", "spine_01", "spine_02", "neck", "head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
	"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
	"thigh_l", "calf_l", "foot_l", "toe_l",
	"thigh_r", "calf_r", "foot_r", "toe_r",
]

func setup(skeleton: Skeleton3D) -> void:
	sk = skeleton
	for name in BONES:
		var idx: int = sk.find_bone(String(name))
		ids[name] = idx
		if idx >= 0:
			rests[name] = sk.get_bone_rest(idx).basis.get_rotation_quaternion()

func set_locomotion(value: float) -> void:
	speed_target = clampf(value, 0.0, 7.0)

func play_attack(variant: int = 0) -> void:
	attack_variant = variant
	attack_t = 0.0
	block = false

func is_attacking() -> bool:
	return attack_t >= 0.0

func set_block(on: bool) -> void:
	block = on
	if on:
		attack_t = -1.0

func set_two_handed(on: bool) -> void:
	two_handed = on

func set_drawn(on: bool) -> void:
	drawn = on

func cape_report() -> Array:
	return [0.0, 0.0, 0.0]

func _process(delta: float) -> void:
	if sk == null:
		return
	speed = lerpf(speed, speed_target, 1.0 - exp(-delta * 6.0))
	var w: float = clampf(speed / 4.8, 0.0, 1.0)
	phase += delta * (2.2 + speed * 1.9)

	var rot: Dictionary = {}
	for name in BONES:
		rot[name] = Vector3.ZERO

	# дыхание и лёгкое покачивание
	rot["spine_01"] = Vector3(sin(phase * 0.55) * 0.012, sin(phase * 0.31) * 0.018, 0.0)
	rot["spine_02"] = Vector3(-sin(phase * 0.45) * 0.010, sin(phase * 0.27) * 0.014, 0.0)
	rot["neck"] = Vector3(sin(phase * 0.4) * 0.012, 0.0, 0.0)

	var sw: float = sin(phase)
	# ноги
	rot["thigh_l"] += Vector3(sw * 0.52 * w * LEG_SWING, 0.0, 0.0)
	rot["thigh_r"] += Vector3(-sw * 0.52 * w * LEG_SWING, 0.0, 0.0)
	rot["calf_l"] += Vector3(maxf(0.0, -sw) * 0.55 * w * LEG_SWING, 0.0, 0.0)
	rot["calf_r"] += Vector3(maxf(0.0, sw) * 0.55 * w * LEG_SWING, 0.0, 0.0)
	rot["foot_l"] += Vector3(-sw * 0.16 * w * LEG_SWING, 0.0, 0.0)
	rot["foot_r"] += Vector3(sw * 0.16 * w * LEG_SWING, 0.0, 0.0)
	rot["toe_l"] += Vector3(maxf(0.0, -sw) * 0.20 * w * LEG_SWING, 0.0, 0.0)
	rot["toe_r"] += Vector3(maxf(0.0, sw) * 0.20 * w * LEG_SWING, 0.0, 0.0)

	# руки: левая держит меч, правая свободна.
	# Z — отведение в сторону (проверено на риге), X — скрутка.
	rot["upperarm_l"] += Vector3(0.0, 0.0, 0.18 + sw * 0.10 * w)
	rot["upperarm_r"] += Vector3(0.0, 0.0, -0.18 - sw * 0.10 * w)
	rot["lowerarm_l"] += Vector3(0.0, 0.0, 0.10 * w)
	rot["lowerarm_r"] += Vector3(0.0, 0.0, -0.10 * w)

	# блок
	if block:
		rot["upperarm_l"] += Vector3(0.0, 0.0, 0.55)
		rot["lowerarm_l"] += Vector3(0.0, 0.0, 0.95)
		rot["upperarm_r"] += Vector3(0.0, 0.0, -0.40)
		rot["lowerarm_r"] += Vector3(0.0, 0.0, -1.00)
		rot["spine_02"] += Vector3(0.0, 0.0, 0.10)

	# атака левой рукой с мечом
	if attack_t >= 0.0:
		attack_t += delta
		var t: float = clampf(attack_t / 0.72, 0.0, 1.0)
		var swing: float = sin(t * PI)
		var wind: float = sin(minf(t * 2.2, 1.0) * PI * 0.5)
		if attack_variant == 1:
			rot["upperarm_l"] += Vector3(0.0, 0.0, 1.05 * swing)
			rot["lowerarm_l"] += Vector3(0.0, 0.0, 0.45 * swing)
		elif attack_variant == 2:
			rot["upperarm_l"] += Vector3(0.0, 0.0, -0.55 * swing)
			rot["lowerarm_l"] += Vector3(0.0, 0.0, -1.05 * swing)
		else:
			rot["upperarm_l"] += Vector3(0.0, 0.0, 1.35 * swing)
			rot["lowerarm_l"] += Vector3(0.0, 0.0, 0.30 * swing)
		rot["upperarm_l"] += Vector3(0.0, -0.25 * wind, 0.0)
		rot["spine_02"] += Vector3(0.0, -0.28 * swing, 0.10 * swing)
		rot["neck"] += Vector3(0.0, 0.18 * swing, 0.0)
		if t >= 1.0:
			attack_t = -1.0

	# двухручный хват / ножны
	if two_handed:
		rot["upperarm_r"] += Vector3(0.0, 0.0, -0.75)
		rot["lowerarm_r"] += Vector3(0.0, 0.0, -1.05)
	if drawn:
		rot["upperarm_l"] += Vector3(0.10, 0.0, 0.0)

	for name in BONES:
		var idx: int = int(ids.get(name, -1))
		if idx < 0:
			continue
		var q: Quaternion = Quaternion.from_euler(rot[name])
		var r: Quaternion = rests.get(name, Quaternion.IDENTITY)
		sk.set_bone_pose_rotation(idx, r * q)
