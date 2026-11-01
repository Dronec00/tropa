class_name RobeBuilder
extends RefCounted

## Роба для массовых врагов: конус из колец + капюшон.
## Ткань колышется в вершинном шейдере — дешево, можно ставить десятками.

const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec3 cloth_color : source_color = vec3(0.07, 0.06, 0.08);
uniform vec3 cloth_edge : source_color = vec3(0.16, 0.13, 0.11);
uniform float mesh_height = 1.35;
uniform float sway = 0.10;
uniform float wind_speed = 2.0;

varying float v_h;

void vertex() {
	float h = clamp(1.0 - VERTEX.y / mesh_height, 0.0, 1.0);
	float phase = TIME * wind_speed + VERTEX.x * 4.0 + VERTEX.z * 3.0;
	float s = sin(phase) * 0.7 + sin(phase * 2.7 + 1.3) * 0.3;
	VERTEX.x += s * sway * h * h;
	VERTEX.z += cos(phase * 0.8) * sway * 0.65 * h * h;
	VERTEX.y += sin(phase * 1.9) * 0.015 * h;
	v_h = h;
}

void fragment() {
	ALBEDO = mix(cloth_color, cloth_edge, v_h * 0.55);
	ROUGHNESS = 1.0;
	BACKLIGHT = cloth_color * 0.5;
}
"""

static func build(parent: Node3D, cloth: Color, height: float, eye_color: Color, pale := false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)

	var top_y := height - 0.45
	var bottom_y := 0.05 if not pale else 0.35
	var top_r := 0.22
	var bottom_r := 0.55 if not pale else 0.62

	var skirt := ArrayMesh.new()
	var arrays := _skirt_arrays(top_y, bottom_y, top_r, bottom_r, 14, 6)
	skirt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	material.set_shader_parameter("cloth_color", cloth)
	material.set_shader_parameter("cloth_edge", cloth.lightened(0.25))
	material.set_shader_parameter("mesh_height", top_y)
	material.set_shader_parameter("sway", 0.12 if pale else 0.09)

	var skirt_node := MeshInstance3D.new()
	skirt_node.mesh = skirt
	skirt_node.material_override = material
	root.add_child(skirt_node)

	# капюшон
	var hood := MeshInstance3D.new()
	var hood_mesh := CylinderMesh.new()
	hood_mesh.top_radius = 0.03
	hood_mesh.bottom_radius = 0.27
	hood_mesh.height = 0.5
	hood.mesh = hood_mesh
	hood.position.y = top_y + 0.16
	var hood_mat := StandardMaterial3D.new()
	hood_mat.albedo_color = cloth.darkened(0.25)
	hood_mat.roughness = 1.0
	hood.material_override = hood_mat
	root.add_child(hood)

	# пустота под капюшоном
	var hollow := MeshInstance3D.new()
	var hollow_mesh := SphereMesh.new()
	hollow_mesh.radius = 0.14
	hollow_mesh.height = 0.28
	hollow.mesh = hollow_mesh
	hollow.position = Vector3(0, top_y + 0.02, -0.06)
	var hollow_mat := StandardMaterial3D.new()
	hollow_mat.albedo_color = Color(0.01, 0.01, 0.012)
	hollow_mat.roughness = 1.0
	hollow.material_override = hollow_mat
	root.add_child(hollow)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = eye_color
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_color
	eye_mat.emission_energy_multiplier = 3.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for x in [-0.06, 0.06]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.028
		eye_mesh.height = 0.056
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(x, top_y + 0.04, -0.17)
		root.add_child(eye)

	# рукава
	for side in [-1.0, 1.0]:
		var sleeve := MeshInstance3D.new()
		var sleeve_mesh := CylinderMesh.new()
		sleeve_mesh.top_radius = 0.05
		sleeve_mesh.bottom_radius = 0.11
		sleeve_mesh.height = 0.62
		sleeve.mesh = sleeve_mesh
		sleeve.position = Vector3(side * 0.26, top_y - 0.22, 0.0)
		sleeve.rotation.z = side * 0.12
		sleeve.material_override = hood_mat
		root.add_child(sleeve)

	return root

static func _skirt_arrays(top_y: float, bottom_y: float, top_r: float, bottom_r: float, segments: int, rings: int) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for j in rings + 1:
		var t := float(j) / float(rings)
		var y := lerpf(top_y, bottom_y, t)
		var r := lerpf(top_r, bottom_r, pow(t, 0.75))
		for i in segments:
			var a := TAU * float(i) / float(segments)
			verts.append(Vector3(cos(a) * r, y, sin(a) * r))
			normals.append(Vector3(cos(a), 0.25, sin(a)).normalized())

	for j in rings:
		for i in segments:
			var a := j * segments + i
			var b := j * segments + (i + 1) % segments
			var c := (j + 1) * segments + i
			var d := (j + 1) * segments + (i + 1) % segments
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
