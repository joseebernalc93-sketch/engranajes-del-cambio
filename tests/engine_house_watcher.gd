extends Node
const Art := preload("res://scripts/world/engine_house_art.gd")
const Journey := preload("res://scripts/world/london_journey.gd")
const Bounds := preload("res://scripts/world/sprite_body_bounds.gd")
const BACKUP := "user://engine_house_backup.json"
var scene: Control
var checks := 0
var failures: Array[String] = []

func begin() -> void:
	if "--read-engine-house" in OS.get_cmdline_user_args(): await _read()
	else: await _write()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("ENGINE HOUSE: " + message)

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

func _buttons() -> Array[Node]:
	return scene.hud.dialogue_options.find_children("*", "Button", true, false)

func _click_door(at: Vector2, id: String, destination: String) -> void:
	scene._navigate_pointer(at)
	_check(scene.pending_interaction == id, "Pictured door selects " + id)
	for frame in 300:
		await get_tree().physics_frame
		scene._physics_process(1.0 / 60.0)
		if scene.changing_area or scene.target == Vector2.INF: break
	await get_tree().create_timer(0.6).timeout
	scene.application_focused = true
	_check(scene.area == destination, "Walking to door reaches " + destination + " (actual %s, %s)" % [scene.area, scene.player.position])

func _walk(action: String, destination: String) -> void:
	Input.action_press(action)
	for frame in 40:
		await get_tree().physics_frame
		scene._physics_process(1.0 / 60.0)
		if scene.changing_area: break
	Input.action_release(action)
	await get_tree().create_timer(0.6).timeout
	scene.application_focused = true
	_check(scene.area == destination, "Walk through doorway reaches " + destination)

func _shot(name: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args(): return
	await _settle()
	RenderingServer.force_draw(false)
	var directory := "res://output/ui/engine_house"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")

func _write() -> void:
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	FileAccess.open(BACKUP, FileAccess.WRITE).store_string(JSON.stringify(backups))
	await _switch("res://scenes/ui/main_menu.tscn")
	GameState.reset_progress(false)
	GameState.run_started = true
	GameState.phase_complete = true
	GameState.coins = 87
	GameState.ensure_phase_two_entry()
	GameState.inventory["costal_carbon"] = 4
	GameState.inventory["biela"] = 1
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
	(_buttons()[0] as Button).pressed.emit()
	scene._close_dialogue()
	_check(scene.ride.active and GameState.coins == 77, "Engine destination charges ten once")
	scene.ride.elapsed = 34.25
	scene.ride.apply_timeline()
	_check(scene.ride.background.texture == Art.YARD, "Journey arrives at the new engine-house patio")
	scene._process(6.0)
	_check(scene.area == "industrial" and scene.player.position == Art.COACH_LANDING and not scene._blocked(), "Coach restores walking in the clear yard landing")
	_check(scene.backdrop.texture == Art.YARD and scene.actors.size() == 1 and scene.actors.has("coachman"), "Exterior has approved background and independent William")
	await get_tree().physics_frame
	_check(not scene.player.test_move(scene.player.global_transform, Vector2(0, -1)), "Landing is clear of coach and foreground railings")
	await _shot("01_patio")
	await _click_door(Vector2(674, 310), "engine_door", "engine_hall")
	_check(scene.backdrop.texture == Art.HALL and scene.actors.size() == 1 and scene.actors.has("murdoch"), "Nave has only Murdoch as NPC")
	var hero: Sprite2D = scene.player.get_node("Sprite2D")
	var murdoch: Sprite2D = scene.actors.murdoch.get_child(0)
	var hero_height: float = Bounds.measure(hero.texture.get_image().get_region(Rect2i(hero.region_rect))).size.y * hero.scale.y * scene.player.scale.y
	var npc_height: float = Bounds.measure(murdoch.texture.get_image().get_region(Rect2i(murdoch.region_rect))).size.y * murdoch.scale.y
	_check(absf(hero_height - npc_height) < 0.5, "Murdoch matches the protagonist's opaque visible height")
	_check(murdoch.texture.get_image().get_pixel(0, 0).a == 0.0, "Murdoch has a transparent sprite")
	_check(not scene.iron_popup.is_open() and not scene.dialogue.visible, "Entering the nave leaves exploration active")
	await _shot("02_nave")
	scene.player.position = Art.MURDOCH_POSITION + Vector2(-65, 20)
	scene._update_nearest()
	_check(scene.hud.prompt_label.text == "E  Hablar con Murdoch, ingeniero", "Murdoch uses the shared E proximity prompt")
	await _shot("03_murdoch")
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.physical_keycode = KEY_E
	interact.pressed = true
	scene._unhandled_input(interact)
	_check(scene.dialogue_kind == "murdoch" and scene.dialogue_text.text.contains("sala de montaje"), "E opens Murdoch's directions in the shared dialogue")
	_check(GameState.has_item("biela") and GameState.has_item("costal_carbon", 4) and GameState.coins == 77 and not scene.iron_popup.is_open(), "Talking preserves the biela, coal and purse")
	await _shot("04_dialogo")
	var saved_position: Vector2 = scene.player.position
	scene._return_home()
	await get_tree().scene_changed
	await _settle()
	_check(GameState.continue_saved_game(), "Continue loads the new nave area")
	await get_tree().scene_changed
	await _settle()
	_freeze()
	_check(scene.area == "engine_hall" and scene.player.position == saved_position and scene.dialogue_kind == "murdoch", "Continue restores exact nave position and conversation")
	scene._close_dialogue()
	_check(not scene.iron_popup.is_open() and GameState.has_item("biela"), "Closing Murdoch's directions returns to walking")
	await _click_door(Vector2(910, 280), "engine_mount_door", "engine_room")
	_check(scene.backdrop.texture == Art.ASSEMBLY and scene.actors.is_empty(), "Mounting room contains the protagonist and stationary machinery")
	_check(not scene.iron_popup.is_open() and GameState.has_item("biela"), "Entering the room does not install the link automatically")
	await _shot("05_sala_montaje")
	scene.player.position = Art.BENCH + Vector2(-55, 30)
	scene._update_nearest()
	_check(scene.hud.prompt_label.text == "E  Trabajar en el motor", "Motor has an E prompt in reach of the bench")
	await _shot("06_proximidad_motor")
	scene._interact("engine_bench")
	_check(scene.dialogue_kind == "motor_biela" and not scene.iron_popup.is_open(), "Existing biela confirmation is offered at the motor")
	scene._cancel_dialogue()
	_check(GameState.has_item("biela") and not scene.iron.data.biela_installed, "Cancelling installation preserves the link")
	scene.player.position = Vector2(112, 435)
	await _walk("move_left", "engine_hall")
	scene.player.position = Vector2(112, 435)
	await _walk("move_left", "industrial")
	scene.player.position = Vector2(60, 445)
	await _walk("move_left", "forge_yard")
	scene.player.position = Vector2(1090, 485)
	await _walk("move_right", "industrial")
	_check(scene.player.position == Vector2(100, 445), "Old road spawn moves above the new foreground fence")
	scene.player.position = Vector2(1090, 445)
	await _walk("move_right", "mine_yard")
	scene.player.position = Vector2(60, 480)
	await _walk("move_left", "industrial")
	_check(GameState.coins == 77 and GameState.has_item("costal_carbon", 4) and scene.iron.data.gears == [1, -1, -1], "Walking across workshops preserves paid fare and engine work")
	scene._set_area("industrial", Vector2(350, 590))
	_check(scene.player.position == Art.COACH_LANDING, "Legacy yard position is relocated to the clear courtyard")
	scene._set_area("engine_room", Vector2(760, 586))
	_check(scene.player.position == Vector2(700, 586), "Legacy motor position is relocated clear of the new bench")
	scene.player.position = Art.BENCH + Vector2(-55, 30)
	scene._interact("engine_bench")
	scene._close_dialogue()
	_check(scene.iron_popup.is_open() and scene.iron.data.biela_installed and not GameState.has_item("biela"), "Existing motor puzzle opens and consumes its link once")
	scene.iron_popup.close()
	_check(GameState.has_item("costal_carbon", 4) and GameState.coins == 77, "Installing keeps all coal and coins")
	scene._show_inventory()
	GameState.save_progress()
	_check(GameState.checkpoint.area == "engine_room", "Mounting room is saved as its own exploration area")
	if not failures.is_empty(): _restore_files()
	print("ENGINE HOUSE WRITE: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _read() -> void:
	_check(GameState.continue_saved_game(), "Fresh process opens the mounting-room save")
	await get_tree().scene_changed
	await _settle()
	_freeze()
	_check(scene.area == "engine_room" and scene.backdrop.texture == Art.ASSEMBLY and scene.hud.inventory_overlay.visible, "Room and open inventory survive a fresh process")
	_check(scene.iron.data.biela_installed and scene.iron.data.gears == [1, -1, -1] and not GameState.has_item("biela"), "Installed link and partial gears survive without duplication")
	_check(GameState.coins == 77 and GameState.has_item("costal_carbon", 4), "Real purse and sacks survive")
	scene.hud._close_inventory()
	scene._update_modal_feedback()
	scene._interact("engine_bench")
	_check(scene.iron_popup.is_open(), "Restored room opens the existing motor puzzle")
	scene.iron_popup.close()
	scene.iron.data.complete = true
	scene.player.position = Vector2(1110, 435)
	scene._interact("textile_exit")
	await get_tree().create_timer(0.6).timeout
	_check(scene.area == "textile_view", "Completed engine retains its textile connection")
	scene.player.position = Vector2(278, 585)
	await _walk("move_left", "engine_room")
	_check(scene.player.position == Vector2(1030, 435), "Textile return lands in the upper motor aisle")
	scene._set_area("industrial", Art.COACHMAN_POSITION + Vector2(-45, 20))
	scene._interact("coachman")
	(_buttons()[0] as Button).pressed.emit()
	scene._close_dialogue()
	_check(scene.ride.active and scene.ride.returning and GameState.coins == 77, "New yard retains the included coach return")
	scene.ride.complete()
	_check(scene.area == "coach_depot" and GameState.coins == 77, "Return reaches London without charging")
	GameState.restart_phase_two()
	await get_tree().scene_changed
	await _settle()
	_check(GameState.coins == 87 and not GameState.has_item("costal_carbon") and not GameState.phase_two.has("iron_mission"), "Restart resets the chapter to its phase-one entry balance")
	_restore_files()
	print("ENGINE HOUSE READ: %d checks, %d failures" % [checks, failures.size()])
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
