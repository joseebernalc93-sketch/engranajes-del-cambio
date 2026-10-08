extends Node

const SAVE_PATH := "user://engranajes_save.json"
const REPORT_PATH := "user://registro_fase_1.json"
const SAVE_VERSION := 18
const FORGE_OPPORTUNITIES := 10
const EASY_FORGE_OPPORTUNITIES := 15
const DIFFICULTY_EASY := "facil"
const DIFFICULTY_HARD := "dificil"
const RAIL_ROUTE := preload("res://scripts/core/rail_route.gd")
const REQUIRED_WHEAT := 3
const FLOUR_SALE_VALUE := 100
const TRAIN_TICKET_PRICE := 10
const COACH_FARE := 3
const PHASE_INTRO_SCENE := "res://scenes/ui/enclosure_story.tscn"
const PHASE_TWO_SCENE := "res://scenes/london_arrival.tscn"
const PHASE_TWO_FACTORY := "res://scenes/phase2_hub.tscn"
const PHASE_TWO_INTRO := "res://scenes/story/phase2_intro.tscn"
const PHASE_START_SPAWN := Vector2(576, 585)
const MILL_PART_FLAGS := {
	"rueda_dentada": "mill_gear_installed",
	"cuerda": "mill_rope_installed",
	"tabla": "mill_plank_installed",
}
var coins := 0
var inventory: Dictionary = {}
var flags: Dictionary = {}
var metrics: Dictionary = {}
var phase_started_at := 0
var phase_complete := false
var phase_summary: Dictionary = {}
var phase_two: Dictionary = {}
var pending_spawn := Vector2.ZERO
var pending_travel_scene := ""
var pending_coach_destination := ""
var difficulty := DIFFICULTY_HARD
var run_started := false
var checkpoint: Dictionary = {}
var chapter_checkpoints: Dictionary = {}
var restoring_session := false
var capturing_session := false
var autosave_elapsed := 0.0
const SESSION_MEMORY := preload("res://scripts/core/session_memory.gd")


func _ready() -> void:
	get_tree().auto_accept_quit = false
	EventBus.dialogue_action_selected.connect(_on_dialogue_action)
	if not load_progress():
		reset_progress(false)


func is_easy_difficulty() -> bool:
	return difficulty == DIFFICULTY_EASY


func get_forge_opportunities() -> int:
	return EASY_FORGE_OPPORTUNITIES if is_easy_difficulty() else FORGE_OPPORTUNITIES


func get_forge_indicator_speed() -> float:
	return 0.25 if is_easy_difficulty() else 1.0


func get_rope_opportunities() -> int:
	return get_forge_opportunities()


func get_lumber_opportunities() -> int:
	return get_forge_opportunities()


func get_lumber_attempts_left() -> int:
	return maxi(0, get_lumber_opportunities() - int(flags.get("lumber_attempts_spent", 0)))


func fail_lumber_attempt() -> int:
	if get_lumber_attempts_left() <= 0:
		return 0
	flags["lumber_attempts_spent"] = int(flags.get("lumber_attempts_spent", 0)) + 1
	metrics["lumber_mistakes"] = int(metrics.get("lumber_mistakes", 0)) + 1
	save_progress()
	return get_lumber_attempts_left()


func show_lumber_encouragement() -> void:
	EventBus.show_dialogue("Bruno, leñador", "La tabla aún necesita trabajo. Sigue intentándolo, no te rindas. ¡Ánimo! Cuando estés listo, preparamos otra pieza y lo probamos de nuevo.", [{"label": "Intentar de nuevo", "action": "restart_lumber_round"}, {"label": "Volver después", "action": "close"}])


func restart_lumber_round() -> void:
	if flags.get("lumber_puzzle_completed", false) or get_lumber_attempts_left() > 0:
		return
	flags["lumber_attempts_spent"] = 0
	flags["lumber_progress"] = {}
	save_progress()
	EventBus.lumber_puzzle_requested.emit()


func get_rope_attempts_left() -> int:
	return maxi(0, get_rope_opportunities() - int(flags.get("rope_attempts_spent", 0)))


func fail_rope_attempt() -> int:
	if get_rope_attempts_left() <= 0:
		return 0
	flags["rope_attempts_spent"] = int(flags.get("rope_attempts_spent", 0)) + 1
	register_rope_action("rope_mistake")
	save_progress()
	return get_rope_attempts_left()


func show_rope_encouragement() -> void:
	EventBus.show_dialogue("Silas, hilandero", "Sigue intentándolo, el cáñamo requiere paciencia. No te rindas, ¡ánimo! Cuando estés listo, preparamos nuevos manojos y lo probamos otra vez.", [{"label": "Intentar de nuevo", "action": "restart_rope_round"}, {"label": "Volver después", "action": "close"}])


func restart_rope_round() -> void:
	if flags.get("rope_puzzle_completed", false) or get_rope_attempts_left() > 0:
		return
	flags["rope_attempts_spent"] = 0
	flags["rope_progress"] = {}
	flags["rope_recorded_turns"] = 0
	save_progress()
	EventBus.rope_puzzle_requested.emit()


func set_difficulty(value: String) -> void:
	if value not in [DIFFICULTY_EASY, DIFFICULTY_HARD] or value == difficulty:
		return
	var spent := maxi(0, int(flags.get("forge_attempts_spent", get_forge_opportunities() - int(flags.get("forge_attempts_left", get_forge_opportunities())))))
	difficulty = value
	flags["forge_attempts_spent"] = spent
	flags["forge_attempts_left"] = maxi(0, get_forge_opportunities() - spent)
	save_progress()


func reset_progress(reload_scene := true) -> void:
	phase_two = {}
	run_started = false
	checkpoint = {}
	chapter_checkpoints = {}
	restoring_session = false
	coins = 0
	inventory = {"herramientas": 1}
	flags = {
		"villager_spoken": false,
		"tools_sold": false,
		"tools_given_to_mateo": false,
		"wheelwright_forge_completed": false,
		"forge_attempts_left": get_forge_opportunities(),
		"forge_attempts_spent": 0,
		"forge_progress": {},
		"flour_milled": false,
		"flour_sold": false,
		"ticket_bought": false,
		"wheat_1": false,
		"wheat_2": false,
		"wheat_3": false,
		"broken_mill_seen": false,
		"withered_wheat_seen": false,
		"wheelwright_spoken": false,
		"lumberjack_spoken": false,
		"lumber_puzzle_completed": false,
		"lumber_attempts_spent": 0,
		"lumber_progress": {},
		"spinner_spoken": false,
		"rope_puzzle_completed": false,
		"rope_attempts_spent": 0,
		"rope_progress": {},
		"rope_recorded_turns": 0,
		"mill_gear_installed": false,
		"mill_rope_installed": false,
		"mill_plank_installed": false,
		"mill_repaired": false,
		"mill_operation_started": false,
		"cart_mission_completed": false,
		"coach_allowance_received": false,
		"coach_fare_paid": false,
		"coach_station_reached": false,
		"rail_wagon_parked": false,
		"rail_route_prepared": false,
		"rail_dispatch_completed": false,
		"rail_track_angles": RAIL_ROUTE.INITIAL.duplicate(),
		"rail_track_checks": 0,
		"steam_machine_seen": false,
		"industrial_gate_seen": false,
	}
	metrics = {
		"interactions": 0,
		"wheat_harvested": 0,
		"dialogues_opened": 0,
		"failed_purchases": 0,
		"historical_clues_found": 0,
		"mill_parts_installed": 0,
		"mill_repair_verified": false,
		"forge_bellows_actions": 0,
		"forge_hammer_actions": 0,
		"forge_failed_attempts": 0,
		"forge_rounds": 1,
		"flour_sacks_milled": 0,
		"boat_trips": 0,
		"passenger_coach_trips": 0,
		"coach_fares_paid": 0,
		"rail_switch_actions": 0,
		"rail_turnout_actions": 0,
		"rail_safety_stops": 0,
		"rail_bell_rings": 0,
		"rail_departure_signals": 0,
		"saw_successes": 0,
		"saw_misses": 0,
		"planing_passes": 0,
		"lumber_defects_found": 0,
		"lumber_setup_actions": 0,
		"plane_grain_errors": 0,
		"lumber_load_sacks": 0,
		"rope_braid_steps": 0,
		"rope_twists": 0,
		"rope_fibers_cleaned": 0,
		"rope_mistakes": 0,
		"rope_stable_seconds": 0.0,
		"mill_gate_adjustments": 0,
		"mill_stable_seconds": 0.0,
		"mill_jams": 0,
		"mill_batches_processed": 0,
		"cart_items_packed": [],
		"cart_balance_moves": 0,
		"cart_route_attempts": 0,
		"cart_protected_item": "",
		"events": [],
	}
	phase_started_at = Time.get_unix_time_from_system()
	phase_complete = false
	phase_summary = {}
	pending_spawn = Vector2.ZERO
	pending_travel_scene = ""
	pending_coach_destination = ""
	if FileAccess.file_exists(REPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
	save_progress()
	if reload_scene and get_tree().current_scene:
		get_tree().reload_current_scene()


func restart_phase() -> void:
	if phase_complete:
		revisit_phase_one()
		return
	reset_progress(false)
	run_started = true
	checkpoint = {"scene": PHASE_INTRO_SCENE, "story_index": 0}
	restoring_session = true
	save_progress()
	pending_spawn = PHASE_START_SPAWN
	call_deferred("_open_phase_intro")


func is_phase_two_unlocked() -> bool:
	return phase_complete or bool(phase_two.get("active", false)) or bool(phase_two.get("intro_seen", false))


func revisit_phase_one() -> void:
	if not phase_complete: return
	save_progress()
	# This is a return to the completed countryside, not a new playthrough.
	_select_chapter_checkpoint({"scene": "res://scenes/sheep_farm.tscn", "position": [PHASE_START_SPAWN.x, PHASE_START_SPAWN.y], "facing": "down"})


func restart_phase_two() -> void:
	if not is_phase_two_unlocked(): return
	save_progress()
	# Replay the arrival while retaining completed work and the shared budget.
	phase_two.erase("arrival")
	if not phase_two.is_empty(): phase_two["intro_seen"] = false
	_select_chapter_checkpoint({"scene": PHASE_TWO_INTRO, "story_index": 0})


func _remember_chapter_checkpoint(saved: Dictionary) -> void:
	var scene_path := str(saved.get("scene", ""))
	if scene_path.is_empty() or scene_path == "res://scenes/ui/main_menu.tscn": return
	var chapter := "2" if scene_path in [PHASE_TWO_SCENE, PHASE_TWO_FACTORY, PHASE_TWO_INTRO] else "1"
	chapter_checkpoints[chapter] = saved.duplicate(true)


func _select_chapter_checkpoint(saved: Dictionary) -> void:
	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene):
		current_scene.set_process(false)
		current_scene.set_physics_process(false)
	pending_spawn = Vector2.ZERO
	pending_travel_scene = ""
	pending_coach_destination = ""
	checkpoint = saved.duplicate(true)
	_remember_chapter_checkpoint(checkpoint)
	restoring_session = true
	save_progress()
	call_deferred("_open_checkpoint_scene")


func _open_phase_intro() -> void:
	var error := get_tree().change_scene_to_file(PHASE_INTRO_SCENE)
	if error != OK:
		push_error("No se pudo reiniciar la fase: %s" % error_string(error))


func add_item(item_id: String, amount := 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	EventBus.inventory_changed.emit()
	save_progress()


func remove_item(item_id: String, amount := 1) -> bool:
	if int(inventory.get(item_id, 0)) < amount:
		return false
	inventory[item_id] = int(inventory[item_id]) - amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	EventBus.inventory_changed.emit()
	save_progress()
	return true


func has_item(item_id: String, amount := 1) -> bool:
	return int(inventory.get(item_id, 0)) >= amount


func get_objective() -> String:
	if phase_complete:
		return "Fase 1 completada. Explora el pueblo o vuelve a Londres desde el cuaderno."
	if not flags.get("villager_spoken", false):
		return "Habla con Elena en la aldea para preparar el viaje."
	if int(metrics.get("wheat_harvested", 0)) < REQUIRED_WHEAT:
		return "Cosecha el trigo junto al molino (%d/%d)." % [int(metrics.get("wheat_harvested", 0)), REQUIRED_WHEAT]
	if not flags.get("wheelwright_forge_completed", false):
		return "Lleva tus herramientas viejas a Mateo y fabrica la rueda dentada."
	if not flags.get("lumber_puzzle_completed", false):
		return "Sigue el camino a la izquierda de Silas hasta el embarcadero y navega a la isla de Bruno para conseguir una tabla resistente."
	if not flags.get("rope_puzzle_completed", false):
		return "Habla con Silas en el taller de cordería y fabrica una cuerda resistente."
	if not flags.get("mill_repaired", false):
		return "Consigue las piezas y repara el molino (%d/3)." % get_mill_repair_progress()
	if not flags.get("flour_milled", false):
		return "Muele los tres puñados de trigo y fabrica un costal de harina."
	if not flags.get("flour_sold", false):
		return "Vende el costal de harina a Tomás, el panadero, por 100 monedas."
	if not flags.get("coach_station_reached", false):
		return "Ve a la estación de carretas, paga 3 monedas al cochero y viaja hasta la estación del tren."
	if not flags.get("ticket_bought", false):
		return "Compra un boleto en la estación (%d monedas)." % TRAIN_TICKET_PRICE
	return "Entra al andén y sube al tren rumbo a la ciudad industrial."


func interact(interaction_id: String) -> bool:
	metrics.interactions = int(metrics.get("interactions", 0)) + 1
	match interaction_id:
		"villager":
			_talk_to_villager()
		"baker", "blacksmith":
			_talk_to_baker()
		"ticket_office":
			_talk_to_ticket_office()
		"train":
			_interact_train()
		"passenger_coach":
			_talk_to_coachman(false)
		"return_passenger_coach":
			_talk_to_coachman(true)
		"station_platform":
			if flags.get("ticket_bought", false):
				EventBus.show_dialogue("Acceso al andén", "Tu boleto está en regla. El tren hacia la ciudad industrial te espera en el andén.", [{"label": "Entrar al andén", "action": "go_station_platform"}, {"label": "Todavía no", "action": "close"}])
			else:
				EventBus.show_dialogue("Acceso al andén", "Compra el boleto en la taquilla antes de pasar al andén.")
		"enclosure":
			_inspect_enclosure()
		"broken_mill":
			_inspect_broken_mill()
		"mill_mechanism":
			_inspect_mill_mechanism()
		"withered_wheat":
			_inspect_withered_wheat()
		"wheelwright":
			_talk_to_wheelwright()
		"lumberjack":
			_talk_to_lumberjack()
		"spinner":
			_talk_to_spinner()
		"boat_to_wood_island":
			_interact_boat_to_island()
		"boat_to_lake_dock", "boat_to_mill":
			_interact_boat_to_lake_dock()
		"lake_dock_info":
			EventBus.show_dialogue("Embarcadero del lago", "Desde este muelle salen botes con madera, lana y alimentos. En los campos de la Revolución Industrial, los lagos y ríos conectaban a los artesanos con los pueblos y sus mercados.")
		"steam_textile_machine":
			_inspect_steam_textile_machine()
		"industrial_gate":
			_inspect_industrial_gate()
		_ when interaction_id.begins_with("wheat_"):
			return _harvest_wheat(interaction_id)
	save_progress()
	return false


func _talk_to_villager() -> void:
	metrics.dialogues_opened += 1
	if not flags.villager_spoken:
		flags.villager_spoken = true
		record_event("Conversó con una campesina desplazada por los cercamientos.")
	if flags.get("flour_sold", false):
		EventBus.show_dialogue("Elena, campesina", "La venta de la harina te permite emprender el viaje. Sigue el camino de la derecha hasta la estación de carretas: Ramón te llevará al tren por 3 monedas. Reserva las otras 10 para el boleto. Nosotros también buscaremos una nueva oportunidad en la ciudad.")
		_emit_progress()
		return
	EventBus.show_dialogue(
		"Elena, campesina",
		"El terrateniente cercó los pastos comunales para criar ovejas. Sin tierra para sembrar ni alimentar a nuestros animales, muchas familias ya partieron hacia la ciudad.",
		[{"label": "Comprendo", "action": "close"}]
	)
	_emit_progress()


func _talk_to_baker() -> void:
	metrics.dialogues_opened += 1
	if flags.get("flour_sold", false):
		var farewell := "El boleto ya está pagado. Que el viaje te acerque a una nueva oportunidad." if flags.ticket_bought else "La harina ya está en la tahona. Con las 100 monedas de la harina puedes pagar la diligencia y el boleto del tren."
		EventBus.show_dialogue("Tomás, panadero", farewell)
		return
	if not flags.villager_spoken:
		EventBus.show_dialogue("Tomás, panadero", "Antes de vender lo último que tienes, habla con Elena. Ella conoce lo que está ocurriendo con las tierras de la aldea.")
		return
	if int(metrics.wheat_harvested) < REQUIRED_WHEAT:
		EventBus.show_dialogue("Tomás, panadero", "El horno está listo, pero falta harina. Cosecha el trigo del sembrío junto al molino y llévalo a moler.")
		return
	if not has_item("costal_harina"):
		var flour_hint := "No puedo amasar pan con el grano entero. Si lo mueles en el viejo molino, podré comprarte el costal de harina por 100 monedas para tu viaje."
		if not has_item("trigo", REQUIRED_WHEAT):
			flour_hint = "Solo falta el costal de harina terminado. Vuelve cuando hayas procesado la cosecha en el molino."
		EventBus.show_dialogue("Tomás, panadero", flour_hint)
		return
	EventBus.show_dialogue(
		"Tomás, panadero",
		"La harina tiene una molienda uniforme: servirá para el pan de toda la aldea. Te pagaré 100 monedas por el costal. La diligencia cuesta 3 y el tren a Londres, 10: llegarás a la ciudad con 87 monedas para tus siguientes viajes.",
		[
			{"label": "Vender harina", "action": "sell_flour"},
			{"label": "Todavía no", "action": "close"},
		]
	)


func _talk_to_coachman(returning: bool) -> void:
	metrics.dialogues_opened = int(metrics.get("dialogues_opened", 0)) + 1
	if returning and flags.get("coach_fare_paid", false):
		EventBus.show_dialogue("Ramón, cochero", "Tu pasaje de diligencia incluye el regreso a la estación de carretas. La aldea está junto al camino de entrada.", [{"label": "Regresar en carreta", "action": "return_by_coach"}, {"label": "Quedarme", "action": "close"}])
	elif flags.get("coach_fare_paid", false):
		EventBus.show_dialogue("Ramón, cochero", "Ya pagaste el pasaje. Sube a la diligencia: te dejaré frente a la entrada principal de la estación del tren.", [{"label": "Subir a la carreta", "action": "take_passenger_coach"}, {"label": "Todavía no", "action": "close"}])
	elif coins < COACH_FARE:
		EventBus.show_dialogue("Ramón, cochero", "El viaje hasta la estación del tren cuesta 3 monedas. No tienes suficiente todavía. Vende un costal de harina a Tomás: te pagará 100 monedas, suficientes para la diligencia y el boleto del tren.")
	else:
		EventBus.show_dialogue("Ramón, cochero", "La diligencia de pasajeros sale hacia la estación del tren. El pasaje cuesta 3 monedas e incluye el regreso si lo necesitas. Te dejaré junto a la entrada principal.", [{"label": "Pagar 3 monedas y viajar", "action": "take_passenger_coach"}, {"label": "Todavía no", "action": "close"}])


func book_passenger_coach(destination: String) -> bool:
	if destination not in ["res://scenes/station.tscn", "res://scenes/carriage_depot.tscn"] or not pending_coach_destination.is_empty():
		return false
	if not flags.get("coach_fare_paid", false):
		if coins < COACH_FARE:
			metrics.failed_purchases = int(metrics.get("failed_purchases", 0)) + 1
			EventBus.show_dialogue("Ramón, cochero", "El pasaje cuesta 3 monedas. Necesitas reunirlas antes de subir.")
			save_progress()
			return false
		coins -= COACH_FARE
		flags["coach_fare_paid"] = true
		metrics["coach_fares_paid"] = int(metrics.get("coach_fares_paid", 0)) + COACH_FARE
		record_event("Pagó 3 monedas por la diligencia de pasajeros hacia la estación del tren.")
		EventBus.coins_changed.emit(coins)
	pending_coach_destination = destination
	_emit_progress()
	save_progress()
	return true


func complete_passenger_coach_trip(destination: String) -> bool:
	if pending_coach_destination != destination:
		return false
	pending_coach_destination = ""
	metrics["passenger_coach_trips"] = int(metrics.get("passenger_coach_trips", 0)) + 1
	if destination == "res://scenes/station.tscn":
		flags["coach_station_reached"] = true
		record_event("Llegó en diligencia a la entrada principal de la estación del tren.")
	else:
		record_event("Regresó en diligencia a la estación de carretas del pueblo.")
	_emit_progress()
	save_progress()
	return true


func _talk_to_ticket_office() -> void:
	metrics.dialogues_opened += 1
	if flags.ticket_bought:
		EventBus.show_dialogue("Agente de estación", "Tu boleto está en regla. El tren espera en el andén.")
		return
	if coins < TRAIN_TICKET_PRICE:
		metrics.failed_purchases += 1
		record_event("Intentó comprar el boleto sin monedas suficientes.")
		EventBus.show_dialogue("Agente de estación", "El boleto cuesta 10 monedas. El panadero Tomás paga 100 monedas por un costal de harina: alcanza para la diligencia y este boleto.")
		return
	EventBus.show_dialogue(
		"Agente de estación",
		"El boleto a la ciudad industrial cuesta 10 monedas. El próximo tren sale en breve; al comprarlo se descontará el importe completo.",
		[
			{"label": "Comprar boleto", "action": "buy_ticket"},
			{"label": "Cancelar", "action": "close"},
		]
	)


func _interact_train() -> void:
	if not flags.ticket_bought:
		EventBus.show_dialogue("Maquinista", "Necesitas un boleto antes de subir. Puedes comprarlo en la ventanilla.")
		return
	if phase_complete:
		return
	EventBus.show_dialogue(
		"Tren a la ciudad",
		"El tren está listo para partir. ¿Deseas subir?",
		[
			{"label": "Entrar al tren", "action": "board_train"},
			{"label": "Todavía no", "action": "close"},
		]
	)


func park_rail_wagon() -> void:
	if flags.get("rail_wagon_parked", false):
		return
	flags["rail_wagon_parked"] = true
	record_event("Apartó y frenó la vagoneta de carga en la vía secundaria.")
	_emit_progress()
	save_progress()


# Archived puzzle resources cannot grant new progress after removal.
func complete_rail_dispatch() -> bool:
	return false


func register_rail_action(action: String) -> void:
	var key := "rail_switch_actions" if action in ["switch", "turnout"] else "rail_safety_stops"
	metrics[key] = int(metrics.get(key, 0)) + 1
	if action == "turnout":
		metrics["rail_turnout_actions"] = int(metrics.get("rail_turnout_actions", 0)) + 1
	save_progress()


func complete_train_departure() -> void:
	if phase_complete:
		return
	phase_complete = true
	consume_train_ticket()
	record_event("Abordó el tren hacia la ciudad industrial.")
	var report := build_report()
	phase_summary = report.duplicate(true)
	_write_report(report)
	EventBus.objective_changed.emit(get_objective())
	EventBus.phase_completed.emit(report)
	save_progress()


func consume_train_ticket() -> void:
	if not inventory.has("boleto"): return
	inventory.erase("boleto")
	EventBus.inventory_changed.emit()


func _inspect_enclosure() -> void:
	if not flags.get("enclosure_seen", false):
		flags.enclosure_seen = true
		metrics.historical_clues_found += 1
		record_event("Conoció el desplazamiento de las familias en la estación de carretas.")
	EventBus.show_dialogue("Estación de carretas", "Aquí las familias preparan sus carretas para partir. Los antiguos pastos comunales quedaron cercados para criar ovejas cuya lana abastece a los telares; muchos campesinos deben buscar trabajo en la ciudad.")


func _inspect_broken_mill() -> void:
	if flags.get("mill_repaired", false):
		EventBus.show_dialogue(
			"Molino comunal reparado",
			"Las aspas vuelven a girar y el mecanismo está listo para moler la cosecha.",
			[
				{"label": "Preparar costal de harina", "action": "go_mill_interior"},
				{"label": "Continuar", "action": "close"},
			]
		)
		return
	if not flags.get("broken_mill_seen", false):
		flags.broken_mill_seen = true
		metrics.historical_clues_found += 1
		record_event("Examinó el molino comunal averiado.")
	EventBus.show_dialogue(
		"Molino comunal averiado",
		"El molino ya casi no se usa. En su interior faltan varias piezas, pero aún podría moler la poca cosecha que queda.",
		[
			{"label": "Entrar al molino", "action": "go_mill_interior"},
			{"label": "Todavía no", "action": "close"},
		]
	)


func _inspect_mill_mechanism() -> void:
	if flags.get("mill_repaired", false):
		if flags.get("flour_milled", false):
			EventBus.show_dialogue(
				"Mecanismo reparado",
				"Las piedras ya molieron la cosecha. El costal de harina está listo para llevarlo con Tomás.",
				[
					{"label": "Ver costal preparado", "action": "open_mill_operation"},
					{"label": "Continuar", "action": "close"},
				]
			)
			return
		if not has_item("trigo", REQUIRED_WHEAT):
			EventBus.show_dialogue(
				"Mecanismo reparado",
				"El molino funciona, pero necesitas los tres puñados de trigo para llenar un costal de harina."
			)
			return
		EventBus.show_dialogue(
			"Mecanismo reparado",
			"La rueda dentada transmite el giro, la cuerda guía las poleas y la tabla mantiene firme la estructura. Ya puedes moler toda la cosecha.",
			[
				{"label": "Preparar costal de harina", "action": "open_mill_operation"},
				{"label": "Todavía no", "action": "close"},
			]
		)
		return
	EventBus.mill_repair_requested.emit()


func is_mill_part_installed(item_id: String) -> bool:
	if not MILL_PART_FLAGS.has(item_id):
		return false
	return bool(flags.get(MILL_PART_FLAGS[item_id], false))


func get_mill_repair_progress() -> int:
	var installed := 0
	for item_id in MILL_PART_FLAGS:
		if is_mill_part_installed(item_id):
			installed += 1
	return installed


func install_mill_part(item_id: String, require_test: bool = false) -> bool:
	if not MILL_PART_FLAGS.has(item_id) or is_mill_part_installed(item_id):
		return false
	if not has_item(item_id) or not remove_item(item_id):
		return false
	flags[MILL_PART_FLAGS[item_id]] = true
	metrics["mill_parts_installed"] = get_mill_repair_progress()
	var item: Dictionary = ContentDB.get_item(item_id)
	record_event("Instaló %s en el mecanismo del molino." % str(item.get("name", item_id)).to_lower())
	EventBus.show_toast("Pieza instalada: %s" % str(item.get("name", item_id)))
	if not require_test and get_mill_repair_progress() == MILL_PART_FLAGS.size():
		complete_mill_repair()
	_emit_progress()
	save_progress()
	return true


func complete_mill_repair() -> bool:
	if flags.get("mill_repaired", false) or get_mill_repair_progress() != MILL_PART_FLAGS.size():
		return false
	flags["mill_repaired"] = true
	record_event("Reparó el molino comunal.")
	EventBus.show_toast("El molino vuelve a funcionar")
	_emit_progress()
	save_progress()
	return true


func _inspect_withered_wheat() -> void:
	if not flags.get("withered_wheat_seen", false):
		flags.withered_wheat_seen = true
		metrics.historical_clues_found += 1
		record_event("Observó el sembrío marchito junto al molino.")
	EventBus.show_dialogue(
		"Sembrío marchito",
		"El campo produce cada vez menos. Las mejores tierras quedaron cercadas para criar ovejas y alimentar la producción de lana."
	)


func _talk_to_wheelwright() -> void:
	metrics.dialogues_opened += 1
	if not flags.get("wheelwright_spoken", false):
		flags["wheelwright_spoken"] = true
		record_event("Conoció a Mateo, maestro carretero de la aldea.")
	if flags.get("wheelwright_forge_completed", false):
		EventBus.show_dialogue(
			"Mateo, maestro carretero",
			"La rueda dentada quedó reforzada con el hierro de tus herramientas. Ya puedes instalarla en el eje del molino."
		)
		return
	if flags.get("tools_given_to_mateo", false):
		if int(flags.get("forge_attempts_left", get_forge_opportunities())) <= 0:
			show_forge_encouragement()
			return
		EventBus.show_dialogue(
			"Mateo, maestro carretero",
			"Conservamos el hierro y tu avance. Monta los refuerzos, controla el calor, remacha, enfría, centra el eje y prueba la rueda. Te quedan %d de %d oportunidades para todo el trabajo." % [int(flags.get("forge_attempts_left", get_forge_opportunities())), get_forge_opportunities()],
			[
				{"label": "Continuar en la fragua", "action": "open_wheelwright_forge"},
				{"label": "Todavía no", "action": "close"},
			]
		)
		return
	if not has_item("herramientas"):
		EventBus.show_dialogue(
			"Mateo, maestro carretero",
			"Necesito hierro aprovechable para reforzar la rueda. Tráeme tus herramientas agrícolas viejas cuando estés listo."
		)
		return
	EventBus.show_dialogue(
		"Mateo, maestro carretero",
		"Puedo recuperar el hierro de tu azada y tu hoz para reforzar una rueda dentada nueva. Tendrás que accionar el fuelle y ayudarme a fijar el metal mientras aún esté caliente.",
		[
			{"label": "Entregar herramientas", "action": "begin_wheelwright_forge"},
			{"label": "Todavía no", "action": "close"},
		]
	)


func _interact_boat_to_island() -> void:
	EventBus.show_dialogue(
		"Embarcadero del lago",
		"El bote del embarcadero cruza el lago hasta la isla boscosa donde vive Bruno, el leñador. Allí podrás conseguir madera resistente para reparar el molino.",
		[
			{"label": "Remar hacia la isla", "action": "sail_to_wood_island"},
			{"label": "Quedarme", "action": "close"},
		]
	)


func _interact_boat_to_lake_dock() -> void:
	EventBus.show_dialogue(
		"Embarcadero de la isla",
		"El bote está amarrado y listo para volver al embarcadero del lago, junto al camino del taller de Silas.",
		[
			{"label": "Regresar al embarcadero", "action": "sail_to_lake_dock"},
			{"label": "Quedarme", "action": "close"},
		]
	)


func _talk_to_lumberjack() -> void:
	metrics.dialogues_opened += 1
	if not flags.get("lumberjack_spoken", false):
		flags["lumberjack_spoken"] = true
		record_event("Conoció a Bruno, leñador de la isla.")
	if flags.get("lumber_puzzle_completed", false):
		EventBus.show_dialogue(
			"Bruno, leñador",
			"La tabla quedó recta, lisa y resistente. Úsala para reforzar la estructura del molino."
		)
		return
	if get_lumber_attempts_left() <= 0:
		show_lumber_encouragement()
		return
	EventBus.show_dialogue(
		"Bruno, leñador",
		"Puedo darte una tabla fuerte, pero debemos prepararla sin desperdiciar el tronco. Elige la veta, mide con regla y escuadra, fija la pieza, guía la sierra y ajusta el cepillo. Al final regularemos el apoyo para probar tres cargas. Si algo sale mal, conservamos el trabajo que ya está bien.",
		[
			{"label": "Preparar la tabla", "action": "open_lumber_puzzle"},
			{"label": "Todavía no", "action": "close"},
		]
	)


func _talk_to_spinner() -> void:
	metrics.dialogues_opened += 1
	if not flags.get("spinner_spoken", false):
		flags["spinner_spoken"] = true
		record_event("Conoció a Silas, hilandero y cordelero artesanal.")
	if flags.get("rope_puzzle_completed", false):
		EventBus.show_dialogue(
			"Silas, hilandero",
			"La cuerda quedó firme, flexible y de grosor parejo. Colócala en el juego de poleas del molino para soportar la carga."
		)
		return
	if get_rope_attempts_left() <= 0:
		show_rope_encouragement()
		return
	EventBus.show_dialogue(
		"Silas, hilandero",
		"Las nuevas hiladoras de vapor nos van dejando sin encargos, pero el cáñamo trabajado a mano sigue siendo indispensable para izar cargas. Seleccionaremos y peinaremos las fibras, montaremos tres cabos, controlaremos la torsión, haremos una ligadura y probaremos la cuerda con cargas.",
		[
			{"label": "Fabricar la cuerda", "action": "open_rope_puzzle"},
			{"label": "Todavía no", "action": "close"},
		]
	)


func _inspect_steam_textile_machine() -> void:
	if not flags.get("steam_machine_seen", false):
		flags.steam_machine_seen = true
		metrics.historical_clues_found += 1
		record_event("Examinó una máquina de vapor aplicada a la producción textil.")
	EventBus.show_dialogue(
		"Maquinaria textil temprana",
		"La máquina de vapor mueve correas que accionan cardadoras e hiladoras. Así, la lana de las ovejas puede procesarse más rápido y en cantidades que el trabajo manual no alcanzaba."
	)


func _inspect_industrial_gate() -> void:
	if not flags.get("industrial_gate_seen", false):
		flags.industrial_gate_seen = true
		metrics.historical_clues_found += 1
		record_event("Encontró cerrada la entrada de la propiedad industrial.")
	EventBus.show_dialogue(
		"Puerta cerrada",
		"No puedes acceder: es una propiedad industrial privada."
	)


func _harvest_wheat(interaction_id: String) -> bool:
	if flags.get(interaction_id, false):
		return false
	flags[interaction_id] = true
	metrics.wheat_harvested += 1
	add_item("trigo")
	record_event("Recolectó trigo con herramientas manuales.")
	EventBus.show_toast("Cosecha escasa: +1 puñado de trigo")
	_emit_progress()
	return true


func _on_dialogue_action(action: String) -> void:
	match action:
		"open_mill_operation":
			flags["mill_operation_started"] = true
			EventBus.mill_operation_requested.emit()
		"begin_wheelwright_forge":
			_begin_wheelwright_forge()
		"open_wheelwright_forge":
			EventBus.wheelwright_forge_requested.emit()
		"restart_forge_round":
			restart_forge_round()
		"open_lumber_puzzle":
			EventBus.lumber_puzzle_requested.emit()
		"restart_lumber_round":
			restart_lumber_round()
		"open_rope_puzzle":
			EventBus.rope_puzzle_requested.emit()
		"restart_rope_round":
			restart_rope_round()
		"mill_wheat":
			_mill_wheat()
		"sell_flour":
			_sell_flour()
		"buy_ticket":
			if coins >= TRAIN_TICKET_PRICE and not flags.ticket_bought:
				coins -= TRAIN_TICKET_PRICE
				flags.ticket_bought = true
				inventory["boleto"] = 1
				record_event("Pagó 10 monedas por un boleto de tren hacia la ciudad industrial.")
				EventBus.inventory_changed.emit()
				EventBus.coins_changed.emit(coins)
				EventBus.show_toast("Boleto adquirido: -10 monedas")
				_emit_progress()
	save_progress()


func _begin_wheelwright_forge() -> void:
	if flags.get("wheelwright_forge_completed", false):
		return
	if not flags.get("tools_given_to_mateo", false):
		if not remove_item("herramientas"):
			EventBus.show_toast("Necesitas las herramientas agrícolas viejas")
			return
		flags["tools_given_to_mateo"] = true
		record_event("Entregó sus herramientas viejas a Mateo para recuperar el hierro.")
		_emit_progress()
	EventBus.wheelwright_forge_requested.emit()


func register_forge_action(action: String) -> void:
	if action == "fuelle":
		metrics["forge_bellows_actions"] = int(metrics.get("forge_bellows_actions", 0)) + 1
	elif action == "martillo":
		metrics["forge_hammer_actions"] = int(metrics.get("forge_hammer_actions", 0)) + 1


func fail_forge_attempt(reason: String) -> int:
	var before := int(flags.get("forge_attempts_left", get_forge_opportunities()))
	if before <= 0:
		return 0
	var remaining := before - 1
	flags["forge_attempts_spent"] = int(flags.get("forge_attempts_spent", get_forge_opportunities() - before)) + 1
	flags["forge_attempts_left"] = remaining
	metrics["forge_failed_attempts"] = int(metrics.get("forge_failed_attempts", 0)) + 1
	record_event("Intento de la fragua fallido: %s. Oportunidades restantes: %d." % [reason, remaining])
	save_progress()
	return remaining


func show_forge_encouragement() -> void:
	EventBus.show_dialogue("Mateo, maestro carretero", "Lo siento, la rueda todavía no está lista. Sigue intentándolo, no te rindas. ¡Ánimo! Conservamos tu hierro. Cuando estés listo, probamos de nuevo.", [{"label": "Intentar de nuevo · %d oportunidades" % get_forge_opportunities(), "action": "restart_forge_round"}, {"label": "Volver después", "action": "close"}])


func restart_forge_round() -> void:
	if flags.get("wheelwright_forge_completed", false) or not flags.get("tools_given_to_mateo", false) or int(flags.get("forge_attempts_left", get_forge_opportunities())) > 0:
		return
	flags["forge_attempts_left"] = get_forge_opportunities()
	flags["forge_attempts_spent"] = 0
	flags["forge_progress"] = {}
	metrics["forge_rounds"] = int(metrics.get("forge_rounds", 1)) + 1
	record_event("Mateo le animó a comenzar otra ronda de la fragua.")
	save_progress()
	EventBus.wheelwright_forge_requested.emit()


func complete_wheelwright_forge() -> bool:
	if flags.get("wheelwright_forge_completed", false) or not flags.get("tools_given_to_mateo", false):
		return false
	flags["wheelwright_forge_completed"] = true
	flags["forge_progress"] = {}
	add_item("rueda_dentada")
	record_event("Ayudó a Mateo a forjar una rueda dentada con el hierro recuperado.")
	EventBus.show_toast("Rueda dentada recibida")
	_emit_progress()
	save_progress()
	return true


func register_boat_trip(destination: String) -> void:
	metrics["boat_trips"] = int(metrics.get("boat_trips", 0)) + 1
	record_event("Viajó en bote hacia %s." % destination)
	save_progress()


func register_lumber_action(action: String) -> void:
	match action:
		"measurement_mark":
			metrics["lumber_measurement_marks"] = int(metrics.get("lumber_measurement_marks", 0)) + 1
		"wood_defect":
			metrics["lumber_defects_found"] = int(metrics.get("lumber_defects_found", 0)) + 1
		"setup_part":
			metrics["lumber_setup_actions"] = int(metrics.get("lumber_setup_actions", 0)) + 1
		"saw_success":
			metrics["saw_successes"] = int(metrics.get("saw_successes", 0)) + 1
		"saw_miss":
			metrics["saw_misses"] = int(metrics.get("saw_misses", 0)) + 1
		"plane_pass":
			metrics["planing_passes"] = int(metrics.get("planing_passes", 0)) + 1
		"plane_grain_error":
			metrics["plane_grain_errors"] = int(metrics.get("plane_grain_errors", 0)) + 1
		"load_sack":
			metrics["lumber_load_sacks"] = int(metrics.get("lumber_load_sacks", 0)) + 1


func complete_lumber_puzzle() -> bool:
	if flags.get("lumber_puzzle_completed", false):
		return false
	flags["lumber_puzzle_completed"] = true
	flags["lumber_progress"] = {}
	add_item("tabla")
	record_event("Ayudó a Bruno a seleccionar, medir, fijar, aserrar, cepillar y probar una tabla estructural.")
	EventBus.show_toast("Tabla de soporte de la bancada recibida")
	_emit_progress()
	save_progress()
	return true


func register_rope_action(action: String) -> void:
	match action:
		"fiber_cleaned":
			metrics["rope_fibers_cleaned"] = int(metrics.get("rope_fibers_cleaned", 0)) + 1
		"braid_step":
			metrics["rope_braid_steps"] = int(metrics.get("rope_braid_steps", 0)) + 1
		"rope_twist":
			metrics["rope_twists"] = int(metrics.get("rope_twists", 0)) + 1
		"rope_mistake":
			metrics["rope_mistakes"] = int(metrics.get("rope_mistakes", 0)) + 1


func complete_rope_puzzle() -> bool:
	if flags.get("rope_puzzle_completed", false):
		return false
	flags["rope_puzzle_completed"] = true
	flags["rope_progress"] = {}
	add_item("cuerda")
	record_event("Ayudó a Silas a seleccionar y peinar el cáñamo, igualar tres cabos, controlar la torsión, asegurar la ligadura y probar tres cargas.")
	EventBus.show_toast("Soga de transmisión resistente recibida")
	_emit_progress()
	save_progress()
	return true


func _mill_wheat() -> void:
	complete_mill_operation(0.0, 0, 0)


func complete_mill_operation(stable_seconds: float, jams: int, gate_adjustments: int) -> bool:
	if flags.get("flour_milled", false) or not flags.get("mill_repaired", false):
		return false
	if not has_item("trigo", REQUIRED_WHEAT):
		EventBus.show_toast("Necesitas los tres puñados de trigo")
		return false
	remove_item("trigo", REQUIRED_WHEAT)
	add_item("costal_harina")
	flags["flour_milled"] = true
	metrics["flour_sacks_milled"] = int(metrics.get("flour_sacks_milled", 0)) + 1
	metrics["mill_batches_processed"] = REQUIRED_WHEAT
	metrics["mill_stable_seconds"] = maxf(float(metrics.get("mill_stable_seconds", 0.0)), stable_seconds)
	metrics["mill_jams"] = int(metrics.get("mill_jams", 0)) + maxi(0, jams)
	metrics["mill_gate_adjustments"] = int(metrics.get("mill_gate_adjustments", 0)) + maxi(0, gate_adjustments)
	record_event("Procesó la cosecha en el molino y llenó un costal de harina.")
	EventBus.show_toast("Costal de harina preparado")
	_emit_progress()
	save_progress()
	return true


func register_cart_action(action: String) -> void:
	match action:
		"balance_move":
			metrics["cart_balance_moves"] = int(metrics.get("cart_balance_moves", 0)) + 1
		"route_attempt":
			metrics["cart_route_attempts"] = int(metrics.get("cart_route_attempts", 0)) + 1


# Retained only for old resources; the removed puzzle cannot award money or progress.
func complete_migration_cart(_packed_items: Array, _protected_item: String) -> bool:
	return false


func _sell_flour() -> void:
	if flags.get("flour_sold", false) or not has_item("costal_harina"):
		EventBus.show_toast("Debes llevar el costal de harina terminado")
		return
	remove_item("costal_harina")
	coins += FLOUR_SALE_VALUE
	flags["flour_sold"] = true
	record_event("Vendió un costal de harina al panadero Tomás por 100 monedas.")
	EventBus.coins_changed.emit(coins)
	EventBus.show_toast("Costal vendido: +100 monedas")
	_emit_progress()


func _emit_progress() -> void:
	EventBus.objective_changed.emit(get_objective())


func record_event(description: String) -> void:
	var elapsed := maxi(0, int(Time.get_unix_time_from_system()) - phase_started_at)
	metrics.events.append({"second": elapsed, "description": description})


func build_report() -> Dictionary:
	if phase_complete and not phase_summary.is_empty():
		return phase_summary.duplicate(true)
	return {
		"fase": "El éxodo rural",
		"puzzles": get_puzzle_progress().duplicate(true),
		"molino_reparado": bool(flags.get("mill_repaired", false)),
		"monedas_harina": FLOUR_SALE_VALUE if flags.get("flour_sold", false) else 0,
		"monedas_carretas": maxi(int(metrics.get("coach_fares_paid", 0)), COACH_FARE if flags.get("coach_fare_paid", false) else 0),
		"monedas_boleto": TRAIN_TICKET_PRICE if flags.get("ticket_bought", false) else 0,
		"dificultad": difficulty,
		"oportunidades_totales_fragua": get_forge_opportunities(),
		"tiempo_segundos": maxi(0, int(Time.get_unix_time_from_system()) - phase_started_at),
		"interacciones": int(metrics.interactions),
		"trigo_recolectado": int(metrics.wheat_harvested),
		"costales_harina": int(metrics.get("flour_sacks_milled", 0)),
		"acciones_fuelle": int(metrics.get("forge_bellows_actions", 0)),
		"golpes_refuerzo": int(metrics.get("forge_hammer_actions", 0)),
		"intentos_fallidos_fragua": int(metrics.get("forge_failed_attempts", 0)),
		"oportunidades_fragua": int(flags.get("forge_attempts_left", get_forge_opportunities())),
		"rondas_fragua": int(metrics.get("forge_rounds", 1)),
		"viajes_bote": int(metrics.get("boat_trips", 0)),
		"viajes_diligencia": int(metrics.get("passenger_coach_trips", 0)),
		"monedas_pasaje_diligencia": int(metrics.get("coach_fares_paid", 0)),
		"maniobra_ferroviaria_completada": bool(flags.get("rail_dispatch_completed", false)),
		"cambios_agujas": int(metrics.get("rail_switch_actions", 0)),
		"acciones_cambiavias": int(metrics.get("rail_turnout_actions", 0)),
		"bloqueos_seguridad_ferroviaria": int(metrics.get("rail_safety_stops", 0)),
		"campanadas_salida": int(metrics.get("rail_bell_rings", 0)),
		"controles_paso_verificados": int(flags.get("rail_track_checks", 0)),
		"senales_salida": int(metrics.get("rail_departure_signals", 0)),
		"cortes_sierra": int(metrics.get("saw_successes", 0)),
		"fallos_sierra": int(metrics.get("saw_misses", 0)),
		"pasadas_cepillo": int(metrics.get("planing_passes", 0)),
		"defectos_madera_detectados": int(metrics.get("lumber_defects_found", 0)),
		"fijaciones_madera": int(metrics.get("lumber_setup_actions", 0)),
		"marcas_medicion_madera": int(metrics.get("lumber_measurement_marks", 0)),
		"errores_contra_veta": int(metrics.get("plane_grain_errors", 0)),
		"sacos_prueba_tabla": int(metrics.get("lumber_load_sacks", 0)),
		"errores_carpinteria": int(metrics.get("lumber_mistakes", 0)),
		"oportunidades_totales_carpinteria": get_lumber_opportunities(),
		"oportunidades_carpinteria": get_lumber_attempts_left(),
		"fibras_canamo_limpias": int(metrics.get("rope_fibers_cleaned", 0)),
		"pasos_trenzado_cuerda": int(metrics.get("rope_braid_steps", 0)),
		"torsiones_rueca_cuerda": int(metrics.get("rope_twists", 0)),
		"errores_corderia": int(metrics.get("rope_mistakes", 0)),
		"oportunidades_totales_corderia": get_rope_opportunities(),
		"oportunidades_corderia": get_rope_attempts_left(),
		"segundos_tension_estable": snappedf(float(metrics.get("rope_stable_seconds", 0.0)), 0.1),
		"ajustes_compuerta_molino": int(metrics.get("mill_gate_adjustments", 0)),
		"segundos_estables_molino": snappedf(float(metrics.get("mill_stable_seconds", 0.0)), 0.1),
		"atascos_molino": int(metrics.get("mill_jams", 0)),
		"tandas_trigo_molidas": int(metrics.get("mill_batches_processed", 0)),
		"objetos_carro": metrics.get("cart_items_packed", []).duplicate(),
		"ajustes_equilibrio_carro": int(metrics.get("cart_balance_moves", 0)),
		"intentos_ruta_cercada": int(metrics.get("cart_route_attempts", 0)),
		"objeto_protegido_carro": str(metrics.get("cart_protected_item", "")),
		"pistas_historicas": int(metrics.historical_clues_found),
		"piezas_molino_instaladas": int(metrics.get("mill_parts_installed", 0)),
		"prueba_giro_molino_completada": bool(metrics.get("mill_repair_verified", false)),
		"intentos_compra_sin_dinero": int(metrics.failed_purchases),
		"eventos": metrics.events.duplicate(true),
	}


func save_progress() -> void:
	if capturing_session:
		return
	capturing_session = true
	if run_started and not restoring_session:
		var current := SESSION_MEMORY.capture(get_tree().current_scene)
		if not current.is_empty():
			checkpoint = current
		_remember_chapter_checkpoint(checkpoint)
	var data := {
		"save_version": SAVE_VERSION,
		"run_started": run_started,
		"checkpoint": checkpoint,
		"chapter_checkpoints": chapter_checkpoints,
		"difficulty": difficulty,
		"coins": coins,
		"inventory": inventory,
		"flags": flags,
		"metrics": metrics,
		"phase_started_at": phase_started_at,
		"phase_complete": phase_complete,
		"phase_summary": phase_summary,
		"phase_two": phase_two,
	}
	# Write the complete checkpoint before replacing the previous save.
	var temporary := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.flush()
		file.close()
		var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(SAVE_PATH))
		if result != OK:
			push_error("No se pudo guardar la partida: " + error_string(result))
	capturing_session = false


func load_progress() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var contents := file.get_as_text()
	file.close()
	var data = JSON.parse_string(contents)
	if not data is Dictionary:
		return false
	checkpoint = data.get("checkpoint", {}) if data.get("checkpoint", {}) is Dictionary else {}
	chapter_checkpoints = data.get("chapter_checkpoints", {}) if data.get("chapter_checkpoints", {}) is Dictionary else {}
	run_started = bool(data.get("run_started", _has_legacy_run(data)))
	if run_started and checkpoint.is_empty():
		# Saves from earlier builds have no coordinates; retain their achievements.
		checkpoint = {"scene": "res://scenes/sheep_farm.tscn", "position": [576, 585], "facing": "down"}
	var save_version := int(data.get("save_version", 1))
	difficulty = str(data.get("difficulty", DIFFICULTY_HARD))
	if difficulty not in [DIFFICULTY_EASY, DIFFICULTY_HARD]:
		difficulty = DIFFICULTY_HARD
	coins = int(data.get("coins", 0))
	inventory = data.get("inventory", {"herramientas": 1})
	flags = data.get("flags", {})
	metrics = data.get("metrics", {})
	phase_started_at = int(data.get("phase_started_at", Time.get_unix_time_from_system()))
	phase_complete = bool(data.get("phase_complete", false))
	phase_summary = data.get("phase_summary", {}) if data.get("phase_summary", {}) is Dictionary else {}
	phase_two = data.get("phase_two", {}) if data.get("phase_two", {}) is Dictionary else {}
	if str(checkpoint.get("scene", "")) == "res://scenes/ui/phase_two_construction.tscn":
		checkpoint = {"scene": PHASE_TWO_INTRO, "story_index": 0}
	# Preserve all workshop checkpoints while routing earlier chapter-two saves
	# through the new explorable arrival. The factory remains available to tools.
	if str(checkpoint.get("scene", "")) == PHASE_TWO_FACTORY:
		checkpoint = {"scene": PHASE_TWO_SCENE}
	if str(chapter_checkpoints.get("2", {}).get("scene", "")) == PHASE_TWO_FACTORY:
		chapter_checkpoints["2"] = {"scene": PHASE_TWO_SCENE}
	_remember_chapter_checkpoint(checkpoint)
	if phase_complete and phase_summary.is_empty():
		phase_summary = build_report()
		# Older saves retain the original departure time when it was recorded.
		for event in metrics.get("events", []):
			if str(event.get("description", "")) == "Abordó el tren hacia la ciudad industrial.":
				phase_summary["tiempo_segundos"] = maxi(0, int(event.get("second", 0)))
	if save_version < SAVE_VERSION:
		if not phase_complete:
			if save_version < 3:
				_migrate_legacy_economy()
			if save_version < 4:
				_migrate_phase_expansion()
		if save_version < 5:
			_migrate_coach_route()
		if save_version < 6:
			flags["rail_dispatch_completed"] = phase_complete
			flags["rail_wagon_parked"] = phase_complete
			flags["rail_route_prepared"] = phase_complete
		if save_version < 7:
			var ready: bool = flags.get("rail_dispatch_completed", false) or phase_complete
			flags["rail_track_angles"] = [0, 2, 1, 3] if ready else [1, 0, 3, 0]
			flags["rail_track_checks"] = 4 if ready else 0
			flags["rail_route_prepared"] = ready
		if save_version < 8:
			_migrate_rail_turnouts()
		if save_version < 9:
			flags["forge_attempts_left"] = int(flags.get("forge_attempts_left", 3))
		if save_version < 10:
			# Expand the old three-opportunity pool, keeping already spent chances spent.
			flags["forge_attempts_left"] = clampi(int(flags.get("forge_attempts_left", 3)), 0, 3) + FORGE_OPPORTUNITIES - 3
			flags["forge_progress"] = {}
		if save_version < 11:
			flags["forge_attempts_spent"] = maxi(0, get_forge_opportunities() - int(flags.get("forge_attempts_left", get_forge_opportunities())))
		if save_version < 12:
			_migrate_without_elena_puzzle()
		if save_version < 13:
			_migrate_without_rail_puzzle()
		if save_version < 18:
			_migrate_london_economy()
		save_progress()
	return true


func _migrate_london_economy() -> void:
	# Versioned, one-time adjustment; never reset the purse or replay the sale.
	if flags.get("flour_sold", false) or phase_complete:
		coins += FLOUR_SALE_VALUE - 13
		flags["flour_sold"] = true
		if not phase_summary.is_empty(): phase_summary["monedas_harina"] = FLOUR_SALE_VALUE
		if phase_complete and not phase_summary.is_empty(): _write_report(phase_summary)
	if phase_complete: consume_train_ticket()


func _migrate_rail_turnouts() -> void:
	var ready: bool = flags.get("rail_dispatch_completed", false) or phase_complete
	var previous: Array = flags.get("rail_track_angles", [1, 0, 3, 0])
	var checked := clampi(int(flags.get("rail_track_checks", 0)), 0, 4)
	var updated: Array = RAIL_ROUTE.TARGETS.duplicate() if ready else RAIL_ROUTE.INITIAL.duplicate()
	if not ready and previous.size() == 4:
		for old_index in range(4):
			# The two exit curves face the opposite way in the expanded topology.
			updated[[1, 2, 6, 7][old_index]] = posmod(int(previous[old_index]) + (2 if old_index >= 2 else 0), 4)
		if checked > 0:
			updated[0] = RAIL_ROUTE.TARGETS[0]
			for old_index in range(checked):
				var new_index: int = [1, 2, 6, 7][old_index]
				updated[new_index] = RAIL_ROUTE.TARGETS[new_index]
	flags["rail_track_angles"] = updated
	flags["rail_track_checks"] = RAIL_ROUTE.COUNT if ready else (mini(checked + 1, 3) if checked > 0 else 0)
	flags["rail_route_prepared"] = ready


func _migrate_legacy_economy() -> void:
	if flags.get("tools_sold", false) or flags.get("ticket_bought", false):
		coins = 0
		inventory["herramientas"] = 1
		inventory.erase("boleto")
	flags["tools_sold"] = false
	flags["ticket_bought"] = false
	flags["tools_given_to_mateo"] = false
	flags["wheelwright_forge_completed"] = false
	flags["flour_milled"] = false
	flags["flour_sold"] = false


func _migrate_phase_expansion() -> void:
	flags["mill_operation_started"] = bool(flags.get("flour_milled", false))
	# Las partidas que ya compraron el boleto no deben quedar bloqueadas por la nueva misión.
	flags["cart_mission_completed"] = bool(flags.get("ticket_bought", false))
	metrics["mill_gate_adjustments"] = int(metrics.get("mill_gate_adjustments", 0))
	metrics["mill_stable_seconds"] = float(metrics.get("mill_stable_seconds", 0.0))
	metrics["mill_jams"] = int(metrics.get("mill_jams", 0))
	metrics["mill_batches_processed"] = int(metrics.get("mill_batches_processed", REQUIRED_WHEAT if flags.get("flour_milled", false) else 0))
	metrics["cart_items_packed"] = metrics.get("cart_items_packed", [])
	metrics["cart_balance_moves"] = int(metrics.get("cart_balance_moves", 0))
	metrics["cart_route_attempts"] = int(metrics.get("cart_route_attempts", 0))
	metrics["cart_protected_item"] = str(metrics.get("cart_protected_item", ""))


func _migrate_coach_route() -> void:
	metrics["passenger_coach_trips"] = int(metrics.get("passenger_coach_trips", 0))
	metrics["coach_fares_paid"] = int(metrics.get("coach_fares_paid", 0))
	if flags.get("ticket_bought", false) or phase_complete:
		flags["coach_allowance_received"] = true
		flags["coach_fare_paid"] = true
		flags["coach_station_reached"] = true


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))


func has_saved_game() -> bool:
	return run_started and not checkpoint.is_empty() and ResourceLoader.exists(str(checkpoint.get("scene", "")))


func start_new_game(selected_difficulty: String) -> void:
	difficulty = selected_difficulty if selected_difficulty in [DIFFICULTY_EASY, DIFFICULTY_HARD] else DIFFICULTY_HARD
	reset_progress(false)
	run_started = true
	checkpoint = {"scene": PHASE_INTRO_SCENE, "story_index": 0}
	restoring_session = true
	save_progress()
	_open_phase_intro()


func continue_saved_game() -> bool:
	if not has_saved_game():
		return false
	restoring_session = true
	pending_spawn = Vector2.ZERO
	pending_travel_scene = str(checkpoint.get("boat_destination", ""))
	pending_coach_destination = str(checkpoint.get("coach_destination", ""))
	var error := get_tree().change_scene_to_file(str(checkpoint.scene))
	if error != OK:
		restoring_session = false
		push_error("No se pudo continuar la partida: " + error_string(error))
		return false
	return true


func open_phase_two() -> void:
	if not is_phase_two_unlocked(): return
	if phase_summary.is_empty(): phase_summary = build_report()
	save_progress()
	var destination: Dictionary = chapter_checkpoints.get("2", {}).duplicate(true)
	if destination.is_empty():
		destination = {"scene": PHASE_TWO_SCENE if bool(phase_two.get("intro_seen", false)) else PHASE_TWO_INTRO, "story_index": 0, "journal_page": 2}
	destination["journal_open"] = false
	_select_chapter_checkpoint(destination)


func _open_checkpoint_scene() -> void:
	var error := get_tree().change_scene_to_file(str(checkpoint.get("scene", PHASE_TWO_INTRO)))
	if error != OK:
		restoring_session = false
		push_error("No se pudo abrir la fase seleccionada: " + error_string(error))


func restore_scene_session(scene: Variant) -> void:
	if not is_instance_valid(scene) or scene != get_tree().current_scene:
		return
	if restoring_session and str(checkpoint.get("scene", "")) == scene.scene_file_path:
		SESSION_MEMORY.restore(scene, checkpoint)
		restoring_session = false
	if run_started:
		save_progress()


func _process(delta: float) -> void:
	if not run_started or restoring_session:
		return
	autosave_elapsed += delta
	if autosave_elapsed >= 1.0:
		autosave_elapsed = 0.0
		save_progress()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and run_started:
		save_progress()


func get_difficulty_name() -> String:
	return "Fácil" if is_easy_difficulty() else "Difícil"


func get_puzzle_progress() -> Array[Dictionary]:
	return [
		{"id": "forge", "label": "Herrero", "icon": "res://assets/gba/ui/pause_anvil.svg", "completed": bool(flags.get("wheelwright_forge_completed", false))},
		{"id": "rope", "label": "Hilandero", "icon": "res://assets/gba/ui/rope_item.svg", "completed": bool(flags.get("rope_puzzle_completed", false))},
		{"id": "lumber", "label": "Leñador", "icon": "res://assets/gba/ui/plank_item.svg", "completed": bool(flags.get("lumber_puzzle_completed", false))},
		{"id": "mill", "label": "Molino", "icon": "res://assets/gba/ui/pause_mill.svg", "completed": bool(flags.get("flour_milled", false))},
	]


func get_phase_guidance() -> String:
	if phase_complete:
		return "Los cuatro puzzles ya están completados. Puedes visitar la aldea libremente; la Fase 2 sigue desbloqueada en el cuaderno y el menú principal."
	if not flags.get("villager_spoken", false):
		return "El cercamiento ha cambiado la aldea. Escucha a Elena y descubre por qué las familias necesitan partir."
	var finished := int(flags.get("wheelwright_forge_completed", false)) + int(flags.get("rope_puzzle_completed", false)) + int(flags.get("lumber_puzzle_completed", false))
	if finished < 3:
		var missing: Array[String] = []
		if not flags.get("wheelwright_forge_completed", false): missing.append("la rueda de Mateo")
		if not flags.get("rope_puzzle_completed", false): missing.append("la cuerda de Silas")
		if not flags.get("lumber_puzzle_completed", false): missing.append("la tabla de Bruno")
		return "Talleres completados: %d de 3. Para reparar el molino falta %s." % [finished, ", ".join(missing)]
	if not flags.get("mill_repaired", false):
		return "Las tres piezas están listas. Instálalas en el molino y comprueba el movimiento del eje."
	if not flags.get("flour_milled", false):
		return "El molino funciona. Regula el agua y procesa el trigo para completar este puzzle."
	if not flags.get("flour_sold", false):
		return "Vende la harina a Tomás por 100 monedas: 3 para la diligencia y 10 para el tren."
	if not flags.get("coach_station_reached", false):
		return "La harina ha financiado tu viaje. Busca a Ramón en la estación de carretas."
	if not flags.get("ticket_bought", false):
		return "Has llegado a la estación. Compra tu boleto en la taquilla y entra al andén para subir al tren."
	return "Los cuatro puzzles están completos y tu boleto está en regla. Sube al tren rumbo a la ciudad."


func _migrate_without_elena_puzzle() -> void:
	# Older flour sales paid 10. Supply only the missing fare, never duplicate Elena's old reward.
	if flags.get("flour_sold", false) and not flags.get("coach_allowance_received", false):
		coins += COACH_FARE
		flags["coach_allowance_received"] = true
		metrics["events"] = metrics.get("events", [])
		record_event("Ajustó el antiguo pago de la harina a 13 monedas para cubrir la diligencia y el tren.")
	var active: Dictionary = checkpoint.get("popup", {})
	if str(active.get("name", "")) == "MigrationCartPopup":
		checkpoint.erase("popup")
		checkpoint.erase("hud")
	var saved_hud: Dictionary = checkpoint.get("hud", {})
	var dialogue: Dictionary = saved_hud.get("dialogue", {})
	if str(dialogue.get("speaker", "")).begins_with("Elena"):
		saved_hud.erase("dialogue")
		checkpoint["hud"] = saved_hud


func _migrate_without_rail_puzzle() -> void:
	# Resume older saves on the same platform without reopening the retired puzzle.
	var active: Dictionary = checkpoint.get("popup", {})
	if str(active.get("name", "")) == "RailDispatchPopup":
		checkpoint.erase("popup")
	var saved_hud: Dictionary = checkpoint.get("hud", {})
	var dialogue: Dictionary = saved_hud.get("dialogue", {})
	var options: Array = dialogue.get("options", [])
	var obsolete := str(dialogue.get("speaker", "")) == "Jefe de estación"
	for option in options:
		if option is Dictionary and str(option.get("action", "")) == "open_rail_dispatch":
			obsolete = true
	if obsolete:
		saved_hud.erase("dialogue")
		checkpoint["hud"] = saved_hud


func _has_legacy_run(data: Dictionary) -> bool:
	if bool(data.get("phase_complete", false)) or int(data.get("coins", 0)) > 0:
		return true
	var previous_metrics: Dictionary = data.get("metrics", {})
	if int(previous_metrics.get("interactions", 0)) > 0 or int(previous_metrics.get("wheat_harvested", 0)) > 0:
		return true
	var previous_flags: Dictionary = data.get("flags", {})
	for flag in ["villager_spoken", "tools_given_to_mateo", "wheelwright_forge_completed", "rope_puzzle_completed", "lumber_puzzle_completed", "mill_repaired", "ticket_bought"]:
		if bool(previous_flags.get(flag, false)): return true
	return false
