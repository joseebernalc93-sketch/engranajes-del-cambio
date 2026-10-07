extends Node2D

const VILLAGE_BACKGROUND := preload("res://assets/gba/environment/village_bakery_courtyard_v4.png")
const CARRIAGE_STATION := preload("res://assets/gba/environment/village_carriage_station_v6.png")
const RIVER_BANK := preload("res://assets/gba/environment/river_bank.png")
const FISHING_BOATS := preload("res://assets/gba/environment/fishing_boats_v2.png")
const OVEN_FIRE := preload("res://assets/gba/environment/forge_fire_sheet.png")
const ELENA_CART := preload("res://assets/gba/environment/elena_horse_wagon_world_v4.png")
const WATER_SHADER := preload("res://assets/shaders/river_water.gdshader")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()
	_spawn_animated_water()
	call_deferred("_spawn_environment_props")


func _draw() -> void:
	draw_texture_rect(VILLAGE_BACKGROUND, Rect2(0, 0, 1152, 648), false)
	# Replace the former corral with the open station, preserving the original houses.
	var station_rect := Rect2(0, 0, 540, 410)
	var source_scale := CARRIAGE_STATION.get_size() / Vector2(1152, 648)
	draw_texture_rect_region(CARRIAGE_STATION, station_rect, Rect2(station_rect.position * source_scale, station_rect.size * source_scale))
	_draw_river()


func _draw_river() -> void:
	# Crop the transparent source so the authored river fills the whole village edge.
	draw_texture_rect_region(
		RIVER_BANK,
		Rect2(0, 545, 1152, 103),
		Rect2(0, 240, 2172, 194)
	)


func _spawn_animated_water() -> void:
	var water_region := AtlasTexture.new()
	water_region.atlas = RIVER_BANK
	water_region.region = Rect2(0, 300, 2172, 134)

	var surface := Sprite2D.new()
	surface.name = "AnimatedWater"
	surface.texture = water_region
	surface.position = Vector2(576, 612.5)
	surface.scale = Vector2(1152.0 / 2172.0, 71.0 / 134.0)
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	surface.material = material
	add_child(surface)


func _spawn_environment_props() -> void:
	var world := get_parent()
	if not world:
		return

	_add_elena_cart(world)
	_add_static_collision(world, "CarriageCanopyCollision", Vector2(246, 106), Vector2(250, 78))
	_add_static_collision(world, "CarriageWaterTroughCollision", Vector2(101, 174), Vector2(57, 25))
	_add_static_collision(world, "BakeryCounterCollision", Vector2(892, 335), Vector2(108, 72))
	_add_static_collision(world, "FlourSacksCollision", Vector2(972, 342), Vector2(46, 56))
	_add_static_collision(world, "BreadRackCollision", Vector2(1060, 320), Vector2(136, 76))
	_add_static_collision(world, "VillageBenchCollision", Vector2(439, 530), Vector2(78, 24))
	_add_oven_fire(world, Vector2(1031, 214), Vector2(34, 38))

	var boat_left := _add_prop(world, "FishingBoatLeft", FISHING_BOATS, Vector2(280, 640), Vector2(160, 105), Vector2.ZERO, false, Rect2(30, 190, 835, 550))
	var boat_right := _add_prop(world, "FishingBoatRight", FISHING_BOATS, Vector2(910, 640), Vector2(160, 105), Vector2.ZERO, true, Rect2(917, 190, 835, 550))
	_start_boat_bobbing(boat_left, false)
	_start_boat_bobbing(boat_right, true)


func _add_elena_cart(world: Node2D) -> void:
	var cart := _add_prop(
		world,
		"ElenaMigrationCart",
		ELENA_CART,
		Vector2(300, 285),
		Vector2(180, 120),
		Vector2.ZERO
	)
	cart.z_index = 0
	_add_static_collision(world, "ElenaMigrationCartCollision", Vector2(259.5, 248.5), Vector2(96, 32))
	_add_static_collision(world, "ElenaHorseCollision", Vector2(352, 267.5), Vector2(51, 27))


func _start_boat_bobbing(boat: Sprite2D, alternate_phase: bool) -> void:
	var base_y := boat.position.y
	var low_y := base_y + 2.0
	var high_y := base_y - 2.5
	boat.position.y = high_y if alternate_phase else low_y
	boat.rotation = -0.012 if alternate_phase else 0.012
	boat.set_meta("bob_base_y", base_y)
	var bob := create_tween().set_loops()
	bob.set_trans(Tween.TRANS_SINE)
	bob.set_ease(Tween.EASE_IN_OUT)
	var first_y := low_y if alternate_phase else high_y
	var first_rotation := 0.012 if alternate_phase else -0.012
	bob.tween_property(boat, "position:y", first_y, 0.9)
	bob.parallel().tween_property(boat, "rotation", first_rotation, 0.9)
	bob.tween_property(boat, "position:y", boat.position.y, 0.9)
	bob.parallel().tween_property(boat, "rotation", boat.rotation, 0.9)


func _add_oven_fire(world: Node2D, fire_position: Vector2, display_size: Vector2) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("burn")
	frames.set_animation_loop("burn", true)
	frames.set_animation_speed("burn", 8.0)
	var frame_starts := [0, 518, 1036, 1554]
	var frame_widths := [518, 518, 518, 519]
	for index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = OVEN_FIRE
		frame.region = Rect2(frame_starts[index], 0, frame_widths[index], 758)
		frames.add_frame("burn", frame)

	var fire := AnimatedSprite2D.new()
	fire.name = "BakeryOvenFire"
	fire.sprite_frames = frames
	fire.animation = "burn"
	fire.position = fire_position
	fire.scale = Vector2(display_size.x / 518.0, display_size.y / 758.0)
	fire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fire.z_index = 1
	world.add_child(fire)
	fire.play()


func _add_prop(
	world: Node2D,
	node_name: String,
	texture: Texture2D,
	foot_position: Vector2,
	display_size: Vector2,
	collision_size: Vector2 = Vector2.ZERO,
	flip_horizontal := false,
	texture_region := Rect2()
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.position = foot_position
	var source_size := Vector2(texture.get_width(), texture.get_height())
	if texture_region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = texture_region
		sprite.region_filter_clip_enabled = true
		source_size = texture_region.size
	sprite.offset = Vector2(0, -source_size.y * 0.5)
	sprite.scale = Vector2(display_size.x / source_size.x, display_size.y / source_size.y)
	sprite.flip_h = flip_horizontal
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(sprite)

	if collision_size != Vector2.ZERO:
		var body := StaticBody2D.new()
		body.name = "%sCollision" % node_name
		body.position = foot_position - Vector2(0, collision_size.y * 0.5)
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = collision_size
		collision.shape = shape
		body.add_child(collision)
		world.add_child(body)

	return sprite


func _add_static_collision(world: Node2D, node_name: String, position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
