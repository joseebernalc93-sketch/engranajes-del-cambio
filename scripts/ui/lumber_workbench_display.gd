extends Control
## Workshop illustration, moving workpiece and direct manipulation targets.

signal section_selected(index: int)
signal fixation_selected(index: int)
signal sack_requested(index: int)
signal mark_requested(index: int)

const WOOD := preload("res://assets/gba/ui/bruno_workpieces_v2.png")
const REGIONS := [Rect2(33, 160, 1472, 197), Rect2(37, 427, 1466, 201), Rect2(37, 700, 1466, 198)]
const GOLD := Color("e8bd70")
const GREEN := Color("bfdc95")
const INK := Color("23170d")
const FIX_POINTS := [Vector2(115, 178), Vector2(340, 176), Vector2(524, 163)]
const SACK_X := [210.0, 335.0, 460.0]
const SECTIONS := [Vector2(161, 137), Vector2(290, 137), Vector2(412, 137), Vector2(538, 137)]

var stage := 0
var active := false
var session_id := 0
var selected := false
var inspected := [false, false, false, false]
var hovered_section := -1
var fixations := [false, false, false]
var fix_progress := [0.0, 0.0, 0.0]
var chalk := 0.0
var saw_count := 0
var saw_direction := 1
var saw_position := Vector2.ZERO
var plane_count := 0
var lane_progress := [0.0, 0.0, 0.0, 0.0]
var offcut := 0.0
var load_count := 0
var verified_loads := 0
var load_locked := false
var load_age := 10.0
var bend := 0.0
var stability_pulse := 0.0
var time := 0.0
var feedback := ""
var feedback_color := GOLD
var feedback_time := 0.0
var font: Font
var extra_mode := ""
var marked_lines := 0
var square_angle := 90.0
var measured_length := 160.0
var difficulty_pace := 1.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hovered_section = -1)


func reset_workbench() -> void:
	stage = 0
	selected = false
	inspected = [false, false, false, false]
	hovered_section = -1
	fixations = [false, false, false]
	fix_progress = [0.0, 0.0, 0.0]
	chalk = 0.0
	saw_count = 0
	saw_direction = 1
	plane_count = 0
	lane_progress = [0.0, 0.0, 0.0, 0.0]
	offcut = 0.0
	load_count = 0
	verified_loads = 0
	load_locked = false
	load_age = 10.0
	bend = 0.0
	stability_pulse = 0.0
	feedback_time = 0.0
	queue_redraw()


func show_feedback(message: String, color := GOLD) -> void:
	feedback = message
	feedback_color = color
	feedback_time = 1.65
	queue_redraw()


func _process(delta: float) -> void:
	if not active or not is_visible_in_tree():
		return
	time += delta
	feedback_time = maxf(0, feedback_time - delta)
	stability_pulse = maxf(0, stability_pulse - delta * 1.7)
	chalk = move_toward(chalk, 1.0 if stage >= 1 else marked_lines / 3.0, delta * 1.8)
	for index in 3:
		fix_progress[index] = move_toward(fix_progress[index], 1.0 if fixations[index] else 0.0, delta * 2.5)
	if saw_count >= 5:
		offcut = minf(1, offcut + delta * 1.2)
	load_age += delta
	var settled := load_count * 0.48
	bend = settled + sin(load_age * 18.0 * difficulty_pace) * exp(-load_age * 4.0) * 5.5 if stage >= 4 else 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if not (event is InputEventMouse or event is InputEventScreenTouch):
		return
	var point: Vector2 = event.position * Vector2(771, 323) / size
	var clicked: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if extra_mode == "measure":
		if clicked:
			for index in 3:
				if point.distance_to(Vector2(90 + index * 230, 78)) < 21:
					mark_requested.emit(index)
	elif stage == 0:
		hovered_section = -1
		for index in 4:
			if Rect2(SECTIONS[index] - Vector2(49, 65), Vector2(98, 95)).has_point(point):
				hovered_section = index
				if clicked:
					section_selected.emit(index)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_section >= 0 else Control.CURSOR_ARROW
	elif stage == 1 and clicked:
		for index in 3:
			if point.distance_to(FIX_POINTS[index]) < 31:
				fixation_selected.emit(index)
	elif stage == 4 and clicked and not load_locked:
		var target := _load_target(load_count)
		if target.has_point(point):
			sack_requested.emit(load_count)


func _load_target(index: int) -> Rect2:
	if index < 0 or index >= 3:
		return Rect2()
	return Rect2(SACK_X[index] - 39, 62, 78, 110)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not active or stage != 4 or load_locked or not data is Dictionary:
		return false
	if data.get("kind") != "lumber_sack" or data.get("session") != session_id:
		return false
	var point := at_position * Vector2(771, 323) / size
	return data.get("index", -1) == load_count and _load_target(load_count).has_point(point)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		sack_requested.emit(load_count)


func deflection_at(x: float) -> float:
	if x > 115 and x < 340:
		return sin((x - 115) / 225.0 * PI) * bend
	if x >= 340 and x < 535:
		return sin((x - 340) / 195.0 * PI) * bend
	return 0.0


func _draw() -> void:
	if font == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(771, 323))
	_draw_wood()
	_draw_fixings()
	_draw_labels()
	if extra_mode == "measure":
		_draw_measuring()
	elif stage == 0:
		_draw_inspection()
	elif stage == 1:
		for index in 3:
			if not fixations[index]:
				_target(FIX_POINTS[index], str(index + 1))
	elif stage == 2:
		_draw_saw_guide()
	elif stage == 3:
		_draw_plane_guide()
	elif stage == 4:
		_draw_load_test()
	elif stage == 5:
		_plate(Rect2(152, 257, 467, 46), Color("192117f5"), Color("8ca665"))
		draw_string(font, Vector2(180, 285), "✓ TABLA ESTRUCTURAL LISTA PARA EL MOLINO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GREEN)
	if stage < 4 and (saw_count > 0 or plane_count > 0):
		for chip in saw_count * 6 + plane_count * 9:
			var point := Vector2(210 + fposmod(chip * 53.7, 330), 226 + fposmod(chip * 23.3, 22))
			if chip % 3 == 0 and plane_count > 0:
				draw_arc(point, 2.0 + chip % 3, 0, PI * 1.6, 12, Color("c5a368"), 1.4)
			else:
				draw_line(point, point + Vector2(3, 1), Color("c39a55"), 1.5)
	if feedback_time > 0:
		var alpha := minf(1.0, feedback_time * 3)
		var width := font.get_string_size(feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 30
		var rect := Rect2((771 - width) / 2, 211, width, 29)
		_plate(rect, Color(0.07, 0.05, 0.02, alpha * 0.94), Color(feedback_color, alpha * 0.7))
		draw_string(font, rect.position + Vector2(15, 20), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(feedback_color, alpha))
	draw_set_transform(Vector2.ZERO)


func _draw_wood() -> void:
	var jiggle := sin(time * 28) * stability_pulse * 1.8
	if stage < 3:
		var source: Rect2 = REGIONS[0]
		if offcut <= 0:
			draw_texture_rect_region(WOOD, Rect2(60, 110 + jiggle, 540, 62), source)
		else:
			var fraction := 490.0 / 540.0
			draw_texture_rect_region(WOOD, Rect2(60, 110, 490, 62), Rect2(source.position, source.size * Vector2(fraction, 1)))
			draw_set_transform(Vector2(550 + offcut * 19, 110 + offcut * offcut * 92) * size / Vector2(771, 323), offcut * 0.48, size / Vector2(771, 323))
			draw_texture_rect_region(WOOD, Rect2(0, 0, 50, 62), Rect2(source.position + Vector2(source.size.x * fraction, 0), source.size * Vector2(1 - fraction, 1)), Color(1, 1, 1, 1 - offcut * 0.6))
			draw_set_transform(Vector2.ZERO, 0, size / Vector2(771, 323))
		if chalk > 0:
			for dash in int(24 * chalk):
				var x := 90 + dash * 19.0
				draw_line(Vector2(x, 121), Vector2(x + 11, 121), Color("f3e8c8"), 1.4)
			draw_line(Vector2(550, 109), Vector2(550, 109 + chalk * 61), Color("f4e9c8"), 2)
	else:
		var source: Rect2 = REGIONS[2] if plane_count >= 4 else REGIONS[1]
		# Strips of the actual timber bend between supports; the room stays still.
		for slice in 70:
			var x := 60 + slice * 7.0
			draw_texture_rect_region(WOOD, Rect2(x, 112 + deflection_at(x), 7.1, 60), Rect2(source.position + Vector2(source.size.x * slice / 70, 0), Vector2(source.size.x / 70 + 0.2, source.size.y)))
		if stage == 3 and plane_count < 4:
			var smooth: Rect2 = REGIONS[2]
			for lane in 4:
				var amount: float = lane_progress[lane]
				if amount > 0:
					draw_texture_rect_region(WOOD, Rect2(60, 112 + lane * 5, 490 * amount, 5), Rect2(smooth.position + Vector2(0, smooth.size.y * lane / 12.0), Vector2(smooth.size.x * amount, smooth.size.y / 12.0)))


func _draw_fixings() -> void:
	if stage < 1 or stage > 2:
		return
	for index in 2:
		var amount: float = fix_progress[index]
		if amount <= 0:
			continue
		var p: Vector2 = FIX_POINTS[index] + Vector2(-22 * (1 - amount), 0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-20, 1), p + Vector2(15, 1), p + Vector2(10, -21)]), INK)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-15, -1), p + Vector2(12, -1), p + Vector2(8, -17)]), Color("b58142"))
		draw_line(p + Vector2(-9, -4), p + Vector2(7, -10), Color("e0b16b"), 2)
	var closing: float = fix_progress[2]
	if closing > 0:
		var x := 524.0
		var top := 100.0 - (1 - closing) * 23
		draw_polyline(PackedVector2Array([Vector2(x + 17, top), Vector2(x + 30, top), Vector2(x + 30, 192), Vector2(x + 9, 192)]), INK, 9)
		draw_polyline(PackedVector2Array([Vector2(x + 17, top), Vector2(x + 30, top), Vector2(x + 30, 192), Vector2(x + 9, 192)]), Color("70695a"), 4)
		draw_line(Vector2(x + 12, 165), Vector2(x + 12, 205), INK, 5)
		for thread in 8:
			draw_line(Vector2(x + 9, 168 + thread * 4), Vector2(x + 15, 166 + thread * 4), Color("a39b7e"), 1)
		draw_line(Vector2(x + 12, 205) - Vector2(cos(closing * TAU * 2) * 15, 2), Vector2(x + 12, 205) + Vector2(cos(closing * TAU * 2) * 15, 2), Color("a0865e"), 4)
		draw_rect(Rect2(x + 6, 162, 14, 5), Color("605b4c"))


func _draw_inspection() -> void:
	for index in 4:
		var p: Vector2 = SECTIONS[index]
		if index == 1:
			draw_polyline(PackedVector2Array([p + Vector2(-17, -14), p + Vector2(2, -4), p + Vector2(-5, 4), p + Vector2(16, 16)]), INK, 2)
		elif index == 2:
			for ring in 3:
				draw_arc(p, 4 + ring * 3, 0, TAU, 24, Color("432915"), 1.4)
		elif index == 3:
			draw_circle(p, 17, Color(0.12, 0.22, 0.15, 0.3))
		var color := (GREEN if index == 0 else Color("e69b58")) if inspected[index] else GOLD
		if hovered_section == index:
			draw_rect(Rect2(p - Vector2(46, 24), Vector2(92, 48)), Color(color, 0.12))
		_target(p + Vector2(0, -47), str(index + 1), color)
		if not inspected[index]:
			draw_line(p + Vector2(0, -33), p + Vector2(0, -22), Color(color, 0.65), 1)
	_plate(Rect2(123, 259, 525, 45), Color("1b170fed"), Color("79603a"))
	var hints := ["1  Veta recta: fibras largas y paralelas", "2  Grieta: una fractura recorre la madera", "3  Nudo: las fibras se desvían alrededor", "4  Humedad: zona oscura y fibras hinchadas"]
	var caption: String = hints[hovered_section] if hovered_section >= 0 else "Explora las cuatro marcas sobre la madera"
	_center_text(caption, 286, 13, GOLD)


func _draw_saw_guide() -> void:
	var handle := saw_position + Vector2(-94 if saw_direction == 1 else 94, 0)
	draw_arc(handle, 19, 0, TAU, 32, Color(GOLD, 0.7 + sin(time * 4) * 0.2), 1.5)
	var direction := "→" if saw_direction == 1 else "←"
	_plate(Rect2(188, 263, 395, 39), Color("1b170fed"), Color("79603a"))
	_center_text("%s    RECORRIDO %d / 5    %s" % [direction, mini(5, saw_count + 1), direction], 287, 15, GOLD)


func _draw_plane_guide() -> void:
	for lane in 4:
		var color := GREEN if lane < plane_count else GOLD if lane == plane_count else Color("786d51")
		draw_circle(Vector2(39, 116 + lane * 5), 2, color)
	_plate(Rect2(170, 263, 432, 39), Color("1b170fed"), Color("79603a"))
	_center_text("A FAVOR DE LA VETA    →    FRANJA %d / 4" % mini(4, plane_count + 1), 287, 13, GOLD)


func _draw_load_test() -> void:
	if load_count < 3 and not load_locked:
		var target := _load_target(load_count)
		draw_rect(target, Color(GREEN, 0.08))
		draw_rect(target, Color(GREEN, 0.65), false, 1.5)
		_target(Vector2(SACK_X[load_count], 80), str(load_count + 1), GREEN)
	_plate(Rect2(163, 258, 445, 47), Color("1b1e13ed"), Color("79603a"))
	var labels := ["CARGA LIGERA", "CARGA MEDIA", "CARGA COMPLETA"]
	for index in 3:
		var color := GREEN if index < verified_loads else GOLD if index < load_count else Color("8d8267")
		draw_string(font, Vector2(181 + index * 141, 286), ("✓ " if index < verified_loads else "○ ") + labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _draw_labels() -> void:
	var titles := ["EXAMINAR LA MADERA", "FIJAR ANTES DE CORTAR", "CORTE GUIADO", "CEPILLADO A FAVOR DE VETA", "PRUEBA DE CARGA", "TABLA TERMINADA"]
	_plate(Rect2(14, 12, 254, 27), Color("1a160feb"), Color("715a39"))
	draw_circle(Vector2(27, 25), 3, GREEN if stage == 5 else GOLD)
	draw_string(font, Vector2(38, 30), "MEDIR Y MARCAR CON ESCUADRA" if extra_mode == "measure" else titles[stage], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
	_plate(Rect2(592, 12, 165, 27), Color("1a160feb"), Color("715a39"))
	draw_string(font, Vector2(606, 30), "TALLER DE BRUNO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)


func _target(point: Vector2, caption: String, color := GOLD) -> void:
	draw_circle(point, 13, Color("20190fea"))
	draw_arc(point, 13, 0, TAU, 28, color, 1.4)
	draw_string(font, point + Vector2(-4, 5), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


func _center_text(caption: String, y: float, font_size: int, color: Color) -> void:
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((771 - width) / 2, y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _plate(rect: Rect2, fill: Color, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	draw_style_box(box, rect)


func _draw_measuring() -> void:
	_plate(Rect2(89, 89, 462, 19), Color("87663a"), Color("d9b374"))
	for tick in 41:
		var x := 96.0 + tick * 11.1
		draw_line(Vector2(x, 103), Vector2(x, 90 if tick % 5 == 0 else 96), INK, 1)
		if tick % 10 == 0:
			draw_string(font, Vector2(x - 2, 86), str(tick * 4), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
	for index in 3:
		_target(Vector2(90 + index * 230, 78), str(index + 1), GREEN if index < marked_lines else GOLD)
	draw_set_transform(Vector2(550, 109) * size / Vector2(771, 323), deg_to_rad(square_angle - 90), size / Vector2(771, 323))
	draw_polyline(PackedVector2Array([Vector2(-59, 0), Vector2(0, 0), Vector2(0, 75)]), INK, 12)
	draw_polyline(PackedVector2Array([Vector2(-59, 0), Vector2(0, 0), Vector2(0, 75)]), Color("b99551"), 7)
	for tick in 8:
		draw_line(Vector2(-3, tick * 9), Vector2(3, tick * 9), INK, 1)
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(771, 323))
	_plate(Rect2(155, 257, 461, 55), Color("241c12"), Color("a48449"))
	_center_text("MARCA %d / 3 · %.0f cm · ESCUADRA %.0f°" % [mini(3, marked_lines + 1), measured_length, square_angle], 273, 12, GOLD)
