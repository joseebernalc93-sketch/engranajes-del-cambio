extends Node

var backups: Dictionary = {}
var failures: Array[String] = []

func begin() -> void:
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	GameState.reset_progress(false)
	for flag in ["villager_spoken", "wheelwright_forge_completed", "rope_puzzle_completed", "lumber_puzzle_completed", "mill_repaired", "flour_milled", "flour_sold", "coach_fare_paid", "coach_station_reached", "ticket_bought"]:
		GameState.flags[flag] = true
	GameState.metrics.wheat_harvested = 3
	GameState.flags.rail_dispatch_completed = false
	var legacy := {"save_version": 12, "run_started": true, "difficulty": "facil", "coins": 0, "inventory": {"boleto": 1}, "flags": GameState.flags.duplicate(true), "metrics": GameState.metrics.duplicate(true), "phase_complete": false, "checkpoint": {"scene": "res://scenes/station_platform.tscn", "position": [680, 400], "facing": "left", "popup": {"name": "RailDispatchPopup", "state": {"selected": 4, "inspector_active": true}}, "hud": {"dialogue": {"speaker": "Jefe de estación", "text": "Prepara los cambiavías.", "options": [{"label": "Preparar la vía", "action": "open_rail_dispatch"}]}}}}
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(GameState.load_progress(), "A version-12 railway-puzzle save must remain loadable")
	_check(not GameState.checkpoint.has("popup") and not GameState.checkpoint.hud.has("dialogue"), "Removed-puzzle checkpoints and their obsolete dialogue must be cleared")
	_check(GameState.coins == 0 and GameState.has_item("boleto") and GameState.get_forge_opportunities() == 15, "Migration must preserve money, ticket and Easy difficulty")
	_check(GameState.get_puzzle_progress().size() == 4, "The journal must contain exactly four workshops")
	_check(GameState.load_progress() and GameState.coins == 0, "Loading the migrated save twice must not change the balance")
	_check(GameState.continue_saved_game(), "Continue must still resume the saved platform")
	await get_tree().scene_changed
	for frame in 5: await get_tree().process_frame
	var station := get_tree().current_scene
	var player = station.get_node("World/Player")
	var hud = station.get_node("HUD")
	var departure = station.get_node("TrainDepartureController")
	_check(not station.has_node("RailDispatchHost") and not station.has_node("RailDispatchPopup") and not station.has_node("World/SignalCabin"), "The station must have no railway-puzzle host, popup or trigger")
	_check(player.position.is_equal_approx(Vector2(680, 400)) and player.facing == "left" and player.controls_enabled, "Continue must restore the position with controls available")
	_check(not hud.dialogue_panel.visible and hud.is_processing_unhandled_input(), "The old modal must not trap the player")
	EventBus.dialogue_action_selected.emit("open_rail_dispatch")
	EventBus.rail_dispatch_requested.emit()
	await get_tree().process_frame
	_check(not station.has_node("RailDispatchPopup") and player.controls_enabled, "Obsolete callbacks must never reopen or lock the removed puzzle")
	GameState.flags.ticket_bought = false
	departure._board_train()
	_check(not departure.boarded and player.visible, "The train must still require a purchased ticket")
	hud._select_dialogue_action("close")
	GameState.flags.ticket_bought = true
	GameState.interact("train")
	_check(hud.active_dialogue.get("options", [])[0].action == "board_train", "Buying the ticket must lead directly to boarding")
	hud._select_dialogue_action("board_train")
	_check(departure.boarded and not player.visible and not GameState.flags.rail_dispatch_completed, "Boarding must work without railway completion")
	var train_start: Vector2 = station.get_node("World/Train").position
	var wheel_start: float = station.get_node("World/Train/SteamTrain").wheel_angle
	hud._select_dialogue_action("depart_train")
	await get_tree().create_timer(0.8).timeout
	_check(station.get_node("World/Train").position.x < train_start.x, "The train must keep its animated departure")
	_check(not is_equal_approx(station.get_node("World/Train/SteamTrain").wheel_angle, wheel_start), "The train wheels must still rotate")
	await get_tree().create_timer(5.0).timeout
	_check(GameState.phase_complete and hud.completion_overlay.visible and FileAccess.file_exists(GameState.REPORT_PATH), "Departure must finish chapter one and retain the report")
	_check(not GameState.flags.rail_dispatch_completed, "Finishing the chapter must not invent a removed-puzzle completion")
	GameState.run_started = false
	for path in backups:
		if backups[path] != null:
			file = FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backups[path])
			file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("RAIL PUZZLE REMOVAL OK: version-12 resume, four cards, ticket-only boarding, moving wheels and chapter completion")
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
