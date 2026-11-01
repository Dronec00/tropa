extends CanvasLayer

## Меню паузы по Esc: продолжить, начать заново, в главное меню, выход.

var game: Node

var _panel: Control
var _visible := false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.015, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.87, 0.8))
	box.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	box.add_child(spacer)

	_button(box, "Продолжить", close)
	_button(box, "Начать заново", _restart)
	_button(box, "В главное меню", _to_menu)
	_button(box, "Выход", func() -> void: get_tree().quit())

func _button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.055, 0.06, 0.94)
	normal.border_color = Color(0.28, 0.24, 0.18)
	normal.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.12, 0.09, 0.96)
	hover.border_color = Color(0.66, 0.5, 0.24)
	b.add_theme_stylebox_override("hover", hover)

	b.pressed.connect(callback)
	parent.add_child(b)

func open() -> void:
	if _visible:
		return
	_visible = true
	_panel.visible = true
	if game != null:
		game.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	if not _visible:
		return
	_visible = false
	_panel.visible = false
	if game != null:
		game.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart() -> void:
	if game != null:
		game.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()

func _to_menu() -> void:
	if game != null:
		game.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not _visible and game != null and game.hud != null and game.hud.levels_visible:
		game.hud.hide_levels()
		get_viewport().set_input_as_handled()
		return
	if _visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()
