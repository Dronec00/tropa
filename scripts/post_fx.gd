class_name PostFX
extends CanvasLayer

## Полноэкранная постобработка поверх 3D, но под HUD.

var _rect: ColorRect

func _ready() -> void:
	layer = 2
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/post_fx.gdshader")

	_rect = ColorRect.new()
	_rect.material = mat
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
