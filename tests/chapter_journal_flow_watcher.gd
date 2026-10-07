extends Node

const BACKUP := "user://chapter_journal_test_backup.json"
var failures: Array[String] = []
var capture := false

func begin() -> void:
	capture = "--capture-ui" in OS.get_cmdline_user_args()
	if "--read-chapter" in OS.get_cmdline_user_args():
		await _read()
	else:
		await _write()

func _write() -> void:
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	var backup := FileAccess.open(BACKUP, FileAccess.WRITE)
	backup.store_string(JSON.stringify(backups))
	backup.close()
	GameState.reset_progress(false)
	GameState.difficulty = "facil"
	GameState.run_started = true
	GameState.phase_started_at = int(Time.get_unix_time_from_system()) - 556
	for flag in ["villager_spoken", "wheelwright_forge_completed", "rope_puzzle_completed", "lumber_puzzle_completed", "mill_repaired", "flour_milled", "flour_sold", "coach_fare_paid", "coach_station_reached", "ticket_bought"]:
		GameState.flags[flag] = true
	GameState.metrics.wheat_harvested = 3
	GameState.metrics.flour_sacks_milled = 1
	GameState.metrics.coach_fares_paid = 3
	GameState.metrics.mill_parts_installed = 3
	GameState.inventory = {"boleto": 1}
	var platform := await _switch("res://scenes/station_platform.tscn")
	var hud = platform.get_node("HUD")
	hud._select_dialogue_action("board_train")
	hud._select_dialogue_action("depart_train")
	await get_tree().create_timer(6.0).timeout
	_check(GameState.phase_complete and hud.completion_overlay.visible, "Real train departure must show the selected completion journal")
	_check(hud.completion_journal.statuses.size() == 4 and hud.completion_journal.stats.text.contains("4 / 4") and hud.completion_journal.stats.text.contains("Fácil"), "Summary must show four completed puzzles and the selected difficulty")
	_check(hud.completion_journal.accounts.text == "13 ganadas · 3 carreta · 10 boleto", "Summary must show the actual flour and travel economy")
	_check(hud.completion_journal.artwork.size == Vector2(1000, 606), "Journal artwork must use the spread dimensions rather than its source image size")
	for image in hud.completion_journal.summary.find_children("*", "TextureRect", true, false):
		_check(image.size.x <= 155 and image.size.y <= 82, "Illustrations must remain inside their authored cards")
	for label in hud.completion_journal.find_children("*", "Label", true, false):
		if label.has_meta("page_rectangle"):
			var rect: Rect2 = label.get_meta("page_rectangle")
			_check(label.size.y <= rect.size.y + 2, "Journal text must fit its authored page rectangle: " + label.text)
	await _shot("phase_one_final_journal")
	var report := GameState.build_report()
	var hard_report := report.duplicate(true)
	hard_report.dificultad = "dificil"
	hud.completion_journal.refresh(hard_report)
	_check(hud.completion_journal.stats.text.contains("Difícil"), "The summary must also display Hard difficulty")
	hud.completion_journal.refresh(report)
	GameState.phase_started_at -= 3600
	_check(GameState.build_report() == report, "Finishing must freeze the report instead of extending the chapter time")
	GameState.save_progress()
	_check(GameState.load_progress() and JSON.parse_string(JSON.stringify(GameState.build_report())) == JSON.parse_string(JSON.stringify(report)), "Save and reload must preserve the original report")
	hud.get_node("%ContinueButton").pressed.emit()
	var phase_two := await _changed()
	_check(phase_two.scene_file_path == GameState.PHASE_TWO_SCENE and not phase_two.has_node("World/Player"), "Continue must reach the construction screen, never the station")
	_check(GameState.phase_complete and GameState.difficulty == "facil", "Entering the future chapter must retain completion and difficulty")
	_check(not phase_two.journal_overlay.visible and phase_two.journal.current_page == 2, "The new screen must start with the journal closed and phase two selected")
	await _shot("phase_two_construction")
	await _escape()
	_check(phase_two.journal_overlay.visible and phase_two.journal.current_page == 2, "Escape must open the new chapter page")
	await _shot("phase_two_journal")
	phase_two.journal.previous_button.pressed.emit()
	await _settle()
	_check(phase_two.journal.current_page == 1 and phase_two.journal.summary.visible, "Previous page must show the completed first chapter")
	await _shot("phase_one_previous_page")
	phase_two.journal.next_button.pressed.emit()
	await _settle()
	_check(phase_two.journal.current_page == 2, "Next page must return to the future chapter")
	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.pressed = true
	Input.parse_input_event(left)
	await _settle()
	_check(phase_two.journal.current_page == 1, "Keyboard left must turn to the previous chapter")
	await _escape()
	_check(not phase_two.journal_overlay.visible, "Escape must close the journal without leaving the construction screen")
	await _escape()
	_check(phase_two.journal_overlay.visible and phase_two.journal.current_page == 1, "Reopening the journal must retain the chosen page")
	var viewport := get_tree().root
	viewport.size = Vector2i(800, 500)
	await _settle()
	_check(phase_two.journal.size.y * phase_two.journal.scale.y <= phase_two.journal_overlay.size.y - 23, "The new journal must fit a smaller window")
	viewport.size = Vector2i(1152, 648)
	await _settle()
	GameState.save_progress()
	_check(GameState.checkpoint.scene == GameState.PHASE_TWO_SCENE and GameState.checkpoint.journal_open and int(GameState.checkpoint.journal_page) == 1, "Saving must remember the construction screen and open previous page")
	# The second process resumes this exact checkpoint after engine shutdown.
	print("CHAPTER JOURNAL WRITE OK: real departure, frozen report, construction screen, Escape, two chapter pages, keyboard, responsive layout and persisted checkpoint" if failures.is_empty() else "CHAPTER JOURNAL WRITE FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)

func _read() -> void:
	_check(GameState.has_saved_game() and GameState.phase_complete, "A fresh process must find the completed chapter save")
	var original := GameState.build_report()
	var menu := await _switch("res://scenes/ui/main_menu.tscn")
	_check(menu.get_node("%ContinueGameButton").visible, "The title screen must offer Continue")
	_check(GameState.continue_saved_game(), "The completed journey must remain resumable")
	var phase_two := await _changed()
	_check(phase_two.scene_file_path == GameState.PHASE_TWO_SCENE and phase_two.journal_overlay.visible and phase_two.journal.current_page == 1, "Continue must restore the exact construction screen and open chapter-one page")
	_check(GameState.build_report() == original and phase_two.journal.stats.text.contains("Fácil"), "Restoring must keep the frozen report and selected difficulty")
	phase_two.close_journal()
	phase_two._return_home()
	await _changed()
	_check(GameState.continue_saved_game(), "Returning to the title must keep the save")
	phase_two = await _changed()
	_check(not phase_two.journal_overlay.visible and phase_two.journal.current_page == 1, "Continue must also restore a closed journal")
	phase_two.open_journal()
	phase_two.journal.turn_to(2)
	_check(GameState.build_report() == original, "Chapter navigation must never modify the chapter-one report")
	GameState.restart_phase()
	var story := await _changed()
	_check(story.scene_file_path == GameState.PHASE_INTRO_SCENE and not GameState.phase_complete and GameState.phase_summary.is_empty(), "Restart must open the first chapter story and clear its previous summary")
	_check(GameState.difficulty == "facil", "Restart must retain difficulty")
	GameState.run_started = false
	if FileAccess.file_exists(BACKUP):
		var backups: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKUP))
		for path in backups:
			if backups[path] == null:
				if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			else:
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_buffer(Marshalls.base64_to_raw(str(backups[path])))
				file.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
	print("CHAPTER JOURNAL READ OK: fresh-process Continue, exact page and visibility, frozen summary, title return and restart" if failures.is_empty() else "CHAPTER JOURNAL READ FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)

func _switch(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	return await _changed()

func _changed() -> Node:
	await get_tree().scene_changed
	await _settle()
	return get_tree().current_scene

func _settle() -> void:
	for frame in 5: await get_tree().process_frame

func _escape() -> void:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventAction.new()
	event.action = "pause"
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()

func _shot(filename: String) -> void:
	if not capture: return
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var directory := "res://output/ui/chapter_journal"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + filename + ".png")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

