extends RefCounted
## Shared human-scale art for both landings, the moving cage and small stones.
const Bounds := preload("res://scripts/world/sprite_body_bounds.gd")
const TUNNEL := preload("res://assets/phase2/mine_tunnel_iron_v1.png")
const SURFACE := preload("res://assets/phase2/mine_yard_pixel_v3.png")
const HOUSE := preload("res://assets/phase2/mine_winding_house_v1.png")
const SHAFT := preload("res://assets/phase2/mine_vertical_shaft_v1.png")
const EXTRACTION := preload("res://assets/phase2/mine_extraction_gallery_v1.png")
const PARTS := preload("res://assets/phase2/mine_lift_parts_v1.png")
const FLOOR_Y: float = 414.0
const ROOF_Y: float = 188.0
const LIFT_X: float = 95.0
const SURFACE_LANDING := Vector2(765, 333)
const HOUSE_LANDING := Vector2(765, 452)
const HOUSE_EXIT := Vector2(665, 482)
const HERO_SCALE: float = 1.8
static var cache: Dictionary = {}
static var hero_cache: Dictionary = {}

static func part(index: int) -> Texture2D:
	if cache.has(index): return cache[index]
	# The sheet uses a tall first row; preserve its actual cells.
	var dimensions := PARTS.get_size()
	var split := floorf(dimensions.y * 0.63)
	var cell := Rect2((index % 2) * dimensions.x * 0.5, 0 if index < 2 else split, dimensions.x * 0.5, split if index < 2 else dimensions.y - split)
	var bounds := Bounds.measure(PARTS.get_image().get_region(Rect2i(cell)))
	var texture := AtlasTexture.new()
	texture.atlas = PARTS
	texture.region = Rect2(cell.position + Vector2(bounds.position), Vector2(bounds.size))
	cache[index] = texture
	return texture

static func hero(texture: Texture2D, region: Rect2) -> Texture2D:
	var key := str(texture.get_rid()) + str(region)
	if hero_cache.has(key): return hero_cache[key]
	var bounds := Bounds.measure(texture.get_image().get_region(Rect2i(region)))
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = Rect2(region.position + Vector2(bounds.position), Vector2(bounds.size))
	hero_cache[key] = result
	return result

static func cage_size(hero_height: float) -> Vector2:
	var texture := part(0)
	var height := hero_height * 1.85
	return Vector2(height * texture.get_width() / texture.get_height(), height)

static func draw_cage(canvas: CanvasItem, feet: Vector2, hero_height: float, closed: float, person: Texture2D = null, person_offset: Vector2 = Vector2.ZERO) -> void:
	var dimensions := cage_size(hero_height)
	canvas.draw_texture_rect(part(0), Rect2(feet - Vector2(dimensions.x * 0.5, dimensions.y - 8), dimensions), false)
	if person != null:
		var person_size := Vector2(hero_height * person.get_width() / person.get_height(), hero_height)
		canvas.draw_texture_rect(person, Rect2(feet + person_offset - Vector2(person_size.x * 0.5, hero_height), person_size), false)
	if closed > 0.001:
		var gate := part(1)
		var width := dimensions.x * 0.96
		var height := minf(width * gate.get_height() / gate.get_width(), hero_height * 0.48)
		var top := feet.y - height - (1.0 - closed) * (dimensions.y - height - 18)
		canvas.draw_texture_rect(gate, Rect2(feet.x - width * 0.5, top, width, height), false, Color(1, 1, 1, minf(1, closed * 5)))
