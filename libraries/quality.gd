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
