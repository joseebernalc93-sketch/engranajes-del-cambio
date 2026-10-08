extends RefCounted
## Ignore faint generation residue when measuring the actual character silhouette.
const SOLID_ALPHA: float = 0.5

static func measure(image: Image) -> Rect2i:
	if image == null or image.is_empty(): return Rect2i()
	var bounds := image.get_used_rect()
	var left: int = bounds.position.x
	var right: int = bounds.end.x
	var top: int = bounds.position.y
	var bottom: int = bounds.end.y
	while top < bottom and not _solid_row(image, top, left, right): top += 1
	if top == bottom: return Rect2i()
	while bottom > top and not _solid_row(image, bottom - 1, left, right): bottom -= 1
	while left < right and not _solid_column(image, left, top, bottom): left += 1
	while right > left and not _solid_column(image, right - 1, top, bottom): right -= 1
	return Rect2i(left, top, right - left, bottom - top)

static func _solid_row(image: Image, y: int, left: int, right: int) -> bool:
	for x in range(left, right):
		if image.get_pixel(x, y).a >= SOLID_ALPHA: return true
	return false

static func _solid_column(image: Image, x: int, top: int, bottom: int) -> bool:
	for y in range(top, bottom):
		if image.get_pixel(x, y).a >= SOLID_ALPHA: return true
	return false
