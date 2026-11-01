class_name TreeLib
extends RefCounted

## Процедурные деревья пяти пород. Один меш на дерево: ствол, ветки, листва.
## UV2 = (нормализованная высота, признак листвы) — по нему шейдер гнёт и красит.

const LEAF_BIRCH := Color(0.30, 0.40, 0.17)
const LEAF_OAK := Color(0.17, 0.25, 0.10)
const LEAF_ASH := Color(0.23, 0.33, 0.13)
const BARK_BIRCH := Color(0.78, 0.78, 0.74)
const BARK_OAK := Color(0.30, 0.24, 0.18)
const BARK_ASH := Color(0.52, 0.50, 0.44)
const BARK_CONIFER := Color(0.62, 0.55, 0.48)

class Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var height := 1.0

	func tube(from: Vector3, to: Vector3, r0: float, r1: float, sides: int, color: Color) -> void:
		var axis := to - from
		if axis.length() < 0.001:
			return
		axis = axis.normalized()
		var up := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var side := axis.cross(up).normalized()
		var fwd := side.cross(axis).normalized()
		var base := verts.size()

		for i in sides + 1:
			var a := TAU * float(i) / float(sides)
			var dir := side * cos(a) + fwd * sin(a)
			verts.append(from + dir * r0)
			normals.append(dir)
			uvs.append(Vector2(float(i) / float(sides), 0.0))
			uv2s.append(Vector2(clampf(from.y / height, 0.0, 1.0), 0.0))
			colors.append(color)

			verts.append(to + dir * r1)
			normals.append(dir)
			uvs.append(Vector2(float(i) / float(sides), 1.0))
			uv2s.append(Vector2(clampf(to.y / height, 0.0, 1.0), 0.0))
			colors.append(color)

		for i in sides:
			var a0 := base + i * 2
			var b0 := a0 + 1
			var a1 := a0 + 2
			var b1 := a0 + 3
			indices.append(a0)
			indices.append(a1)
			indices.append(b0)
			indices.append(b0)
			indices.append(a1)
			indices.append(b1)

	func card(pos: Vector3, size: float, yaw: float, tilt: float, color: Color) -> void:
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		var h := size * 0.5
		var corners := [
			Vector3(-h, -h, 0.0), Vector3(h, -h, 0.0),
			Vector3(h, h, 0.0), Vector3(-h, h, 0.0),
		]
		var base := verts.size()
		var n := basis * Vector3.BACK
		for c in corners:
			verts.append(pos + basis * c)
			normals.append(n)
			uvs.append(Vector2(c.x / size + 0.5, c.y / size + 0.5))
			uv2s.append(Vector2(clampf(pos.y / height, 0.0, 1.0), 1.0))
			colors.append(color)

		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices

		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

static func build(species: String, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Builder.new()
	match species:
		"birch":
			_birch(b, rng)
		"oak":
			_oak(b, rng)
		"ash":
			_ash(b, rng)
		"cedar":
			_conifer(b, rng, false)
		_:
			_conifer(b, rng, true)
	return b.commit()

static func trunk_radius(species: String) -> float:
	match species:
		"oak":
			return 0.45
		"cedar":
			return 0.38
		"spruce":
			return 0.32
		"ash":
			return 0.30
		_:
			return 0.24

static func height_of(species: String) -> float:
	match species:
		"oak":
			return 7.0
		"cedar":
			return 9.0
		"spruce":
			return 11.0
		"ash":
			return 10.0
		_:
			return 7.5

# --- берёза ---

static func _birch(b: Builder, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(6.0, 9.0)
	b.height = h
	var lean := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))

	var p0 := Vector3.ZERO
	var r := 0.13
	for i in 4:
		var t := float(i + 1) / 4.0
		var p1 := Vector3(lean.x * t * t, h * t, lean.z * t * t)
		b.tube(p0, p1, r, r * 0.72, 6, BARK_BIRCH)
		p0 = p1
		r *= 0.72

	for i in 9:
		var t := rng.randf_range(0.45, 0.95)
		var base := Vector3(lean.x * t * t, h * t, lean.z * t * t)
		var a := rng.randf() * TAU
		var branch_len := rng.randf_range(1.1, 2.1)
		var dir := Vector3(cos(a), rng.randf_range(-0.2, 0.2), sin(a)).normalized()
		var tip := base + dir * branch_len
		b.tube(base, tip, 0.055, 0.014, 4, BARK_BIRCH)
		for c in 5:
			var along := rng.randf_range(0.25, 1.05)
			var cp := base + dir * branch_len * along \
				+ Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.35, 0.45), rng.randf_range(-0.6, 0.6))
			b.card(cp, rng.randf_range(1.1, 1.7), rng.randf() * TAU, rng.randf_range(-0.5, 0.5), LEAF_BIRCH)

# --- дуб ---

static func _oak(b: Builder, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(5.5, 7.5)
	b.height = h
	var p0 := Vector3.ZERO
	var r := 0.42
	for i in 3:
		var t := float(i + 1) / 3.0
		var p1 := Vector3(rng.randf_range(-0.3, 0.3) * t, h * 0.55 * t, rng.randf_range(-0.3, 0.3) * t)
		b.tube(p0, p1, r, r * 0.8, 7, BARK_OAK)
		p0 = p1
		r *= 0.8

	for i in 7:
		var t := rng.randf_range(0.35, 0.95)
		var base := Vector3(0.0, h * 0.55 * t, 0.0)
		var a := TAU * float(i) / 7.0 + rng.randf_range(-0.3, 0.3)
		var branch_len := rng.randf_range(1.8, 2.9)
		var dir := Vector3(cos(a), rng.randf_range(0.25, 0.55), sin(a)).normalized()
		var mid := base + dir * branch_len * 0.6
		b.tube(base, mid, 0.14, 0.08, 5, BARK_OAK)
		var tip := mid + (dir + Vector3(0.0, 0.25, 0.0)).normalized() * branch_len * 0.5
		b.tube(mid, tip, 0.08, 0.03, 4, BARK_OAK)
		for c in 7:
			var cp := tip + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.4, 1.0), rng.randf_range(-1.2, 1.2))
			b.card(cp, rng.randf_range(1.3, 1.9), rng.randf() * TAU, rng.randf_range(-0.5, 0.5), LEAF_OAK)

# --- ясень ---

static func _ash(b: Builder, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(8.0, 11.0)
	b.height = h
	var p0 := Vector3.ZERO
	var r := 0.24
	for i in 5:
		var t := float(i + 1) / 5.0
		var p1 := Vector3(rng.randf_range(-0.15, 0.15) * t, h * t, rng.randf_range(-0.15, 0.15) * t)
		b.tube(p0, p1, r, r * 0.8, 6, BARK_ASH)
		p0 = p1
		r *= 0.8

	for i in 10:
		var t := rng.randf_range(0.5, 0.96)
		var base := Vector3(0.0, h * t, 0.0)
		var a := rng.randf() * TAU
		var branch_len := rng.randf_range(1.3, 2.2)
		var dir := Vector3(cos(a), rng.randf_range(0.3, 0.7), sin(a)).normalized()
		var tip := base + dir * branch_len
		b.tube(base, tip, 0.06, 0.02, 4, BARK_ASH)
		for c in 3:
			var cp := tip + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.2, 0.6), rng.randf_range(-0.6, 0.6))
			b.card(cp, rng.randf_range(1.0, 1.5), rng.randf() * TAU, rng.randf_range(-0.4, 0.4), LEAF_ASH)

# --- хвойные ---

static func _conifer(b: Builder, rng: RandomNumberGenerator, narrow: bool) -> void:
	var h := rng.randf_range(9.0, 13.0) if narrow else rng.randf_range(7.0, 10.0)
	b.height = h
	var width := 2.2 if narrow else 3.0
	var needle := Color(0.055, 0.11, 0.065) if narrow else Color(0.07, 0.13, 0.075)

	var p0 := Vector3.ZERO
	var r := 0.2
	for i in 3:
		var t := float(i + 1) / 3.0
		var p1 := Vector3(0.0, h * t, 0.0)
		b.tube(p0, p1, r, r * 0.75, 6, BARK_CONIFER)
		p0 = p1
		r *= 0.75

	var tiers := 6
	for i in tiers:
		var t := float(i) / float(tiers)
		var y := h * (0.28 + t * 0.66)
		var radius := width * (1.0 - t) * 0.9 + 0.25
		b.tube(Vector3(0.0, y, 0.0), Vector3(0.0, y + h * 0.16, 0.0), radius, 0.05, 8, needle)

	# лапы
	for i in 7:
		var t := rng.randf_range(0.35, 0.85)
		var y := h * t
		var a := rng.randf() * TAU
		var len := (width * (1.0 - t) + 0.4) * 0.9
		var base := Vector3(0.0, y, 0.0)
		var tip := base + Vector3(cos(a) * len, rng.randf_range(-0.35, 0.1), sin(a) * len)
		b.tube(base, tip, 0.09, 0.02, 4, needle)
