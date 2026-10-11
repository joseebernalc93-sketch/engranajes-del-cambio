extends Control
signal worked
const Model := preload("res://scripts/core/coal_extraction.gd")
const Art := preload("res://scripts/world/mining_workshop_art.gd")
const Mine := preload("res://scripts/world/mine_art.gd")
const Cart := preload("res://scripts/world/mining_cart_art.gd")
const Transport := preload("res://scripts/world/mining_transport_art.gd")
const HERO := preload("res://assets/gba/campesino_sheet_v2.png")
const CLOSE := preload("res://assets/phase2/coal_workface_closeup_v1.png")
const BENCH := preload("res://assets/phase2/mining_sorting_bench_v1.png")
const LOADING_BAY := preload("res://assets/phase2/mining_loading_bay_v1.png")
const NATIVE := Vector2(1152, 648)
const GOLD := Color("e7bf70")
const SPOTS := [Vector2(330, 230), Vector2(575, 200), Vector2(800, 285), Vector2(350, 365), Vector2(610, 365), Vector2(860, 390)]
const SUPPORT_SLOTS := [Rect2(180, 170, 150, 250), Rect2(500, 170, 150, 250), Rect2(820, 170, 150, 250)]
const VEINS := [Vector2(480, 295), Vector2(700, 295), Vector2(880, 295)]
const FRAGMENTS := [Vector2(350, 315), Vector2(550, 315), Vector2(750, 315), Vector2(350, 430), Vector2(550, 430), Vector2(750, 430)]
const COAL_BIN := Rect2(915, 330, 205, 230)
const STONE_BIN := Rect2(32, 400, 180, 200)
const RAIL_SLOTS := [Rect2(390, 378, 120, 35), Rect2(650, 378, 110, 103), Rect2(820, 378, 110, 103)]
const SWITCHES := [Rect2(325, 300, 70, 90), Rect2(575, 300, 70, 90)]
var model: Model
var selected: int = 0
var piece: int = 0
var bag: int = 0
var coal_bin: bool = true
var pointer := Vector2(330, 230)
var lamp := Vector2(330, 230)
var drag: int = -1
var drag_kind: String = ""
var touch_id: int = -1
var paused: bool = false
var background: TextureRect

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	add_child(background)

func configure(value: Model, saved: Dictionary) -> void:
	model = value
	selected = clampi(int(saved.get("selected", 0)), 0, 7)
	piece = clampi(int(saved.get("piece", 0)), 0, 2)
	bag = clampi(int(saved.get("bag", 0)), 0, 3)
	coal_bin = bool(saved.get("coal_bin", true))
	var coords: Array = saved.get("lamp", [330, 230])
	lamp = Vector2(float(coords[0]), float(coords[1])) if coords.size() == 2 else Vector2(330, 230)
	cancel_drag()
	sync()

func snapshot() -> Dictionary:
	return {"selected": selected, "piece": piece, "bag": bag, "coal_bin": coal_bin, "lamp": [lamp.x, lamp.y]}

func cancel_drag() -> void:
	drag = -1
	drag_kind = ""
	touch_id = -1

func sync() -> void:
	if model == null: return
	background.texture = CLOSE if model.step() == 0 else BENCH if model.step() in [3, 4] else LOADING_BAY if model.step() == 5 else Mine.EXTRACTION
	if model.step() == 0:
		if background.material == null:
			var light := ShaderMaterial.new()
			light.shader = preload("res://shaders/coal_inspector.gdshader")
			background.material = light
		background.material.set_shader_parameter("lamp_center", lamp / NATIVE)
		background.material.set_shader_parameter("motion_time", float(model.data.elapsed))
	else: background.material = null
	queue_redraw()

func _text(value: String, at: Vector2, color: Color = GOLD, height: int = 23) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, height, color)

func _fit(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var dimensions := texture.get_size() * minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	draw_texture_rect(texture, Rect2(rect.get_center() - dimensions / 2, dimensions), false, tint)

func support_stock(index: int) -> Rect2:
	return Rect2(170 + index * 320, 490, 180, 130)

func rail_stock(index: int) -> Rect2:
	return Rect2(190 + index * 300, 540, 180, 80)

func bag_rect(index: int) -> Rect2:
	return Rect2(100 + index * 255, 472, 165, 145)

func weight_position(index: int) -> Vector2:
	var assigned := int(model.data.assignments[index])
	if assigned < 0: return Vector2(88 + index * 140, 418)
	var ordinal := 0
	for previous in index:
		if int(model.data.assignments[previous]) == assigned: ordinal += 1
	return bag_rect(assigned).position + Vector2(40 + (ordinal % 3) * 35, 35 + (ordinal / 3) * 26)

func _draw() -> void:
	if model == null: return
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)
	match model.step():
		0: _draw_inspection()
		1: _draw_supports()
		2: _draw_extraction()
		3: _draw_sorting()
		4: _draw_balance()
		5: _draw_rails()
	draw_set_transform(Vector2.ZERO)

func _draw_inspection() -> void:
	for index in 6:
		_fit(Art.part(2, 2) if index < 3 else Art.part(6, 3), Rect2(SPOTS[index] - Vector2(46, 39), Vector2(92, 78)))
		if index < 3 and bool(model.data.recognised[index]):
			for offset in [-1, 1]: draw_rect(Rect2(SPOTS[index] + Vector2(offset * 52, -6), Vector2(4, 12)), GOLD)
		if selected == index: _text("·", SPOTS[index] + Vector2(-7, 60), Color("fff2cf"), 36)
	_fit(Art.part(0, 2), Rect2(lamp + Vector2(16, -10), Vector2(52, 83)))

func _draw_supports() -> void:
	for slot in 3:
		var rect: Rect2 = SUPPORT_SLOTS[slot]
		_fit(Art.part(Model.SUPPORT_ORDER[slot]), rect, Color(0.9, 0.8, 0.5, 0.32))
		if int(model.data.supports[slot]) >= 0:
			_fit(Art.part(int(model.data.supports[slot])), rect)
		if selected % 3 == slot: draw_rect(rect.grow(8), Color("e7bf7070"), false, 2)
		_text(str(slot + 1), Vector2(rect.get_center().x - 7, 458))
	for index in 3:
		if index in model.data.supports or (drag_kind == "support" and drag == index): continue
		_fit(Art.part(index), support_stock(index))
		if piece == index: draw_rect(support_stock(index).grow(4), GOLD, false, 2)
	if drag_kind == "support": _fit(Art.part(drag), Rect2(pointer - Vector2(75, 105), Vector2(150, 210)))

func _hero(x: float, floor_y: float, working: bool = false, walking: bool = false) -> void:
	var frame: int = [0, 1, 2, 1][int(float(model.data.elapsed) * 7.5) % 4] if walking else 1
	var texture := Mine.hero(HERO, Rect2(frame * 362, 724, 362, 362))
	var height := 135.0
	var dimensions := Vector2(height * texture.get_width() / texture.get_height(), height)
	draw_texture_rect(texture, Rect2(Vector2(x - dimensions.x / 2, floor_y - height), dimensions), false)
	if working:
		var swing := sin(clampf(float(model.data.impact_age) / 0.48, 0, 1) * PI)
		draw_set_transform(Vector2(x + 24, floor_y - 86) * size / NATIVE, -0.6 + swing * 1.2, size / NATIVE)
		# Transform includes board scaling, keeping the pick in the actor's hands.
		draw_texture_rect(Art.part(1, 2), Rect2(-10, -78, 74, 103), false)
		draw_set_transform(Vector2.ZERO, 0, size / NATIVE)

func _draw_extraction() -> void:
	Cart.rails(self)
	var active := int(model.data.selected_vein)
	for index in 3:
		var origin: Vector2 = VEINS[index]
		var count := int(model.data.damage[index])
		_fit(Art.part(2, 2), Rect2(origin - Vector2(45, 40), Vector2(90, 80)), Color("a8a293") if count == 3 else Color.WHITE)
		var path: Array[Vector2] = [Vector2(-21, -26), Vector2(-8, -7), Vector2(5, -14), Vector2(21, 8), Vector2(8, 28), Vector2(25, 33)]
		for segment in mini(count * 2, 5):
			draw_line(origin + path[segment], origin + path[segment + 1], Color("0a0807"), 4)
			draw_line(origin + path[segment] + Vector2(1, 0), origin + path[segment + 1] + Vector2(1, 0), Color("b3976c"), 2)
		_text("%d / 3" % count, origin + Vector2(-27, -64))
	_hero(VEINS[active].x - 90, 414, true)
	_wagon(Vector2(VEINS[active].x + 30, 414), 145, 0, int(model.data.damage[active]) == 3)
	var age := float(model.data.impact_age)
	if age < 0.5:
		for index in 12:
			var at: Vector2 = VEINS[active] + Vector2((index % 7 - 3) * 28, -30 - index * 3) * age + Vector2(0, 180 * age * age)
			draw_rect(Rect2(at.round(), Vector2(3, 3)), Color(0.64, 0.57, 0.4, 1 - age * 2))
	for index in 3:
		var fall := float(model.data.fall[index])
		if int(model.data.damage[index]) != 3 or fall > 0.9: continue
		for fragment in 4:
			var t := clampf(fall / 0.8, 0, 1)
			var pos: Vector2 = VEINS[index].lerp(Vector2(VEINS[index].x + 30 + fragment * 10 - 15, 347), t * t)
			_fit(Art.part(2, 2), Rect2(pos - Vector2(12, 12), Vector2(24, 24)))

func _draw_sorting() -> void:
	_fit(Art.part(1, 4), STONE_BIN)
	_wagon(Vector2(COAL_BIN.get_center().x, 549), 185, 0, int(model.data.collected) > 0)
	for index in 6:
		if int(model.data.sorted[index]) != 0 or (drag_kind == "fragment" and drag == index): continue
		_fit(Art.part(2, 2) if index % 2 == 0 else Art.part(6, 3), Rect2(FRAGMENTS[index] - Vector2(43, 36), Vector2(86, 72)))
		if selected % 6 == index: draw_rect(Rect2(FRAGMENTS[index] - Vector2(48, 41), Vector2(96, 82)), GOLD, false, 2)
	if drag_kind == "fragment": _fit(Art.part(2, 2) if drag % 2 == 0 else Art.part(6, 3), Rect2(pointer - Vector2(43, 36), Vector2(86, 72)))
	_text("PIEDRA", Vector2(63, 626))
	_text("HULLA", Vector2(973, 626))

func _draw_balance() -> void:
	_fit(Art.part(3), Rect2(560, 170, 160, 205))
	var tilt := clampf((model.bag_mass(bag) - model.target_mass()) * 0.075, -0.24, 0.24)
	var pivot := Vector2(640, 190)
	draw_set_transform(pivot * size / NATIVE, tilt, size / NATIVE)
	draw_texture_rect(Art.part(4), Rect2(-175, -20, 350, 40), false)
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)
	var left := pivot + Vector2(-163, 0).rotated(tilt)
	var right := pivot + Vector2(163, 0).rotated(tilt)
	_fit(Art.part(5), Rect2(left + Vector2(-55, 0), Vector2(110, 145)))
	_fit(Art.part(5), Rect2(right + Vector2(-55, 0), Vector2(110, 145)))
	_fit(Art.part(3, 4), Rect2(left + Vector2(-30, 65), Vector2(60, 75)))
	_fit(Art.part(2, 2), Rect2(right + Vector2(-28, 98), Vector2(56, 35)))
	_text("Costal %d: %d" % [bag + 1, model.bag_mass(bag)], left + Vector2(-65, 175))
	_text("Referencia: %d" % model.target_mass(), right + Vector2(-75, 175))
	for index in 4:
		var rect := bag_rect(index)
		_fit(Art.part(2, 4), rect)
		_text("%d / %d" % [model.bag_mass(index), model.target_mass()], rect.position + Vector2(50, 155), Color("bad291") if model.bag_mass(index) == model.target_mass() else GOLD)
		if bag == index: draw_rect(rect.grow(3), GOLD, false, 2)
	for index in 8:
		if drag_kind == "weight" and drag == index: continue
		_draw_weight(index, weight_position(index))
	if drag_kind == "weight": _draw_weight(drag, pointer)

func _draw_weight(index: int, pos: Vector2) -> void:
	var weight := int(model.masses()[index])
	var dimensions := Vector2(27 + weight * 9, 24 + weight * 7)
	_fit(Art.part(2, 2), Rect2(pos - dimensions / 2, dimensions))
	_text(str(weight), pos + Vector2(-6, dimensions.y / 2 + 20), Color("fff0ca"), 20)
	if selected % 8 == index: draw_rect(Rect2(pos - dimensions / 2 - Vector2(4, 4), dimensions + Vector2(8, 8)), GOLD, false, 1)

func _wagon(at: Vector2, width: float, travel: float = 0, coal: bool = false) -> void:
	for offset in [-width * 0.32, width * 0.32]:
		draw_set_transform((at + Vector2(float(offset), -14)) * size / NATIVE, travel / 14, size / NATIVE)
		draw_texture_rect(Cart.part(1), Rect2(-14, -14, 28, 28), false)
	draw_set_transform((at + Vector2(0, -40)) * size / NATIVE, 0, size / NATIVE)
	if coal: draw_texture_rect(Cart.part(2), Rect2(-width * 0.40, -40, width * 0.75, 27), false)
	draw_texture_rect(Cart.part(0), Rect2(-width / 2, -24, width, 50), false)
	draw_set_transform(Vector2.ZERO, 0, size / NATIVE)

func _track(start: Vector2, finish: Vector2) -> void:
	Transport.track(self, PackedVector2Array([start, finish]))

func _rail_corners(rect: Rect2, color: Color) -> void:
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var direction := (rect.get_center() - Vector2(corner)).sign()
		draw_line(corner, corner + Vector2(direction.x * 9, 0), color, 2)
		draw_line(corner, corner + Vector2(0, direction.y * 9), color, 2)

func _draw_rails() -> void:
	# Gaps and junctions remain visible; installed pieces bridge the real route.
	Transport.track(self, Transport.curve(Vector2(360, 395), Vector2(455, 475)))
	Transport.track(self, Transport.curve(Vector2(610, 395), Vector2(700, 510)))
	_track(Vector2(100, 395), Vector2(390, 395))
	_track(Vector2(510, 395), Vector2(650, 395))
	_track(Vector2(760, 465), Vector2(820, 465))
	_track(Vector2(930, 395), Vector2(1080, 395))
	for point in [Vector2(455, 475), Vector2(700, 510)]:
		for index in 5: _fit(Art.part(6, 3), Rect2(point + Vector2(index * 15 - 38, -15 - index % 2 * 16), Vector2(38, 30)))
	for slot in 3:
		var rect: Rect2 = RAIL_SLOTS[slot]
		if int(model.data.rails[slot]) >= 0:
			Transport.track(self, Transport.slot_path(int(model.data.rails[slot]), slot))
		else:
			Transport.track(self, Transport.slot_path(slot, slot), Transport.GAUGE, Color(0.85, 0.8, 0.6, 0.18))
		if selected % 3 == slot and not bool(model.data.travelling): _rail_corners(rect.grow(12), GOLD)
	for index in 2:
		_fit(Art.part(3 + int(model.data.switches[index]), 1), SWITCHES[index])
		var start: Vector2 = SWITCHES[index].get_center() + Vector2(0, 35)
		var correct := int(model.data.switches[index]) == int(Model.SWITCH_ORDER[index])
		# Iron switch tongues and rods replace the flat gold direction line.
		var finish := start + Vector2(43, 9 if correct else 30)
		draw_line(start + Vector2(0, 3), finish + Vector2(0, 3), Color("291b10"), 6)
		draw_line(start, finish, Color("646158"), 4)
		draw_line(start + Vector2(0, -1), finish + Vector2(0, -1), Color("baa17a"), 1)
		for end in [start, finish]: draw_rect(Rect2(end - Vector2(2, 2), Vector2(4, 4)), Color("c6a16a"))
		_text("Q" if index == 0 else "W", SWITCHES[index].position + Vector2(26, -8))
	_fit(Art.part(5, 1), Rect2(1000, 210, 125, 200))
	var pose := Transport.wagon_pose(model.cart_position())
	var moving := bool(model.data.travelling)
	Transport.loaded_wagon(self, pose, size / NATIVE, pose.origin.x - 155, moving)
	var handle: Vector2 = pose * Vector2(-92, -54)
	_hero(handle.x - 27, handle.y + 78, false, moving)
	for index in 3:
		if index in model.data.rails or (drag_kind == "rail" and drag == index): continue
		Transport.track(self, Transport.piece_path(index, rail_stock(index)))
		if piece == index: _rail_corners(rail_stock(index).grow(8), GOLD)
	if drag_kind == "rail": Transport.track(self, Transport.piece_path(drag, Rect2(pointer - Vector2(90, 40), Vector2(180, 80))))

func _nearest(at: Vector2, points: Array, radius: float) -> int:
	var best := -1
	var distance := radius
	for index in points.size():
		var current: float = at.distance_to(points[index])
		if current < distance:
			best = index
			distance = current
	return best

func pointer_down(at: Vector2) -> void:
	if paused or model == null or not model.allowed() or bool(model.data.travelling): return
	grab_focus()
	pointer = at
	match model.step():
		0:
			lamp = at
			var index := _nearest(at, SPOTS, 62)
			if index >= 0:
				selected = index
				model.recognise(index)
		1, 5:
			var support := model.step() == 1
			var slots: Array = SUPPORT_SLOTS if support else RAIL_SLOTS
			var placed: Array = model.data.supports if support else model.data.rails
			for index in 3:
				if slots[index].grow(10).has_point(at):
					selected = index
					if int(placed[index]) >= 0:
						drag = int(placed[index])
						piece = drag
						drag_kind = "support" if support else "rail"
					elif support: model.place_support(index, piece)
					else: model.place_rail(index, piece)
					worked.emit()
					sync()
					return
			for index in 3:
				if (support_stock(index) if support else rail_stock(index)).has_point(at) and not index in placed:
					piece = index
					drag = index
					drag_kind = "support" if support else "rail"
			if not support:
				for index in 2:
					if SWITCHES[index].grow(8).has_point(at): model.toggle_switch(index)
		2:
			if float(model.data.fall.min()) < 0.85: return
			var index := _nearest(at, VEINS, 72)
			if index >= 0:
				selected = index
				model.data.selected_vein = index
				model.hit(index)
		3:
			var index := _nearest(at, FRAGMENTS, 60)
			if index >= 0 and int(model.data.sorted[index]) == 0:
				selected = index
				drag = index
				drag_kind = "fragment"
		4:
			# Assigned pieces take priority over the bag underneath them.
			for index in range(7, -1, -1):
				if at.distance_to(weight_position(index)) < 35:
					selected = index
					drag = index
					drag_kind = "weight"
					break
			if drag < 0:
				for index in 4:
					if bag_rect(index).has_point(at): bag = index
	worked.emit()
	sync()

func pointer_move(at: Vector2) -> void:
	if paused or model == null: return
	pointer = at
	if model.step() == 0: lamp = at.clamp(Vector2.ZERO, NATIVE)
	sync()

func pointer_up(at: Vector2) -> void:
	if not paused and model != null and model.allowed():
		match drag_kind:
			"support", "rail":
				var slots: Array = SUPPORT_SLOTS if drag_kind == "support" else RAIL_SLOTS
				for index in 3:
					if slots[index].grow(12).has_point(at):
						if drag_kind == "support": model.place_support(index, drag)
						else: model.place_rail(index, drag)
						selected = index
						break
			"fragment":
				if COAL_BIN.has_point(at): model.sort(drag, true)
				elif STONE_BIN.has_point(at): model.sort(drag, false)
			"weight":
				for index in 4:
					if bag_rect(index).has_point(at):
						bag = index
						model.assign_piece(drag, index)
						break
				if at.y < 460: model.assign_piece(drag, -1)
	cancel_drag()
	worked.emit()
	sync()

func keyboard(event: InputEventKey) -> bool:
	if paused or model == null or not model.allowed() or event.echo or not event.pressed or bool(model.data.travelling): return false
	var key := event.keycode
	var count: int = [6, 3, 3, 6, 8, 3][model.step()]
	if key in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
		if model.step() == 2 and float(model.data.fall.min()) < 0.85: return true
		selected = posmod(selected + (-1 if key in [KEY_LEFT, KEY_A] else 1), count)
		if model.step() == 0: lamp = SPOTS[selected]
		if model.step() == 2: model.data.selected_vein = selected
	elif key >= KEY_1 and key <= KEY_4 and model.step() in [1, 4, 5]:
		if model.step() == 4: bag = int(key - KEY_1)
		else: piece = mini(2, int(key - KEY_1))
	elif key in [KEY_C, KEY_X] and model.step() == 3:
		coal_bin = key == KEY_C
		model.sort(selected % 6, coal_bin)
	elif key in [KEY_Q, KEY_W] and model.step() == 5:
		model.toggle_switch(0 if key == KEY_Q else 1)
	elif key == KEY_BACKSPACE and model.step() in [1, 4, 5]:
		match model.step():
			1: model.remove_support(selected % 3)
			4: model.empty_bag(bag)
			5: model.remove_rail(selected % 3)
	elif key in [KEY_SPACE, KEY_E]:
		match model.step():
			0: model.recognise(selected % 6)
			1: model.place_support(selected % 3, piece)
			2: model.hit(selected % 3)
			3: model.sort(selected % 6, coal_bin)
			4: model.assign_piece(selected % 8, bag)
			5: model.place_rail(selected % 3, piece)
	else: return false
	worked.emit()
	sync()
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
		elif not event.pressed and event.index == touch_id: pointer_up(event.position * ratio)
	elif event is InputEventScreenDrag:
		if event.index == touch_id: pointer_move(event.position * ratio)
	else: return
	accept_event()
