extends Node2D

const BROKEN_MILL_BACKGROUND := preload("res://assets/gba/environment/mill_field_complete_v4.png")
const REPAIRED_MILL_BACKGROUND := preload("res://assets/gba/environment/mill_field_repaired_v1.png")
const REPAIRED_SAILS := preload("res://assets/gba/environment/windmill_sails_repaired_v1.png")
const WHEAT_FIELD := preload("res://assets/gba/environment/village_bakery_courtyard_v4.png")
const RIVER_BANK := preload("res://assets/gba/environment/river_bank.png")
const WATER_SHADER := preload("res://assets/shaders/river_water.gdshader")

var repaired_sails: Sprite2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()
	_spawn_animated_water()
	if GameState.flags.get("mill_repaired", false):
		call_deferred("_spawn_repaired_sails")
	call_deferred("_spawn_environment_props")
	call_deferred("_update_entrance_prompt")


func _process(delta: float) -> void:
	if is_instance_valid(repaired_sails):
		repaired_sails.rotation = fmod(repaired_sails.rotation + delta * 0.45, TAU)


func _draw() -> void:
	var background: Texture2D = REPAIRED_MILL_BACKGROUND if GameState.flags.get("mill_repaired", false) else BROKEN_MILL_BACKGROUND
	draw_texture_rect(background, Rect2(0, 0, 1152, 648), false)
	# Replace only the crops inside the existing fence, keeping the surrounding woodland.
	var field_rect := Rect2(56, 86, 435, 247)
	var source_scale := WHEAT_FIELD.get_size() / Vector2(1152, 648)
	draw_texture_rect_region(WHEAT_FIELD, field_rect, Rect2(field_rect.position * source_scale, field_rect.size * source_scale))
	_draw_river()


func _draw_river() -> void:
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


func _spawn_repaired_sails() -> void:
	var world := get_parent()
	if not world:
		return
	repaired_sails = Sprite2D.new()
	repaired_sails.name = "RepairedWindmillSails"
	repaired_sails.texture = REPAIRED_SAILS
	repaired_sails.position = Vector2(986, 176)
	repaired_sails.scale = Vector2.ONE * 0.285
	repaired_sails.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	repaired_sails.z_index = 2
	world.add_child(repaired_sails)


func _update_entrance_prompt() -> void:
	if not GameState.flags.get("mill_repaired", false):
		return
	var entrance = get_parent().get_node_or_null("BrokenMillInfo")
	if entrance:
		entrance.prompt = "Preparar costal de harina"


func _spawn_environment_props() -> void:
	var world := get_parent()
	if not world:
		return
	_add_static_collision(world, "BrokenMillCollision", Vector2(990, 250), Vector2(185, 240))


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
