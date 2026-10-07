extends Node2D

const STATION_INTERIOR := preload("res://assets/gba/environment/station_interior_v2.png")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(STATION_INTERIOR, Rect2(0, 0, 1152, 648), false)
