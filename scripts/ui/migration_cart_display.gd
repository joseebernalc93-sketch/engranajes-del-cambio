extends Control
## Cart chassis, rotating wheels, cargo, gate and road are independent layers.

signal preview_requested(id: String)
signal item_requested(id: String)
signal load_shift_requested(value: float)
signal gate_requested
signal push_requested(pressed: bool)

const PARTS := preload("res://assets/gba/ui/elena_cart_parts_v2.png")
const LANDSCAPE := preload("res://assets/gba/ui/elena_riverside_backdrop_v2.png")
const ELENA := preload("res://assets/gba/elena_sheet.png")
const GATE := preload("res://assets/gba/ui/elena_enclosure_gate_v2.png")
const CARGO_ART := preload("res://scripts/ui/elena_cargo_art.gd")
const IDS := ["alimentos", "mantas", "herramientas", "retrato", "olla", "semillas"]
const BODY := preload("res://assets/gba/ui/elena_wagon_body_v4.png")
const HORSE := preload("res://assets/gba/ui/elena_draft_horse_walk_v4.png")
const BODY_REGION := Rect2(25, 102, 1740, 661)
const BODY_RECT := Rect2(99, 110, 417, 157)
const CARGO_BOX := Rect2(137, 132, 261, 73)
const HORSE_RECT := Rect2(498, 151, 188, 140)
const WHEEL_REGION := Rect2(1127, 350, 390, 396)
const DESIGN := Vector2(771, 323)
const GOLD := Color("efc16a")
const LOAD_TARGET := Rect2(137, 132, 261, 96)
const HANDLE_TARGET := HORSE_RECT
const GATE_TARGET := Rect2(564, 92, 178, 190)

var active := false
var stage := 0
var items: Array[String] = []
var balance := 50.0
var gate_checked := false
var alternate_route := false
var priority := ""
var recovery := 0.0
var journey := 0.0
var speed := 0.0
var wheel_angle := 0.0
var travelled := 0.0
var pushing := false
var gate_shake := 0.0
var time := 0.0
var dragging_load := false
var touch_index := -1
var drag_origin := 0.0
var drag_balance := 50.0
var feedback := ""
var feedback_seconds := 0.0
var item_pulses: Dictionary = {}
var preview_item := "alimentos"
var vehicle_origin := Vector2.ZERO
var vehicle_scale := 1.0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func reset_cart() -> void:
	cancel_drag()
	stage = 0
	items.clear()
	balance = 50.0
	gate_checked = false
	alternate_route = false
	priority = ""
	recovery = 0.0
	journey = 0.0
	speed = 0.0
	wheel_angle = 0.0
	travelled = 0.0
	gate_shake = 0.0
	feedback_seconds = 0.0
	item_pulses.clear()
	preview_item = "alimentos"
	queue_redraw()


func cancel_drag() -> void:
	dragging_load = false
	touch_index = -1
	push_requested.emit(false)


func pulse_item(id: String) -> void:
	item_pulses[id] = 0.65


func show_feedback(message: String) -> void:
	feedback = message
	feedback_seconds = 3.0
	queue_redraw()


func _process(delta: float) -> void:
	if not active or not is_visible_in_tree():
		return
	time += delta
	gate_shake = maxf(0.0, gate_shake - delta)
	feedback_seconds = maxf(0.0, feedback_seconds - delta)
	for id in item_pulses:
		item_pulses[id] = maxf(0.0, float(item_pulses[id]) - delta)
	queue_redraw()


func _to_design(pos: Vector2) -> Vector2:
	return pos * DESIGN / size


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_pressed(_to_design(event.position))
		else:
			cancel_drag()
		accept_event()
	elif event is InputEventMouseMotion:
		if dragging_load:
			_pointer_dragged(_to_design(event.position))
			accept_event()
		elif stage == 0:
			for index in IDS.size():
				if Rect2(34 + index * 115, 244, 105, 64).has_point(_to_design(event.position)):
					preview_item = IDS[index]
					preview_requested.emit(preview_item)
					queue_redraw()
					break
	elif event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			_pointer_pressed(_to_design(event.position))
		elif not event.pressed and event.index == touch_index:
			cancel_drag()
		accept_event()
	elif event is InputEventScreenDrag and event.index == touch_index and dragging_load:
		_pointer_dragged(_to_design(event.position))
		accept_event()


func _pointer_pressed(pos: Vector2) -> void:
	if stage == 0:
		for index in IDS.size():
			if Rect2(34 + index * 115, 244, 105, 64).has_point(pos):
				item_requested.emit(IDS[index])
				return
	elif stage == 1 and LOAD_TARGET.has_point(pos):
		dragging_load = true
		drag_origin = pos.x
		drag_balance = balance
	elif stage == 2 and GATE_TARGET.has_point(pos):
		gate_requested.emit()
	elif stage in [3, 5] and HANDLE_TARGET.has_point(pos):
		push_requested.emit(true)


func _pointer_dragged(pos: Vector2) -> void:
	if stage == 1 and dragging_load:
		load_shift_requested.emit(clampf(drag_balance + (pos.x - drag_origin) * 0.5, 0.0, 100.0))


func _draw() -> void:
	if not font:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN)
	_draw_landscape()
	if stage == 2:
		_draw_gate()
	var bog := (1.0 - recovery) if stage in [4, 5] else 0.0
	var bump := sin(travelled * 0.1) * minf(speed / 105.0, 1.0) * 1.2
	vehicle_scale = 0.78 if stage == 2 else 1.0
	vehicle_origin = Vector2(5, 45) if stage == 2 else Vector2(0, bump - (60.0 if stage == 0 else 0.0))
	if stage == 5:
		vehicle_origin.x += recovery * 12.0
	_draw_cart(bog)
	_draw_horse()
	_draw_elena(bog)
	draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN)
	if stage == 0:
		_draw_inventory()
	elif stage == 1:
		_draw_balance_guide()
	elif stage in [3, 5]:
		_draw_handle(vehicle_origin)
	if stage == 6:
		_badge(Vector2(240, 25), "✓ LA FAMILIA ESTÁ A SALVO", Color("bedb91"), 292)
	elif stage == 2:
		_badge(Vector2(24, 20), "DESVÍO JUNTO AL RÍO" if alternate_route else "CAMINO COMUNAL", GOLD, 233)
	if feedback_seconds > 0.0:
		_badge(Vector2(74, 22), feedback, GOLD, 624)
	draw_style_box(_box(Color(0.035, 0.055, 0.023, 0.85), Color("756644")), Rect2(0, 295, 771, 28))
	draw_set_transform(Vector2.ZERO)


func _draw_landscape() -> void:
	# Pan within a single panorama instead of repeating its non-seamless edges.
	var scroll := clampf(journey, 0.0, 1.0) * 300.0
	draw_texture_rect(LANDSCAPE, Rect2(-scroll, -75, 1071, 446), false)
	# Small stones follow the road. Their movement matches the rolling cart.
	for index in 15:
		var stone_x := fposmod(index * 61.0 - travelled, 831.0) - 30.0
		var stone_y := 276.0 + (index % 3) * 16.0
		draw_line(Vector2(stone_x, stone_y), Vector2(stone_x + 6, stone_y), Color("806b43"), 3.0)
	if stage in [4, 5]:
		draw_style_box(_box(Color("4e3725"), Color("776045")), Rect2(359, 274, 98, 25))
		for index in 6:
			draw_line(Vector2(369 + index * 14, 282), Vector2(378 + index * 14, 286), Color("967858"), 2.0)
	if stage == 6:
		draw_line(Vector2(719, 61), Vector2(719, 145), Color("624527"), 6.0)
		draw_style_box(_box(Color("3a4933"), GOLD), Rect2(599, 24, 148, 38))
		draw_string(font, Vector2(611, 49), "ESTACIÓN →", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("ffdf9c"))


func _vehicle_transform() -> void:
	draw_set_transform(vehicle_origin * size / DESIGN, 0.0, size / DESIGN * vehicle_scale)


func get_cargo_layout() -> Array[Dictionary]:
	# Each item has its own floor slot. Movement stays within the bed even at
	# balance extremes and during loading, travel and the recovery animation.
	var layout: Array[Dictionary] = []
	if items.is_empty():
		return layout
	var slot_width := minf(78.0, (CARGO_BOX.size.x - 28.0 - (items.size() - 1) * 8.0) / items.size())
	var step := slot_width + 8.0
	var start := CARGO_BOX.get_center().x - (items.size() - 1) * step * 0.5
	for index in items.size():
		var id: String = items[index]
		var normal := _item_rect(id, Vector2.ZERO, 1.0).size
		var fitting := minf(slot_width / normal.x, 67.0 / normal.y)
		var hop := sin(clampf(float(item_pulses.get(id, 0.0)) / 0.65, 0.0, 1.0) * PI) * 4.0
		var sway := sin(travelled * 0.08 + index) * minf(speed / 105.0, 1.0) * 0.4
		var pos := Vector2(start + index * step + (balance - 50.0) * 0.2 + sway, CARGO_BOX.end.y - hop)
		layout.append({"id": id, "pos": pos, "scale": fitting, "rect": _item_rect(id, pos, fitting)})
	return layout


func _draw_cart(bog: float) -> void:
	_vehicle_transform()
	draw_texture_rect_region(BODY, BODY_RECT, BODY_REGION)
	for entry in get_cargo_layout():
		_draw_item(entry.id, entry.pos, entry.scale)
		if _is_priority(entry.id):
			_draw_item_binding(entry.id, entry.pos, entry.scale)
	# Restore the near wall over the floor/cargo layer: the bed encloses the load.
	var near_region := Rect2(25, 515, 1740, 248)
	var ratio := BODY_RECT.size / BODY_REGION.size
	var near_rect := Rect2(BODY_RECT.position + (near_region.position - BODY_REGION.position) * ratio, near_region.size * ratio)
	draw_texture_rect_region(BODY, near_rect, near_region)
	if stage > 0 and not items.is_empty():
		draw_polyline(PackedVector2Array([Vector2(143, 176), Vector2(152, 228), Vector2(384, 228), Vector2(393, 176)]), Color("d4ad65"), 2.0)
	if stage == 5:
		draw_polygon(PackedVector2Array([Vector2(375, 285), Vector2(451, 272), Vector2(455, 282), Vector2(377, 295)]), PackedColorArray([Color("a5793f")]))
		draw_line(Vector2(376, 284), Vector2(451, 272), Color("e1b16a"), 3.0)
	_draw_wheel(Vector2(163, 253), wheel_angle, 37.0)
	_draw_wheel(Vector2(390, 253 + bog * 8), wheel_angle + (sin(time * 12.0) * 0.09 if pushing and stage == 5 else 0.0), 37.0)
	if stage in [4, 5] and bog > 0:
		draw_line(Vector2(368, 291), Vector2(426, 293), Color("533925"), 6.0 * bog)


func _draw_wheel(center: Vector2, angle: float, radius: float) -> void:
	draw_set_transform((vehicle_origin + center * vehicle_scale) * size / DESIGN, angle, size / DESIGN * vehicle_scale)
	draw_texture_rect_region(PARTS, Rect2(-radius, -radius, radius * 2, radius * 2), WHEEL_REGION)
	_vehicle_transform()


func horse_frame() -> int:
	return int(travelled / 12.0) % 4 if speed > 1.0 else (int(time * 6.0) % 4 if pushing and stage == 5 else 0)


func _draw_horse() -> void:
	_vehicle_transform()
	draw_texture_rect_region(HORSE, HORSE_RECT, Rect2(horse_frame() * 543, 158, 543, 399))
	# The shafts terminate at the belly strap; Elena walks alongside the wagon.
	for offset in [0, 9]:
		draw_line(Vector2(507, 237 + offset), Vector2(592, 227 + offset), Color("4b3422"), 4.0)
		draw_line(Vector2(507, 236 + offset), Vector2(592, 226 + offset), Color("bb8540"), 2.0)
	draw_arc(Vector2(592, 226), 4, 0, TAU, 12, GOLD, 2.0)


func _draw_item(id: String, pos: Vector2, scale_factor: float) -> void:
	var rect := _item_rect(id, pos, scale_factor)
	var shadow := PackedVector2Array()
	for index in 16:
		var angle := index * TAU / 16
		shadow.append(pos + Vector2(cos(angle) * rect.size.x * 0.43, sin(angle) * 3.0 * scale_factor))
	draw_polygon(shadow, PackedColorArray([Color(0.08, 0.065, 0.035, 0.3)]))
	draw_texture_rect_region(CARGO_ART.TEXTURES[id], rect, CARGO_ART.REGIONS[id])


func _item_rect(id: String, pos: Vector2, scale_factor: float) -> Rect2:
	var region: Rect2 = CARGO_ART.REGIONS[id]
	var maximum: Vector2 = CARGO_ART.SIZES[id] * scale_factor
	var fitting := minf(maximum.x / region.size.x, maximum.y / region.size.y)
	var drawn_size := region.size * fitting
	return Rect2(pos - Vector2(drawn_size.x * 0.5, drawn_size.y), drawn_size)


func _draw_item_binding(id: String, pos: Vector2, scale_factor: float) -> void:
	var rect := _item_rect(id, pos, scale_factor)
	for side in [-1, 1]:
		var x: float = rect.get_center().x + side * rect.size.x * 0.3
		var points := PackedVector2Array([Vector2(x - 3, rect.position.y + 5), Vector2(x + 2, rect.position.y + rect.size.y * 0.64), Vector2(x - 1, rect.end.y - 1)])
		draw_polyline(points, Color("635033"), 4)
		draw_polyline(points, Color("d7bd80"), 2)
	var band_y := rect.position.y + rect.size.y * 0.78
	draw_line(Vector2(rect.position.x + 2, band_y), Vector2(rect.end.x - 2, band_y), Color("d7bd80"), 2)
	var knot := Vector2(rect.get_center().x + rect.size.x * 0.3, band_y)
	draw_arc(knot - Vector2(3, 1), 3, 0, TAU, 12, Color("f0d39a"), 1)
	draw_arc(knot + Vector2(3, 1), 3, 0, TAU, 12, Color("f0d39a"), 1)
	draw_line(knot, knot + Vector2(-4, 8), Color("d7bd80"), 2)
	draw_line(knot, knot + Vector2(5, 7), Color("d7bd80"), 2)


func _is_priority(id: String) -> bool:
	if priority.is_empty():
		return false
	return id in ["retrato", "mantas"] if priority == "recuerdo familiar" else id in ["alimentos", "semillas"] if priority == "alimentos" else id in ["herramientas", "olla"]


func _draw_inventory() -> void:
	for index in IDS.size():
		var rect := Rect2(34 + index * 115, 244, 105, 64)
		var selected := items.has(IDS[index])
		draw_style_box(_box(Color(0.1, 0.12, 0.07, 0.87), GOLD if selected else Color("807347")), rect)
		_draw_item(IDS[index], rect.position + Vector2(28, 51), 0.64)
		draw_string(font, rect.position + Vector2(55, 29), ["Comida", "Mantas", "Útiles", "Retrato", "Olla", "Semillas"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f1dfb5"))
		draw_string(font, rect.position + Vector2(56, 46), "✓" if selected else "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD)


func _draw_balance_guide() -> void:
	var marker := Vector2(267.5 + (balance - 50.0) * 0.2, 108)
	draw_line(Vector2(217, 107), Vector2(318, 107), GOLD, 2.0)
	draw_line(Vector2(262, 107), Vector2(273, 107), Color("b4d58c"), 7.0)
	draw_line(marker + Vector2(0, -20), marker, Color("f6d079"), 3.0)
	draw_circle(marker, 5, GOLD)
	_badge(Vector2(159, 40), "← REPARTE LA CARGA →", GOLD, 242)


func _draw_handle(origin: Vector2) -> void:
	var center := Vector2(601, 222) + origin
	draw_arc(center, 22.0 + sin(time * 3.0) * 2, 0, TAU, 40, GOLD, 2.0)
	_badge(Vector2(515, 95), "GUIAR AL CABALLO", GOLD, 220)


func _draw_gate() -> void:
	var shake := sin(gate_shake * 45.0) * gate_shake * 7.0
	draw_texture_rect_region(GATE, Rect2(564 + shake, 101, 184, 179), Rect2(64, 99, 1124, 1055))
	if gate_checked:
		_badge(Vector2(550, 46), "CERCAMIENTO · CERRADO", GOLD, 218)
	if alternate_route:
		draw_polyline(PackedVector2Array([Vector2(463, 300), Vector2(524, 300), Vector2(545, 285), Vector2(538, 245), Vector2(520, 212), Vector2(526, 155), Vector2(553, 123)]), Color("ffdc7b"), 4, false)
		draw_circle(Vector2(553, 123), 6, GOLD)


func _draw_elena(bog: float) -> void:
	if stage in [0, 1, 2]:
		return
	# Preserve Elena's established character appearance.
	var step := int(travelled / 18.0) % 3 if speed > 1.0 else (int(time * 5.0) % 3 if pushing else 1)
	# Atlas rows have uneven vertical spacing; use the three right-facing cells.
	var frames := [Rect2(14, 858, 265, 385), Rect2(309, 858, 265, 385), Rect2(605, 447, 265, 385)]
	_vehicle_transform()
	draw_texture_rect_region(ELENA, Rect2(35, 199 + bog * 2, 50, 91), frames[step])


func _badge(pos: Vector2, text: String, color: Color, width: float) -> void:
	draw_style_box(_box(Color(0.06, 0.08, 0.04, 0.92), Color("857448")), Rect2(pos, Vector2(width, 30)))
	draw_string(font, pos + Vector2(10, 20), text, HORIZONTAL_ALIGNMENT_LEFT, width - 16, 13, color)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
