class_name Quality
extends RefCounted

## Пресеты качества. Применяются при построении мира.

const LEVELS := ["low", "medium", "high"]
const LABELS := {"low": "Низкое", "medium": "Среднее", "high": "Высокое"}

static var level := "medium"

static func grass_amount() -> int:
	match level:
		"low":
			return 55000
		"high":
			return 120000
		_:
			return 85000

static func grass_radius() -> float:
	match level:
		"low":
			return 32.0
		"high":
			return 46.0
		_:
			return 40.0

## Слои травы: чем дальше, тем реже — на расстоянии травинка всё равно
## меньше пикселя. inner_radius считается от предыдущего слоя.
static func grass_layers() -> Array:
	match level:
		"low":
			return [
				{"r": 6.0, "density": 160, "cell": 2.0},
				{"r": 14.0, "density": 55, "cell": 3.0},
				{"r": 28.0, "density": 18, "cell": 5.0},
			]
		"high":
			return [
				{"r": 8.0, "density": 320, "cell": 2.0},
				{"r": 18.0, "density": 110, "cell": 3.0},
				{"r": 44.0, "density": 34, "cell": 5.0},
			]
		_:
			return [
				{"r": 7.0, "density": 250, "cell": 2.0},
				{"r": 16.0, "density": 85, "cell": 3.0},
				{"r": 38.0, "density": 24, "cell": 5.0},
			]

static func apply(env: Environment, sun: DirectionalLight3D) -> void:
	if env == null:
		return
	match level:
		"low":
			env.sdfgi_enabled = false
			env.volumetric_fog_enabled = false
			env.ssr_enabled = false
			env.ssao_enabled = false
			if sun != null:
				sun.shadow_enabled = false
		"high":
			env.sdfgi_enabled = true
			env.volumetric_fog_enabled = true
			env.ssr_enabled = true
			env.ssao_enabled = true
			if sun != null:
				sun.shadow_enabled = true
		_:
			env.sdfgi_enabled = true
			env.volumetric_fog_enabled = true
			env.ssr_enabled = true
			env.ssao_enabled = true
			if sun != null:
				sun.shadow_enabled = true

static func label() -> String:
	return LABELS.get(level, LABELS["medium"])

static func next() -> void:
	var i := LEVELS.find(level)
	level = LEVELS[(i + 1) % LEVELS.size()]
