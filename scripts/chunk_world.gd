extends Node3D
## Streams 9 m Backrooms tiles around the player and drives a pooled light set.

const RENDER_DIST := 5
const LIGHT_POOL_SIZE := 30
const POINT_ENERGY := 4.8
const POINT_RANGE := 20.0
const LIGHT_NEAR := 1.6 * WorldGen.TILE

var _chunks: Dictionary = {} # String -> Dictionary
var _lights: Array[OmniLight3D] = []
var _flicker_clock := 0.0
var _wall_mats: Dictionary = {} # float length -> Material


func setup() -> void:
	ProcMaterials.setup()
	for i in LIGHT_POOL_SIZE:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.874, 0.565) # #ffdf90
		light.light_energy = 0.0
		light.light_specular = 0.15
		light.omni_range = POINT_RANGE
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.position = Vector3(0.0, -50.0, 0.0)
		add_child(light)
		_lights.append(light)


func update_world(player: Node3D, delta: float) -> void:
	var gx := WorldGen.tile_coord(player.global_position.x)
	var gz := WorldGen.tile_coord(player.global_position.z)
	_sync_chunks(gx, gz)
	_flicker_clock += delta
	var levels := PackedFloat32Array()
	levels.resize(WorldGen.FLICKER_GROUPS)
	for i in WorldGen.FLICKER_GROUPS:
		levels[i] = WorldGen.flicker_level(i, _flicker_clock)
	ProcMaterials.set_flicker_levels(levels)
	_update_lights(player, levels)


func _sync_chunks(cx: int, cz: int) -> void:
	var wanted: Dictionary = {}
	for dz in range(-RENDER_DIST, RENDER_DIST + 1):
		for dx in range(-RENDER_DIST, RENDER_DIST + 1):
			wanted[WorldGen.chunk_key(cx + dx, cz + dz)] = Vector2i(cx + dx, cz + dz)
	var stale: Array = []
	for key in _chunks.keys():
		if not wanted.has(key):
			stale.append(key)
	for key in stale:
		var data: Dictionary = _chunks[key]
		(data["node"] as Node).queue_free()
		_chunks.erase(key)
	for key in wanted.keys():
		if _chunks.has(key):
			continue
		var g: Vector2i = wanted[key]
		_chunks[key] = _build_tile(g.x, g.y)


func _update_lights(player: Node3D, flicker_levels: PackedFloat32Array) -> void:
	var origin := player.global_position
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()

	var candidates: Array = []
	for data in _chunks.values():
		var lp: Vector3 = data["light_pos"]
		var to := lp - origin
		to.y = 0.0
		var d2 := to.length_squared()
		var facing := 1.0
		if d2 > 0.04:
			facing = forward.dot(to.normalized())
		var near := d2 < LIGHT_NEAR * LIGHT_NEAR
		var score := d2
		if not near and facing < 0.05:
			score += 8000.0
		candidates.append({"data": data, "score": score})
	candidates.sort_custom(func(a, b): return a["score"] < b["score"])

	for light in _lights:
		light.light_energy = 0.0
		light.position = Vector3(0, -50, 0)

	var n := mini(LIGHT_POOL_SIZE, candidates.size())
	for i in n:
		var data: Dictionary = candidates[i]["data"]
		var light := _lights[i]
		light.global_position = data["light_pos"]
		var power: String = data["power"]
		var energy := 0.0
		if power == "dead":
			energy = 0.0
		elif power == "flicker":
			var g: int = data["flicker_group"]
			var lvl: float = flicker_levels[g] if g < flicker_levels.size() else 1.0
			energy = POINT_ENERGY * lvl
		else:
			energy = POINT_ENERGY
		light.light_energy = energy


func _build_tile(gx: int, gz: int) -> Dictionary:
	var tile := Node3D.new()
	tile.name = "Tile_%d_%d" % [gx, gz]
	tile.position = Vector3(gx * WorldGen.TILE, 0.0, gz * WorldGen.TILE)
	add_child(tile)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	tile.add_child(body)

	# Floor + ceiling
	_add_plane(tile, Vector2(WorldGen.TILE + 0.2, WorldGen.TILE + 0.2), Vector3(0, 0.01, 0), ProcMaterials.floor_mat, 0.0)
	_add_plane(tile, Vector2(WorldGen.TILE + 0.2, WorldGen.TILE + 0.2), Vector3(0, WorldGen.WALL_H - 0.02, 0), ProcMaterials.ceiling_mat, PI)
	_add_collider(body, Vector3(WorldGen.TILE + 0.2, 0.2, WorldGen.TILE + 0.2), Vector3(0, -0.1, 0))

	var half := WorldGen.TILE * 0.5
	# Visual walls on N/W only (neighbor tiles draw S/E) to avoid coplanar z-fight.
	for dir in ["N", "W"]:
		_add_wall_visual(tile, dir, WorldGen.get_edge_type(gx, gz, dir), half)

	var pillar = WorldGen.get_pillar(gx, gz)
	if pillar != null:
		var pv: Vector2 = pillar
		_add_box(tile, Vector3(WorldGen.PILLAR_SIZE, WorldGen.WALL_H, WorldGen.PILLAR_SIZE), Vector3(pv.x, WorldGen.WALL_H * 0.5, pv.y), ProcMaterials.pillar_mat)
		_add_box(tile, Vector3(1.55, 0.14, 1.55), Vector3(pv.x, 0.07, pv.y), ProcMaterials.trim_mat)

	for p in WorldGen.get_tile_posts(gx, gz):
		var post: Vector3 = p
		_add_box(tile, Vector3(WorldGen.POST_SIZE, WorldGen.WALL_H, WorldGen.POST_SIZE), Vector3(post.x, WorldGen.WALL_H * 0.5, post.z), _wallpaper_mat(WorldGen.POST_SIZE))
		_add_box(tile, Vector3(WorldGen.POST_SIZE + 0.04, 0.12, WorldGen.POST_SIZE + 0.04), Vector3(post.x, 0.06, post.z), ProcMaterials.trim_mat)

	var table = WorldGen.get_table(gx, gz)
	if table != null:
		_add_table(tile, body, gx, gz, table)

	for box in WorldGen.edge_colliders_local(gx, gz):
		_add_collider(body, box["size"], box["pos"])

	var power := WorldGen.tile_power(gx, gz)
	var fg := WorldGen.flicker_group_at(gx, gz)
	var panel_mat: Material = ProcMaterials.light_panel
	if power == "dead":
		panel_mat = ProcMaterials.dead_panel
	elif power == "flicker":
		panel_mat = ProcMaterials.flicker_panels[fg]
	_add_ceiling_fixture(tile, panel_mat)

	var light_pos := Vector3(gx * WorldGen.TILE, WorldGen.WALL_H - 0.28, gz * WorldGen.TILE)
	return {
		"node": tile,
		"gx": gx,
		"gz": gz,
		"light_pos": light_pos,
		"power": power,
		"flicker_group": fg,
	}


func _add_wall_visual(tile: Node3D, dir: String, edge_type: String, half: float) -> void:
	if edge_type == "open":
		return
	var is_ns := dir == "N" or dir == "S"
	var normal := 0.0
	if is_ns:
		normal = -half if dir == "N" else half
	else:
		normal = -half if dir == "W" else half
	var ranges: Array = []
	if edge_type == "wall":
		ranges.append(Vector2(-half, half))
	else:
		var d := WorldGen.DOORWAY_WIDTH * 0.5
		ranges.append(Vector2(-half, -d))
		ranges.append(Vector2(d, half))
	for r in ranges:
		var a0: float = r.x
		var a1: float = r.y
		var length := a1 - a0
		if length <= 0.01:
			continue
		var center := (a0 + a1) * 0.5
		var wx := center if is_ns else normal
		var wz := normal if is_ns else center
		var size := Vector3(length if is_ns else WorldGen.WALL_T, WorldGen.WALL_H, WorldGen.WALL_T if is_ns else length)
		_add_box(tile, size, Vector3(wx, WorldGen.WALL_H * 0.5, wz), _wallpaper_mat(length))
		var trim_size := Vector3(
			length if is_ns else WorldGen.WALL_T + 0.04,
			0.12,
			WorldGen.WALL_T + 0.04 if is_ns else length
		)
		_add_box(tile, trim_size, Vector3(wx, 0.06, wz), ProcMaterials.trim_mat)


func _add_ceiling_fixture(tile: Node3D, panel_mat: Material) -> void:
	var y := WorldGen.WALL_H - 0.03
	var width := 2.7
	var depth := 0.9
	var frame_t := 0.05
	var frame_w := 0.07
	var outer_w := width + 0.14
	var outer_d := depth + 0.14
	_add_box(tile, Vector3(outer_w, frame_t, frame_w), Vector3(0, y, -outer_d * 0.5 + frame_w * 0.5), ProcMaterials.trim_mat)
	_add_box(tile, Vector3(outer_w, frame_t, frame_w), Vector3(0, y, outer_d * 0.5 - frame_w * 0.5), ProcMaterials.trim_mat)
	_add_box(tile, Vector3(frame_w, frame_t, outer_d - frame_w * 2.0), Vector3(-outer_w * 0.5 + frame_w * 0.5, y, 0), ProcMaterials.trim_mat)
	_add_box(tile, Vector3(frame_w, frame_t, outer_d - frame_w * 2.0), Vector3(outer_w * 0.5 - frame_w * 0.5, y, 0), ProcMaterials.trim_mat)
	_add_plane(tile, Vector2(width, depth), Vector3(0, y - 0.015, 0), panel_mat, PI)


func _add_table(tile: Node3D, body: StaticBody3D, gx: int, gz: int, table: Dictionary) -> void:
	var tx: float = table["x"]
	var tz: float = table["z"]
	var hw: float = table["hw"]
	var hd: float = table["hd"]
	var dir: String = table["dir"]
	var wide: float = table["wide"]
	var deep: float = table["deep"]

	_add_plane(tile, Vector2(hw * 2.0 + 0.6, hd * 2.0 + 0.6), Vector3(tx, 0.02, tz), ProcMaterials.table_shadow, 0.0)
	_add_box(tile, Vector3(hw * 2.0, 0.06, hd * 2.0), Vector3(tx, WorldGen.TABLE_H - 0.03, tz), ProcMaterials.table_top)
	_add_collider(body, Vector3(hw * 2.0, 0.06, hd * 2.0), Vector3(tx, WorldGen.TABLE_H - 0.03, tz))
	var lx := hw - 0.09
	var lz := hd - 0.09
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg_h := WorldGen.TABLE_H - 0.06
			var lp := Vector3(tx + sx * lx, leg_h * 0.5, tz + sz * lz)
			_add_box(tile, Vector3(0.06, leg_h, 0.06), lp, ProcMaterials.table_leg)
			_add_collider(body, Vector3(0.06, leg_h, 0.06), lp)

	var out_x := 1.0 if dir == "W" else (-1.0 if dir == "E" else 0.0)
	var out_z := 1.0 if dir == "N" else (-1.0 if dir == "S" else 0.0)
	var along_x := 1.0 if out_z != 0.0 else 0.0
	var along_z := 1.0 if out_x != 0.0 else 0.0

	var chair_n := int(floor(WorldGen.hashf(gx * 6.7 + 2.9, gz * 6.7 + 8.1) * 3.0))
	for ci in chair_n:
		var a := (WorldGen.hashf(gx * 3.3 + ci * 7.7 + 1.1, gz * 3.3 + ci * 5.1 + 9.4) - 0.5) * wide * 1.5
		var out_amt := deep + 0.4 + WorldGen.hashf(gx + ci * 2.3, gz * 1.7 + ci) * 0.18
		var cx := tx + out_x * out_amt + along_x * a
		var cz := tz + out_z * out_amt + along_z * a
		var yaw := atan2(-out_x, -out_z) + (WorldGen.hashf(gx * 9.4 + ci, gz * 6.2 + ci * 3.7) - 0.5) * 0.9
		_add_chair(tile, cx, cz, yaw)

	var con_r := WorldGen.hashf(gx * 4.9 + 3.3, gz * 4.9 + 7.9)
	if con_r < 0.55:
		var con_yaw := atan2(-out_x, -out_z) + (WorldGen.hashf(gx * 2.2 + 8.8, gz * 2.2 + 0.4) - 0.5) * 0.8
		var a := (WorldGen.hashf(gx * 7.1 + 5.5, gz * 7.1 + 2.2) - 0.5) * wide
		if con_r < 0.36:
			_add_busted_console(tile, tx + along_x * a, WorldGen.TABLE_H, tz + along_z * a, con_yaw, false)
		else:
			var fx := tx + out_x * (deep + 0.5) + along_x * a
			var fz := tz + out_z * (deep + 0.5) + along_z * a
			_add_busted_console(tile, fx, 0.01, fz, con_yaw + 1.2, WorldGen.hashf(gx * 8.8, gz * 8.8) < 0.5)


func _add_chair(tile: Node3D, cx: float, cz: float, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(cx, 0.0, cz)
	holder.rotation.y = yaw
	tile.add_child(holder)
	_add_box(holder, Vector3(0.42, 0.05, 0.40), Vector3(0, 0.44, 0), ProcMaterials.table_top)
	_add_box(holder, Vector3(0.40, 0.50, 0.05), Vector3(0, 0.72, -0.19), ProcMaterials.table_top)
	_add_box(holder, Vector3(0.04, 0.44, 0.04), Vector3(0.17, 0.22, 0.16), ProcMaterials.table_leg)
	_add_box(holder, Vector3(0.04, 0.44, 0.04), Vector3(-0.17, 0.22, 0.16), ProcMaterials.table_leg)
	_add_box(holder, Vector3(0.04, 0.70, 0.04), Vector3(0.17, 0.35, -0.17), ProcMaterials.table_leg)
	_add_box(holder, Vector3(0.04, 0.70, 0.04), Vector3(-0.17, 0.35, -0.17), ProcMaterials.table_leg)


func _add_busted_console(tile: Node3D, x: float, y: float, z: float, yaw: float, tip: bool) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(x, y, z)
	holder.rotation.y = yaw
	if tip:
		holder.rotation.z = 1.35
		holder.position.y += 0.04
	tile.add_child(holder)
	_add_box(holder, Vector3(0.52, 0.18, 0.40), Vector3(0, 0.09, 0), ProcMaterials.console_case)
	var face := MeshInstance3D.new()
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.46, 0.30, 0.06)
	face.mesh = face_mesh
	face.material_override = ProcMaterials.console_case
	face.position = Vector3(0, 0.30, -0.05)
	face.rotation.x = -0.42
	holder.add_child(face)
	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.36, 0.20, 0.02)
	screen.mesh = screen_mesh
	screen.material_override = ProcMaterials.dead_screen
	screen.position = Vector3(0, 0.30, -0.09)
	screen.rotation.x = -0.42
	holder.add_child(screen)


func _wallpaper_mat(length: float) -> Material:
	var key := snappedf(length, 0.05)
	if not _wall_mats.has(key):
		_wall_mats[key] = ProcMaterials.wallpaper_for_length(length)
	return _wall_mats[key]


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _add_plane(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, rot_x: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = rot_x
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _add_collider(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
