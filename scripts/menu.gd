extends Control

## Главное меню: игра, локации, персонаж, враги.

const LabStateScript := preload("res://scripts/lab_state.gd")

const OBJECTS := [
	{"name": "Берёза", "kind": "birch"},
	{"name": "Берёза многствольная", "kind": "birch_multi"},
	{"name": "Дуб", "kind": "oak"},
	{"name": "Ясень", "kind": "ash"},
	{"name": "Ель", "kind": "spruce"},
	{"name": "Кедр", "kind": "cedar"},
	{"name": "Сосна", "kind": "pine"},
	{"name": "Ива", "kind": "willow"},
	{"name": "Куст", "kind": "bush"},
	{"name": "Папоротник", "kind": "fern"},
	{"name": "Камыш", "kind": "reed"},
	{"name": "Валун", "kind": "rock"},
	{"name": "Лужа", "kind": "puddle"},
	{"name": "Изба", "kind": "hut"},
]

const ENEMIES := [
	{"kind": "wolf", "name": "Волк"},
	{"kind": "cultist", "name": "Послушник"},
	{"kind": "wailer", "name": "Плакальщица"},
	{"kind": "leshy", "name": "Леший"},
	{"kind": "kikimora", "name": "Кикимора"},
]

const LOCATIONS := [
	{"name": "Лагерь у костра", "at": Vector3(2.8, 0.0, 5.4)},
	{"name": "Изба", "at": Vector3(-28.0, 0.0, -42.0)},
	{"name": "Ручей", "at": Vector3(10.0, 0.0, -6.0)},
	{"name": "Край тьмы", "at": Vector3(0.0, 0.0, -70.0)},
]

var _box: VBoxContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_background()
	_setup_layout()
	_show_main()

func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.018, 0.022, 0.028)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.10, 0.08, 0.05, 0.35)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_top = 300.0
	add_child(glow)

func _setup_layout() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_box)

func _clear() -> void:
	for child in _box.get_children():
		child.queue_free()

func _label(text: String, size: int, alpha: float = 1.0) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78, alpha))
	_box.add_child(l)

func _button(text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(460, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.06, 0.065, 0.92)
	normal.border_color = Color(0.24, 0.21, 0.16)
	normal.set_border_width_all(1)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	b.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.11, 0.08, 0.95)
	hover.border_color = Color(0.62, 0.48, 0.24)
	b.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.18, 0.14, 0.09, 0.95)
	b.add_theme_stylebox_override("pressed", pressed)

	b.pressed.connect(callback)
	_box.add_child(b)

func _show_main() -> void:
	_clear()
	_label("ТРОПА", 54)
	_label("мрачный лес · костёр · души", 15, 0.6)
	_spacer(18)
	_button("Играть", _play)
	_button("Локация", _show_locations)
	_button("Персонаж", _open_character)
	_button("Враги", _show_enemies)
	_button("Объекты", _show_objects)
	_button("Трава", func() -> void: get_tree().change_scene_to_file("res://scenes/grass_lab.tscn"))
	_button("Выход", func() -> void: get_tree().quit())

func _show_locations() -> void:
	_clear()
	_label("ЛОКАЦИЯ", 34)
	_label("выбери, откуда начать", 15, 0.6)
	_spacer(12)
	for entry in LOCATIONS:
		var at: Vector3 = entry["at"]
		_button(entry["name"], func() -> void:
			LabStateScript.spawn_at = at
			get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_spacer(10)
	_button("Назад", _show_main)

func _show_enemies() -> void:
	_clear()
	_label("ВРАГИ", 34)
	_label("витрина: посмотреть, как выглядит и двигается", 15, 0.6)
	_spacer(12)
	for entry in ENEMIES:
		var kind: String = entry["kind"]
		_button(entry["name"], func() -> void:
			LabStateScript.enemy = kind
			get_tree().change_scene_to_file("res://scenes/enemy_lab.tscn"))
	_spacer(10)
	_button("Назад", _show_main)

func _show_objects() -> void:
	_clear()
	_label("ОБЪЕКТЫ", 34)
	_label("витрина: один объект на ровной площадке", 15, 0.6)
	_spacer(12)
	for entry in OBJECTS:
		var kind: String = entry["kind"]
		_button(entry["name"], func() -> void:
			LabStateScript.object_name = kind
			get_tree().change_scene_to_file("res://scenes/object_lab.tscn"))
	_spacer(10)
	_button("Назад", _show_main)

func _play() -> void:
	LabStateScript.spawn_at = Vector3.INF
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _open_character() -> void:
	get_tree().change_scene_to_file("res://scenes/character_lab.tscn")

func _spacer(height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	_box.add_child(s)
