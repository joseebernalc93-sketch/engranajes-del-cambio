extends Node2D
## Deterministic 40-second journey; the owner supplies time and serializes it.
signal finished
const TOTAL_TIME: float = 40.0
const ROAD_START: float = 8.0
const ROAD_END: float = 32.0
const DISEMBARK_START: float = 37.5
const PANORAMA := preload("res://assets/phase2/london_coach_panorama_v1.png")
const DEPOT := preload("res://assets/phase2/london_coach_depot_v1.png")
const EngineHouse := preload("res://scripts/world/engine_house_art.gd")
const INDUSTRIAL := EngineHouse.YARD
const DRIVER := preload("res://assets/phase2/william_coachman_pixel_v2.png")
const MINE := preload("res://assets/phase2/mine_yard_pixel_v3.png")
const FoundryArt := preload("res://scripts/world/foundry_art.gd")
const Journey := preload("res://scripts/world/london_journey.gd")
var destination_area: String = "industrial"
var elapsed: float = 0.0
var returning: bool = false
var active: bool = false
var stage: String = "boarding"
var background: Sprite2D
var coach: Node2D
var passenger: CharacterBody2D
var fade: ColorRect
var skip: Button
var start_position := Vector2.ZERO

func _ready() -> void:
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background = Sprite2D.new()
	background.centered = false
	add_child(background)
	coach = preload("res://scenes/world/passenger_coach.tscn").instantiate()
	add_child(coach)
	coach.set_process(false)
	coach.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coach.driver_portrait = DRIVER
	var driver_bounds: Rect2i = preload("res://scripts/world/sprite_body_bounds.gd").measure(DRIVER.get_image())
	coach.driver_portrait_region = Rect2(driver_bounds.position, Vector2(driver_bounds.size.x, driver_bounds.size.y * 0.69))
	coach.scale = Vector2.ONE * 0.92
	passenger = preload("res://scenes/player/player.tscn").instantiate()
	passenger.collision_layer = 0
	passenger.collision_mask = 0
	add_child(passenger)
	passenger.set_physics_process(false)
	passenger.controls_enabled = false
	fade = ColorRect.new()
	fade.size = Vector2(1152, 648)
	fade.color = Color(0.07, 0.05, 0.03, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	skip = Button.new()
	skip.text = "Omitir trayecto"
	skip.position = Vector2(956, 599)
	skip.size = Vector2(180, 33)
	skip.add_theme_font_size_override("font_size", 16)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("20190ee8")
	plate.border_color = Color("ad803e")
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(5)
	skip.add_theme_stylebox_override("normal", plate)
	add_child(skip)
	skip.pressed.connect(complete)
	hide()

func begin(is_returning: bool, origin: Vector2, time: float = 0.0, destination: String = "industrial") -> void:
	destination_area = destination if destination in Journey.COACH_STOPS else "industrial"
	returning = is_returning
	start_position = origin
	elapsed = clampf(time, 0.0, TOTAL_TIME)
	coach.travelled = 0.0
	coach.elapsed = 0.0
	coach.wheel_angle = 0.0
	active = true
	show()
	apply_timeline()

func advance(delta: float) -> void:
	if not active: return
	elapsed = minf(TOTAL_TIME, elapsed + delta)
	apply_timeline()
	coach._process(delta)
	if elapsed >= TOTAL_TIME: complete()

func complete() -> void:
	if not active: return
	active = false
	coach.speed = 0.0
	hide()
	finished.emit()

func apply_timeline() -> void:
	var berth := Vector2(470, 515) if returning else Vector2(750, 485)
	var destination_berth := Vector2(750, 485) if returning else Vector2(470, 515)
	if destination_area == "industrial":
		if returning: berth = EngineHouse.COACH_BERTH
		else: destination_berth = EngineHouse.COACH_BERTH
	if destination_area == "mine_yard":
		if returning: berth = Vector2(420, 520)
		else: destination_berth = Vector2(420, 520)
	elif destination_area == "forge_yard":
		if returning: berth = FoundryArt.COACH_BERTH
		else: destination_berth = FoundryArt.COACH_BERTH
	var remote: Texture2D = MINE if destination_area == "mine_yard" else INDUSTRIAL
	if destination_area == "forge_yard": remote = FoundryArt.YARD
	background.texture = remote if returning else DEPOT
	background.position = Vector2.ZERO
	background.scale = Vector2(1152, 648) / background.texture.get_size()
	coach.facing_left = returning
	coach.passenger_visible = elapsed >= 2.8 and elapsed < DISEMBARK_START
	coach.speed = 0.0
	passenger.hide()
	if elapsed < 2.8:
		stage = "boarding"
		coach.position = berth
		passenger.show()
		passenger.position = start_position.lerp(berth + Vector2(-30, -10), smoothstep(0.0, 2.8, elapsed))
		passenger.facing = "up"
		passenger._set_sprite_frame(int(elapsed * 7) % 3)
	elif elapsed < ROAD_START:
		stage = "departure"
		var part := (elapsed - 2.8) / (ROAD_START - 2.8)
		coach.position = berth.lerp(Vector2(-220 if returning else 1380, berth.y), part * part)
		coach.speed = maxf(35.0, part * 230.0)
	elif elapsed < ROAD_END:
		stage = "city_road"
		var part := (elapsed - ROAD_START) / (ROAD_END - ROAD_START)
		background.texture = PANORAMA
		background.scale = Vector2.ONE * (648.0 / PANORAMA.get_height())
		var distance := PANORAMA.get_width() * background.scale.x - 1152
		background.position.x = -distance * (1.0 - part if returning else part)
		coach.position = Vector2(560 + sin(part * PI) * (40 if returning else -40), 559)
		coach.speed = distance / (ROAD_END - ROAD_START)
	else:
		background.texture = DEPOT if returning else remote
		background.scale = Vector2(1152, 648) / background.texture.get_size()
		if elapsed < DISEMBARK_START:
			stage = "arrival"
			var part := (elapsed - ROAD_END) / (DISEMBARK_START - ROAD_END)
			coach.position = Vector2(1380 if returning else -220, destination_berth.y).lerp(destination_berth, 1.0 - pow(1.0 - part, 3))
			coach.speed = 220 * pow(1.0 - part, 2)
		else:
			stage = "disembarking"
			coach.position = destination_berth
			passenger.show()
			var landing := Vector2(650, 590) if returning or destination_area == "mine_yard" else Vector2(350, 590)
			if not returning and destination_area == "industrial": landing = EngineHouse.COACH_LANDING
			passenger.position = (destination_berth + Vector2(-30, -10)).lerp(landing, smoothstep(DISEMBARK_START, TOTAL_TIME, elapsed))
			passenger.facing = "down"
			passenger._set_sprite_frame(int(elapsed * 7) % 3)
	# Brief scene cuts; no text obstructs the journey.
	fade.color.a = 1.0 - smoothstep(0.0, 0.45, elapsed)
	for boundary in [ROAD_START, ROAD_END]:
		fade.color.a = maxf(fade.color.a, 1.0 - smoothstep(0.0, 0.35, absf(elapsed - boundary)))
	skip.visible = elapsed >= 2.8

func snapshot() -> Dictionary:
	return {"active": active, "elapsed": elapsed, "returning": returning, "destination_area": destination_area, "start": [start_position.x, start_position.y], "coach_distance": coach.travelled, "coach_time": coach.elapsed}

func restore(saved: Dictionary) -> void:
	if not bool(saved.get("active", false)):
		active = false
		coach.speed = 0.0
		hide()
		return
	var start: Array = saved.get("start", [650, 560])
	begin(bool(saved.get("returning", false)), Vector2(float(start[0]), float(start[1])), float(saved.get("elapsed", 0)), str(saved.get("destination_area", "industrial")))
	coach.travelled = maxf(0.0, float(saved.get("coach_distance", 0)))
	coach.elapsed = maxf(0.0, float(saved.get("coach_time", 0)))
	coach._process(0.0)
