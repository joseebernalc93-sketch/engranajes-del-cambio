extends Control
signal worked
const Model := preload("res://scripts/core/foundry_workshop.gd")
const Art := preload("res://scripts/world/foundry_workshop_art.gd")
const NATIVE := Vector2(1152, 648)
const GOLD := Color("f2ce89")
const HOT := Color(2.0, 0.78, 0.28)
const GAUGE := Rect2(410, 190, 330, 170)
const TEMPLATE := Rect2(620, 245, 440, 185)
const DRILL_AXIS := Vector2(575, 418)
const STOCK_EYES := [Vector2(39.0 / 374, 64.0 / 139), Vector2(311.0 / 374, 43.0 / 139)]
const LINK_EYES := [Vector2(39.0 / 376, 65.0 / 139), Vector2(312.0 / 376, 54.0 / 139)]
const FLYWHEEL := Vector2(790, 315)
var model: Model
var paused := false
var selected := 0
var drag := ""
var drag_index := -1
var pointer := Vector2.ZERO
var origin := Vector2.ZERO
var stroke_point := Vector2.ZERO
var touch_id := -1
var clock := 0.0
var held_key: Key = KEY_NONE
var lever_fired := false
var lever_pull := 0.0
var last_angle := 0.0
var stroke_armed := true
var hover_hint := ""
var spindle_angle := 0.0
var spindle_speed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func configure(value: Model, saved: Dictionary = {}) -> void:
	model = value
	selected = clampi(int(saved.get("selected", 0)), 0, 2)
	cancel_drag()
	queue_redraw()

func snapshot() -> Dictionary:
	return {"selected": selected}

func cancel_drag() -> void:
	drag = ""
	drag_index = -1
	touch_id = -1
	held_key = KEY_NONE
	lever_pull = 0.0
	lever_fired = false
	if model != null: model.stop_tools()
	queue_redraw()

func advance(delta: float) -> void:
	clock += delta
	spindle_speed = move_toward(spindle_speed, 16.0 if model != null and model.feed_held else 0.0, delta * 25)
	spindle_angle += spindle_speed * delta
	if held_key != KEY_NONE and model != null and model.allowed():
		match model.step():
			0:
				if held_key == KEY_Q: model.tighten(0, delta * 0.75)
				if held_key == KEY_E: model.tighten(1, delta * 0.75)
			1:
				if held_key in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
					model.move_heat(float(model.data.heat_position) + delta * (-0.4 if held_key in [KEY_LEFT, KEY_A] else 0.4))
	if drag == "clamp": model.tighten(drag_index, delta * 0.65)
	queue_redraw()

func sync() -> void:
	queue_redraw()

func _fit(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var dimensions := texture.get_size() * minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	draw_texture_rect(texture, Rect2(rect.get_center() - dimensions / 2, dimensions), false, tint)

func _part(index: int, rect: Rect2, machine: bool = false, tint: Color = Color.WHITE) -> void:
	_fit(Art.part(index, machine), rect, tint)

func _tool(index: int, rect: Rect2) -> void:
	_fit(Art.tool(index), rect)

func _text(at: Vector2, words: String, color: Color = GOLD, height: int = 21) -> void:
	draw_string(ThemeDB.fallback_font, at + Vector2(1, 2), words, HORIZONTAL_ALIGNMENT_LEFT, -1, height, Color("0b0906"))
	draw_string(ThemeDB.fallback_font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, height, color)

func _selected(rect: Rect2, active: bool) -> void:
	if active: draw_style_box(_outline(), rect.grow(5))

func _outline() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("30241680")
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

static func billet_rect(index: int) -> Rect2:
	return Rect2(110 + index * 325, 490, 280, 130)

static func die_rect(index: int) -> Rect2:
	return Rect2(230 + index * 230, 530, 170, 100)

func piece_rect() -> Rect2:
	return Rect2(120, 300, 440, 170)

func drill_center() -> Vector2:
	return drill_stock_rect().get_center()

func drill_stock_rect() -> Rect2:
	var texture := Art.part(5)
	var dimensions := texture.get_size() * minf(440.0 / texture.get_width(), 125.0 / texture.get_height())
	var anchor: Vector2 = STOCK_EYES[0].lerp(STOCK_EYES[1], float(model.data.position) / 4)
	return Rect2(DRILL_AXIS - anchor * dimensions, dimensions)

func drill_eyes() -> Array[Vector2]:
	var rect := drill_stock_rect()
	return [rect.position + STOCK_EYES[0] * rect.size, rect.position + STOCK_EYES[1] * rect.size]

func drill_tip() -> Vector2:
	var eye := 0 if int(model.data.position) < 2 else 1
	return Vector2(DRILL_AXIS.x, lerpf(348, DRILL_AXIS.y + float(model.data.depths[eye]) * 12, minf(float(model.data.feed) / 0.2, 1)))

func _native_transform() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)

func _screen_vector(vector: Vector2) -> Vector2:
	return vector * size / NATIVE

func _wheel_vector(at: Vector2) -> Vector2:
	return _screen_vector(at - FLYWHEEL) / (size.x / NATIVE.x)

func crank_point(angle: float, radius: float = 100.0) -> Vector2:
	return FLYWHEEL + Vector2.from_angle(angle) * radius * Vector2.ONE * size.x / NATIVE.x / (size / NATIVE)

func billet_on_bench() -> Rect2:
	var index := maxi(0, int(model.data.billet))
	return Rect2(420, 230, 210 if index == 0 else 320, 70 if index == 2 else 110)

func ruler_rect() -> Rect2:
	return Rect2(420, 440 - float(model.data.ruler) * 200, 320, 38)

func caliper_rect() -> Rect2:
	return Rect2(600, 180, 175, 200)

func clamp_center(index: int) -> Vector2:
	return Vector2(345 + index * 480, 385)

func _plate(rect: Rect2, color: Color = Color("312a22")) -> void:
	draw_rect(rect.grow(4), Color("100e0b"))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), color.lightened(0.4))
	draw_rect(Rect2(rect.end - Vector2(rect.size.x, 4), Vector2(rect.size.x, 4)), color.darkened(0.45))
	for at in [rect.position + Vector2(8, 8), rect.position + Vector2(rect.size.x - 8, 8), rect.end - Vector2(8, 8), rect.position + Vector2(8, rect.size.y - 8)]:
		draw_circle(at, 4, Color("161716"))
		draw_line(at - Vector2(2, 0), at + Vector2(2, 0), Color("9c9b89"), 1)

func _handle(center: Vector2, angle: float, radius: float = 37.0, active: bool = false) -> void:
	if active: draw_arc(center, radius + 7, -0.3, PI * 1.5, 24, Color("f2ce8980"), 2)
	draw_set_transform(center * size / NATIVE, angle + PI / 2, size / NATIVE)
	_tool(4, Rect2(-radius * 0.40, -radius, radius * 0.8, radius * 2))
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)

func _badge(at: Vector2, text: String, good: bool = false) -> void:
	var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 22
	draw_set_transform(_screen_vector(at), 0, Vector2.ONE * size.x / NATIVE.x)
	draw_style_box(_panel_style(), Rect2(-8, -24, width, 32))
	_text(Vector2.ZERO, text, Color("b9df89") if good else GOLD, 17)
	_native_transform()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151b19f5")
	style.border_color = Color("a47b45")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color("080b0bb0")
	style.shadow_size = 4
	return style

func _heat_color(value: float) -> Color:
	if value < 0.35: return Color("595e62").lerp(Color("ba3e27"), value / 0.35)
	if value < 0.7: return Color("ba3e27").lerp(Color("ff922c"), (value - 0.35) / 0.35)
	return Color("ff922c").lerp(Color("ffe3a0"), clampf((value - 0.7) / 0.4, 0, 1))

func _ruler(rect: Rect2) -> void:
	draw_texture_rect(Art.tool(3), rect, false)
	for tick in 7:
		var x := rect.position.x + tick / 6.0 * (rect.size.x - 24) + 8
		_text(Vector2(x, rect.end.y - 5), str(tick * 20), Color("271a10"), 12)

func _draw_measuring() -> void:
	draw_texture_rect(Art.tool(7), Rect2(55, 150, 250, 195), false)
	_text(Vector2(78, 177), "PEDIDO DE CORT", Color("362818"), 18)
	_text(Vector2(78, 328), "Largo 120 · Grosor 30", Color("362818"), 17)
	_part(10, Rect2(385, 205, 405, 205))
	if bool(model.data.billet_placed): _part(int(model.data.billet), billet_on_bench())
	for index in 2:
		var center := clamp_center(index)
		var squeeze := float(model.data.clamps[index])
		draw_set_transform(center * size / NATIVE, 0, size / NATIVE * Vector2(-1 if index == 0 else 1, 1))
		_tool(0, Rect2(-150 + squeeze * 7, -77, 160, 140))
		draw_set_transform(Vector2.ZERO, 0, size / NATIVE)
		_handle(center, squeeze * TAU * 2 - PI / 2, 35, drag == "clamp" and drag_index == index)
		_badge(center + Vector2(-35, 70), "Fija" if squeeze >= 0.95 else "Girar", squeeze >= 0.95)
	_ruler(ruler_rect())
	# A sliding jaw physically closes onto the placed bar's thickness.
	var jaw_y := 230 + float(model.data.caliper) * 85
	_tool(1, Rect2(605, 185, 155, 220))
	_tool(2, Rect2(605, jaw_y - 14, 155, 48))
	for index in 3:
		var rect := billet_rect(index)
		_selected(rect, selected == index)
		if not (bool(model.data.billet_placed) and int(model.data.billet) == index) and not (drag == "billet" and drag_index == index): _part(index, rect)
	for index in 2:
		_badge(Vector2(940, 200 + index * 48), ("Largo" if index == 0 else "Grosor") + (" ✓" if bool(model.data.measured[index]) else " · medir"), bool(model.data.measured[index]))

func _draw_heating() -> void:
	var center := Vector2(420 + (float(model.data.heat_position) - 0.5) * 230, 330)
	if not bool(model.data.heating): center = Vector2(420, 450)
	var bar := Rect2(center - Vector2(200, 45), Vector2(400, 90))
	var texture := Art.part(1)
	var dimensions := texture.get_size() * minf(bar.size.x / texture.get_width(), bar.size.y / texture.get_height())
	# Both jaws share the bar's moving contact point. Upper jaw passes behind iron.
	var grip := center + dimensions * Vector2(0.45, -0.20)
	_draw_tongs_jaw(grip, false)
	for index in 3:
		var source := Rect2(Vector2(index * texture.get_width() / 3.0, 0), Vector2(texture.get_width() / 3.0, texture.get_height()))
		var heat := float(model.data.heat_zones[index])
		var tint := Color.WHITE.lerp(Color(2.7, 1.0, 0.3), clampf(heat / 0.7, 0, 1))
		if heat > 0.9: tint = tint.lerp(Color(3.0, 2.5, 1.4), (heat - 0.9) / 0.2)
		draw_texture_rect_region(texture, Rect2(bar.get_center() - dimensions / 2 + Vector2(index * dimensions.x / 3, 0), Vector2(dimensions.x / 3, dimensions.y)), source, tint)
	_draw_tongs_jaw(grip, true)
	var pivot := Vector2(945, 320)
	# Compensate for the board's wide aspect before rotation; the wheel stays round.
	var uniform := Vector2.ONE * size.x / NATIVE.x
	draw_set_transform(pivot * size / NATIVE, float(model.data.air) * TAU * 0.8, uniform)
	draw_texture_rect(Art.part(4, true), Rect2(-88, -88, 176, 176), false)
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)
	if bool(model.data.heating):
		for index in 12:
			var phase := fposmod(clock * (0.8 + float(model.data.air)) + index * 0.19, 1)
			var at := Vector2(225 + index * 33, 385 - phase * (100 + float(model.data.air) * 110))
			draw_circle(at, 2 + (1 - phase) * 3, Color(1, 0.46 + index % 3 * 0.12, 0.08, (1 - phase) * 0.7))
	_badge(Vector2(877, 455), "Aire · %d%%" % roundi(float(model.data.air) * 100))
	_draw_heat_instruments()

func _draw_tongs_jaw(grip: Vector2, lower: bool) -> void:
	var texture := Art.part(9)
	var factor := 300.0 / texture.get_width()
	var dimensions := texture.get_size() * factor
	var pivot := grip + Vector2(dimensions.x * 0.23, 0)
	var half := texture.get_height() * 0.5
	var offset := half if lower else 0.0
	var destination := Rect2(Vector2(-dimensions.x * 0.28, 0 if lower else -dimensions.y * 0.5), Vector2(dimensions.x, dimensions.y * 0.5))
	draw_set_transform(pivot * size / NATIVE, 0.065 if lower else -0.065, size / NATIVE)
	draw_texture_rect_region(texture, destination, Rect2(0, offset, texture.get_width(), half))
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)

func _draw_heat_instruments() -> void:
	var low := 0.65 if model.easy else 0.72
	var high := 0.94 if model.easy else 0.89
	var uniform := Vector2.ONE * size.x / NATIVE.x
	for index in 3:
		var value := float(model.data.heat_zones[index])
		var ready := value >= low and value <= high
		var color := Color("c4dd95") if ready else Color("ffbf76") if value > high else Color("c7bca4")
		draw_set_transform(Vector2(148 + index * 222, 524) * size / NATIVE, 0, uniform)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("151b19f5")
		style.border_color = Color("a47b45")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.shadow_color = Color("080b0bb0")
		style.shadow_size = 4
		draw_style_box(style, Rect2(0, 0, 208, 78))
		draw_line(Vector2(14, 2), Vector2(194, 2), Color("e4bb7270"), 1)
		_text(Vector2(14, 21), ["EXTREMO IZQUIERDO", "CENTRO", "EXTREMO DERECHO"][index], Color("d6bf95"), 12)
		var track := Rect2(14, 31, 180, 12)
		draw_rect(track.grow(1), Color("050b0a"))
		for segment in 45:
			var heat := segment / 44.0 * 1.1
			draw_rect(Rect2(14 + segment * 4, 31, 4, 12), _heat_color(heat).darkened(0.1 if heat <= value else 0.65))
		draw_rect(Rect2(14 + low / 1.1 * 180, 29, (high - low) / 1.1 * 180, 16), Color("d1daa680"), false, 1)
		var marker := 14 + clampf(value / 1.1, 0, 1) * 180
		draw_line(Vector2(marker, 30), Vector2(marker, 44), Color("fff2cf"), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(marker - 3, 25), Vector2(marker + 3, 25), Vector2(marker, 29)]), Color("fff2cf"))
		_text(Vector2(14, 65), "✓ En punto" if ready else "Baja el aire" if value > high else "Calentando" if bool(model.data.heating) else "Por calentar", color, 14)
		if ready: draw_line(Vector2(185, 58), Vector2(190, 63), color, 2)
		if ready: draw_line(Vector2(190, 63), Vector2(198, 54), color, 2)
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)

func air_wheel_angle(at: Vector2) -> float:
	return ((at - Vector2(945, 320)) * size / NATIVE).angle()

func air_wheel_hit(at: Vector2) -> bool:
	return ((at - Vector2(945, 320)) * size / NATIVE).length() < 100 * size.x / NATIVE.x

func mechanism_eyes() -> Array[Vector2]:
	var angle := float(model.data.angle)
	# Solve in equal screen units; rotation must not inherit the stretched backdrop.
	var crank := Vector2.from_angle(angle) * 62
	var slider := Vector2(crank.x - sqrt(260 * 260 - crank.y * crank.y), 0)
	var to_native := Vector2.ONE * size.x / NATIVE.x / (size / NATIVE)
	return [FLYWHEEL + slider * to_native, FLYWHEEL + crank * to_native]

func _draw_drilling() -> void:
	var rect := drill_stock_rect()
	var eyes := drill_eyes()
	# The driving pulley turns with the same spindle, in a uniform screen basis.
	var drive := Vector2(890, 215)
	draw_set_transform(_screen_vector(drive) + Vector2(3, 4), 0, Vector2.ONE * size.x / NATIVE.x)
	draw_circle(Vector2.ZERO, 111, Color("100d0bd0"))
	draw_set_transform(_screen_vector(drive), spindle_angle * 0.35, Vector2.ONE * size.x / NATIVE.x)
	draw_texture_rect(Art.part(4, true), Rect2(-106, -106, 212, 212), false)
	_native_transform()
	_part(5, rect)
	for index in 2:
		var depth := float(model.data.depths[index])
		if depth > 0: _draw_bore(eyes[index], (13 if index == 0 else 26) * minf(1, depth * 3), depth)
		if not bool(model.data.holes[index]):
			var aligned := int(model.data.position) == index * 4
			var color := Color("c4dd95") if aligned else Color("c5b69590")
			for sign_value in [-1, 1]:
				draw_line(eyes[index] + Vector2(sign_value * 18, 0), eyes[index] + Vector2(sign_value * 28, 0), color, 1, true)
				draw_line(eyes[index] + Vector2(0, sign_value * 13), eyes[index] + Vector2(0, sign_value * 20), color, 1, true)
	var tip := drill_tip()
	if bool(model.data.bit_mounted):
		var chuck_y := tip.y - 124
		# An extending quill physically joins the original spindle to the chuck.
		var background: Texture2D = Art.BACKGROUNDS[3]
		var source_ratio := background.get_size() / NATIVE
		draw_texture_rect_region(background, Rect2(DRILL_AXIS.x - 23, 184, 46, chuck_y - 174), Rect2(Vector2(552, 184) * source_ratio, Vector2(46, 22) * source_ratio))
		draw_line(Vector2(DRILL_AXIS.x - 20, 184), Vector2(DRILL_AXIS.x - 20, chuck_y + 10), Color("d2b279"), 2)
		var bit := Art.part(2 + int(model.data.bit), true)
		var dimensions := bit.get_size() * (124.0 / bit.get_height())
		draw_texture_rect(bit, Rect2(Vector2(DRILL_AXIS.x - dimensions.x / 2, chuck_y), dimensions), false)
		# Moving specular bands and helical flutes rotate around the vertical axis.
		var shaft_y := chuck_y + 72
		var radius := 4.5 if int(model.data.bit) == 0 else 8.0
		for flute in 2:
			var points := PackedVector2Array()
			for sample in 32:
				var y := sample / 31.0 * 46
				points.append(Vector2(DRILL_AXIS.x + sin(y * 0.25 + spindle_angle + flute * PI) * radius, shaft_y + y))
			draw_polyline(points, Color("e8e4cfb0") if flute == 0 else Color("211f1cd0"), 1.5, true)
		var glint := sin(spindle_angle) * 13
		draw_line(Vector2(DRILL_AXIS.x + glint, chuck_y + 12), Vector2(DRILL_AXIS.x + glint, chuck_y + 39), Color("fff3cc60"), 2, true)
		var cutting := model.feed_held and tip.y >= DRILL_AXIS.y - 2
		if cutting: _draw_cuttings(DRILL_AXIS, radius)
		elif spindle_speed > 1:
			draw_arc(Vector2(DRILL_AXIS.x, chuck_y + 26), 23, spindle_angle, spindle_angle + 1.0, 20, Color("dfdab343"), 1, true)
	else:
		draw_arc(Vector2(DRILL_AXIS.x, 235), 20, 0, PI, 16, Color("dfbd8190"), 2, true)
		_badge(Vector2(490, 290), "Acopla la broca aquí")
	if not model.feed_held:
		draw_dashed_line(Vector2(DRILL_AXIS.x, tip.y + 8), DRILL_AXIS - Vector2(0, 23), Color("d8c28b80"), 1, 5, true)
	for index in 2:
		var clamp := eyes[index] + Vector2(-5, 67)
		_plate(Rect2(clamp - Vector2(30, 12), Vector2(60, 34)), Color("575d5a"))
		_handle(clamp + Vector2(0, 25), -PI / 2 + (1.5 if bool(model.data.drill_clamped) else 0), 22)
	_ruler(Rect2(290, 535, 455, 32))
	_handle(Vector2(780, 550), float(model.data.position) * 1.7, 36, drag == "feed_screw")
	draw_set_transform(_screen_vector(Vector2(735, 230)), -0.7 + float(model.data.feed) * 1.4, Vector2.ONE * size.x / NATIVE.x)
	_tool(5, Rect2(-18, -105, 105, 125))
	_native_transform()
	for index in 2:
		_draw_bit_tray(index)
	_draw_drill_instruments()

func _draw_bore(at: Vector2, radius: float, depth: float) -> void:
	draw_set_transform(_screen_vector(at), 0, size / NATIVE * Vector2(1, 0.7))
	draw_circle(Vector2.ZERO, radius + 2, Color("bcbcb0"))
	draw_circle(Vector2(0, 1), radius, Color("171918"))
	draw_arc(Vector2.ZERO, radius - 1, PI, TAU, 24, Color("060808"), 3, true)
	draw_arc(Vector2.ZERO, radius + 1, 0.05, PI - 0.05, 24, Color("e2d8bd"), 1, true)
	if depth < 0.95: draw_circle(Vector2(0, radius * 0.2), radius * 0.65, Color("42433d").darkened(depth * 0.6))
	_native_transform()

func _draw_cuttings(at: Vector2, radius: float) -> void:
	for chip in 26:
		var phase := fposmod(clock * 1.7 + chip * 0.137, 1)
		var side := -1.0 if chip % 2 == 0 else 1.0
		var position := at + Vector2(side * (radius + phase * (35 + chip % 6 * 8)), -sin(phase * PI) * (12 + chip % 5 * 6) + phase * phase * 29)
		var curl := PackedVector2Array()
		for point in 8:
			var angle := point * 0.7 + chip
			curl.append(position + Vector2(cos(angle), sin(angle) * 0.65) * (1 + point * 0.35))
		draw_polyline(curl, Color(0.85, 0.83, 0.73, (1 - phase) * 0.9), 1.2, true)
	for ring in 2:
		draw_arc(at, radius + 3 + ring * 4, spindle_angle + ring * PI, spindle_angle + ring * PI + 1.3, 18, Color("e3d4ad70"), 1, true)

func _draw_bit_tray(index: int) -> void:
	var at := Vector2(840 + index * 120, 500)
	draw_set_transform(_screen_vector(at), 0, Vector2.ONE * size.x / NATIVE.x)
	draw_style_box(_panel_style(), Rect2(0, 0, 108, 96))
	var active := int(model.data.bit) == index and bool(model.data.bit_mounted)
	if active: draw_line(Vector2(12, 2), Vector2(96, 2), GOLD, 2)
	_fit(Art.part(2 + index, true), Rect2(30, 6, 48, 62), Color("ffffff60") if active else Color.WHITE)
	_text(Vector2(12, 86), ("✓ " if active else "") + ("Fina · 1" if index == 0 else "Gruesa · 2"), GOLD if active else Color("c7bca4"), 13)
	_native_transform()

func _draw_drill_instruments() -> void:
	draw_set_transform(_screen_vector(Vector2(55, 64)), 0, Vector2.ONE * size.x / NATIVE.x)
	draw_style_box(_panel_style(), Rect2(0, 0, 270, 113))
	_text(Vector2(14, 22), "TALADRO DE TRANSMISIÓN", Color("d6bf95"), 13)
	for index in 2:
		var depth := float(model.data.depths[index])
		var y := 48 + index * 33
		_text(Vector2(14, y), "Ojo pequeño" if index == 0 else "Ojo grande", Color("c7bca4"), 13)
		draw_style_box(_outline(), Rect2(112, y - 11, 114, 8))
		draw_rect(Rect2(113, y - 10, 112 * depth, 6), Color("b9cf95") if bool(model.data.holes[index]) else Color("d2ac6c"))
		_text(Vector2(235, y), "✓" if bool(model.data.holes[index]) else "%d" % roundi(depth * 100), GOLD, 13)
	_text(Vector2(14, 103), "✓ Mordazas fijas" if bool(model.data.drill_clamped) else "Fija las mordazas · C", Color("b9cf95") if bool(model.data.drill_clamped) else GOLD, 13)
	_native_transform()
	if float(model.data.chatter) > 0.05: _badge(Vector2(358, 105), "Vibra: suelta la palanca")
	elif int(model.data.position) in [0, 4]: _badge(Vector2(358, 105), "Eje centrado", true)

func _draw_transmission() -> void:
	var eyes := mechanism_eyes()
	var uniform := Vector2.ONE * size.x / NATIVE.x
	_part(6, Rect2(190, 410, 720, 145), true)
	# Piston and slider share the exact height of the two articulated eye centres.
	draw_set_transform(_screen_vector(Vector2(340, 315)), 0, uniform)
	_fit(Art.part(5, true), Rect2(-125, -52, 250, 104))
	_native_transform()
	# A continuous polished rod reaches the sliding pin; atlas padding cannot leave a gap.
	draw_set_transform(_screen_vector(Vector2(410, 315)), 0, uniform)
	var rod_length := eyes[0].x - 410
	for strip in 9:
		var light := 0.26 + 0.62 * sin((strip + 1) / 10.0 * PI)
		draw_rect(Rect2(0, strip * 2 - 9, rod_length, 2), Color(light, light * 0.98, light * 0.9))
	draw_line(Vector2(0, -9), Vector2(rod_length, -9), Color("cbbd9e"), 1)
	_native_transform()
	_plate(Rect2(eyes[0] - Vector2(22, 33), Vector2(44, 66)), Color("6a6e64"))
	draw_set_transform(_screen_vector(FLYWHEEL) + Vector2(5, 5), 0, uniform)
	draw_circle(Vector2.ZERO, 123, Color("100d0bc0"))
	draw_set_transform(_screen_vector(FLYWHEEL), float(model.data.angle), uniform)
	draw_texture_rect(Art.part(4, true), Rect2(-120, -120, 240, 240), false)
	_native_transform()
	if bool(model.data.link):
		var link := Art.part(6)
		var left: Vector2 = LINK_EYES[0] * link.get_size()
		var right: Vector2 = LINK_EYES[1] * link.get_size()
		var direction := _screen_vector(eyes[1] - eyes[0])
		var natural := right - left
		var factor := direction.length() / natural.length()
		draw_set_transform(_screen_vector(eyes[0]) + Vector2(2, 4), direction.angle() - natural.angle(), Vector2.ONE * factor)
		draw_texture_rect(link, Rect2(-left, link.get_size()), false, Color("080a09a0"))
		draw_set_transform(_screen_vector(eyes[0]), direction.angle() - natural.angle(), Vector2.ONE * factor)
		draw_texture_rect(link, Rect2(-left, link.get_size()), false)
		_native_transform()
		for index in 2:
			_draw_joint(eyes[index], int(model.data.pins[index]), index)
	var crank_tip := FLYWHEEL + Vector2.from_angle(float(model.data.angle)) * 94 * uniform / (size / NATIVE)
	draw_set_transform(_screen_vector(crank_tip), 0, uniform)
	draw_circle(Vector2(3, 5), 13, Color("100e0bbb"))
	draw_circle(Vector2.ZERO, 12, Color("57402a"))
	draw_circle(Vector2(-1, -2), 10, Color("c38e46"))
	draw_arc(Vector2(-1, -2), 8, PI, TAU, 20, GOLD, 2, true)
	draw_circle(Vector2(-2, -2), 6, Color("29221d"))
	draw_line(Vector2(-5, -3), Vector2(2, -3), Color("c7aa75"), 2)
	_native_transform()
	_draw_transmission_dial(Vector2(65, 45), "RECORRIDO", float(model.data.turns), 3)
	_draw_transmission_dial(Vector2(305, 45), "CON CARGA", float(model.data.loaded_turns), 1)
	_draw_brake_control()
	_draw_transmission_tray()

func _draw_joint(at: Vector2, pin: int, eye: int) -> void:
	var radius := 12.0 if eye == 0 else 22.0
	draw_set_transform(_screen_vector(at), 0, Vector2.ONE * size.x / NATIVE.x)
	if pin < 0:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color("c7b78390"), 1.5, true)
	else:
		radius = 12 if pin == 0 else 21
		draw_circle(Vector2(2, 3), radius + 2, Color("14110dd0"))
		draw_circle(Vector2.ZERO, radius, Color("6b4b23"))
		draw_texture_rect(Art.pin_cap(pin), Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2), false)
		draw_arc(Vector2.ZERO, radius - 2, PI * 1.05, TAU, 40, Color("f4d58c"), 2, true)
		draw_arc(Vector2.ZERO, radius - 2, 0, PI, 40, Color("815c27"), 2, true)
	_native_transform()

func _draw_transmission_dial(at: Vector2, caption: String, value: float, total: float) -> void:
	draw_set_transform(_screen_vector(at), 0, Vector2.ONE * size.x / NATIVE.x)
	draw_style_box(_panel_style(), Rect2(0, 0, 222, 114))
	_text(Vector2(14, 22), caption, Color("d6bf95"), 13)
	var center := Vector2(55, 75)
	draw_circle(center, 33, Color("292720"))
	draw_arc(center, 31, 0, TAU, 64, Color("a4824f"), 2, true)
	draw_arc(center, 25, PI * 0.8, PI * 2.2, 60, Color("474a3d"), 4, true)
	var progress := clampf(value / total, 0, 1)
	if progress > 0: draw_arc(center, 25, PI * 0.8, PI * (0.8 + progress * 1.4), 60, Color("bdce91") if progress >= 1 else Color("e4bd74"), 4, true)
	for tick in 9:
		var ray := Vector2.from_angle(PI * (0.8 + tick / 8.0 * 1.4))
		draw_line(center + ray * 18, center + ray * 21, Color("c7b999"), 1, true)
	var needle := Vector2.from_angle(PI * (0.8 + progress * 1.4))
	draw_line(center, center + needle * 20, Color("f5e5b9"), 2, true)
	draw_circle(center, 3, Color("d7ad67"))
	_text(Vector2(101, 65), "%.1f / %d" % [value, int(total)], GOLD, 23)
	_text(Vector2(102, 87), "✓ Comprobado" if progress >= 1 else "vueltas", Color("c3d894") if progress >= 1 else Color("c7bca4"), 13)
	_native_transform()

func _draw_brake_control() -> void:
	draw_set_transform(_screen_vector(Vector2(935, 300)), 0, Vector2.ONE * size.x / NATIVE.x)
	draw_style_box(_panel_style(), Rect2(0, 0, 150, 207))
	_text(Vector2(13, 22), "FRENO DE PRUEBA", Color("d6bf95"), 12)
	var brake := float(model.data.brake)
	draw_rect(Rect2(49, 65, 16, 85), Color("070d0b"))
	draw_rect(Rect2(51, 150 - 0.65 * 80, 12, 0.45 * 80), Color("a2b87570"))
	for tick in 6:
		var y := 150 - tick * 16
		draw_line(Vector2(74, y), Vector2(83, y), Color("b8a17a"), 1)
		_text(Vector2(89, y + 4), str(tick * 20), Color("b8a17a"), 10)
	var knob_y := 150 - brake * 80
	draw_style_box(_outline(), Rect2(29, knob_y - 10, 54, 21))
	draw_rect(Rect2(32, knob_y - 7, 48, 14), Color("77542d"))
	for line in 3: draw_line(Vector2(38, knob_y - 4 + line * 4), Vector2(74, knob_y - 4 + line * 4), Color("c49c60"), 1)
	_text(Vector2(16, 177), "%d%% · Arrastra" % roundi(brake * 100), GOLD, 14)
	_text(Vector2(16, 196), "Afloja el freno" if brake > (0.85 if model.easy else 0.72) else "Carga suave" if brake >= 0.2 else "Giro libre", Color("f2ba82") if brake > 0.72 else Color("c3d894"), 12)
	_native_transform()

func _draw_transmission_tray() -> void:
	for index in 3:
		var at := Vector2(80 if index == 0 else 595 + (index - 1) * 170, 520)
		var width := 400.0 if index == 0 else 140.0
		draw_set_transform(_screen_vector(at), 0, Vector2.ONE * size.x / NATIVE.x)
		draw_style_box(_panel_style(), Rect2(0, 0, width, 85))
		var installed: bool = bool(model.data.link) if index == 0 else index - 1 in model.data.pins
		var held := drag == "link" if index == 0 else drag == "pin" and drag_index == index - 1
		if not held:
			var texture := Art.part(6) if index == 0 else Art.part(6 + index, true)
			_fit(texture, Rect2(18, 7, width - 36, 49), Color("ffffff30") if installed else Color.WHITE)
		_text(Vector2(14, 74), ("✓ " if installed else "") + ["Biela · Arrastra al mecanismo", "Pasador pequeño", "Pasador grande"][index], Color("c3d894") if installed else GOLD, 12)
		_native_transform()

func _draw() -> void:
	if model == null: return
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)
	var step := model.step()
	var background: Texture2D = Art.BACKGROUNDS[[0, 1, 2, 3, 0, 0][step]]
	draw_texture_rect(background, Rect2(Vector2.ZERO, NATIVE), false)
	match step:
		0: _draw_measuring()
		1: _draw_heating()
		2:
			var zone := int(model.data.zone)
			var impact := sin(clampf(float(model.data.impact_age) / 0.55, 0, 1) * PI)
			if bool(model.data.die_mounted): _part(int(model.data.die) + 9, Rect2(495, 390, 180, 90), true)
			else: _selected(Rect2(495, 390, 180, 90), true)
			# Each zone morphs separately. No holes exist before the drill stage.
			var blank := Rect2(365 + (1 - zone) * 155 + float(model.data.blank_offset), 325, 440, 135)
			for index in 3:
				var count := int(model.data.strikes[index])
				var tex := Art.part(1 if count == 0 else 4 if count == 1 else 5)
				var dims := blank.size
				draw_texture_rect_region(tex, Rect2(blank.get_center() - dims / 2 + Vector2(index * dims.x / 3, 0), Vector2(dims.x / 3, dims.y)), Rect2(Vector2(index * tex.get_width() / 3.0, 0), Vector2(tex.get_width() / 3.0, tex.get_height())), HOT)
			_part(0, Rect2(505, 190 + impact * 112, 158, 175), true)
			var pivot := Vector2(982, 462)
			draw_set_transform(pivot * size / NATIVE, -0.48 + maxf(impact, lever_pull) * 0.9, size / NATIVE)
			_part(1, Rect2(-25, -190, 50, 200), true)
			draw_set_transform(Vector2.ZERO, 0, size / NATIVE)
			if impact > 0.65:
				for index in 8:
					var start := Vector2(580, 406)
					var ray := Vector2(cos(index * 0.8), sin(index * 0.8)) * (28 + impact * 25)
					draw_line(start + ray, start + ray * 1.2, Color("ffc96a"), 3)
			if float(model.data.impact_age) < 0.65:
				var age := float(model.data.impact_age)
				for puff in 7:
					draw_circle(Vector2(665 + puff * 8 + age * 28, 210 - age * 65 - puff * 3), 3 + age * 12, Color(0.84, 0.81, 0.72, (1 - age / 0.65) * 0.35))
			for index in 3:
				_selected(die_rect(index), index == int(model.data.die))
				_part(index + 9, die_rect(index), true)
				_text(Vector2(70 + index * 350, 75), "%s · %d / 2" % [["Ojo pequeño", "Cuello", "Ojo grande"][index], int(model.data.strikes[index])], Color("b9df89") if int(model.data.strikes[index]) == 2 else GOLD)
			_badge(Vector2(420, 497), "Tope alineado" if bool(model.data.aligned) else "Ajusta la posición", bool(model.data.aligned))
			_badge(Vector2(892, 535), "Bajar palanca")
		3: _draw_drilling()
		4:
			_part(7, TEMPLATE)
			var count := int(model.data.filed[0]) + int(model.data.filed[1]) + int(model.data.filed[2])
			var rect := TEMPLATE.grow(-22) if bool(model.data.fitted) else piece_rect()
			if drag != "fit": _part(6, rect)
			if not bool(model.data.fitted):
				for index in 3:
					var zone := Vector2(175 + index * 165, 390)
					var burrs := (3 if model.easy else 4) - int(model.data.filed[index])
					for tooth in burrs * 3:
						var at := zone + Vector2(tooth * 4 - 15, -30)
						draw_line(at, at + Vector2(3, -7), Color("ced3c9"), 3)
					if burrs == 0: draw_line(zone + Vector2(-25, -29), zone + Vector2(28, -29), Color("edf0d9"), 3)
					if int(model.data.interference) == index:
						draw_arc(zone, 45, 0, TAU, 32, Color("ffb85d"), 3)
					_text(Vector2(135 + index * 165, 480), "%d / %d" % [int(model.data.filed[index]), 3 if model.easy else 4])
			_part(8, Rect2(pointer - Vector2(125, 25), Vector2(250, 70)) if drag == "file" else Rect2(145, 540, 300, 75))
			if float(model.data.file_age) < 0.65:
				for chip in 9:
					var at := Vector2(175 + int(model.data.zone) * 165 + sin(chip * 5.2) * 35, 390 + float(model.data.file_age) * 95 + chip * 3)
					draw_line(at, at + Vector2(3, 2), Color("c6c9bd"), 2)
			_text(Vector2(665, 460), "Ajuste correcto" if bool(model.data.fitted) else "Plantilla de comprobación", Color("b9df89") if bool(model.data.fitted) else GOLD)
			_text(Vector2(70, 80), "Hierro frío · Lima hacia delante · %d pasadas útiles" % count)
		5: _draw_transmission()
	if drag in ["billet", "fit", "link", "pin", "die", "bit"]:
		var texture: Texture2D = Art.part(drag_index if drag == "billet" else 7 + drag_index if drag == "pin" else 9 + drag_index if drag == "die" else 2 + drag_index if drag == "bit" else 6, drag in ["pin", "die", "bit"])
		_fit(texture, Rect2(pointer - Vector2(140, 60), Vector2(280, 120)))

func pointer_down(at: Vector2) -> void:
	if paused or model == null or not model.allowed(): return
	if model.step() == 1 and bool(model.data.heat_approved): return
	if get_parent() is Control: get_parent().grab_focus()
	pointer = at
	origin = at
	stroke_point = at
	stroke_armed = true
	lever_fired = false
	match model.step():
		0:
			if bool(model.data.billet_placed):
				if ruler_rect().grow(12).has_point(at): drag = "ruler"
				elif caliper_rect().grow(10).has_point(at): drag = "caliper"
				for index in 2:
					if at.distance_to(clamp_center(index)) < 57:
						drag = "clamp"
						drag_index = index
						last_angle = (at - clamp_center(index)).angle()
			for index in 3:
				if drag.is_empty() and billet_rect(index).grow(6).has_point(at):
					selected = index
					model.select_billet(index)
					drag = "billet"
					drag_index = index
		1:
			if air_wheel_hit(at):
				drag = "air"
				last_angle = air_wheel_angle(at)
			elif Rect2(150, 235, 640, 340).has_point(at):
				drag = "tongs"
				model.heat_bar()
		2:
			for index in 3:
				if die_rect(index).has_point(at):
					drag = "die"
					drag_index = index
			if drag.is_empty():
				if at.x > 900 and at.y > 220 and at.y < 525: drag = "lever"
				elif Rect2(230, 300, 650, 185).has_point(at):
					drag = "blank"
					origin.x = at.x - ((1 - int(model.data.zone)) * 155 + float(model.data.blank_offset))
		3:
			for index in 2:
				if Rect2(840 + index * 120, 500, 100, 135).has_point(at):
					drag = "bit"
					drag_index = index
			if drag.is_empty():
				if at.distance_to(Vector2(780, 550)) < 60:
					drag = "feed_screw"
					last_angle = (at - Vector2(780, 550)).angle()
					stroke_point.x = float(model.data.position)
				elif Rect2(680, 120, 190, 230).has_point(at):
					drag = "drill_lever"
					model.drill()
				elif Rect2(drill_center() + Vector2(-235, 30), Vector2(470, 110)).has_point(at): model.clamp_drill()
		4:
			if Rect2(110, 520, 360, 120).has_point(at): drag = "file"
			elif piece_rect().has_point(at) and not bool(model.data.fitted): drag = "fit"
		5:
			if not bool(model.data.link) and Rect2(80, 500, 400, 140).has_point(at): drag = "link"
			if bool(model.data.link):
				var eyes := mechanism_eyes()
				for index in 2:
					if at.distance_to(eyes[index]) < 32 and int(model.data.pins[index]) >= 0:
						drag = "pin"
						drag_index = model.lift_pin(index)
			for index in 2:
				if drag.is_empty() and Rect2(600 + index * 170, 520, 120, 120).has_point(at) and index not in model.data.pins:
					drag = "pin"
					drag_index = index
			if Rect2(938, 365, 125, 170).has_point(at): drag = "brake"
			elif drag.is_empty() and _wheel_vector(at).length() < 140 and bool(model.data.link):
				if model.data.pins == [0, 1]:
					drag = "crank"
					last_angle = _wheel_vector(at).angle()
				else: model.confirm()
	worked.emit()
	queue_redraw()

func pointer_move(at: Vector2) -> void:
	if paused or model == null or not model.allowed(): return
	pointer = at
	match drag:
		"ruler": model.measure_length((440 - at.y) / 200.0)
		"caliper": model.measure_thickness((at.y - 230) / 85.0)
		"clamp":
			var angle := (at - clamp_center(drag_index)).angle()
			model.tighten(drag_index, absf(wrapf(angle - last_angle, -PI, PI)) / TAU)
			last_angle = angle
		"air":
			var angle := air_wheel_angle(at)
			model.set_air(float(model.data.air) + wrapf(angle - last_angle, -PI, PI) / (TAU * 0.8))
			last_angle = angle
		"tongs": model.move_heat((at.x - 305) / 230.0)
		"blank": model.align_blank(at.x - origin.x)
		"lever":
			lever_pull = clampf((at.y - origin.y) / 100, 0, 1)
			if lever_pull >= 0.65 and not lever_fired:
				lever_fired = true
				model.strike()
		"feed_screw":
			var angle := (at - Vector2(780, 550)).angle()
			stroke_point.x = clampf(stroke_point.x + wrapf(angle - last_angle, -PI, PI) / 0.65, 0, 4)
			model.move_jig(roundi(stroke_point.x))
			last_angle = angle
		"file":
			if piece_rect().grow(15).has_point(at):
				if at.x < stroke_point.x - 16:
					stroke_armed = true
					stroke_point = at
				elif at.x - stroke_point.x > (30 if model.easy else 45) and stroke_armed:
					model.file_zone(clampi(roundi((at.x - 175) / 165), 0, 2))
					stroke_armed = false
					stroke_point = at
			else: stroke_point = at
		"brake": model.set_brake((505 - at.y) / 110.0)
		"crank":
			if _wheel_vector(at).length() >= 40:
				var angle := _wheel_vector(at).angle()
				var movement := wrapf(angle - last_angle, -PI, PI)
				if movement > 0 and movement < 0.8: model.crank(movement)
				last_angle = angle
	if drag.is_empty(): hover_hint = tool_hint(at)
	worked.emit()
	queue_redraw()

func pointer_up(at: Vector2) -> void:
	if not paused and model != null and model.allowed():
		match drag:
			"billet":
				if GAUGE.grow(25).has_point(at): model.place_billet()
			"die":
				if Rect2(460, 345, 250, 145).has_point(at): model.choose_die(drag_index)
			"bit":
				if Rect2(520, 190, 160, 190).has_point(at): model.choose_bit(drag_index)
			"fit":
				if TEMPLATE.grow(30).has_point(at): model.fit_piece()
			"link":
				if Rect2(360, 220, 530, 220).has_point(at): model.mount_link()
			"pin":
				var eyes := mechanism_eyes()
				for index in 2:
					if at.distance_to(eyes[index]) < 75: model.place_pin(index, drag_index)
	cancel_drag()
	worked.emit()

func tool_hint(at: Vector2) -> String:
	match model.step():
		0:
			if ruler_rect().grow(15).has_point(at): return "Regla: arrastra hasta el borde de la barra."
			if caliper_rect().has_point(at): return "Calibre: desliza la mordaza hasta tocar el hierro."
			for index in 2:
				if at.distance_to(clamp_center(index)) < 60: return "Mordaza: gira o mantén pulsado para apretar."
			return "Arrastra una barra al soporte. El pedido indica 120 × 30."
		1: return "Calor uniforme aprobado. Pulsa Continuar." if bool(model.data.heat_approved) else "Tenazas: mueve el hierro hacia la zona fría. Volante: gira para regular aire."
		2: return "Arrastra una matriz al yunque. Alinea el hierro y baja la palanca."
		3: return "Monta la broca, gira el avance y mantén la palanca; suelta si vibra."
		4: return "Lima hacia la derecha sobre las rebabas. Regresa para otra pasada."
		5: return "Gira en sentido horario. Desliza el freno para comprobar una vuelta bajo carga."
	return ""

func keyboard(event: InputEventKey) -> bool:
	if paused or model == null or not model.allowed() or event.echo: return false
	if model.step() == 1 and bool(model.data.heat_approved): return false
	var key := event.keycode
	if not event.pressed:
		if key == held_key:
			held_key = KEY_NONE
			lever_pull = 0.0
			model.release_drill()
			model.crank_held = false
			return true
		return false
	var direction := -1 if key in [KEY_LEFT, KEY_A, KEY_DOWN] else 1
	if key in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
		match model.step():
			0:
				selected = posmod(selected + direction, 3)
				model.select_billet(selected)
			1:
				held_key = key
				model.move_heat(float(model.data.heat_position) + direction * 0.1)
			2, 4: model.choose_zone(posmod(int(model.data.zone) + direction, 3))
			3: model.move_jig(int(model.data.position) + direction)
	elif key in [KEY_UP, KEY_DOWN]:
		if model.step() == 1: model.set_air(float(model.data.air) + direction * 0.05)
		elif model.step() == 5: model.set_brake(float(model.data.brake) + direction * 0.05)
	elif key >= KEY_1 and key <= KEY_3:
		var value := int(key - KEY_1)
		match model.step():
			0:
				selected = value
				model.select_billet(value)
			2: model.choose_die(value)
			3: model.choose_bit(mini(value, 1))
			5: model.place_pin(mini(value, 1), mini(value, 1))
	elif key == KEY_R and model.step() == 0: model.measure_length(0.5)
	elif key == KEY_C:
		if model.step() == 0: model.measure_thickness(0.0)
		elif model.step() == 3: model.clamp_drill()
	elif key == KEY_T:
		if model.step() == 1: model.remove_bar()
		elif model.step() == 4: model.fit_piece()
	elif key in [KEY_Q, KEY_E] and model.step() == 0: held_key = key
	elif key == KEY_E and model.step() == 5: model.mount_link()
	elif key in [KEY_SPACE, KEY_E]:
		held_key = key
		match model.step():
			0:
				if int(model.data.billet) < 0: model.select_billet(selected)
				model.place_billet()
			1: model.heat_bar()
			2:
				lever_pull = 1.0
				model.strike()
			3: model.drill()
			4: model.file_zone(int(model.data.zone))
			5: model.crank_held = true
	else: return false
	worked.emit()
	queue_redraw()
	return true

func _gui_input(event: InputEvent) -> void:
	if paused: return
	var ratio := NATIVE / size
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: pointer_down(event.position * ratio)
		else: pointer_up(event.position * ratio)
	elif event is InputEventMouseMotion: pointer_move(event.position * ratio)
	elif event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			pointer_down(event.position * ratio)
		elif not event.pressed and touch_id == event.index: pointer_up(event.position * ratio)
	elif event is InputEventScreenDrag:
		if touch_id == event.index: pointer_move(event.position * ratio)
	else: return
	accept_event()
