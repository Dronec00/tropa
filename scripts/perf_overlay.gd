class_name PerfOverlay
extends CanvasLayer

## Счётчик кадров: F3 — показать/скрыть. При TROPA_FPS=1 пишет средний fps в лог.

var _label: Label
var _acc := 0.0
var _frames := 0
var _total := 0.0
var _total_frames := 0
var _log_mode := false
var _shown := true

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log_mode = OS.get_environment("TROPA_FPS") == "1"

	_label = Label.new()
	_label.position = Vector2(24, 120)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.7))
	if not _log_mode:
		add_child(_label)
	else:
		print("[perf] start")

func _process(delta: float) -> void:
	_acc += delta
	_frames += 1
	_total += delta
	_total_frames += 1

	if _acc >= 0.5:
		var fps := float(_frames) / _acc
		if _shown and _label.is_inside_tree():
			_label.text = "FPS %d  |  %.1f ms  |  draw %d" % [
				int(round(fps)),
				delta * 1000.0,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			]
		_acc = 0.0
		_frames = 0

	if _log_mode and _total >= 1.0:
		print("[perf] fps=%.1f frames=%d" % [float(_total_frames) / _total, _total_frames])
		_total = 0.0
		_total_frames = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_F3:
			_shown = not _shown
			if _label.is_inside_tree():
				_label.visible = _shown
