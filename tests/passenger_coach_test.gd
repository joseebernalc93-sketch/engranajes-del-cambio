extends Node

var capture_ui := false
var failures: Array[String] = []
var dialogue: Dictionary = {}
var saved_files: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		saved_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	capture_ui = "--capture-ui" in OS.get_cmdline_user_args()
	GameState.reset_progress(false)
	EventBus.dialogue_requested.connect(func(payload): dialogue = payload)
	var village := await _load_map("res://scenes/game.tscn")
	var player := _player(village)
	player.position = Vector2(1070, 484)
	await _settle()
	await _walk_to(player, Vector2(1110, 484))
	_check(str(dialogue.text).contains("carretas"), "The village exit must lead to the passenger carriage depot")
	village.get_node("HUD")._select_dialogue_action("go_station")
	var depot := await _wait_map("res://scenes/carriage_depot.tscn")
	if depot == null:
		return
	player = _player(depot)
	_check(player.position == Vector2(90, 480), "The depot must be entered from the village road")
	await _walk_to(player, Vector2(550, 480))
	await _walk_to(player, Vector2(550, 455))
	await _settle()
	player._update_interactable()
	_check(player.nearest_interactable == depot.get_node("World/Ramon"), "The coachman must be reachable on foot")
	depot.get_node("World/Ramon").interact()
	_check(str(dialogue.text).contains("3 monedas") and dialogue.options.is_empty(), "An empty purse must not offer a paid trip")
	_check(not GameState.book_passenger_coach("res://scenes/station.tscn") and GameState.coins == 0, "Insufficient funds must not book or deduct a fare")
	depot.get_node("HUD")._select_dialogue_action("close")
	_check(player.controls_enabled, "Cancelling the fare dialogue must restore controls")
	_complete_prior_work()
	GameState.coins = 0
	GameState.flags.flour_sold = false
	GameState.add_item("costal_harina")
	EventBus.dialogue_action_selected.emit("sell_flour")
	_check(GameState.coins == 13, "The baker must fund both the carriage and the train")
	EventBus.dialogue_action_selected.emit("sell_flour")
	_check(GameState.coins == 13, "The flour sale must be paid only once")
	depot.get_node("World/Ramon").interact()
	_check(dialogue.options[0].action == "take_passenger_coach", "Ramón must offer the paid carriage trip")
	depot.get_node("HUD")._select_dialogue_action("close")
	_check(GameState.coins == 13 and not GameState.flags.coach_fare_paid, "Cancelling must not charge the fare")
	await _walk_to(player, Vector2(510, 455))
	depot.get_node("HUD").toast.visible = false
	await _capture("passenger_depot")
	depot.get_node("World/Ramon").interact()
	depot.get_node("HUD")._select_dialogue_action("take_passenger_coach")
	var voyage := await _wait_map("res://scenes/coach_travel.tscn")
	_check(GameState.coins == 10 and GameState.flags.coach_fare_paid and GameState.metrics.coach_fares_paid == 3, "Booking must charge exactly 3 coins and reserve 10 for the train")
	_check(not GameState.book_passenger_coach("res://scenes/station.tscn") and GameState.coins == 10, "Repeated booking callbacks must not charge twice")
	await _preview_voyage(voyage)
	var exterior := await _wait_map("res://scenes/station.tscn")
	player = _player(exterior)
	_check(player.position == Vector2(610, 430) and player.controls_enabled, "Carriage arrival must leave the player in front of the station with controls")
	_check(not exterior.has_node("World/Train") and not exterior.has_node("TrainDepartureController"), "The new front entrance must have no train or platform")
	_check(GameState.flags.coach_station_reached and GameState.metrics.passenger_coach_trips == 1, "Arrival must complete and record the trip once")
	_check(not player.test_move(player.transform, Vector2(0, -1)), "Arrival must not embed the player in a coach, horse or building")
	await _capture("station_main_entrance")
	await _walk_to(player, Vector2(610, 400))
	await _walk_to(player, Vector2(575, 400))
	await _walk_to(player, Vector2(575, 367))
	await _settle()
	_check(str(dialogue.text).contains("taquilla"), "The front door must open the waiting hall and ticket office")
	exterior.get_node("HUD")._select_dialogue_action("go_station_interior")
	var hall := await _wait_map("res://scenes/station_interior.tscn")
	player = _player(hall)
	await _walk_to(player, Vector2(576, 410))
	await _walk_to(player, Vector2(850, 410))
	await _walk_to(player, Vector2(850, 355))
	await _settle()
	player._update_interactable()
	_check(player.nearest_interactable == hall.get_node("World/TicketClerk"), "The preserved ticket office must be reachable")
	hall.get_node("World/TicketClerk").interact()
	hall.get_node("HUD")._select_dialogue_action("buy_ticket")
	_check(GameState.coins == 0 and GameState.has_item("boleto"), "The remaining 10 coins must buy the train ticket")
	await _walk_to(player, Vector2(600, 355))
	await _walk_to(player, Vector2(576, 325))
	await _settle()
	player._update_interactable()
	_check(player.nearest_interactable == hall.get_node("World/PlatformAccess"), "The new platform access must be reachable")
	hall.get_node("World/PlatformAccess").interact()
	hall.get_node("HUD")._select_dialogue_action("go_station_platform")
	var platform := await _wait_map("res://scenes/station_platform.tscn")
	_check(platform.has_node("World/Train") and platform.has_node("TrainDepartureController"), "The train and departure animation must be preserved in the platform scene")
	# Return through the hall and take the already-paid coach with an empty purse.
	platform._on_dialogue_action("go_station_interior")
	hall = await _wait_map("res://scenes/station_interior.tscn")
	hall._on_dialogue_action("go_station_exterior")
	exterior = await _wait_map("res://scenes/station.tscn")
	exterior.get_node("World/Ramon").interact()
	_check(dialogue.options[0].action == "return_by_coach", "Ramón must offer the included return journey")
	exterior.get_node("HUD")._select_dialogue_action("return_by_coach")
	voyage = await _wait_map("res://scenes/coach_travel.tscn")
	_check(voyage.returning and voyage.coach.facing_left, "The return journey must face the correct direction")
	await _preview_voyage(voyage)
	depot = await _wait_map("res://scenes/carriage_depot.tscn")
	player = _player(depot)
	_check(player.position == Vector2(550, 465) and player.controls_enabled and GameState.coins == 0, "The included return must be free and spawn safely by the coachman")
	_check(GameState.metrics.passenger_coach_trips == 2 and GameState.metrics.coach_fares_paid == 3, "A return must not duplicate the fare")
	_check(GameState.load_progress() and GameState.flags.coach_fare_paid and GameState.coins == 0, "The paid coach fare and remaining balance must survive save/load")
	await _walk_to(player, Vector2(450, 480))
	await _walk_to(player, Vector2(90, 480))
	for _tick in range(20):
		if not is_instance_valid(player) or not player.is_inside_tree():
			break
		player.move_and_collide(Vector2(-4, 0))
		await get_tree().physics_frame
	await _wait_map("res://scenes/game.tscn")
	await _test_train_departure()
	await _test_legacy_save()
	_restore_files()
	if failures.is_empty():
		print("PASSENGER COACH TEST OK: village/depot route, insufficient funds, cancellation, one 3-coin fare, 13-coin flour payment, animated departure/road/arrival/disembarking, real train exterior/interior/platform, affordable train ticket, included return, save/load and legacy migration")
	get_tree().quit(0 if failures.is_empty() else 1)


func _preview_voyage(voyage: Node) -> void:
	voyage.set_process(false)
	var old_auto: bool = voyage.auto_change_destination
	voyage.auto_change_destination = false
	var stages: Dictionary = {}
	var frames: Dictionary = {}
	var captured: Dictionary = {}
	var wheel_start: float = voyage.coach.wheel_angle
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	voyage._unhandled_input(event)
	_check(not voyage.finishing, "The initial embark key must not immediately skip travel")
	for tick in range(int(ceil(voyage.TOTAL_TIME * 60.0))):
		voyage._process(1.0 / 60.0)
		voyage.coach._process(1.0 / 60.0)
		stages[voyage.stage] = true
		frames[voyage.coach.horse_frame()] = true
		var screen: Vector2 = (voyage.coach.position - voyage.camera.position - voyage.camera.offset) * voyage.camera.zoom + get_viewport().get_visible_rect().size * 0.5
		if voyage.stage == "country_road":
			_check(screen.y < get_viewport().get_visible_rect().size.y - 94, "The moving coach must remain above the cinematic footer")
		if capture_ui and not captured.has(voyage.stage):
			var minimum := {"boarding": 0.5, "departure": 2.2, "country_road": 6.0, "arrival": 13.0, "disembarking": 15.2}
			if voyage.elapsed >= minimum.get(voyage.stage, 0.0):
				captured[voyage.stage] = true
				await _capture(("return_coach_" if voyage.returning else "coach_") + voyage.stage)
		if tick % 30 == 0:
			await get_tree().process_frame
	_check(stages.size() == 5 and frames.size() == 4, "Every journey stage and all four horse gait frames must run")
	_check(voyage.coach.wheel_angle != wheel_start, "The carriage wheels must rotate during travel")
	_check(voyage.passenger.position.is_equal_approx(voyage.DEPOT_SPAWN if voyage.returning else voyage.STATION_SPAWN), "The passenger must walk to the real destination spawn")
	voyage.auto_change_destination = old_auto
	# Exercise the same guarded completion callback even when the preview already began fading.
	voyage._change_destination()
	await get_tree().create_timer(0.1).timeout


func _test_train_departure() -> void:
	GameState.flags.rail_dispatch_completed = false
	_check(not GameState.flags.rail_dispatch_completed, "Boarding must not require the removed railway puzzle")
	GameState.pending_spawn = Vector2(640, 410)
	var platform := await _load_map("res://scenes/station_platform.tscn")
	var player := _player(platform)
	await _walk_to(player, Vector2(680, 400))
	platform.get_node("World/Train").interact()
	_check(dialogue.options[0].action == "board_train", "The original train must still accept the purchased ticket")
	platform.get_node("HUD")._select_dialogue_action("board_train")
	_check(not player.visible and platform.get_node("TrainDepartureController").boarded, "Boarding the original train must still work")
	platform.get_node("HUD")._select_dialogue_action("depart_train")
	await get_tree().create_timer(5.65).timeout
	_check(GameState.phase_complete and FileAccess.file_exists(GameState.REPORT_PATH), "The preserved train departure must complete the phase and write its report")
	_check(GameState.build_report().get("viajes_diligencia", 0) == 2, "The final report must record the new coach journeys")


func _test_legacy_save() -> void:
	var legacy := {"save_version": 4, "coins": 10, "inventory": {"costal_harina": 1}, "flags": {"flour_sold": true, "cart_mission_completed": true, "mill_repaired": true, "mill_plank_installed": true, "ticket_bought": false}, "metrics": {"events": [], "wheat_harvested": 3}}
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(GameState.load_progress() and GameState.coins == 13, "An old ten-coin flour sale must receive the missing coach fare")
	_check(GameState.flags.cart_mission_completed and GameState.flags.mill_repaired and GameState.flags.mill_plank_installed, "The save migration must preserve existing puzzle completion and installed pieces")
	_check(GameState.load_progress() and GameState.coins == 13, "Loading a migrated save again must not duplicate the allowance")
	legacy.flags.ticket_bought = true
	legacy.coins = 0
	legacy.inventory = {"boleto": 1}
	file = FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(GameState.load_progress() and GameState.flags.coach_fare_paid and GameState.flags.coach_station_reached and GameState.coins == 0, "Old saves with a train ticket must remain able to finish without paying a new fare")


func _complete_prior_work() -> void:
	for flag in ["villager_spoken", "wheelwright_forge_completed", "lumber_puzzle_completed", "rope_puzzle_completed", "mill_repaired", "flour_milled", "flour_sold"]:
		GameState.flags[flag] = true
	GameState.metrics.wheat_harvested = 3


func _player(map: Node) -> CharacterBody2D:
	var player := map.get_node("World/Player") as CharacterBody2D
	player.set_physics_process(false)
	return player


func _load_map(path: String) -> Node:
	var previous := get_tree().current_scene
	get_tree().current_scene = null
	if previous:
		previous.free()
	var map: Node = load(path).instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _settle()
	return map


func _wait_map(path: String) -> Node:
	for _tick in range(100):
		await get_tree().process_frame
		var map := get_tree().current_scene
		if map and map.scene_file_path == path:
			await _settle()
			return map
	_check(false, "Expected map did not load: " + path)
	return null


func _walk_to(player: CharacterBody2D, target: Vector2) -> void:
	while is_instance_valid(player) and player.is_inside_tree() and player.position.distance_to(target) > 0.1:
		var collision := player.move_and_collide((target - player.position).limit_length(8.0))
		if collision:
			_check(false, "Route blocked at %s toward %s" % [player.position, target])
			return
		await get_tree().physics_frame


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _capture(file_name: String) -> void:
	if not capture_ui:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/passenger_coach"))
	_check(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/passenger_coach/%s.png" % file_name)) == OK, "Journey preview must save")


func _restore_files() -> void:
	for path in saved_files:
		if saved_files[path] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(saved_files[path])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

