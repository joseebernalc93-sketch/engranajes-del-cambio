extends Node2D

signal travel_finished(destination: String)

const TRAVEL_BACKGROUND := preload("res://assets/gba/environment/river_travel_v1.png")
const WATER_SHADER := preload("res://assets/shaders/boat_travel_water.gdshader")
const SHORE_SCRIPT := preload("res://scripts/world/boat_travel_shore.gd")
const EFFECTS_SCRIPT := preload("res://scripts/world/boat_travel_effects.gd")
const FRAME_WIDTH := 543.0
const DOCK_SCENE := "res://scenes/lake_dock.tscn"
const ISLAND_SCENE := "res://scenes/wood_island.tscn"
const ISLAND_OFFSET := Vector2(2150, 0)
const DOCK_BERTH := Vector2(720, 586)
const ISLAND_BERTH := ISLAND_OFFSET + Vector2(658, 616)
const DOCK_OPEN_WATER := Vector2(700, 960)
const ISLAND_OPEN_WATER := Vector2(2410, 960)
const HOLD_TIME := 0.55
const DEPART_TIME := 2.25
const CROSS_TIME := 3.6
const ARRIVE_TIME := 2.4
const MOOR_TIME := 0.6
const TOTAL_TIME := HOLD_TIME + DEPART_TIME + CROSS_TIME + ARRIVE_TIME + MOOR_TIME

@onready var boat: Sprite2D = $Boat
@onready var fade: ColorRect = $CanvasLayer/Root/Fade
@onready var camera: Camera2D = $VoyageCamera
@onready var journey_label: Label = $CanvasLayer/Root/Header/Margin/JourneyLabel
@onready var status_label: Label = $CanvasLayer/Root/Footer/Margin/Row/Details/StatusLabel
@onready var route_label: Label = $CanvasLayer/Root/Footer/Margin/Row/Details/RouteLabel
@onready var progress: ProgressBar = $CanvasLayer/Root/Footer/Margin/Row/Details/Progress
@onready var skip_button: Button = $CanvasLayer/Root/Footer/Margin/Row/SkipButton

@export var auto_change_destination := true

var elapsed := 0.0
var direction := 1.0
var destination := ""
var returning := false
var stage := "departure"
var finishing := false
var completed := false
var stroke_time := 0.0
var last_frame := 0
var last_position := Vector2.ZERO
var camera_zoom := 1.0
var effects: Node2D
var departure_curve: Curve2D
var arrival_curve: Curve2D


func _ready() -> void:
	GameState.restore_scene_session.call_deferred(self)
	destination = DOCK_SCENE if GameState.pending_travel_scene.is_empty() else GameState.pending_travel_scene
	returning = destination == DOCK_SCENE
	direction = -1.0 if returning else 1.0
	boat.flip_h = returning
	boat.scale = Vector2.ONE * 0.26
	_spawn_water()
	_spawn_shore("LakeDockShore", Vector2.ZERO, false)
	_spawn_shore("IslandShore", ISLAND_OFFSET, true)
	effects = Node2D.new()
	effects.set_script(EFFECTS_SCRIPT)
	effects.name = "BoatWake"
	effects.z_index = 1
	add_child(effects)
	_build_route()
	journey_label.text = "De la isla de Bruno al embarcadero" if returning else "Del embarcadero a la isla de Bruno"
	route_label.text = "ISLA DE BRUNO  →  EMBARCADERO" if returning else "EMBARCADERO  →  ISLA DE BRUNO"
	skip_button.pressed.connect(_finish_travel)
	get_viewport().size_changed.connect(_update_camera_zoom)
	_apply_timeline(0.0)
	last_position = boat.position


func _build_route() -> void:
	var berth := ISLAND_BERTH if returning else DOCK_BERTH
	var open_water := ISLAND_OPEN_WATER if returning else DOCK_OPEN_WATER
	var end_water := DOCK_OPEN_WATER if returning else ISLAND_OPEN_WATER
	var end_berth := DOCK_BERTH if returning else ISLAND_BERTH
	departure_curve = Curve2D.new()
	departure_curve.add_point(berth, Vector2.ZERO, Vector2(direction * 65, 80))
	departure_curve.add_point(open_water, Vector2(-direction * 120, 0))
	arrival_curve = Curve2D.new()
	arrival_curve.add_point(end_water, Vector2.ZERO, Vector2(direction * 180, 0))
	arrival_curve.add_point(end_berth, Vector2(-direction * 45, 90))


func _process(delta: float) -> void:
	if completed:
		return
	if not finishing:
		elapsed = minf(elapsed + delta, TOTAL_TIME)
		_apply_timeline(elapsed)
	var motion := boat.position - last_position
	var speed := motion.length() / maxf(delta, 0.001)
	last_position = boat.position
	var rowing := not finishing and stage != "mooring" and elapsed > HOLD_TIME and speed > 8.0
	if rowing:
		stroke_time += delta * clampf(speed / 170.0, 0.6, 1.35)
		var frame := int(stroke_time * 6.0) % 4
		boat.region_rect.position.x = frame * FRAME_WIDTH
		if frame != last_frame and frame == 2:
			effects.add_oar_splash(boat.position + Vector2(direction * 21, 35))
		last_frame = frame
	else:
		boat.region_rect.position.x = 0.0
	boat.rotation = sin(elapsed * 3.2) * (0.012 if rowing else 0.004)
	boat.offset.y = sin(elapsed * 3.5) * 4.0
	effects.update_motion(boat.position + Vector2(0, 24), motion, speed, delta)
	if elapsed >= TOTAL_TIME and not finishing:
		_finish_travel()


func _apply_timeline(time: float) -> void:
	var start_camera := ISLAND_OFFSET + Vector2(576, 445) if returning else Vector2(576, 445)
	var end_camera := Vector2(576, 445) if returning else ISLAND_OFFSET + Vector2(576, 445)
	var start_water := ISLAND_OPEN_WATER if returning else DOCK_OPEN_WATER
	var end_water := DOCK_OPEN_WATER if returning else ISLAND_OPEN_WATER
	if time < HOLD_TIME + DEPART_TIME:
		stage = "departure"
		var part := clampf((time - HOLD_TIME) / DEPART_TIME, 0.0, 1.0)
		var eased := part * part
		boat.position = departure_curve.sample_baked(departure_curve.get_baked_length() * eased, true)
		camera.position = start_camera.lerp(start_water + Vector2(direction * 75, 10), smoothstep(0.0, 1.0, part))
		camera_zoom = lerpf(1.0, 0.9, smoothstep(0.0, 1.0, part))
		if not returning:
			# Pan sideways only once the riverbank has left the frame.
			var pan := smoothstep(0.78, 1.0, part)
			camera.position.x = lerpf(start_camera.x, start_water.x + 75.0, pan)
			camera_zoom = lerpf(1.0, 0.9, pan)
		status_label.text = "Soltando amarras en la isla" if returning else "Partiendo del embarcadero del lago"
	elif time < HOLD_TIME + DEPART_TIME + CROSS_TIME:
		stage = "crossing"
		var part := (time - HOLD_TIME - DEPART_TIME) / CROSS_TIME
		boat.position = start_water.lerp(end_water, part)
		boat.position.y += sin(part * PI) * 35.0
		camera.position = boat.position + Vector2(direction * 75, 10)
		camera_zoom = 0.9 - sin(part * PI) * 0.045
		status_label.text = "Remando de regreso por el lago" if returning else "Cruzando el lago hacia la isla boscosa"
	elif time < TOTAL_TIME - MOOR_TIME:
		stage = "arrival"
		var part := clampf((time - HOLD_TIME - DEPART_TIME - CROSS_TIME) / ARRIVE_TIME, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - part, 2.0)
		boat.position = arrival_curve.sample_baked(arrival_curve.get_baked_length() * eased, true)
		camera.position = (end_water + Vector2(direction * 75, 10)).lerp(end_camera, smoothstep(0.0, 1.0, part))
		camera_zoom = lerpf(0.9, 1.0, smoothstep(0.0, 1.0, part))
		status_label.text = "Acercándonos al embarcadero del lago" if returning else "Llegando al muelle de Bruno"
	else:
		stage = "mooring"
		boat.position = DOCK_BERTH if returning else ISLAND_BERTH
		camera.position = end_camera
		camera_zoom = 1.0
		status_label.text = "Bote amarrado · Embarcadero del lago" if returning else "Bote amarrado · La isla de Bruno"
	progress.value = clampf(time / (TOTAL_TIME - MOOR_TIME), 0.0, 1.0)
	if not finishing:
		fade.modulate.a = 1.0 - smoothstep(0.0, HOLD_TIME, time)
	_update_camera_zoom()


func _update_camera_zoom() -> void:
	var viewport_size := get_viewport_rect().size
	var fit := minf(viewport_size.x / 1152.0, viewport_size.y / 648.0)
	camera.zoom = Vector2.ONE * fit * camera_zoom
	# Keep the berth visible above the fixed-height footer on smaller windows.
	camera.offset.y = maxf(0.0, 94.0 * (1.0 - fit)) / camera.zoom.y


func _spawn_water() -> void:
	var surface := Sprite2D.new()
	surface.name = "TravelWater"
	surface.texture = TRAVEL_BACKGROUND
	surface.position = Vector2(1800, 750)
	surface.scale = Vector2(5600.0, 2300.0) / TRAVEL_BACKGROUND.get_size()
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	surface.material = material
	surface.z_index = -10
	add_child(surface)


func _spawn_shore(node_name: String, location: Vector2, island: bool) -> void:
	var shore := Node2D.new()
	shore.set_script(SHORE_SCRIPT)
	shore.name = node_name
	shore.position = location
	shore.island = island
	add_child(shore)


func _unhandled_input(event: InputEvent) -> void:
	if elapsed < HOLD_TIME or finishing or event.is_echo():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish_travel()


func _finish_travel() -> void:
	if finishing or completed:
		return
	finishing = true
	skip_button.disabled = true
	var exit := create_tween()
	exit.tween_property(fade, "modulate:a", 1.0, 0.4)
	exit.tween_callback(_change_destination)


func _change_destination() -> void:
	if completed:
		return
	completed = true
	travel_finished.emit(destination)
	if not auto_change_destination:
		return
	GameState.pending_travel_scene = ""
	GameState.pending_spawn = Vector2(580, 480) if returning else Vector2(576, 535)
	get_tree().change_scene_to_file(destination)
