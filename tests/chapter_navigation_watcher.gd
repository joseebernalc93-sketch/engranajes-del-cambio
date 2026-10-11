extends Node
## Run the writer and reader in separate processes to verify persisted chapter hops.
const BACKUP := "user://chapter_navigation_backup.json"
const Journey := preload("res://scripts/world/london_journey.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Iron := preload("res://scripts/core/iron_mission.gd")
var failures: Array[String] = []
var checks := 0
var capture := false

func begin() -> void:
	capture = "--capture-ui" in OS.get_cmdline_user_args()
	if "--read-navigation" in OS.get_cmdline_user_args():
		await _read()
	else:
		_backup()
		for difficulty in ["facil", "dificil"]:
			await _exercise(difficulty)
		print("CHAPTER NAVIGATION WRITE: %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)

func _exercise(difficulty: String) -> void:
	await _switch("res://scenes/ui/main_menu.tscn")
	GameState.reset_progress(false)
	GameState.difficulty = difficulty
	GameState.run_started = true
	GameState.phase_complete = true
	GameState.phase_summary = {"tiempo_segundos": 556, "dificultad": difficulty, "puzzles_completados": 4}
	for flag in ["villager_spoken", "wheelwright_forge_completed", "rope_puzzle_completed", "lumber_puzzle_completed", "mill_repaired", "flour_milled", "flour_sold", "coach_fare_paid", "coach_station_reached", "ticket_bought"]:
		GameState.flags[flag] = true
	GameState.coins = 87
	GameState.inventory = {"boleto": 1, "recuerdo": 1}
	GameState.ensure_phase_two_entry()
	var snapshot := GameState.phase_summary.duplicate(true)
	var state := Journey.ensure()
	state.arrived = true
	state.guide_spoken = true
	state.clerk_spoken = true
	state.city_reached = true
	state.area = "street"
	state.elapsed = 20.0
	var london := await _switch(GameState.PHASE_TWO_SCENE)
	london._set_area("street", Vector2(731, 506))
	london.player.facing = "left"
	london._show_journal()
	london.journal.show_page(1)
	GameState.save_progress()
	var exact := GameState.checkpoint.duplicate(true)
	london._return_home()
	var menu := await _changed()
	_check(menu.chapter_button.visible, "Completed save exposes unlocked phases on the title screen")
	menu.get_node("%ContinueGameButton").pressed.emit()
	london = await _changed()
	_check(london.area == "street" and london.player.position == Vector2(731, 506) and london.player.facing == "left", "Continue restores exact London area, coordinates and facing")
	_check(london.journal_overlay.visible and london.journal.current_page == 1, "Continue restores the open journal and selected page")
	_check(GameState.chapter_checkpoints["2"].position == exact.position, "London has its own saved checkpoint")
	# Exercise the previous-page return button, rather than invoking a model shortcut.
	var return_button: Button = london.journal.summary.get_children().filter(func(node: Node): return node is Button and node.text == "Volver a fase 1")[0]
	return_button.pressed.emit()
	var countryside := await _changed()
	_check(countryside.scene_file_path == "res://scenes/sheep_farm.tscn", "Previous chapter returns to the countryside start")
	_preserved(snapshot, difficulty)
	var hud := countryside.get_node("HUD")
	hud._open_pause()
	await _settle()
	_check(hud.pause_board.counter.text.contains("4 / 4"), "Revisited chapter shows four completed puzzles")
	_check(hud.pause_board.phase_two_button.visible, "Phase two stays accessible from the countryside journal")
	_check(hud.get_node("%PauseRestartButton").text == "Volver al inicio de fase 1", "Completed chapter return is clearly named")
	await _shot("phase_one_revisited_" + difficulty)
	GameState.save_progress()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	menu = await _changed()
	menu.get_node("%ContinueGameButton").pressed.emit()
	countryside = await _changed()
	_check(countryside.scene_file_path == "res://scenes/sheep_farm.tscn" and countryside.get_node("HUD").pause_overlay.visible, "Global Continue now resumes the most recent countryside session")
	countryside.get_node("HUD").pause_board.phase_two_button.pressed.emit()
	london = await _changed()
	_check(london.area == "street" and london.player.position == Vector2(731, 506), "Returning to phase two retains its independent London position")
	_check(not london.journal_overlay.visible and Journey.ensure().guide_spoken and Journey.ensure().city_reached, "Chapter hop resumes exploration with discoveries preserved")
	london._return_home()
	menu = await _changed()
	menu.chapter_button.pressed.emit()
	_check(menu.chapter_overlay.visible and not menu.phase_one_button.disabled and not menu.restart_two_button.disabled, "Selector exposes both unlocked phases and phase two restart")
	await _shot("chapter_selector_" + difficulty)
	menu.restart_two_button.pressed.emit()
	_check(menu.restart_overlay.visible and menu.pending_chapter_restart, "Restart phase two asks before replacing its arrival checkpoint")
	menu.get_node("%CancelRestartButton").pressed.emit()
	_check(menu.chapter_overlay.visible and Journey.ensure().city_reached, "Cancelling restart leaves London untouched")
	menu.phase_one_button.pressed.emit()
	countryside = await _changed()
	_preserved(snapshot, difficulty)
	countryside.get_node("HUD")._open_pause()
	countryside.get_node("HUD").pause_board.phase_two_button.pressed.emit()
	london = await _changed()
	_check(london.area == "street", "Selector return does not replace the London checkpoint")
	london._return_home()
	menu = await _changed()
	menu._open_chapters()
	# Reproduce a player with five paid city trips and an advanced coal mission.
	GameState.coins = 37
	GameState.inventory.merge({"costal_carbon": 4, "hulla": 1, "biela": 1, "potencia_vapor": 1, "pano_industrial": 1})
	GameState.phase_two.city_transport = {"outbound_trips": 5, "fares_paid": 50, "industrial_reached": true}
	GameState.phase_two.spent = 7
	GameState.phase_two.completed = ["mine", "engine"]
	GameState.phase_two.work = {"mine": {"complete": true}}
	GameState.phase_two.glossary = [{"id": "hulla"}]
	GameState.phase_two.iron_mission = {"stage": 5, "started": true, "route": 3, "batch_issued": true, "stable_seconds": 90.0, "fuel": 1.2, "portion": 4, "complete": true}
	GameState.save_progress()
	menu.restart_two_button.pressed.emit()
	menu.get_node("%CancelRestartButton").pressed.emit()
	_check(GameState.coins == 37 and int(GameState.inventory.costal_carbon) == 4 and int(GameState.phase_two.iron_mission.stage) == 5, "Cancelling phase two restart preserves current money, coal and engine")
	menu.restart_two_button.pressed.emit()
	menu.get_node("%ConfirmRestartButton").pressed.emit()
	var story := await _changed()
	_check(story.scene_file_path == GameState.PHASE_TWO_INTRO and story.current_index == 0, "Confirmed restart phase two opens its first story page")
	_check(not GameState.phase_two.has("arrival"), "Restart clears London discoveries without restoring the former scene state")
	_check(GameState.coins == 87 and GameState.inventory == {"recuerdo": 1}, "Restart restores the original purse and backpack without coal, rewards or used ticket")
	_check(GameState.phase_two.work.is_empty() and GameState.phase_two.completed.is_empty() and GameState.phase_two.glossary.is_empty(), "Restart clears workshops, achievements and glossary from phase two")
	_check(not GameState.phase_two.has("iron_mission") and not GameState.phase_two.has("city_transport") and Campaign.remaining() == Campaign.total(), "Restart clears engine and fares and restores the entire difficulty budget")
	var reset_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phase2Metrics.PATH))
	_check(not bool(reset_report.completada) and reset_report.talleres_completados.is_empty() and int(reset_report.balance_productivo.carbon_paleadas) == 0, "Restart replaces the previous teacher report with fresh phase two statistics")
	_preserved(snapshot, difficulty)
	for page in 4: story._advance_story()
	london = await _changed()
	_check(london.area == "platform" and not Journey.ensure().guide_spoken, "Restart replays the train arrival and the guide encounter")
	var mission := Iron.new()
	_check(not bool(mission.data.started) and mission.stage() == 0 and not bool(mission.data.batch_issued) and float(mission.data.stable_seconds) == 0.0, "Restarted mine offers a fresh coal collection attempt")
	GameState.coins = 77
	GameState.phase_two.city_transport.fares_paid = 10
	GameState.save_progress()
	GameState.restart_phase_two()
	story = await _changed()
	_check(GameState.coins == 87 and not GameState.phase_two.has("city_transport"), "Repeating restart restores the same baseline instead of adding refunds")
	for page in 4: story._advance_story()
	london = await _changed()
	london.set_process(false)
	london.elapsed = 20.0
	Journey.ensure().arrived = true
	Journey.ensure().guide_spoken = true
	london._set_area("hall", Vector2(617, 522))
	london.player.facing = "right"
	GameState.save_progress()
	GameState.revisit_phase_one()
	countryside = await _changed()
	countryside.get_node("World/Player").position = Vector2(620, 580)
	countryside.get_node("World/Player").facing = "up"
	GameState.save_progress()
	_check(GameState.checkpoint.scene == "res://scenes/sheep_farm.tscn" and GameState.chapter_checkpoints["2"].area == "hall", "Save retains a checkpoint for each chapter before shutdown")

func _read() -> void:
	if not FileAccess.file_exists(BACKUP):
		push_error("Run chapter_navigation_test writer before its reader")
		get_tree().quit(1)
		return
	_check(GameState.phase_complete and GameState.is_phase_two_unlocked(), "Fresh process retains completion and phase two unlock")
	var menu := await _switch("res://scenes/ui/main_menu.tscn")
	_check(menu.chapter_button.visible, "Fresh title exposes chapter selection")
	menu.get_node("%ContinueGameButton").pressed.emit()
	var countryside := await _changed()
	_check(countryside.scene_file_path == "res://scenes/sheep_farm.tscn" and countryside.get_node("World/Player").position == Vector2(620, 580), "Fresh Continue restores last visited countryside position")
	_preserved(GameState.phase_summary.duplicate(true), "dificil")
	countryside.get_node("HUD")._open_pause()
	countryside.get_node("HUD").pause_board.phase_two_button.pressed.emit()
	var london := await _changed()
	_check(london.area == "hall" and london.player.position == Vector2(617, 522) and london.player.facing == "right", "Fresh chapter hop restores independent London position and facing")
	_check(Journey.ensure().guide_spoken and not Journey.ensure().clerk_spoken, "Fresh chapter hop keeps London discoveries")
	# Old v16 saves have no chapter index; seed it from their global checkpoint.
	GameState.save_progress()
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	legacy.erase("chapter_checkpoints")
	legacy.save_version = 16
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(GameState.load_progress() and GameState.chapter_checkpoints.has("2"), "Version sixteen saves migrate without losing their London checkpoint")
	_check(GameState.chapter_checkpoints["2"].area == "hall" and GameState.phase_complete, "Legacy migration preserves chapter state and unlock")
	# The current player save predates entry snapshots: reconstruct, but do not
	# reset the ongoing game until Restart is explicitly chosen.
	var old_balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	old_balance.save_version = 18
	old_balance.erase("phase_two_entry")
	old_balance.coins = 37
	old_balance.inventory = {"recuerdo": 1, "costal_carbon": 4, "hulla": 1, "boleto": 1}
	old_balance.phase_two.city_transport = {"outbound_trips": 5, "fares_paid": 50, "industrial_reached": true}
	old_balance.phase_two.iron_mission = {"stage": 5, "started": true, "batch_issued": true, "complete": true}
	FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify(old_balance))
	_check(GameState.load_progress() and GameState.coins == 37 and GameState.has_item("costal_carbon"), "Migrating an existing save preserves its ongoing balance and coal")
	_check(int(GameState.phase_two_entry.coins) == 87 and GameState.phase_two_entry.inventory.size() == 1 and int(GameState.phase_two_entry.inventory.get("recuerdo", 0)) == 1, "Version eighteen reconstructs original money and removes chapter two items only from the entry snapshot")
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(int(migrated.save_version) == GameState.SAVE_VERSION and int(migrated.phase_two_entry.coins) == 87, "Recovered entry snapshot is saved durably")
	_check(GameState.load_progress() and GameState.coins == 37 and int(GameState.phase_two_entry.coins) == 87, "Reloading the migration neither refunds money nor changes the original balance")
	GameState.restart_phase_two()
	var story := await _changed()
	_check(story.scene_file_path == GameState.PHASE_TWO_INTRO and GameState.coins == 87 and GameState.inventory.size() == 1 and int(GameState.inventory.get("recuerdo", 0)) == 1, "Restarting an old save restores its real original purse and clears collected coal")
	_check(not GameState.phase_two.has("iron_mission") and GameState.phase_complete and Campaign.remaining() == 10, "Legacy restart resets the mine and hard budget while keeping completed phase one")
	GameState.phase_two_entry = {}
	GameState.coins = 31
	GameState.phase_two.city_transport = {"fares_paid": 20}
	GameState.ensure_phase_two_entry()
	GameState.restart_phase_two()
	await _changed()
	_check(GameState.coins == 51, "Entry recovery uses the recorded balance rather than hardcoding eighty-seven")
	_restore()
	print("CHAPTER NAVIGATION READ: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _preserved(report: Dictionary, difficulty: String) -> void:
	_check(GameState.phase_complete and GameState.phase_summary == report, "Returning or restarting chapter two preserves completed chapter one report")
	_check(GameState.difficulty == difficulty and GameState.coins == 87 and GameState.has_item("recuerdo"), "Difficulty, original coins and phase one inventory remain intact")
	for puzzle in GameState.get_puzzle_progress(): _check(puzzle.completed, "Completed puzzle stays completed: " + str(puzzle.label))
	_check(GameState.is_phase_two_unlocked(), "London remains unlocked")

func _backup() -> void:
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	var file := FileAccess.open(BACKUP, FileAccess.WRITE)
	file.store_string(JSON.stringify(backups))
	file.close()

func _restore() -> void:
	GameState.run_started = false
	Phase2Metrics.set_process(false)
	Phase2Metrics.flush()
	var backups: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKUP))
	for path in backups:
		if backups[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(Marshalls.base64_to_raw(str(backups[path])))
			file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))

func _switch(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	return await _changed()

func _changed() -> Node:
	await get_tree().scene_changed
	await _settle()
	return get_tree().current_scene

func _settle() -> void:
	for frame in 5: await get_tree().process_frame

func _shot(filename: String) -> void:
	if not capture: return
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var directory := "res://output/ui/chapter_navigation"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + filename + ".png")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
