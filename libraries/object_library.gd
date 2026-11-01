class_name ObjectLibrary
extends RefCounted

## Библиотека вариантов объектов.
## Все варианты вида считаются от одного «аттрактора» — общего шума по имени вида,
## поэтому предметы отличаются друг от друга, но остаются в одном стиле.

const TreeLibScript := preload("res://scripts/tree_lib.gd")

const SPACING := {
	"birch": 4.6, "birch_multi": 4.6, "oak": 5.6, "ash": 4.8,
	"spruce": 4.6, "cedar": 5.2, "pine": 4.6, "willow": 5.0,
	"bush": 2.2, "fern": 1.8, "reed": 1.6,
	"rock": 2.6, "moss_rock": 2.6, "bonfire": 4.0, "puddle": 5.0, "hut": 12.0, "grass": 6.0,
}

static func variants(kind: String, count: int = 8) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = abs(hash(kind)) % 100000
	noise.frequency = 0.35
	noise.fractal_octaves = 3

	var out: Array = []
	for i in count:
		var a: float = noise.get_noise_1d(float(i) * 13.7)
		var b: float = noise.get_noise_1d(float(i) * 13.7 + 311.0)
		var c: float = noise.get_noise_1d(float(i) * 13.7 + 733.0)
		var ta := clampf(a * 0.5 + 0.5, 0.0, 1.0)
		var tb := clampf(b * 0.5 + 0.5, 0.0, 1.0)
		var tc := clampf(c * 0.5 + 0.5, 0.0, 1.0)

		var entry := {
			"index": i,
			"name": kind + "_" + str(i),
			"seed": 7000 + i * 131,
			"scale": lerpf(0.72, 1.38, ta),
			"lean": lerpf(-0.10, 0.10, tb),
			"tint": tc,
			"radius": lerpf(0.45, 1.25, ta),
			"squash": lerpf(0.55, 0.95, tb),
			"yaw": tb * TAU,
			"rough": lerpf(0.12, 0.35, tc),
		}
		out.append(entry)
	return out

static func spacing(kind: String) -> float:
	return float(SPACING.get(kind, 4.0))

## Камень: сфера, искажённая шумом. У каждого варианта свой силуэт.
static func make_stone(entry: Dictionary) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["seed"])
	var noise := FastNoiseLite.new()
	noise.seed = int(entry["seed"])
	noise.frequency = 1.1
	noise.fractal_octaves = 3

	var rings := 10
	var segs := 14
	var radius: float = entry["radius"]
	var squash: float = entry["squash"]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for r in rings + 1:
		var v := float(r) / float(rings)
		var phi := v * PI
		for s in segs:
			var u := float(s) / float(segs)
			var theta := u * TAU
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var n: float = noise.get_noise_3dv(dir * 1.6)
			var rr := radius * (1.0 + n * 0.32)
			var p := dir * rr
			p.y *= squash
			verts.append(p)
			normals.append(dir)
			uvs.append(Vector2(u, v))

	for r in rings:
		for s in segs:
			var a := r * segs + s
			var b := r * segs + (s + 1) % segs
			var c := (r + 1) * segs + s
			var d := (r + 1) * segs + (s + 1) % segs
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
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
