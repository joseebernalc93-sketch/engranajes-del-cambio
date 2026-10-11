extends Node
const EngineHouse := preload("res://scripts/world/engine_house_art.gd")
const Journey := preload("res://scripts/world/london_journey.gd")
const BACKUP := "user://london_coach_test_backup.json"
var failures: Array[String] = []
var checks: int = 0
var scene: Control
var capture: bool = false

func begin() -> void:
	capture = "--capture-ui" in OS.get_cmdline_user_args()
	if "--read-coach" in OS.get_cmdline_user_args(): await _read()
	else: await _write()

func _write() -> void:
	var backup := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backup[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	FileAccess.open(BACKUP, FileAccess.WRITE).store_string(JSON.stringify(backup))
	for difficulty in ["facil", "dificil"]:
		await _switch("res://scenes/ui/main_menu.tscn")
		GameState.reset_progress(false)
		GameState.difficulty = difficulty
		GameState.run_started = true
		GameState.add_item("costal_harina")
		GameState._sell_flour()
		_check(GameState.coins == 100, "Flour pays 100")
		GameState._sell_flour()
		_check(GameState.coins == 100, "Flour cannot be sold twice")
		_check(GameState.book_passenger_coach("res://scenes/station.tscn") and GameState.coins == 97, "Village coach costs three")
		GameState.complete_passenger_coach_trip("res://scenes/station.tscn")
		EventBus.dialogue_action_selected.emit("buy_ticket")
		_check(GameState.coins == 87 and GameState.has_item("boleto"), "Train costs ten; 87 remain")
		GameState.complete_train_departure()
		_check(not GameState.has_item("boleto") and GameState.flags.ticket_bought, "Boarding consumes ticket while retaining travel history")
		var arrival := Journey.ensure()
		arrival.arrived = true
		arrival.city_reached = true
		arrival.elapsed = 9.5
		await _switch(GameState.PHASE_TWO_SCENE)
		scene = get_tree().current_scene
		_freeze()
		scene._set_area("street", Vector2(576, 551))
		await _walk("move_down")
		_check(scene.area == "coach_depot", "Walking down leaves railway plaza for coach station")
		_check(scene.actors.has("coachman") and scene.scenery.has_node("LondonParkedCoach"), "New station has a coachman, coach and horse")
		var hero: Sprite2D = scene.player.get_node("Sprite2D")
		var william: Sprite2D = scene.actors.coachman.get_child(0)
		var hero_size := _solid_size(hero) * hero.scale.abs()
		var william_size := _solid_size(william) * william.scale.abs()
		_check(absf(hero_size.y - william_size.y) < 0.5, "William's actual opaque height matches the protagonist")
		_check(william_size.x >= hero_size.x * 0.8, "Coachman has substantial chibi proportions rather than a thin adult silhouette")
		_check(william.texture.resource_path.ends_with("william_coachman_pixel_v2.png"), "London uses its new coachman without replacing Ramon in the village")
		_check(not scene.hud.slot_buttons.has("boleto"), "Consumed train ticket does not appear in inventory")
		scene.player.position = Vector2(605, 560)
		scene.player.facing = "down"
		scene.player._set_sprite_frame(1)
		scene._update_nearest()
		await _shot(difficulty + "_01_parada")
		scene.player.position = Vector2(576, 442)
		await _walk("move_up")
		_check(scene.area == "street", "Coach station connects back to plaza on foot")
		scene._set_area("coach_depot", Vector2(610, 560))
		scene._update_nearest()
		_check(scene.hud.prompt_label.text.contains("William"), "Coachman has shared proximity prompt")
		scene._interact("coachman")
		_check(scene.dialogue.visible and scene.dialogue_text.text.contains("10 monedas"), "Fare is disclosed before purchase")
		_check(scene.dialogue_text.text.begins_with("¿A dónde deseas ir?"), "Coachman asks the player for a destination")
		var destination_buttons := _destination_buttons()
		var labels: Array[String] = []
		for button in destination_buttons: labels.append(button.text)
		_check(labels == ["Ensamble del motor", "El pozo minero", "La forja y fundición", "Nave Textil"], "Exactly four destination options appear in the requested order")
		_check(not destination_buttons[0].disabled and not destination_buttons[1].disabled and not destination_buttons[2].disabled and destination_buttons[3].disabled, "Engine assembly, mine and foundry offer trips; textile remains reserved")
		_check(destination_buttons[0].get_parent() is GridContainer and destination_buttons[0].get_parent().columns == 2, "Four routes use a two-by-two grid")
		scene._cycle_focus(false)
		_check(get_viewport().gui_get_focus_owner() == destination_buttons[1], "Tab reaches the new mine destination")
		scene._cycle_focus(false)
		_check(get_viewport().gui_get_focus_owner() == destination_buttons[2], "Tab reaches the foundry destination")
		scene._cycle_focus(false)
		_check(get_viewport().gui_get_focus_owner() == destination_buttons[0], "Tab skips reserved routes and stays inside the selector")
		await _shot(difficulty + "_03_cuatro_destinos")
		var viewport := get_viewport() as Window
		viewport.size = Vector2i(800, 500)
		await _settle()
		_check(scene.dialogue.get_global_rect().size.x <= viewport.get_visible_rect().size.x, "Destination panel fits a smaller game window")
		for button in destination_buttons:
			_check(scene.dialogue.get_global_rect().encloses(button.get_global_rect()), "Each route button stays inside the dialogue panel")
		await _shot(difficulty + "_04_destinos_ventana_pequena")
		viewport.size = Vector2i(1152, 648)
		await _settle()
		GameState.save_progress()
		var choices_save: Dictionary = scene.get_session_state()
		scene._cancel_dialogue()
		scene.restore_session_state(choices_save)
		_check(scene.dialogue_kind == "coach_destinations" and _destination_buttons().size() == 4 and GameState.coins == 87, "Saved route selection restores all four options without charging")
		scene._cancel_dialogue()
		_check(GameState.coins == 87 and not scene.ride.active, "Cancelling does not charge or depart")
		GameState.coins = 9
		scene._interact("coachman")
		_destination_buttons()[0].pressed.emit()
		_check(scene.dialogue_kind == "coach_unaffordable" and scene.hud.dialogue_options.get_child_count() == 1, "Insufficient funds do not offer a paid ride")
		scene._close_dialogue()
		_check(not scene._book_city_coach() and GameState.coins == 9, "Insufficient funds cannot start travel")
		scene._close_dialogue()
		GameState.coins = 87
		EventBus.coins_changed.emit(87)
		scene._interact("coachman")
		_destination_buttons()[0].pressed.emit()
		_check(scene.dialogue_kind == "coach_trip" and scene.dialogue_text.text.contains("Ensamble del motor") and GameState.coins == 87, "Choosing engine assembly opens a separate fare confirmation without charging")
		scene._cancel_dialogue()
		scene._interact("coachman")
		_destination_buttons()[0].pressed.emit()
		(scene.hud.dialogue_options.get_child(0) as Button).pressed.emit()
		_check(scene.ride.active and GameState.coins == 77 and scene.hud.get_node("%CoinsLabel").text == "77", "Real purchase starts journey and leaves 77")
		_check(scene.ride.coach.driver_portrait == scene.COACHMAN, "The travelling driver uses William's new pixel-art portrait too")
		_check(not scene._book_city_coach() and GameState.coins == 77, "Duplicate purchase cannot charge again")
		_check(scene._blocked() and not scene.hud.prompt_panel.visible, "Travel blocks walking and proximity prompts")
		_check(scene.ride.TOTAL_TIME >= 40, "Journey is a long cinematic")
		for moment in [1.4, 5.0, 14.0, 25.0, 34.0, 38.6]:
			scene.ride.elapsed = moment
			scene.ride.apply_timeline()
			_check(scene.ride.coach.position.is_finite(), "Cinematic stage has valid coach geometry")
			await _shot(difficulty + "_trayecto_%02d" % int(moment))
		scene.ride.elapsed = 19.75
		scene.ride.apply_timeline()
		_check(scene.ride.stage == "city_road" and scene.ride.background.position.x < 0, "City panorama scrolls through canal toward factories")
		var wheel: float = scene.ride.coach.travelled
		scene._process(0.5)
		_check(scene.ride.coach.travelled > wheel, "Horse and carriage wheels animate during transit")
		scene.ride.elapsed = 19.75
		scene.ride.apply_timeline()
		scene._show_journal()
		scene._process(5.0)
		_check(is_equal_approx(scene.ride.elapsed, 19.75), "Journal pauses the exact travel instant")
		scene._hide_journal()
		scene.application_focused = false
		scene._process(5.0)
		_check(is_equal_approx(scene.ride.elapsed, 19.75), "Focus loss pauses the ride")
		scene.application_focused = true
		scene._show_inventory()
		scene._process(5.0)
		_check(scene.hud.inventory_overlay.visible and is_equal_approx(scene.ride.elapsed, 19.75), "Inventory is available and pauses transit")
		scene.hud._close_inventory()
		GameState.save_progress()
		_check(GameState.checkpoint.city_ride.active and is_equal_approx(float(GameState.checkpoint.city_ride.elapsed), 19.75), "Save includes exact paid journey")
		scene._return_home()
		await get_tree().scene_changed
		await _settle()
		_check(GameState.continue_saved_game(), "Main menu can continue a paid journey")
		await get_tree().scene_changed
		await _settle()
		scene = get_tree().current_scene
		_freeze()
		_check(scene.ride.active and absf(scene.ride.elapsed - 19.75) < 0.25 and GameState.coins == 77, "Continue resumes transit without rebilling")
		scene._process(scene.ride.TOTAL_TIME - scene.ride.elapsed + 0.01)
		_check(scene.area == "industrial" and GameState.phase_two.city_transport.industrial_reached, "Arrival opens industrial district")
		_check(not scene._blocked() and scene.player.controls_enabled and scene.player.position == EngineHouse.COACH_LANDING, "Natural cinematic completion restores walking at a safe landing")
		await get_tree().physics_frame
		_check(not scene.player.test_move(scene.player.global_transform, Vector2(0, -1)), "Landing is clear of the carriage and actor footprint")
		_check(int(GameState.phase_two.city_transport.fares_paid) == 10, "Only one ten-coin fare recorded")
		await _shot(difficulty + "_02_distrito_industrial")
		scene.player.position = EngineHouse.COACHMAN_POSITION + Vector2(-45, 20)
		scene._interact("coachman")
		_destination_buttons()[0].pressed.emit()
		_check(scene.dialogue_text.text.contains("incluye el regreso"), "Industrial coach offers included return")
		(scene.hud.dialogue_options.get_child(0) as Button).pressed.emit()
		_check(scene.ride.active and scene.ride.returning and GameState.coins == 77, "Return journey is free and faces opposite direction")
		scene.ride.complete()
		_check(scene.area == "coach_depot" and GameState.coins == 77, "Return arrives at the original coach station")
		if difficulty == "dificil":
			GameState.coins = 87
			EventBus.coins_changed.emit(87)
			_check(scene._book_city_coach() and GameState.coins == 77, "A new outbound journey charges its own fare once")
			scene.ride.elapsed = 19.75
			scene.ride.apply_timeline()
			scene._show_journal()
			GameState.save_progress()
	print("LONDON COACH WRITE: %d checks, %d failures" % [checks, failures.size()])
	if not failures.is_empty(): _restore_files()
	get_tree().quit(0 if failures.is_empty() else 1)

func _read() -> void:
	_check(GameState.continue_saved_game(), "Fresh process opens paid transit")
	await get_tree().scene_changed
	await _settle()
	scene = get_tree().current_scene
	_freeze()
	_check(scene.area == "coach_depot" and scene.ride.active and is_equal_approx(scene.ride.elapsed, 19.75), "Fresh process restores exact paid ride")
	_check(scene.journal_overlay.visible and GameState.coins == 77 and GameState.difficulty == "dificil", "Journal, balance and difficulty survive shutdown")
	_check(not GameState.has_item("boleto"), "Used train ticket stays consumed")
	_check(is_equal_approx(scene.ride.coach.travelled, float(GameState.checkpoint.city_ride.coach_distance)), "Wheel and horse phase survive shutdown at the paused instant")
	scene._hide_journal()
	scene.ride.complete()
	_check(scene.area == "industrial" and GameState.coins == 77, "Resumed arrival never charges again")
	# Migrate a real version-17 completed journey with the old zero balance.
	await _switch("res://scenes/ui/main_menu.tscn")
	GameState.reset_progress(false)
	preload("res://scripts/core/phase2_campaign.gd").ensure()
	var old_flags := GameState.flags.duplicate(true)
	old_flags.flour_sold = true
	old_flags.ticket_bought = true
	old_flags.coach_fare_paid = true
	var legacy := {"save_version": 17, "run_started": true, "difficulty": "facil", "coins": 0, "inventory": {"boleto": 1, "recuerdo": 1}, "flags": old_flags, "metrics": GameState.metrics.duplicate(true), "phase_complete": true, "phase_summary": {"monedas_harina": 13, "tiempo_segundos": 556}, "phase_two": {"active": true}, "checkpoint": {"scene": GameState.PHASE_TWO_SCENE, "area": "street", "position": [700, 520]}}
	legacy.phase_two = GameState.phase_two.duplicate(true)
	FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify(legacy))
	_check(GameState.load_progress() and GameState.coins == 87, "Existing completed saves receive the 87-coin difference")
	_check(not GameState.has_item("boleto") and GameState.has_item("recuerdo"), "Migration removes only the used train ticket")
	_check(int(GameState.phase_summary.monedas_harina) == 100 and int(GameState.phase_summary.tiempo_segundos) == 556, "Migration updates flour accounting while preserving completion time")
	_check(GameState.checkpoint.area == "street" and Vector2(float(GameState.checkpoint.position[0]), float(GameState.checkpoint.position[1])) == Vector2(700, 520), "Migration preserves exact map position")
	_check(GameState.load_progress() and GameState.coins == 87, "Repeated loading never duplicates compensation")
	legacy.coins = 5
	FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify(legacy))
	_check(GameState.load_progress() and GameState.coins == 92, "Migration adds only the difference to an existing balance")
	legacy.phase_complete = false
	legacy.flags.flour_sold = false
	legacy.flags.ticket_bought = false
	legacy.coins = 0
	legacy.inventory = {"herramientas": 1}
	FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify(legacy))
	_check(GameState.load_progress() and GameState.coins == 0, "Unsold flour grants no migration reward")
	_restore_files()
	print("LONDON COACH READ: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _freeze() -> void:
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.application_focused = true

func _switch(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await _settle()

func _walk(action: String) -> void:
	Input.action_press(action)
	for step in 40:
		await get_tree().physics_frame
		scene._physics_process(1.0 / 60.0)
		if scene.changing_area: break
	Input.action_release(action)
	await get_tree().create_timer(0.6).timeout

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _shot(filename: String) -> void:
	if not capture: return
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var directory := "res://output/ui/london_coach"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + filename + ".png")

func _restore_files() -> void:
	GameState.run_started = false
	Phase2Metrics.set_process(false)
	Phase2Metrics.flush()
	if not FileAccess.file_exists(BACKUP): return
	var backups: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKUP))
	for path in backups:
		if backups[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else: FileAccess.open(path, FileAccess.WRITE).store_buffer(Marshalls.base64_to_raw(str(backups[path])))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition: return
	failures.append(message)
	push_error("LONDON COACH: " + message)

func _destination_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in scene.hud.dialogue_options.find_children("*", "Button", true, false):
		buttons.append(child as Button)
	return buttons

func _solid_size(sprite: Sprite2D) -> Vector2:
	# Independent body measurement catches transparent-padding and proportion regressions.
	var image: Image = sprite.texture.get_image().get_region(Rect2i(sprite.region_rect))
	var left := image.get_width()
	var right: int = -1
	var top := image.get_height()
	var bottom: int = -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.5: continue
			left = mini(left, x)
			right = maxi(right, x)
			top = mini(top, y)
			bottom = maxi(bottom, y)
	return Vector2(right - left + 1, bottom - top + 1)
