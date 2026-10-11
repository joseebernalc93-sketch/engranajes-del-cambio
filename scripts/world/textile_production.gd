extends Node2D
## A powered hall after the pressure trial; no additional puzzle or text overlay.
const TOOLS := preload("res://assets/phase2/tools_pixel_v1.png")
const PARTS := preload("res://assets/phase2/iron_mission_parts_pixel_v2.png")
var elapsed: float = 0.0

func _draw() -> void:
	var tool_cell := TOOLS.get_size() / Vector2(4, 3)
	var part_cell := PARTS.get_size() / Vector2(4, 2)
	for index in 4:
		var x := 200.0 + index * 235.0
		var shuttle := Vector2(x + sin(elapsed * 6.0 + index * 0.6) * 50, 372)
		draw_texture_rect_region(TOOLS, Rect2(shuttle - Vector2(30, 14), Vector2(60, 28)), Rect2(Vector2(tool_cell.x * 2, tool_cell.y * 2), tool_cell))
		draw_set_transform(Vector2(x + 80, 430), elapsed * 2.5)
		draw_texture_rect_region(PARTS, Rect2(-20, -20, 40, 40), Rect2(Vector2(part_cell.x * 3, part_cell.y), part_cell))
		draw_set_transform(Vector2.ZERO)
	var bales := mini(3, 1 + int(elapsed / 12.0))
	for index in bales:
		draw_texture_rect_region(TOOLS, Rect2(850 + index * 48, 515 - index * 3, 54, 43), Rect2(Vector2(tool_cell.x * 3, tool_cell.y * 2), tool_cell))
