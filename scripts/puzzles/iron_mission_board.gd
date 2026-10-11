extends Control
## Sprite-based tools; pointer zones and keyboard commands share mission actions.
signal requested(action_name: String, index: int, value: float)
const Mission := preload("res://scripts/core/iron_mission.gd")
const PARTS := preload("res://assets/phase2/iron_mission_parts_pixel_v2.png")
const BodyBounds := preload("res://scripts/world/sprite_body_bounds.gd")
const TOOLS := preload("res://assets/phase2/tools_pixel_v1.png")
const LEVER := preload("res://assets/gba/ui/silas_brake_parts_pixel_v2.png")
const MINE := preload("res://assets/phase2/mine_tunnel_iron_v1.png")
const ENGINE := preload("res://assets/phase2/engine_pixel_v1.png")
const GOLD := Color("e7bf70")
const GREEN := Color("a8c382")
var mission: Mission
var refill: bool = false
var selected: int = 0
var selected_gear: int = 0
var drag_gear: int = -1
var drag_fragment: int = -1
var drag_valve: bool = false
var pointer := Vector2.ZERO
var zones: Array[Dictionary] = []
var rotation_clock: float = 0.0
var gears_turning: bool = false
var tools_locked: bool = false
var effects: CPUParticles2D
var fire: ColorRect
var atlas_cache: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	effects = CPUParticles2D.new()
	effects.amount = 18
	effects.lifetime = 0.45
	effects.emitting = false
	effects.direction = Vector2(0, -1)
	effects.spread = 50
	effects.initial_velocity_min = 20
	effects.initial_velocity_max = 65
	effects.gravity = Vector2(0, 150)
	effects.color = Color("d3b285")
	add_child(effects)
	fire = ColorRect.new()
	fire.position = Vector2(85, 130)
	fire.size = Vector2(270, 140)
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://shaders/coal_fire.gdshader")
	fire.material = glow
	add_child(fire)
	fire.hide()

func part(index: int, tools: bool = false) -> Texture2D:
	var key := index + (20 if tools else 0)
	if atlas_cache.has(key): return atlas_cache[key]
	var texture := AtlasTexture.new()
	texture.atlas = TOOLS if tools else PARTS
	var cell := texture.atlas.get_size() / Vector2(4, 3 if tools else 2)
	texture.region = Rect2(Vector2(index % 4, floori(index / 4.0)) * cell, cell)
	var crop := BodyBounds.measure(texture.atlas.get_image().get_region(Rect2i(texture.region)))
	texture.region = Rect2(texture.region.position + Vector2(crop.position), Vector2(crop.size))
	atlas_cache[key] = texture
	return texture

func update_visual(delta: float) -> void:
	rotation_clock += delta
	fire.visible = mission != null and mission.stage() >= 4 and not refill and bool(mission.data.lit)
	if fire.visible:
		(fire.material as ShaderMaterial).set_shader_parameter("motion_time", rotation_clock)
		(fire.material as ShaderMaterial).set_shader_parameter("intensity", float(mission.data.fuel))
	queue_redraw()

func cancel_drag() -> void:
	drag_gear = -1
	drag_fragment = -1
	drag_valve = false
	effects.emitting = false

func _text(text: String, pos: Vector2, color: Color = GOLD, font_size: int = 15) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _plate(rect: Rect2) -> void:
	draw_style_box(_style(), rect)

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171a18ed")
	style.border_color = Color("80603a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _zone(rect: Rect2, action_name: String, index: int = -1) -> void:
	zones.append({"rect": rect, "action": action_name, "index": index})

func _draw() -> void:
	if mission == null: return
	zones.clear()
	var mining := mission.stage() == 1 or refill
	draw_texture_rect(MINE if mining else ENGINE, Rect2(Vector2.ZERO, size), false, Color(0.65, 0.63, 0.58))
	if mining: _draw_mining()
	else:
		match mission.stage():
			2: _draw_gears()
			3: _draw_pipes()
			4, 5: _draw_boiler()

func _draw_mining() -> void:
	var key := "refill_hits" if refill else "hits"
	var sorted_key := "refill_sorted" if refill else "sorted"
	if int(mission.data[key]) < 6:
		_plate(Rect2(225, 42, 540, 278))
		draw_texture_rect(part(2, true), Rect2(380, 65, 230, 220), false)
		var raised := float(mission.data.hit_clock) > (0.25 if mission.easy else 0.45)
		draw_set_transform(Vector2(635, 140), -0.3 if raised else 0.35)
		draw_texture_rect(part(1, true), Rect2(-70, -85, 140, 170), false)
		draw_set_transform(Vector2.ZERO)
		_text("PIQUETA · %d / 6 fragmentos" % int(mission.data[key]), Vector2(310, 311))
		_text("Lista para otro golpe" if raised else "Deja volver la herramienta", Vector2(350, 350), GREEN if raised else GOLD)
		_zone(Rect2(225, 42, 540, 278), "hit")
		return
	_plate(Rect2(115, 53, 770, 170))
	for index in 6:
		if index in mission.data[sorted_key] or drag_fragment == index: continue
		var rect := Rect2(145 + index * 118, 82, 100, 105)
		draw_texture_rect(part(2, true) if index % 2 == 0 else part(6), rect, false)
		if selected == index: draw_rect(rect.grow(3), GOLD, false, 2)
		_zone(rect, "fragment", index)
	for index in 2:
		var rect := Rect2(125 + index * 420, 245, 325, 100)
		_plate(rect)
		draw_texture_rect(part(6 if index == 0 else 5), Rect2(rect.position + Vector2(15, 8), Vector2(78, 80)), false)
		_text("PIEDRA" if index == 0 else "CARBÓN", rect.position + Vector2(115, 57), GOLD, 20)
		_zone(rect, "sort", index)
	if drag_fragment >= 0:
		draw_texture_rect(part(2, true) if drag_fragment % 2 == 0 else part(6), Rect2(pointer - Vector2(42, 42), Vector2(84, 84)), false)
	_text("Clasificados: %d / 6 · arrastra al cajón correspondiente" % mission.data[sorted_key].size(), Vector2(250, 375))

func gear_center(index: int) -> Vector2:
	return [Vector2(355, 180), Vector2(453, 180), Vector2(573, 180)][index]

func gear_radius(gear: int) -> float:
	return [37.0, 62.0, 83.0][gear]

func _draw_gear(gear: int, center: Vector2, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	var radius := gear_radius(gear)
	draw_set_transform(center, angle)
	draw_texture_rect(part(gear), Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2), false, tint)
	draw_set_transform(Vector2.ZERO)

func _draw_gears() -> void:
	_plate(Rect2(80, 35, 840, 250))
	_text("DEL EJE MOTOR A LA TRANSMISIÓN", Vector2(280, 65))
	for index in 3:
		var center := gear_center(index)
		var radius := gear_radius(Mission.GEAR_ORDER[index])
		draw_arc(center, radius - 3, 0, TAU, 40, Color("8c805e"), 2)
		draw_circle(center, 7, Color("d0b578"))
		var gear: int = mission.data.gears[index]
		if gear >= 0:
			_draw_gear(gear, center, rotation_clock * (1 if index % 2 == 0 else -1) * 37.0 / gear_radius(gear) if gears_turning else 0.0)
		if selected == index: draw_arc(center, radius + 6, 0, TAU, 40, GOLD, 2)
		_zone(Rect2(center - Vector2.ONE * (radius + 6), Vector2.ONE * (radius + 6) * 2), "slot", index)
	_text("Arrastra cada rueda a su eje · toca una rueda instalada para retirarla", Vector2(210, 273))
	for gear in 3:
		var center := Vector2(300 + gear * 200, 339)
		if gear not in mission.data.gears and drag_gear != gear:
			var radius := gear_radius(gear) * 0.53
			draw_texture_rect(part(gear), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, Color(1, 1, 1, 1 if selected_gear == gear else 0.7))
		_zone(Rect2(center - Vector2(90, 50), Vector2(180, 100)), "gear", gear)
	if drag_gear >= 0: _draw_gear(drag_gear, pointer)

func pipe_center(index: int) -> Vector2:
	return Vector2(300 + (index / 3) * 420, 100 + (index % 3) * 90)

func _draw_pipes() -> void:
	_plate(Rect2(55, 25, 890, 350))
	for row in 2:
		var x := 300.0 + row * 420.0
		_text("AGUA PARA LA CALDERA" if row == 0 else "AGUA FRÍA · CONDENSADOR", Vector2(x - 172, 52), GOLD, 15)
		# Stationary fittings end exactly at the rotatable components.
		draw_texture_rect(part(3), Rect2(x - 150, 87, 110, 26), false)
		draw_texture_rect(part(3), Rect2(x + 40, 267, 110, 26), false)
		_text("DEPÓSITO", Vector2(x - 175, 82), Color("9bbdcc"), 12)
		_text("CALDERA" if row == 0 else "CONDENSADOR", Vector2(x + 47, 322), GOLD, 12)
		for item in 3:
			var index := row * 3 + item
			var center := pipe_center(index)
			var turns: int = mission.data.pipes[index]
			var base_turn := 1 if item == 1 else (3 if item == 2 else 0)
			draw_set_transform(center, (turns + base_turn) * PI / 2)
			# Place the bend at the tile origin so its ports meet the neighbors.
			draw_texture_rect(part(3 if item == 1 else 4), Rect2(-40, -13, 80, 26) if item == 1 else Rect2(-18, -40, 58, 58), false)
			draw_set_transform(Vector2.ZERO)
			if selected == index: draw_rect(Rect2(center - Vector2(43, 43), Vector2(86, 86)), GOLD, false, 2)
			_zone(Rect2(center - Vector2(43, 43), Vector2(86, 86)), "pipe", index)
		# Fixed copper collars join the movable sections.
		for y in [145.0, 235.0]:
			draw_set_transform(Vector2(x, y), PI / 2)
			draw_texture_rect(part(3), Rect2(-5, -13, 10, 26), false)
			draw_set_transform(Vector2.ZERO)
		if mission.circuit_connected(row):
			draw_polyline(PackedVector2Array([Vector2(x - 140, 100), Vector2(x, 100), Vector2(x, 280), Vector2(x + 140, 280)]), Color(0.45, 0.8, 0.9, 0.65), 4)
			_text("CIRCUITO CERRADO", Vector2(x - 70, 354), GREEN, 12)

func _gauge(center: Vector2, pressure: float) -> void:
	draw_circle(center + Vector2(3, 5), 83, Color("090d0dd0"))
	draw_circle(center, 82, Color("ad874c"))
	draw_circle(center, 75, Color("ead8a0"))
	draw_arc(center, 64, PI * 0.75 + (0.5 - mission.pressure_band()) * PI * 1.5, PI * 0.75 + (0.5 + mission.pressure_band()) * PI * 1.5, 26, Color("658255"), 12)
	for mark in 21:
		var angle := PI * 0.75 + float(mark) / 20 * PI * 1.5
		draw_line(center + Vector2.from_angle(angle) * 58, center + Vector2.from_angle(angle) * (68 if mark % 5 == 0 else 64), Color("4c4937"), 2)
	var needle := PI * 0.75 + clampf(pressure, 0, 1) * PI * 1.5
	draw_line(center, center + Vector2.from_angle(needle) * 57, Color("6d472c"), 4)
	draw_circle(center, 7, GOLD)
	_text("PRESIÓN", center + Vector2(-33, 43), Color("4a3624"), 13)

func _draw_boiler() -> void:
	_plate(Rect2(55, 45, 330, 295))
	_text("HOGAR DE LA CALDERA", Vector2(105, 73))
	var flames := Color("ffbd54") if bool(mission.data.lit) and float(mission.data.fuel) > 0 else Color("504439")
	for coal in 6:
		draw_texture_rect(part(2, true), Rect2(85 + coal % 3 * 85, 160 + (coal / 3) * 65, 80, 70), false, flames)
	_text("Fuego débil" if float(mission.data.fuel) < 0.34 else ("Hogar cargado" if float(mission.data.fuel) > 0.7 else "Fuego vivo"), Vector2(150, 333), GOLD)
	_text("Agua: preparada" if bool(mission.data.water) else "Agua: pendiente", Vector2(100, 307), GREEN if bool(mission.data.water) else GOLD)
	_zone(Rect2(55, 45, 330, 295), "feed")
	_gauge(Vector2(520, 151), float(mission.data.pressure))
	_text("Carbón: %d costales · %d paladas disponibles" % [int(GameState.inventory.get(Mission.COAL_ITEM, 0)), mission.fuel_available()], Vector2(405, 280))
	if mission.stage() == 5:
		var seconds := int(float(mission.data.stable_seconds))
		_text("Tiempo estable: %02d:%02d / 02:00" % [seconds / 60, seconds % 60], Vector2(410, 310), GREEN, 19)
		_text("Descarga de vapor", Vector2(720, 78))
		# Existing textured Silas lever, reused across the game's mechanical tools.
		draw_texture_rect_region(LEVER, Rect2(720, 247, 200, 80), Rect2(199, 337, 1010, 427))
		draw_set_transform(Vector2(818, 258), lerpf(-0.65, 0.65, float(mission.data.valve)))
		draw_texture_rect_region(LEVER, Rect2(-12, -138, 24, 151), Rect2(1526, 26, 131, 743))
		draw_set_transform(Vector2.ZERO)
		_text("CERRAR              ABRIR", Vector2(725, 330), GOLD, 12)
		_zone(Rect2(710, 100, 225, 235), "valve")
	else:
		draw_texture_rect(part(5), Rect2(735, 120, 155, 190), false)

func _gui_input(event: InputEvent) -> void:
	if mission == null or mission.blocked() or tools_locked: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(event.position, event.pressed)
	elif event is InputEventScreenTouch: _pointer(event.position, event.pressed)
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		pointer = event.position
		if drag_valve: requested.emit("valve", -1, clampf((pointer.x - 710) / 225, 0, 1))
		queue_redraw()
	accept_event()

func _pointer(pos: Vector2, pressed: bool) -> void:
	pointer = pos
	if not pressed:
		for zone in zones:
			if not zone.rect.has_point(pos): continue
			if drag_gear >= 0 and zone.action == "slot": requested.emit("place", int(zone.index), drag_gear)
			if drag_fragment >= 0 and zone.action == "sort": requested.emit("sort", drag_fragment, int(zone.index))
		cancel_drag()
		queue_redraw()
		return
	for zone in zones:
		if not zone.rect.has_point(pos): continue
		match str(zone.action):
			"gear":
				selected_gear = int(zone.index)
				if selected_gear not in mission.data.gears: drag_gear = selected_gear
			"slot":
				selected = int(zone.index)
				if int(mission.data.gears[selected]) >= 0:
					drag_gear = int(mission.data.gears[selected])
					mission.data.gears[selected] = -1
					mission.persist()
			"fragment":
				selected = int(zone.index)
				drag_fragment = selected
			"pipe":
				selected = int(zone.index)
				requested.emit("pipe", selected, 0)
			"valve":
				drag_valve = true
				requested.emit("valve", -1, clampf((pos.x - 710) / 225, 0, 1))
			_:
				requested.emit(str(zone.action), int(zone.index), 0)
				if zone.action == "hit":
					effects.position = pos
					effects.restart()
					effects.emitting = true
		break
	queue_redraw()
