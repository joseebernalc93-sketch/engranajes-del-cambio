extends RefCounted
## Textured rails share one gauge, sleeper spacing and continuous curved geometry.
const Art := preload("res://scripts/world/mining_workshop_art.gd")
const Cart := preload("res://scripts/world/mining_cart_art.gd")
const Bounds := preload("res://scripts/world/sprite_body_bounds.gd")
const CARGO := preload("res://assets/phase2/mining_sack_bundle_v2.png")
const GAUGE: float = 42.0
static var meshes: Dictionary = {}
static var cargo: AtlasTexture

static func cargo_texture() -> AtlasTexture:
	if cargo == null:
		cargo = AtlasTexture.new()
		cargo.atlas = CARGO
		cargo.region = Rect2(Bounds.measure(CARGO.get_image()))
	return cargo

static func curve(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in 25:
		var t := index / 24.0
		result.append(Vector2(lerpf(start.x, finish.x, t), lerpf(start.y, finish.y, t * t * (3.0 - 2.0 * t))))
	return result

static func piece_path(piece: int, rect: Rect2) -> PackedVector2Array:
	var inset := 8.0
	var middle := rect.get_center().y
	var rise := minf(70, maxf(44, rect.size.y - 33))
	var start := Vector2(rect.position.x + inset, middle)
	var finish := Vector2(rect.end.x - inset, middle)
	if piece == 0: return PackedVector2Array([start, finish])
	start.y += (-0.5 if piece == 1 else 0.5) * rise
	finish.y += (0.5 if piece == 1 else -0.5) * rise
	return curve(start, finish)

static func slot_path(piece: int, slot: int) -> PackedVector2Array:
	var start := Vector2([390, 650, 820][slot], 395)
	var finish := Vector2([510, 760, 930][slot], 395)
	if piece == 0:
		if slot > 0:
			start.y = 430
			finish.y = 430
		return PackedVector2Array([start, finish])
	if piece == 1: finish.y = 465
	else: start.y = 465
	return curve(start, finish)

static func visual_position(point: Vector2) -> Vector2:
	# Keep saved logical progress; ease the two bends along the visible rails.
	point.y = _route_y(point.x)
	return point

static func _route_y(x: float) -> float:
	if x >= 650 and x <= 760:
		var t := (x - 650) / 110.0
		return lerpf(395, 465, t * t * (3.0 - 2.0 * t))
	if x > 760 and x < 820: return 465
	if x >= 820 and x <= 930:
		var t := (x - 820) / 110.0
		return lerpf(465, 395, t * t * (3.0 - 2.0 * t))
	return 395

static func wagon_pose(point: Vector2) -> Transform2D:
	var angle := 0.0
	var left_y := point.y
	var right_y := point.y
	# Both wheels support the rigid chassis, including when spanning a bend.
	for index in 4:
		var half_axle := 57 * cos(angle)
		left_y = _route_y(point.x - half_axle)
		right_y = _route_y(point.x + half_axle)
		angle = Vector2(half_axle * 2, right_y - left_y).angle()
	return Transform2D(angle, Vector2(point.x, (left_y + right_y) / 2))

static func _sample(path: PackedVector2Array, distance: float) -> Vector2:
	for index in path.size() - 1:
		var length := path[index].distance_to(path[index + 1])
		if distance <= length: return path[index].lerp(path[index + 1], distance / maxf(0.001, length))
		distance -= length
	return path[-1]

static func _mesh(path: PackedVector2Array, width: float) -> ArrayMesh:
	var key := str(path) + ":" + str(width)
	if meshes.has(key): return meshes[key]
	var texture := Art.part(0, 1) as AtlasTexture
	var source_size := texture.atlas.get_size()
	var region := texture.region
	# Remove just the end overhang so adjacent repeats share the same rail ends.
	region.position.x += 4
	region.size.x -= 8
	var tile_length := width * region.size.x / region.size.y
	var length := 0.0
	for index in path.size() - 1: length += path[index].distance_to(path[index + 1])
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var distance := 0.0
	while distance < length - 0.001:
		var u := fmod(distance, tile_length)
		if tile_length - u < 0.01: u = 0
		var advance := minf(9.0, minf(tile_length - u, length - distance))
		var a := _sample(path, distance)
		var b := _sample(path, distance + advance)
		var normal_a := (_sample(path, minf(length, distance + 0.5)) - _sample(path, maxf(0, distance - 0.5))).normalized().orthogonal()
		var normal_b := (_sample(path, minf(length, distance + advance + 0.5)) - _sample(path, maxf(0, distance + advance - 0.5))).normalized().orthogonal()
		# The front rail is the cart's ground contact; the back rail sits behind it.
		a.y -= 10
		b.y -= 10
		var corners := [a - normal_a * width / 2, b - normal_b * width / 2, b + normal_b * width / 2, a + normal_a * width / 2]
		var source_uv := [Vector2(u / tile_length, 0), Vector2((u + advance) / tile_length, 0), Vector2((u + advance) / tile_length, 1), Vector2(u / tile_length, 1)]
		var base := vertices.size()
		for index in 4:
			vertices.append(Vector3(corners[index].x, corners[index].y, 0))
			uv.append((region.position + source_uv[index] * region.size) / source_size)
		for index in [0, 1, 2, 0, 2, 3]: indices.append(base + index)
		distance += advance
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	meshes[key] = result
	# A dragged preview can visit many positions; do not retain them indefinitely.
	if meshes.size() > 100: meshes.erase(meshes.keys()[0])
	return result

static func track(canvas: CanvasItem, path: PackedVector2Array, width: float = GAUGE, tint: Color = Color.WHITE) -> void:
	if path.size() < 2: return
	var mesh := _mesh(path, width)
	var texture := (Art.part(0, 1) as AtlasTexture).atlas
	canvas.draw_mesh(mesh, texture, Transform2D(0, Vector2(0, 4)), Color(0.12, 0.07, 0.03, tint.a * 0.32))
	canvas.draw_mesh(mesh, texture, Transform2D.IDENTITY, tint)

static func loaded_wagon(canvas: CanvasItem, pose: Transform2D, scale: Vector2, travel: float, moving: bool) -> void:
	var at := pose.origin
	var angle := pose.get_rotation()
	var bob := sin(travel * 0.32) * 1.1 if moving else 0.0
	var rock := sin(travel * 0.075) * 0.012 if moving else 0.0
	canvas.draw_set_transform(at * scale, angle, scale)
	# Stepped contact shadow, kept on the ground while the sprung body moves.
	canvas.draw_rect(Rect2(-85, -3, 170, 11), Color("1d120b65"))
	canvas.draw_rect(Rect2(-73, -5, 146, 15), Color("1d120b40"))
	canvas.draw_set_transform((at + Vector2(0, bob).rotated(angle)) * scale, angle + rock, scale)
	canvas.draw_texture_rect(Cart.part(0), Rect2(-92, -78, 184, 64), false, Color("b19d7f"))
	# One cohesive cargo sprite replaces four undersized floating bag icons.
	var dimensions := cargo_texture().get_size()
	dimensions *= minf(164.0 / dimensions.x, 116.0 / dimensions.y)
	canvas.draw_texture_rect(cargo_texture(), Rect2(Vector2(-dimensions.x / 2, -158), dimensions), false)
	canvas.draw_texture_rect(Cart.part(0), Rect2(-92, -71, 184, 60), false)
	for offset in [-57, 57]:
		canvas.draw_set_transform((at + Vector2(float(offset), -17).rotated(angle)) * scale, angle + travel / 18, scale)
		canvas.draw_texture_rect(Cart.part(1), Rect2(-18, -18, 36, 36), false)
	canvas.draw_set_transform(Vector2.ZERO, 0, scale)
