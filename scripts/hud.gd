extends CanvasLayer

var player

var _root: Control
var _hp: ProgressBar
var _sp: ProgressBar
var _souls_label: Label
var _flask_label: Label
var _torch_label: Label
var _notice_label: Label
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

	_hp = _make_bar(Vector2(36, 634), Vector2(320, 16), Color(0.52, 0.10, 0.10))
	_sp = _make_bar(Vector2(36, 658), Vector2(320, 9), Color(0.36, 0.52, 0.26))

	_flask_label = _make_label(Vector2(36, 596), Vector2(320, 24), 16)
	_flask_label.text = "Фляга: 3"

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
	hint.text = "WASD — идти    ЛКМ — удар    Пробел — перекат    Q — фляга    F — факел    E — костёр    Esc — мышь"

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

func _make_label(pos: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label

func bind(target) -> void:
	player = target
	player.health_changed.connect(set_health)
	player.stamina_changed.connect(set_stamina)
	player.souls_changed.connect(set_souls)
	set_health(player.health, player.max_health)
	set_stamina(player.stamina, player.max_stamina)
	set_souls(player.souls)

func set_health(current: float, maximum: float) -> void:
	_hp.max_value = maximum
	_hp.value = current
	if _last_health >= 0.0 and current < _last_health:
		_hurt_alpha = 0.45
	_last_health = current

func set_stamina(current: float, maximum: float) -> void:
	_sp.max_value = maximum
	_sp.value = current

func set_souls(total: int) -> void:
	_souls_label.text = "Души: %d" % total

func show_notice(text: String, duration: float = 2.0) -> void:
	_notice_label.text = text
	_notice_label.modulate.a = 1.0
	_notice_timer = duration

func _process(delta: float) -> void:
	if _hurt_alpha > 0.0:
		_hurt_alpha = maxf(0.0, _hurt_alpha - delta * 1.7)
		_hurt.color = Color(0.7, 0.0, 0.0, _hurt_alpha)

	if _notice_timer > 0.0:
		_notice_timer -= delta
		_notice_label.modulate.a = clampf(_notice_timer, 0.0, 1.0)

	if player and is_instance_valid(player):
		_flask_label.text = "Фляга: %d" % player.flasks
		var fuel := int(round(player.torch_fuel / player.torch_max * 100.0))
		var state := "горит" if player.torch_lit else "погашен"
		_torch_label.text = "Факел: %d%% (%s)" % [fuel, state]
