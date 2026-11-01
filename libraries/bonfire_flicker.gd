class_name BonfireFlicker
extends Node3D

## Живой огонь: мерцание света и пульсация углей.

var light: OmniLight3D
var embers: Array = []
var base_energy := 2.4
var base_range := 15.0
var _t := 0.0

func _process(delta: float) -> void:
	if OS.get_environment("TROPA_NO_FLICKER") == "1":
		return
	_t += delta
	var n := sin(_t * 8.3) * 0.5 + sin(_t * 13.7) * 0.3 + sin(_t * 2.7) * 0.2
	if light != null:
		light.light_energy = base_energy * (1.0 + n * 0.16)
		light.omni_range = base_range * (1.0 + n * 0.03)

	for i in embers.size():
		var node: MeshInstance3D = embers[i]
		var ph := float(i) * 1.7
		var k := 0.75 + 0.35 * sin(_t * (2.0 + float(i % 5) * 0.7) + ph)
		node.scale = Vector3.ONE * k
