extends CanvasLayer

var player

var _root: Control
var _hp: ProgressBar
var _sp: ProgressBar
var _souls_label: Label
var _flask_label: Label
var _torch_label: Label
var _notice_label: Label
var _level_panel: Control
var _level_title: Label
var _level_cost: Label
var _level_rows: Array[Label] = []
var levels_visible := false
var _hurt: ColorRect

var _notice_timer := 0.0
var _hurt_alpha := 0.0
var _last_health := -1.0

func _ready() -> void:
	layer = 10

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_hurt = ColorRect.new()
	_hurt.color = Color(0.7, 0.0, 0.0, 0.0)
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_shader := Shader.new()
	vignette_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = SCREEN_UV;
	float d = distance(uv, vec2(0.5, 0.5));
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.42, 0.95, d) * 0.8);
}
"""
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = vignette_shader
	vignette.material = vignette_mat
	_root.add_child(vignette)

	_hp = _make_bar(Vector2(36, 634), Vector2(320, 16), Color(0.52, 0.10, 0.10))
	_sp = _make_bar(Vector2(36, 658), Vector2(320, 9), Color(0.36, 0.52, 0.26))

	_flask_label = _make_label(Vector2(36, 596), Vector2(320, 24), 16)
	_flask_label.text = "Фляга: 3"

	_build_level_panel()

	_torch_label = _make_label(Vector2(36, 570), Vector2(320, 24), 16)
	_torch_label.text = "Факел: 100%"

	_souls_label = _make_label(Vector2(900, 28), Vector2(340, 32), 20)
	_souls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_souls_label.text = "Души: 0"

	_notice_label = _make_label(Vector2(0, 96), Vector2(1280, 40), 22)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.modulate.a = 0.0

	var hint := _make_label(Vector2(0, 690), Vector2(1280, 24), 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.text = "WASD — идти    ЛКМ — удар    Пробел — перекат    Tab — захват    ПКМ — блок    Q — фляга    F — факел    E — костёр"

func _build_level_panel() -> void:
	_level_panel = Control.new()
	_level_panel.position = Vector2(320, 150)
	_level_panel.size = Vector2(640, 360)
	_level_panel.visible = false
	_level_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_level_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025, 0.88)
	bg.size = Vector2(640, 360)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_panel.add_child(bg)

	var frame := ColorRect.new()
	frame.color = Color(0.35, 0.30, 0.22, 0.9)
	frame.position = Vector2(0, 0)
	frame.size = Vector2(640, 2)
	_level_panel.add_child(frame)
	var frame2 := ColorRect.new()
	frame2.color = Color(0.35, 0.30, 0.22, 0.9)
	frame2.position = Vector2(0, 358)
	frame2.size = Vector2(640, 2)
	_level_panel.add_child(frame2)

	_level_title = _make_label(Vector2(28, 22), Vector2(580, 34), 24, _level_panel)
	_level_title.text = "У КОСТРА"

	_level_cost = _make_label(Vector2(28, 62), Vector2(580, 26), 16, _level_panel)
	_level_cost.text = ""

	for i in 4:
		var row := _make_label(Vector2(28, 110 + i * 44), Vector2(584, 34), 18, _level_panel)
		_level_rows.append(row)

	var foot := _make_label(Vector2(28, 300), Vector2(584, 26), 15, _level_panel)
	foot.modulate = Color(1, 1, 1, 0.6)
	foot.text = "1-4 — вложить души    E — закрыть"

func show_levels(target) -> void:
	levels_visible = true
	_level_panel.visible = true
	refresh_levels(target)

func hide_levels() -> void:
	levels_visible = false
	_level_panel.visible = false

func refresh_levels(target) -> void:
	if target == null:
		return
	_level_title.text = "УРОВЕНЬ %d" % target.soul_level
	_level_cost.text = "Души: %d      Следующий уровень: %d" % [target.souls, target.level_cost()]
	var rows := [
		"1   Сила              %d      урон +%d" % [target.strength, int(target.strength * 6)],
		"2   Выносливость      %d      здоровье +%d" % [target.endurance, int(target.endurance * 15)],
		"3   Чутьё             %d      захват +%d м" % [target.perception, int(target.perception * 3)],
		"4   Ремесло           %d      фляга +%d" % [target.craft, int(target.craft * 15)],
	]
	for i in rows.size():
		_level_rows[i].text = rows[i]

func _make_bar(pos: Vector2, size: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = size
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.03, 0.8)
	bg.border_color = Color(0.32, 0.28, 0.22, 0.9)
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill)

	_root.add_child(bar)
	return bar

func _make_label(pos: Vector2, size: Vector2, font_size: int, parent: Control = null) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent == null:
		parent = _root
	parent.add_child(label)
	return label

func bind(target) -> void:
	player = target
	player.health_changed.connect(set_health)
	player.stamina_changed.connect(set_stamina)
	player.souls_changed.connect(set_souls)
	player.stats_changed.connect(func(): set_souls(player.souls))
	set_health(player.health, player.max_health)
	set_stamina(player.stamina, player.max_stamina)
	set_souls(player.souls)

func set_health(current: float, maximum: float) -> void:
	_hp.max_value = maximum
	_hp.value = current
	if _last_health >= 0.0 and current < _last_health:
		_hurt_alpha = 0.28
	_last_health = current

func set_stamina(current: float, maximum: float) -> void:
	_sp.max_value = maximum
	_sp.value = current

func set_souls(total: int) -> void:
	var lvl: int = 1
	if player:
		lvl = player.soul_level
	_souls_label.text = "Уровень %d   Души: %d" % [lvl, total]

func show_notice(text: String, duration: float = 2.0) -> void:
	_notice_label.text = text
	_notice_label.modulate.a = 1.0
	_notice_timer = duration

func _process(delta: float) -> void:
	if _hurt_alpha > 0.0:
		_hurt_alpha = maxf(0.0, _hurt_alpha - delta * 2.4)
		_hurt.color = Color(0.7, 0.0, 0.0, _hurt_alpha)

	if _notice_timer > 0.0:
		_notice_timer -= delta
		_notice_label.modulate.a = clampf(_notice_timer, 0.0, 1.0)

	if player and is_instance_valid(player):
		_flask_label.text = "Фляга: %d" % player.flasks
		if levels_visible:
			refresh_levels(player)
		var fuel := int(round(player.torch_fuel / player.torch_max * 100.0))
		var state := "горит" if player.torch_lit else "погашен"
		_torch_label.text = "Факел: %d%% (%s)" % [fuel, state]
