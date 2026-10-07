extends Control
## Independent hydraulic, transmission, grain and flour layers over a fixed frame.

signal gate_changed(value: float)
signal load_requested
signal tie_requested(pressed: bool)

const BACKGROUND := preload("res://assets/gba/ui/mill_workshop_backdrop_v2.png")
const FRAME := preload("res://assets/gba/ui/mill_stationary_frame_v2.png")
const WHEEL := preload("res://assets/gba/ui/mill_waterwheel_v2.png")
const GEAR := preload("res://assets/gba/ui/mill_gear_piece_v1.png")
const SACK := preload("res://assets/items/flour_sack_v1.png")
const WHEAT := preload("res://assets/items/wheat_v2.png")
const DESIGN := Vector2(771, 323)
const WHEEL_CENTER := Vector2(293, 176)
const GATE_TARGET := Rect2(82, 47, 66, 131)
const HOPPER_TARGET := Rect2(531, 64, 112, 87)
const WHEAT_TARGET := Rect2(22, 237, 136, 55)
const SACK_TARGET := Rect2(656, 215, 86, 77)
const GOLD := Color("eab75d")

var active := false
var gate := 0.0
var rpm := 0.0
var flow := 0.0
var grain := 0.0
var batches := 0
var grinding := false
var jammed := false
var tripped := false
var can_load := false
var finishing := false
var can_tie := false
var tie := 0.0
var completed := false
var wheel_angle := 0.0
var load_age := 10.0
var time := 0.0
var dragging_gate := false
var dragging_wheat := false
var touch_index := -1
var drag_position := Vector2.ZERO
var feedback := ""
var feedback_seconds := 0.0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func reset_machine() -> void:
	cancel_drag()
	wheel_angle = 0.0
	time = 0.0
	load_age = 10.0
	feedback_seconds = 0.0
	queue_redraw()


func cancel_drag() -> void:
	dragging_gate = false
	dragging_wheat = false
	touch_index = -1
	tie_requested.emit(false)


func _process(delta: float) -> void:
	if active and is_visible_in_tree():
		feedback_seconds = maxf(0.0, feedback_seconds - delta)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position * DESIGN / size)
		else:
			release_pointer(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_drag(event.position * DESIGN / size)
		if dragging_gate or dragging_wheat:
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			_press(event.position * DESIGN / size)
		elif not event.pressed and event.index == touch_index:
			release_pointer(event.position)
		accept_event()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_drag(event.position * DESIGN / size)
		accept_event()


func _press(pos: Vector2) -> void:
	if completed:
		return
	if GATE_TARGET.has_point(pos):
		dragging_gate = true
		_set_gate(pos.y)
	elif WHEAT_TARGET.has_point(pos) and can_load:
		dragging_wheat = true
		drag_position = pos
	elif HOPPER_TARGET.has_point(pos):
		if can_load:
			load_requested.emit()
		else:
			feedback = "Estabiliza la rueda antes de cargar otra tanda."
			feedback_seconds = 2.5
	elif SACK_TARGET.has_point(pos) and can_tie:
		tie_requested.emit(true)


func _drag(pos: Vector2) -> void:
	if dragging_gate:
		_set_gate(pos.y)
	elif dragging_wheat:
		drag_position = pos


func release_pointer(local_pos: Vector2) -> void:
	if dragging_wheat and HOPPER_TARGET.has_point(local_pos * DESIGN / size) and can_load:
		load_requested.emit()
	cancel_drag()


func _set_gate(y: float) -> void:
	gate_changed.emit(clampf(inverse_lerp(160.0, 66.0, y) * 100.0, 0.0, 100.0))


func _draw() -> void:
	if not font:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN)
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, DESIGN), false)
	draw_texture_rect(FRAME, Rect2(119, 30, 569, 260), false)
	_draw_water()
	_draw_wheel()
	_draw_transmission()
	_draw_stones_and_grain()
	_draw_gate()
	_draw_sack()
	_draw_wheat()
	if dragging_wheat:
		draw_texture_rect(WHEAT, Rect2(drag_position - Vector2(25, 37), Vector2(50, 60)), false)
		draw_rect(HOPPER_TARGET, Color("f9d075"), false, 3.0)
	if load_age < 0.8:
		var pouring := clampf(load_age / 0.8, 0.0, 1.0)
		for index in 15:
			var pos := Vector2(564 + index % 4 * 11, 42 + fposmod(pouring * 78 + index * 3, 48.0))
			draw_line(pos, pos + Vector2(3, 2), GOLD, 3.0)
	if jammed or tripped:
		_badge(Vector2(316, 20), "TOLVA ATASCADA" if jammed else "SEGURO ACTIVADO", Color("efb17a"), 217)
	elif completed:
		_badge(Vector2(316, 20), "✓ COSTAL TERMINADO", Color("c0d996"), 238)
	elif can_load:
		_badge(Vector2(506, 27), "LLEVA EL TRIGO A LA TOLVA ↓", GOLD, 244)
	if feedback_seconds > 0.0:
		_badge(Vector2(242, 22), feedback, GOLD, 484)
	draw_style_box(_box(Color(0.03, 0.035, 0.018, 0.91), Color("776044")), Rect2(0, 296, 771, 27))
	draw_set_transform(Vector2.ZERO)


func _draw_water() -> void:
	var intensity := clampf(flow / 72.0, 0.0, 1.0)
	if intensity <= 0.015:
		return
	# Flume to paddles, then to the stone channel. Movement follows flow.
	for index in 11:
		var x := 228 + index * 3.0
		var start := Vector2(x, 87)
		var end := Vector2(x - 30 + sin(time * 5 + index) * 2, 212)
		draw_line(start, end, Color(0.29, 0.62, 0.75, intensity * 0.55), 3.0)
		var t := fposmod(time * (0.3 + intensity * 1.9) + index * 0.12, 1.0)
		var pos := start.lerp(end, t)
		draw_line(pos, pos + Vector2(-2, 8), Color(0.79, 0.92, 0.9, intensity * 0.85), 2.0)
	for row in 4:
		var points := PackedVector2Array()
		for index in 28:
			points.append(Vector2(217 + index * 5, 252 + row * 5 + sin(index * 0.65 - time * 5) * intensity * 2))
		draw_polyline(points, Color(0.45, 0.74, 0.81, intensity * 0.75), 2, false)


func _draw_wheel() -> void:
	draw_set_transform(WHEEL_CENTER * size / DESIGN, wheel_angle, size / DESIGN)
	draw_texture_rect(WHEEL, Rect2(-87, -87, 174, 174), false)
	draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN)


func _draw_transmission() -> void:
	draw_line(WHEEL_CENTER, Vector2(480, 176), Color("59412a"), 14.0)
	draw_line(WHEEL_CENTER + Vector2(0, -3), Vector2(480, 173), Color("ac8550"), 4.0)
	_gear(WHEEL_CENTER, 27.0, wheel_angle)
	_gear(Vector2(342, 176), 22.0, -wheel_angle * 27.0 / 22.0)
	# An offset bevel on the spindle transfers the motion to the upper stone.
	_gear(Vector2(480, 137), 29.0, wheel_angle * 1.5)
	draw_line(Vector2(480, 154), Vector2(480, 179), Color("4e4637"), 10)
	if rpm > 0.8:
		draw_line(Vector2(480, 155), Vector2(480 + sin(wheel_angle * 1.5) * 4, 179), Color("b9a16a"), 2)


func _gear(center: Vector2, radius: float, angle: float) -> void:
	draw_set_transform(center * size / DESIGN, angle, size / DESIGN)
	draw_texture_rect(GEAR, Rect2(-radius, -radius, radius * 2, radius * 2), false)
	draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN)


func _draw_stones_and_grain() -> void:
	# The stone stays on its support; surface grooves orbit in its top plane.
	for index in 9:
		var angle := wheel_angle * 1.5 + index * TAU / 9.0
		var inner := Vector2(481 + cos(angle) * 16, 185 + sin(angle) * 4)
		var outer := Vector2(481 + cos(angle) * 68, 185 + sin(angle) * 15)
		draw_line(inner, outer, Color(0.4, 0.36, 0.29, 0.75), 2)
	if grain > 0.0:
		for index in 62:
			var x := 557 + index % 14 * 5.1
			var y := 82 + index / 14 * 3.0
			if float(index) / 62.0 < grain:
				draw_circle(Vector2(x, y), 2.1, Color("dba552") if index % 2 == 0 else Color("f4cf7d"))
	if grinding:
		for index in 18:
			var t := fposmod(time * 1.5 + index * 0.056, 1.0)
			var pos := Vector2(520, 163).lerp(Vector2(482, 184), t)
			pos.y += sin(t * PI) * 6.0
			draw_circle(pos + Vector2(index % 3, 0), 1.6, GOLD)
		for index in 25:
			var t := fposmod(time * 1.6 + index * 0.043, 1.0)
			var pos := Vector2(665, 224).lerp(Vector2(701, 246), t)
			pos.y -= sin(t * PI) * 7
			draw_circle(pos + Vector2(index % 3, 0), 1.3, Color("f2e1b8"))


func _draw_gate() -> void:
	draw_style_box(_box(Color("322c21"), Color("ab8752")), Rect2(101, 54, 23, 120))
	for tick in 6:
		draw_line(Vector2(95, 65 + tick * 19), Vector2(101, 65 + tick * 19), Color("bfad76"), 2)
	var y := lerpf(160, 66, gate / 100.0)
	draw_line(Vector2(110, y), Vector2(151, y), GOLD, 8)
	draw_circle(Vector2(148, y), 10, Color("674126"))
	draw_arc(Vector2(148, y), 12, 0, TAU, 32, GOLD, 2)
	draw_string(font, Vector2(73, 193), "COMPUERTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f2cc87"))
	draw_string(font, Vector2(102, 213), "%d%%" % roundi(gate), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fae0a0"))


func _draw_sack() -> void:
	var fill := clampf((batches + (1.0 - grain if grain > 0.0 else 0.0)) / 3.0, 0.0, 1.0)
	var height := lerpf(37.0, 77.0, fill)
	var rect := Rect2(659, 292 - height, 79, height)
	if tie >= 1.0:
		draw_texture_rect(SACK, Rect2(655, 205, 90, 88), false)
	else:
		draw_texture_rect_region(SACK, rect, Rect2(220, 470, 820, 720))
		draw_line(rect.position + Vector2(9, 2), rect.position + Vector2(66, 2), Color("e0c99c"), 6)
		if fill > 0.02:
			draw_line(rect.position + Vector2(15, 3), rect.position + Vector2(59, 3), Color("f2e3c3"), 5)
		for index in ceili(tie * 3.0):
			draw_line(rect.position + Vector2(9, 14 + index * 3), rect.position + Vector2(69, 14 + index * 3), GOLD, 2)
		if tie > 0.6:
			draw_arc(rect.position + Vector2(63, 17), tie * 9, 0, TAU, 22, GOLD, 2)
	if can_tie:
		draw_rect(SACK_TARGET, GOLD, false, 2)
		_badge(Vector2(607, 183), "MANTÉN PARA ATAR ↓", GOLD, 152)
	if not can_tie:
		draw_string(font, Vector2(650, 207), "Costal %d%%" % roundi(fill * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)


func _draw_wheat() -> void:
	if finishing:
		return
	draw_style_box(_box(Color(0.12, 0.1, 0.05, 0.92), GOLD if can_load else Color("796749")), WHEAT_TARGET)
	for index in maxi(0, 3 - batches - (1 if grain > 0.0 else 0)):
		draw_texture_rect(WHEAT, Rect2(29 + index * 34, 241, 28, 39), false)
	draw_string(font, Vector2(31, 289), "ARRASTRA A LA TOLVA" if can_load else "TRIGO DE LA COSECHA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f0d5a4"))


func _badge(pos: Vector2, text: String, color: Color, width: float) -> void:
	draw_style_box(_box(Color(0.06, 0.07, 0.04, 0.92), Color("877048")), Rect2(pos, Vector2(width, 28)))
	draw_string(font, pos + Vector2(8, 19), text, HORIZONTAL_ALIGNMENT_LEFT, width - 12, 12, color)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
