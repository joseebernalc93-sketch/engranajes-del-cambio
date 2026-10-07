extends Control
## Native interactive parts, clamps, gauges and centering screws over Mateo's workshop.
var puzzle: CanvasLayer
var dragging_piece := false
var drag_point := Vector2.ZERO
var drag_start := Vector2.ZERO
var held_screw := -1
const TRAY := [Vector2(350, 83), Vector2(420, 83), Vector2(350, 195), Vector2(420, 195)]
const SCREW_OFFSETS := [Vector2(-25, -21), Vector2(25, -21), Vector2(0, 30)]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func release_pointer() -> void:
	dragging_piece = false
	held_screw = -1


func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(puzzle) or not puzzle.overlay.visible or puzzle.action_locked:
		return
	if not (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var point: Vector2 = event.position * Vector2(771, 323) / size
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if puzzle.forge_stage == puzzle.STAGE_ASSEMBLE:
		if pressed:
			for index in range(4):
				if not puzzle.parts_placed[index] and point.distance_to(TRAY[index]) < 36:
					puzzle.selected_piece = index
					dragging_piece = true
					drag_start = point
					drag_point = point
					accept_event()
					return
			for index in range(4):
				if point.distance_to(target(index)) < 25:
					puzzle.place_part(puzzle.selected_piece, index)
					accept_event()
					return
			for index in range(2):
				if point.distance_to(clamp_position(index)) < 23:
					puzzle.selected_clamp = index
					puzzle.clamp_hold = true
					accept_event()
					return
		elif dragging_piece and (event is InputEventMouseMotion or event is InputEventScreenDrag):
			drag_point = point
			accept_event()
		elif released:
			puzzle.clamp_hold = false
			if dragging_piece:
				dragging_piece = false
				if point.distance_to(drag_start) > 8:
					for index in range(4):
						if point.distance_to(target(index)) < 27:
							puzzle.place_part(puzzle.selected_piece, index)
							break
				accept_event()
	elif puzzle.forge_stage == puzzle.STAGE_CENTER:
		if pressed:
			for index in range(3):
				if point.distance_to(screw_position(index)) < 17:
					puzzle.selected_screw = index
					held_screw = index
					drag_point = point
					accept_event()
					return
		elif held_screw >= 0 and (event is InputEventMouseMotion or event is InputEventScreenDrag):
			puzzle.adjust_screw(held_screw, (point.x - drag_point.x) / 140)
			drag_point = point
			accept_event()
		elif released:
			held_screw = -1
	elif puzzle.forge_stage == puzzle.STAGE_TEST:
		var handle: Vector2 = puzzle.workbench.CENTER + Vector2(31, 0).rotated(puzzle.workbench.wheel_angle)
		if pressed and (point.distance_to(handle) < 23 or point.distance_to(puzzle.workbench.CENTER) < 24):
			puzzle.pointer_proof = true
			accept_event()
		elif released:
			puzzle.pointer_proof = false


func target(index: int) -> Vector2:
	return puzzle.workbench.CENTER + Vector2(0, -69).rotated(index * PI / 2)


func clamp_position(index: int) -> Vector2:
	return puzzle.workbench.CENTER + Vector2(-111 if index == 0 else 111, 0)


func screw_position(index: int) -> Vector2:
	return puzzle.workbench.CENTER + SCREW_OFFSETS[index]


func _draw() -> void:
	if not is_instance_valid(puzzle) or not puzzle.overlay.visible:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(771, 323))
	var font := ThemeDB.fallback_font
	if puzzle.forge_stage == puzzle.STAGE_ASSEMBLE:
		for index in range(4):
			if not puzzle.parts_placed[index]:
				var rect := Rect2(TRAY[index] - Vector2(30, 40), Vector2(60, 80))
				draw_rect(rect, Color("171812e8"))
				draw_rect(rect, Color("e4b466") if puzzle.selected_piece == index else Color("77664d"), false, 1.5)
				_piece(TRAY[index], puzzle.piece_angles[index], index, Color("b1b4ab"))
				draw_string(font, TRAY[index] + Vector2(-19, 33), "PIEZA %d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d6c297"))
			var color := Color("b7d69a") if puzzle.parts_placed[index] else Color("d2ae69")
			draw_arc(target(index), 21, 0, TAU, 32, color, 1.5, true)
			if puzzle.parts_placed[index]:
				_piece(target(index), index, index, Color("899081"))
			else:
				draw_string(font, target(index) + Vector2(-4, 5), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		for index in range(2):
			var point := clamp_position(index)
			draw_rect(Rect2(point - Vector2(13, 18), Vector2(26, 36)), Color("242722"))
			draw_rect(Rect2(point - Vector2(10, 15), Vector2(20, 30)), Color("8e754c"))
			var shaft := point + Vector2((1 - puzzle.clamps[index]) * (12 if index == 0 else -12), 0)
			draw_line(shaft - Vector2(0, 11), shaft + Vector2(0, 11), Color("dfcda0"), 4)
			draw_circle(point + Vector2(0, 27), 4, Color("b7d69a") if puzzle.clamps[index] >= 1 else Color("785442"))
		if dragging_piece:
			_piece(drag_point, puzzle.piece_angles[puzzle.selected_piece], puzzle.selected_piece, Color("e4d2a7"))
	elif puzzle.forge_stage == puzzle.STAGE_RIVET:
		_meter(Rect2(333, 206, 145, 20), puzzle.precision_value(), 0.38, 0.62, "PRECISIÓN DEL GOLPE")
	elif puzzle.forge_stage == puzzle.STAGE_COOL:
		_meter(Rect2(333, 206, 145, 20), puzzle.cooling_rate() / 20, (puzzle.cooling_target() - 2) / 20, (puzzle.cooling_target() + 2) / 20, "RITMO DE ENFRIAMIENTO")
	elif puzzle.forge_stage == puzzle.STAGE_CENTER:
		var center := Vector2(397, 146)
		draw_rect(Rect2(332, 68, 141, 162), Color("171b17ec"))
		draw_circle(center, 47, Color("a99469"))
		draw_circle(center, 43, Color("e4d8b6"))
		for tick in range(11):
			var direction := Vector2.from_angle(-PI * 0.8 + tick * PI * 1.6 / 10)
			draw_line(center + direction * 34, center + direction * 40, Color("4c5146"), 1.4)
		var needle := Vector2.from_angle(-PI * 0.8 + clampf(puzzle.center_error() / 0.6, 0, 1) * PI * 1.6)
		draw_line(center - needle * 7, center + needle * 32, Color("944e38"), 2.5, true)
		draw_circle(center, 4, Color("6b5e44"))
		draw_string(font, Vector2(343, 89), "RELOJ COMPARADOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dec792"))
		draw_string(font, Vector2(343, 210), "CENTRADO: ≤ 6.5%", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b7d69a"))
		for index in range(3):
			var point := screw_position(index)
			var color := Color("b7d69a") if absf(puzzle.screws[index] - puzzle.SCREW_TARGETS[index]) <= 0.065 else Color("d4b272")
			draw_circle(point, 12, Color("282e2b"))
			draw_circle(point, 9, color)
			var direction := Vector2.from_angle(puzzle.screws[index] * TAU * 3)
			draw_line(point - direction * 6, point + direction * 6, Color("36372c"), 2)
			if puzzle.selected_screw == index:
				draw_arc(point, 15, 0, TAU, 24, Color("f4d590"), 1.5)
			_meter(Rect2(331, 237 + index * 17, 145, 10), puzzle.screws[index], puzzle.SCREW_TARGETS[index] - 0.065, puzzle.SCREW_TARGETS[index] + 0.065, "" if index > 0 else "AJUSTE DE LOS TRES TORNILLOS")
	elif puzzle.forge_stage == puzzle.STAGE_TEST:
		var hub: Vector2 = puzzle.workbench.CENTER
		var handle := hub + Vector2(31, 0).rotated(puzzle.workbench.wheel_angle)
		draw_line(hub, handle, Color("252b26"), 8, true)
		draw_line(hub, handle, Color("c7b483"), 4, true)
		draw_circle(handle, 8, Color("6e492c"))
		draw_circle(handle - Vector2(1, 2), 4, Color("b88a53"))
		_meter(Rect2(332, 206, 146, 20), puzzle.wheel_speed / 3, (puzzle.proof_target() - 0.28) / 3, (puzzle.proof_target() + 0.28) / 3, "VELOCIDAD BAJO CARGA")
		for index in range(3):
			var rect := Rect2(636 + index * 27, 257, 23, 23)
			draw_rect(rect, Color("8d734f") if index <= puzzle.proof_checks else Color("393a32"))
			draw_rect(rect, Color("c9b282"), false, 1)
			draw_string(font, rect.position + Vector2(8, 16), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("efe5c4"))
	draw_set_transform(Vector2.ZERO)


func _piece(point: Vector2, quarter: int, index: int, color: Color) -> void:
	draw_set_transform(point * size / Vector2(771, 323), quarter * PI / 2, size / Vector2(771, 323))
	draw_rect(Rect2(-21, -10, 42, 20), Color("242a27"))
	draw_rect(Rect2(-19, -8, 38, 16), color)
	draw_rect(Rect2(-4, -10, 8, 5), Color("2b2920"))
	for bolt in [-13.0, 13.0]:
		draw_circle(Vector2(bolt, 0), 2.4, Color("343a33"))
	draw_string(ThemeDB.fallback_font, Vector2(-4, 5), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("35372f"))
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(771, 323))


func _meter(rect: Rect2, value: float, low: float, high: float, title: String) -> void:
	draw_rect(rect, Color("161c18"))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * clampf(low, 0, 1), 0), Vector2(rect.size.x * (high - low), rect.size.y)), Color("6d8852"))
	draw_rect(rect, Color("a08e5c"), false, 1)
	var x := rect.position.x + rect.size.x * clampf(value, 0, 1)
	draw_line(Vector2(x, rect.position.y - 3), Vector2(x, rect.end.y + 3), Color("ffdea1"), 2.5)
	if not title.is_empty():
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -9), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e6d2a1"))
