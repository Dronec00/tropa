extends Node3D

## Экспорт модели ГГ в models/dhampir.glb.
##   godot --headless --path . res://tools/export_dhampir.tscn

const DhampirScript := preload("res://scripts/dhampir_model.gd")

func _ready() -> void:
	var model: Node3D = Node3D.new()
	model.name = "Dhampir"
	add_child(model)
	var parts: Dictionary = DhampirScript.build(model)
	var animator: Node = parts.get("animator") as Node
	if animator != null:
		animator.queue_free()

	# для внешнего просмотра меч убран в ножны: клинок не дублируем
	var sword: Node3D = parts.get("sword_pivot") as Node3D
	if sword != null:
		sword.get_parent().remove_child(sword)
		sword.queue_free()
	var torch: Node3D = parts.get("torch_pivot") as Node3D
	if torch != null and torch.get_parent() != null:
		torch.get_parent().remove_child(torch)
		torch.queue_free()

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://models")):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://models"))
	var path: String = ProjectSettings.globalize_path("res://models/dhampir.glb")
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: Error = doc.append_from_scene(model, state)
	if err != OK:
		push_error("append_from_scene: %s" % error_string(err))
		get_tree().quit(1)
		return
	err = doc.write_to_filesystem(state, path)
	print("[export] %s -> %s" % [path, error_string(err)])

	# проверка: читаем обратно и считаем меши
	var check_state: GLTFState = GLTFState.new()
	var cerr: Error = doc.append_from_file(path, check_state)
	var root: Node = doc.generate_scene(check_state) if cerr == OK else null
	var meshes: int = _count_meshes(root) if root != null else -1
	print("[export] проверка: %s, мешей %d, размер %.1f КБ" % [
		error_string(cerr), meshes, _file_size(path) / 1024.0])
	if root != null:
		root.free()
	model.free()
	await get_tree().process_frame
	get_tree().quit(0 if err == OK and meshes > 50 else 1)

func _count_meshes(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D:
		total += 1
	for child in node.get_children():
		total += _count_meshes(child)
	return total

func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size: int = f.get_length()
	f.close()
	return size
