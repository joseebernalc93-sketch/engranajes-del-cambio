extends Control
## A stable green band and moving needle, shared by marking and support adjustment.
var value := 0.5:
	set(next):
		value = clampf(next, 0, 1)
		queue_redraw()
var low := 0.38
var high := 0.62

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var width := size.x - 8.0
	var y := size.y * 0.5
	var box := StyleBoxFlat.new()
	box.bg_color = Color("201a13")
	box.border_color = Color("a88245")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	draw_style_box(box, Rect2(0, y - 9, size.x, 18))
	draw_rect(Rect2(4 + low * width, y - 6, (high - low) * width, 12), Color("7aab5b"))
	for mark in [low, high]:
		var x: float = 4 + mark * width
		draw_line(Vector2(x, y - 12), Vector2(x, y + 12), Color("ead9a5"), 1)
	var needle := 4 + value * width
	draw_colored_polygon(PackedVector2Array([Vector2(needle - 4, y - 17), Vector2(needle + 4, y - 17), Vector2(needle, y - 11)]), Color("fff1bd"))
	draw_line(Vector2(needle, y - 8), Vector2(needle, y + 8), Color("fff1bd"), 2)
