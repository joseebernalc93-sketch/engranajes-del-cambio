extends Control
## The workshop stays still; only the working parts respond to the player's actions.

signal hook_selected(index: int)
signal crank_pressed
signal carriage_moved(value: float)

const WHEEL := preload("res://assets/gba/ui/ropewalk_wheel_v2.png")
const CART := preload("res://assets/gba/ui/ropewalk_carriage_v2.png")
const CART_WHEELS := preload("res://shaders/rope_carriage_wheels.gdshader")
const GOLD := Color("e8bd70")
const INK := Color("20170e")
const STRAND_COLORS := [Color("ebcc87"), Color("cea15e"), Color("f4dfa7")]
const HOOKS := [Vector2(182, 89), Vector2(182, 114), Vector2(182, 139)]
const WHEEL_CENTER := Vector2(78, 119)

var stage := 0
var fibers := 0
var mounted: Array[bool] = [false, false, false]
var strand_reveal := [0.0, 0.0, 0.0]
var tension := 0.0
var progress := 0.0
var driving := false
var wheel_angle := 0.0
var wheel_speed := 0.0
var carriage := 28.0
var carriage_target := 28.0
var motion_time := 0.0
var binding := 0.0
var binding_target := 0.0
var warning_flash := 0.0
var dragging_carriage := false
var hovered_hook := -1
var feedback := ""
var feedback_color := GOLD
var feedback_time := 0.0
var active := false
var font: Font
var cart_sprite: Sprite2D
var cart_material: ShaderMaterial
var cart_wheel_angle := 0.0
var carriage_drag_offset := 0.0
var proof_load := 0.0
var proof_checks := 0
var loose_end_flash := 0.0
var difficulty_pace := 1.0
var craft_mode := ""


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	cart_material = ShaderMaterial.new()
	cart_material.shader = CART_WHEELS
	cart_sprite = Sprite2D.new()
	cart_sprite.name = "AnimatedCarriage"
	cart_sprite.texture = CART
	cart_sprite.material = cart_material
	add_child(cart_sprite)
	_update_cart_sprite()
	mouse_exited.connect(func(): hovered_hook = -1)


func reset_machine() -> void:
	stage = 0
	fibers = 0
	mounted = [false, false, false]
	strand_reveal = [0.0, 0.0, 0.0]
	tension = 0.0
	progress = 0.0
	driving = false
	wheel_angle = 0.0
	wheel_speed = 0.0
	carriage = 28.0
	carriage_target = 28.0
	motion_time = 0.0
	binding = 0.0
	binding_target = 0.0
	warning_flash = 0.0
	feedback_time = 0.0
	dragging_carriage = false
	hovered_hook = -1
	cart_wheel_angle = 0.0
	carriage_drag_offset = 0.0
	proof_load = 0.0
	proof_checks = 0
	loose_end_flash = 0.0
	_update_cart_sprite()
	queue_redraw()


func show_feedback(message: String, color := GOLD) -> void:
	feedback = message
	feedback_color = color
	feedback_time = 1.8
	queue_redraw()


func _process(delta: float) -> void:
	if not active or not is_visible_in_tree():
		return
	motion_time += delta
	# Acceleration and friction are independent of frame rate.
	wheel_speed = move_toward(wheel_speed, 3.5 * difficulty_pace if driving else 0.0, delta * (5.5 if driving else 6.0))
	wheel_angle = fposmod(wheel_angle + wheel_speed * delta, TAU)
	var previous_carriage := carriage
	carriage = move_toward(carriage, carriage_target, delta * 80.0)
	cart_wheel_angle += (carriage - previous_carriage) * 1.2 / 14.0
	_update_cart_sprite()
	for index in 3:
		strand_reveal[index] = move_toward(strand_reveal[index], 1.0 if mounted[index] else 0.0, delta * 2.8)
	binding = move_toward(binding, binding_target, delta * 1.5)
	warning_flash = maxf(0.0, warning_flash - delta * 1.8)
	feedback_time = maxf(0.0, feedback_time - delta)
	loose_end_flash = maxf(0.0, loose_end_flash - delta * 0.65)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	var point: Vector2 = event.position * Vector2(771, 323) / size if event is InputEventMouse else get_local_mouse_position() * Vector2(771, 323) / size
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			dragging_carriage = false
		elif stage == 1:
			for index in 3:
				if point.distance_to(HOOKS[index]) < 18.0 and not mounted[index]:
					hook_selected.emit(index)
					accept_event()
		elif stage == 2:
			if point.distance_to(WHEEL_CENTER) < 79.0:
				crank_pressed.emit()
				accept_event()
			elif Rect2(_cart_x() - 60, 84, 134, 111).has_point(point):
				dragging_carriage = true
				carriage_drag_offset = point.x - _cart_x()
				accept_event()
	if event is InputEventMouseMotion:
		hovered_hook = -1
		if stage == 1:
			for index in 3:
				if point.distance_to(HOOKS[index]) < 18.0 and not mounted[index]:
					hovered_hook = index
		if dragging_carriage and stage == 2:
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				carriage_moved.emit(clampf((point.x - carriage_drag_offset - 565.0) / 1.2, 0.0, 100.0))
			else:
				dragging_carriage = false
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_hook >= 0 or (stage == 2 and point.distance_to(WHEEL_CENTER) < 79.0) else Control.CURSOR_ARROW
		if stage == 2 and Rect2(_cart_x() - 60, 84, 134, 111).has_point(point):
			mouse_default_cursor_shape = Control.CURSOR_DRAG


func _cart_x() -> float:
	return 565.0 + carriage * 1.2


func _update_cart_sprite() -> void:
	if not is_instance_valid(cart_sprite):
		return
	var view_scale := size / Vector2(771, 323)
	cart_sprite.position = Vector2(_cart_x() + 5, 137.5) * view_scale
	cart_sprite.scale = Vector2(134, 103) / CART.get_size() * view_scale
	cart_material.set_shader_parameter("travel_angle", cart_wheel_angle)


func _draw() -> void:
	if font == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(771, 323))
	_draw_machine()
	_draw_top_labels()
	if craft_mode != "":
		pass
	elif stage == 0:
		_draw_fibers()
	elif stage == 5:
		_draw_finished_rope()
	elif stage == 4:
		_draw_proof_readout()
	else:
		_draw_work_readout()
	if feedback_time > 0.0 and craft_mode == "":
		var alpha := minf(feedback_time * 3.0, 1.0)
		var width := font.get_string_size(feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 34.0
		var rect := Rect2((771.0 - width) * 0.5, 209, width, 31)
		_plate(rect, Color(0.065, 0.049, 0.024, alpha * 0.96), Color(feedback_color, alpha * 0.6))
		draw_string(font, rect.position + Vector2(17, 21), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(feedback_color, alpha))
	draw_set_transform(Vector2.ZERO)


func _draw_machine() -> void:
	# A separate circular sprite rotates within an elliptical perspective transform.
	draw_set_transform_matrix(get_transform_for_wheel())
	draw_texture_rect(WHEEL, Rect2(-83, -83, 166, 166), false, Color("f0d6ae"))
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(771, 323))
	# The bearing and foot remain stationary in front of the rotating wheel.
	draw_line(WHEEL_CENTER + Vector2(0, 4), Vector2(78, 192), INK, 15)
	draw_line(WHEEL_CENTER + Vector2(-2, 4), Vector2(76, 191), Color("89562d"), 10)
	draw_line(Vector2(72, 140), Vector2(72, 189), Color("ba8646"), 2)
	_plate(Rect2(64, 188, 28, 9), Color("42362a"), Color("8d8060"))
	var handle := WHEEL_CENTER + Vector2(cos(wheel_angle + 2.2) * 36.0, sin(wheel_angle + 2.2) * 43.0)
	draw_line(WHEEL_CENTER, handle, INK, 9)
	draw_line(WHEEL_CENTER, handle, Color("b8884e"), 5)
	draw_circle(WHEEL_CENTER, 6, Color("504a3a"))
	draw_circle(WHEEL_CENTER - Vector2(1, 1), 2.5, Color("c4b38c"))
	draw_line(handle, handle + Vector2(-14, 3), INK, 10)
	draw_line(handle, handle + Vector2(-14, 3), Color("d2a260"), 6)
	for index in 3:
		if strand_reveal[index] > 0.0:
			_draw_strand(index)
		if stage == 1 and not mounted[index]:
			var opacity := 0.62 + sin(motion_time * 3.0 + index) * 0.2
			draw_circle(HOOKS[index], 15, Color(0.10, 0.07, 0.025, 0.85))
			draw_arc(HOOKS[index], 15, 0, TAU, 36, Color(GOLD, opacity), 2.0)
			if hovered_hook == index:
				draw_arc(HOOKS[index], 19, 0, TAU, 36, GOLD, 2.0)
			draw_string(font, HOOKS[index] + Vector2(-4, 5), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
	_draw_twisted_rope()
	var cart_x := _cart_x()
	if stage >= 4:
		_draw_test_load()
	# A small movement indicator makes carriage travel readable against the rails.
	if stage == 2:
		draw_line(Vector2(565, 202), Vector2(685, 202), Color("735938"), 2)
		draw_circle(Vector2(cart_x, 202), 3, GOLD)
		draw_string(font, Vector2(cart_x - 28, 218), "CARRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
	if warning_flash > 0.0:
		draw_rect(Rect2(2, 2, 767, 319), Color(0.95, 0.30, 0.16, warning_flash * 0.12))


func get_transform_for_wheel() -> Transform2D:
	var view := Transform2D(0, size / Vector2(771, 323), 0, Vector2.ZERO)
	var perspective := Transform2D(0, Vector2(0.80, 1.0), 0, WHEEL_CENTER)
	return view * perspective * Transform2D(wheel_angle, Vector2.ZERO)


func _draw_strand(index: int) -> void:
	var start: Vector2 = HOOKS[index]
	var end := Vector2(391, 106 + index * 14)
	var points := PackedVector2Array()
	var sag := lerpf(18.0, 1.0, clampf(tension / 60.0, 0.0, 1.0))
	var amount := int(48.0 * float(strand_reveal[index]))
	for step in amount + 1:
		var portion := float(step) / 48.0
		var point := start.lerp(end, portion)
		point.y += sin(portion * PI) * sag
		if driving:
			point.y += sin(portion * 35.0 - wheel_angle * 4.0 + index) * (1.8 if tension > 70.0 else 0.7) * sin(portion * PI)
		points.append(point)
	if points.size() < 2:
		return
	draw_polyline(points, INK, 5.5)
	draw_polyline(points, STRAND_COLORS[index], 3.0)
	for step in range(1, points.size() - 1, 3):
		var point: Vector2 = points[step]
		draw_line(point + Vector2(-1, -1), point + Vector2(1, 1), Color("8d632f"), 1)


func _draw_twisted_rope() -> void:
	if stage < 2:
		return
	var start := Vector2(448, 127)
	var end := Vector2(_cart_x() + 36, 127)
	var amplitude := lerpf(5.8, 1.8, progress / 100.0)
	var sag := lerpf(20.0, 1.0, clampf(tension / 60.0, 0.0, 1.0))
	var turns := lerpf(5.0, 16.0, progress / 100.0)
	var spine := PackedVector2Array()
	for step in 61:
		var portion := float(step) / 60.0
		var point := start.lerp(end, portion)
		point.y += sin(portion * PI) * sag
		spine.append(point)
	draw_polyline(spine, INK, amplitude * 2.0 + 3.0)
	draw_polyline(spine, Color("9e783e"), amplitude * 2.0 + 1.0)
	for index in 3:
		var points := PackedVector2Array()
		for step in 121:
			var portion := float(step) / 120.0
			var phase := portion * TAU * turns - wheel_angle * 2.0 + index * TAU / 3.0
			var point := start.lerp(end, portion)
			point.y += sin(portion * PI) * sag + sin(phase) * amplitude
			if tension > 70.0 and driving:
				point.y += sin(motion_time * 38.0 + portion * 30.0) * 1.6
			points.append(point)
		draw_polyline(points, STRAND_COLORS[index], 1.8)
	if binding > 0.0:
		for wrap in int(binding * 9):
			var x := _cart_x() - 81.0 + wrap * 2.2
			var portion := clampf((x - start.x) / (end.x - start.x), 0.0, 1.0)
			var y := 127.0 + sin(portion * PI) * sag
			draw_line(Vector2(x, y - 7), Vector2(x + 2, y + 7), INK, 4)
			draw_line(Vector2(x, y - 7), Vector2(x + 2, y + 7), Color("f4df9b"), 2)
	if loose_end_flash > 0.0:
		for index in 3:
			var loose_points := PackedVector2Array()
			for step in 20:
				var amount := float(step) / 19.0
				loose_points.append(Vector2(_cart_x() - 90 + amount * 43, 127 + sin(amount * PI * 0.75) * (index - 1) * 19 * loose_end_flash))
			draw_polyline(loose_points, Color(STRAND_COLORS[index], loose_end_flash), 2)


func _draw_top_labels() -> void:
	var states := ["PREPARAR LAS FIBRAS", "MONTAR LOS TRES CABOS", "MANIVELA DETENIDA", "ASEGURAR LA CUERDA", "PRUEBA DE RESISTENCIA", "CUERDA LISTA"]
	var caption: String = states[stage]
	if craft_mode == "comb":
		caption = "PEINAR Y ALINEAR EL CÁÑAMO"
	elif craft_mode == "bind":
		caption = "AJUSTAR LA LIGADURA"
	var color := GOLD
	if stage == 2 and driving:
		caption = "TORSIÓN EN MARCHA"
		color = Color("bde58c") if tension >= 45.0 and tension <= 70.0 else Color("f2ab70")
	_plate(Rect2(14, 12, 224, 27), Color("19160fe8"), Color("6d5639"))
	draw_circle(Vector2(27, 25), 3, color)
	draw_string(font, Vector2(38, 30), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	_plate(Rect2(597, 12, 160, 27), Color("19160fe8"), Color("6d5639"))
	draw_string(font, Vector2(614, 30), "TALLER DE SILAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)


func _draw_fibers() -> void:
	_plate(Rect2(183, 248, 405, 59), Color("19160fed"), Color("7c633c"))
	for bundle in 3:
		var origin := Vector2(204 + bundle * 126, 262)
		var ready_bundle := bundle < fibers
		var color := GOLD if ready_bundle else Color("554c37")
		for strand in 8:
			var start := origin + Vector2(sin(strand * 3.0) * 4.0, strand * 2)
			draw_line(start, start + Vector2(79 + cos(strand * 5.0) * 7, sin(strand * 2.0) * 2), INK, 3)
			draw_line(start, start + Vector2(79 + cos(strand * 5.0) * 7, sin(strand * 2.0) * 2), color, 1)
		if ready_bundle:
			draw_line(origin + Vector2(40, -2), origin + Vector2(39, 16), Color("bdcf8e"), 3)
		draw_string(font, origin + Vector2(13, 34), "LIMPIO" if ready_bundle else "MANOJO %d" % (bundle + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _draw_work_readout() -> void:
	_plate(Rect2(148, 259, 475, 45), Color("19160fed"), Color("7c633c"))
	var message := "Pulsa los ganchos iluminados o los botones de abajo"
	if stage == 2:
		message = "ESPACIO: girar     /     ← →: mover el carro"
	elif stage == 3:
		message = "Fija el extremo para conservar todo tu trabajo"
	var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2((771.0 - width) * 0.5, 286), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e4d8b7"))


func _draw_finished_rope() -> void:
	_plate(Rect2(159, 246, 453, 65), Color("182017f5"), Color("93ad64"))
	for loop in 4:
		draw_arc(Vector2(202, 278), 12 + loop * 3, 0, TAU, 48, INK, 5)
		draw_arc(Vector2(202, 278), 12 + loop * 3, 0, TAU, 48, STRAND_COLORS[loop % 3], 2.4)
	draw_string(font, Vector2(239, 275), "CUERDA RESISTENTE OBTENIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d9e7a4"))
	draw_string(font, Vector2(239, 297), "Lista para las poleas del molino", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b5bd9b"))


func _draw_test_load() -> void:
	# The locked machine holds a suspended test load; the main wheel stays still.
	var pulley := Vector2(_cart_x() + 63, 127)
	var lift := proof_load * 34.0
	var sway := sin(motion_time * 3.0) * 1.5 * proof_load
	var neck := Vector2(pulley.x + 7 + sway, 202 - lift)
	draw_line(Vector2(_cart_x() + 28, 127), pulley, INK, 5)
	draw_line(Vector2(_cart_x() + 28, 127), pulley, GOLD, 2.5)
	draw_circle(pulley, 9, INK)
	draw_arc(pulley, 7, 0, TAU, 24, Color("a48b57"), 3)
	draw_circle(pulley, 2, Color("e7d6a1"))
	draw_line(pulley + Vector2(7, 0), neck, INK, 4)
	draw_line(pulley + Vector2(7, 0), neck, Color("e3c886"), 2)
	# Burlap sack with a tied neck, shaded folds, seam and a floor shadow.
	draw_set_transform(Vector2(pulley.x + 7, 246) * size / Vector2(771, 323), 0, size / Vector2(771, 323) * Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 21 - proof_load * 3, Color(0.035, 0.025, 0.012, 0.45 - proof_load * 0.16))
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(771, 323))
	var bag := PackedVector2Array([neck + Vector2(-5, 0), neck + Vector2(-11, 10), neck + Vector2(-20, 20), neck + Vector2(-18, 38), neck + Vector2(-11, 43), neck + Vector2(13, 43), neck + Vector2(21, 37), neck + Vector2(19, 19), neck + Vector2(9, 9), neck + Vector2(5, 0)])
	draw_colored_polygon(bag, Color("aa8650"))
	var outline := bag.duplicate()
	outline.append(bag[0])
	draw_polyline(outline, INK, 2.5)
	draw_colored_polygon(PackedVector2Array([neck + Vector2(5, 9), neck + Vector2(17, 22), neck + Vector2(17, 35), neck + Vector2(10, 40), neck + Vector2(5, 38)]), Color("77562f"))
	for fold in 4:
		var start := neck + Vector2(-12 + fold * 6, 19)
		draw_line(start, start + Vector2(-2 + fold, 17), Color("c9a873"), 1)
	draw_line(neck + Vector2(-6, 3), neck + Vector2(6, 3), INK, 5)
	draw_line(neck + Vector2(-6, 3), neck + Vector2(6, 3), Color("e2c887"), 2)


func _draw_proof_readout() -> void:
	_plate(Rect2(122, 256, 527, 48), Color("191b12ed"), Color("7c633c"))
	var labels := ["REMATE FIRME", "CARGA REPARTIDA", "CUERDA PROBADA"]
	for index in 3:
		var x := 142.0 + index * 169.0
		var passed := index < proof_checks
		var color := Color("b9db87") if passed else Color("9e9376")
		draw_circle(Vector2(x, 279), 7, Color("262a1a"))
		draw_arc(Vector2(x, 279), 7, 0, TAU, 24, color, 1)
		if passed:
			draw_polyline(PackedVector2Array([Vector2(x - 3, 279), Vector2(x - 1, 282), Vector2(x + 4, 276)]), color, 1.5)
		draw_string(font, Vector2(x + 13, 283), labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _plate(rect: Rect2, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	draw_style_box(style, rect)
