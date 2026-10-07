extends Control
## Lightweight industrial decoration, drawn at the actual control size.
@export_enum("Frame", "Blueprint", "Status", "Slot") var surface := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if surface == 1:
		_draw_blueprint()
		return
	if surface == 3:
		_draw_slot()
		return
	_draw_brushed_metal()
	var inset := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_style_box(_frame_style(), inset)
	draw_line(Vector2(18, 6), Vector2(size.x - 18, 6), Color("#d5a57b"), 1.0, true)
	draw_line(Vector2(18, size.y - 6), Vector2(size.x - 18, size.y - 6), Color("#382b23"), 1.0, true)
	for x in [12.0, size.x - 12.0]:
		for y in [12.0, size.y - 12.0]:
			_draw_rivet(Vector2(x, y), 2.3 if surface == 0 else 1.8)
	if surface == 0:
		_draw_rail(92)
		_draw_rail(size.y - 54)
		# Short copper inlays keep the edges mechanical without taking up space.
		for x in [8.0, size.x - 8.0]:
			draw_line(Vector2(x, 38), Vector2(x, 71), Color("#8b654b"), 2, true)
			draw_line(Vector2(x, size.y - 72), Vector2(x, size.y - 39), Color("#8b654b"), 2, true)


func _draw_brushed_metal() -> void:
	var height := 84.0 if surface == 0 else size.y - 12.0
	for y in range(9, int(height)):
		var highlight := 0.075 * pow(1.0 - float(y) / height, 1.8)
		draw_line(Vector2(18, y), Vector2(size.x - 18, y), Color(0.63, 0.72, 0.72, highlight), 1)
	for y in range(12, int(size.y - 10), 4):
		var sheen := 0.013 if y % 12 == 0 else 0.006
		draw_line(Vector2(18, y), Vector2(size.x - 18, y), Color(0.84, 0.77, 0.65, sheen), 1)


func _draw_rail(y: float) -> void:
	draw_line(Vector2(24, y), Vector2(size.x - 24, y), Color("#080f12"), 3, true)
	draw_line(Vector2(24, y), Vector2(size.x - 24, y), Color("#70523c"), 1, true)
	draw_line(Vector2(24, y - 1), Vector2(130, y - 1), Color("#cea275"), 1, true)
	for x in [24.0, size.x - 24.0]:
		_draw_rivet(Vector2(x, y), 1.7)


func _draw_rivet(point: Vector2, radius: float) -> void:
	draw_circle(point + Vector2(0, 1), radius + 1, Color("#080e11"), true, -1, true)
	draw_circle(point, radius, Color("#765139"), true, -1, true)
	draw_circle(point - Vector2(0.4, 0.5), radius * 0.73, Color("#c99e74"), true, -1, true)
	draw_line(point - Vector2(radius * 0.45, 0), point + Vector2(radius * 0.45, 0), Color("#4c3426"), 0.8, true)


func _draw_slot() -> void:
	var highlight := Color(0.75, 0.8, 0.76, 0.09)
	draw_line(Vector2(8, 4), Vector2(size.x - 8, 4), highlight, 1, true)
	draw_line(Vector2(4, 8), Vector2(4, size.y - 8), Color(0.75, 0.8, 0.76, 0.035), 1, true)
	draw_line(Vector2(8, size.y - 4), Vector2(size.x - 8, size.y - 4), Color(0, 0, 0, 0.3), 1, true)
	for x in [8.0, size.x - 8.0]:
		draw_circle(Vector2(x, 8), 1.2, Color("#66726b"), true, -1, true)


func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("#694f3e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func _draw_blueprint() -> void:
	for x in range(0, int(size.x), 16):
		var alpha := 0.08 if x % 64 == 0 else 0.035
		draw_line(Vector2(x, 1), Vector2(x, size.y - 1), Color(0.57, 0.76, 0.79, alpha), 1)
	for y in range(0, int(size.y), 16):
		var alpha := 0.08 if y % 64 == 0 else 0.035
		draw_line(Vector2(1, y), Vector2(size.x - 1, y), Color(0.57, 0.76, 0.79, alpha), 1)
	var center := size * 0.5
	var ink := Color(0.61, 0.8, 0.8, 0.16)
	draw_arc(center, 51, 0, TAU, 80, ink, 1, true)
	draw_arc(center, 62, 0, TAU, 80, ink, 1, true)
	draw_line(Vector2(20, center.y), Vector2(size.x - 20, center.y), ink, 1, true)
	draw_line(Vector2(center.x, 12), Vector2(center.x, size.y - 12), ink, 1, true)
	var baseline := size.y - 14.0
	draw_line(Vector2(28, baseline), Vector2(size.x - 28, baseline), ink, 1, true)
	for x in range(28, int(size.x - 27), 8):
		var tick := 5 if (x - 28) % 32 == 0 else 2
		draw_line(Vector2(x, baseline), Vector2(x, baseline - tick), ink, 1, true)
	for point in [Vector2(12, 12), Vector2(size.x - 12, 12), Vector2(12, size.y - 12), size - Vector2(12, 12)]:
		draw_line(point - Vector2(4, 0), point + Vector2(4, 0), ink, 1, true)
		draw_line(point - Vector2(0, 4), point + Vector2(0, 4), ink, 1, true)
