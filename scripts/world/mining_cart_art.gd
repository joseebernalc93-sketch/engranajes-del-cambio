extends RefCounted
## The same cart and rails appear in exploration and during the extraction game.
const Bounds := preload("res://scripts/world/sprite_body_bounds.gd")
const TEXTURE := preload("res://assets/phase2/mining_cart_parts_v1.png")
static var cache: Dictionary = {}

static func part(index: int) -> Texture2D:
	if cache.has(index): return cache[index]
	var cells := [Rect2(0, 0, 0.70, 0.55), Rect2(0.70, 0, 0.30, 0.55), Rect2(0, 0.55, 0.54, 0.45), Rect2(0.54, 0.55, 0.46, 0.45)]
	var region := Rect2(cells[index].position * TEXTURE.get_size(), cells[index].size * TEXTURE.get_size())
	var bounds := Bounds.measure(TEXTURE.get_image().get_region(Rect2i(region)))
	var result := AtlasTexture.new()
	result.atlas = TEXTURE
	result.region = Rect2(region.position + Vector2(bounds.position), Vector2(bounds.size))
	cache[index] = result
	return result

static func rails(canvas: CanvasItem) -> void:
	for x in range(250, 1040, 38): canvas.draw_rect(Rect2(x, 404, 25, 11), Color("51391f"))
	canvas.draw_line(Vector2(250, 406), Vector2(1040, 406), Color("73716b"), 3)
	canvas.draw_line(Vector2(250, 414), Vector2(1040, 414), Color("343632"), 3)

static func wagon(canvas: CanvasItem, x: float, width: float, travel: float = 0, coal: bool = false, stone: bool = false, tilt: float = 0) -> void:
	for offset in [-width * 0.32, width * 0.32]:
		canvas.draw_set_transform(Vector2(x + float(offset), 400), travel / 14)
		canvas.draw_texture_rect(part(1), Rect2(-14, -14, 28, 28), false)
	canvas.draw_set_transform(Vector2(x, 374), tilt)
	if coal: canvas.draw_texture_rect(part(2), Rect2(-width * 0.40, -40, width * 0.75, 27), false)
	if stone: canvas.draw_texture_rect(part(3), Rect2(-width * 0.27, -42, width * 0.65, 30), false)
	canvas.draw_texture_rect(part(0), Rect2(-width / 2, -24, width, 50), false)
	canvas.draw_set_transform(Vector2.ZERO)
