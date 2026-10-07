extends Control
## The workshop stays fixed; each installed part and tool is a separate layer.

signal part_selected(part: String)
signal part_dropped(part: String, target: String)
signal target_pressed(part: String)
signal action_held(pressed: bool)
signal gear_turned(delta_angle: float)
signal tension_changed(value: float)

const BACKGROUND := preload("res://assets/gba/ui/mill_workshop_backdrop_v2.png")
const FRAME := preload("res://assets/gba/ui/mill_stationary_frame_v2.png")
const GEAR := preload("res://assets/gba/ui/mill_gear_piece_v1.png")
const ROPE := preload("res://assets/gba/ui/mill_rope_piece_v1.png")
const PLANK := preload("res://assets/gba/ui/mill_plank_piece_v1.png")
const DESIGN := Vector2(771, 323)
const GEAR_CENTER := Vector2(293, 176)
const PINION_CENTER := Vector2(382, 176)
const UPPER_PULLEY := Vector2(480, 109)
const TARGETS := {
	"rueda_dentada": Rect2(221, 104, 144, 144),
	"cuerda": Rect2(352, 75, 164, 136),
	"tabla": Rect2(574, 166, 105, 121),
}
const TRAYS := {
	"rueda_dentada": Rect2(17, 229, 58, 58),
	"cuerda": Rect2(80, 229, 58, 58),
	"tabla": Rect2(143, 229, 58, 58),
}
const BOLTS := [Vector2(599, 258), Vector2(650, 191)]
const GOLD := Color("ebbb65")
const GREEN := Color("abc67b")

var active := false
var stage := "select"
var selected := ""
var installed: Dictionary = {}
var available: Dictionary = {}
var gear_angle := 0.0
var shaft_angle := 0.0
var tension := 20.0
var mounting := 0.0
var bolts := 0
var bolt_progress := 0.0
var proof := 0.0
var held := false
var completed := false
var time := 0.0
var settle_age := 2.0
var placement_age := 2.0
var settled_part := ""
var feedback := ""
var feedback_seconds := 0.0
var dragging_part := ""
var drag_position := Vector2.ZERO
var turning_gear := false
var dragging_tension := false
var last_angle := 0.0
var touch_index := -1
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func _process(delta: float) -> void:
	if not active:
		return
	time += delta
	settle_age += delta
	placement_age += delta
	feedback_seconds = maxf(0.0, feedback_seconds - delta)
	queue_redraw()


func cancel_drag() -> void:
	dragging_part = ""
	turning_gear = false
	dragging_tension = false
	touch_index = -1
	action_held.emit(false)


func show_feedback(text: String) -> void:
	feedback = text
	feedback_seconds = 2.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not active or completed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position * DESIGN / size)
		else:
			release_pointer(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_drag(event.position * DESIGN / size)
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
	if stage == "select":
		for part in TRAYS:
			if TRAYS[part].has_point(pos) and available.get(part, false) and not installed.get(part, false):
				dragging_part = part
				drag_position = pos
				part_selected.emit(part)
				return
		for part in TARGETS:
			if TARGETS[part].has_point(pos) and not installed.get(part, false):
				target_pressed.emit(part)
				return
	elif stage == "gear":
		var distance := pos.distance_to(GEAR_CENTER)
		if distance > 24 and distance < 82:
			turning_gear = true
			last_angle = (pos - GEAR_CENTER).angle()
		elif distance <= 24:
			action_held.emit(true)
	elif stage == "rope":
		if Rect2(534, 190, 112, 32).has_point(pos):
			dragging_tension = true
			_set_tension(pos.x)
		elif TARGETS.cuerda.has_point(pos):
			action_held.emit(true)
	elif stage == "plank":
		if bolts < 2 and pos.distance_to(BOLTS[bolts]) < 30:
			action_held.emit(true)
	elif stage == "proof" and TARGETS.rueda_dentada.has_point(pos):
		action_held.emit(true)


func _drag(pos: Vector2) -> void:
	if not dragging_part.is_empty():
		drag_position = pos
	elif turning_gear:
		var angle := (pos - GEAR_CENTER).angle()
		gear_turned.emit(wrapf(angle - last_angle, -PI, PI))
		last_angle = angle
	elif dragging_tension:
		_set_tension(pos.x)
	queue_redraw()


func release_pointer(local_pos: Vector2) -> void:
	if not dragging_part.is_empty():
		var dropped := dragging_part
		var pos := local_pos * DESIGN / size
		var target := ""
		for part in TARGETS:
			if TARGETS[part].has_point(pos):
				target = part
				break
		dragging_part = ""
		if not target.is_empty():
			part_dropped.emit(dropped, target)
		elif not TRAYS[dropped].has_point(pos):
			show_feedback("La pieza vuelve a la mesa")
	turning_gear = false
	dragging_tension = false
	touch_index = -1
	action_held.emit(false)
	queue_redraw()


func _set_tension(x: float) -> void:
	tension_changed.emit(clampf(inverse_lerp(544.0, 636.0, x) * 100.0, 0, 100))


func _draw() -> void:
	if not font:
		return
	draw_set_transform(Vector2.ZERO, 0, size / DESIGN)
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, DESIGN), false)
	draw_texture_rect(FRAME, Rect2(119, 30, 569, 260), false)
	# A stationary shaft remains visible inside the empty square socket.
	draw_line(Vector2(239, 176), Vector2(481, 176), Color("51412c"), 15)
	draw_line(Vector2(239, 173), Vector2(481, 173), Color("ba9355"), 4)
	_draw_pulley(UPPER_PULLEY, -shaft_angle * 61.0 / 28.0)
	_draw_gear(PINION_CENTER, 28, -shaft_angle * 61.0 / 28.0, Color.WHITE)
	if installed.get("cuerda", false) or stage == "rope":
		_draw_rope()
	if installed.get("rueda_dentada", false):
		var bounce := sin(settle_age * 22.0) * exp(-settle_age * 8.0) * 6.0 if settled_part == "rueda_dentada" else 0.0
		_draw_gear(GEAR_CENTER + Vector2(bounce, 0), 61, shaft_angle, Color.WHITE)
	elif stage == "gear":
		_draw_gear(GEAR_CENTER + Vector2(0, -18 * (1 - mounting)), 61, gear_angle, Color(1, 1, 1, 0.92))
		draw_arc(GEAR_CENTER, 77, -PI * 0.6, PI * 0.6, 40, GOLD, 2)
		draw_line(GEAR_CENTER + Vector2(-10, -10), GEAR_CENTER + Vector2(10, -10), GREEN, 3)
		draw_rect(Rect2(GEAR_CENTER - Vector2(9, 9), Vector2(18, 18)), GREEN, false, 2)
	else:
		draw_circle(GEAR_CENTER, 18, Color("2a2520"))
		draw_rect(Rect2(GEAR_CENTER - Vector2(9, 9), Vector2(18, 18)), GOLD, false, 2)
	_draw_plank()
	_draw_stone()
	if stage == "select":
		_draw_targets()
		_draw_trays()
	elif stage == "rope":
		_draw_tensioner()
	elif stage == "proof":
		draw_arc(GEAR_CENTER, 77, -PI / 2, -PI / 2 + maxf(0.001, proof) * TAU, 60, GREEN, 4)
		_badge(Vector2(26, 31), "MANTÉN EL EJE PARA PROBAR", GOLD, 279)
	elif stage == "gear":
		_badge(Vector2(27, 30), "ALINEA LA RANURA CUADRADA", GOLD, 279)
	elif stage == "plank":
		_badge(Vector2(27, 30), "APRIETA LAS DOS FIJACIONES", GOLD, 268)
	if completed:
		_badge(Vector2(245, 23), "✓ TRANSMISIÓN COMPROBADA", GREEN, 291)
	if not dragging_part.is_empty():
		draw_texture_rect(_texture(dragging_part), Rect2(drag_position - Vector2(30, 30), Vector2(60, 60)), false)
		draw_rect(TARGETS[dragging_part], GOLD, false, 3)
	if feedback_seconds > 0:
		_badge(Vector2(214, 269), feedback, GOLD, 350)
	draw_rect(Rect2(0, 296, 771, 27), Color(0.03, 0.035, 0.018, 0.94))
	draw_set_transform(Vector2.ZERO)


func _draw_gear(center: Vector2, radius: float, angle: float, tint: Color) -> void:
	draw_set_transform(center * size / DESIGN, angle, size / DESIGN)
	# Crop the sprite's transparent margin; tooth tips meet across the pitch circles.
	var tip_radius := radius + 3.0
	draw_texture_rect_region(GEAR, Rect2(-tip_radius, -tip_radius, tip_radius * 2, tip_radius * 2), Rect2(64, 64, 1126, 1126), tint)
	draw_set_transform(Vector2.ZERO, 0, size / DESIGN)


func _draw_pulley(center: Vector2, angle: float) -> void:
	draw_circle(center + Vector2(2, 3), 29, Color("2b2118"))
	draw_circle(center, 27, Color("845829"))
	draw_arc(center, 24, 0, TAU, 40, Color("d0a45d"), 3)
	for spoke in 6:
		var radial := Vector2.from_angle(angle + spoke * TAU / 6)
		draw_line(center + radial * 7, center + radial * 21, Color("493424"), 6)
		draw_line(center + radial * 7, center + radial * 21, Color("c09a55"), 2)
	draw_circle(center, 7, Color("484337"))
	draw_circle(center, 3, Color("bcb092"))


func _draw_rope() -> void:
	var angle := (UPPER_PULLEY - PINION_CENTER).angle()
	var normal := Vector2.from_angle(angle + PI / 2)
	var points := PackedVector2Array([PINION_CENTER + normal * 29, UPPER_PULLEY + normal * 29])
	for index in 21:
		points.append(UPPER_PULLEY + Vector2.from_angle(angle + PI / 2 - index * PI / 20) * 29)
	var from := UPPER_PULLEY - normal * 29
	var to := PINION_CENTER - normal * 29
	var slack := (1 - tension / 100.0) * 42.0
	for index in 21:
		var t := index / 20.0
		points.append(from.lerp(to, t) + Vector2(0, sin(t * PI) * slack))
	for index in 21:
		points.append(PINION_CENTER + Vector2.from_angle(angle - PI / 2 - index * PI / 20) * 29)
	points.append(points[0])
	if stage == "rope" and placement_age < 0.75:
		var full_length := 0.0
		for index in range(1, points.size()):
			full_length += points[index - 1].distance_to(points[index])
		var remaining := full_length * clampf(placement_age / 0.75, 0.001, 1)
		var laid := PackedVector2Array([points[0]])
		for index in range(1, points.size()):
			var length := points[index - 1].distance_to(points[index])
			if remaining < length:
				laid.append(points[index - 1].lerp(points[index], remaining / maxf(length, 0.001)))
				break
			laid.append(points[index])
			remaining -= length
		points = laid
	draw_polyline(points, Color("3f2b1a"), 8)
	draw_polyline(points, Color("c39c5d"), 5)
	var distance := 0.0
	var phase := fposmod(-shaft_angle * 61.0, 9.0)
	for index in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		var length := a.distance_to(b)
		var step := fposmod(phase - distance, 9.0)
		while step < length:
			var pos := a.lerp(b, step / maxf(length, 0.001))
			var n := (b - a).normalized().orthogonal()
			draw_line(pos - n * 2, pos + n * 2 + (b - a).normalized() * 2, Color("edd294"), 1)
			step += 9
		distance += length
	if installed.get("cuerda", false) or (mounting > 0 and placement_age >= 0.75):
		# The binding travels with the endless rope, including around both pulleys.
		var knot_distance := fposmod(distance * 0.21 - shaft_angle * 61.0, distance)
		var knot := points[0]
		var tangent := Vector2.RIGHT
		for index in range(1, points.size()):
			var segment_length := points[index - 1].distance_to(points[index])
			if knot_distance <= segment_length:
				knot = points[index - 1].lerp(points[index], knot_distance / maxf(segment_length, 0.001))
				tangent = (points[index] - points[index - 1]).normalized()
				break
			knot_distance -= segment_length
		var cross := tangent.orthogonal()
		for index in 4:
			draw_line(knot + tangent * (index * 3 - 6) - cross * 5, knot + tangent * (index * 3 - 4) + cross * 5, Color("e8cf97"), 2)


func _draw_plank() -> void:
	if not installed.get("tabla", false) and stage != "plank":
		draw_polyline(PackedVector2Array([Vector2(657, 247), Vector2(642, 252), Vector2(655, 262), Vector2(641, 268)]), Color("291b12"), 4)
		return
	var slide := Vector2(24, -14) * pow(1 - clampf(placement_age / 0.35, 0, 1), 3) if stage == "plank" else Vector2.ZERO
	draw_texture_rect(PLANK, Rect2(Vector2(574, 166) + slide, Vector2(105, 121)), false)
	for index in 2:
		var pos: Vector2 = BOLTS[index] + slide
		var fitted: bool = installed.get("tabla", false) or index < bolts
		var rotation_amount := bolt_progress * TAU * 2 if index == bolts else 0.0
		draw_circle(pos, 8, Color("38332d"))
		draw_circle(pos, 6, GREEN if fitted else Color("b79c71"))
		var dir := Vector2.from_angle(rotation_amount)
		draw_line(pos - dir * 4, pos + dir * 4, Color("332a22"), 2)
		if stage == "plank" and index == bolts:
			draw_arc(pos, 17, 0, TAU, 30, GOLD, 2)
			if held:
				var end := pos + Vector2.from_angle(rotation_amount) * 32
				draw_line(pos, end, Color("282726"), 8)
				draw_line(pos, end, Color("b8b6a4"), 4)


func _draw_stone() -> void:
	for index in 9:
		var angle := -shaft_angle * 61.0 / 28.0 + index * TAU / 9
		draw_line(Vector2(481, 185) + Vector2(cos(angle) * 16, sin(angle) * 4), Vector2(481, 185) + Vector2(cos(angle) * 68, sin(angle) * 15), Color(0.4, 0.36, 0.29, 0.8), 2)


func _draw_tensioner() -> void:
	_badge(Vector2(528, 164), "TENSOR DE LA SOGA", GOLD, 171)
	draw_rect(Rect2(534, 190, 112, 32), Color("24241c"))
	draw_rect(Rect2(544 + 64 * 0.92, 194, 14 * 0.92, 24), Color("526d37"))
	draw_line(Vector2(544, 206), Vector2(636, 206), Color("bd9c5b"), 3)
	draw_circle(Vector2(544 + tension * 0.92, 206), 8, GOLD)


func _draw_targets() -> void:
	var names := {"rueda_dentada": "1 · EJE", "cuerda": "2 · POLEAS", "tabla": "3 · BANCADA"}
	for part in TARGETS:
		if installed.get(part, false):
			continue
		var rect: Rect2 = TARGETS[part]
		var color := GOLD if selected == part else Color("ac9365")
		draw_rect(rect, Color(0.10, 0.08, 0.04, 0.18))
		draw_rect(rect, color, false, 2 if selected == part else 1)
		_badge(rect.position + Vector2(0, -24), names[part], color, rect.size.x)


func _draw_trays() -> void:
	draw_rect(Rect2(10, 223, 198, 69), Color("342417"))
	draw_rect(Rect2(10, 223, 198, 69), Color("946338"), false, 2)
	for part in TRAYS:
		var rect: Rect2 = TRAYS[part]
		if installed.get(part, false):
			draw_string(font, rect.position + Vector2(17, 37), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, GREEN)
		elif available.get(part, false):
			draw_texture_rect(_texture(part), rect.grow(-4), false)
			if selected == part:
				draw_rect(rect, GOLD, false, 2)
		else:
			draw_texture_rect(_texture(part), rect.grow(-4), false, Color(0.55, 0.5, 0.4, 0.32))


func _texture(part: String) -> Texture2D:
	return {"rueda_dentada": GEAR, "cuerda": ROPE, "tabla": PLANK}[part]


func _badge(pos: Vector2, text: String, color: Color, width: float) -> void:
	draw_rect(Rect2(pos, Vector2(width, 24)), Color(0.04, 0.035, 0.025, 0.92))
	draw_string(font, pos + Vector2(8, 17), text, HORIZONTAL_ALIGNMENT_LEFT, width - 16, 11, color)
