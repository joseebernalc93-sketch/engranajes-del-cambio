extends Node2D

const STATION_BACKGROUND := preload("res://assets/gba/environment/station_front_entrance_v4.png")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(STATION_BACKGROUND, Rect2(0, 0, 1152, 648), false)
