extends Node

var backups: Dictionary = {}
var failures: Array[String] = []

func begin() -> void:
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	GameState.reset_progress(false)
	GameState.run_started = true
	GameState.flags.ticket_bought = true
	GameState.flags.cart_mission_completed = true
	GameState.flags.rail_dispatch_completed = false
	GameState.flags.coach_fare_paid = true
	GameState.flags.coach_station_reached = true
	GameState.inventory["boleto"] = 1
	var platform = await _switch("res://scenes/station_platform.tscn")
	var hud = platform.get_node("HUD")
	hud._select_dialogue_action("board_train")
	hud._select_dialogue_action("depart_train")
	await get_tree().create_timer(6.0).timeout
	_check(GameState.phase_complete and hud.completion_overlay.visible, "The real train departure must finish chapter one")
	_check(FileAccess.file_exists(GameState.REPORT_PATH), "Finishing the chapter must retain its report")
	hud._close_completion()
	var next_chapter = await _changed()
	_check(next_chapter.scene_file_path == GameState.PHASE_TWO_SCENE, "Continue must open chapter two's construction screen")
	# Legacy completed saves can still be in the village or station.
	var station = await _switch("res://scenes/station.tscn")
	# Keep the old HUD alive but detached during the second awaited layout frame.
	# This reproduces scene replacement without depending on queue_free timing.
	hud = station.get_node("HUD")
	get_tree().process_frame.connect(station.remove_child.bind(hud), CONNECT_ONE_SHOT)
	hud._fit_pause_panel()
	await get_tree().process_frame
	await get_tree().process_frame
	hud.queue_free()
	await get_tree().process_frame
	station = await _switch("res://scenes/station.tscn")
	hud = station.get_node("HUD")
	GameState.interact("return_passenger_coach")
	_check(hud.dialogue_panel.visible and hud.active_dialogue.options[0].action == "return_by_coach", "Ramón must offer the return journey after the chapter ends")
	var coins_before: int = GameState.coins
	var fare_before := int(GameState.metrics.get("coach_fares_paid", 0))
	# Start a fit, then leave while its two-frame layout wait is running.
	hud._fit_pause_panel()
	await get_tree().process_frame
	hud._select_dialogue_action("return_by_coach")
	var travel = await _changed()
	_check(travel.scene_file_path == "res://scenes/coach_travel.tscn" and travel.returning, "Return must open the animated coach journey")
	travel._finish_travel()
	var depot = await _changed()
	_check(depot.scene_file_path == "res://scenes/carriage_depot.tscn", "Return must arrive at the carriage depot")
	_check(GameState.coins == coins_before and int(GameState.metrics.get("coach_fares_paid", 0)) == fare_before, "The included return must not charge another fare")
	_check(GameState.phase_complete and FileAccess.file_exists(GameState.REPORT_PATH), "Returning must preserve the completed chapter and report")
	depot.get_node("HUD")._select_dialogue_action("go_village")
	var village = await _changed()
	_check(village.scene_file_path == "res://scenes/game.tscn" and village.get_node("World/Player").controls_enabled, "The player must return to the village with movement enabled")
	hud = village.get_node("HUD")
	hud._open_pause()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = hud.get_node("Root/PauseOverlay/Panel")
	_check(panel.get_global_rect().get_center().distance_to(get_viewport().get_visible_rect().size * 0.5) < 2, "The completed-chapter pause must stay centered")
	_check(hud.get_node("%PauseDifficultyLabel").text == "Dificultad: " + GameState.get_difficulty_name(), "Returning must retain the selected difficulty")
	GameState.save_progress()
	_check(str(GameState.checkpoint.get("scene", "")) == "res://scenes/game.tscn" and GameState.has_saved_game(), "The completed game must save the new village location")
	GameState.run_started = false
	for path in backups:
		if backups[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backups[path])
			file.close()
	print("COMPLETED CHAPTER RETURN OK: departure, detached HUD layout, return coach, village, preserved completion and save" if failures.is_empty() else "COMPLETED CHAPTER RETURN FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)

func _switch(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	return await _changed()

func _changed() -> Node:
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	return get_tree().current_scene

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
