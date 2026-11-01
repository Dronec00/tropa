extends Node

## Аниматор дампира: стойка, шаг/бег, три удара с выниманием меча из-за спины,
## блок, «меч в руке» для витрины. Всё процедурное — без AnimationPlayer.
##
## Витрина/игрок зовут:
##   set_locomotion(speed)   — каждый кадр, 0 = стойка
##   play_attack(variant)    — 0,1,2; удар ~0.80 c
##   set_block(on)
##   set_two_handed(on)      — true: обе руки на мече, false: левая с пламенем
##   set_drawn(on)           — только витрина: держать меч в руке
##
## Меч не является частью руки: он всегда висит в корне модели и каждый кадр
## получает трансформ либо ножен за спиной, либо кисти. Так вынимание выглядит
## плавно и не ломает иерархию.

const GRIP_OFFSET := Vector3(0.0, -0.052, -0.004)

var _rig: Dictionary
var _t := 0.0
var _phase := 0.0
var _speed := 0.0
var _target_speed := 0.0

var _attacking := false
var _attack_t := 0.0
var _attack_len := 0.80
var _variant := 0
var _block := false
var _two_handed := true
var _drawn := false

var _draw := 0.0
var _want_draw := 0.0
var _blink_t := 3.0
var _blink := 0.0

var _rest: Dictionary = {}
var _cape_rot: Array[Vector3] = []
var _keys: Array[String] = [
	"hips", "torso", "head",
	"shoulder_r", "elbow_r", "wrist_r",
	"shoulder_l", "elbow_l", "wrist_l",
	"thigh_r", "knee_r", "ankle_r",
	"thigh_l", "knee_l", "ankle_l",
]

func setup(rig: Dictionary) -> void:
	_rig = rig
	process_priority = 10
	for key in _keys:
		var node: Node3D = _rig.get(key) as Node3D
		if node != null:
			_rest[key] = node.rotation
	# плащ и волосы: фиксируем позу покоя ОДИН раз. Раньше база бралась из
	# текущего кадра — угол накапливался, и плащ улетал через голову.
	var segs: Array = _rig.get("cape", [])
	for i in range(segs.size()):
		var seg: Node3D = segs[i] as Node3D
		_rest["cape_%d" % i] = seg.rotation
		_cape_rot.append(seg.rotation)
	var hairs: Array = _rig.get("hair", [])
	for i in range(hairs.size()):
		var hair: Node3D = hairs[i] as Node3D
		_rest["hair_%d" % i] = hair.rotation
	var hat: Node3D = _rig.get("hat") as Node3D
	if hat != null:
		_rest["hat"] = hat.rotation
	set_process(true)

func set_locomotion(speed: float) -> void:
	_target_speed = maxf(0.0, speed)

func play_attack(variant: int = 0) -> void:
	_variant = clampi(variant, 0, 2)
	_attacking = true
	_attack_t = 0.0
	_attack_len = 0.90 if _variant == 2 else 0.80

func set_block(on: bool) -> void:
	_block = on

func set_two_handed(on: bool) -> void:
	_two_handed = on
	var torch: Node3D = _rig.get("torch") as Node3D
	if torch != null:
		torch.visible = not on

func set_drawn(on: bool) -> void:
	_drawn = on

func is_attacking() -> bool:
	return _attacking

# =========================================================================

func _process(delta: float) -> void:
	_t += delta
	_speed = lerpf(_speed, _target_speed, minf(1.0, delta * 7.0))
	_phase += delta * (2.4 + _speed * 1.55)

	if _attacking:
		_attack_t += delta
		if _attack_t >= _attack_len:
			_attacking = false
			_attack_t = 0.0
			_drawn = false

	var want := 1.0 if (_attacking or _block or _drawn) else 0.0
	_want_draw = want
	var rate := 16.0 if _attacking else 9.0
	_draw = move_toward(_draw, _want_draw, delta * rate)

	_update_blink(delta)
	_update_sword()
	_apply_pose(delta)

func _update_blink(delta: float) -> void:
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.14
		_blink_t = 3.2 + fmod(absf(sin(_t * 1.73)), 3.4)
	_blink = maxf(0.0, _blink - delta)
	var lid_r: Node3D = _rig.get("lid_r") as Node3D
	var lid_l: Node3D = _rig.get("lid_l") as Node3D
	var open := clampf(_blink / 0.07, 0.0, 1.0)
	if lid_r != null:
		lid_r.scale.y = 1.0 - open * 0.92
	if lid_l != null:
		lid_l.scale.y = 1.0 - open * 0.92

# =========================================================================
#  Меч: ножны за спиной <-> кисть
# =========================================================================

func _update_sword() -> void:
	var sword: Node3D = _rig.get("sword") as Node3D
	var hilt: Node3D = _rig.get("hilt") as Node3D
	var mount: Node3D = _rig.get("sword_mount") as Node3D
	var grip: Node3D = _rig.get("grip") as Node3D
	if sword == null or mount == null or grip == null:
		return

	var back: Transform3D = mount.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.10, 0.0))
	var hand: Transform3D = grip.global_transform
	var k: float = _ease(_draw)

	if k <= 0.001:
		sword.visible = false
	else:
		sword.visible = true
		sword.global_transform = back.interpolate_with(hand, k)

	if hilt != null:
		hilt.visible = _draw < 0.5

	var flame: Node3D = _rig.get("torch") as Node3D
	if flame != null:
		flame.visible = not _two_handed

# =========================================================================
#  Позы
# =========================================================================

func _apply_pose(delta: float) -> void:
	var p: Dictionary = _base_pose()
	_add_idle(p)
	_add_gait(p)
	if _block:
		_block_pose(p)
	if _attacking:
		_attack_pose(p)
	_apply(p, delta)

func _base_pose() -> Dictionary:
	return {
		"hips_y": 0.0,
		"hips_yaw": 0.0, "hips_roll": 0.0,
		"torso_pitch": 0.0, "torso_yaw": 0.0, "torso_roll": 0.0,
		"head_pitch": 0.0, "head_yaw": 0.0, "head_roll": 0.0,
		"sh_rx": 0.0, "sh_ry": 0.0, "sh_rz": 0.07,
		"el_rx": 0.10, "el_ry": 0.0,
		"wr_rx": 0.0, "wr_rz": 0.0,
		"sh_lx": 0.0, "sh_ly": 0.0, "sh_lz": -0.07,
		"el_lx": 0.10, "el_ly": 0.0,
		"wr_lx": 0.0, "wr_lz": 0.0,
		"th_rx": 0.0, "th_rz": 0.02,
		"kn_rx": 0.0, "an_rx": 0.0,
		"th_lx": 0.0, "th_lz": -0.02,
		"kn_lx": 0.0, "an_lx": 0.0,
	}

func _add_idle(p: Dictionary) -> void:
	var breath := sin(_t * 1.35)
	var sway := sin(_t * 0.62)
	p["hips_y"] = breath * 0.006
	p["torso_pitch"] += breath * 0.012
	p["torso_roll"] = sway * 0.014
	p["head_yaw"] = sin(_t * 0.37 + 1.2) * 0.10
	p["head_pitch"] = sin(_t * 0.53) * 0.025
	p["sh_rx"] += breath * 0.018
	p["sh_lx"] += breath * 0.018
	p["el_rx"] += breath * 0.02
	p["el_lx"] += breath * 0.02
	p["sh_rz"] += sway * 0.008
	p["sh_lz"] -= sway * 0.008

func _add_gait(p: Dictionary) -> void:
	var g: float = clampf(_speed / 4.4, 0.0, 1.35)
	if g <= 0.001:
		return
	var run: float = clampf((_speed - 4.4) / 2.6, 0.0, 1.0)
	var sw := sin(_phase)
	var sw2 := sin(_phase + PI)
	var amp := 0.42 + run * 0.26
	p["th_rx"] += sw * amp * g
	p["th_lx"] += sw2 * amp * g
	p["kn_rx"] -= maxf(0.0, -sin(_phase - 0.35)) * (0.75 + run * 0.35) * g
	p["kn_lx"] -= maxf(0.0, -sin(_phase + PI - 0.35)) * (0.75 + run * 0.35) * g
	p["an_rx"] += (-sw * 0.22 - 0.06) * g
	p["an_lx"] += (-sw2 * 0.22 - 0.06) * g
	p["hips_y"] -= absf(cos(_phase)) * 0.022 * g
	p["hips_roll"] += sin(_phase) * 0.03 * g
	p["hips_yaw"] += sin(_phase) * 0.10 * g
	p["torso_yaw"] -= sin(_phase) * 0.13 * g
	p["torso_pitch"] += (0.06 + run * 0.10) * g
	p["sh_rx"] -= sw * (0.30 + run * 0.22) * g
	p["sh_lx"] -= sw2 * (0.30 + run * 0.22) * g
	p["el_rx"] += 0.16 * g
	p["el_lx"] += 0.16 * g
	p["head_pitch"] -= (0.02 + run * 0.05) * g

func _block_pose(p: Dictionary) -> void:
	p["torso_pitch"] += 0.10
	p["torso_yaw"] += 0.20
	p["hips_y"] -= 0.02
	p["sh_rx"] = 1.10
	p["sh_rz"] = -0.12
	p["el_rx"] = 1.55
	p["wr_rx"] = 0.0
	if _two_handed:
		p["sh_lx"] = 1.00
		p["sh_lz"] = 0.24
		p["el_lx"] = 1.62
	else:
		p["sh_lx"] = 0.35
		p["sh_lz"] = -0.28
		p["el_lx"] = 0.65
	p["th_rx"] += 0.10
	p["th_lx"] -= 0.12
	p["kn_rx"] -= 0.16

func _attack_pose(p: Dictionary) -> void:
	var neutral: Dictionary = p.duplicate()
	var t: float = _attack_t / _attack_len
	var wind: Dictionary
	var strike: Dictionary
	match _variant:
		0:
			wind = _pose({ "torso_yaw": 0.55, "sh_rx": 2.05, "sh_rz": 0.95,
					"el_rx": 0.55, "wr_rx": 0.35, "head_yaw": 0.18,
					"th_rx": 0.10, "kn_rx": -0.10 })
			strike = _pose({ "torso_yaw": -0.62, "sh_rx": 1.30, "sh_rz": -0.85,
					"el_rx": 0.10, "wr_rx": -0.25, "head_yaw": -0.22,
					"hips_yaw": -0.20, "th_rx": 0.22, "kn_rx": -0.16 })
		1:
			wind = _pose({ "torso_yaw": -0.50, "sh_rx": 1.55, "sh_rz": -0.95,
					"el_rx": 1.35, "wr_rx": 0.20, "head_yaw": -0.20,
					"th_lx": 0.12, "kn_lx": -0.12 })
			strike = _pose({ "torso_yaw": 0.60, "sh_rx": 1.95, "sh_rz": 0.95,
					"el_rx": 0.28, "wr_rx": 0.10, "head_yaw": 0.20,
					"hips_yaw": 0.20, "th_lx": 0.18, "kn_lx": -0.14 })
		_:
			wind = _pose({ "torso_pitch": -0.20, "sh_rx": 2.75, "sh_rz": 0.15,
					"el_rx": -0.35, "wr_rx": -0.30, "head_pitch": -0.12,
					"sh_lx": 2.65, "sh_lz": -0.20, "el_lx": -0.30 })
			strike = _pose({ "torso_pitch": 0.38, "sh_rx": 0.65, "sh_rz": 0.05,
					"el_rx": 0.12, "wr_rx": 0.35, "head_pitch": 0.20,
					"sh_lx": 0.60, "sh_lz": 0.18, "el_lx": 0.20,
					"hips_y": -0.05, "th_rx": 0.16, "kn_rx": -0.14 })

	var reach: Dictionary = _pose({ "torso_yaw": -0.28, "head_yaw": -0.18,
			"sh_rx": -0.45, "sh_rz": 0.45, "el_rx": 1.95, "wr_rx": 0.30 })

	var draw_end := 0.22
	var wind_end := 0.42 if _variant == 2 else 0.38
	var hit_end := 0.58 if _variant == 2 else 0.52

	if t < draw_end:
		_blend(p, reach, _ease(t / draw_end))
	elif t < wind_end:
		_blend(p, wind, _ease((t - draw_end) / (wind_end - draw_end)))
	elif t < hit_end:
		_blend(p, strike, _ease((t - wind_end) / (hit_end - wind_end)))
	else:
		var tail: float = (t - hit_end) / maxf(0.01, 1.0 - hit_end)
		_blend(p, neutral, _ease(tail))
	if not _two_handed:
		p["sh_lx"] = neutral["sh_lx"]
		p["sh_ly"] = neutral["sh_ly"]
		p["sh_lz"] = neutral["sh_lz"]
		p["el_lx"] = neutral["el_lx"]
		p["el_ly"] = neutral["el_ly"]

func _pose(values: Dictionary) -> Dictionary:
	var p: Dictionary = _base_pose()
	for key in values:
		p[key] = values[key]
	return p

func _blend(p: Dictionary, target: Dictionary, k: float) -> void:
	for key in p:
		if target.has(key):
			p[key] = lerpf(float(p[key]), float(target[key]), k)

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

# =========================================================================

func _apply(p: Dictionary, delta: float) -> void:
	var hips: Node3D = _rig.get("hips") as Node3D
	if hips != null:
		hips.position.y = _rig.get("hips_y", 1.0) + float(p["hips_y"])
		hips.rotation = Vector3(_rest.get("hips", Vector3.ZERO).x,
				float(p["hips_yaw"]), float(p["hips_roll"]))

	var torso: Node3D = _rig.get("torso") as Node3D
	if torso != null:
		torso.rotation = Vector3(float(p["torso_pitch"]), float(p["torso_yaw"]),
				float(p["torso_roll"]))

	var head: Node3D = _rig.get("head") as Node3D
	if head != null:
		head.rotation = Vector3(float(p["head_pitch"]), float(p["head_yaw"]),
				float(p["head_roll"]))

	_set_rot("shoulder_r", "sh_rx", "sh_ry", "sh_rz", p)
	_set_rot("elbow_r", "el_rx", "el_ry", null, p)
	_set_rot("wrist_r", "wr_rx", null, "wr_rz", p)
	_set_rot("shoulder_l", "sh_lx", "sh_ly", "sh_lz", p)
	_set_rot("elbow_l", "el_lx", "el_ly", null, p)
	_set_rot("wrist_l", "wr_lx", null, "wr_lz", p)
	_set_rot("thigh_r", "th_rx", null, "th_rz", p)
	_set_rot("knee_r", "kn_rx", null, null, p)
	_set_rot("ankle_r", "an_rx", null, null, p)
	_set_rot("thigh_l", "th_lx", null, "th_lz", p)
	_set_rot("knee_l", "kn_lx", null, null, p)
	_set_rot("ankle_l", "an_lx", null, null, p)

	# --- плащ: пружина, ветер и шлейф от движения ---
	# x < 0 — плащ уходит назад (за спину), x > 0 — вперёд, на тело.
	var trail: float = clampf(_speed / 6.0, 0.0, 1.0)
	var wind_local: Vector3 = Vector3.RIGHT
	var hips_node: Node3D = _rig.get("hips") as Node3D
	var model: Node3D = hips_node.get_parent() as Node3D if hips_node != null else null
	if model != null and Wind.strength > 0.01:
		wind_local = model.global_transform.basis.inverse() * Wind.direction
	var wind_amp: float = 0.020 * clampf(Wind.strength, 0.0, 2.0)
	var segs: Array = _rig.get("cape", [])
	for i in range(segs.size()):
		var seg: Node3D = segs[i] as Node3D
		var base: Vector3 = _rest.get("cape_%d" % i, Vector3.ZERO)
		var lag: float = 1.0 - exp(-delta * (3.6 - float(i) * 0.45))
		var flutter: float = sin(_t * 3.4 + float(i) * 1.1) * (0.008 + 0.010 * trail)
		var target_x: float = base.x - trail * (0.24 + 0.15 * float(i))
		target_x += sin(_t * 1.05 + float(i) * 0.8) * wind_amp * (1.0 - trail * 0.45)
		target_x += flutter
		var target_z: float = base.z + sin(_t * 0.72 + float(i) * 0.65) * wind_amp * 0.9
		target_z += wind_local.x * wind_amp * 1.8 * (1.0 + trail * 0.7)
		target_x = clampf(target_x, -1.12, 0.10)
		target_z = clampf(target_z, -0.20, 0.20)
		_cape_rot[i] = _cape_rot[i].lerp(Vector3(target_x, base.y, target_z), lag)
		seg.rotation = _cape_rot[i]

	# --- волосы: мягко отстают, но не накапливают угол ---
	var hairs: Array = _rig.get("hair", [])
	for i in range(hairs.size()):
		var hair: Node3D = hairs[i] as Node3D
		var base_h: Vector3 = _rest.get("hair_%d" % i, Vector3.ZERO)
		var h_amp: float = 0.018 + trail * 0.035
		hair.rotation = Vector3(
				base_h.x - trail * 0.10 + sin(_t * 1.55 + float(i) * 0.8) * h_amp
						+ wind_local.z * wind_amp * 0.6,
				base_h.y,
				base_h.z + sin(_t * 0.82 + float(i)) * 0.014
						+ wind_local.x * wind_amp * 1.2)

	# --- шляпа: чуть отстаёт на бегу, база больше не теряется ---
	var hat: Node3D = _rig.get("hat") as Node3D
	if hat != null:
		var base_hat: Vector3 = _rest.get("hat", Vector3.ZERO)
		hat.rotation = Vector3(
				base_hat.x + sin(_t * 1.1) * 0.006 - trail * 0.035,
				base_hat.y, base_hat.z)

func _set_rot(key: String, rx: String, ry, rz, p: Dictionary) -> void:
	var node: Node3D = _rig.get(key) as Node3D
	if node == null:
		return
	var base: Vector3 = _rest.get(key, Vector3.ZERO)
	node.rotation = Vector3(
			base.x + float(p[rx]),
			base.y + (float(p[ry]) if ry != null else 0.0),
			base.z + (float(p[rz]) if rz != null else 0.0))
