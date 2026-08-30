class_name WorldGen
extends Object
## Deterministic Backrooms world queries (edges, pillars, tables, dark zones).
## Ported from myearian/BackroomsInfinite src/main.js — same constants and hash.

const TILE := 9.0
const WALL_H := 4.0
const WALL_T := 0.28
const DOORWAY_WIDTH := 4.5
const EYE_HEIGHT := 1.65

const DARK_BLOCK := 3
const DARK_ZONE_CHANCE := 0.22
const LONE_FLICKER_CHANCE := 0.05
const FLICKER_GROUPS := 4

const BIG_ROOM_BLOCK := 5
const BIG_ROOM_CHANCE := 0.04

const TABLE_CHANCE := 0.25
const TABLE_W := 2.2
const TABLE_D := 1.1
const TABLE_H := 0.74

const PILLAR_SIZE := 1.35
const POST_SIZE := 0.3


static func hashf(n1: float, n2: float) -> float:
	var h := sin(n1 * 12.9898 + n2 * 78.233) * 43758.5453
	return h - floor(h)


static func tile_coord(x: float) -> int:
	# Matches JS Math.round (half toward +inf).
	return int(floor(x / TILE + 0.5))


static func chunk_key(gx: int, gz: int) -> String:
	return "%d,%d" % [gx, gz]


static func big_room_block(gx: int, gz: int) -> Vector2i:
	return Vector2i(int(floor(float(gx) / BIG_ROOM_BLOCK)), int(floor(float(gz) / BIG_ROOM_BLOCK)))


static func in_big_room(gx: int, gz: int) -> bool:
	var b := big_room_block(gx, gz)
	return hashf(b.x * 1.37 + 0.5, b.y * 1.37 + 9.2) < BIG_ROOM_CHANCE


static func _edge_mid(gx: int, gz: int, dir: String) -> Vector2:
	match dir:
		"N":
			return Vector2(gx, gz - 0.5)
		"S":
			return Vector2(gx, gz + 0.5)
		"E":
			return Vector2(gx + 0.5, gz)
		_:
			return Vector2(gx - 0.5, gz)


static func get_edge_type(gx: int, gz: int, dir: String) -> String:
	if in_big_room(gx, gz):
		var ngx := gx
		var ngz := gz
		if dir == "E":
			ngx = gx + 1
		elif dir == "W":
			ngx = gx - 1
		elif dir == "S":
			ngz = gz + 1
		elif dir == "N":
			ngz = gz - 1
		var a := big_room_block(gx, gz)
		var b := big_room_block(ngx, ngz)
		if a == b:
			return "open"
	var m := _edge_mid(gx, gz, dir)
	# Same double-factor as the JS getEdgeType (hash already applies 12.9898 / 78.233).
	var h := hashf(m.x * 12.9898, m.y * 78.233)
	if h < 0.34:
		return "open"
	if h < 0.66:
		return "doorway"
	return "wall"


static func wall_seg_len(edge_type: String) -> float:
	if edge_type == "open":
		return 0.0
	if edge_type == "wall":
		return TILE
	return (TILE - DOORWAY_WIDTH) * 0.5


static func wall_seg_offset(edge_type: String) -> float:
	if edge_type != "doorway":
		return 0.0
	return DOORWAY_WIDTH * 0.5 + wall_seg_len("doorway") * 0.5


static func get_pillar(gx: int, gz: int) -> Variant:
	if in_big_room(gx, gz):
		return null
	var seed := hashf(float(gx), float(gz))
	if seed <= 0.78 or seed >= 0.9:
		return null
	var ox := 2.25 + hashf(gx * 3.1, float(gz)) * 0.4
	var oz := 2.25 + hashf(gz * 3.1, float(gx)) * 0.4
	var px := -ox if hashf(float(gx), gz * 5.7) < 0.5 else ox
	var pz := -oz if hashf(float(gz), gx * 5.7) < 0.5 else oz
	return Vector2(px, pz)


static func get_table(gx: int, gz: int) -> Variant:
	if hashf(gx * 5.31 + 7.7, gz * 5.31 + 3.3) >= TABLE_CHANCE:
		return null
	var dirs := ["N", "E", "S", "W"]
	var start := int(floor(hashf(gx * 1.93 + 4.2, gz * 1.93 + 6.6) * 4.0))
	var dir := ""
	for i in 4:
		var d: String = dirs[(start + i) % 4]
		if get_edge_type(gx, gz, d) == "wall":
			dir = d
			break
	if dir == "":
		return null
	var is_ns := dir == "N" or dir == "S"
	var hw := (TABLE_W if is_ns else TABLE_D) * 0.5
	var hd := (TABLE_D if is_ns else TABLE_W) * 0.5
	var wide := TABLE_W * 0.5
	var deep := TABLE_D * 0.5
	var half := TILE * 0.5
	var back_off := half - 0.14 - deep - 0.06
	var along := (hashf(gx * 8.21 + 0.7, gz * 8.21 + 5.9) - 0.5) * 2.0 * (half - wide - 0.9)
	var p = get_pillar(gx, gz)
	var px0 := along if is_ns else (-back_off if dir == "W" else back_off)
	var pz0 := (-back_off if dir == "N" else back_off) if is_ns else along
	if p != null:
		var pv: Vector2 = p
		if abs(px0 - pv.x) < hw + 1.0 and abs(pz0 - pv.y) < hd + 1.0:
			along = -along
	var tx := along if is_ns else (-back_off if dir == "W" else back_off)
	var tz := (-back_off if dir == "N" else back_off) if is_ns else along
	return {
		"x": tx,
		"z": tz,
		"hw": hw,
		"hd": hd,
		"dir": dir,
		"wide": wide,
		"deep": deep,
	}


static func get_tile_posts(gx: int, gz: int) -> Array:
	var h := TILE * 0.5
	var d := DOORWAY_WIDTH * 0.5
	var n_type := get_edge_type(gx, gz, "N")
	var w_type := get_edge_type(gx, gz, "W")
	var posts: Array = []
	if n_type != "open" or w_type != "open":
		posts.append(Vector3(-h, 0.0, -h))
	if n_type == "doorway":
		posts.append(Vector3(-d, 0.0, -h))
		posts.append(Vector3(d, 0.0, -h))
	if w_type == "doorway":
		posts.append(Vector3(-h, 0.0, -d))
		posts.append(Vector3(-h, 0.0, d))
	return posts


static func dark_block(gx: int, gz: int) -> Vector2i:
	return Vector2i(int(floor(float(gx) / DARK_BLOCK)), int(floor(float(gz) / DARK_BLOCK)))


static func flicker_group_at(gx: int, gz: int) -> int:
	return int(floor(hashf(gx * 8.11 + 0.3, gz * 8.11 + 0.6) * FLICKER_GROUPS))


static func tile_power(gx: int, gz: int) -> String:
	if abs(gx) <= 1 and abs(gz) <= 1:
		return "lit"
	var b := dark_block(gx, gz)
	if hashf(b.x * 2.71 + 3.13, b.y * 2.71 + 7.91) < DARK_ZONE_CHANCE:
		return "dead"
	if hashf(gx * 5.31 + 1.7, gz * 5.31 + 2.9) < LONE_FLICKER_CHANCE:
		return "flicker"
	return "lit"


static func flicker_level(group: int, t: float) -> float:
	var tt := t + group * 6.37
	var seg := int(floor(tt * 0.7))
	var mode := hashf(seg * 1.73 + group * 9.1, seg * 0.31 + group * 2.3)
	if mode > 0.30:
		return 1.0
	var f := int(floor(tt * 17.0))
	var r := hashf(f * 0.137 + group * 3.1, f * 0.711 - group * 1.9)
	if mode < 0.08:
		return 0.05 if r < 0.88 else 0.55
	if r < 0.35:
		return 0.06
	if r < 0.55:
		return 0.45
	return 1.0


static func edge_colliders_local(gx: int, gz: int) -> Array:
	## Returns dicts {pos: Vector3, size: Vector3} in tile-local space.
	var boxes: Array = []
	var h := TILE * 0.5
	for dir in ["N", "E", "S", "W"]:
		var edge_type := get_edge_type(gx, gz, dir)
		if edge_type == "open":
			continue
		var seg_len := wall_seg_len(edge_type)
		var seg_off := wall_seg_offset(edge_type)
		if edge_type == "wall":
			match dir:
				"E":
					boxes.append({"pos": Vector3(h, WALL_H * 0.5, 0.0), "size": Vector3(WALL_T, WALL_H, TILE)})
				"W":
					boxes.append({"pos": Vector3(-h, WALL_H * 0.5, 0.0), "size": Vector3(WALL_T, WALL_H, TILE)})
				"S":
					boxes.append({"pos": Vector3(0.0, WALL_H * 0.5, h), "size": Vector3(TILE, WALL_H, WALL_T)})
				"N":
					boxes.append({"pos": Vector3(0.0, WALL_H * 0.5, -h), "size": Vector3(TILE, WALL_H, WALL_T)})
			continue
		match dir:
			"E":
				boxes.append({"pos": Vector3(h, WALL_H * 0.5, -seg_off), "size": Vector3(WALL_T, WALL_H, seg_len)})
				boxes.append({"pos": Vector3(h, WALL_H * 0.5, seg_off), "size": Vector3(WALL_T, WALL_H, seg_len)})
			"W":
				boxes.append({"pos": Vector3(-h, WALL_H * 0.5, -seg_off), "size": Vector3(WALL_T, WALL_H, seg_len)})
				boxes.append({"pos": Vector3(-h, WALL_H * 0.5, seg_off), "size": Vector3(WALL_T, WALL_H, seg_len)})
			"S":
				boxes.append({"pos": Vector3(-seg_off, WALL_H * 0.5, h), "size": Vector3(seg_len, WALL_H, WALL_T)})
				boxes.append({"pos": Vector3(seg_off, WALL_H * 0.5, h), "size": Vector3(seg_len, WALL_H, WALL_T)})
			"N":
				boxes.append({"pos": Vector3(-seg_off, WALL_H * 0.5, -h), "size": Vector3(seg_len, WALL_H, WALL_T)})
				boxes.append({"pos": Vector3(seg_off, WALL_H * 0.5, -h), "size": Vector3(seg_len, WALL_H, WALL_T)})
	var pillar = get_pillar(gx, gz)
	if pillar != null:
		var pv: Vector2 = pillar
		boxes.append({
			"pos": Vector3(pv.x, WALL_H * 0.5, pv.y),
			"size": Vector3(PILLAR_SIZE, WALL_H, PILLAR_SIZE),
		})
	for p in get_tile_posts(gx, gz):
		var post: Vector3 = p
		boxes.append({
			"pos": Vector3(post.x, WALL_H * 0.5, post.z),
			"size": Vector3(POST_SIZE, WALL_H, POST_SIZE),
		})
	return boxes
