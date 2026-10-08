extends Control
## Diegetic canvas: sprite tools, analog instruments and direct manipulation.
signal requested(action_name: String, value: float, index: int)
signal selected(index: int)
const Work := preload("res://scripts/puzzles/factory_work_state.gd")
const Catalog := preload("res://scripts/puzzles/factory_stage_catalog.gd")
const TOOLS := preload("res://assets/phase2/tools_pixel_v1.png")
const MECHANISMS := preload("res://assets/phase2/mechanisms_pixel_v1.png")
const TEXTILE_SETUP := preload("res://assets/phase2/textile_setup_pixel_v1.png")
const LEVER := preload("res://assets/gba/ui/silas_brake_parts_pixel_v2.png")
const ROPE := preload("res://assets/gba/ui/silas_rope_braid_pixel_v1.png")
const CART := preload("res://assets/gba/ui/ropewalk_carriage_v2.png")
const TIMBER := preload("res://assets/gba/ui/mill_plank_piece_v1.png")
var workshop_id: String = "mine"
var work: Work
var background: Texture2D
var zones: Array[Dictionary] = []
var drag: Dictionary = {}
var previous: Vector2 = Vector2.ZERO
var sparks: GPUParticles2D
var lamp: ColorRect
var hot: Sprite2D
var steam: Sprite2D
var font: Font = ThemeDB.fallback_font
var paused_visual: bool = false
const GOLD := Color("e7bf70")
const GREEN := Color("a5bd79")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	background = load("res://assets/phase2/%s_pixel_v1.png" % workshop_id)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sparks = GPUParticles2D.new()
	sparks.amount = 28
	sparks.lifetime = 0.6
	sparks.emitting = false
	sparks.visibility_rect = Rect2(-100, -100, 1000, 600)
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 50.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 70.0
	material.gravity = Vector3(0, 140, 0)
	material.scale_min = 1.5
	material.scale_max = 3.0
	material.color = Color("e4aa4a")
	sparks.process_material = material
	add_child(sparks)
	lamp = ColorRect.new()
	lamp.size = Vector2(100, 130)
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://shaders/davy_lamp_glow.gdshader")
	lamp.material = glow
	add_child(lamp)
	hot = Sprite2D.new()
	hot.texture = _atlas(5)
	hot.scale = Vector2.ONE * 0.42
	var heat_material := ShaderMaterial.new()
	heat_material.shader = preload("res://shaders/hot_iron_glow.gdshader")
	hot.material = heat_material
	add_child(hot)
	steam = Sprite2D.new()
	steam.texture = preload("res://assets/gba/steam_puff_v2.png")
	steam.scale = Vector2.ONE * 0.5
	var steam_material := ShaderMaterial.new()
	steam_material.shader = preload("res://shaders/steam_pressure_leak.gdshader")
	steam.material = steam_material
	add_child(steam)
	set_process(true)

func _atlas(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = TOOLS
	var cell := Vector2(TOOLS.get_width() / 4.0, TOOLS.get_height() / 3.0)
	atlas.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
	if index == 6: atlas.region = Rect2(cell.x * 2.16, cell.y * 1.06, cell.x * 0.74, cell.y * 0.93)
	return atlas

func _mechanism(index: int, rect: Rect2, action_name: String = "", selected_index: int = -1) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = MECHANISMS
	var cell := Vector2(MECHANISMS.get_width() / 4.0, MECHANISMS.get_height() / 2.0)
	texture.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
	draw_texture_rect(texture, rect, false)
	if not action_name.is_empty(): zones.append({"rect": rect, "action": action_name, "index": selected_index})

func _process(_delta: float) -> void:
	if work == null:
		lamp.hide()
		hot.hide()
		steam.hide()
		return
	lamp.visible = workshop_id == "mine" and work.stage in [0, 1]
	lamp.position = (Vector2(365, 172) if work.stage == 0 else work.pointer * size) - lamp.size * 0.5
	(lamp.material as ShaderMaterial).set_shader_parameter("methane", maxf(0.0, 1.0 - float(work.data.count) / 3.0) if work.stage == 0 else 0.0)
	(lamp.material as ShaderMaterial).set_shader_parameter("motion_time", work.clock)
	hot.visible = workshop_id == "forge" and work.stage in [1, 2, 3, 4]
	hot.position = (work.pointer * size if not drag.is_empty() and work.stage == 3 else Vector2(470, 185))
	(hot.material as ShaderMaterial).set_shader_parameter("temperature", float(work.data.heat))
	(hot.material as ShaderMaterial).set_shader_parameter("motion_time", work.clock)
	steam.visible = workshop_id in ["engine", "textile"] and work.stage == (5 if workshop_id == "engine" else 3)
	steam.position = Vector2(95, 90)
	(steam.material as ShaderMaterial).set_shader_parameter("pressure", float(work.data.pressure))
	(steam.material as ShaderMaterial).set_shader_parameter("motion_time", work.clock)
	sparks.emitting = not drag.is_empty() and not work.paused and workshop_id in ["mine", "forge"]
	sparks.speed_scale = 0.0 if work.paused or paused_visual else 1.0
	sparks.position = work.pointer * size
	queue_redraw()

func _draw() -> void:
	if workshop_id == "textile": background = TEXTILE_SETUP if work != null and work.stage == 0 else preload("res://assets/phase2/textile_pixel_v1.png")
	if background != null:
		var source := Rect2(Vector2.ZERO, background.get_size())
		var width := source.size.y * size.x / size.y
		source.position.x = (source.size.x - width) * 0.5
		source.size.x = width
		if width > background.get_width():
			source = Rect2(0, (background.get_height() - background.get_width() * size.y / size.x) * 0.5, background.get_width(), background.get_width() * size.y / size.x)
		draw_texture_rect_region(background, Rect2(Vector2.ZERO, size), source)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.01, 0.25))
	zones.clear()
	if work == null: return
	_chip("%s · %d / %d" % ["TALLER INDUSTRIAL", work.stage + 1, work.phase_count()], Vector2(14, 12), 300)
	match workshop_id:
		"mine": _draw_mine()
		"forge": _draw_forge()
		"engine": _draw_engine()
		"textile": _draw_textile()
	for zone in zones:
		if int(zone.index) >= 0 and int(zone.index) == int(work.data.selected):
			draw_rect((zone.rect as Rect2).grow(3), Color(0.89, 0.74, 0.37, 0.8), false, 2)
	_chip(readout(), Vector2(14, size.y - 35), size.x - 28)
	if work.paused: draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.2))

func _chip(text: String, pos: Vector2, width: float = 150.0, ink: Color = GOLD) -> void:
	draw_rect(Rect2(pos, Vector2(width, 27)), Color("21190eef"))
	draw_rect(Rect2(pos, Vector2(width, 27)), Color("987342"), false, 1.0)
	draw_string(font, pos + Vector2(9, 18), text, HORIZONTAL_ALIGNMENT_LEFT, width - 14, 13, ink)

func _sprite(index: int, rect: Rect2, action_name: String = "", selected_index: int = -1, tint := Color.WHITE) -> void:
	draw_texture_rect(_atlas(index), rect, false, tint)
	if not action_name.is_empty(): zones.append({"rect": rect, "action": action_name, "index": selected_index})

func _gauge(value: float, label: String, center := Vector2(703, 88), radius: float = 55.0, target: float = 0.5, tolerance: float = -1.0) -> void:
	var margin := work.tolerance() if tolerance < 0.0 else tolerance
	draw_circle(center, radius + 5, Color("211911"))
	draw_circle(center, radius + 2, Color("c19b54"))
	draw_circle(center, radius - 2, Color("e0d19a"))
	draw_arc(center, radius - 10, PI * 0.75 + (target - margin) * PI * 1.5, PI * 0.75 + (target + margin) * PI * 1.5, 24, Color("607b46"), 9)
	for tick in 21:
		var a := PI * 0.75 + float(tick) / 20.0 * PI * 1.5
		draw_line(center + Vector2.from_angle(a) * (radius - 7), center + Vector2.from_angle(a) * (radius - (18 if tick % 5 == 0 else 13)), Color("4e3a25"), 1)
	var angle := PI * 0.75 + clampf(value, 0, 1) * PI * 1.5
	draw_line(center, center + Vector2.from_angle(angle) * (radius - 18), Color("855132"), 3)
	draw_circle(center, 5, Color("a77838"))
	_chip(label, center + Vector2(-radius - 8, radius + 11), radius * 2 + 16)

func _lever(value: float, position: Vector2) -> void:
	draw_texture_rect_region(LEVER, Rect2(position - Vector2(58, 10), Vector2(116, 49)), Rect2(199, 337, 1010, 427))
	draw_set_transform(position, (value - 0.5) * 1.6)
	draw_texture_rect_region(LEVER, Rect2(-8, -66, 16, 74), Rect2(1526, 26, 131, 743))
	draw_set_transform(Vector2.ZERO)
	zones.append({"rect": Rect2(position - Vector2(65, 76), Vector2(130, 114)), "action": "lever", "index": -1})

func _draw_mine() -> void:
	match work.stage:
		0:
			_sprite(0, Rect2(280, 52, 170, 214), "adjust")
			_mechanism(0, Rect2(48, 153, 168, 105), "vent")
			_gauge(float(work.data.adjust), "CIERRE DE MALLA")
			_chip("Fuelle · %d / 3 purgas" % int(work.data.count), Vector2(45, 262), 218)
		1:
			for index in 6:
				var rect := Rect2(80 + (index % 3) * 175, 75 + (index / 3) * 103, 98, 91)
				_sprite(2, rect, "inspect", index, Color(1.8, 1.6, 1.1) if index % 2 != 0 else Color.WHITE)
				_chip(("✓ " if index in work.data.marks else "") + "Veta %d" % (index + 1), rect.position + Vector2(0, 74), 98)
			_sprite(0, Rect2(work.pointer * size - Vector2(28, 52), Vector2(56, 106)))
		2:
			_sprite(2, Rect2(255, 100, 215, 178))
			_sprite(1, Rect2(420, 90 + sin(work.clock * 2.4) * 12, 140, 155), "hit")
			_gauge(work.oscillator(), "COMPÁS · GOLPEA")
		3:
			_mechanism(2, Rect2(235, 120, 280, 133))
			for index in 6:
				if index in work.data.marks: continue
				var rect := Rect2(90 + index * 96, 75, 70, 70)
				_sprite(2, rect, "sort_drag", index, Color(1.8, 1.6, 1.1) if index % 2 != 0 else Color.WHITE)
			_chip("PIEDRA CLARA · descartar", Vector2(55, 240), 275)
			_chip("HULLA NEGRA · conservar", Vector2(440, 240), 275)
			if not drag.is_empty(): _sprite(2, Rect2(work.pointer * size - Vector2(30, 30), Vector2(60, 60)))
		4:
			for index in 3:
				var value := float(work.data.gates[index])
				_sprite(3, Rect2(100 + index * 175, 80 - value * 24, 140, 150), "gate", index)
				_chip("Compuerta %d" % (index + 1), Vector2(100 + index * 175, 239), 140)
			_gauge((work.airflow() - 25.0) / 75.0, "TIRO · CFM", Vector2(705, 95), 52, 0.5, 1.0 / 6.0)
		5:
			var height := 235.0 - float(work.data.crank) * 150.0
			var sway := float(work.data.sway) * 25.0
			draw_texture_rect(TIMBER, Rect2(323, 42, 190, 17), false)
			for post in [329.0, 502.0]:
				draw_set_transform(Vector2(post, 44), PI * 0.5)
				draw_texture_rect(TIMBER, Rect2(0, -8, 249, 17), false)
				draw_set_transform(Vector2.ZERO)
			draw_texture_rect_region(ROPE, Rect2(410 + sway, 50, 8, height - 15), Rect2(22, 305, 2065, 134))
			draw_texture_rect(CART, Rect2(353 + sway, height, 120, 85), false)
			_sprite(2, Rect2(384 + sway, height - 4, 58, 53))
			_mechanism(1, Rect2(75, 124, 188, 140), "crank_drag")
			draw_set_transform(Vector2(238, 219), float(work.data.angle))
			draw_texture_rect_region(LEVER, Rect2(-5, -39, 10, 44), Rect2(1526, 26, 131, 743))
			draw_set_transform(Vector2.ZERO)
			_lever(float(work.data.brake), Vector2(677, 255))
			_chip("CABRESTANTE · giro horario", Vector2(68, 275), 240)

func _draw_forge() -> void:
	match work.stage:
		0:
			_sprite(2, Rect2(115, 90, 110, 110), "fuel")
			_mechanism(5, Rect2(388, 100, 140, 122), "ore")
			_chip("Hogar · coque %d / 2" % int(work.data.fuel), Vector2(63, 249), 235)
			_chip("Solera · arrabio %d / 3" % int(work.data.ore), Vector2(375, 249), 255)
		1:
			_sprite(4, Rect2(work.pointer * size - Vector2(80, 80), Vector2(160, 160)), "stir_drag")
			_gauge(float(work.data.heat), "CALOR DE PUDELADO", Vector2(705, 90), 53, 0.85)
			_chip("Rabot · traza círculos sobre la masa", Vector2(110, 270), 350)
			zones.append({"rect": Rect2(110, 65, 490, 225), "action": "stir_drag", "index": -1})
		2:
			for index in 3:
				if index in work.data.marks: continue
				_sprite(2, Rect2(260 + index * 80, 155, 55, 45), "skim", index)
			_gauge(float(work.data.heat), "HIERRO CALIENTE", Vector2(705, 90), 53, 0.85)
		3:
			zones.append({"rect": Rect2(240, 85, 300, 200), "action": "transfer_drag", "index": -1})
			_chip("Tenazas → yunque", Vector2(470, 275), 230)
			_gauge(float(work.data.heat), "AMARILLO DE FORJA", Vector2(705, 90), 53, 0.85)
		4:
			_sprite(6, Rect2(288, 95, 170, 190), "hit")
			_mechanism(3, Rect2(87, 75, 160, 190), "hit")
			_gauge(work.oscillator(), "PEDAL DEL MARTINETE")
			for index in 4: _chip("Cara %d%s" % [index + 1, " ✓" if int(work.data.count) >= (index + 1) * 2 else ""], Vector2(45 + index * 147, 269), 130)
		5:
			_sprite(6, Rect2(256, 92 + (1.0 - float(work.data.heat)) * 38, 175, 180), "cool_drag")
			_mechanism(4, Rect2(470, 100, 110, 125), "adjust")
			_gauge(float(work.data.adjust), "COMPÁS · PATRÓN")
			_chip("Inmersión gradual · enfriamiento", Vector2(170, 280), 370)

func _draw_engine() -> void:
	var part: int = [7, 8, 7, 6, 9, 9][work.stage]
	if work.stage in [2, 3]:
		draw_set_transform(Vector2(375, 158), (float(work.data.adjust) - 0.5) * 0.4)
		_mechanism(6, Rect2(-100, -85, 200, 170))
		draw_set_transform(Vector2.ZERO)
		zones.append({"rect": Rect2(275, 73, 200, 170), "action": "adjust", "index": -1})
	else: _sprite(part, Rect2(275, 73, 200, 218), "engine_drag")
	var count := Catalog.selectors(workshop_id, work.stage)
	for index in count:
		var pos := Vector2(65 + index * 135, 248)
		var finished: bool = index in work.data.marks or index in work.data.bolts or index in work.data.pipes
		_chip("%d · %s" % [index + 1, "✓" if finished else "encajar"], pos, 116)
		zones.append({"rect": Rect2(pos, Vector2(116, 45)), "action": "engine_part", "index": index})
	if work.stage == 0: _chip("%s · empaque %s" % ["Émbolo dentro" if int(work.data.count) > 0 else "Inserta el émbolo", "✓" if bool(work.data.packing) else "pendiente"], Vector2(63, 65), 300)
	if work.stage == 1: _chip("Arandelas %d · tuberías %d" % [work.data.washers.size(), work.data.pipes.size()], Vector2(63, 65), 300)
	if work.stage in [2, 3]: _gauge(float(work.data.adjust), "ALINEACIÓN")
	if work.stage == 5:
		_gauge(float(work.data.pressure), "%.1f PSI" % (float(work.data.pressure) * 30.0))
		_lever(float(work.data.inlet), Vector2(588, 253))
		_chip("Condensado · " + ("purgado ✓" if bool(work.data.purged) else "purga pendiente"), Vector2(62, 270), 275)

func _draw_textile() -> void:
	for index in 4:
		var x := 97.0 + index * 158.0
		var done: bool = index in work.data.belts or index in work.data.marks
		if work.stage > 0 or done:
			draw_line(Vector2(x - 9, 53), Vector2(x - 9 + sin(work.clock * 5.0) * 2.0, 202), Color("684127"), 6)
			draw_line(Vector2(x + 9, 53), Vector2(x + 9, 202), Color("d4a760"), 4)
		var shifting := 0.0
		if work.stage == 3 and bool(work.data.running) and not bool(work.data.emergency) and not bool(work.data.broken[index]) and not bool(work.data.stopped[index]): shifting = sin(work.clock * 8.0 + index) * 14.0
		_sprite(10, Rect2(x - 46 + shifting, 149, 92, 91), "loom", index)
		var tag := "Telar %d" % (index + 1)
		if work.stage == 3:
			if bool(work.data.broken[index]): tag += " · hilo roto"
			elif bool(work.data.stopped[index]): tag += " · frenado"
			elif float(work.data.stocks[index]) <= 0.0: tag += " · sin hilo"
			else: tag += " · hilo %.0f%%" % (float(work.data.stocks[index]) * 100)
		var ink := GOLD
		if work.stage == 3 and (bool(work.data.broken[index]) or float(work.data.stocks[index]) < 0.25): ink = Color("efa278")
		_chip(tag, Vector2(x - 65, 258), 150, ink)
		if work.stage == 1:
			_gauge(float(work.data.tensions[index]), "POLEA %d" % (index + 1), Vector2(x, 103), 39)
			zones.append({"rect": Rect2(x - 50, 50, 100, 100), "action": "tension", "index": index})
		elif work.stage == 0: zones.append({"rect": Rect2(x - 50, 45, 100, 195), "action": "belt_drag", "index": index})
	if work.stage == 0: _mechanism(7, Rect2(648, 40, 115, 95))
	if work.stage == 3:
		_sprite(2, Rect2(17, 57, 52, 49), "feed")
		_gauge(float(work.data.pressure), "CALDERA", Vector2(723, 83), 49)
		_sprite(11, Rect2(655, 184, 105, 77))

func readout() -> String:
	if work == null: return ""
	var d := work.data
	if work.complete: return "Trabajo terminado · ficha añadida al glosario"
	match workshop_id:
		"mine":
			return ["Cierre %.0f%% · purgas %d / 3" % [float(d.adjust) * 100, int(d.count)], "Vetas útiles %d / 3" % d.marks.size(), "Golpes seguros %d / 6" % int(d.count), "Fragmentos separados %d / 6" % d.marks.size(), "Tiro %.1f CFM · estable %.1f / 1,2 s" % [work.airflow(), work.stable], "Elevación %.0f%% · oscilación %.0f%%" % [float(d.crank) * 100, absf(float(d.sway)) * 100]][work.stage]
		"forge":
			return ["Arrabio %d / 3 · coque %d / 2" % [int(d.ore), int(d.fuel)], "Batido %.1f / 3 vueltas · hierro %.0f%%" % [float(d.angle) / TAU, float(d.heat) * 100], "Escorias retiradas %d / 3" % d.marks.size(), "Traslado con tenazas · hierro %.0f%%" % (float(d.heat) * 100), "Compactación %d / 8 golpes" % int(d.count), "Enfriamiento %.0f%% · compás %.0f%%" % [(1.0 - float(d.heat)) * 100, float(d.adjust) * 100]][work.stage]
		"engine":
			if work.stage == 5: return "Admisión %.0f%% · presión %.1f PSI · estable %.1f / 1,2 s" % [float(d.inlet) * 100, float(d.pressure) * 30.0, work.stable]
			return "Uniones %d · ajuste %.0f%%" % [d.bolts.size() + d.pipes.size() + d.marks.size(), float(d.adjust) * 100]
		"textile":
			if work.stage == 3: return "Turno %02d:%02d / 02:00 · fardos %d / 10%s" % [int(float(d.elapsed)) / 60, int(float(d.elapsed)) % 60, int(float(d.bales)), " · PARADA" if bool(d.emergency) else ""]
			return "Telar %d seleccionado · transmisión %d / 4" % [int(d.selected) + 1, d.belts.size() if work.stage == 0 else d.marks.size()]
	return ""

func cancel_drag() -> void:
	drag = {}
	if sparks != null: sparks.emitting = false

func _gui_input(event: InputEvent) -> void:
	if work == null or work.paused or work.complete: return
	var pos := Vector2.ZERO
	var press := false
	var release := false
	var moving := false
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT: return
		pos = event.position
		press = event.pressed
		release = not press
	elif event is InputEventScreenTouch:
		pos = event.position
		press = event.pressed
		release = not press
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		pos = event.position
		moving = true
	else: return
	work.pointer = pos / size
	if press:
		for zone in zones:
			if not (zone.rect as Rect2).has_point(pos): continue
			drag = zone.duplicate()
			if int(zone.index) >= 0: selected.emit(int(zone.index))
			if str(zone.action) in ["inspect", "hit", "skim", "fuel", "ore", "vent", "feed"]:
				requested.emit(str(zone.action), 0.0, int(zone.index))
				drag = {}
			break
		previous = pos
	if moving and not drag.is_empty(): _drag_motion(pos)
	if release and not drag.is_empty():
		var action_name := str(drag.action)
		var index := int(drag.index)
		if action_name == "sort_drag": requested.emit("sort", 1.0 if pos.x >= size.x * 0.5 else 0.0, index)
		elif action_name == "transfer_drag" and pos.x > size.x * 0.62: requested.emit("transfer", 0.0, index)
		elif action_name == "belt_drag": requested.emit("belt", 0.0, index)
		elif action_name == "loom" and work.stage == 2: requested.emit("clutch", 0.0, index)
		elif action_name == "loom" and work.stage == 3:
			if bool(work.data.broken[index]): requested.emit("knot" if bool(work.data.stopped[index]) else "stop", 0.0, index)
			elif bool(work.data.stopped[index]): requested.emit("restart", 0.0, index)
			else: requested.emit("refill", 0.0, index)
		elif action_name in ["engine_drag", "engine_part"]: _engine_drop(index)
		cancel_drag()
	accept_event()

func _drag_motion(pos: Vector2) -> void:
	var action_name := str(drag.action)
	var index := int(drag.index)
	if action_name in ["stir_drag", "crank_drag"]:
		var center := Vector2(470, 185) if action_name == "stir_drag" else Vector2(165, 195)
		if pos.distance_to(center) < 22.0 or previous.distance_to(center) < 22.0:
			previous = pos
			return
		var angle := wrapf((pos - center).angle() - (previous - center).angle(), -PI, PI)
		if action_name == "stir_drag": requested.emit("stir", minf(absf(angle), 0.4), index)
		elif angle > 0: requested.emit("crank", minf(angle / TAU, 0.12), index)
	elif action_name == "gate": requested.emit("adjust", clampf(1.0 - (pos.y - 65.0) / 210.0, 0, 1), index)
	elif action_name == "tension": requested.emit("adjust", clampf((pos.y - 55.0) / 105.0, 0, 1), index)
	elif action_name == "lever":
		var pivot := Vector2(677, 255) if workshop_id == "mine" else Vector2(588, 253)
		requested.emit("adjust", clampf(0.5 + atan2(pos.x - pivot.x, pivot.y - pos.y) / 1.6, 0, 1), index)
	elif action_name == "adjust": requested.emit("adjust", clampf((pos.x - 200.0) / 400.0, 0, 1), index)
	elif action_name == "cool_drag" and pos.y > previous.y: requested.emit("cool", minf((pos.y - previous.y) / 100.0, 0.12), index)
	previous = pos

func _engine_drop(index: int) -> void:
	index = int(work.data.selected) if index < 0 else index
	match work.stage:
		0:
			if int(work.data.count) == 0: requested.emit("piston", 0.0, index)
			elif not bool(work.data.packing): requested.emit("packing", 0.0, index)
			else: requested.emit("bolt", 0.0, index)
		1: requested.emit("pipe" if index in work.data.washers else "washer", 0.0, index)
		3: requested.emit("arm", 0.0, index)
		4: requested.emit("ball", 0.0, index)
