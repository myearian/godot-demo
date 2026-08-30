class_name ProcMaterials
extends Object
## Runtime-generated wallpaper, carpet, and ceiling-tile materials. No art packs.

static var floor_mat: StandardMaterial3D
static var wall_plain: StandardMaterial3D
static var wall_pattern: StandardMaterial3D
static var ceiling_mat: StandardMaterial3D
static var light_panel: StandardMaterial3D
static var dead_panel: StandardMaterial3D
static var flicker_panels: Array[StandardMaterial3D] = []
static var trim_mat: StandardMaterial3D
static var pillar_mat: StandardMaterial3D
static var table_top: StandardMaterial3D
static var table_leg: StandardMaterial3D
static var table_shadow: StandardMaterial3D
static var console_case: StandardMaterial3D
static var dead_screen: StandardMaterial3D
static var _ready := false

const CEIL_EMISSIVE := 0.12
const FLICKER_PANEL_BASE := 2.5


static func setup() -> void:
	if _ready:
		return
	_ready = true

	floor_mat = _lambert()
	floor_mat.albedo_color = Color(0.784, 0.710, 0.561) # #c8b58f
	floor_mat.albedo_texture = _carpet_tex()
	floor_mat.uv1_scale = Vector3(3.6, 3.6, 1.0)

	wall_plain = _lambert()
	wall_plain.albedo_color = Color(0.941, 0.894, 0.784) # #f0e4c8

	wall_pattern = _lambert()
	wall_pattern.albedo_color = Color(0.933, 0.902, 0.831) # #eee6d4
	wall_pattern.albedo_texture = _wallpaper_tex()
	wall_pattern.uv1_scale = Vector3(4.5, 2.8, 1.0)

	ceiling_mat = _lambert()
	ceiling_mat.albedo_color = Color(1.0, 0.910, 0.690) # #ffe8b0
	ceiling_mat.albedo_texture = _ceiling_tex()
	ceiling_mat.uv1_scale = Vector3(2.8, 2.8, 1.0)
	ceiling_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ceiling_mat.emission_enabled = true
	ceiling_mat.emission = Color(0.353, 0.290, 0.125) # #5a4a20
	ceiling_mat.emission_energy_multiplier = CEIL_EMISSIVE

	light_panel = _lambert()
	light_panel.albedo_color = Color.WHITE
	light_panel.emission_enabled = true
	light_panel.emission = Color(1.0, 0.894, 0.604) # #ffe49a
	light_panel.emission_energy_multiplier = FLICKER_PANEL_BASE
	light_panel.cull_mode = BaseMaterial3D.CULL_DISABLED

	dead_panel = _lambert()
	dead_panel.albedo_color = Color(0.149, 0.137, 0.118) # #26231e
	dead_panel.cull_mode = BaseMaterial3D.CULL_DISABLED

	flicker_panels.clear()
	for i in WorldGen.FLICKER_GROUPS:
		var fm: StandardMaterial3D = light_panel.duplicate()
		flicker_panels.append(fm)

	trim_mat = _lambert()
	trim_mat.albedo_color = Color(0.784, 0.737, 0.627) # #c8bca0

	pillar_mat = _lambert()
	pillar_mat.albedo_color = Color(0.910, 0.878, 0.800) # #e8e0cc

	table_top = _lambert()
	table_top.albedo_color = Color(0.839, 0.812, 0.737) # #d6cfbc

	table_leg = _lambert()
	table_leg.albedo_color = Color(0.298, 0.298, 0.314) # #4c4c50

	table_shadow = StandardMaterial3D.new()
	table_shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	table_shadow.albedo_texture = _contact_shadow_tex()
	table_shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	table_shadow.cull_mode = BaseMaterial3D.CULL_DISABLED
	table_shadow.albedo_color = Color(1, 1, 1, 1)

	console_case = _lambert()
	console_case.albedo_color = Color(0.106, 0.106, 0.125) # #1b1b20

	dead_screen = _lambert()
	dead_screen.albedo_color = Color(0.035, 0.043, 0.047) # #090b0c


static func wallpaper_for_length(length: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = wall_pattern.duplicate()
	m.uv1_scale = Vector3(4.5 * (length / WorldGen.TILE), 2.8, 1.0)
	return m


static func set_flicker_levels(levels: PackedFloat32Array) -> void:
	for i in flicker_panels.size():
		var lvl: float = levels[i] if i < levels.size() else 1.0
		flicker_panels[i].emission_energy_multiplier = FLICKER_PANEL_BASE * lvl


static func _lambert() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.texture_repeat = true
	return m


static func _carpet_tex() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color8(0xc8, 0xb5, 0x8f))
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC4A9E7
	for i in 280:
		var x := rng.randi_range(0, size - 1)
		var y := rng.randi_range(0, size - 1)
		var r := 1 + rng.randi_range(0, 2)
		_stamp_disk(img, x, y, r, Color(0.55, 0.45, 0.27, 1.0), 0.10)
	# A few larger tea-stain blobs.
	for i in 8:
		var sx := rng.randi_range(12, size - 12)
		var sy := rng.randi_range(12, size - 12)
		_stamp_disk(img, sx, sy, rng.randi_range(10, 22), Color(0.48, 0.38, 0.22, 1.0), 0.14)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _ceiling_tex() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var tile := 64
	for row in range(0, size, tile):
		for col in range(0, size, tile):
			var shade := 238 + int(WorldGen.hashf(float(col), float(row)) * 14.0)
			var c := Color8(shade, clampi(shade - 4, 0, 255), clampi(shade - 58, 0, 255))
			img.fill_rect(Rect2i(col + 2, row + 2, tile - 4, tile - 4), c)
			for i in 28:
				var px := col + 4 + int(WorldGen.hashf(col + i, float(row)) * float(tile - 8))
				var py := row + 4 + int(WorldGen.hashf(row + i, float(col)) * float(tile - 8))
				if px >= 0 and py >= 0 and px < size and py < size:
					img.set_pixel(px, py, Color(0.647, 0.569, 0.333, 1.0))
	var grid := Color8(0x9a, 0x88, 0x60)
	for i in range(0, size, tile):
		img.fill_rect(Rect2i(i, 0, 3, size), grid)
		img.fill_rect(Rect2i(0, i, size, 3), grid)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _wallpaper_tex() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color8(0xd8, 0xd4, 0xa8))
	var leaf := Color8(0x8a, 0x9a, 0x5c)
	var tile_w := 32
	var tile_h := 48
	for row in range(0, size, tile_h):
		for col in range(0, size, tile_w):
			var cx := col + tile_w * 0.5
			var cy := row + tile_h * 0.35
			_fill_triangle(img, cx, cy - 10.0, cx - 7.0, cy + 4.0, cx + 7.0, cy + 4.0, leaf)
			_fill_triangle(img, cx, cy - 2.0, cx - 3.0, cy + 4.0, cx + 3.0, cy + 4.0, leaf)
			img.fill_rect(Rect2i(int(cx) - 1, int(cy) + 4, 3, 14), leaf)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _contact_shadow_tex() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 128:
		for x in 128:
			var dx := (x - 64.0) / 64.0
			var dy := (y - 64.0) / 64.0
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if d < 0.125:
				a = 0.52
			elif d < 0.6:
				a = lerpf(0.52, 0.30, (d - 0.125) / 0.475)
			elif d < 1.0:
				a = lerpf(0.30, 0.0, (d - 0.6) / 0.4)
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)


static func _stamp_disk(img: Image, cx: int, cy: int, radius: int, color: Color, alpha: float) -> void:
	var size := img.get_width()
	var blended := color
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= size or y >= size:
				continue
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) > radius * radius:
				continue
			var src := img.get_pixel(x, y)
			img.set_pixel(x, y, src.lerp(blended, alpha))


static func _fill_triangle(img: Image, ax: float, ay: float, bx: float, by: float, cx: float, cy: float, color: Color) -> void:
	var minx := maxi(0, int(floor(minf(ax, minf(bx, cx)))))
	var maxx := mini(img.get_width() - 1, int(ceil(maxf(ax, maxf(bx, cx)))))
	var miny := maxi(0, int(floor(minf(ay, minf(by, cy)))))
	var maxy := mini(img.get_height() - 1, int(ceil(maxf(ay, maxf(by, cy)))))
	var area := (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
	if abs(area) < 0.0001:
		return
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			var w0 := ((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / area
			var w1 := ((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / area
			var w2 := 1.0 - w0 - w1
			if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
				img.set_pixel(x, y, color)
