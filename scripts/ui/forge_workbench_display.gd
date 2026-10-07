extends Control
## Independent furnace, bellows, workpiece and meshing pinion over a fixed workshop.

signal bellows_pressed
signal rivet_pressed(index: int)
signal wheel_rotation_requested(angle: float)

const FORGE := preload("res://assets/gba/ui/mateo_forge_bellows_sheet_v1.png")
const WHEEL := preload("res://assets/gba/ui/mill_gear_piece_v1.png")
const PINION := preload("res://assets/gba/ui/mateo_pinion_v2.png")
const FIRE := preload("res://assets/gba/environment/forge_fire_sheet.png")
const CENTER := Vector2(557, 161)
const PINION_CENTER := Vector2(680, 161)
const RIVET_RADIUS := 69.0
const BELLOWS_TARGET := Rect2(83, 138, 143, 139)
const GOLD := Color("e8bd70")
const GREEN := Color("bedc95")

var active := false
var stage := 0
var assembly_visible := false
var parts_placed := [false, false, false, false]
var center_deviation := 0.0
var allow_proof_drag := true
var centering_visible := false
var heat := 0.0
var active_rivet := 0
var hits := [0, 0, 0, 0]
var wheel_angle := 0.0
var wheel_speed := 0.0
var pump_age := 10.0
var pump_compression := 0.0
var impact_flash := 0.0
var impact_rivet := 0
var ventilating := false
var proof_checks := 0
var proof_progress := 0.0
var dragging_wheel := false
var drag_last_angle := 0.0
var touch_index := -1
var strike_locked := false
var feedback := ""
var feedback_color := GOLD
var feedback_seconds := 0.0
var time := 0.0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func reset_workbench() -> void:
	stage = 0
	heat = 0.0
	active_rivet = 0
	hits = [0, 0, 0, 0]
	wheel_angle = 0.0
	wheel_speed = 0.0
	pump_age = 10.0
	pump_compression = 0.0
	impact_flash = 0.0
	ventilating = false
	proof_checks = 0
	proof_progress = 0.0
	dragging_wheel = false
	touch_index = -1
	strike_locked = false
	feedback_seconds = 0.0
	queue_redraw()


func show_feedback(message: String, color := GOLD) -> void:
	feedback = message
	feedback_color = color
	feedback_seconds = 1.7
	queue_redraw()


func rivet_position(index: int) -> Vector2:
	return CENTER + Vector2(0, -RIVET_RADIUS).rotated(wheel_angle + index * PI / 2)


func _process(delta: float) -> void:
	if not active or not is_visible_in_tree():
		return
	time += delta
	pump_age += delta
	pump_compression = sin(minf(pump_age / 0.56, 1) * PI) if pump_age < 0.56 else 0.0
	impact_flash = maxf(0, impact_flash - delta * 4)
	feedback_seconds = maxf(0, feedback_seconds - delta)
	queue_redraw()


func release_pointer() -> void:
	dragging_wheel = false
	touch_index = -1


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if not (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var point: Vector2 = event.position * Vector2(771, 323) / size
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if released:
		release_pointer()
		return
	if pressed:
		if stage == 1:
			for index in range(4):
				if point.distance_to(rivet_position(index)) < 23:
					rivet_pressed.emit(index)
					accept_event()
					return
		if stage <= 1 and BELLOWS_TARGET.has_point(point):
			bellows_pressed.emit()
			accept_event()
		elif (stage == 1 or (stage == 3 and allow_proof_drag)) and not strike_locked and point.distance_to(CENTER) >= 27 and point.distance_to(CENTER) < 110:
			dragging_wheel = true
			drag_last_angle = (point - CENTER).angle()
			touch_index = event.index if event is InputEventScreenTouch else -1
			accept_event()
	elif dragging_wheel and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		if event is InputEventScreenDrag and event.index != touch_index:
			return
		var angle := (point - CENTER).angle()
		wheel_rotation_requested.emit(wheel_angle + wrapf(angle - drag_last_angle, -PI, PI))
		drag_last_angle = angle
		accept_event()
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if (stage <= 1 and BELLOWS_TARGET.has_point(point)) else CURSOR_DRAG if stage in [1, 3] and point.distance_to(CENTER) < 110 else CURSOR_ARROW


func _draw() -> void:
	if font == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(771, 323))
	_draw_forge()
	_draw_stand()
	_draw_wheel()
	if stage >= 3 and not centering_visible:
		_draw_pinion()
	_draw_labels()
	if stage == 0 and not assembly_visible:
		_plate(Rect2(334, 119, 145, 68), Color("1b150fed"), Color("79603a"))
		draw_string(font, Vector2(347, 142), "HIERRO RECUPERADO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
		draw_string(font, Vector2(347, 164), "Azada y hoz → refuerzos", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d0c2a0"))
	elif stage == 1:
		_draw_targets()
	elif stage == 2 and ventilating:
		for stripe in 7:
			var x := 417 + fposmod(time * 115 + stripe * 21, 92)
			var y := 112 + stripe * 16.0
			draw_line(Vector2(x, y), Vector2(x + 22, y - 4), Color(0.74, 0.83, 0.84, 0.45), 1.2)
	if feedback_seconds > 0:
		var width := minf(680, font.get_string_size(feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 28)
		_plate(Rect2((771 - width) / 2, 249, width, 27), Color("1a140fed"), Color(feedback_color, 0.7))
		draw_string(font, Vector2((771 - width) / 2 + 14, 268), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, feedback_color)
	draw_set_transform(Vector2.ZERO)


func _draw_forge() -> void:
	# Draw atlas regions independently: the chimney and floor do not squash with the leather.
	draw_ellipse_shadow(Vector2(223, 282), Vector2(121, 13))
	var lower := Rect2(0, 515, 290, 85)
	draw_texture_rect_region(FORGE, Rect2(89, 252, 122, 36), lower)
	var compression := pump_compression * 23
	draw_texture_rect_region(FORGE, Rect2(89, 142 + compression, 122, 110 - compression), Rect2(0, 255, 290, 260))
	draw_line(Vector2(207, 223), Vector2(226, 223), Color("353337"), 10)
	draw_line(Vector2(207, 222), Vector2(226, 222), Color("8b8171"), 3)
	draw_texture_rect_region(FORGE, Rect2(212, 52, 107, 238), Rect2(290, 70, 253, 565))
	var power := clampf(heat / 100.0 + pump_compression * 0.2, 0, 1)
	var flame_frame := int(time * (5 + power * 5)) % 4
	var fire_size := Vector2(61, 18 + power * 45)
	draw_texture_rect_region(FIRE, Rect2(Vector2(233, 239) - Vector2(0, fire_size.y), fire_size), Rect2(flame_frame * 518, 0, 518, 758), Color(1, 1, 1, 0.25 + power * 0.68))
	if stage <= 1:
		for index in 3:
			var iron := Color("66636a").lerp(Color("ffad45"), power)
			draw_rect(Rect2(246 - index * 4, 235 + index * 7, 54, 5), Color("251911"))
			draw_rect(Rect2(247 - index * 4, 235 + index * 7, 52, 3), iron)
	for spark in 10:
		if power < 0.25:
			break
		var age := fposmod(time * 0.48 + spark * 0.119, 1)
		var point := Vector2(251 + sin(spark * 6.1) * 17 + sin(age * 5) * 8, 250 - age * (34 + power * 58))
		draw_rect(Rect2(point, Vector2(1.4, 2)), Color(1, 0.55 + power * 0.25, 0.15, (1 - age) * power))
	if stage <= 1:
		draw_arc(Vector2(154, 202), 45, 0, TAU, 40, Color(GOLD, 0.2 + sin(time * 3) * 0.08), 1.2)


func _draw_stand() -> void:
	draw_ellipse_shadow(Vector2(558, 284), Vector2(111, 14))
	for x in [510, 603]:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, 205), Vector2(x + 7, 205), Vector2(x + 29, 280), Vector2(x + 10, 280)]), Color("342415"))
		draw_line(Vector2(x + 1, 214), Vector2(x + 20, 275), Color("976c3c"), 8)
	draw_line(Vector2(498, 221), Vector2(628, 221), Color("2b1c13"), 15)
	draw_line(Vector2(498, 217), Vector2(628, 217), Color("9a7046"), 8)
	draw_rect(Rect2(550, 155, 14, 119), Color("483b28"))
	draw_line(Vector2(558, 167), Vector2(558, 267), Color("a58856"), 3)


func _draw_wheel() -> void:
	var scale_factor := size / Vector2(771, 323)
	var jitter := sin(time * 62) * impact_flash * 1.4 + sin(time * 3.5) * center_deviation * 10
	draw_set_transform((CENTER + Vector2(jitter, 0)) * scale_factor, wheel_angle, scale_factor)
	draw_texture_rect(WHEEL, Rect2(-105, -105, 210, 210), false)
	for index in 4:
		if assembly_visible and not parts_placed[index]:
			continue
		var angle := index * PI / 2
		var point := Vector2(0, -RIVET_RADIUS).rotated(angle)
		# Position follows the wheel, as well as plate orientation.
		draw_set_transform((CENTER + point.rotated(wheel_angle) + Vector2(jitter, 0)) * scale_factor, wheel_angle + angle, scale_factor)
		var hot := clampf((heat - 15) / 85, 0, 1) if stage > 0 else 0.0
		var color := Color("72777a").lerp(Color("ff9c3f"), hot)
		var plate_height: float = 13 - hits[index]
		draw_rect(Rect2(-15, -plate_height / 2, 30, plate_height), Color("231d19"))
		draw_rect(Rect2(-13, -plate_height / 2 + 1, 26, plate_height - 2), color)
		draw_line(Vector2(-10, -plate_height / 2 + 2), Vector2(10, -plate_height / 2 + 2), color.lightened(0.25), 1)
		for bolt in [-8.0, 8.0]:
			draw_circle(Vector2(bolt, 0), 2.4 if hits[index] >= 3 else 3.2, Color("262724"))
			draw_circle(Vector2(bolt, -0.6), 1.7, Color("c3c7b2") if hits[index] >= 3 else color.lightened(0.1))
		if impact_flash > 0 and index == impact_rivet:
			draw_arc(Vector2.ZERO, 17 + (1 - impact_flash) * 13, 0, TAU, 32, Color(1, 0.82, 0.4, impact_flash * 0.7), 1.5)
	draw_set_transform(Vector2.ZERO, 0, scale_factor)
	draw_rect(Rect2(CENTER - Vector2(7, 7), Vector2(14, 14)), Color("4c5154"))
	draw_rect(Rect2(CENTER - Vector2(4, 4), Vector2(8, 8)), Color("b9b6a3"))


func _draw_targets() -> void:
	for index in 4:
		var point := rivet_position(index)
		var color := GREEN if hits[index] >= 3 else GOLD if index == active_rivet else Color("84775b")
		if index == active_rivet:
			draw_arc(point, 20, 0, TAU, 36, Color(color, 0.65 + sin(time * 5) * 0.2), 1.5)
		for dot in 3:
			draw_circle(point + Vector2(-8 + dot * 8, 26), 2.5, GREEN if dot < hits[index] else Color("4d4230"))
	# The hammer stays at the top of the stand; rotate the active plate to it.
	draw_line(CENTER + Vector2(-22, -RIVET_RADIUS - 27), CENTER + Vector2(22, -RIVET_RADIUS - 27), Color(GOLD, 0.7), 1.5)
	draw_line(CENTER + Vector2(0, -RIVET_RADIUS - 27), CENTER + Vector2(0, -RIVET_RADIUS - 20), GOLD, 1.5)


func _draw_pinion() -> void:
	var scale_factor := size / Vector2(771, 323)
	draw_line(PINION_CENTER + Vector2(0, 28), PINION_CENTER + Vector2(0, 89), Color("514330"), 14)
	draw_line(PINION_CENTER + Vector2(-31, 88), PINION_CENTER + Vector2(31, 88), Color("a0804c"), 8)
	draw_set_transform(PINION_CENTER * scale_factor, -wheel_angle * 2, scale_factor)
	draw_texture_rect_region(PINION, Rect2(-44, -44, 88, 88), Rect2(89, 82, 1074, 1074))
	draw_set_transform(Vector2.ZERO, 0, scale_factor)
	draw_rect(Rect2(PINION_CENTER - Vector2(3, 3), Vector2(6, 6)), Color("bcb69d"))


func _draw_labels() -> void:
	_plate(Rect2(14, 12, 198, 27), Color("1b160feb"), Color("715a39"))
	draw_string(font, Vector2(27, 30), "FUELLE Y HOGAR DE CARBÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
	_plate(Rect2(533, 12, 223, 27), Color("1b160feb"), Color("715a39"))
	draw_string(font, Vector2(548, 30), "TALLER DE MATEO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	_plate(Rect2(137, 285, 497, 28), Color("1b170fed"), Color("79603a"))
	var captions := ["AIRE → CARBÓN → HIERRO CALIENTE", "REFUERZOS OPUESTOS · GIRO Y REMACHADO", "EL METAL PIERDE SU BRILLO AL ENFRIARSE", "GIRO LIBRE → TRANSMISIÓN AL PIÑÓN", "✓ RUEDA DENTADA LISTA PARA EL MOLINO"]
	if assembly_visible:
		captions[0] = "CUATRO REFUERZOS ENCAJADOS → DOS ABRAZADERAS FIRMES"
	elif centering_visible:
		captions[3] = "TRES TORNILLOS → EJE CENTRADO Y SIN OSCILACIÓN"
	var width := font.get_string_size(captions[stage], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2((771 - width) / 2, 304), captions[stage], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GREEN if stage == 4 else GOLD)
	if stage == 3 and not centering_visible:
		_plate(Rect2(370, 42, 386, 23), Color("1b170fe8"), Color("79603a"))
		var labels := ["EJE LIBRE", "REFUERZOS FIRMES", "TRANSMISIÓN"]
		for index in 3:
			var x := 381 + index * 122
			draw_string(font, Vector2(x, 58), ("✓ " if proof_checks > index else "○ ") + labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GREEN if proof_checks > index else GOLD)


func draw_ellipse_shadow(center: Vector2, radius: Vector2) -> void:
	var points := PackedVector2Array()
	for step in 40:
		points.append(center + Vector2.from_angle(step * TAU / 40) * radius)
	draw_colored_polygon(points, Color(0.08, 0.05, 0.03, 0.45))


func _plate(rect: Rect2, fill: Color, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	draw_style_box(box, rect)
