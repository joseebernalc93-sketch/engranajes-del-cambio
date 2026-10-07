extends Node2D

const BACKGROUND := preload("res://assets/gba/environment/coach_countryside_v1.png")
const WATER_SHADER := preload("res://assets/shaders/lake_dock_water.gdshader")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	material = water
	queue_redraw()


func _draw() -> void:
	for index in range(-2, 7):
		var mirrored: bool = absi(index) % 2 == 1
		var location := Vector2((index + 1 if mirrored else index) * 1152, 0)
		draw_set_transform(location, 0.0, Vector2(-1.0 if mirrored else 1.0, 1.0))
		draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, Vector2(1152, 648)), false)
	draw_set_transform(Vector2.ZERO)
