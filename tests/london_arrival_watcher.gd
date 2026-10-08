extends Node
const Journey := preload("res://scripts/world/london_journey.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const BACKUP := "user://london_arrival_test_backup.json"
var failures: Array[String] = []
var checks: int = 0
var capture: bool = false
var scene: Control

func begin() -> void:
	capture = "--capture-ui" in OS.get_cmdline_user_args()
	if "--read-london" in OS.get_cmdline_user_args(): await _read()
	else: await _write()

func _write() -> void:
	var fringe := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	fringe.fill(Color.TRANSPARENT)
	fringe.fill_rect(Rect2i(8, 12, 16, 40), Color.WHITE)
	fringe.set_pixel(0, 0, Color(1, 1, 1, 0.01))
	fringe.set_pixel(31, 63, Color(1, 1, 1, 0.01))
	_check(preload("res://scripts/world/sprite_body_bounds.gd").measure(fringe) == Rect2i(8, 12, 16, 40), "Almost transparent generation residue does not shrink character bodies")
	fringe.fill(Color.TRANSPARENT)
	_check(preload("res://scripts/world/sprite_body_bounds.gd").measure(fringe) == Rect2i(), "An empty character image has no body bounds")
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	FileAccess.open(BACKUP, FileAccess.WRITE).store_string(JSON.stringify(backups))
	for difficulty in ["facil", "dificil"]:
		# Leave the previous London scene before starting an independent run.
		# Otherwise its capture callback would seed the new chapter checkpoint.
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		await _changed()
		GameState.reset_progress(false)
		GameState.run_started = true
		GameState.phase_complete = true
		GameState.phase_summary = {"fase": "El éxodo rural", "tiempo_segundos": 556, "dificultad": difficulty}
		GameState.difficulty = difficulty
		Campaign.ensure()
		Campaign.save_work("mine", {"stage": 2, "accepted": [0, 2]})
		GameState.open_phase_two()
		await _changed()
		var intro: Control = get_tree().current_scene
		_check(intro.scene_file_path == GameState.PHASE_TWO_INTRO, "Phase-one continuation opens the story")
		for page in 4:
			_check(not intro.STORY_TEXTS[page].contains("Briggs"), "Story introduces arrival before meeting factory tutors")
			intro._advance_story()
			if page < 3: await _settle()
		await _changed()
		scene = get_tree().current_scene
		scene.set_process(false)
		scene.set_physics_process(false)
		scene.application_focused = true
		_check(scene.scene_file_path == GameState.PHASE_TWO_SCENE, "Story opens London arrival")
		_check(scene.find_children("*", "CanvasLayer", true, false).size() == 1 and scene.hud.inventory_only, "Arrival reuses the phase-one HUD without workshop popups")
		_check(scene.actors.keys() == ["guide"], "Platform contains only the protagonist and the train attendant")
		_check_character_size("guide")
		var attendant_texture: AtlasTexture = scene.actors.guide.get_child(0).texture
		_check(scene.dialogue == scene.hud.dialogue_panel and scene.dialogue_heading == scene.hud.dialogue_speaker, "London reuses the exact phase-one dialogue panel and speaker style")
		_check(Campaign.remaining() == (15 if difficulty == "facil" else 10), "Difficulty and shared opportunities are preserved")
		_check(scene.journal.journey_difficulty.text.contains("Fácil" if difficulty == "facil" else "Difícil"), "Difficulty remains available in the journal")
		_check(scene.hud.scene_file_path == "res://scenes/ui/hud.tscn" and scene.hud.get_node("%CoinsLabel").text == str(GameState.coins), "London uses exactly the same inventory and live coin bar as phase one")
		GameState.coins = 13
		EventBus.coins_changed.emit(13)
		_check(scene.hud.get_node("%CoinsLabel").text == "13", "Shared coin bar updates when the balance changes")
		_check(scene.content.find_children("*", "Label", false, false).is_empty() and scene.scenery.find_children("*", "Label", true, false).is_empty(), "Exploration has no headings, controls, location labels, signs or NPC name tags")
		_check(not scene.player.visible and not Journey.ensure().arrived, "Player stays aboard until arrival")
		scene.elapsed = 2.5
		scene._apply_arrival()
		await _shot(difficulty + "_01_tren_llegando")
		var train_position: Vector2 = scene.train.position
		scene._show_journal()
		_check(get_viewport().gui_get_focus_owner() == scene.journal.journey_continue, "Journal focuses Continue rather than the main-menu action")
		for tab in 12: scene._cycle_focus(false)
		_check(scene.journal.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Tab stays inside the open journal")
		scene._process(3.0)
		_check(is_equal_approx(scene.elapsed, 2.5) and scene.train.position == train_position, "Journal freezes arrival animation and particles")
		_check(scene.journal.journey_page.visible and not scene.journal.factory_objective.visible, "Journal shows travel discoveries instead of workshop cards")
		scene.journal.turn_to(1)
		_check(scene.journal.summary.visible and scene.journal.stats.text.contains("09:16"), "Previous page preserves chapter-one report")
		scene.journal.turn_to(2)
		scene._hide_journal()
		scene.application_focused = false
		scene._process(3.0)
		_check(is_equal_approx(scene.elapsed, 2.5), "Focus loss freezes train")
		scene.application_focused = true
		GameState.save_progress()
		_check(GameState.checkpoint.area == "platform" and is_equal_approx(float(GameState.checkpoint.elapsed), 2.5), "Save captures exact cinematic time")
		var save := JSON.parse_string(JSON.stringify(GameState.checkpoint)) as Dictionary
		scene.restore_session_state(save)
		_check(scene.train.position == train_position and not scene.player.visible, "Restoring cinematic does not restart it")
		scene.elapsed = 7.6
		scene._apply_arrival()
		_check(scene.player.visible and scene.player.position.y < 462, "Player steps from carriage onto platform")
		await _shot(difficulty + "_02_descenso")
		scene._process(2.0)
		_check(Journey.ensure().arrived and scene.player.visible, "Cinematic ends in controllable platform")
		scene.hud.get_node("%InventoryButton").pressed.emit()
		_check(scene.hud.inventory_overlay.visible and scene._blocked(), "Shared inventory button opens the real inventory and pauses exploration")
		await _shot(difficulty + "_inventario_compartido")
		var stationary: Vector2 = scene.player.position
		Input.action_press("move_right")
		scene._physics_process(1.0 / 60.0)
		Input.action_release("move_right")
		_check(scene.player.position == stationary, "Walking is suspended while inventory is open")
		for tab in 12: scene._cycle_focus(false)
		_check(scene.hud.inventory_overlay.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Keyboard focus stays within inventory")
		var inventory_save: Dictionary = scene.get_session_state()
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		get_viewport().push_input(escape, true)
		await _settle()
		_check(not scene.hud.inventory_overlay.visible and not scene.journal_overlay.visible, "Escape closes inventory without opening the journal")
		scene.restore_session_state(inventory_save)
		_check(scene.hud.inventory_overlay.visible, "Saved London session restores an open inventory")
		scene.hud._close_inventory()
		scene._show_inventory()
		_check(scene.hud.inventory_overlay.visible and not scene.dialogue.visible, "I opens the shared inventory rather than a text-only dialogue")
		scene._show_inventory()
		_check(not scene.hud.inventory_overlay.visible, "I toggles inventory closed")
		await _shot(difficulty + "_03_andenes")
		await _walk_exit(Vector2(1091, 551), "move_right")
		_check(scene.area == "hall" and not scene.dialogue.visible and not Journey.ensure().guide_spoken, "Walking to the platform's lower right edge reaches the hall without a forced dialogue")
		await _walk_exit(Vector2(61, 410), "move_left")
		_check(scene.area == "platform" and not scene.dialogue.visible, "Walking to the hall's upper left edge returns to the platform")
		scene.player.position = Vector2(760, 492)
		scene._update_nearest()
		_check(scene.hud.prompt_panel.visible and scene.hud.prompt_label.text == "E  Hablar con Henry, encargado del tren", "Approaching attendant shows the phase-one talk prompt")
		await _shot(difficulty + "_aviso_henry")
		var talk := InputEventAction.new()
		talk.action = "interact"
		talk.pressed = true
		get_viewport().push_input(talk, true)
		talk.pressed = false
		get_viewport().push_input(talk, true)
		_check(scene.dialogue.visible and not Journey.ensure().guide_spoken, "Guide conversation is a resumable pending interaction")
		_check(not scene.hud.prompt_panel.visible and scene.dialogue_heading.text == "Henry, encargado del tren", "Talk prompt hides while the shared dialogue is open")
		GameState.save_progress()
		_check(GameState.checkpoint.dialogue_kind == "guide", "Pending guide dialogue is saved")
		await _shot(difficulty + "_04_guia")
		scene._return_home()
		await _changed()
		_check(GameState.continue_saved_game(), "Pending shared dialogue resumes through the title screen")
		await _changed()
		scene = get_tree().current_scene
		scene.set_process(false)
		scene.set_physics_process(false)
		scene.application_focused = true
		_check(scene.dialogue.visible and scene.dialogue_kind == "guide" and not Journey.ensure().guide_spoken, "Continue keeps the attendant conversation pending")
		(scene.hud.dialogue_options.get_child(0) as Button).pressed.emit()
		_check(Journey.ensure().guide_spoken and Journey.objective().contains("derecha"), "Guide updates objective when conversation completes")
		_check(not scene.dialogue.visible, "The real shared Continue button closes the London conversation")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = scene.content.get_global_transform() * Vector2(600, 540)
		get_viewport().push_input(click, true)
		await _settle()
		_check(scene.target.distance_to(Vector2(600, 540)) < 1.0, "Actual mouse event passes correct viewport coordinates through map UI")
		click.pressed = false
		get_viewport().push_input(click, true)
		scene.player.position = Vector2(735, 510)
		scene._navigate_pointer(Vector2(803, 442))
		_check(scene.pending_interaction == "guide" and scene.target != Vector2.INF, "Touching NPC approaches and speaks")
		for step in 120:
			await get_tree().physics_frame
			scene._physics_process(1.0 / 60.0)
			if scene.dialogue.visible: break
		_check(scene.dialogue.visible and scene.dialogue_kind == "guide", "Pointer walk reaches real NPC interaction: position=%s target=%s pending=%s blocked=%s" % [scene.player.position, scene.target, scene.pending_interaction, scene._blocked()])
		scene._close_dialogue()
		scene.player.position = Vector2(630, 470)
		Input.action_press("move_up")
		for step in 120: scene._physics_process(1.0 / 60.0)
		Input.action_release("move_up")
		_check(scene.player.position.y >= scene.walk_bounds.position.y, "Physical bounds keep player off the tracks")
		await _walk_exit(Vector2(1091, 445), "move_right")
		_check(scene.area == "hall" and scene.backdrop.texture == scene.BACKGROUNDS.hall, "Platform doorway opens ticket hall")
		_check(scene.actors.keys() == ["clerk"], "Ticket hall contains only the protagonist and the uniformed clerk")
		_check_character_size("clerk")
		var clerk_texture: AtlasTexture = scene.actors.clerk.get_child(0).texture
		_check(attendant_texture.atlas == scene.STAFF and clerk_texture.atlas == scene.STAFF and attendant_texture.region != clerk_texture.region, "Attendant and clerk use two distinct portraits from the new staff atlas")
		_check(_green_pixels(clerk_texture.get_image()) > _green_pixels(attendant_texture.get_image()) * 2, "Ticket clerk has a distinct forest-green uniform")
		scene.player.position = Vector2(520, 407)
		scene.player.facing = "down"
		scene.player._set_sprite_frame(1)
		await _shot(difficulty + "_05_boleteria")
		scene.player.position = Vector2(568, 447)
		scene._interact("clerk")
		_check(scene.dialogue.visible and scene.dialogue_text.text.contains("No necesitas otro boleto"), "Ticket clerk explains exit without charging another fare")
		scene._close_dialogue()
		_check(Journey.ensure().clerk_spoken, "Ticket conversation persists")
		scene.player.position = Vector2(1080, 551)
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.index = 0
		touch.position = scene.content.get_global_transform() * Vector2(1150, 551)
		get_viewport().push_input(touch, true)
		await _settle()
		touch.pressed = false
		get_viewport().push_input(touch, true)
		_check(scene.pending_interaction.is_empty() and scene.target.x == scene.walk_bounds.end.x, "Touching the edge walks there without a labelled exit control")
		await _walk_exit(Vector2(1080, 551), "")
		_check(scene.area == "street" and Journey.ensure().city_reached and not scene.dialogue.visible, "Station edge reveals London without an automatic welcome popup")
		_check(scene.actors.size() == 2 and scene.actors.has("news") and scene.actors.has("resident"), "London keeps its two outdoor characters")
		_check(scene.scenery.has_node("NewspaperStall") and scene.actors.news.position.x < 350 and scene.actors.resident.position.x > 950, "Newspaper seller and carriage-side resident occupy opposite corners")
		_check_character_size("news")
		_check_character_size("resident")
		_check(Journey.objective().contains("Explora") and Journey.steps() == [true, true, true, true], "Arrival concludes in free exploration")
		await _shot(difficulty + "_06_londres")
		scene.player.position = Vector2(336, 539)
		scene.player.facing = "down"
		scene.player._set_sprite_frame(1)
		scene._update_nearest()
		await _shot(difficulty + "_tamano_edward")
		scene.player.position = Vector2(936, 500)
		scene._update_nearest()
		await _shot(difficulty + "_tamano_rose")
		scene.player.position = Vector2(940, 542)
		scene._update_nearest()
		_check(scene.hud.prompt_panel.visible and scene.hud.prompt_label.text.contains("Rose"), "Carriage-side resident has a proximity talk prompt")
		scene._interact("resident")
		await _shot(difficulty + "_rose_carruaje")
		(scene.hud.dialogue_options.get_child(0) as Button).pressed.emit()
		_check("resident" in Journey.ensure().talked, "London residents provide optional conversations")
		scene.player.position = Vector2(250, 565)
		scene._navigate_pointer(Vector2(166, 500))
		_check(scene.pending_interaction == "news", "Touching the newspaper stall approaches its seller")
		for step in 120:
			await get_tree().physics_frame
			scene._physics_process(1.0 / 60.0)
			if scene.dialogue.visible: break
		_check(scene.dialogue.visible and scene.dialogue_kind == "news", "Stall approach reaches the seller without crossing the counter")
		await _shot(difficulty + "_puesto_periodicos")
		if scene.dialogue.visible: (scene.hud.dialogue_options.get_child(0) as Button).pressed.emit()
		scene.player.position = Vector2(400, 550)
		scene._update_nearest()
		_check(not scene.hud.prompt_panel.visible, "Talk prompt disappears after walking away")
		await _walk_exit(Vector2(227, 440), "move_up")
		_check(scene.area == "hall" and Journey.ensure().city_reached, "Can return to ticket hall without erasing city visit: area=%s position=%s blocked=%s" % [scene.area, scene.player.position, scene._blocked()])
		await _walk_exit(Vector2(61, 551), "move_left")
		_check(scene.area == "platform" and Journey.ensure().arrived, "Returning to platform does not replay arrival")
		_check(Campaign.remaining() == Campaign.total() and GameState.phase_two.work.mine.stage == 2, "Exploration consumes no opportunities and preserves reserved puzzles")
		var viewport := get_tree().root
		viewport.size = Vector2i(800, 500)
		await _settle()
		var fitted: Vector2 = scene.content.size * scene.content.scale
		_check(fitted.x <= viewport.get_visible_rect().size.x and fitted.y <= viewport.get_visible_rect().size.y, "Maps and journal fit smaller windows")
		viewport.size = Vector2i(1152, 648)
		await _settle()
	# Leave an exact city checkpoint for the separate process below.
	scene._set_area("street", Vector2(458, 520))
	scene.player.facing = "left"
	scene._show_journal()
	scene.journal.turn_to(1)
	GameState.save_progress()
	await _shot("07_cuaderno_fase_anterior")
	scene.journal.turn_to(2)
	await _shot("08_cuaderno_llegada")
	scene.journal.turn_to(1)
	GameState.save_progress()
	Phase2Metrics.flush()
	print("LONDON ARRIVAL WRITE: %d checks, %d failures" % [checks, failures.size()])
	if not failures.is_empty(): _restore_files()
	get_tree().quit(0 if failures.is_empty() else 1)

func _read() -> void:
	_check(GameState.has_saved_game(), "Fresh process discovers London save")
	if not GameState.has_saved_game():
		_restore_files()
		get_tree().quit(1)
		return
	_check(GameState.continue_saved_game(), "Continue loads London")
	if not failures.is_empty():
		_restore_files()
		get_tree().quit(1)
		return
	await _changed()
	scene = get_tree().current_scene
	scene.application_focused = true
	_check(scene.scene_file_path == GameState.PHASE_TWO_SCENE and scene.area == "street", "Fresh process restores exact map")
	_check(scene.player.position == Vector2(458, 520) and scene.player.facing == "left", "Fresh process restores position and facing")
	_check(scene.journal_overlay.visible and scene.journal.current_page == 1, "Open previous journal page survives shutdown")
	_check(Journey.ensure().guide_spoken and Journey.ensure().clerk_spoken and Journey.ensure().city_reached, "Conversations and discoveries survive shutdown")
	_check(GameState.difficulty == "dificil" and Campaign.remaining() == 10, "Selected difficulty survives shutdown")
	_check(GameState.phase_two.work.mine.stage == 2 and int(GameState.phase_summary.tiempo_segundos) == 556, "Reserved work and frozen chapter one survive")
	scene._hide_journal()
	scene._return_home()
	await _changed()
	_check(GameState.continue_saved_game(), "Main menu returns to same adventure")
	await _changed()
	scene = get_tree().current_scene
	_check(scene.area == "street" and not scene.journal_overlay.visible, "Main-menu Continue resumes closed journal")
	scene._show_inventory()
	scene.hud._set_inventory_mode("glossary")
	scene.hud._show_item("cuerda")
	scene._return_home()
	await _changed()
	_check(GameState.continue_saved_game(), "Open inventory remains resumable through the main menu")
	await _changed()
	scene = get_tree().current_scene
	_check(scene.hud.inventory_overlay.visible and scene.hud.inventory_mode == "glossary" and scene.hud.selected_item_id == "cuerda", "Continue restores the shared inventory, glossary tab and selected item")
	_check(scene.area == "street" and scene.player.position == Vector2(458, 520) and scene._blocked(), "Restored inventory retains world position and suspends movement")
	scene.hud._close_inventory()
	# Simulate an old factory save without deleting its puzzle progress.
	GameState.restoring_session = true
	GameState.checkpoint = {"scene": GameState.PHASE_TWO_FACTORY, "active_workshop": 0}
	GameState.save_progress()
	GameState.restoring_session = false
	_check(GameState.load_progress(), "Old save loads")
	_check(GameState.checkpoint.scene == GameState.PHASE_TWO_SCENE and GameState.phase_two.work.mine.stage == 2, "Old factory save migrates to adventure and retains work")
	_restore_files()
	print("LONDON ARRIVAL READ: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

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

func _changed() -> void:
	await get_tree().scene_changed
	await _settle()

func _walk_exit(start: Vector2, action: String) -> void:
	scene.player.position = start
	if not action.is_empty(): Input.action_press(action)
	for step in 45:
		await get_tree().physics_frame
		scene._physics_process(1.0 / 60.0)
		if scene.changing_area: break
	if not action.is_empty(): Input.action_release(action)
	await get_tree().create_timer(0.60).timeout

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _shot(filename: String) -> void:
	if not capture: return
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var directory := "res://output/ui/london_arrival"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + filename + ".png")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition: return
	failures.append(message)
	push_error("LONDON: " + message)

func _check_character_size(id: String) -> void:
	var hero: Sprite2D = scene.player.get_node("Sprite2D")
	var character: Sprite2D = scene.actors[id].get_child(0)
	var hero_height := _opaque_height(hero.texture.get_image().get_region(Rect2i(hero.region_rect))) * absf(hero.scale.y)
	var npc_height := _opaque_height(character.texture.get_image().get_region(Rect2i(character.region_rect))) * absf(character.scale.y)
	_check(absf(hero_height - npc_height) < 0.5, "%s actual opaque height matches hero: %.2f / %.2f" % [id, npc_height, hero_height])

func _opaque_height(image: Image) -> int:
	# Independently scan solid rows, rather than trusting the authored region height.
	var first: int = -1
	var last: int = -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				if first < 0: first = y
				last = y
				break
	return last - first + 1 if first >= 0 else 0

func _green_pixels(image: Image) -> int:
	var count: int = 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			if color.a >= 0.5 and color.g > color.r * 1.2 and color.g > color.b * 1.1: count += 1
	return count
