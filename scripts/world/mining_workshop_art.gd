extends RefCounted
const Bounds := preload("res://scripts/world/sprite_body_bounds.gd")
const SOURCES := [preload("res://assets/phase2/mining_workshop_tools_v1.png"), preload("res://assets/phase2/mining_rail_parts_v1.png"), preload("res://assets/phase2/tools_pixel_v1.png"), preload("res://assets/phase2/iron_mission_parts_pixel_v2.png"), preload("res://assets/phase2/coal_extraction_props_v1.png")]
static var cache: Dictionary = {}

static func part(index: int, sheet: int = 0) -> Texture2D:
	var key := sheet * 20 + index
	if cache.has(key): return cache[key]
	var source: Texture2D = SOURCES[sheet]
	var grid: Vector2 = [Vector2(2, 3), Vector2(2, 3), Vector2(4, 3), Vector2(4, 2), Vector2(3, 2)][sheet]
	var cell := source.get_size() / grid
	var region := Rect2(Vector2(index % int(grid.x), floori(index / grid.x)) * cell, cell)
	if sheet == 0:
		# The generated balance base is taller than the first row of braces.
		var rows := [0.0, 0.34, 0.72, 1.0]
		var row := index / 2
		region = Rect2((index % 2) * cell.x, rows[row] * source.get_height(), cell.x, (rows[row + 1] - rows[row]) * source.get_height())
	var bounds := Bounds.measure(source.get_image().get_region(Rect2i(region)))
	var result := AtlasTexture.new()
	result.atlas = source
	result.region = Rect2(region.position + Vector2(bounds.position), Vector2(bounds.size))
	cache[key] = result
	return result
