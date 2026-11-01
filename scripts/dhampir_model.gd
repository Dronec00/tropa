class_name DhampirModel
extends RefCounted

## Дампир — главный герой. Полностью процедурная модель, без внешних ассетов.
##
## Ориентация: лицо в −Z, origin между ступнями, рост 1.93 м.
## build(parent) возвращает Dictionary:
##   "animator"     : Node     — стойка/шаг/удары/блок
##   "sword_pivot"  : Node3D   — меч (висит в корне, двигает аниматор)
##   "torch_pivot"  : Node3D   — пламя в левой ладони
##   "torch_flame"  : Node3D
##   "torch_light"  : OmniLight3D
##   "torch_particles": CPUParticles3D
##   "height"       : float
##
## Детали: шляпа с янтарной изнанкой и брошью, длинные волосы, бледное лицо,
## высокий ворот, плащ с подкладкой, рога на плечах, амулет, ножны за спиной,
## длинный меч с золотой гардой.

const HIPS_Y := 1.00
const TORSO_Y := 0.10
const HEAD_Y := 0.44
const HEIGHT := 1.93

const AnimatorScript := preload("res://scripts/dhampir_animator.gd")

# =========================================================================
#  Сборка
# =========================================================================

static func build(parent: Node3D) -> Dictionary:
	var kit: Kit = _make_kit()
	var rig: Dictionary = {}
	rig["hips_y"] = HIPS_Y

	var hips: Node3D = _pivot(parent, "Hips", Vector3(0.0, HIPS_Y, 0.0))
	rig["hips"] = hips
	_build_hips(hips, kit)

	var leg_r: Dictionary = _build_leg(hips, 1.0, "R", kit)
	var leg_l: Dictionary = _build_leg(hips, -1.0, "L", kit)
	for key in ["thigh", "knee", "ankle"]:
		rig[key + "_r"] = leg_r[key]
		rig[key + "_l"] = leg_l[key]

	var torso: Node3D = _pivot(hips, "Torso", Vector3(0.0, TORSO_Y, 0.0))
	rig["torso"] = torso
	_build_torso(torso, kit)

	var head: Node3D = _pivot(torso, "Head", Vector3(0.0, HEAD_Y, 0.0))
	rig["head"] = head
	var lids: Array = _build_head(head, kit)
	rig["lid_r"] = lids[0]
	rig["lid_l"] = lids[1]

	var hat: Node3D = _build_hat(head, kit)
	rig["hat"] = hat

	var hair: Array = _build_hair(head, kit)
	rig["hair"] = hair

	var cape: Array = _build_cape(torso, kit)
	rig["cape"] = cape
	_build_mantle(torso, kit)

	var arm_r: Dictionary = _build_arm(torso, 1.0, true, kit)
	var arm_l: Dictionary = _build_arm(torso, -1.0, false, kit)
	rig["shoulder_r"] = arm_r["shoulder"]
	rig["elbow_r"] = arm_r["elbow"]
	rig["wrist_r"] = arm_r["wrist"]
	rig["shoulder_l"] = arm_l["shoulder"]
	rig["elbow_l"] = arm_l["elbow"]
	rig["wrist_l"] = arm_l["wrist"]
	rig["grip"] = arm_r["grip"]

	# --- оружие ---
	var mount: Node3D = _pivot(torso, "SwordMount", Vector3(0.105, 0.305, 0.262),
			Vector3(0.04, 0.0, -0.55))
	rig["sword_mount"] = mount
	_build_scabbard(mount, kit)
	var hilt: Node3D = _build_hilt_prop(mount, kit)
	rig["hilt"] = hilt

	var sword: Node3D = _build_sword(parent, kit)
	rig["sword"] = sword
	rig["sword_pivot"] = sword

	# --- пламя в левой руке ---
	var torch: Dictionary = _build_ember(arm_l["wrist"] as Node3D, kit)
	rig["torch"] = torch["pivot"]
	rig["torch_flame"] = torch["flame"]
	rig["torch_light"] = torch["light"]
	rig["torch_particles"] = torch["particles"]

	var animator: Node = AnimatorScript.new()
	animator.name = "Animator"
	parent.add_child(animator)
	animator.setup(rig)
	animator.set_two_handed(true)

	return {
		"animator": animator,
		"sword_pivot": sword,
		"torch_pivot": torch["pivot"],
		"torch_flame": torch["flame"],
		"torch_light": torch["light"],
		"torch_particles": torch["particles"],
		"height": HEIGHT,
	}

# =========================================================================
#  Материалы
# =========================================================================

class Kit:
	var skin: StandardMaterial3D
	var skin_shade: StandardMaterial3D
	var lip: StandardMaterial3D
	var fang: StandardMaterial3D
	var hair: StandardMaterial3D
	var hair_hi: StandardMaterial3D
	var brow: StandardMaterial3D
	var eye_white: StandardMaterial3D
	var iris: StandardMaterial3D
	var pupil: StandardMaterial3D
	var eye_glint: StandardMaterial3D
	var cloth: StandardMaterial3D
	var cloth_dark: StandardMaterial3D
	var cloth_soft: StandardMaterial3D
	var lining: StandardMaterial3D
	var lining_dark: StandardMaterial3D
	var hat: StandardMaterial3D
	var leather: StandardMaterial3D
	var leather_dark: StandardMaterial3D
	var gold: StandardMaterial3D
	var gold_dark: StandardMaterial3D
	var silver: StandardMaterial3D
	var steel: StandardMaterial3D
	var blade: StandardMaterial3D
	var gem: StandardMaterial3D
	var ember: StandardMaterial3D
	var ember_core: StandardMaterial3D

static func _make_kit() -> Kit:
	var kit: Kit = Kit.new()
	var grain: ImageTexture = _grain_texture()

	kit.skin = _mat(Color(0.500, 0.520, 0.565), 0.0, 0.74)
	kit.skin_shade = _mat(Color(0.340, 0.358, 0.410), 0.0, 0.76)
	kit.lip = _mat(Color(0.245, 0.135, 0.155), 0.0, 0.58)
	kit.fang = _mat(Color(0.900, 0.900, 0.870), 0.0, 0.38)

	kit.hair = _mat(Color(0.040, 0.038, 0.048), 0.0, 0.52)
	kit.hair.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.hair_hi = _mat(Color(0.115, 0.110, 0.130), 0.0, 0.42)
	kit.hair_hi.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.brow = _mat(Color(0.035, 0.033, 0.040), 0.0, 0.70)

	kit.eye_white = _mat(Color(0.780, 0.800, 0.820), 0.0, 0.30)
	kit.iris = _mat(Color(0.560, 0.660, 0.720), 0.0, 0.22)
	kit.iris.emission_enabled = true
	kit.iris.emission = Color(0.20, 0.34, 0.44)
	kit.iris.emission_energy_multiplier = 0.55
	kit.pupil = _mat(Color(0.020, 0.020, 0.024), 0.0, 0.40)
	kit.eye_glint = StandardMaterial3D.new()
	kit.eye_glint.albedo_color = Color(0.95, 0.97, 1.0)
	kit.eye_glint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	kit.cloth = _mat(Color(0.032, 0.033, 0.042), 0.0, 0.82)
	kit.cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.cloth.albedo_texture = grain
	kit.cloth.uv1_scale = Vector3(3.0, 3.0, 3.0)
	kit.cloth_dark = _mat(Color(0.020, 0.021, 0.027), 0.0, 0.86)
	kit.cloth_dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.cloth_soft = _mat(Color(0.052, 0.051, 0.062), 0.0, 0.84)
	kit.cloth_soft.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.cloth_soft.albedo_texture = grain
	kit.cloth_soft.uv1_scale = Vector3(4.0, 4.0, 4.0)

	kit.lining = _mat(Color(0.330, 0.165, 0.045), 0.0, 0.86)
	kit.lining.cull_mode = BaseMaterial3D.CULL_DISABLED
	kit.lining.albedo_texture = grain
	kit.lining.uv1_scale = Vector3(3.0, 3.0, 3.0)
	kit.lining_dark = _mat(Color(0.255, 0.130, 0.040), 0.0, 0.90)
	kit.lining_dark.cull_mode = BaseMaterial3D.CULL_DISABLED

	kit.hat = _mat(Color(0.022, 0.022, 0.029), 0.0, 0.78)
	kit.hat.albedo_texture = grain
	kit.hat.uv1_scale = Vector3(4.0, 4.0, 4.0)
	kit.leather = _mat(Color(0.052, 0.045, 0.043), 0.02, 0.52)
	kit.leather.albedo_texture = grain
	kit.leather.uv1_scale = Vector3(5.0, 5.0, 5.0)
	kit.leather_dark = _mat(Color(0.032, 0.029, 0.029), 0.0, 0.62)
	kit.leather_dark.albedo_texture = grain
	kit.leather_dark.uv1_scale = Vector3(6.0, 6.0, 6.0)

	kit.gold = _mat(Color(0.420, 0.305, 0.115), 0.90, 0.36)
	kit.gold_dark = _mat(Color(0.330, 0.245, 0.095), 0.88, 0.42)
	kit.silver = _mat(Color(0.330, 0.342, 0.375), 0.92, 0.34)
	kit.steel = _mat(Color(0.300, 0.310, 0.340), 0.85, 0.38)
	kit.blade = _mat(Color(0.660, 0.690, 0.740), 1.0, 0.17)
	kit.blade.cull_mode = BaseMaterial3D.CULL_BACK

	kit.gem = _mat(Color(0.070, 0.200, 0.720), 0.25, 0.10)
	kit.gem.emission_enabled = true
	kit.gem.emission = Color(0.08, 0.22, 0.85)
	kit.gem.emission_energy_multiplier = 1.25

	kit.ember = StandardMaterial3D.new()
	kit.ember.albedo_color = Color(1.0, 0.66, 0.30)
	kit.ember.emission_enabled = true
	kit.ember.emission = Color(1.0, 0.50, 0.16)
	kit.ember.emission_energy_multiplier = 5.5
	kit.ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	kit.ember_core = StandardMaterial3D.new()
	kit.ember_core.albedo_color = Color(1.0, 0.90, 0.65)
	kit.ember_core.emission_enabled = true
	kit.ember_core.emission = Color(1.0, 0.80, 0.45)
	kit.ember_core.emission_energy_multiplier = 9.0
	kit.ember_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return kit

static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

## Мягкое зерно ткани: без него кожа и плащ выглядят пластиковыми.
static func _grain_texture() -> ImageTexture:
	var size: int = 96
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n: float = sin(float(x) * 2.13 + sin(float(y) * 0.71) * 2.4)
			n += sin(float(y) * 3.37 + cos(float(x) * 0.53) * 1.9) * 0.5
			var v: float = 0.90 + n * 0.035
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# =========================================================================
#  Таз, пояс, юбка пальто
# =========================================================================

static func _build_hips(hips: Node3D, kit: Kit) -> void:
	_add(hips, _cyl(0.145, 0.158, 0.20, 18), kit.cloth_dark, Vector3(0.0, -0.03, 0.0))
	_add(hips, _sphere(0.122, 18, 10), kit.cloth, Vector3(0.0, -0.02, 0.0),
			Vector3.ZERO, Vector3(1.08, 0.72, 0.86))

	# ремень
	_add(hips, _cyl(0.166, 0.170, 0.062, 22), kit.leather, Vector3(0.0, 0.045, 0.0))
	_add(hips, _cyl(0.171, 0.171, 0.011, 22), kit.leather_dark, Vector3(0.0, 0.076, 0.0))
	_add(hips, _cyl(0.171, 0.171, 0.011, 22), kit.leather_dark, Vector3(0.0, 0.014, 0.0))
	_skull_buckle(hips, Vector3(0.0, 0.044, -0.176), 1.0, kit)

	# подсумки и ножны на бедре
	for side in [-1.0, 1.0]:
		_add(hips, _box(Vector3(0.082, 0.105, 0.062)), kit.leather,
				Vector3(side * 0.176, -0.015, -0.040), Vector3(0.0, side * 0.30, side * 0.05))
		_add(hips, _box(Vector3(0.084, 0.030, 0.066)), kit.leather_dark,
				Vector3(side * 0.176, 0.033, -0.040), Vector3(0.0, side * 0.30, side * 0.05))
		_add(hips, _box(Vector3(0.016, 0.020, 0.010)), kit.gold,
				Vector3(side * 0.196, 0.004, -0.072), Vector3(0.0, side * 0.30, side * 0.05))

	# кинжал на правом бедре
	var dagger: Node3D = _pivot(hips, "Dagger", Vector3(0.205, -0.020, 0.020),
			Vector3(0.18, 0.0, 0.22))
	_add(dagger, _box(Vector3(0.020, 0.20, 0.035)), kit.leather_dark, Vector3.ZERO)
	_add(dagger, _cyl(0.012, 0.010, 0.085, 8), kit.leather, Vector3(0.0, 0.142, 0.0))
	_add(dagger, _sphere(0.019, 10, 6), kit.silver, Vector3(0.0, 0.192, 0.0),
			Vector3.ZERO, Vector3(1.0, 0.8, 1.0))

	# пальто: полотнище вокруг бёдер с разрезом спереди + фалды
	var skirt: Node3D = _pivot(hips, "CoatSkirt", Vector3(0.0, -0.005, 0.004))
	var so: MeshInstance3D = MeshInstance3D.new()
	so.mesh = _cape_sheet(0.145, 0.235, 0.530, 252.0, 18, 7, 0.012, 0.028, 1.3, false)
	so.material_override = kit.cloth
	skirt.add_child(so)
	var si_mi: MeshInstance3D = MeshInstance3D.new()
	si_mi.mesh = _cape_sheet(0.138, 0.228, 0.525, 249.0, 18, 7, 0.010, 0.026, 2.2, true)
	si_mi.material_override = kit.cloth_dark
	skirt.add_child(si_mi)
	# короткий верхний слой
	var so2: MeshInstance3D = MeshInstance3D.new()
	so2.mesh = _cape_sheet(0.152, 0.215, 0.285, 254.0, 16, 4, 0.009, 0.014, 2.8, false)
	so2.material_override = kit.leather_dark
	skirt.add_child(so2)
	# передние фалды по бокам от разреза
	for side in [-1.0, 1.0]:
		var tail: Node3D = _pivot(hips, "Tail" + ("R" if side > 0.0 else "L"),
				Vector3(side * 0.105, -0.015, -0.120), Vector3(0.0, side * 0.10, 0.0))
		var tail_mesh: ArrayMesh = _cloth(0.085, 0.130, 0.500, 3, 6, 0.020, 0.014, 0.030,
				side * 1.4)
		var tmi: MeshInstance3D = MeshInstance3D.new()
		tmi.mesh = tail_mesh
		tmi.material_override = kit.cloth_dark
		tail.add_child(tmi)
		_add(tail, _box(Vector3(0.012, 0.470, 0.010)), kit.gold_dark,
				Vector3(side * 0.055, -0.245, 0.002))

static func _skull_buckle(parent: Node3D, pos: Vector3, scale: float, kit: Kit) -> void:
	var skull: Node3D = _pivot(parent, "SkullBuckle", pos, Vector3(0.10, 0.0, 0.0))
	_add(skull, _sphere(0.036 * scale, 14, 10), kit.silver, Vector3.ZERO,
			Vector3.ZERO, Vector3(1.0, 1.10, 0.55))
	_add(skull, _box(Vector3(0.040 * scale, 0.024 * scale, 0.014 * scale)), kit.silver,
			Vector3(0.0, -0.030 * scale, -0.004))
	for side in [-1.0, 1.0]:
		_add(skull, _sphere(0.010 * scale, 8, 6), kit.pupil,
				Vector3(side * 0.014 * scale, 0.006 * scale, -0.021 * scale),
				Vector3.ZERO, Vector3(1.0, 1.2, 0.4))
	_add(skull, _cone(0.004 * scale, 0.010 * scale, 0.010 * scale, 6), kit.pupil,
			Vector3(0.0, -0.010 * scale, -0.023 * scale), Vector3(PI, 0.0, 0.0))
	for i in range(3):
		_add(skull, _box(Vector3(0.006 * scale, 0.012 * scale, 0.008 * scale)), kit.silver,
				Vector3(-0.010 * scale + float(i) * 0.010 * scale, -0.044 * scale, -0.006))

# =========================================================================
#  Ноги и сапоги
# =========================================================================

static func _build_leg(hips: Node3D, side: float, suffix: String, kit: Kit) -> Dictionary:
	var thigh: Node3D = _pivot(hips, "Thigh" + suffix, Vector3(side * 0.112, -0.025, 0.0))
	_add(thigh, _capsule(0.074, 0.455, 14), kit.cloth_dark, Vector3(0.0, -0.215, 0.0))
	_add(thigh, _capsule(0.070, 0.36, 12), kit.cloth, Vector3(0.0, -0.26, 0.0))
	_add(thigh, _cyl(0.075, 0.075, 0.032, 16), kit.leather, Vector3(0.0, -0.115, 0.0))
	_add(thigh, _cyl(0.071, 0.071, 0.028, 16), kit.leather, Vector3(0.0, -0.360, 0.0))
	_add(thigh, _box(Vector3(0.014, 0.024, 0.010)), kit.silver, Vector3(0.0, -0.115, -0.076))

	var knee: Node3D = _pivot(thigh, "Knee" + suffix, Vector3(0.0, -0.455, 0.0))
	_add(knee, _sphere(0.068, 14, 10), kit.cloth_dark, Vector3(0.0, 0.0, -0.006),
			Vector3.ZERO, Vector3(0.98, 0.95, 1.0))
	# наколенник с острым верхом
	_add(knee, _sphere(0.059, 14, 8), kit.leather, Vector3(0.0, 0.005, -0.052),
			Vector3.ZERO, Vector3(1.08, 0.92, 0.52))
	_add(knee, _cone(0.035, 0.028, 0.070, 6), kit.leather_dark,
			Vector3(0.0, 0.062, -0.052), Vector3(0.22, 0.0, 0.0))
	_add(knee, _box(Vector3(0.086, 0.013, 0.014)), kit.silver,
			Vector3(0.0, -0.018, -0.079), Vector3(0.10, 0.0, 0.0))
	_add(knee, _sphere(0.008, 8, 6), kit.silver, Vector3(0.0, 0.038, -0.070))

	# голень
	_add(knee, _capsule(0.060, 0.415, 12), kit.cloth_dark, Vector3(0.0, -0.205, 0.0))
	# голенище сапога
	_add(knee, _cyl(0.074, 0.088, 0.330, 16), kit.leather, Vector3(0.0, -0.245, 0.0))
	_add(knee, _cyl(0.090, 0.091, 0.048, 16), kit.leather, Vector3(0.0, -0.100, 0.0))
	_add(knee, _torus(0.078, 0.092, 18, 6), kit.leather_dark, Vector3(0.0, -0.092, 0.0))
	# задний шов
	_add(knee, _box(Vector3(0.010, 0.33, 0.012)), kit.leather_dark, Vector3(0.0, -0.245, 0.086))

	var ankle: Node3D = _pivot(knee, "Ankle" + suffix, Vector3(0.0, -0.415, 0.0))
	# ступня
	_add(ankle, _box(Vector3(0.096, 0.085, 0.235)), kit.leather, Vector3(0.0, -0.055, -0.052))
	_add(ankle, _sphere(0.055, 14, 8), kit.leather, Vector3(0.0, -0.070, -0.164),
			Vector3.ZERO, Vector3(0.92, 0.62, 1.35))
	_add(ankle, _cone(0.050, 0.030, 0.085, 10), kit.leather,
			Vector3(0.0, -0.078, -0.218), Vector3(-PI * 0.5, 0.0, 0.0))
	_add(ankle, _box(Vector3(0.102, 0.045, 0.130)), kit.leather, Vector3(0.0, -0.070, 0.058))
	_add(ankle, _box(Vector3(0.108, 0.026, 0.290)), kit.leather_dark, Vector3(0.0, -0.092, -0.048))
	_add(ankle, _box(Vector3(0.070, 0.030, 0.070)), kit.leather_dark, Vector3(0.0, -0.090, 0.084))
	# ремни
	for i in range(3):
		var y: float = -0.022 - float(i) * 0.032
		var z: float = -0.040 - float(i) * 0.024
		_add(ankle, _box(Vector3(0.104, 0.020, 0.112)), kit.leather_dark,
				Vector3(0.0, y, z))
		_add(ankle, _box(Vector3(0.020, 0.024, 0.010)), kit.silver,
				Vector3(side * 0.042, y, z - 0.060))
	# шпоры-накладки
	_add(ankle, _box(Vector3(0.014, 0.070, 0.012)), kit.silver,
			Vector3(side * 0.052, -0.040, 0.010), Vector3(0.0, 0.0, side * 0.2))
	return {"thigh": thigh, "knee": knee, "ankle": ankle}

# =========================================================================
#  Торс, ворот, амулет, перевязь
# =========================================================================

static func _build_torso(torso: Node3D, kit: Kit) -> void:
	# стан
	_add(torso, _cyl(0.128, 0.152, 0.20, 18), kit.cloth_dark, Vector3(0.0, 0.075, 0.0))
	_add(torso, _sphere(0.149, 20, 12), kit.cloth, Vector3(0.0, 0.265, 0.0),
			Vector3.ZERO, Vector3(1.12, 1.10, 0.78))
	_add(torso, _sphere(0.118, 16, 10), kit.cloth, Vector3(0.0, 0.135, 0.0),
			Vector3.ZERO, Vector3(1.02, 0.72, 0.80))

	# рельеф: грудь и пресс
	for side in [-1.0, 1.0]:
		_add(torso, _sphere(0.058, 14, 8), kit.cloth_soft,
				Vector3(side * 0.060, 0.322, -0.108), Vector3(0.0, side * 0.12, 0.0),
				Vector3(1.10, 0.62, 0.26))
	for row in range(3):
		for side in [-1.0, 1.0]:
			_add(torso, _sphere(0.030, 10, 6), kit.cloth_soft,
					Vector3(side * 0.032, 0.245 - float(row) * 0.052, -0.116 + float(row) * 0.008),
					Vector3.ZERO, Vector3(1.0, 0.55, 0.20))
			_add(torso, _box(Vector3(0.062, 0.004, 0.012)), kit.leather_dark,
					Vector3(side * 0.036, 0.218 - float(row) * 0.052, -0.128))
	# косые мышцы
	for side in [-1.0, 1.0]:
		_add(torso, _sphere(0.045, 10, 6), kit.cloth_soft,
				Vector3(side * 0.100, 0.170, -0.070), Vector3(0.0, 0.0, side * 0.35),
				Vector3(0.60, 1.35, 0.36))
	# ключицы
	for side in [-1.0, 1.0]:
		_add(torso, _box(Vector3(0.105, 0.016, 0.020)), kit.cloth_soft,
				Vector3(side * 0.070, 0.374, -0.098), Vector3(0.0, side * 0.10, side * 0.10))

	# высокий ворот: сзади и по бокам, спереди расстёгнут
	_build_collar(torso, kit)
	# застёжка ворота
	_add(torso, _sphere(0.010, 10, 8), kit.gold, Vector3(0.0, 0.372, -0.128))
	_add(torso, _sphere(0.006, 8, 6), kit.gem, Vector3(0.0, 0.372, -0.136))

	# плечевое коромысло под плащом
	for side in [-1.0, 1.0]:
		_add(torso, _sphere(0.086, 14, 8), kit.cloth,
				Vector3(side * 0.150, 0.360, 0.0), Vector3.ZERO, Vector3(0.95, 0.70, 0.95))

	# перевязь через грудь
	var strap: Node3D = _pivot(torso, "ChestStrap", Vector3(0.012, 0.285, -0.128),
			Vector3(0.0, 0.0, 0.62))
	_add(strap, _box(Vector3(0.040, 0.310, 0.018)), kit.leather, Vector3.ZERO)
	_add(strap, _box(Vector3(0.050, 0.030, 0.024)), kit.leather_dark, Vector3(0.0, 0.085, -0.002))
	_add(strap, _box(Vector3(0.030, 0.030, 0.010)), kit.gold, Vector3(0.0, 0.085, -0.016))
	_add(strap, _box(Vector3(0.026, 0.016, 0.012)), kit.leather_dark, Vector3(0.0, -0.060, -0.002))
	# пряжка перевязи
	_add(torso, _box(Vector3(0.036, 0.024, 0.012)), kit.silver,
			Vector3(0.075, 0.312, -0.136))
	_add(torso, _box(Vector3(0.022, 0.010, 0.008)), kit.leather_dark,
			Vector3(0.075, 0.312, -0.143))

	# нижние ремни с заклёпками
	for side in [-1.0, 1.0]:
		_add(torso, _cyl(0.014, 0.014, 0.014, 8), kit.silver,
				Vector3(side * 0.115, 0.190, -0.108), Vector3(PI * 0.5, 0.0, 0.0))

	# амулет на цепи
	_build_amulet(torso, kit)

static func _build_collar(torso: Node3D, kit: Kit) -> void:
	var outer: MeshInstance3D = MeshInstance3D.new()
	outer.mesh = _collar_mesh(0.100, 0.166, 0.118, 0.90, false)
	outer.material_override = kit.cloth
	outer.position = Vector3(0.0, 0.352, 0.004)
	torso.add_child(outer)
	var inner: MeshInstance3D = MeshInstance3D.new()
	inner.mesh = _collar_mesh(0.095, 0.158, 0.114, 0.90, true)
	inner.material_override = kit.lining
	inner.position = Vector3(0.0, 0.354, 0.004)
	torso.add_child(inner)
	# валик по верхнему краю, только сзади
	for i in range(9):
		var a: float = 1.15 + float(i) * (TAU - 2.3) / 8.0
		_add(torso, _sphere(0.0075, 8, 6), kit.leather_dark,
				Vector3(sin(a) * 0.164, 0.468, -cos(a) * 0.164 + 0.004))

## Ворот: часть конуса с вырезом спереди.
static func _collar_mesh(bottom_r: float, top_r: float, height: float,
		gap: float, flip: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = 22
	for i in range(seg):
		var a0: float = gap + (TAU - gap * 2.0) * float(i) / float(seg)
		var a1: float = gap + (TAU - gap * 2.0) * float(i + 1) / float(seg)
		var b0: Vector3 = Vector3(sin(a0) * bottom_r, 0.0, -cos(a0) * bottom_r)
		var b1: Vector3 = Vector3(sin(a1) * bottom_r, 0.0, -cos(a1) * bottom_r)
		var t0: Vector3 = Vector3(sin(a0) * top_r, height, -cos(a0) * top_r)
		var t1: Vector3 = Vector3(sin(a1) * top_r, height, -cos(a1) * top_r)
		if flip:
			st.add_vertex(b0); st.add_vertex(t1); st.add_vertex(t0)
			st.add_vertex(b0); st.add_vertex(b1); st.add_vertex(t1)
		else:
			st.add_vertex(b0); st.add_vertex(t0); st.add_vertex(t1)
			st.add_vertex(b0); st.add_vertex(t1); st.add_vertex(b1)
	st.generate_normals()
	return st.commit()

static func _build_amulet(torso: Node3D, kit: Kit) -> void:
	var a: float = -0.30
	for i in range(11):
		var y: float = 0.398 - float(i) * 0.0165
		var x: float = -0.070 + a * float(i) * 0.006
		var z: float = -0.106 - sin(float(i) * 0.24) * 0.016 - float(i) * 0.0038
		_add(torso, _torus(0.0048, 0.0082, 8, 4), kit.gold_dark,
				Vector3(x, y, z), Vector3(PI * 0.5, 0.0, 0.0 if i % 2 == 0 else 0.0))
	# медальон
	var m: Node3D = _pivot(torso, "Amulet", Vector3(-0.072, 0.208, -0.163),
			Vector3(0.10, 0.0, 0.0))
	_add(m, _torus(0.034, 0.049, 22, 8), kit.gold, Vector3.ZERO)
	_add(m, _cyl(0.036, 0.036, 0.010, 20), kit.gold_dark, Vector3(0.0, 0.0, 0.004),
			Vector3(PI * 0.5, 0.0, 0.0))
	_add(m, _sphere(0.030, 16, 12), kit.gem, Vector3(0.0, 0.0, -0.007),
			Vector3.ZERO, Vector3(1.0, 1.0, 0.45))
	for i in range(4):
		var ang: float = TAU * float(i) / 4.0 + PI * 0.25
		_add(m, _sphere(0.006, 8, 6), kit.gold,
				Vector3(cos(ang) * 0.040, sin(ang) * 0.040, -0.004))

# =========================================================================
#  Плащ и плечевая накидка
# =========================================================================

static func _build_cape(torso: Node3D, kit: Kit) -> Array:
	var segments: Array = []
	var parent: Node3D = torso
	var layout: Array = [
		{"y": 0.400, "top": 0.165, "bot": 0.235, "len": 0.320, "span": 168.0, "cols": 20},
		{"y": -0.315, "top": 0.220, "bot": 0.305, "len": 0.420, "span": 178.0, "cols": 22},
		{"y": -0.415, "top": 0.285, "bot": 0.405, "len": 0.580, "span": 188.0, "cols": 24},
	]
	for si in range(3):
		var spec: Dictionary = layout[si]
		var seg: Node3D = _pivot(parent, "CapeSeg%d" % (si + 1),
				Vector3(0.0, float(spec["y"]), 0.105 if si == 0 else 0.0),
				Vector3(-0.04 if si == 0 else -0.025, 0.0, 0.0))
		var outer: MeshInstance3D = MeshInstance3D.new()
		outer.mesh = _cape_sheet(float(spec["top"]), float(spec["bot"]),
				float(spec["len"]), float(spec["span"]), int(spec["cols"]), 8,
				0.012 + float(si) * 0.004, 0.040 + float(si) * 0.010,
				float(si) * 2.3, false)
		outer.material_override = kit.cloth if si != 1 else kit.cloth_dark
		seg.add_child(outer)
		var inner: MeshInstance3D = MeshInstance3D.new()
		inner.mesh = _cape_sheet(float(spec["top"]) - 0.012, float(spec["bot"]) - 0.012,
				float(spec["len"]) * 0.995, float(spec["span"]) - 3.0,
				int(spec["cols"]), 8, 0.010 + float(si) * 0.004,
				0.038 + float(si) * 0.010, float(si) * 2.3 + 1.1, true)
		inner.material_override = kit.lining if si < 2 else kit.lining_dark
		seg.add_child(inner)
		# утяжелённая кромка по низу
		for i in range(7):
			var a: float = -float(spec["span"]) * 0.5 * PI / 180.0 + float(spec["span"]) * PI / 180.0 * (float(i) + 0.5) / 7.0
			var r: float = float(spec["bot"]) + 0.006
			_add(seg, _sphere(0.010, 6, 6), kit.leather_dark,
					Vector3(sin(a) * r, -float(spec["len"]) + 0.012, cos(a) * r))
		if si == 0:
			# ворот плаща и застёжки
			pass
		segments.append(seg)
		parent = seg
	return segments

## Полотнище плаща: дуга вокруг спины, складки, рваный низ.
static func _cape_sheet(top_r: float, bot_r: float, length: float, span_deg: float,
		cols: int, rows: int, fold_amp: float, ruff: float, seed: float,
		flip: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span: float = deg_to_rad(span_deg)
	var grid: Array = []
	for j in range(rows + 1):
		var v: float = float(j) / float(rows)
		var r: float = lerpf(top_r, bot_r, v)
		r += v * v * 0.030
		for i in range(cols + 1):
			var u: float = float(i) / float(cols)
			var ang: float = -span * 0.5 + span * u
			var folds: float = sin(u * PI * 6.0 + seed) * fold_amp * (0.25 + v * 0.75)
			folds += sin(u * PI * 2.0 + seed * 0.7) * fold_amp * 0.45 * v
			var rr: float = r + folds
			var y: float = -v * length
			y -= pow(v, 4.0) * ruff * (0.45 + 0.55 * sin(u * 24.0 + seed * 2.0))
			# низ чуть отходит назад, чтобы плащ не лип к ногам
			y += v * v * 0.020
			grid.append(Vector3(sin(ang) * rr, y, cos(ang) * rr))
	var idx := func(i: int, j: int) -> int:
		return j * (cols + 1) + i
	for j in range(rows):
		for i in range(cols):
			var a: int = idx.call(i, j)
			var b: int = idx.call(i + 1, j)
			var c: int = idx.call(i + 1, j + 1)
			var d: int = idx.call(i, j + 1)
			var ua: Vector2 = Vector2(float(i) / cols, 1.0 - float(j) / rows)
			var ub: Vector2 = Vector2(float(i + 1) / cols, 1.0 - float(j) / rows)
			var uc: Vector2 = Vector2(float(i + 1) / cols, 1.0 - float(j + 1) / rows)
			var ud: Vector2 = Vector2(float(i) / cols, 1.0 - float(j + 1) / rows)
			if flip:
				_tri(st, grid[a], grid[c], grid[b], ua, uc, ub)
				_tri(st, grid[a], grid[d], grid[c], ua, ud, uc)
			else:
				_tri(st, grid[a], grid[b], grid[c], ua, ub, uc)
				_tri(st, grid[a], grid[c], grid[d], ua, uc, ud)
	st.generate_normals()
	return st.commit()

static func _build_mantle(torso: Node3D, kit: Kit) -> void:
	# короткая накидка поверх плеч: та же логика, что у плаща
	var m: Node3D = _pivot(torso, "Mantle", Vector3(0.0, 0.425, 0.020),
			Vector3(-0.10, 0.0, 0.0))
	var outer: MeshInstance3D = MeshInstance3D.new()
	outer.mesh = _cape_sheet(0.155, 0.230, 0.215, 205.0, 18, 5, 0.016, 0.016, 3.1, false)
	outer.material_override = kit.cloth
	m.add_child(outer)
	var inner: MeshInstance3D = MeshInstance3D.new()
	inner.mesh = _cape_sheet(0.145, 0.220, 0.210, 202.0, 18, 5, 0.014, 0.014, 4.2, true)
	inner.material_override = kit.lining
	m.add_child(inner)

	# накидка второго слоя, короче и шире
	var m2: Node3D = _pivot(torso, "Mantle2", Vector3(0.0, 0.400, 0.010),
			Vector3(-0.04, 0.0, 0.0))
	var outer2: MeshInstance3D = MeshInstance3D.new()
	outer2.mesh = _cape_sheet(0.172, 0.245, 0.140, 215.0, 18, 4, 0.014, 0.012, 1.7, false)
	outer2.material_override = kit.cloth_dark
	m2.add_child(outer2)
	var inner2: MeshInstance3D = MeshInstance3D.new()
	inner2.mesh = _cape_sheet(0.162, 0.235, 0.136, 212.0, 18, 4, 0.012, 0.010, 2.4, true)
	inner2.material_override = kit.lining_dark
	m2.add_child(inner2)

	# рога на плечах
	for side in [-1.0, 1.0]:
		var horn: Node3D = _pivot(torso, "Horn" + ("R" if side > 0.0 else "L"),
				Vector3(side * 0.205, 0.405, 0.040), Vector3(0.10, 0.0, side * 0.16))
		var pts: Array = [
			Vector3(0.0, 0.0, 0.0),
			Vector3(side * 0.026, 0.048, -0.002),
			Vector3(side * 0.064, 0.104, -0.012),
			Vector3(side * 0.094, 0.148, -0.022),
			Vector3(side * 0.116, 0.188, -0.030),
		]
		var radii: Array = [0.044, 0.036, 0.025, 0.012, 0.0015]
		var horn_mi: MeshInstance3D = MeshInstance3D.new()
		horn_mi.mesh = _tube(pts, radii, 7)
		horn_mi.material_override = kit.leather
		horn.add_child(horn_mi)
		_add(horn, _torus(0.031, 0.043, 12, 6), kit.silver, Vector3(0.0, 0.006, 0.0),
				Vector3(0.0, 0.0, side * 0.10))
		_add(horn, _sphere(0.010, 8, 6), kit.gold, Vector3(side * 0.052, 0.091, -0.010))
		# застёжка плаща на плече
		_add(torso, _torus(0.014, 0.022, 10, 5), kit.gold_dark,
				Vector3(side * 0.150, 0.395, -0.088), Vector3(PI * 0.5, 0.0, 0.0))
		_add(torso, _sphere(0.008, 8, 6), kit.leather_dark,
				Vector3(side * 0.150, 0.395, -0.098))

# =========================================================================
#  Голова, лицо, уши
# =========================================================================

static func _build_head(head: Node3D, kit: Kit) -> Array:
	# шея
	_add(head, _capsule(0.047, 0.140, 10), kit.skin, Vector3(0.0, -0.040, 0.012))
	_add(head, _cyl(0.054, 0.062, 0.030, 12), kit.skin_shade, Vector3(0.0, -0.092, 0.012))
	# череп: узкий, вытянутый
	_add(head, _sphere(0.103, 24, 16), kit.skin, Vector3(0.0, 0.126, 0.008),
			Vector3.ZERO, Vector3(0.88, 1.12, 0.96))
	# лобные и височные плоскости
	for side in [-1.0, 1.0]:
		_add(head, _sphere(0.040, 12, 8), kit.skin, Vector3(side * 0.052, 0.150, -0.062),
				Vector3(0.0, side * 0.25, 0.0), Vector3(0.90, 0.62, 0.55))
		_add(head, _sphere(0.030, 10, 6), kit.skin_shade,
				Vector3(side * 0.076, 0.138, -0.038), Vector3.ZERO, Vector3(0.7, 1.0, 0.5))
	# челюсть
	_add(head, _sphere(0.080, 18, 12), kit.skin, Vector3(0.0, 0.056, -0.016),
			Vector3.ZERO, Vector3(0.82, 0.72, 0.94))
	_add(head, _sphere(0.026, 12, 8), kit.skin, Vector3(0.0, 0.016, -0.068),
			Vector3.ZERO, Vector3(0.95, 0.85, 0.85))
	for side in [-1.0, 1.0]:
		# линия челюсти от уха к подбородку
		_add(head, _sphere(0.026, 10, 6), kit.skin_shade,
				Vector3(side * 0.048, 0.040, -0.058), Vector3(0.0, 0.0, side * 0.45),
				Vector3(0.65, 1.10, 0.55))
		# скула
		_add(head, _sphere(0.028, 12, 8), kit.skin, Vector3(side * 0.057, 0.108, -0.058),
				Vector3(0.0, side * 0.22, 0.0), Vector3(0.78, 0.66, 0.78))
		# впадина под скулой
		_add(head, _sphere(0.021, 10, 6), kit.skin_shade,
				Vector3(side * 0.052, 0.080, -0.070), Vector3.ZERO, Vector3(0.8, 1.0, 0.45))
	# надбровье
	_add(head, _box(Vector3(0.126, 0.017, 0.022)), kit.skin_shade,
			Vector3(0.0, 0.165, -0.086), Vector3(0.14, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		# глазница
		_add(head, _sphere(0.026, 14, 8), kit.skin_shade,
				Vector3(side * 0.043, 0.142, -0.080), Vector3(0.0, side * 0.16, 0.0),
				Vector3(1.08, 0.66, 0.42))
		# белок: узкий, восточный разрез
		_add(head, _sphere(0.0163, 14, 10), kit.eye_white,
				Vector3(side * 0.041, 0.1440, -0.0925),
				Vector3(0.0, side * 0.14, 0.0), Vector3(1.08, 0.66, 0.50))
		# радужка и зрачок
		_add(head, _cyl(0.0096, 0.0096, 0.0030, 14), kit.iris,
				Vector3(side * 0.041, 0.1432, -0.1032),
				Vector3(PI * 0.5, 0.0, 0.0))
		_add(head, _cyl(0.0037, 0.0037, 0.0022, 10), kit.pupil,
				Vector3(side * 0.041, 0.1432, -0.1050),
				Vector3(PI * 0.5, 0.0, 0.0))
		_add(head, _sphere(0.0026, 6, 6), kit.eye_glint,
				Vector3(side * 0.0445, 0.1472, -0.1058))
		# веко (моргает)
		var lid: Node3D = _pivot(head, "Lid" + ("R" if side > 0.0 else "L"),
				Vector3(side * 0.041, 0.1580, -0.0940), Vector3(-0.12, side * 0.10, 0.0))
		_add(lid, _box(Vector3(0.033, 0.0115, 0.010)), kit.skin_shade,
				Vector3(0.0, -0.006, 0.0), Vector3(0.0, 0.0, side * -0.05))
		_add(lid, _box(Vector3(0.032, 0.0032, 0.011)), kit.brow,
				Vector3(0.0, -0.0152, 0.0))
		# нижнее веко
		_add(head, _box(Vector3(0.031, 0.0028, 0.008)), kit.skin_shade,
				Vector3(side * 0.041, 0.1330, -0.0970))
		# бровь: тонкая, с изломом
		_add(head, _box(Vector3(0.040, 0.0040, 0.008)), kit.brow,
				Vector3(side * 0.041, 0.1720, -0.0970), Vector3(0.0, 0.0, side * 0.16))
		_add(head, _box(Vector3(0.013, 0.0032, 0.007)), kit.brow,
				Vector3(side * 0.064, 0.1780, -0.0935), Vector3(0.0, 0.0, side * 0.36))

	# нос: длинный, прямой, с горбинкой
	_add(head, _box(Vector3(0.0150, 0.100, 0.024)), kit.skin,
			Vector3(0.0, 0.118, -0.0985), Vector3(0.20, 0.0, 0.0))
	_add(head, _sphere(0.0128, 12, 10), kit.skin, Vector3(0.0, 0.0725, -0.1215),
			Vector3.ZERO, Vector3(0.94, 0.80, 1.12))
	for side in [-1.0, 1.0]:
		_add(head, _box(Vector3(0.007, 0.055, 0.014)), kit.skin_shade,
				Vector3(side * 0.010, 0.112, -0.104), Vector3(0.20, 0.0, side * 0.10))
		_add(head, _sphere(0.0095, 8, 6), kit.skin_shade,
				Vector3(side * 0.0135, 0.0705, -0.1135), Vector3.ZERO, Vector3(1.0, 0.7, 0.8))
		_add(head, _sphere(0.0034, 6, 6), kit.pupil,
				Vector3(side * 0.0105, 0.0655, -0.1175), Vector3.ZERO, Vector3(1.2, 0.5, 0.6))
	# фильтрум
	_add(head, _box(Vector3(0.010, 0.016, 0.008)), kit.skin_shade,
			Vector3(0.0, 0.0565, -0.0965))

	# губы: тонкие, бледные
	_add(head, _box(Vector3(0.039, 0.0058, 0.013)), kit.lip,
			Vector3(0.0, 0.0450, -0.0930), Vector3(0.18, 0.0, 0.0))
	_add(head, _box(Vector3(0.034, 0.0072, 0.013)), kit.lip,
			Vector3(0.0, 0.0355, -0.0920), Vector3(0.10, 0.0, 0.0))
	_add(head, _box(Vector3(0.036, 0.0020, 0.010)), kit.brow,
			Vector3(0.0, 0.0400, -0.0980))
	for side in [-1.0, 1.0]:
		_add(head, _sphere(0.0036, 6, 6), kit.lip,
				Vector3(side * 0.0215, 0.0405, -0.0935))
		# клык
		_add(head, _cone(0.0030, 0.0050, 0.012, 6), kit.fang,
				Vector3(side * 0.0155, 0.0315, -0.0955), Vector3(PI, 0.0, 0.0))
	# ямка на подбородке
	_add(head, _sphere(0.0085, 8, 6), kit.skin_shade, Vector3(0.0, 0.021, -0.0655),
			Vector3.ZERO, Vector3(1.2, 0.7, 0.5))

	# уши: острые, отведены назад
	for side in [-1.0, 1.0]:
		var ear: Node3D = _pivot(head, "Ear" + ("R" if side > 0.0 else "L"),
				Vector3(side * 0.096, 0.133, 0.010), Vector3(0.0, side * 0.32, side * 0.78))
		_add(ear, _cone(0.021, 0.005, 0.080, 8), kit.skin, Vector3(0.0, 0.028, 0.0),
				Vector3.ZERO, Vector3(0.55, 1.0, 1.0))
		_add(ear, _cone(0.013, 0.002, 0.050, 8), kit.skin_shade,
				Vector3(0.0, 0.024, -0.009), Vector3.ZERO, Vector3(0.45, 1.0, 0.9))
		_add(ear, _sphere(0.0055, 6, 6), kit.skin, Vector3(0.0, -0.008, 0.004))

	# кадык
	_add(head, _sphere(0.010, 8, 6), kit.skin_shade, Vector3(0.0, -0.070, -0.034),
			Vector3.ZERO, Vector3(0.8, 1.3, 0.7))

	return [head.get_node("LidR"), head.get_node("LidL")]

# =========================================================================
#  Волосы
# =========================================================================

static func _build_hair(head: Node3D, kit: Kit) -> Array:
	# шапка волос: закрывает темечко и лобные углы
	_add(head, _sphere(0.104, 20, 14), kit.hair, Vector3(0.0, 0.170, 0.010),
			Vector3.ZERO, Vector3(1.02, 0.66, 1.03))
	# затылок
	_add(head, _sphere(0.108, 20, 14), kit.hair, Vector3(0.0, 0.128, 0.038),
			Vector3.ZERO, Vector3(1.06, 1.08, 0.94))
	# масса до лопаток
	_add(head, _sphere(0.105, 18, 12), kit.hair, Vector3(0.0, 0.060, 0.082),
			Vector3.ZERO, Vector3(1.04, 1.20, 0.66))
	# боковые массы у висков
	for side in [-1.0, 1.0]:
		_add(head, _sphere(0.058, 14, 10), kit.hair,
				Vector3(side * 0.083, 0.140, 0.020), Vector3(0.0, side * 0.2, 0.0),
				Vector3(0.55, 1.05, 0.78))
	# бороздки на шапке волос
	for i in range(5):
		var t: float = float(i) / 4.0 - 0.5
		var pts: Array = []
		for j in range(4):
			var v: float = float(j) / 3.0
			pts.append(Vector3(t * 0.16, 0.205 - v * 0.075, -0.070 + v * 0.040 + absf(t) * 0.030))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _tube(pts, [0.010, 0.008, 0.006, 0.003], 5)
		mi.material_override = kit.hair_hi
		head.add_child(mi)

	var nodes: Array = []

	# длинные пряди-полотна сзади
	var backs: Array = [
		{"x": 0.0, "y": 0.140, "z": 0.085, "w": 0.100, "len": 0.62, "yaw": 0.0},
		{"x": -0.054, "y": 0.145, "z": 0.080, "w": 0.072, "len": 0.56, "yaw": 0.10},
		{"x": 0.054, "y": 0.145, "z": 0.080, "w": 0.072, "len": 0.56, "yaw": -0.10},
		{"x": -0.090, "y": 0.135, "z": 0.062, "w": 0.056, "len": 0.48, "yaw": 0.26},
		{"x": 0.090, "y": 0.135, "z": 0.062, "w": 0.056, "len": 0.48, "yaw": -0.26},
	]
	for i in range(backs.size()):
		var b: Dictionary = backs[i]
		var pivot: Node3D = _pivot(head, "HairBack%d" % i,
				Vector3(float(b["x"]), float(b["y"]), float(b["z"])),
				Vector3(-0.05, float(b["yaw"]), 0.0))
		var panel: ArrayMesh = _cloth(float(b["w"]), float(b["w"]) * 1.50,
				float(b["len"]), 3, 8, 0.028, 0.034, 0.022, float(i) * 1.9)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = panel
		mi.material_override = kit.hair if i % 2 == 0 else kit.hair_hi
		pivot.add_child(mi)
		nodes.append(pivot)
		for k in range(2):
			var x0: float = float(b["x"]) + (float(k) - 0.5) * float(b["w"]) * 0.55
			var pts: Array = []
			for j in range(7):
				var v: float = float(j) / 6.0
				pts.append(Vector3(
					x0 + sin(v * 3.6 + float(i) + float(k)) * 0.014,
					float(b["y"]) - v * float(b["len"]) * 0.99,
					float(b["z"]) + 0.014 - v * 0.018 + sin(v * 3.2 + float(k)) * 0.010))
			var strand: MeshInstance3D = MeshInstance3D.new()
			strand.mesh = _tube(pts, [0.017, 0.015, 0.012, 0.009, 0.006, 0.003, 0.001], 5)
			strand.material_override = kit.hair
			head.add_child(strand)

	# боковые локоны вдоль щёк
	for side in [-1.0, 1.0]:
		for k in range(2):
			var pts: Array = []
			for j in range(7):
				var v: float = float(j) / 6.0
				pts.append(Vector3(
					side * (0.084 + float(k) * 0.013) + sin(v * 3.2 + float(k)) * 0.012,
					0.175 - v * (0.30 + float(k) * 0.09),
					-0.030 + sin(v * 2.4 + float(k) * 1.3) * 0.018 - v * 0.010))
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = _tube(pts, [0.019, 0.017, 0.014, 0.011, 0.008, 0.005, 0.002], 6)
			mi.material_override = kit.hair
			head.add_child(mi)

	# сплошная масса чёлки над бровями
	_add(head, _sphere(0.072, 16, 10), kit.hair, Vector3(0.0, 0.202, -0.048),
			Vector3(0.0, 0.0, 0.0), Vector3(1.02, 0.30, 0.42))
	for side in [-1.0, 1.0]:
		_add(head, _sphere(0.050, 12, 8), kit.hair,
				Vector3(side * 0.060, 0.178, -0.062), Vector3(0.0, side * 0.2, side * 0.2),
				Vector3(0.70, 0.55, 0.55))

	# чёлка: пять широких прядей, разлетаются от пробора
	for i in range(5):
		var t: float = float(i) / 4.0 - 0.5
		var side: float = signf(t) if absf(t) > 0.001 else 1.0
		var end_x: float = t * 0.24
		var end_y: float = 0.170 - absf(t) * 0.045
		var pts: Array = [
			Vector3(t * 0.060, 0.205, -0.048),
			Vector3(t * 0.090, 0.196, -0.075),
			Vector3(t * 0.120, 0.186, -0.094),
			Vector3(t * 0.160, 0.178, -0.100),
			Vector3(end_x, end_y, -0.096),
		]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _tube(pts, [0.017, 0.016, 0.013, 0.009, 0.002], 5)
		mi.material_override = kit.hair
		head.add_child(mi)
		# вторая, более тонкая прядь рядом
		var pts2: Array = []
		for p in pts:
			pts2.append(p + Vector3(side * 0.012, -0.008, 0.006))
		var mi2: MeshInstance3D = MeshInstance3D.new()
		mi2.mesh = _tube(pts2, [0.010, 0.009, 0.007, 0.005, 0.001], 5)
		mi2.material_override = kit.hair_hi
		head.add_child(mi2)

	# отдельные длинные пряди у лица
	for side in [-1.0, 1.0]:
		var pts: Array = [
			Vector3(side * 0.088, 0.180, -0.010),
			Vector3(side * 0.102, 0.145, -0.040),
			Vector3(side * 0.108, 0.100, -0.052),
			Vector3(side * 0.100, 0.060, -0.044),
			Vector3(side * 0.094, 0.020, -0.030),
		]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _tube(pts, [0.012, 0.010, 0.008, 0.005, 0.002], 5)
		mi.material_override = kit.hair_hi
		head.add_child(mi)

	# разлетающиеся пряди
	for side in [-1.0, 1.0]:
		var pts: Array = [
			Vector3(side * 0.088, 0.190, 0.020),
			Vector3(side * 0.125, 0.176, 0.048),
			Vector3(side * 0.148, 0.140, 0.085),
			Vector3(side * 0.138, 0.100, 0.120),
		]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _tube(pts, [0.010, 0.008, 0.005, 0.0015], 5)
		mi.material_override = kit.hair_hi
		head.add_child(mi)
	return nodes

# =========================================================================
#  Шляпа
# =========================================================================

static func _build_hat(head: Node3D, kit: Kit) -> Node3D:
	var hat: Node3D = _pivot(head, "Hat", Vector3(0.0, 0.232, 0.004),
			Vector3(-0.05, 0.0, 0.0))

	# поля: верх чёрный, изнанка янтарная, бока подняты
	var top: MeshInstance3D = MeshInstance3D.new()
	top.mesh = _brim_mesh(0.0)
	top.material_override = kit.hat
	hat.add_child(top)
	var under: MeshInstance3D = MeshInstance3D.new()
	under.mesh = _brim_mesh(-0.010)
	under.material_override = kit.lining
	under.position = Vector3(0.0, -0.003, 0.0)
	hat.add_child(under)
	var edge: MeshInstance3D = MeshInstance3D.new()
	edge.mesh = _brim_edge()
	edge.material_override = kit.leather_dark
	hat.add_child(edge)

	# тулья: сужается кверху, с мягкой макушкой
	_add(hat, _cyl(0.108, 0.150, 0.130, 24), kit.hat, Vector3(0.0, 0.066, 0.0))
	_add(hat, _sphere(0.109, 22, 12), kit.hat, Vector3(0.0, 0.126, 0.0),
			Vector3.ZERO, Vector3(1.0, 0.42, 1.0))
	# лента и золотая кромка
	_add(hat, _cyl(0.153, 0.157, 0.040, 24), kit.leather, Vector3(0.0, 0.010, 0.0))
	_add(hat, _cyl(0.158, 0.158, 0.006, 24), kit.gold_dark, Vector3(0.0, 0.030, 0.0))
	# швы тульи
	for i in range(4):
		var ang: float = TAU * float(i) / 4.0 + 0.5
		_add(hat, _box(Vector3(0.0055, 0.165, 0.0055)), kit.leather_dark,
				Vector3(cos(ang) * 0.126, 0.078, sin(ang) * 0.126), Vector3(0.0, -ang, 0.0))

	# брошь на тулье
	var brooch: Node3D = _pivot(hat, "Brooch", Vector3(-0.058, 0.092, -0.128),
			Vector3(-0.08, 0.26, 0.0))
	_add(brooch, _torus(0.021, 0.031, 18, 8), kit.gold, Vector3.ZERO,
			Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 0.70, 1.0))
	_add(brooch, _sphere(0.022, 14, 10), kit.gold_dark, Vector3(0.0, 0.0, 0.003),
			Vector3.ZERO, Vector3(1.0, 0.70, 0.26))
	_add(brooch, _sphere(0.018, 14, 10), kit.skin_shade, Vector3(0.0, 0.0, -0.006),
			Vector3.ZERO, Vector3(1.0, 0.68, 0.34))
	_add(brooch, _sphere(0.008, 8, 6), kit.eye_glint, Vector3(-0.006, 0.005, -0.014))
	return hat

# =========================================================================
#  Руки и кисти
# =========================================================================

static func _build_arm(torso: Node3D, side: float, is_right: bool, kit: Kit) -> Dictionary:
	var suffix: String = "R" if is_right else "L"
	var shoulder: Node3D = _pivot(torso, "Shoulder" + suffix,
			Vector3(side * 0.196, 0.360, 0.0),
			Vector3(0.04, 0.0, side * 0.07))

	_add(shoulder, _capsule(0.049, 0.315, 12), kit.cloth, Vector3(0.0, -0.150, 0.0))
	_add(shoulder, _cyl(0.053, 0.055, 0.070, 14), kit.cloth_dark, Vector3(0.0, -0.105, 0.0))
	_add(shoulder, _cyl(0.051, 0.051, 0.020, 14), kit.leather, Vector3(0.0, -0.245, 0.0))
	_add(shoulder, _sphere(0.054, 12, 8), kit.cloth_dark, Vector3(0.0, -0.295, 0.0))

	var elbow: Node3D = _pivot(shoulder, "Elbow" + suffix, Vector3(0.0, -0.300, 0.0),
			Vector3(0.30, 0.0, 0.0))
	# локоть и наруч
	_add(elbow, _sphere(0.053, 14, 8), kit.leather, Vector3(0.0, 0.005, -0.004),
			Vector3.ZERO, Vector3(1.0, 0.92, 1.02))
	_add(elbow, _sphere(0.030, 10, 6), kit.leather_dark,
			Vector3(0.0, 0.012, -0.046), Vector3.ZERO, Vector3(1.0, 0.9, 0.5))
	_add(elbow, _capsule(0.042, 0.290, 12), kit.cloth, Vector3(0.0, -0.150, 0.0))
	# широкий наруч с золотой кромкой
	_add(elbow, _cyl(0.048, 0.058, 0.190, 16), kit.leather, Vector3(0.0, -0.155, 0.0))
	_add(elbow, _cyl(0.060, 0.060, 0.014, 16), kit.gold_dark, Vector3(0.0, -0.062, 0.0))
	_add(elbow, _cyl(0.049, 0.049, 0.014, 16), kit.gold_dark, Vector3(0.0, -0.248, 0.0))
	_add(elbow, _box(Vector3(0.016, 0.150, 0.014)), kit.gold_dark,
			Vector3(side * 0.048, -0.160, 0.0))
	_add(elbow, _sphere(0.007, 8, 6), kit.gold, Vector3(side * 0.053, -0.100, 0.0))
	_add(elbow, _sphere(0.007, 8, 6), kit.gold, Vector3(side * 0.053, -0.215, 0.0))

	var wrist: Node3D = _pivot(elbow, "Wrist" + suffix, Vector3(0.0, -0.290, 0.0))
	_add(wrist, _cyl(0.043, 0.040, 0.055, 14), kit.leather_dark, Vector3(0.0, -0.010, 0.0))
	_build_hand(wrist, side, kit)

	var grip: Node3D = _pivot(wrist, "Grip", Vector3(0.0, -0.055, -0.004),
			Vector3(PI, 0.0, 0.0))
	if is_right:
		return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist, "grip": grip,
				"weapon": grip}
	return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist, "grip": grip,
			"weapon": grip}

static func _build_hand(wrist: Node3D, side: float, kit: Kit) -> void:
	# ладонь
	_add(wrist, _box(Vector3(0.072, 0.090, 0.038)), kit.skin, Vector3(0.0, -0.048, 0.0),
			Vector3(0.04, 0.0, side * 0.03))
	_add(wrist, _sphere(0.036, 12, 8), kit.skin, Vector3(0.0, -0.082, 0.0),
			Vector3.ZERO, Vector3(0.95, 0.70, 0.62))
	# костяшки
	for i in range(4):
		_add(wrist, _sphere(0.0095, 8, 6), kit.skin,
				Vector3(-0.0255 + float(i) * 0.017, -0.088, -0.012))
	# пальцы: три фаланги, лёгкий изгиб внутрь
	for i in range(4):
		var x: float = -0.0255 + float(i) * 0.017
		var length: float = 0.050 if i == 1 or i == 2 else 0.043
		var curl: float = 0.10 + float(i) * 0.015
		var y0: float = -0.088
		var z0: float = -0.010
		for seg in range(3):
			var seg_len: float = length * (0.40 - float(seg) * 0.06)
			var ang: float = curl * float(seg + 1)
			var mi: MeshInstance3D = _add(wrist, _capsule(0.0062, seg_len + 0.004, 6),
					kit.skin, Vector3(x, y0 - seg_len * 0.5, z0))
			mi.rotation.x = ang
			y0 -= cos(ang) * seg_len
			z0 -= sin(ang) * seg_len
		# ноготь
		_add(wrist, _box(Vector3(0.009, 0.012, 0.005)), kit.fang,
				Vector3(x, y0 + 0.006, z0 - 0.002), Vector3(curl * 3.0, 0.0, 0.0))
	# большой палец
	var thumb: Node3D = _pivot(wrist, "Thumb", Vector3(side * 0.034, -0.045, -0.004),
			Vector3(-0.25, 0.0, side * 0.85))
	_add(thumb, _capsule(0.0085, 0.040, 6), kit.skin, Vector3(0.0, -0.020, 0.0))
	var thumb2: Node3D = _pivot(thumb, "Thumb2", Vector3(0.0, -0.042, 0.0),
			Vector3(-0.30, 0.0, 0.0))
	_add(thumb2, _capsule(0.0072, 0.030, 6), kit.skin, Vector3(0.0, -0.014, 0.0))
	_add(thumb2, _box(Vector3(0.008, 0.010, 0.005)), kit.fang, Vector3(0.0, -0.028, -0.003))
	# вена/сухожилие на тыле кисти
	_add(wrist, _box(Vector3(0.004, 0.045, 0.004)), kit.skin_shade,
			Vector3(side * 0.012, -0.050, -0.019), Vector3(0.0, 0.0, side * 0.10))

# =========================================================================
#  Меч, ножны, рукоять за спиной
# =========================================================================

static func _build_sword(parent: Node3D, kit: Kit) -> Node3D:
	var sword: Node3D = Node3D.new()
	sword.name = "Sword"
	parent.add_child(sword)
	sword.visible = false

	# клинок: узкий, с долом
	var blade: MeshInstance3D = MeshInstance3D.new()
	blade.mesh = _blade_mesh(1.02, 0.028, 0.0058)
	blade.material_override = kit.blade
	blade.position = Vector3(0.0, 0.105, 0.0)
	sword.add_child(blade)
	# пята клинка
	_add(sword, _box(Vector3(0.052, 0.030, 0.016)), kit.steel, Vector3(0.0, 0.098, 0.0))

	# гарда: золото, загнутые концы
	_add(sword, _box(Vector3(0.115, 0.020, 0.030)), kit.gold, Vector3(0.0, 0.088, 0.0))
	for side in [-1.0, 1.0]:
		_add(sword, _box(Vector3(0.070, 0.014, 0.022)), kit.gold,
				Vector3(side * 0.085, 0.094, 0.0), Vector3(0.0, 0.0, side * 0.30))
		_add(sword, _sphere(0.012, 10, 8), kit.gold_dark,
				Vector3(side * 0.118, 0.104, 0.0))
		_add(sword, _cone(0.010, 0.004, 0.030, 6), kit.gold,
				Vector3(side * 0.130, 0.118, 0.0), Vector3(0.0, 0.0, side * 0.5))
	_add(sword, _sphere(0.011, 10, 8), kit.gem, Vector3(0.0, 0.088, -0.020),
			Vector3.ZERO, Vector3(1.0, 1.0, 0.5))

	# рукоять: тёмно-красная кожа, золотая обмотка
	_add(sword, _cyl(0.0155, 0.0175, 0.190, 12), kit.lip, Vector3(0.0, 0.0, 0.0))
	for i in range(6):
		_add(sword, _torus(0.0165, 0.0195, 10, 5), kit.gold_dark,
				Vector3(0.0, -0.070 + float(i) * 0.028, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	# навершие
	_add(sword, _cyl(0.024, 0.030, 0.020, 12), kit.gold, Vector3(0.0, -0.104, 0.0))
	_add(sword, _sphere(0.026, 12, 10), kit.gold, Vector3(0.0, -0.123, 0.0),
			Vector3.ZERO, Vector3(1.0, 0.86, 1.0))
	_add(sword, _sphere(0.010, 8, 6), kit.gem, Vector3(0.0, -0.136, -0.014),
			Vector3.ZERO, Vector3(1.0, 1.0, 0.6))
	return sword

static func _build_scabbard(mount: Node3D, kit: Kit) -> void:
	# ножны уходят вниз по −Y от устья
	_add(mount, _box(Vector3(0.062, 0.640, 0.026)), kit.leather_dark,
			Vector3(0.0, -0.320, 0.0))
	_add(mount, _box(Vector3(0.050, 0.420, 0.020)), kit.leather_dark,
			Vector3(0.0, -0.840, 0.0))
	_add(mount, _cyl(0.028, 0.012, 0.065, 8), kit.gold_dark, Vector3(0.0, -1.070, 0.0))
	# устье и обоймицы
	_add(mount, _box(Vector3(0.076, 0.042, 0.034)), kit.gold, Vector3(0.0, -0.006, 0.0))
	_add(mount, _box(Vector3(0.070, 0.026, 0.030)), kit.gold_dark, Vector3(0.0, -0.300, 0.0))
	_add(mount, _box(Vector3(0.060, 0.022, 0.026)), kit.gold_dark, Vector3(0.0, -0.640, 0.0))
	_add(mount, _box(Vector3(0.054, 0.018, 0.024)), kit.gold, Vector3(0.0, -0.960, 0.0))
	# кожаный ремень через ножны
	_add(mount, _box(Vector3(0.084, 0.028, 0.040)), kit.leather, Vector3(0.0, -0.210, 0.0))
	_add(mount, _box(Vector3(0.026, 0.024, 0.012)), kit.silver, Vector3(0.0, -0.210, -0.022))

static func _build_hilt_prop(mount: Node3D, kit: Kit) -> Node3D:
	var hilt: Node3D = Node3D.new()
	hilt.name = "HiltProp"
	mount.add_child(hilt)

	_add(hilt, _box(Vector3(0.108, 0.019, 0.028)), kit.gold, Vector3(0.0, 0.008, 0.0))
	for side in [-1.0, 1.0]:
		_add(hilt, _box(Vector3(0.062, 0.013, 0.020)), kit.gold,
				Vector3(side * 0.080, 0.014, 0.0), Vector3(0.0, 0.0, side * 0.28))
		_add(hilt, _sphere(0.011, 8, 6), kit.gold_dark,
				Vector3(side * 0.108, 0.024, 0.0))
	# рукоять вверх
	_add(hilt, _cyl(0.0165, 0.0185, 0.195, 12), kit.lip, Vector3(0.0, 0.115, 0.0))
	for i in range(6):
		_add(hilt, _torus(0.0175, 0.0205, 10, 5), kit.gold_dark,
				Vector3(0.0, 0.048 + float(i) * 0.028, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	_add(hilt, _cyl(0.024, 0.030, 0.020, 12), kit.gold, Vector3(0.0, 0.218, 0.0))
	_add(hilt, _sphere(0.026, 12, 10), kit.gold, Vector3(0.0, 0.236, 0.0),
			Vector3.ZERO, Vector3(1.0, 0.86, 1.0))
	return hilt

static func _blade_mesh(length: float, half_width: float, half_thick: float) -> ArrayMesh:
	var profile: Array = [
		Vector2(-1.0, 0.0), Vector2(-0.52, -1.0), Vector2(0.0, -0.55), Vector2(0.52, -1.0),
		Vector2(1.0, 0.0), Vector2(0.52, 1.0), Vector2(0.0, 0.55), Vector2(-0.52, 1.0),
	]
	var ts: Array = [0.0, 0.45, 0.68, 0.84, 0.95, 1.0]
	var ws: Array = [1.0, 0.98, 0.92, 0.72, 0.38, 0.010]
	var hs: Array = [1.0, 0.98, 0.92, 0.74, 0.40, 0.010]

	var rings: Array = []
	var normals: Array = []
	for r in range(ts.size()):
		var ring: Array = []
		var nring: Array = []
		for j in range(profile.size()):
			var p: Vector2 = profile[j]
			ring.append(Vector3(p.x * half_width * float(ws[r]), float(ts[r]) * length,
					p.y * half_thick * float(hs[r])))
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
	return st.commit()

# =========================================================================
#  Пламя в левой руке
# =========================================================================

static func _build_ember(wrist: Node3D, kit: Kit) -> Dictionary:
	var pivot: Node3D = Node3D.new()
	pivot.name = "Ember"
	pivot.position = Vector3(0.0, -0.150, -0.030)
	pivot.visible = false
	wrist.add_child(pivot)

	var flame: MeshInstance3D = MeshInstance3D.new()
	var fm: SphereMesh = SphereMesh.new()
	fm.radius = 0.038
	fm.height = 0.115
	fm.radial_segments = 12
	fm.rings = 8
	flame.mesh = fm
	flame.material_override = kit.ember
	pivot.add_child(flame)
	_add(pivot, _sphere(0.020, 10, 8), kit.ember_core, Vector3(0.0, -0.008, 0.0),
			Vector3.ZERO, Vector3(1.0, 1.5, 1.0))
	for i in range(5):
		var ang: float = TAU * float(i) / 5.0
		_add(pivot, _sphere(0.0035, 6, 6), kit.ember_core,
				Vector3(cos(ang) * 0.025, 0.030 + 0.018 * sin(ang), sin(ang) * 0.025))

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.34)
	light.light_energy = 0.0
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	pivot.add_child(light)

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = 18
	particles.lifetime = 0.55
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.028
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 22.0
	particles.gravity = Vector3(0.0, 0.9, 0.0)
	particles.initial_velocity_min = 0.10
	particles.initial_velocity_max = 0.30
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 0.8
	particles.color = Color(1.0, 0.55, 0.18, 0.8)
	particles.emitting = false
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	particles.mesh = quad
	var pm: StandardMaterial3D = StandardMaterial3D.new()
	pm.albedo_color = Color(1.0, 0.6, 0.25, 0.8)
	pm.emission_enabled = true
	pm.emission = Color(1.0, 0.55, 0.2)
	pm.emission_energy_multiplier = 5.0
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = pm
	pivot.add_child(particles)

	return {"pivot": pivot, "flame": flame, "light": light, "particles": particles}

# =========================================================================
#  Процедурные меши
# =========================================================================

## Лоскут ткани: провисает, колышется, снизу рваный.
static func _cloth(top_width: float, bottom_width: float, length: float,
		cols: int, rows: int, sag: float, billow: float, ragged: float,
		seed: float, flip: bool = false) -> ArrayMesh:
	var grid: Array = []
	for j in range(rows + 1):
		var v: float = float(j) / float(rows)
		var w: float = lerpf(top_width, bottom_width, v)
		for i in range(cols + 1):
			var u: float = float(i) / float(cols)
			var x: float = (u - 0.5) * w
			var y: float = -v * length
			var z: float = sin(u * PI) * sag * sin(v * PI * 0.85)
			z += sin(u * PI * 2.0 + seed) * billow * v * v
			y -= pow(v, 4.0) * ragged * (0.55 + 0.45 * sin(u * 15.0 + seed))
			grid.append(Vector3(x, y, z))

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := func(i: int, j: int) -> int:
		return j * (cols + 1) + i
	for j in range(rows):
		for i in range(cols):
			var a: int = idx.call(i, j)
			var b: int = idx.call(i + 1, j)
			var c: int = idx.call(i + 1, j + 1)
			var d: int = idx.call(i, j + 1)
			if not flip:
				_tri(st, grid[a], grid[b], grid[c], Vector2(float(i) / cols, 1.0 - float(j) / rows),
						Vector2(float(i + 1) / cols, 1.0 - float(j) / rows),
						Vector2(float(i + 1) / cols, 1.0 - float(j + 1) / rows))
				_tri(st, grid[a], grid[c], grid[d], Vector2(float(i) / cols, 1.0 - float(j) / rows),
						Vector2(float(i + 1) / cols, 1.0 - float(j + 1) / rows),
						Vector2(float(i) / cols, 1.0 - float(j + 1) / rows))
			else:
				_tri(st, grid[a], grid[c], grid[b], Vector2(float(i) / cols, 1.0 - float(j) / rows),
						Vector2(float(i + 1) / cols, 1.0 - float(j + 1) / rows),
						Vector2(float(i + 1) / cols, 1.0 - float(j) / rows))
				_tri(st, grid[a], grid[d], grid[c], Vector2(float(i) / cols, 1.0 - float(j) / rows),
						Vector2(float(i) / cols, 1.0 - float(j + 1) / rows),
						Vector2(float(i + 1) / cols, 1.0 - float(j + 1) / rows))
	st.generate_normals()
	return st.commit()

## Трубка по точкам: волосы, рога, шнуры.
static func _tube(points: Array, radii: Array, sides: int = 6) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(0, i - 1)]
		var next: Vector3 = points[mini(points.size() - 1, i + 1)]
		var tangent: Vector3 = (next - prev)
		if tangent.length() < 0.0001:
			tangent = Vector3.DOWN
		tangent = tangent.normalized()
		var up: Vector3 = Vector3.UP
		if absf(tangent.dot(up)) > 0.95:
			up = Vector3.BACK
		var side_v: Vector3 = tangent.cross(up).normalized()
		var nrm: Vector3 = side_v.cross(tangent).normalized()
		var radius: float = float(radii[i])
		var ring: Array = []
		for s in range(sides):
			var a: float = TAU * float(s) / float(sides)
			ring.append(p + side_v * cos(a) * radius + nrm * sin(a) * radius)
		rings.append(ring)
	for i in range(rings.size() - 1):
		for s in range(sides):
			var s2: int = (s + 1) % sides
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][s2]
			var c: Vector3 = rings[i + 1][s2]
			var d: Vector3 = rings[i + 1][s]
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(a)
			st.add_vertex(d)
			st.add_vertex(c)
	st.generate_normals()
	return st.commit()

## Поля шляпы: широкий диск с подъёмом и острыми кончиками по бокам.
static func _brim_mesh(y_shift: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = 56
	var rings: int = 5
	var grid: Array = []
	for r in range(rings):
		var t: float = float(r) / float(rings - 1)
		for s in range(seg):
			var ang: float = TAU * float(s) / float(seg)
			var side_bump: float = pow(absf(cos(ang)), 3.2)
			var outer: float = 0.144 + t * (0.170 + 0.032 * side_bump)
			var y: float = 0.008 - 0.030 * t + pow(t, 1.6) * (0.086 * side_bump
					+ 0.022 * pow(absf(sin(ang)), 4.0))
			grid.append(Vector3(cos(ang) * outer, y + y_shift, sin(ang) * outer))
	var idx := func(r: int, s: int) -> int:
		return r * seg + (s % seg)
	for r in range(rings - 1):
		for s in range(seg):
			var a: int = idx.call(r, s)
			var b: int = idx.call(r, s + 1)
			var c: int = idx.call(r + 1, s + 1)
			var d: int = idx.call(r + 1, s)
			st.add_vertex(grid[a])
			st.add_vertex(grid[b])
			st.add_vertex(grid[c])
			st.add_vertex(grid[a])
			st.add_vertex(grid[c])
			st.add_vertex(grid[d])
	st.generate_normals()
	return st.commit()

static func _brim_edge() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = 56
	var top: Array = []
	var bot: Array = []
	for s in range(seg):
		var ang: float = TAU * float(s) / float(seg)
		var side_bump: float = pow(absf(cos(ang)), 3.2)
		var outer: float = 0.314 + 0.032 * side_bump
		var y: float = 0.008 - 0.030 + 0.086 * side_bump + 0.022 * pow(absf(sin(ang)), 4.0)
		top.append(Vector3(cos(ang) * outer, y, sin(ang) * outer))
		bot.append(Vector3(cos(ang) * outer, y - 0.010, sin(ang) * outer))
	for s in range(seg):
		var s2: int = (s + 1) % seg
		st.add_vertex(top[s])
		st.add_vertex(bot[s])
		st.add_vertex(bot[s2])
		st.add_vertex(top[s])
		st.add_vertex(bot[s2])
		st.add_vertex(top[s2])
	st.generate_normals()
	return st.commit()

# =========================================================================
#  Узлы и примитивы
# =========================================================================

static func _pivot(parent: Node3D, node_name: String, pos: Vector3,
		rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	return n

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO,
		rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
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

static func _cone(top: float, bottom: float, height: float, segments: int = 12) -> CylinderMesh:
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
	m.rings = 4
	return m

static func _torus(inner: float, outer: float, rings: int = 16, segments: int = 6) -> TorusMesh:
	var m: TorusMesh = TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = segments
	return m

static func _vert(st: SurfaceTool, v: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(v)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
