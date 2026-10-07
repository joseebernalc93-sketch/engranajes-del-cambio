extends Node2D

signal travel_finished(destination: String)

const COACH := preload("res://scenes/world/passenger_coach.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
const DEPOT_SCRIPT := preload("res://scripts/world/carriage_depot.gd")
const STATION_SCRIPT := preload("res://scripts/world/station.gd")
const ROAD_SCRIPT := preload("res://scripts/world/coach_road.gd")
const DEPOT_SCENE := "res://scenes/carriage_depot.tscn"
const STATION_SCENE := "res://scenes/station.tscn"
const BOARD_TIME := 1.0
const DEPART_TIME := 3.6
const ROAD_TIME := 6.2
const ARRIVE_TIME := 3.5
const DISEMBARK_TIME := 1.3
const TOTAL_TIME := BOARD_TIME + DEPART_TIME + ROAD_TIME + ARRIVE_TIME + DISEMBARK_TIME
const DEPOT_BERTH := Vector2(600, 398)
const STATION_BERTH := Vector2(450, 480)
const DEPOT_SPAWN := Vector2(550, 465)
const STATION_SPAWN := Vector2(610, 430)

@export var auto_change_destination := true

@onready var camera: Camera2D = $VoyageCamera
@onready var fade: ColorRect = $CanvasLayer/Root/Fade
@onready var journey_label: Label = $CanvasLayer/Root/Header/Margin/JourneyLabel
@onready var status_label: Label = $CanvasLayer/Root/Footer/Margin/Row/Details/StatusLabel
@onready var route_label: Label = $CanvasLayer/Root/Footer/Margin/Row/Details/RouteLabel
@onready var progress: ProgressBar = $CanvasLayer/Root/Footer/Margin/Row/Details/Progress
@onready var skip_button: Button = $CanvasLayer/Root/Footer/Margin/Row/SkipButton

var destination := ""
var returning := false
var elapsed := 0.0
var stage := "boarding"
var finishing := false
var completed := false
var coach: Node2D
var passenger: CharacterBody2D
var depot: Node2D
var station: Node2D
var road: Node2D
var last_coach_position := Vector2.ZERO
var last_stage := ""
var zoom_factor := 1.0
var dust: Array[Dictionary] = []
var dust_elapsed := 0.0


func _ready() -> void:
	GameState.restore_scene_session.call_deferred(self)
	destination = GameState.pending_coach_destination if not GameState.pending_coach_destination.is_empty() else STATION_SCENE
	returning = destination == DEPOT_SCENE
	depot = _background("DepotDeparture", DEPOT_SCRIPT)
	depot.travel_mode = true
	# The background must know its mode before entering the tree.
	add_child(depot)
	station = _background("StationArrival", STATION_SCRIPT)
	add_child(station)
	road = _background("Countryside", ROAD_SCRIPT)
	add_child(road)
	coach = COACH.instantiate()
	coach.name = "PassengerCoach"
	coach.z_index = 2
	coach.facing_left = returning
	add_child(coach)
	passenger = PLAYER.instantiate()
	passenger.name = "TravellingPassenger"
	passenger.z_index = 3
	passenger.collision_layer = 0
	passenger.collision_mask = 0
	add_child(passenger)
	passenger.set_physics_process(false)
	passenger.controls_enabled = false
	journey_label.text = "De regreso a la estación de carretas" if returning else "En diligencia hacia la estación del tren"
	route_label.text = "ESTACIÓN DEL TREN  →  ESTACIÓN DE CARRETAS" if returning else "ESTACIÓN DE CARRETAS  →  ESTACIÓN DEL TREN"
	skip_button.pressed.connect(_finish_travel)
	get_viewport().size_changed.connect(_fit_camera)
	_apply_timeline(0.0)
	last_coach_position = coach.position
	last_stage = stage


func _background(node_name: String, source: Script) -> Node2D:
	var background := Node2D.new()
	background.set_script(source)
	background.name = node_name
	background.z_index = -1
	return background


func _process(delta: float) -> void:
	if completed:
		return
	if not finishing:
		elapsed = minf(elapsed + delta, TOTAL_TIME)
		_apply_timeline(elapsed)
	var motion := coach.position - last_coach_position
	coach.speed = motion.length() / maxf(delta, 0.001) if stage == last_stage and stage in ["departure", "country_road", "arrival"] else 0.0
	coach.speed = minf(coach.speed, 430.0)
	last_coach_position = coach.position
	last_stage = stage
	_update_dust(delta)
	if passenger.visible:
		var direction := Vector2.ZERO
		if stage == "boarding":
			direction = (Vector2(425, 479) - STATION_SPAWN).normalized() if returning else (Vector2(620, 403) - Vector2(550, 455)).normalized()
		elif stage == "disembarking" and elapsed < TOTAL_TIME - 0.08:
			direction = ((DEPOT_SPAWN - Vector2(595, 419)) if returning else (STATION_SPAWN - Vector2(475, 492))).normalized()
		passenger._update_walk_animation(direction, delta)
	queue_redraw()
	if elapsed >= TOTAL_TIME and not finishing:
		_finish_travel()


func _apply_timeline(time: float) -> void:
	var departure_end := BOARD_TIME + DEPART_TIME
	var road_end := departure_end + ROAD_TIME
	var arrival_end := road_end + ARRIVE_TIME
	var use_depot := not returning
	passenger.visible = false
	coach.passenger_visible = true
	camera.position = Vector2(576, 324)
	zoom_factor = 1.0
	if time < BOARD_TIME:
		stage = "boarding"
		coach.position = STATION_BERTH if returning else DEPOT_BERTH
		coach.passenger_visible = false
		passenger.visible = true
		passenger.position = STATION_SPAWN.lerp(Vector2(425, 479), smoothstep(0.0, 1.0, time / BOARD_TIME)) if returning else Vector2(550, 455).lerp(Vector2(620, 403), smoothstep(0.0, 1.0, time / BOARD_TIME))
		status_label.text = "Subiendo a la diligencia · Regreso incluido" if returning else "Subiendo a la diligencia · Pasaje: 3 monedas"
	elif time < departure_end:
		stage = "departure"
		var part := (time - BOARD_TIME) / DEPART_TIME
		if returning:
			coach.position = STATION_BERTH.lerp(Vector2(-190, 480), part * part)
		elif part < 0.35:
			coach.position = DEPOT_BERTH.lerp(Vector2(675, 477), smoothstep(0.0, 1.0, part / 0.35))
		else:
			var drive := (part - 0.35) / 0.65
			coach.position = Vector2(675 + drive * 645, 477)
		status_label.text = "Dejando atrás la estación del tren" if returning else "Saliendo de la estación de carretas"
	elif time < road_end:
		stage = "country_road"
		var part := (time - departure_end) / ROAD_TIME
		coach.position = Vector2(2450 - part * 1800 if returning else 600 + part * 1800, 373)
		camera.position = coach.position + Vector2(-70 if returning else 70, -80)
		zoom_factor = 1.02
		status_label.text = "De regreso por los campos y el lago" if returning else "Recorriendo el camino entre los campos y el lago"
	elif time < arrival_end:
		stage = "arrival"
		use_depot = returning
		var part := (time - road_end) / ARRIVE_TIME
		if returning:
			if part < 0.66:
				coach.position = Vector2(1320, 477).lerp(Vector2(675, 477), smoothstep(0.0, 1.0, part / 0.66))
			else:
				coach.position = Vector2(675, 477).lerp(DEPOT_BERTH, smoothstep(0.0, 1.0, (part - 0.66) / 0.34))
		else:
			coach.position = Vector2(-190, 480).lerp(STATION_BERTH, 1.0 - pow(1.0 - part, 2.0))
		status_label.text = "Llegando a la terminal de carretas" if returning else "Llegando a la entrada principal de la estación"
	else:
		stage = "disembarking"
		use_depot = returning
		var part := clampf((time - arrival_end) / DISEMBARK_TIME, 0.0, 1.0)
		coach.position = DEPOT_BERTH if returning else STATION_BERTH
		coach.passenger_visible = false
		passenger.visible = true
		passenger.position = Vector2(595, 419).lerp(DEPOT_SPAWN, smoothstep(0.0, 1.0, part)) if returning else Vector2(475, 492).lerp(STATION_SPAWN, smoothstep(0.0, 1.0, part))
		status_label.text = "Bajando de la carreta · La aldea está cerca" if returning else "Bajando de la carreta · La taquilla está dentro"
	depot.visible = stage != "country_road" and use_depot
	station.visible = stage != "country_road" and not use_depot
	road.visible = stage == "country_road"
	progress.value = clampf(time / TOTAL_TIME, 0.0, 1.0)
	if not finishing:
		fade.modulate.a = 1.0 - smoothstep(0.0, 0.45, time)
		for boundary in [departure_end, road_end]:
			fade.modulate.a = maxf(fade.modulate.a, 1.0 - smoothstep(0.0, 0.25, absf(time - boundary)))
	_fit_camera()


func _fit_camera() -> void:
	var size := get_viewport_rect().size
	var fit := minf(size.x / 1152.0, size.y / 648.0)
	camera.zoom = Vector2.ONE * fit * zoom_factor
	camera.offset.y = maxf(0.0, 76.0 * (1.0 - fit)) / maxf(camera.zoom.y, 0.01)


func _update_dust(delta: float) -> void:
	for index in range(dust.size() - 1, -1, -1):
		dust[index].age += delta
		if float(dust[index].age) > 0.8:
			dust.remove_at(index)
	dust_elapsed += delta
	if coach.speed > 35.0 and dust_elapsed > 0.08:
		dust_elapsed = 0.0
		var direction := -1.0 if returning else 1.0
		dust.append({"position": coach.position + Vector2(-76 * direction * 0.82, 0), "age": 0.0})


func _draw() -> void:
	for puff in dust:
		var age: float = puff.age
		var position: Vector2 = puff.position + Vector2(-age * 20.0 if not returning else age * 20.0, -age * 8.0)
		draw_circle(position, 2.5 + age * 7.0, Color(0.72, 0.60, 0.37, (1.0 - age / 0.8) * 0.14))


func _unhandled_input(event: InputEvent) -> void:
	if elapsed < BOARD_TIME or finishing or event.is_echo():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish_travel()


func _finish_travel() -> void:
	if finishing or completed:
		return
	finishing = true
	coach.speed = 0.0
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
	GameState.complete_passenger_coach_trip(destination)
	GameState.pending_spawn = DEPOT_SPAWN if returning else STATION_SPAWN
	get_tree().change_scene_to_file(destination)
