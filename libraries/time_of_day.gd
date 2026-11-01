class_name TimeOfDay
extends RefCounted

## Пресеты суток. День намеренно приглушённый: лес должен оставаться мрачным.

const ORDER := ["evening", "night", "morning", "day"]

const PRESETS := {
	"night": {
		"label": "Ночь",
		"ambient": Color(0.19, 0.26, 0.40),
		"ambient_energy": 0.24,
		"sun": Color(0.50, 0.64, 0.92),
		"sun_energy": 0.95,
		"sun_rot": Vector3(-38.0, 28.0, 0.0),
		"fog": Color(0.05, 0.07, 0.11),
		"fog_density": 0.038,
		"vol_density": 0.014,
		"vol_albedo": Color(0.52, 0.60, 0.74),
		"sky_top": Color(0.006, 0.010, 0.022),
		"sky_horizon": Color(0.020, 0.028, 0.045),
		"stars": 6.5,
		"moon_dir": Vector3(0.45, 0.55, -0.70),
		"moon": 1.0,
		"clouds": 0.42,
		"cloud_color": Color(0.05, 0.06, 0.09),
		"cloud_lit": Color(0.30, 0.34, 0.42),
		"exposure": 0.92,
		"contrast": 1.18,
	},
	"morning": {
		"label": "Утро",
		"ambient": Color(0.42, 0.46, 0.54),
		"ambient_energy": 0.42,
		"sun": Color(0.92, 0.86, 0.76),
		"sun_energy": 0.85,
		"sun_rot": Vector3(-16.0, 62.0, 0.0),
		"fog": Color(0.26, 0.29, 0.33),
		"fog_density": 0.055,
		"vol_density": 0.026,
		"vol_albedo": Color(0.70, 0.74, 0.80),
		"sky_top": Color(0.12, 0.16, 0.24),
		"sky_horizon": Color(0.42, 0.40, 0.44),
		"stars": 0.6,
		"moon_dir": Vector3(0.30, 0.62, 0.72),
		"moon": 0.25,
		"clouds": 0.55,
		"cloud_color": Color(0.22, 0.24, 0.28),
		"cloud_lit": Color(0.55, 0.56, 0.60),
		"exposure": 0.90,
		"contrast": 1.08,
	},
	"day": {
		"label": "День",
		"ambient": Color(0.46, 0.50, 0.56),
		"ambient_energy": 0.45,
		"sun": Color(0.90, 0.89, 0.84),
		"sun_energy": 0.95,
		"sun_rot": Vector3(-58.0, 40.0, 0.0),
		"fog": Color(0.30, 0.33, 0.37),
		"fog_density": 0.032,
		"vol_density": 0.012,
		"vol_albedo": Color(0.68, 0.72, 0.78),
		"sky_top": Color(0.22, 0.30, 0.42),
		"sky_horizon": Color(0.48, 0.50, 0.54),
		"stars": 0.0,
		"moon_dir": Vector3(0.20, 0.90, 0.30),
		"moon": 0.0,
		"clouds": 0.60,
		"cloud_color": Color(0.34, 0.37, 0.42),
		"cloud_lit": Color(0.62, 0.64, 0.68),
		"exposure": 0.84,
		"contrast": 1.04,
	},
	"evening": {
		"label": "Вечер",
		"ambient": Color(0.34, 0.28, 0.28),
		"ambient_energy": 0.30,
		"sun": Color(1.0, 0.62, 0.38),
		"sun_energy": 1.15,
		"sun_rot": Vector3(-11.0, -96.0, 0.0),
		"fog": Color(0.20, 0.15, 0.15),
		"fog_density": 0.040,
		"vol_density": 0.016,
		"vol_albedo": Color(0.72, 0.58, 0.52),
		"sky_top": Color(0.07, 0.08, 0.15),
		"sky_horizon": Color(0.46, 0.26, 0.20),
		"stars": 1.6,
		"moon_dir": Vector3(-0.65, 0.40, 0.64),
		"moon": 0.85,
		"clouds": 0.40,
		"cloud_color": Color(0.14, 0.10, 0.10),
		"cloud_lit": Color(0.52, 0.32, 0.24),
		"exposure": 0.94,
		"contrast": 1.12,
	},
}

static func label(key: String) -> String:
	var preset: Dictionary = PRESETS.get(key, PRESETS["night"])
	return preset["label"]

static func next_key(current: String) -> String:
	var i := ORDER.find(current)
	return ORDER[(i + 1) % ORDER.size()]

static func apply(key: String, env: Environment, sun: DirectionalLight3D, sky_mat: ShaderMaterial) -> void:
	var p: Dictionary = PRESETS.get(key, PRESETS["night"])

	env.ambient_light_color = p["ambient"]
	env.ambient_light_energy = p["ambient_energy"]
	env.fog_light_color = p["fog"]
	env.fog_density = p["fog_density"]
	env.volumetric_fog_density = p["vol_density"]
	env.volumetric_fog_albedo = p["vol_albedo"]
	env.tonemap_exposure = p["exposure"]
	env.adjustment_contrast = p["contrast"]

	sun.light_color = p["sun"]
	sun.light_energy = p["sun_energy"]
	var rot: Vector3 = p["sun_rot"]
	sun.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), 0.0)

	if sky_mat != null:
		sky_mat.set_shader_parameter("top_color", p["sky_top"])
		sky_mat.set_shader_parameter("horizon_color", p["sky_horizon"])
		sky_mat.set_shader_parameter("star_brightness", p["stars"])
		sky_mat.set_shader_parameter("moon_glow", p["moon"])
		sky_mat.set_shader_parameter("cloud_cover", p["clouds"])
		sky_mat.set_shader_parameter("cloud_color", p["cloud_color"])
		sky_mat.set_shader_parameter("cloud_lit", p["cloud_lit"])

		sky_mat.set_shader_parameter("moon_dir", (p["moon_dir"] as Vector3).normalized())
