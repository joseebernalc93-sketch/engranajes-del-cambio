extends Node2D

const BACKGROUND := preload("res://assets/gba/environment/wood_island_v2.png")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 1152, 648), false)
