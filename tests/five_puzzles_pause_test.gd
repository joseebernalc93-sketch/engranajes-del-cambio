extends Node

var saved_files: Dictionary = {}
var dialogue: Dictionary = {}
var failures: Array[String] = []

func _ready() -> void:
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		saved_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	GameState.reset_progress(false)
	GameState.difficulty = GameState.DIFFICULTY_EASY
	EventBus.dialogue_requested.connect(func(payload): dialogue = payload)
	var village := preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	await _settle()
	_check(not village.has_node("MigrationCartPopup"), "Elena's puzzle must be absent from the village")
	var horse: Node2D = village.get_node("World/ElenaMigrationCart")
	_check(horse.position == Vector2(300, 285), "The horse and wagon must retain their position")
	GameState.flags.cart_mission_completed = true
	EventBus.objective_changed.emit(GameState.get_objective())
	await _settle()
	_check(is_instance_valid(horse) and horse.visible, "A legacy completion flag must not remove the horse")
	_check(village.has_node("World/ElenaHorseCollision"), "The horse's collision must remain")
	GameState.flags.cart_mission_completed = false
	GameState.metrics.wheat_harvested = 3
	GameState.interact("villager")
	_check(dialogue.speaker.begins_with("Elena"), "Elena must remain a character with dialogue")
	village.get_node("HUD")._select_dialogue_action("close")
	var hud = village.get_node("HUD")
	hud._open_pause()
	await _settle()
	_check(hud.pause_board.left_page.is_ancestor_of(hud.get_node("%PauseObjectiveLabel")) and hud.pause_board.left_page.is_ancestor_of(hud.get_node("%PauseInfo")), "Objective and guidance must belong to the left page")
	for status in hud.pause_board.cards.values():
		_check(hud.pause_board.right_page.is_ancestor_of(status), "All four illustrated cards must belong to the right page")
	_check(hud.pause_board.cards.size() == 4, "The menu must contain exactly four puzzle cards")
	_check(hud.pause_board.counter.text.contains("0 / 4"), "A fresh game must show 0 of 5")
	_check(hud.get_node("%PauseDifficultyLabel").text == "Dificultad: Fácil", "Easy difficulty must appear in the pause menu")
	await _capture("pause_journal_start")
	var before: String = hud.get_node("%PauseInfo").text
	for flag in ["wheelwright_forge_completed", "rope_puzzle_completed"]:
		GameState.flags[flag] = true
	EventBus.objective_changed.emit(GameState.get_objective())
	await _settle()
	_check(hud.pause_board.counter.text.contains("2 / 4"), "Completed crafts must count once each")
	_check(hud.get_node("%PauseInfo").text != before and "tabla de Bruno" in hud.get_node("%PauseInfo").text, "Guidance must describe the remaining work")
	_check(hud.pause_board.cards.forge.text.contains("Completado") and hud.pause_board.cards.lumber.text.contains("Pendiente"), "Card states must reflect real progress")
	await _capture("pause_four_puzzles_easy")
	GameState.flags.lumber_puzzle_completed = true
	GameState.flags.mill_repaired = true
	EventBus.objective_changed.emit(GameState.get_objective())
	_check(hud.pause_board.counter.text.contains("3 / 4"), "Repair alone must not finish the milling puzzle")
	GameState.flags.flour_milled = true
	EventBus.objective_changed.emit(GameState.get_objective())
	_check(hud.pause_board.counter.text.contains("4 / 4"), "Finished milling must complete the fourth puzzle")
	hud.get_node("%ResumeButton").pressed.emit()
	_check(not hud.pause_overlay.visible and village.get_node("World/Player").controls_enabled, "Continue must restore movement")
	GameState.add_item("costal_harina")
	GameState._sell_flour()
	_check(GameState.coins == 13, "The baker must pay 13 coins")
	GameState._sell_flour()
	_check(GameState.coins == 13, "Flour must not pay twice")
	GameState.interact("villager")
	_check(dialogue.options.is_empty(), "Elena must never offer the removed puzzle")
	hud._select_dialogue_action("close")
	_check(GameState.book_passenger_coach("res://scenes/station.tscn") and GameState.coins == 10, "The coach fare must leave the ten coins needed for the ticket")
	GameState.complete_passenger_coach_trip("res://scenes/station.tscn")
	EventBus.dialogue_action_selected.emit("buy_ticket")
	_check(GameState.flags.ticket_bought and GameState.coins == 0, "The ticket must be available without Elena's puzzle")
	GameState.difficulty = GameState.DIFFICULTY_HARD
	hud._open_pause()
	await _settle()
	_check(hud.pause_board.counter.text.contains("4 / 4"), "Milling must finish all four puzzles; the railway is not a puzzle")
	_check(hud.get_node("%PauseDifficultyLabel").text == "Dificultad: Difícil", "Hard difficulty must be displayed")
	_check(hud.get_node("%PauseObjectiveLabel").text.contains("sube al tren"), "The final objective must permit boarding")
	await _capture("pause_four_puzzles_complete")
	var panel: Control = hud.get_node("Root/PauseOverlay/Panel")
	_check(panel.size.y <= 624, "The pause menu must fit the reference viewport")
	var scene_tree := get_tree()
	var viewport := scene_tree.root
	viewport.size = Vector2i(800, 500)
	await _settle()
	_check(panel.size.y * panel.scale.y <= hud.pause_overlay.size.y - 24 + 0.1, "The pause menu must adapt to small windows")
	viewport.size = Vector2i(1152, 648)
	await _settle()
	hud.get_node("%PauseStoryButton").pressed.emit()
	await _settle()
	_check(hud.get_node("Root").has_node("EnclosureStory"), "The story review button must remain functional")
	hud.get_node("Root/EnclosureStory")._close_overlay()
	await _settle()
	village.free()
	_test_legacy_migration()
	for path in saved_files:
		if saved_files[path] != null:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(saved_files[path])
			file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("FOUR PUZZLES PAUSE OK: horse preserved, 13 coin economy, four cards, difficulty, guidance and save migration")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _test_legacy_migration() -> void:
	GameState.reset_progress(false)
	var old_flags := GameState.flags.duplicate(true)
	old_flags.flour_sold = true
	var old := {"save_version": 11, "run_started": true, "difficulty": "facil", "coins": 10, "inventory": {}, "flags": old_flags, "metrics": GameState.metrics.duplicate(true), "checkpoint": {"scene": "res://scenes/game.tscn", "position": [430, 480], "popup": {"name": "MigrationCartPopup", "state": {"stage": 2}}, "hud": {"dialogue": {"speaker": "Elena, campesina", "options": [{"action": "begin_migration_cart"}]}}}}
	_write_old_save(old)
	_check(GameState.load_progress() and GameState.coins == 13, "Old ten-coin sales must receive the missing fare")
	_check(not GameState.checkpoint.has("popup") and Vector2(float(GameState.checkpoint.position[0]), float(GameState.checkpoint.position[1])) == Vector2(430, 480), "A removed-puzzle save must resume outside it at the same position")
	_check(GameState.difficulty == "facil" and not GameState.flags.cart_mission_completed, "Save migration must preserve difficulty and existing progress")
	_check(GameState.load_progress() and GameState.coins == 13, "Repeated loads must never duplicate compensation")
	old.flags.coach_allowance_received = true
	old.coins = 0
	_write_old_save(old)
	_check(GameState.load_progress() and GameState.coins == 0, "A reward already received and spent must not be awarded again")

func _write_old_save(data: Dictionary) -> void:
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _settle() -> void:
	for frame in 5: await get_tree().process_frame

func _capture(file_name: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	var folder := "res://output/ui/pause_traveler_journal"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	get_viewport().get_texture().get_image().save_png(folder.path_join(file_name + ".png"))

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
