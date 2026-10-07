extends Node2D

const BACKGROUND := preload("res://assets/gba/environment/spinner_yard_v2.png")
const WEST_ROAD := preload("res://assets/gba/environment/spinner_yard_west_road_v3.png")
const RIVER_BANK := preload("res://assets/gba/environment/river_bank.png")
const WATER_SHADER := preload("res://assets/shaders/river_water.gdshader")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()
	_spawn_animated_water()


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 1152, 648), false)
	var road_rect := Rect2(0, 370, 305, 165)
	var source_scale := WEST_ROAD.get_size() / Vector2(1152, 648)
	draw_texture_rect_region(WEST_ROAD, road_rect, Rect2(road_rect.position * source_scale, road_rect.size * source_scale))
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
