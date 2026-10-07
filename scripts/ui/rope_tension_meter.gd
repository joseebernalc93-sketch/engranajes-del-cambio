extends Control
## A fixed safe band and moving needle avoid confusing carriage position with tension.

var value := 0.0:
	set(next):
		value = next
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var width := size.x
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 17, width, 18), Color("211b13"))
	draw_rect(Rect2(2, 19, (width - 4) * 0.45, 14), Color("83613b"))
	draw_rect(Rect2(2 + (width - 4) * 0.45, 19, (width - 4) * 0.25, 14), Color("78a85c"))
	draw_rect(Rect2(2 + (width - 4) * 0.70, 19, (width - 4) * 0.30, 14), Color("a5553f"))
	for mark in [45.0, 70.0]:
		var x: float = 2.0 + (width - 4) * mark / 100.0
		draw_line(Vector2(x, 15), Vector2(x, 37), Color("efe0b0"), 1)
	var needle := 2.0 + (width - 4) * clampf(value / 100.0, 0, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(needle - 5, 7), Vector2(needle + 5, 7), Vector2(needle, 15)]), Color("fff0bf"))
	draw_line(Vector2(needle, 17), Vector2(needle, 35), Color("fff0bf"), 2)
	draw_string(font, Vector2(0, 53), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("aa9e81"))
	draw_string(font, Vector2(width * 0.45 - 7, 53), "45", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c9dcab"))
	draw_string(font, Vector2(width * 0.70 - 7, 53), "70", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c9dcab"))
	draw_string(font, Vector2(width - 21, 53), "100", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("aa9e81"))
