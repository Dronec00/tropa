class_name TreeLib
extends RefCounted

## Процедурные деревья пяти пород. Один меш на дерево: ствол, ветки, листва.
## UV2 = (нормализованная высота, признак листвы) — по нему шейдер гнёт и красит.

const LEAF_BIRCH := Color(0.30, 0.40, 0.17)
const LEAF_OAK := Color(0.17, 0.25, 0.10)
const LEAF_ASH := Color(0.23, 0.33, 0.13)
const BARK_BIRCH := Color(0.58, 0.58, 0.55)
const BARK_OAK := Color(0.30, 0.24, 0.18)
const BARK_ASH := Color(0.52, 0.50, 0.44)
const BARK_CONIFER := Color(0.62, 0.55, 0.48)
const LEAF_WILLOW := Color(0.22, 0.31, 0.12)
const LEAF_BUSH := Color(0.15, 0.22, 0.10)
const BARK_BUSH := Color(0.28, 0.24, 0.18)

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

static var simple := false

static func build(species: String, seed_value: int, low := false) -> ArrayMesh:
	simple = low
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Builder.new()
	match species:
		"birch":
			_deciduous(b, rng, 1)
		"birch_multi":
			_deciduous(b, rng, rng.randi_range(2, 3))
		"oak":
			_oak(b, rng)
		"ash":
			_ash(b, rng)
		"willow":
			_willow(b, rng)
		"pine":
			_pine(b, rng)
		"fern":
			_fern(b, rng)
		"reed":
			_reed(b, rng)
		"bush":
			_bush(b, rng)
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
		"willow":
			return 0.34
		"bush":
			return 0.30
		"fern":
			return 0.08
		"reed":
			return 0.04
		"pine":
			return 0.34
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
		"willow":
			return 6.0
		"bush":
			return 1.2
		"fern":
			return 0.9
		"reed":
			return 1.6
		"pine":
			return 13.0
		_:
			return 7.5

# --- лиственные ---

static func _curved_trunk(b: Builder, rng: RandomNumberGenerator, base: Vector3, height: float, lean: Vector3, radius: float, color: Color) -> Vector3:
	var p := base
	var dir := Vector3(lean.x, 1.0, lean.z).normalized()
	var r := radius
	var bend_dir := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
	var segments := 5
	for i in segments:
		var t := float(i + 1) / float(segments)
		var bend := Vector3(sin(t * 2.4), 0.0, cos(t * 2.1)) * 0.05 + bend_dir * 0.04
		dir = (dir + bend).normalized()
		var p1 := p + dir * (height / float(segments))
		b.tube(p, p1, r, r * 0.8, 6, color)
		p = p1
		r *= 0.8
	return p

static func _deciduous(b: Builder, rng: RandomNumberGenerator, trunks: int) -> void:
	var f := 0.45 if TreeLib.simple else 1.0
	var h := rng.randf_range(6.5, 9.5)
	b.height = h

	for trunk_i in trunks:
		var offset := Vector3.ZERO
		if trunks > 1:
			var a := TAU * float(trunk_i) / float(trunks) + rng.randf_range(-0.4, 0.4)
			offset = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.15, 0.45)
		var lean := Vector3(rng.randf_range(-0.09, 0.09), 0.0, rng.randf_range(-0.09, 0.09))
		var top := _curved_trunk(b, rng, offset, h * rng.randf_range(0.85, 1.0), lean, 0.13, BARK_BIRCH)

		for i in maxi(2, int(8.0 * f)):
			var base := offset.lerp(top, rng.randf_range(0.55, 0.98))
			var a := rng.randf() * TAU
			var branch_len := rng.randf_range(1.1, 2.0)
			var dir := Vector3(cos(a), rng.randf_range(-0.15, 0.25), sin(a)).normalized()
			var tip := base + dir * branch_len
			b.tube(base, tip, 0.05, 0.013, 4, BARK_BIRCH)
			var leaf_tint := LEAF_BIRCH.lerp(Color(0.62, 0.50, 0.16), rng.randf_range(0.0, 0.55))
			for c in maxi(2, int(12.0 * f)):
				var along := rng.randf_range(0.15, 1.15)
				var cp := base + dir * branch_len * along \
					+ Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.35, 0.45), rng.randf_range(-0.6, 0.6))
				b.card(cp, rng.randf_range(1.1, 1.7), rng.randf() * TAU, rng.randf_range(-0.5, 0.5), leaf_tint)

# --- ива ---

static func _willow(b: Builder, rng: RandomNumberGenerator) -> void:
	var f := 0.45 if TreeLib.simple else 1.0
	var h := rng.randf_range(4.2, 5.8)
	b.height = h
	var top := _curved_trunk(b, rng, Vector3.ZERO, h,
		Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15)), 0.26, BARK_ASH)

	# крона: купол из листвы
	for i in maxi(6, int(40.0 * f)):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.3, 1.6)
		var p := top + Vector3(cos(a) * r, rng.randf_range(-0.2, 0.6), sin(a) * r)
		b.card(p, rng.randf_range(0.7, 1.1), rng.randf() * TAU, rng.randf_range(-0.6, 0.6), LEAF_WILLOW)

	# пряди: тонкие нити, уходящие вниз
	var strands := maxi(8, int(46.0 * f))
	for i in strands:
		var a := TAU * float(i) / float(strands) + rng.randf_range(-0.12, 0.12)
		var out := Vector3(cos(a), 0.0, sin(a))
		var start := top + out * rng.randf_range(0.2, 1.2) + Vector3(0.0, rng.randf_range(-0.1, 0.5), 0.0)
		var drop := rng.randf_range(2.0, 3.4)
		var p1 := start + out * 0.45 + Vector3(0.0, 0.18, 0.0)
		var p2 := p1 + out * 0.35 + Vector3(0.0, -drop * 0.55, 0.0)
		var p3 := p2 + out * 0.15 + Vector3(0.0, -drop * 0.45, 0.0)
		b.tube(start, p1, 0.022, 0.016, 3, BARK_ASH)
		b.tube(p1, p2, 0.016, 0.010, 3, BARK_ASH)
		b.tube(p2, p3, 0.010, 0.004, 3, BARK_ASH)
		for c in 5:
			var t01 := rng.randf_range(0.0, 1.0)
			var cp := p2.lerp(p3, t01) + Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
			b.card(cp, rng.randf_range(0.38, 0.62), rng.randf() * TAU, rng.randf_range(-0.3, 0.3), LEAF_WILLOW)

# --- куст ---

static func _bush(b: Builder, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.9, 1.5)
	b.height = h
	for i in 8:
		var a := TAU * float(i) / 8.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a))
		var tip := out * rng.randf_range(0.35, 0.75) + Vector3(0.0, h * rng.randf_range(0.55, 1.0), 0.0)
		b.tube(Vector3(0.0, 0.05, 0.0), tip, 0.05, 0.02, 4, BARK_BUSH)
		for c in 5:
			var cp := tip + Vector3(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.12, 0.2), rng.randf_range(-0.28, 0.28))
			b.card(cp, rng.randf_range(0.55, 0.95), rng.randf() * TAU, rng.randf_range(-0.5, 0.5), LEAF_BUSH)

# --- дуб ---# --- дуб ---

static func _oak(b: Builder, rng: RandomNumberGenerator) -> void:
	var f := 0.45 if TreeLib.simple else 1.0
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

	for i in maxi(2, int(7.0 * f)):
		var t := rng.randf_range(0.35, 0.95)
		var base := Vector3(0.0, h * 0.55 * t, 0.0)
		var a := TAU * float(i) / 7.0 + rng.randf_range(-0.3, 0.3)
		var branch_len := rng.randf_range(1.8, 2.9)
		var dir := Vector3(cos(a), rng.randf_range(0.25, 0.55), sin(a)).normalized()
		var mid := base + dir * branch_len * 0.6
		b.tube(base, mid, 0.14, 0.08, 5, BARK_OAK)
		var tip := mid + (dir + Vector3(0.0, 0.25, 0.0)).normalized() * branch_len * 0.5
		b.tube(mid, tip, 0.08, 0.03, 4, BARK_OAK)
		for c in maxi(2, int(7.0 * f)):
			var cp := tip + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.4, 1.0), rng.randf_range(-1.2, 1.2))
			b.card(cp, rng.randf_range(1.3, 1.9), rng.randf() * TAU, rng.randf_range(-0.5, 0.5), LEAF_OAK)

# --- ясень ---

static func _ash(b: Builder, rng: RandomNumberGenerator) -> void:
	var f := 0.45 if TreeLib.simple else 1.0
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

	for i in maxi(3, int(10.0 * f)):
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
	var f := 0.45 if TreeLib.simple else 1.0
	var h := rng.randf_range(9.0, 13.0) if narrow else rng.randf_range(7.0, 10.5)
	b.height = h
	var max_r := 2.4 if narrow else 3.0
	var needle := Color(0.085, 0.155, 0.085) if narrow else Color(0.10, 0.175, 0.095)
	var bark := BARK_CONIFER

	# ствол
	var p0 := Vector3.ZERO
	var r := 0.19
	for i in 4:
		var t := float(i + 1) / 4.0
		var p1 := Vector3(0.0, h * t, 0.0)
		b.tube(p0, p1, r, r * 0.72, 6, bark)
		p0 = p1
		r *= 0.72

	# ярусы ветвей
	var levels := maxi(5, int(19.0 * f))
	for i in levels:
		var t := float(i) / float(levels)
		var y := h * (0.20 + t * 0.74)
		var radius := max_r * pow(1.0 - t, 1.15) + 0.12
		var branches := 8 if t < 0.45 else 6
		var a0 := rng.randf() * TAU
		for j in branches:
			var a := a0 + TAU * float(j) / float(branches) + rng.randf_range(-0.12, 0.12)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var base := Vector3(0.0, y, 0.0)
			var tip := base + dir * radius + Vector3(0.0, -rng.randf_range(0.06, 0.28), 0.0)
			var mid := base.lerp(tip, 0.6) + Vector3(0.0, 0.07, 0.0)
			b.tube(base, mid, 0.042, 0.026, 4, bark)
			b.tube(mid, tip, 0.026, 0.010, 4, bark)
			for c in maxi(1, int(4.0 * f)):
				var tt := rng.randf_range(0.25, 1.0)
				var cp := mid.lerp(tip, tt) + Vector3(
					rng.randf_range(-0.18, 0.18),
					rng.randf_range(-0.10, 0.14),
					rng.randf_range(-0.18, 0.18)
				)
				b.card(cp, rng.randf_range(0.85, 1.30), rng.randf() * TAU, rng.randf_range(-0.8, 0.8), needle)

	# макушка-шпиль
	for i in 6:
		var top_base := Vector3(0.0, h * 0.94, 0.0)
		var tip := Vector3(rng.randf_range(-0.18, 0.18), h + rng.randf_range(-0.05, 0.22), rng.randf_range(-0.18, 0.18))
		b.tube(top_base, tip, 0.022, 0.004, 3, bark)
		b.card(tip, rng.randf_range(0.30, 0.5), rng.randf() * TAU, rng.randf_range(-0.4, 0.4), needle)

# --- сосна ---

static func _pine(b: Builder, rng: RandomNumberGenerator) -> void:
	var f := 0.45 if TreeLib.simple else 1.0
	var h := rng.randf_range(11.0, 16.0)
	b.height = h
	var bark := Color(0.42, 0.30, 0.22)
	var needle := Color(0.10, 0.17, 0.10)

	var p0 := Vector3.ZERO
	var r := 0.24
	for i in 4:
		var t := float(i + 1) / 4.0
		var p1 := Vector3(0.0, h * t, 0.0)
		b.tube(p0, p1, r, r * 0.7, 6, bark)
		p0 = p1
		r *= 0.7

	# крона только в верхней части
	for i in maxi(2, int(6.0 * f)):
		var t := 0.58 + float(i) * 0.07
		var y := h * t
		var radius := 1.7 * (1.0 - (t - 0.58) / 0.42) + 0.3
		for j in maxi(2, int(5.0 * f)):
			var a := TAU * float(j) / 5.0 + rng.randf_range(-0.2, 0.2) + float(i) * 0.4
			var dir := Vector3(cos(a), 0.0, sin(a))
			var base := Vector3(0.0, y, 0.0)
			var tip := base + dir * radius + Vector3(0.0, rng.randf_range(-0.1, 0.1), 0.0)
			b.tube(base, tip, 0.035, 0.012, 4, bark)
			for c in 3:
				var cp := base.lerp(tip, rng.randf_range(0.4, 1.0)) + Vector3(0.0, 0.1, 0.0)
				b.card(cp, rng.randf_range(0.7, 1.05), rng.randf() * TAU, rng.randf_range(-0.6, 0.6), needle)

	for i in 4:
		var tip := Vector3(rng.randf_range(-0.12, 0.12), h + rng.randf_range(0.0, 0.3), rng.randf_range(-0.12, 0.12))
		b.tube(Vector3(0.0, h * 0.98, 0.0), tip, 0.02, 0.004, 3, bark)

# --- папоротник ---

static func _fern(b: Builder, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.55, 1.05)
	b.height = h
	var leaf := Color(0.10, 0.20, 0.085).lerp(Color(0.22, 0.30, 0.10), rng.randf_range(0.0, 0.6))

	for i in 9:
		var a := TAU * float(i) / 9.0 + rng.randf_range(-0.25, 0.25)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var p0 := Vector3(0.0, 0.04, 0.0)
		var p1 := dir * 0.22 + Vector3(0.0, h * 0.55, 0.0)
		var p2 := dir * 0.52 + Vector3(0.0, h * 0.95, 0.0)
		b.tube(p0, p1, 0.012, 0.008, 3, BARK_BUSH)
		b.tube(p1, p2, 0.008, 0.003, 3, BARK_BUSH)
		for c in 5:
			var tt := float(c) / 4.0
			var cp := p1.lerp(p2, tt) + Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
			b.card(cp, rng.randf_range(0.20, 0.34), rng.randf() * TAU, rng.randf_range(-0.6, 0.6), leaf)

# --- камыш ---

static func _reed(b: Builder, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(1.0, 1.7)
	b.height = h
	var stem := Color(0.18, 0.20, 0.10)
	var head := Color(0.16, 0.12, 0.07)
	for i in 6:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.05, 0.22)
		var top := dir + Vector3(0.0, h * rng.randf_range(0.8, 1.1), 0.0)
		b.tube(Vector3(0.0, 0.02, 0.0), top, 0.014, 0.006, 3, stem)
		var head_mesh_pos := top + Vector3(0.0, 0.12, 0.0)
		b.card(head_mesh_pos, 0.16, rng.randf() * TAU, 0.0, head)
