class_name KnightModelV2
extends RefCounted

## Детализированный рыцарь в кольчуге: Primitive-only, всё строится кодом.
##
## Ориентация: лицо смотрит в -Z (как у player.tscn), origin — у ступней.
## Высота ~1.88 м.
##
## build(parent) возвращает Dictionary:
##   "sword_pivot"    : Node3D    — меч в правом кулаке
##   "torch_pivot"    : Node3D    — факел в левом кулаке
##   "torch_flame"    : Node3D    — сфера пламени (visible = false)
##   "torch_light"    : OmniLight3D (light_energy = 0)
##   "torch_particles": CPUParticles3D (emitting = false)
##   "animator"       : Node      — set_locomotion(speed), play_attack()
##
## Узлы скелета: Hips, Torso, Head, ShoulderR/L, ElbowR/L, WristR/L,
## ThighR/L, KneeR/L, AnkleR/L, CapeSeg1..3, SwordPivot, TorchPivot.
##
## Аниматор — внутренний class StackAnimator (Node):
##   set_locomotion(speed)  — 0 = стойка, >0 = ходьба; звать каждый кадр
##   play_attack()          — удар ~1.0 c (замах ~0.35 c, удар ~0.5 c)
## Меч жёстко закреплён в правой кисти: не двигайте sword_pivot отдельно.
## Плащ встроенный (3 сегмента): старый cape.gd при интеграции отключить.

const ATTACK_LENGTH: float = 1.0
const HIPS_HEIGHT: float = 0.96
const TORSO_HEIGHT: float = 0.14
const HEAD_HEIGHT: float = 0.43

# =========================================================================
#  API
# =========================================================================

static func build(parent: Node3D) -> Dictionary:
	var kit: Kit = _make_kit()
	var rig: Dictionary = {}

	# --- таз / юбка / ноги ---
	var hips: Node3D = _pivot(parent, "Hips", Vector3(0.0, HIPS_HEIGHT, 0.0))
	rig["hips"] = hips
	_build_hips(hips, kit)

	var leg_r: Dictionary = _build_leg(hips, 1.0, "R", kit)
	var leg_l: Dictionary = _build_leg(hips, -1.0, "L", kit)
	rig["thigh_r"] = leg_r["thigh"]
	rig["knee_r"] = leg_r["knee"]
	rig["ankle_r"] = leg_r["ankle"]
	rig["thigh_l"] = leg_l["thigh"]
	rig["knee_l"] = leg_l["knee"]
	rig["ankle_l"] = leg_l["ankle"]

	# --- торс ---
	var torso: Node3D = _pivot(hips, "Torso", Vector3(0.0, TORSO_HEIGHT, 0.0))
	rig["torso"] = torso
	_build_torso(torso, kit)

	# --- голова / шлем ---
	var head: Node3D = _pivot(torso, "Head", Vector3(0.0, HEAD_HEIGHT, 0.0))
	rig["head"] = head
	_build_head(head, kit)

	# --- плащ из трёх сегментов ---
	var cape: Array[Node3D] = _build_cape(torso, kit)
	rig["cape"] = cape

	# --- руки ---
	var arm_r: Dictionary = _build_arm(torso, 1.0, true, kit)
	var arm_l: Dictionary = _build_arm(torso, -1.0, false, kit)
	rig["shoulder_r"] = arm_r["shoulder"]
	rig["elbow_r"] = arm_r["elbow"]
	rig["wrist_r"] = arm_r["wrist"]
	rig["shoulder_l"] = arm_l["shoulder"]
	rig["elbow_l"] = arm_l["elbow"]
	rig["wrist_l"] = arm_l["wrist"]

	var sword_pivot: Node3D = arm_r["weapon"] as Node3D
	var torch_pivot: Node3D = arm_l["weapon"] as Node3D
	var flame: MeshInstance3D = arm_l["flame"] as MeshInstance3D
	var light: OmniLight3D = arm_l["light"] as OmniLight3D
	var particles: CPUParticles3D = arm_l["particles"] as CPUParticles3D
	rig["flame"] = flame
	rig["torch"] = torch_pivot

	# --- аниматор ---
	var animator: StackAnimator = StackAnimator.new()
	animator.name = "Animator"
	parent.add_child(animator)
	animator.setup(rig)

	return {
		"sword_pivot": sword_pivot,
		"torch_pivot": torch_pivot,
		"torch_flame": flame,
		"torch_light": light,
		"torch_particles": particles,
		"animator": animator,
	}

# =========================================================================
#  Материалы и палитра
# =========================================================================

class Kit:
	var mail: StandardMaterial3D
	var mail_dark: StandardMaterial3D
	var plate: StandardMaterial3D
	var plate_dark: StandardMaterial3D
	var steel: StandardMaterial3D
	var blade: StandardMaterial3D
	var iron: StandardMaterial3D
	var leather: StandardMaterial3D
	var leather_dark: StandardMaterial3D
	var cloth: StandardMaterial3D
	var cloth_dark: StandardMaterial3D
	var black: StandardMaterial3D
	var wood: StandardMaterial3D
	var flame: StandardMaterial3D

static func _make_kit() -> Kit:
	var kit: Kit = Kit.new()
	var mail_tex: ImageTexture = _mail_texture()

	kit.mail = _mat(Color(0.40, 0.41, 0.44), 0.58, 0.62)
	kit.mail.albedo_texture = mail_tex
	kit.mail.uv1_scale = Vector3(6.0, 6.0, 6.0)
	kit.mail.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	kit.mail_dark = _mat(Color(0.30, 0.31, 0.34), 0.55, 0.68)
	kit.mail_dark.albedo_texture = mail_tex
	kit.mail_dark.uv1_scale = Vector3(7.0, 7.0, 7.0)
	kit.mail_dark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	kit.plate = _mat(Color(0.235, 0.245, 0.265), 0.62, 0.54)
	kit.plate_dark = _mat(Color(0.160, 0.170, 0.190), 0.68, 0.54)
	kit.steel = _mat(Color(0.300, 0.310, 0.340), 0.82, 0.36)
	kit.iron = _mat(Color(0.200, 0.200, 0.220), 0.80, 0.50)

	kit.blade = _mat(Color(0.330, 0.340, 0.370), 0.88, 0.30)
	kit.blade.cull_mode = BaseMaterial3D.CULL_BACK

	kit.leather = _mat(Color(0.075, 0.058, 0.043), 0.04, 0.86)
	kit.leather_dark = _mat(Color(0.042, 0.034, 0.026), 0.0, 0.92)
	kit.cloth = _mat(Color(0.180, 0.132, 0.090), 0.0, 1.0)
	kit.cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.cloth_dark = _mat(Color(0.105, 0.078, 0.055), 0.0, 1.0)
	kit.cloth_dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.black = _mat(Color(0.030, 0.030, 0.034), 0.08, 0.74)
	kit.wood = _mat(Color(0.115, 0.080, 0.052), 0.0, 0.94)

	kit.flame = StandardMaterial3D.new()
	kit.flame.albedo_color = Color(1.0, 0.62, 0.22)
	kit.flame.emission_enabled = true
	kit.flame.emission = Color(1.0, 0.48, 0.10)
	kit.flame.emission_energy_multiplier = 6.0
	kit.flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return kit

static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

## Процедурная "кольчуга": сетка колец, без внешних текстур.
static func _mail_texture() -> ImageTexture:
	var size: int = 64
	var cell: int = 8
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.48, 0.48, 0.52))
	var row: int = 0
	for cy in range(0, size, cell):
		var offset: int = cell / 2 if row % 2 == 1 else 0
		for cx in range(0, size, cell):
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var d: float = sqrt(float(dx * dx + dy * dy))
					if d >= 2.0 and d <= 3.2:
						var px: int = (cx + dx + offset + size) % size
						var py: int = (cy + dy + size) % size
						var shade: float = 0.88 + 0.11 * sin(float(px) * 1.7 + float(py) * 2.3)
						img.set_pixel(px, py, Color(shade, shade, minf(shade * 1.04, 1.0)))
		row += 1
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# =========================================================================
#  Таз, юбка, пояс
# =========================================================================

static func _build_hips(hips: Node3D, kit: Kit) -> void:
	# таз под кольчугой
	_add(hips, _cyl(0.19, 0.205, 0.17, 16), kit.mail, Vector3(0.0, -0.02, 0.0))

	# кольчужная юбка до колен
	_add(hips, _cyl(0.205, 0.278, 0.35, 20), kit.mail, Vector3(0.0, -0.185, 0.0))
	_add(hips, _cyl(0.275, 0.285, 0.055, 20), kit.mail_dark, Vector3(0.0, -0.355, 0.0))
	# тёмная ткань под кольчугой, чтобы не просвечивал низ
	_add(hips, _cyl(0.19, 0.25, 0.30, 16), kit.cloth_dark, Vector3(0.0, -0.22, 0.0))

	# стягивающие ремни юбки
	_add(hips, _cyl(0.234, 0.234, 0.028, 20), kit.leather, Vector3(0.0, -0.12, 0.0))
	_add(hips, _cyl(0.262, 0.262, 0.026, 20), kit.leather, Vector3(0.0, -0.28, 0.0))

	# пояс
	_add(hips, _cyl(0.213, 0.218, 0.062, 20), kit.leather, Vector3(0.0, 0.055, 0.0))
	_add(hips, _box(Vector3(0.078, 0.058, 0.018)), kit.iron, Vector3(0.0, 0.055, -0.213))
	_add(hips, _box(Vector3(0.046, 0.032, 0.012)), kit.leather_dark, Vector3(0.0, 0.055, -0.224))
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		_add(hips, _sphere(0.009, 8, 6), kit.iron,
				Vector3(sin(a) * 0.218, 0.055, -cos(a) * 0.218))

	# подсумок на левом бедре (сбоку, не мешает спереди)
	_add(hips, _box(Vector3(0.078, 0.10, 0.055)), kit.leather,
			Vector3(-0.238, -0.035, 0.012), Vector3(0.0, PI * 0.5, 0.04))
	_add(hips, _box(Vector3(0.082, 0.038, 0.058)), kit.leather_dark,
			Vector3(-0.238, 0.02, 0.012), Vector3(0.0, PI * 0.5, 0.04))
	_add(hips, _box(Vector3(0.018, 0.02, 0.012)), kit.iron,
			Vector3(-0.269, -0.008, 0.012), Vector3(0.0, PI * 0.5, 0.04))

	# стальные пластины-тассеты по кругу
	for i in range(6):
		var a: float = TAU * float(i) / 6.0
		var pivot: Node3D = _pivot(hips, "Tasset%d" % i, Vector3.ZERO, Vector3(0.0, a, 0.0))
		_add(pivot, _box(Vector3(0.092, 0.13, 0.018)), kit.plate_dark,
				Vector3(0.0, -0.10, -0.238), Vector3(-0.14, 0.0, 0.0))
		_add(pivot, _sphere(0.009, 8, 6), kit.iron, Vector3(0.0, -0.04, -0.232))
		_add(pivot, _box(Vector3(0.026, 0.024, 0.012)), kit.leather,
				Vector3(0.0, -0.155, -0.25))

# =========================================================================
#  Ноги
# =========================================================================

static func _build_leg(hips: Node3D, side: float, suffix: String, kit: Kit) -> Dictionary:
	var thigh: Node3D = _pivot(hips, "Thigh" + suffix, Vector3(side * 0.135, -0.02, 0.0))
	# кольчужное бедро
	_add(thigh, _capsule(0.082, 0.43, 12), kit.mail, Vector3(0.0, -0.205, 0.0))
	# набедренная пластина
	_add(thigh, _sphere(0.092, 14, 8), kit.plate, Vector3(0.0, -0.175, -0.055),
			Vector3.ZERO, Vector3(0.82, 1.35, 0.42))
	# ремни
	_add(thigh, _cyl(0.081, 0.081, 0.026, 14), kit.leather, Vector3(0.0, -0.10, 0.0))
	_add(thigh, _cyl(0.079, 0.079, 0.026, 14), kit.leather, Vector3(0.0, -0.31, 0.0))

	var knee: Node3D = _pivot(thigh, "Knee" + suffix, Vector3(0.0, -0.41, 0.0))
	# наколенник
	_add(knee, _sphere(0.077, 14, 8), kit.plate, Vector3(0.0, -0.005, -0.012),
			Vector3.ZERO, Vector3(1.0, 0.85, 1.02))
	_add(knee, _box(Vector3(0.03, 0.075, 0.07)), kit.plate_dark,
			Vector3(side * 0.062, -0.02, 0.0), Vector3(0.0, 0.0, side * 0.18))
	_add(knee, _sphere(0.009, 8, 6), kit.iron, Vector3(0.0, 0.04, -0.07))

	# кольчужная голень
	_add(knee, _capsule(0.070, 0.38, 12), kit.mail, Vector3(0.0, -0.185, 0.0))
	# стальная наголенка
	_add(knee, _box(Vector3(0.093, 0.245, 0.03)), kit.plate, Vector3(0.0, -0.185, -0.062))
	_add(knee, _box(Vector3(0.02, 0.23, 0.012)), kit.plate_dark, Vector3(0.0, -0.185, -0.079))
	_add(knee, _cyl(0.071, 0.071, 0.024, 14), kit.leather, Vector3(0.0, -0.075, 0.0))
	_add(knee, _cyl(0.069, 0.069, 0.024, 14), kit.leather, Vector3(0.0, -0.30, 0.0))

	var ankle: Node3D = _pivot(knee, "Ankle" + suffix, Vector3(0.0, -0.36, 0.0))
	# голенище
	_add(ankle, _cyl(0.082, 0.092, 0.16, 14), kit.black, Vector3(0.0, 0.065, 0.008))
	_add(ankle, _cyl(0.094, 0.094, 0.028, 14), kit.leather, Vector3(0.0, 0.135, 0.008))
	# ступня
	_add(ankle, _box(Vector3(0.105, 0.10, 0.225)), kit.black, Vector3(0.0, -0.095, -0.055))
	_add(ankle, _sphere(0.058, 14, 8), kit.black, Vector3(0.0, -0.108, -0.175),
			Vector3.ZERO, Vector3(0.92, 0.68, 1.15))
	_add(ankle, _box(Vector3(0.10, 0.06, 0.075)), kit.black, Vector3(0.0, -0.112, 0.048))
	# подошва
	_add(ankle, _box(Vector3(0.116, 0.03, 0.285)), kit.leather_dark, Vector3(0.0, -0.155, -0.055))
	# ремни с пряжками
	for i in range(2):
		var y: float = -0.045 - float(i) * 0.052
		_add(ankle, _box(Vector3(0.112, 0.024, 0.16)), kit.leather, Vector3(0.0, y, -0.075))
		_add(ankle, _box(Vector3(0.026, 0.032, 0.014)), kit.iron,
				Vector3(side * 0.052, y, -0.145))
	return {"thigh": thigh, "knee": knee, "ankle": ankle}

# =========================================================================
#  Торс
# =========================================================================

static func _build_torso(torso: Node3D, kit: Kit) -> void:
	# стёганый поддоспешник у пояса
	_add(torso, _cyl(0.178, 0.190, 0.16, 16), kit.cloth_dark, Vector3(0.0, 0.015, 0.0))
	# кольчужный корпус — цилиндр, чтобы нагрудник читался отдельной пластиной
	_add(torso, _cyl(0.186, 0.202, 0.405, 20), kit.mail, Vector3(0.0, 0.205, 0.0))

	# нагрудник — широкий, но не «шар»: вытянут по груди и уплощён
	_add(torso, _sphere(0.15, 22, 12), kit.plate, Vector3(0.0, 0.300, -0.148),
			Vector3.ZERO, Vector3(1.16, 0.70, 0.48))
	# ребро жёсткости
	_add(torso, _box(Vector3(0.022, 0.175, 0.026)), kit.plate_dark,
			Vector3(0.0, 0.305, -0.220), Vector3(0.03, 0.0, 0.0))
	# верхняя кромка нагрудника
	_add(torso, _box(Vector3(0.230, 0.024, 0.026)), kit.plate_dark,
			Vector3(0.0, 0.402, -0.168), Vector3(0.16, 0.0, 0.0))
	# ламели-пластины живота
	for i in range(3):
		var y: float = 0.165 - float(i) * 0.062
		_add(torso, _box(Vector3(0.27 - float(i) * 0.015, 0.058, 0.045)), kit.plate_dark,
				Vector3(0.0, y, -0.185 + float(i) * 0.006),
				Vector3(0.12 + float(i) * 0.04, 0.0, 0.0))
	# заклёпки нагрудника
	for i in range(2):
		var x: float = -0.125 + float(i) * 0.25
		_add(torso, _sphere(0.009, 8, 6), kit.iron, Vector3(x, 0.165, -0.230))

	# спинная пластина
	_add(torso, _sphere(0.145, 16, 8), kit.plate_dark, Vector3(0.0, 0.275, 0.120),
			Vector3.ZERO, Vector3(1.15, 0.95, 0.42))

	# воротник кольчуги
	_add(torso, _cyl(0.098, 0.150, 0.110, 16), kit.mail_dark, Vector3(0.0, 0.400, 0.0))
	_add(torso, _torus(0.090, 0.120, 20, 8), kit.mail, Vector3(0.0, 0.442, 0.0))

	# плечевые ремни (лежат на кольчуге у шеи)
	for side in [-1.0, 1.0]:
		_add(torso, _box(Vector3(0.046, 0.145, 0.024)), kit.leather,
				Vector3(side * 0.140, 0.385, -0.132), Vector3(-0.12, 0.0, side * 0.10))
		_add(torso, _box(Vector3(0.030, 0.026, 0.014)), kit.iron,
				Vector3(side * 0.148, 0.318, -0.148))

	# перевязь через грудь поверх нагрудника
	_add(torso, _box(Vector3(0.056, 0.43, 0.020)), kit.leather,
			Vector3(0.02, 0.215, -0.232), Vector3(0.0, 0.0, -0.52))
	_add(torso, _box(Vector3(0.060, 0.038, 0.024)), kit.iron,
			Vector3(0.112, 0.325, -0.238), Vector3(0.0, 0.0, -0.52))
	_add(torso, _box(Vector3(0.028, 0.065, 0.018)), kit.leather_dark,
			Vector3(0.055, 0.225, -0.243), Vector3(0.0, 0.0, -0.52))

	# застёжки плаща на плечах
	for side in [-1.0, 1.0]:
		_add(torso, _torus(0.018, 0.030, 12, 6), kit.iron,
				Vector3(side * 0.158, 0.402, -0.102), Vector3(PI * 0.5, 0.0, 0.0))
		_add(torso, _sphere(0.010, 8, 6), kit.steel,
				Vector3(side * 0.158, 0.402, -0.102))

	# ножны на спине (пустые)
	var scab: Node3D = _pivot(torso, "Scabbard", Vector3(0.045, 0.16, 0.240),
			Vector3(0.10, 0.0, -0.50))
	_add(scab, _box(Vector3(0.078, 0.80, 0.030)), kit.leather, Vector3.ZERO)
	_add(scab, _box(Vector3(0.088, 0.095, 0.040)), kit.iron, Vector3(0.0, 0.36, 0.0))
	_add(scab, _box(Vector3(0.062, 0.07, 0.034)), kit.iron, Vector3(0.0, -0.345, 0.0))
	_add(scab, _cyl(0.028, 0.002, 0.07, 10), kit.iron, Vector3(0.0, -0.408, 0.0))
	_add(scab, _box(Vector3(0.092, 0.032, 0.042)), kit.leather_dark, Vector3(0.0, 0.20, 0.0))
	_add(scab, _box(Vector3(0.092, 0.032, 0.042)), kit.leather_dark, Vector3(0.0, -0.16, 0.0))
	_add(scab, _box(Vector3(0.024, 0.12, 0.010)), kit.iron, Vector3(0.0, 0.30, -0.022),
			Vector3(0.0, 0.0, 0.06))

# =========================================================================
#  Шлем и голова
# =========================================================================

static func _build_head(head: Node3D, kit: Kit) -> void:
	# шея
	_add(head, _cyl(0.066, 0.076, 0.13, 12), kit.mail_dark, Vector3(0.0, -0.060, 0.0))
	# кольчужный койф (уже лицевой маски, чтобы не лез в лицо)
	_add(head, _cyl(0.132, 0.152, 0.135, 18), kit.mail, Vector3(0.0, -0.005, 0.004))
	# кольчужная пелерина сзади
	_add(head, _box(Vector3(0.215, 0.16, 0.06)), kit.mail_dark,
			Vector3(0.0, -0.020, 0.125), Vector3(0.26, 0.0, 0.0))

	# кожаный подшлемник
	_add(head, _cyl(0.141, 0.148, 0.062, 20), kit.leather, Vector3(0.0, 0.104, 0.0))
	_add(head, _torus(0.128, 0.150, 22, 8), kit.leather_dark, Vector3(0.0, 0.073, 0.0))

	# купол и тулья
	_add(head, _cyl(0.118, 0.137, 0.185, 20), kit.plate, Vector3(0.0, 0.185, 0.0))
	_add(head, _sphere(0.126, 22, 12), kit.plate, Vector3(0.0, 0.262, 0.0),
			Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	_add(head, _torus(0.120, 0.140, 24, 7), kit.plate_dark, Vector3(0.0, 0.240, 0.0))
	_add(head, _torus(0.132, 0.144, 24, 7), kit.plate_dark, Vector3(0.0, 0.100, 0.0))
	_add(head, _cyl(0.018, 0.022, 0.028, 10), kit.iron, Vector3(0.0, 0.342, 0.0))

	# лицевая маска
	_add(head, _box(Vector3(0.200, 0.180, 0.060)), kit.plate,
			Vector3(0.0, 0.128, -0.122), Vector3(0.03, 0.0, 0.0))
	# прорезь для глаз
	_add(head, _box(Vector3(0.186, 0.034, 0.018)), kit.black,
			Vector3(0.0, 0.188, -0.159))
	_add(head, _box(Vector3(0.198, 0.010, 0.020)), kit.plate_dark,
			Vector3(0.0, 0.208, -0.160))
	# наносник
	_add(head, _box(Vector3(0.028, 0.172, 0.032)), kit.plate,
			Vector3(0.0, 0.118, -0.170))
	_add(head, _sphere(0.020, 10, 6), kit.plate_dark, Vector3(0.0, 0.036, -0.163),
			Vector3.ZERO, Vector3(1.0, 0.85, 0.85))
	# бровка
	_add(head, _box(Vector3(0.206, 0.030, 0.026)), kit.plate_dark,
			Vector3(0.0, 0.212, -0.150), Vector3(0.12, 0.0, 0.0))
	# заклёпки у бровки и дыхательные отверстия на маске
	for side in [-1.0, 1.0]:
		_add(head, _sphere(0.0060, 8, 6), kit.iron,
				Vector3(side * 0.086, 0.225, -0.156))
		for i in range(3):
			_add(head, _cyl(0.0045, 0.0045, 0.007, 6), kit.black,
					Vector3(side * (0.060 - float(i) * 0.010), 0.080 - float(i) * 0.012, -0.154),
					Vector3(PI * 0.5, 0.0, 0.0))
	# подбородочная пластина (перекрывает стык маски и койфа)
	_add(head, _box(Vector3(0.160, 0.060, 0.050)), kit.plate_dark,
			Vector3(0.0, 0.052, -0.132), Vector3(-0.05, 0.0, 0.0))

	# заклёпки по обручу
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		_add(head, _sphere(0.007, 8, 6), kit.iron,
				Vector3(sin(a) * 0.141, 0.240, -cos(a) * 0.141))

	# затылочная пластина
	_add(head, _box(Vector3(0.195, 0.070, 0.095)), kit.plate_dark,
			Vector3(0.0, 0.115, 0.112), Vector3(0.32, 0.0, 0.0))

# =========================================================================
#  Плащ из трёх сегментов
# =========================================================================

static func _build_cape(torso: Node3D, kit: Kit) -> Array[Node3D]:
	var segments: Array[Node3D] = []
	var widths: Array[float] = [0.44, 0.50, 0.48]
	var lengths: Array[float] = [0.25, 0.25, 0.23]
	var ragged: Array[float] = [0.014, 0.032, 0.055]
	var parent: Node3D = torso
	var y_offset: float = 0.372
	for i in range(3):
		var seg: Node3D = _pivot(parent, "CapeSeg%d" % (i + 1),
				Vector3(0.0, y_offset if i == 0 else -lengths[i - 1], 0.176 if i == 0 else 0.0),
				Vector3(-0.17 if i == 0 else -0.05, 0.0, 0.0))
		var top_w: float = widths[i]
		var bot_w: float = widths[i] + (0.08 if i < 2 else 0.02)
		# две половины с небольшим расходом внизу — вместо плоского щита
		for side in [-1.0, 1.0]:
			var half: Node3D = Node3D.new()
			half.name = "FoldL" if side < 0.0 else "FoldR"
			half.position = Vector3(side * top_w * 0.245, 0.0, 0.0)
			half.rotation = Vector3(0.0, side * 0.06, side * 0.07)
			seg.add_child(half)
			var panel: ArrayMesh = _cloth_mesh(top_w * 0.49, bot_w * 0.49, lengths[i],
					6, 5, 0.075, 0.040, ragged[i], 0.034)
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = panel
			mi.material_override = kit.cloth if i != 1 else kit.cloth_dark
			half.add_child(mi)
			_add(half, _box(Vector3(bot_w * 0.47, 0.016, 0.020)), kit.cloth_dark,
					Vector3(0.0, -lengths[i] + 0.012, 0.0))
		if i == 0:
			# валик у ворота
			_add(seg, _cyl(0.027, 0.027, 0.415, 10), kit.cloth_dark,
					Vector3(0.0, -0.006, 0.010), Vector3(0.0, 0.0, PI * 0.5))
		segments.append(seg)
		parent = seg
		y_offset = 0.0
	return segments

# =========================================================================
#  Руки
# =========================================================================

static func _build_arm(torso: Node3D, side: float, is_right: bool, kit: Kit) -> Dictionary:
	var suffix: String = "R" if is_right else "L"
	var shoulder: Node3D = _pivot(torso, "Shoulder" + suffix,
			Vector3(side * 0.225, 0.35, 0.0),
			Vector3(0.12, 0.03, 0.10) if is_right else Vector3(0.55, -0.03, -0.20))

	# наплечник: купол + две наклонные ламели
	_add(shoulder, _sphere(0.106, 18, 10), kit.plate, Vector3(side * 0.006, 0.020, 0.0),
			Vector3(0.0, 0.0, side * 0.10), Vector3(1.20, 0.72, 1.08))
	_add(shoulder, _box(Vector3(0.195, 0.046, 0.170)), kit.plate_dark,
			Vector3(side * 0.014, -0.052, 0.0), Vector3(0.0, 0.0, side * 0.26))
	_add(shoulder, _box(Vector3(0.180, 0.040, 0.150)), kit.plate_dark,
			Vector3(side * 0.032, -0.094, 0.0), Vector3(0.0, 0.0, side * 0.38))
	_add(shoulder, _sphere(0.008, 8, 6), kit.iron, Vector3(side * 0.066, 0.080, -0.050))
	_add(shoulder, _cyl(0.062, 0.062, 0.022, 14), kit.leather, Vector3(0.0, -0.118, 0.0))

	# плечо
	_add(shoulder, _capsule(0.058, 0.30, 12), kit.mail, Vector3(0.0, -0.15, 0.0))
	_add(shoulder, _cyl(0.064, 0.06, 0.10, 14), kit.plate, Vector3(0.0, -0.105, 0.0))
	_add(shoulder, _cyl(0.061, 0.061, 0.024, 14), kit.leather, Vector3(0.0, -0.205, 0.0))
	_add(shoulder, _sphere(0.062, 12, 8), kit.mail_dark, Vector3(0.0, -0.275, 0.0))

	var elbow: Node3D = _pivot(shoulder, "Elbow" + suffix, Vector3(0.0, -0.30, 0.0),
			Vector3(0.80 if is_right else 0.95, 0.0, 0.0))
	# наруч / локоть
	_add(elbow, _sphere(0.072, 14, 8), kit.plate, Vector3(0.0, 0.005, -0.008),
			Vector3.ZERO, Vector3(1.0, 0.92, 1.05))
	_add(elbow, _box(Vector3(0.022, 0.09, 0.075)), kit.plate_dark,
			Vector3(side * 0.058, -0.01, 0.0), Vector3(0.0, 0.0, side * 0.2))
	_add(elbow, _sphere(0.009, 8, 6), kit.iron, Vector3(0.0, 0.045, -0.06))

	# предплечье
	_add(elbow, _capsule(0.052, 0.28, 12), kit.mail, Vector3(0.0, -0.14, 0.0))
	_add(elbow, _cyl(0.056, 0.063, 0.17, 14), kit.plate, Vector3(0.0, -0.15, 0.0))
	_add(elbow, _box(Vector3(0.02, 0.15, 0.02)), kit.plate_dark, Vector3(0.0, -0.15, -0.058))
	_add(elbow, _cyl(0.058, 0.058, 0.022, 14), kit.leather, Vector3(0.0, -0.085, 0.0))
	_add(elbow, _cyl(0.056, 0.056, 0.022, 14), kit.leather, Vector3(0.0, -0.235, 0.0))
	_add(elbow, _cyl(0.052, 0.048, 0.035, 14), kit.leather, Vector3(0.0, -0.272, 0.0))

	var wrist: Node3D = _pivot(elbow, "Wrist" + suffix, Vector3(0.0, -0.28, 0.0))
	_build_hand(wrist, side, kit)

	if is_right:
		var sword: Dictionary = _build_sword(wrist, kit)
		return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist,
				"weapon": sword["pivot"]}
	var torch: Dictionary = _build_torch(wrist, kit)
	return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist,
			"weapon": torch["pivot"], "flame": torch["flame"],
			"light": torch["light"], "particles": torch["particles"]}

static func _build_hand(wrist: Node3D, side: float, kit: Kit) -> void:
	# ладонь
	_add(wrist, _box(Vector3(0.078, 0.092, 0.050)), kit.leather_dark, Vector3(0.0, -0.036, 0.036))
	# накладка на тыльную сторону кисти
	_add(wrist, _box(Vector3(0.014, 0.072, 0.05)), kit.plate_dark,
			Vector3(side * 0.042, -0.032, 0.012))
	_add(wrist, _sphere(0.008, 8, 6), kit.iron, Vector3(side * 0.049, -0.005, 0.0))

	# пальцы, обхватывающие рукоять (рукоять проходит по локальной Y)
	for i in range(4):
		var y: float = -0.069 + float(i) * 0.0225
		_add(wrist, _box(Vector3(0.060, 0.020, 0.038)), kit.plate_dark,
				Vector3(0.0, y, -0.023), Vector3(-0.10, 0.0, 0.0))
		_add(wrist, _box(Vector3(0.052, 0.006, 0.014)), kit.leather_dark,
				Vector3(0.0, y - 0.009, -0.038))
	# большой палец
	_add(wrist, _box(Vector3(0.024, 0.05, 0.028)), kit.leather_dark,
			Vector3(side * 0.034, -0.032, -0.024), Vector3(0.0, 0.0, side * 0.5))
	_add(wrist, _sphere(0.012, 8, 6), kit.plate_dark,
			Vector3(side * 0.044, -0.008, -0.032))

# =========================================================================
#  Меч (в правой руке)
# =========================================================================

static func _build_sword(wrist: Node3D, kit: Kit) -> Dictionary:
	var pivot: Node3D = _pivot(wrist, "SwordPivot", Vector3(0.0, -0.035, 0.0))

	# клинок с долом: геометрия генерируется кодом
	var blade_mesh: ArrayMesh = _blade_mesh(0.755, 0.034, 0.0068)
	var blade: MeshInstance3D = MeshInstance3D.new()
	blade.mesh = blade_mesh
	blade.material_override = kit.blade
	blade.position = Vector3(0.0, -0.088, 0.0)
	blade.rotation = Vector3(PI, 0.0, 0.0)
	pivot.add_child(blade)

	# крестовина
	_add(pivot, _box(Vector3(0.226, 0.028, 0.036)), kit.steel, Vector3(0.0, -0.072, 0.0))
	for side in [-1.0, 1.0]:
		_add(pivot, _box(Vector3(0.045, 0.038, 0.042)), kit.steel,
				Vector3(side * 0.118, -0.078, 0.0), Vector3(0.0, 0.0, side * 0.45))
		_add(pivot, _sphere(0.014, 8, 6), kit.steel, Vector3(side * 0.131, -0.09, 0.0))

	# рукоять с обмоткой
	_add(pivot, _cyl(0.0185, 0.0205, 0.205, 12), kit.leather, Vector3(0.0, 0.035, 0.0))
	for i in range(4):
		var y: float = -0.03 + float(i) * 0.032
		_add(pivot, _torus(0.019, 0.0225, 10, 5), kit.leather_dark, Vector3(0.0, y, 0.0),
				Vector3(PI * 0.5, 0.0, 0.0))
	# навершие
	_add(pivot, _sphere(0.036, 12, 8), kit.steel, Vector3(0.0, 0.152, 0.0),
			Vector3.ZERO, Vector3(1.0, 0.92, 1.0))
	_add(pivot, _cyl(0.026, 0.032, 0.018, 12), kit.plate_dark, Vector3(0.0, 0.172, 0.0))
	_add(pivot, _sphere(0.008, 8, 6), kit.iron, Vector3(0.0, 0.192, 0.0))

	return {"pivot": pivot}

## Клинок: профиль с долом, сужение к острию. Длина идёт по +Y (потом меш перевёрнут).
static func _blade_mesh(length: float, half_width: float, half_thick: float) -> ArrayMesh:
	var profile: Array[Vector2] = [
		Vector2(-1.0, 0.0), Vector2(-0.55, -1.0), Vector2(0.0, -0.62), Vector2(0.55, -1.0),
		Vector2(1.0, 0.0), Vector2(0.55, 1.0), Vector2(0.0, 0.62), Vector2(-0.55, 1.0),
	]
	var ts: Array[float] = [0.0, 0.50, 0.70, 0.85, 0.96, 1.0]
	var ws: Array[float] = [1.0, 0.96, 0.88, 0.62, 0.26, 0.012]
	var hs: Array[float] = [1.0, 0.96, 0.90, 0.68, 0.30, 0.012]

	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for r in range(ts.size()):
		var ring: PackedVector3Array = PackedVector3Array()
		var nring: PackedVector3Array = PackedVector3Array()
		for j in range(profile.size()):
			var p: Vector2 = profile[j]
			ring.append(Vector3(p.x * half_width * ws[r], ts[r] * length,
					p.y * half_thick * hs[r]))
			var prev_p: Vector2 = profile[(j + profile.size() - 1) % profile.size()]
			var next_p: Vector2 = profile[(j + 1) % profile.size()]
			var tan: Vector2 = (next_p - prev_p).normalized()
			var n2: Vector2 = Vector2(-tan.y, tan.x)
			if n2.dot(p) < 0.0:
				n2 = -n2
			nring.append(Vector3(n2.x, 0.0, n2.y).normalized())
		rings.append(ring)
		normals.append(nring)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings.size() - 1):
		for j in range(profile.size()):
			var j2: int = (j + 1) % profile.size()
			var a: Vector3 = rings[r][j]
			var ap: Vector3 = rings[r][j2]
			var b: Vector3 = rings[r + 1][j]
			var bp: Vector3 = rings[r + 1][j2]
			_vert(st, bp, normals[r + 1][j2])
			_vert(st, b, normals[r + 1][j])
			_vert(st, a, normals[r][j])
			_vert(st, bp, normals[r + 1][j2])
			_vert(st, a, normals[r][j])
			_vert(st, ap, normals[r][j2])
	var mesh: ArrayMesh = st.commit()
	return mesh

# =========================================================================
#  Факел (в левой руке)
# =========================================================================

static func _build_torch(wrist: Node3D, kit: Kit) -> Dictionary:
	var pivot: Node3D = _pivot(wrist, "TorchPivot", Vector3(0.0, -0.035, 0.0),
			Vector3(-1.55, 0.0, 0.20))
	# древко
	_add(pivot, _cyl(0.020, 0.024, 0.62, 12), kit.wood, Vector3(0.0, 0.22, 0.0))
	# обмотка
	for i in range(4):
		_add(pivot, _torus(0.021, 0.027, 10, 5), kit.leather_dark,
				Vector3(0.0, 0.30 + float(i) * 0.045, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	_add(pivot, _cyl(0.028, 0.028, 0.03, 12), kit.iron, Vector3(0.0, 0.505, 0.0))
	# просмоленная голова
	_add(pivot, _cyl(0.036, 0.048, 0.11, 12), kit.cloth_dark, Vector3(0.0, 0.560, 0.0))
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0
		_add(pivot, _box(Vector3(0.058, 0.020, 0.012)), kit.cloth_dark,
				Vector3(sin(ang) * 0.012, 0.545 + float(i) * 0.028, cos(ang) * 0.012),
				Vector3(0.0, ang, 0.18))
	_add(pivot, _cyl(0.028, 0.040, 0.032, 12), kit.iron, Vector3(0.0, 0.505, 0.0))

	var flame: MeshInstance3D = MeshInstance3D.new()
	var flame_mesh: SphereMesh = SphereMesh.new()
	flame_mesh.radius = 0.065
	flame_mesh.height = 0.16
	flame_mesh.radial_segments = 12
	flame_mesh.rings = 6
	flame.mesh = flame_mesh
	flame.material_override = kit.flame
	flame.position = Vector3(0.0, 0.645, 0.0)
	flame.visible = false
	pivot.add_child(flame)

	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(0.0, 0.665, 0.0)
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 0.0
	light.omni_range = 10.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	pivot.add_child(light)

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.position = Vector3(0.0, 0.665, 0.0)
	particles.amount = 26
	particles.lifetime = 0.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.04
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 16.0
	particles.gravity = Vector3(0, 1.1, 0)
	particles.initial_velocity_min = 0.12
	particles.initial_velocity_max = 0.4
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 0.9
	particles.color = Color(1.0, 0.55, 0.16, 0.85)
	particles.emitting = false
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	particles.mesh = quad
	var pmat: StandardMaterial3D = StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pmat.vertex_color_use_as_albedo = true
	pmat.albedo_color = Color(1.0, 0.6, 0.2, 0.9)
	pmat.albedo_texture = _soft_particle_texture()
	particles.material_override = pmat
	pivot.add_child(particles)

	return {"pivot": pivot, "flame": flame, "light": light, "particles": particles}

# =========================================================================
#  Процедурные меши
# =========================================================================

## Полотнище плаща: изогнутая сетка, рваный низ, складки.
static func _cloth_mesh(top_width: float, bottom_width: float, length: float,
		cols: int, rows: int, curve: float, wrinkle: float, ragged: float,
		top_drop: float = 0.0) -> ArrayMesh:
	var grid: Array[PackedVector3Array] = []
	for j in range(rows + 1):
		var v: float = float(j) / float(rows)
		var row: PackedVector3Array = PackedVector3Array()
		for i in range(cols + 1):
			var u: float = float(i) / float(cols) - 0.5
			var w: float = lerpf(top_width, bottom_width, v)
			var x: float = u * w
			var z: float = -curve * (u * 2.0) * (u * 2.0) \
					+ sin(u * PI * 3.0 + v * 2.2) * wrinkle * v
			var y: float = -v * length
			y += (u * 2.0) * (u * 2.0) * top_drop * (1.0 - v)
			if j == rows and ragged > 0.0:
				y -= absf(sin(u * PI * 3.5 + 0.7)) * ragged
			row.append(Vector3(x, y, z))
		grid.append(row)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(rows):
		for i in range(cols):
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			var na: Vector3 = _grid_normal(grid, i, j, cols, rows)
			var nb: Vector3 = _grid_normal(grid, i + 1, j, cols, rows)
			var nc: Vector3 = _grid_normal(grid, i + 1, j + 1, cols, rows)
			var nd: Vector3 = _grid_normal(grid, i, j + 1, cols, rows)
			_vert(st, a, na)
			_vert(st, b, nb)
			_vert(st, c, nc)
			_vert(st, a, na)
			_vert(st, c, nc)
			_vert(st, d, nd)
	var mesh: ArrayMesh = st.commit()
	return mesh

static func _grid_normal(grid: Array, i: int, j: int, cols: int, rows: int) -> Vector3:
	var left: Vector3 = grid[j][maxi(i - 1, 0)]
	var right: Vector3 = grid[j][mini(i + 1, cols)]
	var up: Vector3 = grid[maxi(j - 1, 0)][i]
	var down: Vector3 = grid[mini(j + 1, rows)][i]
	var n: Vector3 = (down - up).cross(right - left).normalized()
	if n.z < 0.0:
		n = -n
	if n.length_squared() < 0.25:
		n = Vector3(0.0, 0.0, 1.0)
	return n

static func _vert(st: SurfaceTool, v: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(v)

# =========================================================================
#  Хелперы
# =========================================================================

static func _pivot(parent: Node3D, node_name: String, pos: Vector3,
		rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	return n

static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func _box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m

static func _cyl(top: float, bottom: float, height: float, segments: int = 16) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m

static func _sphere(radius: float, segments: int = 16, rings: int = 8) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return m

static func _capsule(radius: float, height: float, segments: int = 12) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 6
	return m

static func _torus(inner: float, outer: float, rings: int = 16, segments: int = 6) -> TorusMesh:
	var m: TorusMesh = TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = segments
	return m

static func _soft_particle_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex

# =========================================================================
#  Аниматор: стойка, ходьба, удар
# =========================================================================

class StackAnimator extends Node:
	var _hips: Node3D
	var _torso: Node3D
	var _head: Node3D
	var _shoulder_r: Node3D
	var _elbow_r: Node3D
	var _wrist_r: Node3D
	var _shoulder_l: Node3D
	var _elbow_l: Node3D
	var _wrist_l: Node3D
	var _thigh_r: Node3D
	var _knee_r: Node3D
	var _ankle_r: Node3D
	var _thigh_l: Node3D
	var _knee_l: Node3D
	var _ankle_l: Node3D
	var _torch: Node3D
	var _flame: Node3D
	var _cape: Array[Node3D] = []
	var _cape_rest: Array[Vector3] = []
	var _rest: Dictionary = {}
	var _frames: Array[Dictionary] = []
	var _frames_chop: Array[Dictionary] = []
	var _frames_thrust: Array[Dictionary] = []

	var _time: float = 0.0
	var _idle_time: float = 0.0
	var _speed: float = 0.0
	var _target_speed: float = 0.0
	var _phase: float = 0.0
	var _attacking: bool = false
	var _attack_time: float = 0.0
	var _mirror: bool = false
	var _ik_ready: bool = false
	var _ankle_offset: float = 0.10
	var _block: bool = false
	var _two_handed: bool = true

	func setup(rig: Dictionary) -> void:
		_hips = rig.get("hips") as Node3D
		_torso = rig.get("torso") as Node3D
		_head = rig.get("head") as Node3D
		_shoulder_r = rig.get("shoulder_r") as Node3D
		_elbow_r = rig.get("elbow_r") as Node3D
		_wrist_r = rig.get("wrist_r") as Node3D
		_shoulder_l = rig.get("shoulder_l") as Node3D
		_elbow_l = rig.get("elbow_l") as Node3D
		_wrist_l = rig.get("wrist_l") as Node3D
		_thigh_r = rig.get("thigh_r") as Node3D
		_knee_r = rig.get("knee_r") as Node3D
		_ankle_r = rig.get("ankle_r") as Node3D
		_thigh_l = rig.get("thigh_l") as Node3D
		_knee_l = rig.get("knee_l") as Node3D
		_ankle_l = rig.get("ankle_l") as Node3D
		_torch = rig.get("torch") as Node3D
		_flame = rig.get("flame") as Node3D

		if _hips == null or _torso == null or _shoulder_r == null:
			push_warning("KnightModelV2: rig неполный, аниматор отключён")
			set_process(false)
			return

		_rest["hips_pos"] = _hips.position
		_rest["hips"] = _hips.rotation
		_rest["torso"] = _torso.rotation
		_rest["head"] = _head.rotation
		_rest["sh_r"] = _shoulder_r.rotation
		_rest["el_r"] = _elbow_r.rotation
		_rest["wr_r"] = _wrist_r.rotation
		_rest["sh_l"] = _shoulder_l.rotation
		_rest["el_l"] = _elbow_l.rotation
		_rest["wr_l"] = _wrist_l.rotation
		_rest["thigh_r"] = _thigh_r.rotation
		_rest["knee_r"] = _knee_r.rotation
		_rest["ankle_r"] = _ankle_r.rotation
		_rest["thigh_l"] = _thigh_l.rotation
		_rest["knee_l"] = _knee_l.rotation
		_rest["ankle_l"] = _ankle_l.rotation

		var cape_list: Array = rig.get("cape", [])
		for item in cape_list:
			var n: Node3D = item as Node3D
			if n != null:
				_cape.append(n)
				_cape_rest.append(n.rotation)

		_build_attack_frames()

	# --- публичное API ---

	func set_locomotion(speed: float) -> void:
		_target_speed = clampf(speed, 0.0, 9.0)

	func play_attack(variant: int = 0) -> void:
		_attacking = true
		_attack_time = 0.0
		_mirror = variant == 2
		_frames = _frames_chop

	func set_block(active: bool) -> void:
		_block = active

	func set_two_handed(active: bool) -> void:
		_two_handed = active

	func _foot_hit(pos: Vector3) -> Dictionary:
		if _hips == null:
			return {}
		var space: PhysicsDirectSpaceState3D = _hips.get_world_3d().direct_space_state
		if space == null:
			return {}
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.8, pos + Vector3.DOWN * 0.7, 1)
		return space.intersect_ray(query)

	func _apply_ground_snap() -> void:
		if _ankle_r == null or _ankle_l == null or _hips == null:
			return
		if not _ik_ready:
			_ankle_offset = 0.11
			_ik_ready = true

		var hit_r := _foot_hit(_ankle_r.global_position)
		var hit_l := _foot_hit(_ankle_l.global_position)
		if hit_r.is_empty() and hit_l.is_empty():
			return

		var err_r: float = 999.0
		var err_l: float = 999.0
		if not hit_r.is_empty():
			err_r = _ankle_r.global_position.y - ((hit_r["position"] as Vector3).y + _ankle_offset)
		if not hit_l.is_empty():
			err_l = _ankle_l.global_position.y - ((hit_l["position"] as Vector3).y + _ankle_offset)

		var err := minf(err_r, err_l)
		if absf(err) < 0.01 or err > 900.0:
			pass
		else:
			_hips.position.y -= clampf(err, -0.28, 0.28) * 0.85

		if not hit_r.is_empty():
			var n: Vector3 = hit_r["normal"]
			_ankle_r.rotation.x += clampf(atan2(n.z, n.y), -0.5, 0.5) * 0.6
		if not hit_l.is_empty():
			var n2: Vector3 = hit_l["normal"]
			_ankle_l.rotation.x += clampf(atan2(n2.z, n2.y), -0.5, 0.5) * 0.6


	# --- кадры удара ---

	func _build_attack_frames() -> void:
		_build_thrust()
		_build_chop()
		_frames = _frames_chop

	func _build_chop() -> void:
		# Рубящий сверху: меч уходит над головой и падает вниз перед собой.
		_frames_chop = [
			{
				"t": 0.0,
				"sh_r": Vector3.ZERO, "el_r": Vector3.ZERO, "wr_r": Vector3.ZERO,
				"sh_l": Vector3.ZERO, "el_l": Vector3.ZERO, "wr_l": Vector3.ZERO,
				"torso": Vector3.ZERO, "head": Vector3.ZERO,
				"hips_rot": Vector3.ZERO, "hips_pos": Vector3.ZERO,
				"thigh_r": Vector3.ZERO, "knee_r": Vector3.ZERO, "ankle_r": Vector3.ZERO,
				"thigh_l": Vector3.ZERO, "knee_l": Vector3.ZERO, "ankle_l": Vector3.ZERO,
			},
			{
				"t": 0.20,
				"sh_r": Vector3(-2.05, 0.06, -0.10),
				"el_r": Vector3(-0.60, 0.0, 0.0),
				"wr_r": Vector3(0.55, 0.0, 0.0),
				"sh_l": Vector3(-0.30, -0.10, -0.10),
				"el_l": Vector3(-0.35, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(-0.18, 0.12, 0.02),
				"head": Vector3(-0.12, -0.05, 0.0),
				"hips_rot": Vector3(0.0, 0.06, 0.0),
				"hips_pos": Vector3(0.0, -0.02, 0.04),
				"thigh_r": Vector3(0.10, 0.0, 0.0), "knee_r": Vector3(-0.12, 0.0, 0.0), "ankle_r": Vector3(0.0, 0.0, 0.0),
				"thigh_l": Vector3(-0.14, 0.0, 0.0), "knee_l": Vector3(-0.18, 0.0, 0.0), "ankle_l": Vector3(0.06, 0.0, 0.0),
			},
			{
				"t": 0.32,
				"sh_r": Vector3(-2.20, 0.08, -0.12),
				"el_r": Vector3(-0.75, 0.0, 0.0),
				"wr_r": Vector3(0.70, 0.0, 0.0),
				"sh_l": Vector3(-0.36, -0.12, -0.12),
				"el_l": Vector3(-0.45, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(-0.24, 0.16, 0.03),
				"head": Vector3(-0.16, -0.06, 0.0),
				"hips_rot": Vector3(0.0, 0.08, 0.0),
				"hips_pos": Vector3(0.0, -0.03, 0.05),
				"thigh_r": Vector3(0.12, 0.0, 0.0), "knee_r": Vector3(-0.14, 0.0, 0.0), "ankle_r": Vector3(0.0, 0.0, 0.0),
				"thigh_l": Vector3(-0.16, 0.0, 0.0), "knee_l": Vector3(-0.20, 0.0, 0.0), "ankle_l": Vector3(0.08, 0.0, 0.0),
			},
			{
				"t": 0.46,
				"sh_r": Vector3(1.05, 0.04, 0.0),
				"el_r": Vector3(-0.18, 0.0, 0.0),
				"wr_r": Vector3(-0.85, 0.0, 0.0),
				"sh_l": Vector3(-0.10, 0.0, 0.06),
				"el_l": Vector3(0.10, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(0.34, -0.06, -0.02),
				"head": Vector3(0.16, 0.04, 0.0),
				"hips_rot": Vector3(0.0, -0.05, 0.0),
				"hips_pos": Vector3(0.0, -0.06, -0.12),
				"thigh_r": Vector3(0.52, 0.0, 0.0), "knee_r": Vector3(-0.34, 0.0, 0.0), "ankle_r": Vector3(0.12, 0.0, 0.0),
				"thigh_l": Vector3(-0.32, 0.0, 0.0), "knee_l": Vector3(-0.16, 0.0, 0.0), "ankle_l": Vector3(-0.06, 0.0, 0.0),
			},
			{
				"t": 0.58,
				"sh_r": Vector3(1.40, 0.06, 0.02),
				"el_r": Vector3(-0.10, 0.0, 0.0),
				"wr_r": Vector3(-1.00, 0.0, 0.0),
				"sh_l": Vector3(-0.06, 0.0, 0.04),
				"el_l": Vector3(0.08, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(0.42, -0.08, -0.03),
				"head": Vector3(0.20, 0.05, 0.0),
				"hips_rot": Vector3(0.0, -0.04, 0.0),
				"hips_pos": Vector3(0.0, -0.07, -0.13),
				"thigh_r": Vector3(0.50, 0.0, 0.0), "knee_r": Vector3(-0.30, 0.0, 0.0), "ankle_r": Vector3(0.10, 0.0, 0.0),
				"thigh_l": Vector3(-0.30, 0.0, 0.0), "knee_l": Vector3(-0.14, 0.0, 0.0), "ankle_l": Vector3(-0.04, 0.0, 0.0),
			},
			{
				"t": 0.80,
				"sh_r": Vector3(0.40, 0.02, 0.0),
				"el_r": Vector3(-0.06, 0.0, 0.0),
				"wr_r": Vector3(-0.30, 0.0, 0.0),
				"sh_l": Vector3(-0.02, 0.0, 0.01),
				"el_l": Vector3(0.04, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(0.14, -0.03, -0.01),
				"head": Vector3(0.07, 0.02, 0.0),
				"hips_rot": Vector3(0.0, -0.01, 0.0),
				"hips_pos": Vector3(0.0, -0.02, -0.04),
				"thigh_r": Vector3(0.18, 0.0, 0.0), "knee_r": Vector3(-0.10, 0.0, 0.0), "ankle_r": Vector3(0.04, 0.0, 0.0),
				"thigh_l": Vector3(-0.10, 0.0, 0.0), "knee_l": Vector3(-0.06, 0.0, 0.0), "ankle_l": Vector3(0.0, 0.0, 0.0),
			},
			{
				"t": 1.0,
				"sh_r": Vector3.ZERO, "el_r": Vector3.ZERO, "wr_r": Vector3.ZERO,
				"sh_l": Vector3.ZERO, "el_l": Vector3.ZERO, "wr_l": Vector3.ZERO,
				"torso": Vector3.ZERO, "head": Vector3.ZERO,
				"hips_rot": Vector3.ZERO, "hips_pos": Vector3.ZERO,
				"thigh_r": Vector3.ZERO, "knee_r": Vector3.ZERO, "ankle_r": Vector3.ZERO,
				"thigh_l": Vector3.ZERO, "knee_l": Vector3.ZERO, "ankle_l": Vector3.ZERO,
			},
		]

	func _build_thrust() -> void:
		# Смещения относительно позы покоя. Прежний удар с шагом вперёд правой ногой.
		_frames_thrust = [
			{
				"t": 0.0,
				"sh_r": Vector3.ZERO, "el_r": Vector3.ZERO, "wr_r": Vector3.ZERO,
				"sh_l": Vector3.ZERO, "el_l": Vector3.ZERO, "wr_l": Vector3.ZERO,
				"torso": Vector3.ZERO, "head": Vector3.ZERO,
				"hips_rot": Vector3.ZERO, "hips_pos": Vector3.ZERO,
				"thigh_r": Vector3.ZERO, "knee_r": Vector3.ZERO, "ankle_r": Vector3.ZERO,
				"thigh_l": Vector3.ZERO, "knee_l": Vector3.ZERO, "ankle_l": Vector3.ZERO,
			},
			{
				"t": 0.24,
				"sh_r": Vector3(-2.30, -0.26, 0.06),
				"el_r": Vector3(-0.95, 0.0, 0.0),
				"wr_r": Vector3(0.24, 0.0, 0.0),
				"sh_l": Vector3(-0.16, 0.03, 0.05),
				"el_l": Vector3(0.08, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(-0.06, -0.36, 0.04),
				"head": Vector3(-0.02, 0.30, 0.0),
				"hips_rot": Vector3(0.0, -0.13, 0.0),
				"hips_pos": Vector3(0.0, -0.02, 0.06),
				"thigh_r": Vector3(-0.16, 0.0, 0.0), "knee_r": Vector3(-0.26, 0.0, 0.0), "ankle_r": Vector3(0.10, 0.0, 0.0),
				"thigh_l": Vector3(0.12, 0.0, 0.0), "knee_l": Vector3(-0.12, 0.0, 0.0), "ankle_l": Vector3(0.0, 0.0, 0.0),
			},
			{
				"t": 0.34,
				"sh_r": Vector3(-2.42, -0.30, 0.08),
				"el_r": Vector3(-1.02, 0.0, 0.0),
				"wr_r": Vector3(0.28, 0.0, 0.0),
				"sh_l": Vector3(-0.20, 0.03, 0.06),
				"el_l": Vector3(0.10, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(-0.09, -0.42, 0.05),
				"head": Vector3(-0.03, 0.34, 0.0),
				"hips_rot": Vector3(0.0, -0.15, 0.0),
				"hips_pos": Vector3(0.0, -0.03, 0.07),
				"thigh_r": Vector3(-0.20, 0.0, 0.0), "knee_r": Vector3(-0.30, 0.0, 0.0), "ankle_r": Vector3(0.12, 0.0, 0.0),
				"thigh_l": Vector3(0.15, 0.0, 0.0), "knee_l": Vector3(-0.14, 0.0, 0.0), "ankle_l": Vector3(0.0, 0.0, 0.0),
			},
			{
				"t": 0.48,
				"sh_r": Vector3(0.85, 0.26, -0.10),
				"el_r": Vector3(-0.38, 0.0, 0.0),
				"wr_r": Vector3(-0.55, 0.0, 0.0),
				"sh_l": Vector3(-0.06, 0.0, 0.04),
				"el_l": Vector3(0.12, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(0.26, 0.34, -0.05),
				"head": Vector3(0.12, -0.16, 0.0),
				"hips_rot": Vector3(0.0, 0.15, -0.02),
				"hips_pos": Vector3(0.0, -0.05, -0.12),
				"thigh_r": Vector3(0.55, 0.0, 0.0), "knee_r": Vector3(-0.36, 0.0, 0.0), "ankle_r": Vector3(0.12, 0.0, 0.0),
				"thigh_l": Vector3(-0.34, 0.0, 0.0), "knee_l": Vector3(-0.16, 0.0, 0.0), "ankle_l": Vector3(-0.06, 0.0, 0.0),
			},
			{
				"t": 0.62,
				"sh_r": Vector3(0.52, 0.46, -0.16),
				"el_r": Vector3(-0.30, 0.0, 0.0),
				"wr_r": Vector3(-0.42, 0.0, 0.0),
				"sh_l": Vector3(-0.04, 0.0, 0.03),
				"el_l": Vector3(0.08, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(0.31, 0.43, -0.06),
				"head": Vector3(0.15, -0.20, 0.0),
				"hips_rot": Vector3(0.0, 0.13, -0.02),
				"hips_pos": Vector3(0.0, -0.06, -0.14),
				"thigh_r": Vector3(0.50, 0.0, 0.0), "knee_r": Vector3(-0.30, 0.0, 0.0), "ankle_r": Vector3(0.10, 0.0, 0.0),
				"thigh_l": Vector3(-0.30, 0.0, 0.0), "knee_l": Vector3(-0.14, 0.0, 0.0), "ankle_l": Vector3(-0.04, 0.0, 0.0),
			},
			{
				"t": 0.82,
				"sh_r": Vector3(0.16, 0.16, -0.05),
				"el_r": Vector3(-0.12, 0.0, 0.0),
				"wr_r": Vector3(-0.14, 0.0, 0.0),
				"sh_l": Vector3(-0.02, 0.0, 0.01),
				"el_l": Vector3(0.04, 0.0, 0.0),
				"wr_l": Vector3.ZERO,
				"torso": Vector3(0.10, 0.14, -0.02),
				"head": Vector3(0.05, -0.07, 0.0),
				"hips_rot": Vector3(0.0, 0.05, 0.0),
				"hips_pos": Vector3(0.0, -0.02, -0.04),
				"thigh_r": Vector3(0.18, 0.0, 0.0), "knee_r": Vector3(-0.10, 0.0, 0.0), "ankle_r": Vector3(0.04, 0.0, 0.0),
				"thigh_l": Vector3(-0.10, 0.0, 0.0), "knee_l": Vector3(-0.06, 0.0, 0.0), "ankle_l": Vector3(0.0, 0.0, 0.0),
			},
			{
				"t": 1.0,
				"sh_r": Vector3.ZERO, "el_r": Vector3.ZERO, "wr_r": Vector3.ZERO,
				"sh_l": Vector3.ZERO, "el_l": Vector3.ZERO, "wr_l": Vector3.ZERO,
				"torso": Vector3.ZERO, "head": Vector3.ZERO,
				"hips_rot": Vector3.ZERO, "hips_pos": Vector3.ZERO,
				"thigh_r": Vector3.ZERO, "knee_r": Vector3.ZERO, "ankle_r": Vector3.ZERO,
				"thigh_l": Vector3.ZERO, "knee_l": Vector3.ZERO, "ankle_l": Vector3.ZERO,
			},
		]

	func _pose_at(t: float) -> Dictionary:
		if _frames.is_empty():
			return {}
		if t <= (_frames[0]["t"] as float):
			return _frames[0]
		for i in range(1, _frames.size()):
			var f0: Dictionary = _frames[i - 1]
			var f1: Dictionary = _frames[i]
			var t0: float = f0["t"] as float
			var t1: float = f1["t"] as float
			if t <= t1:
				var u: float = clampf((t - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
				u = u * u * (3.0 - 2.0 * u)
				var out: Dictionary = {}
				for key in f0.keys():
					if key == "t":
						continue
					out[key] = (f0[key] as Vector3).lerp(f1[key] as Vector3, u)
				return out
		return _frames[_frames.size() - 1]

	func _rv(key: String) -> Vector3:
		return _rest[key] as Vector3

	# --- кадр ---

	func _process(delta: float) -> void:
		_time += delta
		_idle_time += delta

		if _hips == null:
			return

		_speed = lerpf(_speed, _target_speed, clampf(delta * 8.0, 0.0, 1.0))
		var norm_speed: float = clampf(_speed / 4.4, 0.0, 1.5)
		var walk_w: float = clampf(_speed / 0.6, 0.0, 1.0)
		var amp: float = clampf(_speed / 4.4, 0.0, 1.15)
		_phase = fmod(_phase + delta * (1.2 + 7.0 * minf(norm_speed, 1.3)), TAU)

		var breathe: float = sin(_idle_time * 1.7)
		var idle_w: float = 1.0 - walk_w

		# --- корпус ---
		_hips.position = _rv("hips_pos") + Vector3(
				sin(_phase) * 0.012 * amp * walk_w,
				(sin(_phase * 2.0) * 0.5 + 0.5) * 0.022 * amp * walk_w
						+ breathe * 0.004 * idle_w,
				0.0)
		_hips.rotation = _rv("hips") + Vector3(
				0.0,
				sin(_phase) * 0.035 * amp * walk_w,
				sin(_phase) * 0.022 * amp * walk_w)

		_torso.rotation = _rv("torso") + Vector3(
				breathe * 0.012 * idle_w + sin(_phase * 2.0) * 0.012 * amp * walk_w,
				sin(_phase) * 0.06 * amp * walk_w,
				-sin(_phase) * 0.03 * amp * walk_w)
		_head.rotation = _rv("head") + Vector3(
				sin(_idle_time * 1.7 + 0.4) * 0.010 * idle_w,
				sin(_idle_time * 0.31) * 0.055 * idle_w - sin(_phase) * 0.035 * amp * walk_w,
				sin(_idle_time * 0.47) * 0.012 * idle_w)

		# --- ноги ---
		var leg: float = 0.55 * amp * walk_w
		var thigh_r_d: float = sin(_phase) * leg
		var thigh_l_d: float = sin(_phase + PI) * leg
		var lift_r: float = maxf(0.0, sin(_phase + 0.6))
		var lift_l: float = maxf(0.0, sin(_phase + PI + 0.6))
		var knee_amt: float = 0.95 * amp * walk_w
		var knee_r_d: float = -0.05 - lift_r * knee_amt
		var knee_l_d: float = -0.05 - lift_l * knee_amt

		_thigh_r.rotation = _rv("thigh_r") + Vector3(thigh_r_d, 0.0, 0.0)
		_thigh_l.rotation = _rv("thigh_l") + Vector3(thigh_l_d, 0.0, 0.0)
		_knee_r.rotation = _rv("knee_r") + Vector3(knee_r_d, 0.0, 0.0)
		_knee_l.rotation = _rv("knee_l") + Vector3(knee_l_d, 0.0, 0.0)
		_ankle_r.rotation = _rv("ankle_r") + Vector3(-(thigh_r_d + knee_r_d) * 0.35, 0.0, 0.0)
		_ankle_l.rotation = _rv("ankle_l") + Vector3(-(thigh_l_d + knee_l_d) * 0.35, 0.0, 0.0)

		# --- руки: свободная (левая) в противофазе ногам ---
		var arm_swing: float = -sin(_phase) * 0.26 * amp * walk_w
		_shoulder_l.rotation = _rv("sh_l") + Vector3(
				arm_swing, 0.0, sin(_phase * 2.0) * 0.012 * amp * walk_w)
		_elbow_l.rotation = _rv("el_l") + Vector3(
				maxf(0.0, sin(_phase + PI * 0.5)) * 0.10 * amp * walk_w, 0.0, 0.0)
		_wrist_l.rotation = _rv("wr_l")
		_shoulder_r.rotation = _rv("sh_r") + Vector3(
				sin(_phase) * 0.09 * amp * walk_w, 0.0,
				sin(_phase * 2.0) * 0.008 * amp * walk_w)
		_elbow_r.rotation = _rv("el_r")
		_wrist_r.rotation = _rv("wr_r")

		# --- foot IK: стопы ищут землю ---
		_apply_ground_snap()

		# --- удар поверх локомоции ---
		if _attacking:
			_attack_time += delta
			var t: float = _attack_time / ATTACK_LENGTH
			if t >= 1.0:
				_attacking = false
				t = 1.0
			var w: float = clampf(minf(_attack_time / 0.06,
					(ATTACK_LENGTH - _attack_time) / 0.10), 0.0, 1.0)
			if w > 0.001:
				_apply_attack(t, w)

		# --- двуручный хват: левая рука на рукояти ---
		if _two_handed and not _block and not _attacking:
			_shoulder_l.rotation = _shoulder_l.rotation.lerp(
				_rv("sh_l") + Vector3(-0.62, 0.42, 0.30), 0.18)
			_elbow_l.rotation = _elbow_l.rotation.lerp(
				_rv("el_l") + Vector3(-1.30, 0.0, 0.0), 0.18)

		# --- стойка блока ---
		if _block and not _attacking:
			var guard: float = 0.75
			_shoulder_l.rotation = _shoulder_l.rotation.lerp(
				_rv("sh_l") + Vector3(-0.85, 0.55, 0.35), guard)
			_elbow_l.rotation = _elbow_l.rotation.lerp(
				_rv("el_l") + Vector3(-1.15, 0.0, 0.0), guard)
			_shoulder_r.rotation = _shoulder_r.rotation.lerp(
				_rv("sh_r") + Vector3(-0.55, -0.35, 0.0), guard)
			_elbow_r.rotation = _elbow_r.rotation.lerp(
				_rv("el_r") + Vector3(-1.0, 0.0, 0.0), guard)
			_torso.rotation = _torso.rotation.lerp(
				_rv("torso") + Vector3(0.08, 0.18, 0.0), guard)

		# --- факел всегда держим вертикально (кисть компенсирует) ---
		if _torch != null and _torch.is_inside_tree():
			_torch.global_rotation = Vector3(-0.06, 0.0, 0.05)

		# --- плащ ---
		var cape_back: float = -0.04 - 0.20 * clampf(_speed / 4.4, 0.0, 1.0)
		for i in range(_cape.size()):
			var sway: float = sin(_time * 1.25 + float(i) * 0.8) * 0.018 \
					+ sin(_phase) * 0.018 * amp * walk_w
			_cape[i].rotation = _cape_rest[i] + Vector3(
					cape_back + sway,
					sin(_time * 0.8 + float(i) * 0.6) * 0.014,
					sway * 0.6)

		# --- пламя ---
		if _flame != null and _flame.visible:
			var f: float = 1.0 + sin(_time * 19.0) * 0.09 + sin(_time * 31.0 + 0.7) * 0.05
			_flame.scale = Vector3(f, 0.92 + (f - 1.0) * 1.3, f)

	func _apply_attack(t: float, w: float) -> void:
		var p: Dictionary = _pose_at(t)
		if p.is_empty():
			return
		if _mirror:
			var mirrored: Dictionary = {}
			for key in p.keys():
				if key == "t":
					mirrored[key] = p[key]
					continue
				var v: Vector3 = p[key]
				mirrored[key] = Vector3(v.x, -v.y, -v.z)
			mirrored["thigh_r"] = p["thigh_l"]
			mirrored["knee_r"] = p["knee_l"]
			mirrored["ankle_r"] = p["ankle_l"]
			mirrored["thigh_l"] = p["thigh_r"]
			mirrored["knee_l"] = p["knee_r"]
			mirrored["ankle_l"] = p["ankle_r"]
			p = mirrored
		_shoulder_r.rotation = _shoulder_r.rotation.lerp(
				_rv("sh_r") + (p["sh_r"] as Vector3), w)
		_elbow_r.rotation = _elbow_r.rotation.lerp(
				_rv("el_r") + (p["el_r"] as Vector3), w)
		_wrist_r.rotation = _wrist_r.rotation.lerp(
				_rv("wr_r") + (p["wr_r"] as Vector3), w)
		_shoulder_l.rotation = _shoulder_l.rotation.lerp(
				_rv("sh_l") + (p["sh_l"] as Vector3), w)
		_elbow_l.rotation = _elbow_l.rotation.lerp(
				_rv("el_l") + (p["el_l"] as Vector3), w)
		_wrist_l.rotation = _wrist_l.rotation.lerp(
				_rv("wr_l") + (p["wr_l"] as Vector3), w)
		_torso.rotation = _torso.rotation.lerp(
				_rv("torso") + (p["torso"] as Vector3), w)
		_head.rotation = _head.rotation.lerp(
				_rv("head") + (p["head"] as Vector3), w)
		_hips.rotation = _hips.rotation.lerp(
				_rv("hips") + (p["hips_rot"] as Vector3), w)
		_hips.position = _hips.position.lerp(
				_rv("hips_pos") + (p["hips_pos"] as Vector3), w)
		_thigh_r.rotation = _thigh_r.rotation.lerp(
				_rv("thigh_r") + (p["thigh_r"] as Vector3), w)
		_knee_r.rotation = _knee_r.rotation.lerp(
				_rv("knee_r") + (p["knee_r"] as Vector3), w)
		_ankle_r.rotation = _ankle_r.rotation.lerp(
				_rv("ankle_r") + (p["ankle_r"] as Vector3), w)
		_thigh_l.rotation = _thigh_l.rotation.lerp(
				_rv("thigh_l") + (p["thigh_l"] as Vector3), w)
		_knee_l.rotation = _knee_l.rotation.lerp(
				_rv("knee_l") + (p["knee_l"] as Vector3), w)
		_ankle_l.rotation = _ankle_l.rotation.lerp(
				_rv("ankle_l") + (p["ankle_l"] as Vector3), w)
