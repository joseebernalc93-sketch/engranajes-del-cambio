class_name LumberWorkbenchDisplay
extends Control
## One coordinate space for pointer, touch, keyboard, physical bodies and tool art.
signal tool_selected(tool: String)
signal gesture_finished
signal offcut_landed
const State = preload("res://scripts/ui/lumber_work_state.gd")
const WOOD: Texture2D = preload("res://assets/gba/ui/bruno_workpieces_v2.png")
const ROOM: Texture2D = preload("res://assets/gba/ui/bruno_workshop_backdrop_v2.png")
const TOOLS: Texture2D = preload("res://assets/gba/ui/lumber_tools_sheet_v1.png")
const SACK: Texture2D = preload("res://assets/items/flour_sack_v1.png")
const LEVER_PARTS: Texture2D = preload("res://assets/gba/ui/silas_brake_parts_pixel_v2.png")
const LEVER_BASE_REGION := Rect2(199, 337, 1010, 427)
const LEVER_ARM_REGION := Rect2(1526, 26, 131, 743)
const LEVER_PIVOT := Vector2(718, 300)
const LEVER_SWING := 0.8
const SURFACE: Shader = preload("res://shaders/wood_surface_smooth.gdshader")
const CURVING: Shader = preload("res://shaders/wood_curving.gdshader")
const BRASS := Color("d5ad67")
const LIGHT := Color("f4dfac")
const INK := Color("24180e")
const GREEN := Color("a5c985")
const RED := Color("df8b68")
const DESIGN_SIZE := Vector2(800, 420)
@export var keyboard_speed: float = 240.0
@onready var world: Node2D = $World
@onready var timber: Polygon2D = $World/Timber
@onready var art: Node2D = $World/ToolIllustrations
@onready var lens: ColorRect = $World/InspectorLens
@onready var lens_backbuffer: BackBufferCopy = $World/LensBackBuffer
@onready var incision: Line2D = $World/Incision
@onready var offcut: RigidBody2D = $World/Offcut
@onready var dust: GPUParticles2D = $World/Sawdust
@onready var shavings: GPUParticles2D = $World/Shavings
var model: LumberWorkState
var active: bool = false
var pointer_id: int = -2
var pointer_tool: String = ""
var pointer_start: Vector2 = Vector2.ZERO
var pointer_last: Vector2 = Vector2.ZERO
var pointer_angle: float = 0.0
var pointer_offset: Vector2 = Vector2.ZERO
var keyboard_direction: Vector2 = Vector2.ZERO
var keyboard_space_held: bool = false
var keyboard_release_required: bool = false
var offcut_released: bool = false
var surface_material: ShaderMaterial
var bend_material: ShaderMaterial
var dust_age: float = 1.0
var shavings_age: float = 1.0
var font: Font = ThemeDB.fallback_font
var plate_styles: Dictionary = {}

func _ready() -> void:
	resized.connect(_resize_canvas)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_mesh()
	_build_particles(dust, false)
	_build_particles(shavings, true)
	offcut.contact_monitor = true
	offcut.max_contacts_reported = 4
	offcut.body_entered.connect(func(_body: Node): offcut_landed.emit())
	_resize_canvas()

func bind(state: LumberWorkState) -> void:
	model = state
	offcut.freeze = true
	offcut.position = Vector2(630, 228)
	offcut.rotation = 0
	offcut.linear_velocity = Vector2.ZERO
	offcut.angular_velocity = 0
	offcut_released = model.cuts >= 5
	offcut.visible = false
	cancel_gesture()
	refresh()

func _resize_canvas() -> void:
	if is_instance_valid(world): world.scale = size / DESIGN_SIZE
	queue_redraw()

func _build_mesh() -> void:
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var faces: Array[PackedInt32Array] = []
	for index in 65:
		var fraction := index / 64.0
		points.append(Vector2(72 + fraction * 620, 184))
		points.append(Vector2(72 + fraction * 620, 272))
		uv.append(Vector2(fraction, 0) * WOOD.get_size())
		uv.append(Vector2(fraction, 1) * WOOD.get_size())
		if index < 64: faces.append(PackedInt32Array([index * 2, index * 2 + 2, index * 2 + 3, index * 2 + 1]))
	timber.polygon = points
	timber.texture = WOOD
	timber.uv = uv
	timber.polygons = faces
	surface_material = ShaderMaterial.new()
	surface_material.shader = SURFACE
	surface_material.set_shader_parameter("wood_atlas", WOOD)
	bend_material = ShaderMaterial.new()
	bend_material.shader = CURVING
	bend_material.set_shader_parameter("wood_atlas", WOOD)
	timber.material = surface_material
	var sprite := offcut.get_node("Wood") as Sprite2D
	var atlas := AtlasTexture.new()
	atlas.atlas = WOOD
	atlas.region = Rect2(1210, 427, 293, 201)
	sprite.texture = atlas
	sprite.scale = Vector2(124, 88) / atlas.get_size()

func _build_particles(particles: GPUParticles2D, curled: bool) -> void:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(-0.45, -1, 0)
	process.spread = 35
	process.initial_velocity_min = 35 if curled else 15
	process.initial_velocity_max = 90 if curled else 65
	process.gravity = Vector3(0, 170, 0)
	process.scale_min = 0.5
	process.scale_max = 1.1
	process.angular_velocity_min = -150
	process.angular_velocity_max = 180
	process.color = Color("edca8b")
	particles.process_material = process
	particles.amount = 22 if curled else 36
	particles.lifetime = 0.8
	particles.visibility_rect = Rect2(-180, -180, 360, 430)
	var image := Image.create(18 if curled else 5, 14 if curled else 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	if curled:
		for step in 60:
			var t := step / 59.0 * TAU * 1.4
			var radius := 5.5 - step / 59.0 * 3.5
			var point := Vector2(9 + cos(t) * radius, 7 + sin(t) * radius)
			image.set_pixel(clampi(int(point.x), 0, 17), clampi(int(point.y), 0, 13), Color.WHITE)
	else: image.fill(Color.WHITE)
	particles.texture = ImageTexture.create_from_image(image)
	particles.emitting = false

func refresh() -> void:
	if not model or not is_node_ready(): return
	timber.material = bend_material if model.stage == State.Stage.LOAD else surface_material
	var lanes := Vector4.ZERO
	for index in 4:
		var amount := 1.0 if index < model.passes else 0.0
		if model.stage == State.Stage.PLANE and index == model.passes and model.tool_active and model.depth_safe(): amount = model.stroke_distance / 496.0
		lanes[index] = amount
	for material in [surface_material, bend_material]:
		material.set_shader_parameter("lane_progress", lanes)
		material.set_shader_parameter("cut_progress", model.cuts / 5.0)
		material.set_shader_parameter("polished", model.passes == 4)
		material.set_shader_parameter("inspection", model.stage == State.Stage.INSPECT)
	bend_material.set_shader_parameter("deflection", model.deflection * 2.5)
	lens.visible = active and model.stage == State.Stage.INSPECT and model.selected_tool == "lens"
	lens.position = model.lens_position - Vector2(44, 44)
	# Viewport copying keeps screen UV correct through resized/scaled modal canvases.
	# It is disabled entirely outside the inspection lens.
	lens_backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if lens.visible else BackBufferCopy.COPY_MODE_DISABLED
	(lens.material as ShaderMaterial).set_shader_parameter("lens_screen_size", lens.size * world.scale * get_global_transform().get_scale() / get_viewport_rect().size)
	incision.clear_points()
	if model.stage == State.Stage.MEASURE and model.tool_active:
		incision.add_point(model.stroke_start)
		incision.add_point(model.tool_position)
	offcut.freeze = not active or model.paused or not offcut_released
	dust.speed_scale = 0.0 if not active or model.paused else 1.0
	shavings.speed_scale = dust.speed_scale
	if active and not model.paused and model.cuts >= 5 and not offcut_released:
		offcut_released = true
		offcut.show()
		offcut.freeze = false
		offcut.linear_velocity = Vector2(25, 5)
		offcut.angular_velocity = 0.7
	world.position = Vector2(sin(model.impact_age * 170) * 1.7, 0) if model.impact_age < 0.1 and active and not model.paused else Vector2.ZERO
	art.queue_redraw()

func emit_work(action: String, point: Vector2) -> void:
	if DisplayServer.get_name() == "headless": return
	if action in ["scribe", "saw"]:
		dust.position = point
		dust_age = 0
	elif action == "plane":
		shavings.position = point
		shavings_age = 0

func physics_step(delta: float) -> void:
	if not model or not active or model.paused: return
	dust_age += delta
	shavings_age += delta
	dust.emitting = dust_age < 0.08
	shavings.emitting = shavings_age < 0.08
	if keyboard_direction != Vector2.ZERO or keyboard_space_held: _keyboard_step(delta)
	refresh()

func set_tool(tool: String) -> void:
	if not model or model.paused: return
	cancel_gesture()
	model.selected_tool = tool
	tool_selected.emit(tool)
	refresh()

func handle_key(event: InputEventKey) -> bool:
	var key := event.physical_keycode if event.physical_keycode else event.keycode
	if key not in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S, KEY_SPACE]: return false
	if event.echo: return true
	var value := 1.0 if event.pressed else 0.0
	match key:
		KEY_LEFT, KEY_A: keyboard_direction.x = -value if event.pressed or keyboard_direction.x < 0 else keyboard_direction.x
		KEY_RIGHT, KEY_D: keyboard_direction.x = value if event.pressed or keyboard_direction.x > 0 else keyboard_direction.x
		KEY_UP, KEY_W: keyboard_direction.y = -value if event.pressed or keyboard_direction.y < 0 else keyboard_direction.y
		KEY_DOWN, KEY_S: keyboard_direction.y = value if event.pressed or keyboard_direction.y > 0 else keyboard_direction.y
		KEY_SPACE:
			keyboard_space_held = event.pressed
			if not event.pressed:
				keyboard_release_required = false
				model.cancel_tool()
				gesture_finished.emit()
			elif model.selected_tool.begins_with("wedge"): model.hammer(int(model.selected_tool.right(1)))
			elif model.stage == State.Stage.INSPECT and model.selected_tool == "template": model.confirm()
			elif model.stage == State.Stage.LOAD and model.selected_tool == "sack": model.place_sack()
	return true

func _keyboard_step(delta: float) -> void:
	var tool := model.selected_tool
	var direction := keyboard_direction
	if tool == "lens": model.lens_position = (model.lens_position + direction * delta * 150).clamp(Vector2(44, 44), Vector2(756, 376))
	elif tool == "template": model.adjust(tool, direction.x * delta * 130)
	elif tool == "rule": model.adjust(tool, direction.x * delta * (12 if model.easy else 22))
	elif tool == "square": model.adjust(tool, direction.x * delta * (3 if model.easy else 6))
	elif tool in ["vice", "depth", "lever"]: model.adjust(tool, direction.x * delta * (0.16 if model.easy else 0.24))
	elif keyboard_space_held and not keyboard_release_required:
		var start := Vector2.ZERO
		match tool:
			"scribe": start = Vector2(98 if model.marked_lines == 0 else State.CUT_X, 184)
			"saw": start = Vector2(466 if model.cuts % 2 == 0 else 636, 202)
			"plane": start = Vector2(72, model.lane_y())
			_: return
		if tool == "saw" and not model.easy and is_zero_approx(direction.x): return
		if not model.tool_active: model.begin_tool(start)
		if not model.tool_active: return
		var target := model.tool_position
		if tool == "scribe": target.y += delta * 65
		elif tool == "saw":
			var expected := 1.0 if model.cuts % 2 == 0 else -1.0
			target.x += (direction.x if direction.x else expected) * delta * keyboard_speed * (2.0 / 3.0 if model.easy else 1.0)
		else: target.x += delta * (190 if model.easy else 280)
		model.move_tool(target)
		if not model.tool_active: keyboard_release_required = true

func cancel_gesture() -> void:
	pointer_id = -2
	pointer_tool = ""
	pointer_offset = Vector2.ZERO
	keyboard_direction = Vector2.ZERO
	keyboard_space_held = false
	keyboard_release_required = false
	if model: model.cancel_tool()
	if is_node_ready():
		dust.emitting = false
		shavings.emitting = false

func _gui_input(event: InputEvent) -> void:
	if not active or not model or model.paused: return
	var point := Vector2.ZERO
	var pressed := false
	var released := false
	var identity := -1
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT: return
		point = event.position * DESIGN_SIZE / size
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion: point = event.position * DESIGN_SIZE / size
	elif event is InputEventScreenTouch:
		point = event.position * DESIGN_SIZE / size
		pressed = event.pressed
		released = not event.pressed
		identity = event.index
	elif event is InputEventScreenDrag:
		point = event.position * DESIGN_SIZE / size
		identity = event.index
	else: return
	if pressed and pointer_id == -2:
		pointer_id = identity
		pointer_start = point
		pointer_last = point
		_pointer_press(point)
		grab_focus()
	elif pointer_id == identity:
		if released:
			_pointer_release(point)
			pointer_id = -2
			pointer_tool = ""
			gesture_finished.emit()
		else: _pointer_move(point)
	accept_event()

func _pointer_press(point: Vector2) -> void:
	var tool := model.selected_tool
	if model.stage == State.Stage.SECURE:
		if Rect2(605, 184, 86, 88).has_point(point):
			model.confirm()
			return
		if model.selected_tool.begins_with("wedge"):
			var wedge := int(model.selected_tool.right(1))
			if Rect2(118 + wedge * 210, 135, 72, 105).has_point(point):
				pointer_tool = model.selected_tool
				return
		for index in 3:
			if point.distance_to(Vector2(150 + index * 210, 282 if model.wedge_inserted[index] else 360)) < 38:
				model.selected_tool = "wedge%d" % index
				pointer_tool = model.selected_tool
				tool_selected.emit(pointer_tool)
				return
		if point.distance_to(Vector2(718, 295)) < 58: tool = "vice"
	elif model.stage == State.Stage.MEASURE:
		if point.distance_to(Vector2(72 + model.length_cm / 200 * 620, 147)) < 28: tool = "rule"
		elif point.distance_to(Vector2(568, 115)) < 28: tool = "square"
	elif model.stage == State.Stage.PLANE and point.distance_to(Vector2(730, 206)) < 45: tool = "depth"
	elif model.stage == State.Stage.LOAD:
		if Rect2(300, 76, 85, 95).has_point(point) and not model.load_active: tool = "sack"
		elif point.distance_to(LEVER_PIVOT) < 78: tool = "lever"
	model.selected_tool = tool
	pointer_tool = tool
	tool_selected.emit(tool)
	if tool in ["scribe", "saw", "plane"]:
		var grip := Vector2.ZERO
		var bounds := Rect2()
		match tool:
			"scribe":
				grip = Vector2(98 if model.marked_lines == 0 else State.CUT_X, 184)
				bounds = Rect2(grip - Vector2(20, 38), Vector2(55, 60))
			"saw":
				grip = Vector2(466 if model.cuts % 2 == 0 else 636, 202)
				bounds = Rect2(grip - Vector2(125, 100), Vector2(250, 135))
			"plane":
				grip = Vector2(72, model.lane_y())
				bounds = Rect2(grip - Vector2(40, 60), Vector2(120, 85))
		if bounds.has_point(point):
			pointer_offset = point - grip
			model.begin_tool(grip)
	if tool in ["vice", "depth"]:
		var center := Vector2(718, 295) if tool == "vice" else Vector2(730, 206)
		pointer_angle = (point - center).angle()

func _pointer_move(point: Vector2) -> void:
	match pointer_tool:
		"template": model.adjust("template", point.x - pointer_last.x)
		"lens": model.lens_position = point.clamp(Vector2(44, 44), Vector2(756, 376))
		"rule": model.length_cm = clampf((point.x - 72) / 620 * 200, 100, 190)
		"square": model.square_angle = clampf(90 + rad_to_deg((point - Vector2(568, 184)).angle() + PI / 2), 78, 102)
		"vice", "depth":
			var center := Vector2(718, 295) if pointer_tool == "vice" else Vector2(730, 206)
			var angle := (point - center).angle()
			model.adjust(pointer_tool, wrapf(angle - pointer_angle, -PI, PI) / TAU * 0.6)
			pointer_angle = angle
		"lever":
			var offset := point - LEVER_PIVOT
			model.counterforce = inverse_lerp(-LEVER_SWING, LEVER_SWING, clampf(atan2(offset.x, -offset.y), -LEVER_SWING, LEVER_SWING))
		"scribe", "saw", "plane": model.move_tool(point - pointer_offset)
	pointer_last = point
	refresh()

func _pointer_release(point: Vector2) -> void:
	if pointer_tool.begins_with("wedge"):
		var index := int(pointer_tool.right(1))
		if not model.wedge_inserted[index]:
			if point.distance_to(Vector2(150 + index * 210, 282)) < 40: model.insert_wedge(index)
		elif point.y - pointer_start.y > 18 or point.distance_to(pointer_start) < 12: model.hammer(index)
	elif pointer_tool == "sack" and Rect2(250, 145, 180, 130).has_point(point): model.place_sack()
	model.cancel_tool()
	refresh()

func release_from_viewport(point: Vector2, identity: int) -> bool:
	if pointer_id != identity: return false
	var local := get_global_transform_with_canvas().affine_inverse() * point
	_pointer_release(local * DESIGN_SIZE / size)
	pointer_id = -2
	pointer_tool = ""
	gesture_finished.emit()
	return true

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / DESIGN_SIZE)
	draw_texture_rect(ROOM, Rect2(Vector2.ZERO, DESIGN_SIZE), false, Color(0.66, 0.60, 0.49))
	draw_style_box(_plate_style(Color("20170ddc"), Color("715438")), Rect2(22, 128, 756, 208))
	for leg in [102, 602]:
		draw_rect(Rect2(leg, 320, 22, 88), Color("51351e"))
		draw_rect(Rect2(leg + 3, 320, 3, 88), Color("967044"))
	draw_style_box(_plate_style(Color("5a3d25"), Color("bc9052")), Rect2(32, 308, 736, 26))
	draw_string(font, Vector2(42, 32), "ISLA LACUSTRE  /  TALLER DE BRUNO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LIGHT)
	draw_line(Vector2(42, 42), Vector2(758, 42), Color("a67c4866"))
	draw_set_transform(Vector2.ZERO)

func _plate_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var key := str(fill) + str(edge)
	if plate_styles.has(key): return plate_styles[key] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	plate_styles[key] = style
	return style

func draw_tools(canvas: Node2D) -> void:
	if not model: return
	for x in [110, 530]:
		canvas.draw_rect(Rect2(x - 22, 274, 44, 33), Color("302418"))
		canvas.draw_line(Vector2(x - 22, 274), Vector2(x + 22, 274), BRASS, 2)
	match model.stage:
		State.Stage.INSPECT: _draw_inspection(canvas)
		State.Stage.MEASURE: _draw_measuring(canvas)
		State.Stage.SECURE: _draw_fixing(canvas)
		State.Stage.SAW: _draw_saw(canvas)
		State.Stage.PLANE: _draw_plane(canvas)
		State.Stage.LOAD: _draw_load(canvas)
		State.Stage.COMPLETE:
			_text(canvas, Vector2(196, 120), "✓  TABLA DE SOPORTE DE LA BANCADA", 17, GREEN)
			_text(canvas, Vector2(196, 146), "Veta continua · corte preciso · carga verificada", 13, LIGHT)
	if model.stage == State.Stage.MEASURE:
		for index in model.marked_lines:
			var x := 98.0 if index == 0 else State.CUT_X
			canvas.draw_line(Vector2(x, 185), Vector2(x, 271), INK, 2)

func _draw_inspection(canvas: Node2D) -> void:
	for defect in model.defects:
		var p := Vector2(72 + float(defect.x), 184 + float(defect.y))
		var radius := float(defect.radius)
		match int(defect.kind):
			0:
				canvas.draw_circle(p, radius, Color("47301d"))
				for ring in 3: canvas.draw_arc(p, radius * (0.3 + ring * 0.3), 0, TAU, 24, Color("987041"), 1)
			1: canvas.draw_polyline(PackedVector2Array([p - Vector2(18, 4), p - Vector2(3, 1), p + Vector2(2, 7), p + Vector2(20, 3)]), Color("352017"), 2)
			2:
				for dot in 9: canvas.draw_circle(p + Vector2(sin(dot * 2.7) * radius, cos(dot * 3.1) * radius * 0.6), 1.5, Color("59492e"))
	var rect := Rect2(72 + model.template_x, 180, State.TEMPLATE_WIDTH, 96)
	var color := GREEN if model.template_safe() else RED
	canvas.draw_rect(rect, Color(color, 0.13))
	canvas.draw_rect(rect, color, false, 2)
	for x in [rect.position.x + 18, rect.get_center().x, rect.end.x - 18]: canvas.draw_line(Vector2(x, 181), Vector2(x, 275), Color(color, 0.65), 1)
	_text(canvas, rect.position + Vector2(8, -12), "PLANTILLA  /  ZONAS DE APOYO", 12, color)
	_text(canvas, Vector2(72, 365), "Veta continua" if model.template_safe() else "Atención: defecto dentro de la pieza", 14, color)
	if model.selected_tool == "lens":
		canvas.draw_line(model.lens_position + Vector2(29, 29), model.lens_position + Vector2(58, 58), INK, 14)
		canvas.draw_line(model.lens_position + Vector2(29, 29), model.lens_position + Vector2(58, 58), BRASS, 8)

func _draw_measuring(canvas: Node2D) -> void:
	canvas.draw_style_box(_plate_style(Color("b88e47"), LIGHT), Rect2(72, 139, 620, 30))
	for tick in 101:
		var x := 72 + tick * 6.2
		canvas.draw_line(Vector2(x, 140), Vector2(x, 153 if tick % 10 else 160), INK, 1)
		if tick % 10 == 0: _text(canvas, Vector2(x - 8, 166), str(tick * 2), 10, INK)
	var stop_x := 72 + model.length_cm / 200 * 620
	canvas.draw_rect(Rect2(stop_x - 6, 132, 12, 46), Color("403c32"))
	canvas.draw_circle(Vector2(stop_x, 147), 6, LIGHT)
	_text(canvas, Vector2(76, 122), "TOPE: %.1f cm  ·  OBJETIVO: 160 cm" % model.length_cm, 13, LIGHT)
	var pivot := Vector2(568, 184)
	var arm := Vector2(0, -80).rotated(deg_to_rad(model.square_angle - 90))
	canvas.draw_polyline(PackedVector2Array([pivot + Vector2(-65, 0), pivot, pivot + arm]), INK, 12)
	canvas.draw_polyline(PackedVector2Array([pivot + Vector2(-65, 0), pivot, pivot + arm]), Color("b4b5a2"), 6)
	canvas.draw_circle(pivot + arm, 8, BRASS)
	_text(canvas, Vector2(615, 121), "%.1f°" % model.square_angle, 14, LIGHT)
	var mark_x := 98.0 if model.marked_lines == 0 else State.CUT_X
	canvas.draw_line(Vector2(mark_x, 184), Vector2(mark_x, 272), Color(GREEN, 0.65), 2)
	canvas.draw_circle(Vector2(mark_x, 184), 7, BRASS)
	var pen := model.tool_position if model.tool_active else Vector2(mark_x, 176)
	canvas.draw_line(pen + Vector2(13, -29), pen, Color("26160d"), 9)
	canvas.draw_line(pen + Vector2(13, -29), pen + Vector2(3, -7), BRASS, 5)
	canvas.draw_line(pen + Vector2(3, -7), pen, LIGHT, 2)
	_text(canvas, Vector2(72, 365), "Incisiones: %d / 2  ·  sigue la escuadra de canto a canto" % model.marked_lines, 14, LIGHT)

func _draw_fixing(canvas: Node2D) -> void:
	for index in 3:
		var p := Vector2(150 + index * 210, 286 - model.wedge_hits[index] * 5)
		canvas.draw_rect(Rect2(p.x - 21, 270, 42, 32), INK)
		if not model.wedge_inserted[index]:
			canvas.draw_rect(Rect2(p.x - 20, 270, 40, 30), Color(GREEN, 0.7), false, 1)
			p.y = 360
			if pointer_tool == "wedge%d" % index and pointer_start.y > 330: p = pointer_last
		canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-18, 13), p + Vector2(19, 13), p + Vector2(15, -18)]), Color("b27b3e"))
		canvas.draw_line(p + Vector2(-12, 8), p + Vector2(12, -9), BRASS, 2)
		_text(canvas, Vector2(127 + index * 210, 393), "Cuña %d" % (index + 1), 12, LIGHT)
		for hit in 3: canvas.draw_circle(Vector2(138 + index * 210 + hit * 12, 405), 3, GREEN if hit < model.wedge_hits[index] else Color("67533c"))
	var index := int(model.selected_tool.right(1)) if model.selected_tool.begins_with("wedge") else 1
	var mallet := Vector2(150 + index * 210, 168 - (14 if model.impact_age < 0.08 else 0))
	if pointer_tool.begins_with("wedge"): mallet.y = clampf(pointer_last.y, 130, 258)
	canvas.draw_line(mallet, mallet + Vector2(15, 68), BRASS, 9)
	canvas.draw_style_box(_plate_style(Color("a3713f"), LIGHT), Rect2(mallet - Vector2(27, 14), Vector2(54, 28)))
	canvas.draw_texture_rect_region(WOOD, Rect2(mallet - Vector2(25, 12), Vector2(50, 24)), Rect2(100, 720, 400, 100))
	var jaw_y := 178.0 - (1.0 - model.pressure) * 22
	canvas.draw_polyline(PackedVector2Array([Vector2(665, jaw_y), Vector2(705, jaw_y), Vector2(705, 285), Vector2(675, 285)]), INK, 12)
	canvas.draw_polyline(PackedVector2Array([Vector2(665, jaw_y), Vector2(705, jaw_y), Vector2(705, 285), Vector2(675, 285)]), Color("9c9a85"), 6)
	for thread in 8: canvas.draw_line(Vector2(678, 265 + thread * 4), Vector2(688, 262 + thread * 4), BRASS, 2)
	_dial(canvas, Vector2(718, 295), model.pressure, 0.60, 0.18 if model.easy else 0.07, "MORDAZA")
	_text(canvas, Vector2(72, 108), "Asienta tres cuñas · gira la mordaza · prueba el extremo libre", 13, LIGHT)

func _draw_saw(canvas: Node2D) -> void:
	var x := model.tool_position.x if model.tool_active else (466.0 if model.cuts % 2 == 0 else 636.0)
	var center := Vector2(x, 170 + model.cuts * 9)
	canvas.draw_line(Vector2(State.CUT_X, 182), Vector2(State.CUT_X, 274), Color(GREEN, 0.5), 1)
	canvas.draw_polyline(PackedVector2Array([center + Vector2(-110, 34), center + Vector2(-110, -55), center + Vector2(110, -55), center + Vector2(110, 34)]), INK, 16)
	canvas.draw_polyline(PackedVector2Array([center + Vector2(-110, 34), center + Vector2(-110, -55), center + Vector2(110, -55), center + Vector2(110, 34)]), Color("a87a48"), 10)
	canvas.draw_texture_rect_region(WOOD, Rect2(center + Vector2(-108, -60), Vector2(216, 10)), Rect2(37, 708, 1466, 45))
	for side in [-1, 1]:
		for y in [-53, 32]: canvas.draw_circle(center + Vector2(side * 110, y), 3, BRASS)
	canvas.draw_line(center + Vector2(-110, 34), center + Vector2(110, 34), Color("ccc8ac"), 4)
	for tooth in 42:
		var p := center + Vector2(-108 + tooth * 5.2, 36)
		canvas.draw_line(p, p + Vector2(2, 3), Color("e3d8ba"), 1)
	_text(canvas, Vector2(72, 363), "%s  ·  RECORRIDOS %d / 5" % ["→ Avanza" if model.cuts % 2 == 0 else "← Regresa", model.cuts], 15, LIGHT)
	for cut in 5: canvas.draw_circle(Vector2(588 + cut * 21, 359), 5, GREEN if cut < model.cuts else BRASS.darkened(0.55))

func _draw_plane(canvas: Node2D) -> void:
	var y := model.lane_y()
	canvas.draw_rect(Rect2(73, y - 8, 494, 17), Color(GREEN, 0.12))
	canvas.draw_line(Vector2(72, y), Vector2(568, y), Color(GREEN, 0.7), 1)
	var p := model.tool_position if model.tool_active else Vector2(72, y)
	canvas.draw_texture_rect_region(TOOLS, Rect2(p - Vector2(37, 48), Vector2(110, 48)), Rect2(1230, 190, 920, 320))
	_dial(canvas, Vector2(730, 206), model.blade_depth, 0.5, 0.18 if model.easy else 0.05, "CUCHILLA")
	_text(canvas, Vector2(72, 363), "→ A favor de veta  ·  FRANJA %d / 4" % mini(model.passes + 1, 4), 15, LIGHT)
	_text(canvas, Vector2(656, 279), "Gira la rueda", 12, LIGHT)

func lever_grip(value: float) -> Vector2:
	var angle := lerpf(-LEVER_SWING, LEVER_SWING, value)
	return LEVER_PIVOT + Vector2(sin(angle), -cos(angle)) * 56

func _draw_load(canvas: Node2D) -> void:
	var count := model.verified_loads + (1 if model.load_active else 0)
	for index in count: _sack(canvas, Vector2(320 + index * 15, 181 - index * 28 + model.deflection * 2.5), index)
	if not model.load_active and model.verified_loads < 3:
		_sack(canvas, pointer_last + Vector2(0, 28) if pointer_tool == "sack" else Vector2(338, 138), model.verified_loads)
		_text(canvas, Vector2(280, 70), "Arrastra al centro", 12, LIGHT)
	canvas.draw_rect(Rect2(266, 175, 125, 100), Color(GREEN, 0.09))
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_texture_rect_region(LEVER_PARTS, Rect2(LEVER_PIVOT - Vector2(58, 18), Vector2(116, 48)), LEVER_BASE_REGION)
	canvas.draw_set_transform(LEVER_PIVOT, lerpf(-LEVER_SWING, LEVER_SWING, model.counterforce))
	canvas.draw_texture_rect_region(LEVER_PARTS, Rect2(-8, -64, 16, 68), LEVER_ARM_REGION)
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_style_box(_plate_style(Color("29271eee"), BRASS), Rect2(594, 78, 175, 100))
	canvas.draw_rect(Rect2(602, 125 - model.load_tolerance() * 8, 159, model.load_tolerance() * 16), Color(GREEN, 0.25))
	for line in 11: canvas.draw_line(Vector2(605, 87 + line * 8), Vector2(759, 87 + line * 8), Color("d8cda43b"), 1)
	for line in 16: canvas.draw_line(Vector2(605 + line * 10, 86), Vector2(605 + line * 10, 168), Color("d8cda426"), 1)
	var pointer_y := clampf(125 + model.deflection * 8, 87, 167)
	canvas.draw_line(Vector2(611, pointer_y), Vector2(748, pointer_y), BRASS, 3)
	_text(canvas, Vector2(608, 73), "COMPARADOR · FLECHA", 11, LIGHT)
	_text(canvas, Vector2(72, 364), "Cargas verificadas: %d / 3  ·  aguja en verde durante 1,2 s" % model.verified_loads, 14, LIGHT)
	if model.load_active: canvas.draw_arc(Vector2(339, 100), 23, -PI / 2, -PI / 2 + TAU * model.stable_seconds / 1.2, 36, GREEN, 3)

func _sack(canvas: Node2D, point: Vector2, index: int) -> void:
	canvas.draw_texture_rect(SACK, Rect2(point - Vector2(30, 58), Vector2(60, 58)), false)
	canvas.draw_circle(point + Vector2(0, -23), 10, INK)
	_text(canvas, point + Vector2(-4, -18), str(index + 1), 14, LIGHT)

func _dial(canvas: Node2D, center: Vector2, value: float, target: float, tolerance: float, caption: String) -> void:
	canvas.draw_circle(center, 35, INK)
	canvas.draw_arc(center, 34, 0, TAU, 48, BRASS, 3)
	canvas.draw_arc(center, 29, PI * (0.75 + (target - tolerance) * 1.5), PI * (0.75 + (target + tolerance) * 1.5), 30, GREEN, 5)
	for tick in 13:
		var direction := Vector2.from_angle(PI * (0.75 + tick / 12.0 * 1.5))
		canvas.draw_line(center + direction * 22, center + direction * 26, LIGHT, 1)
	var needle := Vector2.from_angle(PI * (0.75 + value * 1.5))
	canvas.draw_line(center, center + needle * 24, BRASS, 3)
	canvas.draw_circle(center, 5, LIGHT)
	_text(canvas, center + Vector2(-36, -46), caption, 11, LIGHT)

func _text(canvas: Node2D, point: Vector2, text: String, font_size: int, color: Color) -> void:
	canvas.draw_string(font, point + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("120e0bee"))
	canvas.draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
