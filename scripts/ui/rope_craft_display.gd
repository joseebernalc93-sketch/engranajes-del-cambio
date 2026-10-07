extends Control
## Workbench tools are drawn above the existing workshop; no background movement.
signal precision_requested(value: float)

var mode := ""
var cursor := 0.0
var green_min := 0.38
var green_max := 0.62
var bundle := 0
var passes: Array = [0, 0, 0]
var wraps := 0
var dragging := false
var active := false
var font: Font
const GOLD := Color("e8bd70")
const INK := Color("241b10")

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if not active or mode == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var tool_x := 30.0 + cursor * (size.x - 60.0)
		if event.pressed and absf(event.position.x - tool_x) <= 22.0 and event.position.y >= 22.0 and event.position.y <= 62.0:
			dragging = true
			accept_event()
		elif not event.pressed:
			release_grip()
	if event is InputEventMouseMotion and dragging:
		cursor = clampf((event.position.x - 30) / (size.x - 60), 0, 1)
		queue_redraw()
		accept_event()

func release_grip() -> void:
	if dragging:
		dragging = false
		precision_requested.emit(cursor)

func _draw() -> void:
	if mode == "" or font == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(440, 94))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("2c2117")
	panel.border_color = Color("b18c4e")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(5)
	draw_style_box(panel, Rect2(0, 0, 440, 94))
	for screw in [Vector2(9, 9), Vector2(431, 9), Vector2(9, 85), Vector2(431, 85)]:
		draw_circle(screw, 3, GOLD)
		draw_line(screw - Vector2(2, 0), screw + Vector2(2, 0), INK, 1)
	var x := 30.0 + cursor * 380.0
	if mode == "comb":
		draw_string(font, Vector2(20, 20), "MANOJO %d · PASADA %d / 2" % [bundle + 1, mini(2, int(passes[bundle]) + 1)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
		for strand in 11:
			var points := PackedVector2Array()
			for step in 36:
				var px := 28.0 + step * 11.0
				var wave := (0.5 if passes[bundle] > 0 else 3.0) * sin(step * 0.8 + strand)
				points.append(Vector2(px, 35 + strand * 1.9 + wave))
			draw_polyline(points, Color("edce88") if passes[bundle] >= 2 else Color("b79350"), 1.1)
		draw_rect(Rect2(x - 15, 26, 30, 8), INK)
		draw_rect(Rect2(x - 14, 27, 28, 5), Color("a96d37"))
		for tooth in 8:
			draw_line(Vector2(x - 11 + tooth * 3, 33), Vector2(x - 11 + tooth * 3, 57), Color("d9d0ae"), 1.5)
	else:
		draw_string(font, Vector2(20, 20), "LIGADURA · %d / 3 VUELTAS FIRMES" % wraps, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
		for strand in 3:
			var points := PackedVector2Array()
			for step in 91:
				points.append(Vector2(40 + step * 4, 44 + sin(step * 0.5 + strand * TAU / 3) * 5))
			draw_polyline(points, [Color("ebcc87"), Color("c79855"), Color("f4dfa7")][strand], 2.4)
		for wrap in wraps * 3:
			draw_line(Vector2(193 + wrap * 5, 33), Vector2(196 + wrap * 5, 56), Color("f3db9a"), 3)
		draw_circle(Vector2(x, 46), 7, INK)
		draw_arc(Vector2(x, 46), 6, 0, TAU, 20, GOLD, 2)
	draw_rect(Rect2(30, 70, 380, 11), Color("16170f"))
	draw_rect(Rect2(30 + green_min * 380, 70, (green_max - green_min) * 380, 11), Color("74a65a"))
	draw_line(Vector2(x, 66), Vector2(x, 85), Color("fff0c1"), 2.5)
	draw_set_transform(Vector2.ZERO)
