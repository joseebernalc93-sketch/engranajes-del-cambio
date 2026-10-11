extends Node
const Journey := preload("res://scripts/world/london_journey.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Art := preload("res://scripts/world/foundry_art.gd")
const Bounds := preload("res://scripts/world/sprite_body_bounds.gd")
const BACKUP := "user://foundry_scene_backup.json"
var scene: Control
var checks: int = 0
var failures: Array[String] = []

func begin() -> void:
	if "--restore-foundry" in OS.get_cmdline_user_args():
		_restore_files()
		get_tree().quit()
	elif "--read-foundry" in OS.get_cmdline_user_args(): await _read()
	else: await _write()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("FOUNDRY: " + message)

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _switch(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await _settle()

func _freeze() -> void:
	scene = get_tree().current_scene
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.application_focused = true
	scene._update_modal_feedback()

func _buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button in scene.hud.dialogue_options.find_children("*", "Button", true, false): result.append(button as Button)
	return result

func _walk(action: String) -> void:
	Input.action_press(action)
	for frame in 40:
		await get_tree().physics_frame
		scene._physics_process(1.0 / 60.0)
		if scene.changing_area: break
	Input.action_release(action)
	await get_tree().create_timer(0.6).timeout
	scene.application_focused = true

func _click_door() -> void:
	scene._navigate_pointer(Vector2(829, 400))
	_check(scene.pending_interaction == "forge_door", "Clicking the pictured door selects its actual interaction")
	for frame in 240:
		await get_tree().physics_frame
		scene._physics_process(1.0 / 60.0)
		if scene.changing_area or scene.target == Vector2.INF: break
	await get_tree().create_timer(0.6).timeout
	scene.application_focused = true

func _shot(name: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args(): return
	await _settle()
	RenderingServer.force_draw(false)
	var directory := "res://output/ui/foundry"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")

func _write() -> void:
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	FileAccess.open(BACKUP, FileAccess.WRITE).store_string(JSON.stringify(backups))
	await _switch("res://scenes/ui/main_menu.tscn")
	GameState.reset_progress(false)
	GameState.difficulty = "facil"
	GameState.run_started = true
	GameState.phase_complete = true
	GameState.coins = 87
	GameState.ensure_phase_two_entry()
	GameState.inventory["costal_carbon"] = 4
	var arrival := Journey.ensure()
	arrival.arrived = true
	arrival.city_reached = true
	arrival.elapsed = 9.5
	await _switch(GameState.PHASE_TWO_SCENE)
	_freeze()
	scene.iron.data.stage = 2
	scene.iron.data.started = true
	scene.iron.data.batch_issued = true
	scene.iron.data.gears = [1, -1, -1]
	scene._set_area("coach_depot", Vector2(610, 560))
	scene._interact("coachman")
	_check(_buttons().size() == 4 and not _buttons()[2].disabled and _buttons()[3].disabled, "Foundry is available among four routes; independent textile route remains reserved")
	_buttons()[2].pressed.emit()
	_check(scene.dialogue_text.text.contains("La forja y fundición") and GameState.coins == 87, "Foundry selection discloses its fare without charging")
	scene._cancel_dialogue()
	_check(not scene.ride.active and GameState.coins == 87, "Cancelling the foundry fare preserves the purse")
	scene._interact("coachman")
	_buttons()[2].pressed.emit()
	scene._close_dialogue()
	_check(scene.ride.active and scene.ride.destination_area == "forge_yard" and GameState.coins == 77, "Accepting starts a paid foundry journey")
	_check(not scene._book_city_coach() and GameState.coins == 77, "Repeated booking cannot charge twice")
	scene.ride.elapsed = 34.25
	scene.ride.apply_timeline()
	_check(scene.ride.background.texture == Art.YARD and scene.ride.stage == "arrival", "Foundry arrival uses its own approved exterior")
	scene._process(6.0)
	_check(scene.area == "forge_yard" and scene.player.position == Art.COACH_LANDING and not scene._blocked(), "Natural arrival restores walking at the foundry")
	await get_tree().physics_frame
	_check(not scene.player.test_move(scene.player.global_transform, Vector2(0, -1)), "Foundry disembarkation is clear of the coach and William")
	_check(scene.actors.size() == 1 and scene.actors.has("coachman"), "Foundry yard has only the hero and William as movable people")
	await _shot("01_exterior")
	await _click_door()
	_check(scene.area == "forge_hall" and scene.backdrop.texture == Art.HALL, "Walking to the clicked door enters the separate foundry hall")
	_check(scene.actors.size() == 1 and scene.actors.has("cort"), "The hall contains Cort and the protagonist")
	var hero: Sprite2D = scene.player.get_node("Sprite2D")
	var cort: Sprite2D = scene.actors.cort.get_child(0)
	var hero_height: float = Bounds.measure(hero.texture.get_image().get_region(Rect2i(hero.region_rect))).size.y * hero.scale.y * scene.player.scale.y
	var cort_height: float = Bounds.measure(cort.texture.get_image().get_region(Rect2i(cort.region_rect))).size.y * cort.scale.y
	_check(absf(hero_height - cort_height) < 0.5, "Cort's opaque visible height matches the enlarged interior hero")
	_check(cort.texture.get_image().get_pixel(0, 0).a == 0.0, "Cort's game sprite has a transparent background")
	_check(Journey.objective().contains("Cort"), "Journal objective describes the foundry visit")
	_check(not scene.iron_popup.is_open() and not scene.coal_view.is_open(), "Exploring the foundry does not open a puzzle")
	await _shot("02_interior")
	scene.player.position = Art.CORT_POSITION + Vector2(-66, 18)
	scene._update_nearest()
	_check(scene.hud.prompt_label.text == "E  Hablar con Cort, maestro de fundición", "Cort uses the shared proximity interaction prompt")
	await _shot("03_proximidad_cort")
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.physical_keycode = KEY_E
	interact.pressed = true
	scene._unhandled_input(interact)
	_check(scene.dialogue.visible and scene.dialogue == scene.hud.dialogue_panel and scene.dialogue_heading.text == "Cort, maestro de fundición", "E opens the same conversation panel as phase one")
	_check(scene._blocked() and not scene.hud.prompt_panel.visible, "Cort's dialogue pauses movement and hides the proximity prompt")
	_check(not Campaign.done("forge") and GameState.has_item("costal_carbon", 4) and GameState.coins == 77 and scene.iron.data.gears == [1, -1, -1], "Conversation neither completes a puzzle nor consumes coal, coins or engine work")
	await _shot("04_dialogo_cort")
	var saved_position: Vector2 = scene.player.position
	scene._return_home()
	await get_tree().scene_changed
	await _settle()
	_check(GameState.continue_saved_game(), "Menu Continue reopens the foundry save")
	await get_tree().scene_changed
	await _settle()
	_freeze()
	_check(scene.area == "forge_hall" and scene.player.position == saved_position and scene.dialogue_kind == "cort", "Continue restores the exact hall position and Cort's conversation")
	_check(GameState.coins == 77 and GameState.has_item("costal_carbon", 4) and scene.iron.data.gears == [1, -1, -1], "Continue preserves purse, sacks and engine assembly")
	scene._close_dialogue()
	_check("cort" in Journey.ensure().talked and not Campaign.done("forge"), "Cort is recorded as a conversation without granting a workshop reward")
	_check(scene.foundry_view.is_open(), "Cort now offers the implemented six-step workshop")
	scene.foundry_view.close()
	scene.player.position = Vector2(115, 530)
	await _walk("move_left")
	_check(scene.area == "forge_yard", "Walking through the hall's left doorway returns to the yard")
	scene.player.position = Vector2(1090, 485)
	await _walk("move_right")
	_check(scene.area == "industrial" and GameState.coins == 77, "The yard connects to the industrial district on foot for free")
	scene.player.position = Vector2(60, 445)
	await _walk("move_left")
	_check(scene.area == "forge_yard", "Walking left from the industrial district reaches the foundry")
	_check(GameState.has_item("costal_carbon", 4) and scene.iron.data.stage == 2, "Walking between workshops preserves mission inventory and stage")
	scene.player.position = scene.points.coachman + Vector2(-45, 20)
	scene._interact("coachman")
	_buttons()[2].pressed.emit()
	_check(_buttons()[0].text.contains("Incluido"), "William offers the foundry return as included")
	scene._close_dialogue()
	_check(scene.ride.active and scene.ride.returning and scene.ride.destination_area == "forge_yard" and GameState.coins == 77, "Foundry return uses the correct origin without charging")
	scene.ride.complete()
	_check(scene.area == "coach_depot" and GameState.coins == 77, "Foundry return arrives at the original London coach station")
	scene.player.position = Vector2(610, 560)
	scene._interact("coachman")
	_buttons()[2].pressed.emit()
	scene._close_dialogue()
	_check(scene.ride.active and GameState.coins == 67, "A second outbound trip charges exactly its own fare")
	scene.ride.elapsed = 34.25
	scene.ride.apply_timeline()
	scene._show_journal()
	GameState.save_progress()
	_check(GameState.checkpoint.city_ride.destination_area == "forge_yard", "Saved journey includes the new foundry destination")
	if not failures.is_empty(): _restore_files()
	print("FOUNDRY WRITE: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _read() -> void:
	_check(GameState.continue_saved_game(), "Fresh process loads the saved foundry journey")
	await get_tree().scene_changed
	await _settle()
	_freeze()
	_check(scene.ride.active and scene.ride.destination_area == "forge_yard" and is_equal_approx(scene.ride.elapsed, 34.25), "Fresh process restores the exact foundry arrival instant")
	_check(scene.journal_overlay.visible and scene.ride.background.texture == Art.YARD and GameState.coins == 67, "Paused journal, foundry background and paid balance survive shutdown")
	scene._process(3.0)
	_check(is_equal_approx(scene.ride.elapsed, 34.25), "Journal keeps the restored foundry journey paused")
	scene._hide_journal()
	scene._process(6.0)
	_check(scene.area == "forge_yard" and GameState.coins == 67 and int(GameState.phase_two.city_transport.fares_paid) == 20, "Resumed foundry arrival does not bill again")
	_check(GameState.has_item("costal_carbon", 4) and "cort" in Journey.ensure().talked and not Campaign.done("forge"), "Sacks and Cort's discovery persist without a forge puzzle completion")
	scene.player.position = Art.YARD_DOOR + Vector2(0, 25)
	scene._interact("forge_door")
	await get_tree().create_timer(0.6).timeout
	_check(scene.area == "forge_hall" and scene.actors.has("cort"), "Restored game can still enter the hall")
	GameState.restart_phase_two()
	await get_tree().scene_changed
	await _settle()
	_check(GameState.coins == 87 and not GameState.has_item("costal_carbon") and GameState.phase_complete, "Restart restores phase-two entry money and preserves completed phase one")
	_check(not GameState.phase_two.has("arrival") and not GameState.phase_two.has("iron_mission"), "Restart clears the new visit with other phase-two progress")
	_restore_files()
	print("FOUNDRY READ: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _restore_files() -> void:
	if not FileAccess.file_exists(BACKUP): return
	GameState.run_started = false
	Phase2Metrics.set_process(false)
	if Phase2Metrics.task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(Phase2Metrics.task_id)
		Phase2Metrics.task_id = -1
	var backups: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKUP))
	for path in backups:
		if backups[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else: FileAccess.open(path, FileAccess.WRITE).store_buffer(Marshalls.base64_to_raw(str(backups[path])))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
