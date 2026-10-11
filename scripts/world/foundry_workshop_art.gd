extends RefCounted
const Bounds := preload("res://scripts/world/sprite_body_bounds.gd")
const BACKGROUNDS := [preload("res://assets/phase2/foundry_workbench_v1.png"), preload("res://assets/phase2/foundry_reheating_hearth_v1.png"), preload("res://assets/phase2/foundry_steam_hammer_bay_v1.png"), preload("res://assets/phase2/foundry_belt_drill_bay_v1.png")]
const MATERIALS := preload("res://assets/phase2/foundry_materials_atlas_v1.png")
const MACHINES := preload("res://assets/phase2/foundry_machine_parts_atlas_v1.png")
const TOOLS := preload("res://assets/phase2/foundry_interactive_tools_v2.png")
static var cache: Dictionary = {}

static func tool(index: int) -> Texture2D:
	if cache.has(60 + index): return cache[60 + index]
	var regions := [Rect2(0, 0, 0.28, 0.46), Rect2(0.29, 0, 0.19, 0.46), Rect2(0.50, 0.20, 0.19, 0.18), Rect2(0.69, 0.18, 0.31, 0.14), Rect2(0.05, 0.47, 0.10, 0.50), Rect2(0.25, 0.46, 0.24, 0.51), Rect2(0.50, 0.46, 0.18, 0.51), Rect2(0.69, 0.54, 0.31, 0.39)]
	var region := Rect2(regions[index].position * TOOLS.get_size(), regions[index].size * TOOLS.get_size())
	var bounds := Bounds.measure(TOOLS.get_image().get_region(Rect2i(region)))
	var texture := AtlasTexture.new()
	texture.atlas = TOOLS
	texture.region = Rect2(region.position + Vector2(bounds.position), Vector2(bounds.size))
	cache[60 + index] = texture
	return texture

static func part(index: int, machine: bool = false) -> Texture2D:
	var key := index + (20 if machine else 0)
	if cache.has(key): return cache[key]
	var source: Texture2D = MACHINES if machine else MATERIALS
	var region := Rect2(Vector2(index % 4, index / 4) * source.get_size() / Vector2(4, 3), source.get_size() / Vector2(4, 3))
	if machine:
		# Generated components have uneven row heights; regions exclude neighbouring sprites.
		var regions := [Rect2(0, 0, 0.25, 0.41), Rect2(0.27, 0, 0.21, 0.41), Rect2(0.50, 0, 0.23, 0.41), Rect2(0.74, 0, 0.26, 0.41), Rect2(0, 0.41, 0.25, 0.35), Rect2(0.25, 0.49, 0.25, 0.23), Rect2(0.50, 0.49, 0.34, 0.23), Rect2(0.85, 0.50, 0.15, 0.22), Rect2(0, 0.77, 0.25, 0.23), Rect2(0.26, 0.77, 0.23, 0.23), Rect2(0.50, 0.77, 0.23, 0.23), Rect2(0.74, 0.77, 0.26, 0.23)]
		region = Rect2(regions[index].position * source.get_size(), regions[index].size * source.get_size())
	else:
		var columns := [0.0, 0.25, 0.495, 0.735, 1.0]
		var rows := [0.0, 0.40, 0.69, 1.0]
		var column := index % 4
		var row := index / 4
		region = Rect2(Vector2(columns[column], rows[row]) * source.get_size(), Vector2(columns[column + 1] - columns[column], rows[row + 1] - rows[row]) * source.get_size())
		if index == 2: region.size.x = source.get_width() * 0.225
		if index == 3:
			region.position.x = source.get_width() * 0.72
			region.size.x = source.get_width() * 0.28
	var bounds := Bounds.measure(source.get_image().get_region(Rect2i(region)))
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = Rect2(region.position + Vector2(bounds.position), Vector2(bounds.size))
	cache[key] = texture
	return texture

static func piston_rod() -> Texture2D:
	if cache.has(40): return cache[40]
	var piston := part(5, true) as AtlasTexture
	var rod := AtlasTexture.new()
	rod.atlas = piston.atlas
	rod.region = Rect2(piston.region.position + piston.region.size * Vector2(0.64, 0.37), piston.region.size * Vector2(0.26, 0.25))
	cache[40] = rod
	return rod

static func pin_cap(index: int) -> Texture2D:
	if cache.has(41 + index): return cache[41 + index]
	var pin := part(7 + index, true) as AtlasTexture
	var cap := AtlasTexture.new()
	cap.atlas = pin.atlas
	cap.region = Rect2(pin.region.position, pin.region.size * Vector2(0.34, 1))
	cache[41 + index] = cap
	return cap
