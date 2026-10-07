extends Node

var failures: Array[String] = []
var capture := false
const MAIN := "res://scenes/ui/main_menu.tscn"
const BACKUP := "user://session_test_original.json"

func begin() -> void:
	capture = "--capture-session" in OS.get_cmdline_user_args()
	if "--read-session" in OS.get_cmdline_user_args():
		await _read_session()
	else:
		await _write_session()

func _switch(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	return get_tree().current_scene

func _changed() -> Node:
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	return get_tree().current_scene

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _shot(name: String) -> void:
	if not capture: return
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var scene := get_tree().current_scene
	var hud := scene.get_node_or_null("HUD")
	if hud and hud.pause_overlay.visible:
		var panel: Control = hud.get_node("Root/PauseOverlay/Panel")
		_check(panel.scale.x > 0.95 and panel.size.y < 625, "Pause must retain a readable size after the first layout")
		_check(panel.get_global_rect().get_center().distance_to(get_viewport().get_visible_rect().size * 0.5) < 2, "Pause must remain centered")
	var directory := "res://output/ui/session_flow"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")

func _backup() -> void:
	var original := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		original[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	var file := FileAccess.open(BACKUP, FileAccess.WRITE)
	file.store_string(JSON.stringify(original))
	file.close()

func _restore() -> void:
	GameState.run_started = false
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKUP))
	for path in original:
		if original[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(original[path])
			file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))

func _write_session() -> void:
	_backup()
	GameState.difficulty = GameState.DIFFICULTY_HARD
	GameState.reset_progress(false)
	var menu = await _switch(MAIN)
	_check(menu.start_button.visible and not menu.continue_button.visible and not menu.difficulty_button.visible, "Fresh start must show only Comenzar")
	await _shot("01_inicio_sin_partida")
	menu.start_button.pressed.emit()
	_check(menu.difficulty_button.visible and not menu.start_button.visible and not menu.continue_button.visible, "The second step must show only Elegir dificultad")
	await _shot("02_elegir_dificultad")
	menu.difficulty_button.pressed.emit()
	menu.easy_button.pressed.emit()
	_check(not GameState.is_easy_difficulty(), "Pending difficulty must not change the stored profile")
	await _shot("03_selector_facil")
	menu.difficulty_close_button.pressed.emit()
	var story = await _changed()
	_check(story.scene_file_path == GameState.PHASE_INTRO_SCENE and story.current_index == 0, "Listo must start the introduction")
	_check(GameState.is_easy_difficulty() and GameState.get_forge_opportunities() == 15, "A new Easy game must start with the Easy profile")
	story._advance_story()
	story._advance_story()
	GameState.save_progress()
	menu = await _switch(MAIN)
	GameState.load_progress()
	_check(menu.continue_button.visible and menu.start_button.visible and not menu.difficulty_button.visible, "An existing run must show Continuar above Comenzar")
	_check(menu.continue_button.get_global_rect().end.y < menu.start_button.get_global_rect().position.y, "Continue must be placed above Start")
	await _shot("04_inicio_con_partida")
	var previous := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	menu.start_button.pressed.emit()
	menu.difficulty_button.pressed.emit()
	menu.hard_button.pressed.emit()
	menu.difficulty_close_button.pressed.emit()
	_check(menu.restart_overlay.visible and not menu.difficulty_overlay.visible, "Existing progress must require an explicit restart confirmation")
	_check(GameState.is_easy_difficulty() and FileAccess.get_file_as_string(GameState.SAVE_PATH) == previous, "Preparing a new game must preserve the save and its difficulty")
	await _shot("05_confirmar_reinicio")
	menu.get_node("%CancelRestartButton").pressed.emit()
	_check(not menu.restart_overlay.visible and menu.difficulty_overlay.visible, "Cancelling must return to difficulty selection")
	menu._show_home()
	menu.continue_button.pressed.emit()
	story = await _changed()
	_check(story.current_index == 2 and GameState.is_easy_difficulty(), "Continue must recover the saved story page and difficulty")
	story._advance_story()
	story._advance_story()
	var farm = await _changed()
	_check(farm.get_node("World/Player").position == GameState.PHASE_START_SPAWN, "Story must still enter the enclosed estate")
	GameState.flags.villager_spoken = true
	GameState.coins = 7
	GameState.inventory["trigo"] = 2
	var yard = await _switch("res://scenes/spinner_yard.tscn")
	yard.get_node("World/Player").position = Vector2(492, 474)
	yard.get_node("World/Player").facing = "left"
	var rope = yard.get_node("RopePuzzlePopup")
	rope.open()
	rope._material_buttons()[0].pressed.emit()
	rope._material_buttons()[1].pressed.emit()
	_check(rope.awaiting_retry and GameState.get_rope_attempts_left() == 14, "Fixture must save one completed bundle and one charged error")
	GameState.save_progress()
	_check(str(GameState.checkpoint.get("popup", {}).get("name", "")) == "RopePuzzlePopup", "The save must include the active workshop")
	if not failures.is_empty():
		_restore()
		get_tree().quit(1)
		return
	print("SESSION WRITE OK — closing the game with an active puzzle")
	GameState.notification(NOTIFICATION_WM_CLOSE_REQUEST)

func _roundtrip() -> Node:
	GameState.save_progress()
	await _switch(MAIN)
	_check(GameState.load_progress(), "The serialized checkpoint must load")
	var menu = get_tree().current_scene
	menu.continue_button.pressed.emit()
	return await _changed()

func _read_session() -> void:
	_check(GameState.has_saved_game() and GameState.is_easy_difficulty(), "A second engine process must load the saved run")
	var menu = await _switch(MAIN)
	menu.continue_button.pressed.emit()
	var yard = await _changed()
	var player = yard.get_node("World/Player")
	var rope = yard.get_node("RopePuzzlePopup")
	_check(yard.scene_file_path == "res://scenes/spinner_yard.tscn" and player.position == Vector2(492, 474) and player.facing == "left", "Relaunch must restore map, exact position and facing")
	_check(GameState.coins == 7 and int(GameState.inventory.get("trigo", 0)) == 2, "Relaunch must restore coins and inventory")
	_check(rope.overlay.visible and rope.stage == rope.STAGE_PREPARE and rope.cleaned_fibers == 1 and GameState.get_rope_attempts_left() == 14, "Relaunch must restore the active rope stage, partial work and spent opportunity")
	_check(rope.awaiting_retry and rope.retry_notice.visible and not player.controls_enabled, "Relaunch must recover the error notice without charging again")
	rope.retry_notice.continued.emit()
	_check(not rope.awaiting_retry and GameState.get_rope_attempts_left() == 14, "Continue phase after relaunch must not charge another opportunity")
	rope.close()
	var hud = yard.get_node("HUD")
	hud._open_pause()
	var first_guide: String = hud.get_node("%PauseInfo").text
	_check(hud.get_node("%PauseDifficultyLabel").text == "Dificultad: Fácil", "Pause must always show the Easy difficulty")
	await _shot("06_pausa_facil")
	GameState.flags.wheelwright_forge_completed = true
	GameState.flags.rope_puzzle_completed = true
	hud._refresh_pause_guidance()
	_check(hud.get_node("%PauseInfo").text != first_guide and "tabla de Bruno" in hud.get_node("%PauseInfo").text and "2 de 3" in hud.get_node("%PauseInfo").text, "Pause guidance must follow completed workshops")
	await _shot("07_pausa_avance")
	yard = await _roundtrip()
	_check(yard.get_node("HUD").pause_overlay.visible and not yard.get_node("World/Player").controls_enabled, "Pause must resume with movement locked")
	yard.get_node("HUD")._close_pause()
	GameState.flags.wheelwright_forge_completed = false
	GameState.flags.rope_puzzle_completed = false
	var island = await _switch("res://scenes/wood_island.tscn")
	var lumber = island.get_node("LumberPuzzlePopup")
	lumber.open()
	lumber.straight_grain.pressed.emit()
	await get_tree().create_timer(0.7).timeout
	lumber.marked_lines = 1
	lumber.length_slider.set_value_no_signal(160)
	lumber.angle_slider.set_value_no_signal(90)
	lumber._update_measure_progress()
	island = await _roundtrip()
	lumber = island.get_node("LumberPuzzlePopup")
	_check(lumber.overlay.visible and lumber.stage == lumber.STAGE_MEASURE and lumber.marked_lines == 1 and is_equal_approx(lumber.length_slider.value, 160), "Lumber must recover its measurement stage, mark and adjustment")
	lumber.close()
	GameState.flags.tools_given_to_mateo = true
	var forge_yard = await _switch("res://scenes/wheelwright_yard.tscn")
	var forge = forge_yard.get_node("WheelwrightForgePopup")
	forge.open()
	forge.forge_stage = forge.STAGE_RIVET
	forge.rivet_hits = [1, 0, 0, 0]
	forge.rivet_index = 0
	forge.heat = 85
	forge._show_stage()
	forge_yard = await _roundtrip()
	forge = forge_yard.get_node("WheelwrightForgePopup")
	_check(forge.overlay.visible and forge.forge_stage == forge.STAGE_RIVET and forge.rivet_hits[0] == 1, "Forge must recover the active phase and completed hammer hit")
	forge.close()
	var mill = await _switch("res://scenes/mill_interior.tscn")
	var repair = mill.get_node("MillRepairPopup")
	repair.open()
	repair.stage = "plank"
	repair.selected_part = "tabla"
	repair.bolts = 1
	repair.bolt_progress = 0.4
	repair._refresh()
	mill = await _roundtrip()
	repair = mill.get_node("MillRepairPopup")
	_check(repair.overlay.visible and repair.stage == "plank" and repair.bolts == 1 and repair.bolt_progress >= 0.4, "Mill assembly must recover a partially tightened second fastening")
	repair.close()
	GameState.flags.mill_repaired = true
	GameState.inventory["trigo"] = 3
	var operation = mill.get_node("MillOperationPopup")
	operation.open()
	operation.batches_processed = 1
	operation.gate_opening = 45
	operation.rotation_speed = 49
	operation._update_interface()
	mill = await _roundtrip()
	operation = mill.get_node("MillOperationPopup")
	_check(operation.overlay.visible and operation.batches_processed == 1 and is_equal_approx(operation.gate_opening, 45), "Milling must recover completed batches and water gate")
	operation.close()
	GameState.flags.flour_sold = true
	var village = await _switch("res://scenes/game.tscn")
	_check(not village.has_node("MigrationCartPopup"), "Elena's removed puzzle must not be restored")
	GameState.flags.ticket_bought = true
	var station = await _switch("res://scenes/station_platform.tscn")
	_check(not station.has_node("RailDispatchHost") and not station.has_node("RailDispatchPopup"), "The removed railway puzzle must never reopen")
	var hud_station = station.get_node("HUD")
	hud_station._show_dialogue({"speaker": "Agente de estación", "text": "Tu boleto está preparado.", "options": [{"label": "Continuar", "action": "close"}]})
	station = await _roundtrip()
	hud_station = station.get_node("HUD")
	_check(hud_station.dialogue_panel.visible and hud_station.dialogue_text.text == "Tu boleto está preparado.", "A saved dialogue must reopen with its text and choices")
	hud_station._select_dialogue_action("close")
	hud_station._set_inventory_mode("glossary")
	hud_station._toggle_inventory()
	hud_station._show_item("cuerda")
	station = await _roundtrip()
	hud_station = station.get_node("HUD")
	_check(hud_station.inventory_overlay.visible and hud_station.inventory_mode == "glossary" and hud_station.selected_item_id == "cuerda", "The open glossary must restore its selected object")
	hud_station._close_inventory()
	hud_station._show_story_overlay()
	var review = hud_station.get_node("Root/EnclosureStory")
	review.current_index = 1
	review._show_page(false)
	station = await _roundtrip()
	hud_station = station.get_node("HUD")
	_check(hud_station.get_node("Root/EnclosureStory").current_index == 1, "Story review must retain its page without replacing the saved map")
	hud_station.get_node("Root/EnclosureStory")._close_overlay()
	await get_tree().process_frame
	GameState.flags.cart_mission_completed = true
	GameState.flags.rail_dispatch_completed = false
	var departure = station.get_node("TrainDepartureController")
	departure._board_train()
	hud_station._select_dialogue_action("depart_train")
	await get_tree().process_frame
	departure.departure_elapsed = 2.0
	station = await _roundtrip()
	departure = station.get_node("TrainDepartureController")
	_check(departure.departing and departure.boarded and departure.departure_elapsed >= 2.0 and departure.departure_elapsed < 2.5 and not station.get_node("World/Player").visible, "Closing during train departure must restore its progress and boarding state")
	await get_tree().create_timer(3.6).timeout
	_check(GameState.phase_complete, "Resumed train departure must complete the phase")
	station = await _roundtrip()
	_check(station.get_node("HUD").completion_overlay.visible and station.get_node("TrainDepartureController").departure_finished, "Continue must restore the phase report after train departure")
	GameState.phase_complete = false
	GameState.pending_travel_scene = "res://scenes/wood_island.tscn"
	var boat = await _switch("res://scenes/boat_travel.tscn")
	boat.elapsed = 4.5
	boat._apply_timeline(boat.elapsed)
	boat = await _roundtrip()
	_check(boat.destination == "res://scenes/wood_island.tscn" and boat.elapsed >= 4.5 and boat.elapsed < 5.1, "Boat must resume its elapsed journey toward the correct island")
	GameState.pending_coach_destination = "res://scenes/station.tscn"
	var coach = await _switch("res://scenes/coach_travel.tscn")
	coach.elapsed = 7
	coach._apply_timeline(coach.elapsed)
	var paid := int(GameState.metrics.get("coach_fares_paid", 0))
	coach = await _roundtrip()
	_check(coach.destination == "res://scenes/station.tscn" and coach.elapsed >= 7 and coach.elapsed < 7.6, "Coach must resume the road journey")
	_check(int(GameState.metrics.get("coach_fares_paid", 0)) == paid, "Resuming a journey must not charge another fare")
	await _switch("res://scenes/sheep_farm.tscn")
	menu = await _switch(MAIN)
	menu.start_button.pressed.emit()
	menu.difficulty_button.pressed.emit()
	menu.hard_button.pressed.emit()
	menu.difficulty_close_button.pressed.emit()
	_check(menu.restart_overlay.visible, "A saved trip must still require restart confirmation")
	menu.get_node("%ConfirmRestartButton").pressed.emit()
	var story = await _changed()
	_check(story.current_index == 0 and not GameState.is_easy_difficulty() and GameState.coins == 0 and GameState.get_forge_opportunities() == 10 and GameState.get_rope_attempts_left() == 10, "Confirmed new Hard game must clear the old run and start at story page one with ten opportunities")
	for page in 4: story._advance_story()
	var farm = await _changed()
	hud = farm.get_node("HUD")
	hud._open_pause()
	_check(hud.get_node("%PauseDifficultyLabel").text == "Dificultad: Difícil", "Pause must display the confirmed Hard profile")
	await _shot("08_pausa_dificil")
	_restore()
	print("SESSION READ OK — full flow and five panels across four puzzles verified" if failures.is_empty() else "SESSION FLOW FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)

