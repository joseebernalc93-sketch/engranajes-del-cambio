extends Node2D
const Art := preload("res://scripts/world/mine_art.gd")
@export var hero_height: float = 60.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	var dimensions := Art.cage_size(hero_height)
	draw_line(Vector2(0, -300), Vector2(0, -dimensions.y + 8), Color("9f804e"), 2)
	Art.draw_cage(self, Vector2.ZERO, hero_height, 0.0)
