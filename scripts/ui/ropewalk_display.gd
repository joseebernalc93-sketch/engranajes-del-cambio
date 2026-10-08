class_name RopewalkDisplay
extends Control
## Tool coordinates, single-pointer switching and simultaneous touch crank/carriage control.
signal tool_selected(tool: String)
signal gesture_finished
const State = preload("res://scripts/ui/rope_work_state.gd")
const ROOM: Texture2D = preload("res://assets/gba/ui/ropewalk_backdrop_v2.png")
const WHEEL: Texture2D = preload("res://assets/gba/ui/ropewalk_wheel_v2.png")
const CART: Texture2D = preload("res://assets/gba/ui/ropewalk_carriage_v2.png")
const SACK: Texture2D = preload("res://assets/items/flour_sack_v1.png")
const HATCHEL: Texture2D = preload("res://assets/gba/ui/silas_hatchel_pixel_v1.png")
const COIL: Texture2D = preload("res://assets/gba/ui/silas_rope_coil_pixel_v1.png")
const BRAID: Texture2D = preload("res://assets/gba/ui/silas_rope_braid_pixel_v1.png")
const CARDING_ROOM: Texture2D = preload("res://assets/gba/ui/silas_carding_room_pixel_v2.png")
const PROOF_ROOM: Texture2D = preload("res://assets/gba/ui/silas_proof_room_pixel_v2.png")
const BRAKE_PARTS: Texture2D = preload("res://assets/gba/ui/silas_brake_parts_pixel_v2.png")
const BINDING_JIG: Texture2D = preload("res://assets/gba/ui/silas_binding_jig_pixel_v2.png")
const BINDING_THREAD: Texture2D = preload("res://assets/gba/ui/silas_binding_thread_pixel_v2.png")
const HEMP_BUNDLE: Texture2D = preload("res://assets/gba/ui/silas_hemp_bundle_pixel_v2.png")
const BRAKE_BASE_REGION := Rect2(199, 337, 1010, 427)
const BRAKE_ARM_REGION := Rect2(1526, 26, 131, 743)
const BINDING_JIG_REGION := Rect2(2, 0, 1252, 1230)
const BINDING_THREAD_REGION := Rect2(291, 78, 466, 1319)
const HEMP_BUNDLE_REGION := Rect2(10, 201, 1950, 399)
const HATCHEL_REGION := Rect2(6, 8, 1077, 1413)
const COIL_REGION := Rect2(173, 64, 1247, 946)
const BRAID_REGION := Rect2(22, 305, 2065, 134)
const FIBER: Shader = preload("res://shaders/hemp_fiber_carding.gdshader")
const SPIRAL: Shader = preload("res://shaders/rope_spiral_twist.gdshader")
const VIBRATE: Shader = preload("res://shaders/rope_tension_vibrate.gdshader")
const CART_WHEELS: Shader = preload("res://shaders/ropewalk_cart_wheels.gdshader")
const GOLD := Color("d6b271")
const LIGHT := Color("f0dfb5")
const GREEN := Color("a9ce8b")
const RED := Color("e59570")
const INK := Color("21180f")
const DESIGN_SIZE := Vector2(800, 420)
const CRANK_CENTER := Vector2(102, 200)
const THREAD_CENTER := Vector2(400, 215)
const PROOF_PULLEY_EXIT := Vector2(417, 77)
const TENSION_BRAKE_PIVOT := Vector2(625, 340)
const PROOF_BRAKE_PIVOT := Vector2(680, 316)
const BRAKE_SWING := 0.8
# Landmarks measured in the backdrop's normalized 800x420 coordinate space.
const HEAD_HOOKS := [Vector2(186, 117), Vector2(186, 150), Vector2(186, 184)]
const GUIDE_FACE := Vector2(403, 162)
const GUIDE_EXIT := Vector2(468, 162)
const GUIDE_REGION := Rect2(399, 117, 72, 94)
const TRACK_CONTACT_Y := 237.0
# The opaque wheel tread ends at source y=978/1060: 143 + 102 * 978/1060 = 237.
const CART_RECT := Rect2(-66, 143, 132, 102)
const QUALITY_TITLE_RECT := Rect2(225, 100, 390, 23)
const QUALITY_COIL_RECT := Rect2(249, 141, 222, 168)
@export var keyboard_speed: float = 210.0
@onready var world: Node2D = $World
@onready var art: Node2D = $World/ToolIllustrations
@onready var dust: GPUParticles2D = $World/FiberDust
var model: RopeWorkState
var active: bool = false
var fibers: Array[TextureRect] = []
var ropes: Array[Line2D] = []
var pointers: Dictionary = {}
var keyboard_direction: Vector2 = Vector2.ZERO
var keyboard_space_held: bool = false
var keyboard_release_required: bool = false
var particle_age: float = 1.0
var font: Font = ThemeDB.fallback_font
var plate_style: StyleBoxFlat
var cart_sprite: Sprite2D
var cart_material: ShaderMaterial
var asset_regions: Dictionary = {}
var backdrop_stage: int = -1

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_resize_canvas)
	for index in 4:
		if index < 3: _build_fiber(index)
		var rope := Line2D.new()
		rope.width = 8
		rope.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		# Line2D emits normalized UVs. Sample the transparent atlas explicitly in the shader.
		var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		pixel.fill(Color.WHITE)
		rope.texture = ImageTexture.create_from_image(pixel)
		rope.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rope.antialiased = false
		rope.material = ShaderMaterial.new()
		(rope.material as ShaderMaterial).shader = SPIRAL
		world.add_child(rope)
		world.move_child(rope, 0)
		ropes.append(rope)
	cart_sprite = Sprite2D.new()
	cart_sprite.texture = CART
	cart_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cart_sprite.scale = CART_RECT.size / CART.get_size()
	cart_material = ShaderMaterial.new()
	cart_material.shader = CART_WHEELS
	cart_sprite.material = cart_material
	world.add_child(cart_sprite)
	world.move_child(cart_sprite, world.get_child_count() - 3)
	_build_particles()
	_resize_canvas()

func _build_fiber(index: int) -> void:
	var fiber := TextureRect.new()
	fiber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atlas := AtlasTexture.new()
	atlas.atlas = HEMP_BUNDLE
	atlas.region = HEMP_BUNDLE_REGION
	atlas.filter_clip = true
	fiber.texture = atlas
	fiber.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fiber.stretch_mode = TextureRect.STRETCH_SCALE
	fiber.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fiber.position = Vector2(180, 124 + index * 82)
	fiber.size = Vector2(460, 42)
	var material := ShaderMaterial.new()
	material.shader = FIBER
	material.set_shader_parameter("fiber_region", Vector4(atlas.region.position.x / HEMP_BUNDLE.get_width(), atlas.region.position.y / HEMP_BUNDLE.get_height(), atlas.region.size.x / HEMP_BUNDLE.get_width(), atlas.region.size.y / HEMP_BUNDLE.get_height()))
	fiber.material = material
	world.add_child(fiber)
	world.move_child(fiber, 0)
	fibers.append(fiber)

func _build_particles() -> void:
	var particles := ParticleProcessMaterial.new()
	particles.direction = Vector3(-0.4, -1, 0)
	particles.spread = 45
	particles.initial_velocity_min = 12
	particles.initial_velocity_max = 55
	particles.gravity = Vector3(0, 105, 0)
	particles.angular_velocity_min = -80
	particles.angular_velocity_max = 120
	particles.scale_min = 0.5
	particles.scale_max = 1.3
	particles.color = Color("d4bc7c")
	dust.process_material = particles
	dust.amount = 32
	dust.lifetime = 0.7
	dust.visibility_rect = Rect2(-200, -200, 400, 400)
	var fleck := Image.create(8, 2, false, Image.FORMAT_RGBA8)
	fleck.fill(Color.WHITE)
	dust.texture = ImageTexture.create_from_image(fleck)
	dust.emitting = false

func bind(state: RopeWorkState) -> void:
	model = state
	cancel_gesture()
	refresh()

func _resize_canvas() -> void:
	if is_instance_valid(world): world.scale = size / DESIGN_SIZE
	queue_redraw()

func refresh() -> void:
	if not model or not is_node_ready(): return
	if backdrop_stage != model.stage:
		backdrop_stage = model.stage
		queue_redraw()
	for index in 3:
		fibers[index].visible = model.stage == State.Stage.CARD
		var material := fibers[index].material as ShaderMaterial
		material.set_shader_parameter("alignment", model.comb_passes[index] / 2.0)
		material.set_shader_parameter("stroke", (model.tool_position.x - 180) / 460 if model.tool_active and model.selected_bundle == index else 0)
	for index in 4:
		ropes[index].visible = model.stage in [State.Stage.MOUNT, State.Stage.TWIST, State.Stage.TENSION, State.Stage.PROOF]
		var single := model.stage >= State.Stage.TENSION
		if single and index in [1, 2]: ropes[index].visible = false
		var from: Vector2 = HEAD_HOOKS[mini(index, 2)]
		var to := GUIDE_FACE + Vector2(0, (index - 1) * 12)
		if single:
			from = HEAD_HOOKS[1]
			to = GUIDE_FACE
		if index == 3:
			from = GUIDE_EXIT
			to = carriage_anchor()
		if model.stage == State.Stage.PROOF:
			if index > 0: ropes[index].visible = false
			from = PROOF_PULLEY_EXIT
			to = proof_sack_hook()
		var points := PackedVector2Array()
		for sample in 49:
			var t := sample / 48.0
			var sag := (1.0 - clampf(model.tension / 100, 0, 1)) * (9 if index == 3 else 12)
			if model.stage == State.Stage.MOUNT: sag = 9
			if model.stage == State.Stage.PROOF: sag = 0
			points.append(from.lerp(to, t) + Vector2(0, 4 * t * (1 - t) * sag))
		ropes[index].points = points
		ropes[index].width = 9 if single or index == 3 else 4 * model.portions[index]
		ropes[index].modulate.a = 1.0 if model.stage != State.Stage.MOUNT or index == 3 or model.mounted[index] else 0.35
		var rope_material := ropes[index].material as ShaderMaterial
		rope_material.shader = VIBRATE if model.stage == State.Stage.TENSION else SPIRAL
		rope_material.set_shader_parameter("hemp_texture", BRAID)
		rope_material.set_shader_parameter("braid_region", Vector4(BRAID_REGION.position.x / BRAID.get_width(), BRAID_REGION.position.y / BRAID.get_height(), BRAID_REGION.size.x / BRAID.get_width(), BRAID_REGION.size.y / BRAID.get_height()))
		rope_material.set_shader_parameter("turns", model.twists)
		rope_material.set_shader_parameter("work_clock", model.clock)
		if model.stage == State.Stage.TENSION: rope_material.set_shader_parameter("tension", model.tension)
	cart_sprite.visible = model.stage in [State.Stage.MOUNT, State.Stage.TWIST, State.Stage.TENSION]
	cart_sprite.position = Vector2(model.carriage, CART_RECT.get_center().y)
	cart_material.set_shader_parameter("wheel_angle", (model.carriage - 660) / 14.0)
	dust.speed_scale = 0.0 if model.paused or not active else 1.0
	if model.paused or not active: dust.emitting = false
	art.queue_redraw()

func carriage_anchor() -> Vector2:
	return Vector2(model.carriage - 39, CART_RECT.position.y + 39)

func proof_sack_hook() -> Vector2:
	return Vector2(PROOF_PULLEY_EXIT.x, 210 + model.proof_force * 15)

func backdrop_for_stage(stage: int) -> Texture2D:
	if stage == State.Stage.CARD: return CARDING_ROOM
	if stage >= State.Stage.PROOF: return PROOF_ROOM
	return ROOM

func brake_grip(value: float, proof: bool) -> Vector2:
	var angle := lerpf(-BRAKE_SWING, BRAKE_SWING, value)
	return (PROOF_BRAKE_PIVOT if proof else TENSION_BRAKE_PIVOT) + Vector2(sin(angle), -cos(angle)) * 56

func _brake_value_at(point: Vector2, proof: bool) -> float:
	var offset := point - (PROOF_BRAKE_PIVOT if proof else TENSION_BRAKE_PIVOT)
	return inverse_lerp(-BRAKE_SWING, BRAKE_SWING, clampf(atan2(offset.x, -offset.y), -BRAKE_SWING, BRAKE_SWING))

func emit_work(action: String, point: Vector2) -> void:
	if action != "card" or DisplayServer.get_name() == "headless": return
	dust.position = point
	particle_age = 0

func physics_step(delta: float) -> void:
	if not model or not active or model.paused: return
	particle_age += delta
	dust.emitting = particle_age < 0.08
	_keyboard_step(delta)
	refresh()

func set_tool(tool: String) -> void:
	if not model or model.paused: return
	cancel_gesture()
	model.select_tool(tool)
	tool_selected.emit(tool)
	grab_focus()

func cancel_gesture() -> void:
	pointers.clear()
	keyboard_space_held = false
	keyboard_release_required = false
	keyboard_direction = Vector2.ZERO
	if model: model.cancel_gesture()

func handle_key(event: InputEventKey) -> bool:
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if key not in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE]: return false
	if event.echo: return true
	var value := 1.0 if event.pressed else 0.0
	if key in [KEY_LEFT, KEY_A]: keyboard_direction.x = -value
	elif key in [KEY_RIGHT, KEY_D]: keyboard_direction.x = value
	elif key in [KEY_UP, KEY_W]: keyboard_direction.y = -value
	elif key in [KEY_DOWN, KEY_S]: keyboard_direction.y = value
	elif key == KEY_SPACE:
		keyboard_space_held = event.pressed
		if not event.pressed:
			keyboard_release_required = false
			model.tool_active = false
			model.cranking = false
			model.release_wrap()
		elif not keyboard_release_required:
			if model.stage == State.Stage.CARD: model.begin_card(Vector2(180, 145 + model.selected_bundle * 82), model.selected_bundle)
			elif model.stage == State.Stage.MOUNT: model.mount(model.selected_bundle)
			elif model.stage == State.Stage.BIND:
				if model.binding_wraps == 3: model.pull_binding(100)
				else: model.begin_wrap()
			elif model.stage == State.Stage.PROOF and model.selected_tool == "sack":
				model.place_sack()
				if model.load_active: set_tool("lever")
	return true

func _keyboard_step(delta: float) -> void:
	var direction := keyboard_direction.x
	if model.stage in [State.Stage.TWIST, State.Stage.TENSION]:
		# Space always drives the wheel, leaving arrows free for the second control.
		model.cranking = keyboard_space_held
		var tool := "carriage" if model.stage == State.Stage.TWIST else "brake"
		model.adjust(tool, direction * delta * (38 if tool == "carriage" else 0.28) * (0.6 if model.easy else 1.0))
	elif model.stage == State.Stage.MOUNT: model.adjust(model.selected_tool, direction * delta * 0.25)
	elif model.stage == State.Stage.PROOF: model.adjust("lever", direction * delta * (0.18 if model.easy else 0.3))
	if not keyboard_space_held or keyboard_release_required: return
	if model.stage == State.Stage.CARD and model.tool_active:
		model.move_card(model.tool_position + Vector2(keyboard_speed * (0.65 if model.easy else 1.0) * delta, 0))
		if not model.tool_active: keyboard_release_required = true
	elif model.stage == State.Stage.BIND and model.wrap_active:
		model.turn_wrap(delta * TAU * 1.6 * model.pace())
		if not model.wrap_active: keyboard_release_required = true

func _gui_input(event: InputEvent) -> void:
	if not active or not model or model.paused: return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position * DESIGN_SIZE / size
		if event.pressed: _press(point, -1)
		else: _release(point, -1)
		accept_event()
	elif event is InputEventMouseMotion and pointers.has(-1):
		_motion(event.position * DESIGN_SIZE / size, -1)
		accept_event()
	elif event is InputEventScreenTouch:
		point = event.position * DESIGN_SIZE / size
		if event.pressed: _press(point, event.index)
		else: _release(point, event.index)
		accept_event()
	elif event is InputEventScreenDrag and pointers.has(event.index):
		_motion(event.position * DESIGN_SIZE / size, event.index)
		accept_event()

func _press(point: Vector2, id: int) -> void:
	if pointers.has(id): return
	if model.stage in [State.Stage.CARD, State.Stage.BIND] and not pointers.is_empty(): return
	grab_focus()
	var tool := model.selected_tool
	var mode := "tool"
	if model.stage == State.Stage.CARD:
		var index := clampi(int(round((point.y - 145) / 82)), 0, 2)
		var handle := false
		for bundle in 3:
			if Rect2(154, 90 + bundle * 82, 52, 75).has_point(point):
				index = bundle
				handle = true
				break
		tool = "card%d" % index
		model.select_tool(tool)
		model.begin_card(Vector2(180, 145 + index * 82) if handle else point, index)
	elif model.stage == State.Stage.MOUNT:
		for index in 3:
			if point.distance_to(HEAD_HOOKS[index]) <= 20:
				model.mount(index)
				return
		if point.y > 280:
			tool = "portion%d" % clampi(int((point.x - 184) / 155), 0, 2)
			mode = "bundle" if point.y >= 310 else "caliper"
	elif model.stage in [State.Stage.TWIST, State.Stage.TENSION]:
		if point.distance_to(CRANK_CENTER) < 95: tool = "crank"
		elif model.stage == State.Stage.TWIST: tool = "carriage"
		else: tool = "brake"
	elif model.stage == State.Stage.BIND:
		tool = "pull" if model.binding_wraps == 3 else "thread"
		if tool == "thread": model.begin_wrap()
	elif model.stage == State.Stage.PROOF:
		tool = "sack" if Rect2(110, 200, 110, 140).has_point(point) and not model.load_active else "lever"
	# Independent touch slots allow one finger to crank while another accompanies the carriage.
	for pointer in pointers.values():
		if pointer.tool == tool: return
	model.select_tool(tool)
	var center := CRANK_CENTER if tool == "crank" else THREAD_CENTER
	pointers[id] = {"tool": tool, "mode": mode, "start": point, "last": point, "angle": (point - center).angle(), "offset": model.carriage - point.x, "grip": model.tool_position - point if tool.begins_with("card") else Vector2.ZERO}
	tool_selected.emit(tool)
	refresh()

func _motion(point: Vector2, id: int) -> void:
	if not pointers.has(id) or model.paused: return
	var pointer: Dictionary = pointers[id]
	var tool := str(pointer.tool)
	if tool.begins_with("card"): model.move_card(point + Vector2(pointer.grip))
	elif tool.begins_with("portion"):
		# Caliper jaws transfer material between the two unmounted bundles, preserving total mass.
		if pointer.mode == "caliper": model.adjust(tool, (point.x - float(pointer.last.x)) / 150.0)
	elif tool == "crank" or tool == "thread":
		var center := CRANK_CENTER if tool == "crank" else THREAD_CENTER
		var radius := point.distance_to(center)
		if tool == "thread" and (radius < 35 or radius > (140 if model.easy else 105)):
			model.release_wrap()
			return
		var angle := (point - center).angle()
		var change := wrapf(angle - float(pointer.angle), -PI, PI)
		pointer.angle = angle
		if tool == "crank": model.turn_wheel(change)
		else: model.turn_wrap(change)
	elif tool == "carriage": model.adjust(tool, point.x + float(pointer.offset) - model.carriage)
	elif tool == "brake": model.adjust(tool, _brake_value_at(point, false) - model.brake)
	elif tool == "lever": model.adjust(tool, _brake_value_at(point, true) - model.proof_brake)
	pointer.last = point
	if pointers.has(id): pointers[id] = pointer
	refresh()

func _release(point: Vector2, id: int) -> void:
	if not pointers.has(id): return
	var pointer: Dictionary = pointers[id]
	pointers.erase(id)
	if not model.paused:
		match str(pointer.tool):
			"thread": model.release_wrap()
			"pull": model.pull_binding(point.y - float(pointer.start.y))
			"sack":
				if point.distance_to(proof_sack_hook() + Vector2(0, 35)) < 85:
					model.place_sack()
					if model.load_active: model.select_tool("lever")
			"portion0", "portion1", "portion2":
				var index := int(str(pointer.tool).right(1))
				if pointer.mode == "bundle" and point.distance_to(HEAD_HOOKS[index]) < 25: model.mount(index)
		model.tool_active = false
	tool_selected.emit(model.selected_tool)
	gesture_finished.emit()
	refresh()

func release_from_viewport(position: Vector2, id: int) -> bool:
	if not pointers.has(id): return false
	_release(get_global_transform_with_canvas().affine_inverse() * position * DESIGN_SIZE / size, id)
	return true

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	draw_texture_rect(backdrop_for_stage(model.stage if model else State.Stage.CARD), Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.01, 0.25))

func draw_tools(canvas: Node2D) -> void:
	if not model: return
	_plate(canvas, Rect2(14, 12, 290, 29))
	_text(canvas, Vector2(28, 32), "PISTA DE CORDELERÍA · TALLER DE SILAS", 12, GOLD)
	match model.stage:
		State.Stage.CARD: _draw_card(canvas)
		State.Stage.MOUNT: _draw_mount(canvas)
		State.Stage.TWIST, State.Stage.TENSION: _draw_machine(canvas)
		State.Stage.BIND: _draw_binding(canvas)
		State.Stage.PROOF: _draw_proof(canvas)
		State.Stage.COMPLETE: _draw_complete(canvas)

func _draw_card(c: Node2D) -> void:
	for index in 3:
		var y := 145.0 + index * 82
		_plate(c, Rect2(22, y - 25, 125, 53))
		_text(c, Vector2(32, y - 6), "MANOJO %d" % (index + 1), 13, GOLD)
		_text(c, Vector2(40, y + 17), "%d / 2 pasadas" % model.comb_passes[index], 12, GREEN if model.comb_passes[index] == 2 else LIGHT)
		c.draw_line(Vector2(180, y + 29), Vector2(640, y + 29), Color("9c855755"), 1)
		c.draw_line(Vector2(607, y + 24), Vector2(640, y + 29), GOLD, 2)
		var position := Vector2(180, y)
		if model.tool_active and model.selected_bundle == index: position = model.tool_position
		_sprite(c, HATCHEL, Rect2(position - Vector2(29, 61), Vector2(58, 76)), HATCHEL_REGION)
	_caption(c, "Peina a favor de la fibra · dos pasadas suaves por manojo")

func _draw_mount(c: Node2D) -> void:
	_draw_guide_and_anchor(c)
	for index in 3:
		var center: Vector2 = HEAD_HOOKS[index]
		c.draw_arc(center, 13, 0, TAU, 28, GREEN if model.mounted[index] else Color("d6b27188"), 1, true)
		_text(c, center + Vector2(18, 5), str(index + 1), 12, LIGHT)
		var origin := Vector2(230 + index * 155, 320)
		_cabo_plate(c, Rect2(origin - Vector2(46, 39), Vector2(144, 89)), model.mounted[index])
		var bundle_origin := origin
		for pointer in pointers.values():
			if pointer.tool == "portion%d" % index and pointer.mode == "bundle": bundle_origin += Vector2(pointer.last) - Vector2(pointer.start)
		_sprite(c, BRAID, Rect2(bundle_origin + Vector2(-26, -5), Vector2(89, 10 * model.portions[index])), BRAID_REGION)
		_sprite(c, BRAID, Rect2(bundle_origin + Vector2(-26, 4), Vector2(89, 9 * model.portions[index])), BRAID_REGION)
		_text(c, origin + Vector2(-32, 33), ["PRIMER CABO", "SEGUNDO CABO", "TERCER CABO"][index], 11, GREEN if model.mounted[index] else LIGHT)
		c.draw_rect(Rect2(origin + Vector2(76, 25), Vector2(7, 7)), GREEN if model.mounted[index] else Color("8a704b"))
		# Caliper reference notch and movable jaw show relative diameter without a menu.
		var jaw := 32.0 * model.portions[index]
		c.draw_rect(Rect2(origin + Vector2(-36, -30), Vector2(106, 7)), Color("292c29"))
		c.draw_rect(Rect2(origin + Vector2(-35, -29), Vector2(104, 4)), Color("989c91"))
		for tick in 18:
			c.draw_rect(Rect2(origin + Vector2(-32 + tick * 5, -29), Vector2(1, 4 if tick % 3 == 0 else 2)), INK)
		for x in [-16.0, -16.0 + jaw]:
			c.draw_rect(Rect2(origin + Vector2(x - 3, -30), Vector2(7, 44)), INK)
			c.draw_rect(Rect2(origin + Vector2(x - 2, -29), Vector2(4, 42)), Color("b9bcae"))
			c.draw_rect(Rect2(origin + Vector2(x - 1, -29), Vector2(1, 40)), Color("e3dfc5"))
		c.draw_rect(Rect2(origin + Vector2(-20 + jaw, -32), Vector2(10, 9)), Color("a8813c"))
		c.draw_line(origin + Vector2(16, -35), origin + Vector2(16, -22), GREEN, 3)
	_caption(c, "Reparte con el calibre · arrastra el manojo al gancho correspondiente")

func _draw_machine(c: Node2D) -> void:
	_draw_guide_and_anchor(c)
	c.draw_set_transform(CRANK_CENTER, model.wheel_angle)
	c.draw_texture_rect(WHEEL, Rect2(-83, -83, 166, 166), false)
	c.draw_set_transform(Vector2.ZERO)
	c.draw_circle(CRANK_CENTER, 10, GOLD)
	c.draw_line(CRANK_CENTER, CRANK_CENTER + Vector2(cos(model.wheel_angle), sin(model.wheel_angle)) * 60, GOLD, 6)
	c.draw_circle(CRANK_CENTER + Vector2(cos(model.wheel_angle), sin(model.wheel_angle)) * 60, 9, Color("694220"))
	if model.stage == State.Stage.TWIST:
		var target := model.ideal_carriage()
		c.draw_arc(Vector2(target, 282), 18, 0, PI, 20, GREEN, 3)
		_text(c, Vector2(target - 47, 321), "ACOMPAÑA", 12, GREEN)
		_text(c, Vector2(230, 69), "TORSIÓN Y ACORTAMIENTO", 15, GOLD)
		for turn in 5:
			c.draw_circle(Vector2(270 + turn * 28, 91), 6, GREEN if model.twists >= turn + 1 else INK)
	else:
		_draw_brake(c, model.brake, false)
		_text(c, Vector2(520, 385), "LIBERAR     FRENO     APRETAR", 12, GOLD)
		_text(c, Vector2(208, 100), "COMPACTACIÓN · %.1f / 3 s" % model.stable_seconds, 15, LIGHT)
	_gauge(c, Vector2(690, 85), 60, model.tension / 100, 0.45, 0.70, "TENSIÓN", 100)
	_caption(c, "Espacio: rueda · ← →: carro" if model.stage == State.Stage.TWIST else "Espacio: rueda · ← →: freno · conserva la aguja en verde")

func _draw_guide_and_anchor(c: Node2D) -> void:
	# Restore the original guide above the strands: they enter its mouth instead of crossing its face.
	c.draw_texture_rect_region(ROOM, GUIDE_REGION, Rect2(GUIDE_REGION.position / DESIGN_SIZE * ROOM.get_size(), GUIDE_REGION.size / DESIGN_SIZE * ROOM.get_size()))
	c.draw_rect(GUIDE_REGION, Color(0.05, 0.03, 0.01, 0.25))
	var anchor := carriage_anchor()
	c.draw_line(anchor + Vector2(7, 0), anchor + Vector2(22, 0), INK, 6)
	c.draw_line(anchor + Vector2(7, -1), anchor + Vector2(22, -1), Color("aaa89a"), 3)
	c.draw_arc(anchor, 7, 0, TAU, 22, INK, 4, true)
	c.draw_arc(anchor, 6, 0, TAU, 22, Color("b1ad96"), 2, true)

func _draw_binding(c: Node2D) -> void:
	_plate(c, Rect2(110, 76, 580, 277))
	_text(c, Vector2(135, 104), "REMATE ENCERADO · VISTA DE DETALLE", 14, GOLD)
	_sprite(c, BINDING_JIG, Rect2(310, 125, 180, 180), BINDING_JIG_REGION)
	_sprite(c, BRAID, Rect2(175, 194, 450, 42), BRAID_REGION)
	for wrap in model.binding_wraps:
		_sprite(c, BINDING_THREAD, Rect2(373 + wrap * 18, 188, 20, 55), BINDING_THREAD_REGION)
	# Small glints follow the engraved physical guide; no synthetic progress circle.
	for division in 32:
		var angle := division / 32.0 * TAU
		if model.wrap_angle > angle:
			var mark := THREAD_CENTER + Vector2(sin(angle), -cos(angle)) * 74
			c.draw_rect(Rect2(mark.round() - Vector2(1, 1), Vector2(3, 3)), GREEN)
	var end := THREAD_CENTER + Vector2(sin(model.wrap_angle), -cos(model.wrap_angle)) * 74
	if model.binding_wraps == 3:
		end = Vector2(430, 250)
		for pointer in pointers.values():
			if pointer.tool == "pull": end = pointer.last
		_draw_cord(c, Vector2(430, 230), end, 4)
		_plate(c, Rect2(414, 332, 34, 16))
		c.draw_rect(Rect2(420, 338, 22, 3), GREEN)
		_text(c, Vector2(468, 328), "TIRA HASTA AQUÍ", 12, GREEN)
	else: _draw_cord(c, THREAD_CENTER + Vector2(0, 17), end, 3)
	_sprite(c, COIL, Rect2(end - Vector2(12, 9), Vector2(24, 18)), COIL_REGION)
	_text(c, Vector2(145, 329), "%d / 3 vueltas aseguradas" % model.binding_wraps, 15, LIGHT)
	_caption(c, "Gira en sentido horario · suelta después de cada vuelta · tira para cerrar")

func _draw_proof(c: Node2D) -> void:
	if model.load_active or model.proof_checks > 0: _sprite(c, SACK, Rect2(proof_sack_hook() - Vector2(41, 2), Vector2(82, 88)), _asset_region(SACK))
	if not model.load_active:
		var loose := Vector2(152, 250)
		for pointer in pointers.values():
			if pointer.tool == "sack": loose = pointer.last
		_sprite(c, SACK, Rect2(loose, Vector2(70, 78)), _asset_region(SACK))
		_text(c, Vector2(119, 341), "SACO %d" % mini(model.proof_checks + 1, 3), 14, GOLD)
		_text(c, Vector2(303, 380), "Arrastra a la polea", 13, LIGHT)
	_draw_brake(c, model.proof_brake, true)
	_text(c, Vector2(610, 360), "FRENO DE CARGA", 13, GOLD)
	_gauge(c, Vector2(660, 143), 78, model.proof_force, model.load_target() - model.load_green(), model.load_target() + model.load_green(), "LIBRAS · lb", 100)
	c.draw_arc(Vector2(660, 143), 86, -PI * 0.8, -PI * 0.8 + model.stable_seconds / 1.2 * PI * 1.6, 60, GREEN, 3, true)
	_caption(c, "Cargas %d / 3 · %.1f / 1,2 s · freno a la derecha: amortiguar" % [model.proof_checks, model.stable_seconds])

func _draw_complete(c: Node2D) -> void:
	_plate(c, Rect2(200, 82, 440, 260))
	_sprite(c, COIL, QUALITY_COIL_RECT, COIL_REGION)
	_text(c, QUALITY_TITLE_RECT.position + Vector2(35, 17), "SELLO DE CALIDAD ARTESANAL", 16, GOLD)
	c.draw_line(Vector2(225, 126), Vector2(615, 126), Color("8f6a36"), 1)
	# Stamped brass seal, separated from the rope and its heading.
	c.draw_colored_polygon(PackedVector2Array([Vector2(536, 237), Vector2(552, 244), Vector2(568, 237), Vector2(571, 307), Vector2(552, 297), Vector2(533, 307)]), Color("725035"))
	for ring in [38, 34, 30]:
		c.draw_circle(Vector2(552, 219), ring, GOLD if ring == 38 else (INK if ring == 34 else Color("4b633c")))
	c.draw_polyline(PackedVector2Array([Vector2(537, 219), Vector2(548, 230), Vector2(569, 206)]), LIGHT, 4, false)
	_text(c, Vector2(519, 273), "APROBADA", 11, GOLD)
	_caption(c, "Tres cargas aprobadas · soga resistente para las poleas del molino")

func _gauge(c: Node2D, center: Vector2, radius: float, value: float, low: float, high: float, title: String, units: int) -> void:
	c.draw_circle(center, radius + 4, INK)
	c.draw_arc(center, radius, 0, TAU, 80, GOLD, 3, true)
	c.draw_circle(center, radius - 5, Color("ddd0a4"))
	var start := -PI * 0.8
	var span := PI * 1.6
	c.draw_arc(center, radius - 13, start - PI / 2 + low * span, start - PI / 2 + high * span, 28, Color("638b4d"), 9, true)
	for tick in 21:
		var angle := start + tick / 20.0 * span
		var direction := Vector2(sin(angle), -cos(angle))
		c.draw_line(center + direction * (radius - 22), center + direction * (radius - 10), Color("493a23"), 1 if tick % 5 else 2)
		if tick % 5 == 0: _text(c, center + direction * (radius - 33) - Vector2(7, -4), str(tick * units / 20), 10, INK)
	# Gauge uses the same upward-zero convention as its ticks and green band.
	var angle := start + clampf(value, 0, 1) * span
	c.draw_line(center, center + Vector2(sin(angle), -cos(angle)) * (radius - 22), Color("834926"), 3)
	c.draw_circle(center, 6, GOLD)
	_text(c, center + Vector2(-42, radius + 22), title, 12, GOLD)

func _plate(c: Node2D, rect: Rect2) -> void:
	c.draw_style_box(_plate_style(), rect)

func _sprite(c: Node2D, texture: Texture2D, rect: Rect2, region: Rect2) -> void:
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.draw_texture_rect_region(texture, rect, region)

func _asset_region(texture: Texture2D) -> Rect2:
	var key := str(texture.get_instance_id())
	if asset_regions.has(key): return asset_regions[key]
	var source := texture.get_image()
	var region := source.get_used_rect()
	asset_regions[key] = Rect2(region)
	return Rect2(region)

func _draw_brake(c: Node2D, value: float, proof: bool) -> void:
	var pivot := PROOF_BRAKE_PIVOT if proof else TENSION_BRAKE_PIVOT
	_sprite(c, BRAKE_PARTS, Rect2(pivot - Vector2(58, 18), Vector2(116, 48)), BRAKE_BASE_REGION)
	c.draw_set_transform(pivot, lerpf(-BRAKE_SWING, BRAKE_SWING, value))
	_sprite(c, BRAKE_PARTS, Rect2(-8, -64, 16, 68), BRAKE_ARM_REGION)
	c.draw_set_transform(Vector2.ZERO)

func _draw_cord(c: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	c.draw_set_transform(from, (to - from).angle())
	_sprite(c, BRAID, Rect2(0, -width * 0.5, from.distance_to(to), width), BRAID_REGION)
	c.draw_set_transform(Vector2.ZERO)

func _cabo_plate(c: Node2D, rect: Rect2, complete: bool) -> void:
	# Oak grain, iron edging and inset brass corners keep the gauge part of the workshop.
	c.draw_rect(rect, Color("17130f"))
	c.draw_rect(rect.grow(-2), Color("725033"))
	c.draw_rect(rect.grow(-4), Color("302315"))
	for grain in 11:
		var y := rect.position.y + 7 + grain * 7
		c.draw_line(Vector2(rect.position.x + 5, y), Vector2(rect.end.x - 5, y), Color("382919"), 2)
	c.draw_rect(rect.grow(-3), Color("879468") if complete else Color("ac8549"), false, 1)
	for corner in [rect.position + Vector2(6, 6), Vector2(rect.end.x - 7, rect.position.y + 6), Vector2(rect.position.x + 6, rect.end.y - 7), rect.end - Vector2(7, 7)]:
		c.draw_rect(Rect2(corner - Vector2(2, 2), Vector2(5, 5)), Color("b99557"))
		c.draw_rect(Rect2(corner, Vector2(2, 2)), INK)

func _plate_style() -> StyleBoxFlat:
	if plate_style: return plate_style
	var style := StyleBoxFlat.new()
	style.bg_color = Color("21180fee")
	style.border_color = Color("a4824f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	plate_style = style
	return style

func _text(c: Node2D, position: Vector2, text: String, font_size: int, color: Color) -> void:
	c.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _caption(c: Node2D, text: String) -> void:
	_plate(c, Rect2(18, 390, 764, 27))
	_text(c, Vector2(30, 409), text, 13, LIGHT)
