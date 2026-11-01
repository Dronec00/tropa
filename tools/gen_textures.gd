extends SceneTree

## Генератор процедурных текстур. Запуск:
##   godot --headless --path . --script res://tools/gen_textures.gd
## Пишет PNG в assets/textures. Все текстуры тайлятся (периодический шум).

const SIZE := 512
const OUT := "res://assets/textures/"

var _rng := RandomNumberGenerator.new()
var _heights := PackedFloat32Array()

func _initialize() -> void:
	_rng.seed = 20261101
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_gen_ground()
	_gen_bark("birch", Color(0.80, 0.80, 0.76), Color(0.16, 0.15, 0.14), 0.35, true)
	_gen_bark("spruce", Color(0.20, 0.15, 0.11), Color(0.05, 0.04, 0.03), 0.65, false)
	_gen_leaf_atlas()
	print("[tex] готово")
	quit()

# --- шум ---

func _grid(cells: int) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(cells * cells)
	for i in g.size():
		g[i] = _rng.randf()
	return g

func _sample(grid: PackedFloat32Array, cells: int, u: float, v: float) -> float:
	var fx := u * float(cells)
	var fy := v * float(cells)
	var x0 := int(floor(fx)) % cells
	var y0 := int(floor(fy)) % cells
	var x1 := (x0 + 1) % cells
	var y1 := (y0 + 1) % cells
	var tx: float = fx - floor(fx)
	var ty: float = fy - floor(fy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := grid[y0 * cells + x0]
	var b := grid[y0 * cells + x1]
	var c := grid[y1 * cells + x0]
	var d := grid[y1 * cells + x1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

func _fbm(u: float, v: float, base_cells: int, octaves: int, grids: Array) -> float:
	var total := 0.0
	var amp := 1.0
	var norm := 0.0
	for o in octaves:
		var cells := base_cells * int(pow(2.0, float(o)))
		total += _sample(grids[o], cells, u, v) * amp
		norm += amp
		amp *= 0.5
	return total / norm

func _make_grids(base_cells: int, octaves: int) -> Array:
	var grids: Array = []
	for o in octaves:
		grids.append(_grid(base_cells * int(pow(2.0, float(o)))))
	return grids

# --- земля ---

func _gen_ground() -> void:
	var size := SIZE
	var grids := _make_grids(4, 5)
	var fine := _make_grids(16, 3)

	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rough := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := PackedFloat32Array()
	height.resize(size * size)

	for y in size:
		for x in size:
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			var n := _fbm(u, v, 4, 5, grids)
			var f := _fbm(u, v, 16, 3, fine)
			var h := n * 0.8 + f * 0.2
			height[y * size + x] = h

			var moss := clampf((n - 0.42) * 3.2, 0.0, 1.0)
			var litter := clampf((0.55 - n) * 2.6, 0.0, 1.0)
			var sand := clampf((0.36 - n) * 4.0, 0.0, 1.0)
			var base := Color(0.92, 0.92, 0.88).lerp(Color(0.80, 0.87, 0.72), moss)
			base = base.lerp(Color(0.72, 0.60, 0.44), litter * 0.85)
			base = base.lerp(Color(0.98, 0.93, 0.80), sand * 0.7)
			# хвойные иглы: тонкие штрихи
			var needle := sin(u * 900.0 + f * 22.0) * sin(v * 90.0 + n * 12.0)
			if needle > 0.55:
				base = base.lerp(Color(0.62, 0.46, 0.30), 0.5)
			var speck := 0.62 + f * 0.58
			base = Color(base.r * speck, base.g * speck, base.b * speck)
			if f > 0.84:
				base = base.lightened(0.10)
			albedo.set_pixel(x, y, base)

			var r := clampf(0.72 + f * 0.28, 0.0, 1.0)
			rough.set_pixel(x, y, Color(r, r, r))

	albedo.save_png(OUT + "ground_albedo.png")
	rough.save_png(OUT + "ground_rough.png")
	_normal_from_height(height, size, 2.2).save_png(OUT + "ground_normal.png")

func _normal_from_height(height: PackedFloat32Array, size: int, strength: float) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var xl := (x - 1 + size) % size
			var xr := (x + 1) % size
			var yu := (y - 1 + size) % size
			var yd := (y + 1) % size
			var hx := height[y * size + xr] - height[y * size + xl]
			var hy := height[yd * size + x] - height[yu * size + x]
			var n := Vector3(-hx * strength, 1.0, -hy * strength).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return img

# --- кора ---

func _gen_bark(name: String, base: Color, dark: Color, crack_amount: float, birch: bool) -> void:
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var grids := _make_grids(6, 3)
	var fine_grids := _make_grids(24, 2)

	for y in h:
		for x in w:
			var u := float(x) / float(w)
			var v := float(y) / float(h)
			var n := _fbm(u, v, 6, 3, grids)
			var f := _fbm(u, v, 24, 2, fine_grids)

			var col := base.lerp(dark, clampf((n - 0.45) * 2.2, 0.0, 1.0) * (0.4 + crack_amount))

			if birch:
				# горизонтальные чёрточки
				var dash := sin(v * 120.0 + n * 9.0) * sin(u * 26.0 + f * 6.0)
				if dash > 0.72:
					col = col.darkened(0.55 + 0.2 * f)
				if n > 0.78:
					col = col.darkened(0.4)
			else:
				# вертикальные трещины
				var crack := sin(u * 34.0 + n * 7.0) * sin(v * 3.0 + f * 4.0)
				if crack > 0.55:
					col = col.darkened(0.45)
				var ring := sin(v * 42.0 + n * 5.0)
				if ring > 0.85:
					col = col.darkened(0.25)

			col = Color(
				clampf(col.r * (0.9 + f * 0.2), 0.0, 1.0),
				clampf(col.g * (0.9 + f * 0.2), 0.0, 1.0),
				clampf(col.b * (0.9 + f * 0.2), 0.0, 1.0)
			)
			img.set_pixel(x, y, col)

	img.save_png(OUT + name + "_bark.png")

# --- атлас листвы ---

func _gen_leaf_atlas() -> void:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)

	for i in 96:
		var cx := _rng.randf_range(0.15, 0.85) * size
		var cy := _rng.randf_range(0.15, 0.85) * size
		var len := _rng.randf_range(11.0, 21.0)
		var wid := _rng.randf_range(5.0, 10.0)
		var ang := _rng.randf_range(0.0, TAU)
		var tint := Color(
			_rng.randf_range(0.10, 0.22),
			_rng.randf_range(0.18, 0.34),
			_rng.randf_range(0.06, 0.14)
		)
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)

		for py in range(int(cy - len - 4.0), int(cy + len + 4.0)):
			for px in range(int(cx - len - 4.0), int(cx + len + 4.0)):
				if px < 0 or py < 0 or px >= size or py >= size:
					continue
				var p := Vector2(px, py) - Vector2(cx, cy)
				var along := p.dot(dir) / len
				var across := p.dot(side) / wid
				if absf(along) > 1.0:
					continue
				var taper: float = 1.0 - absf(along) * 0.85
				var dist: float = absf(across) / maxf(taper, 0.15)
				if dist < 1.0:
					var alpha: float = clampf(1.0 - dist * dist, 0.0, 1.0)
					var px_old := img.get_pixel(px, py)
					if alpha > px_old.a:
						var shade := 0.8 + 0.2 * (1.0 - absf(along))
						img.set_pixel(px, py, Color(tint.r * shade, tint.g * shade, tint.b * shade, alpha))

	img.save_png(OUT + "leaf_atlas.png")
