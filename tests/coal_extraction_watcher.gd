extends Node
const Journey := preload("res://scripts/world/london_journey.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Model := preload("res://scripts/core/coal_extraction.gd")
const Driver := preload("res://tests/coal_extraction_driver.gd")
const Board := preload("res://scripts/puzzles/mining_workshop_board.gd")
const Art := preload("res://scripts/world/mine_art.gd")
const BACKUP := "user://coal_extraction_backup.json"
var scene: Control
var checks: int = 0
var failures: Array[String] = []

func begin() -> void:
	if "--restore-coal" in OS.get_cmdline_user_args():
		_restore_files()
		get_tree().quit()
	elif "--read-coal" in OS.get_cmdline_user_args(): await _read()
	else: await _write()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _switch(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	for frame in 4: await get_tree().process_frame

func _freeze() -> void:
	scene = get_tree().current_scene
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.application_focused = true
	scene.iron_popup.set_process(false)
	scene._update_modal_feedback()

func _resume() -> void:
	if scene.dialogue.visible: scene._close_dialogue()
	scene.application_focused = true
	scene._update_modal_feedback()

func _shot(label: String) -> void:
	if not "--capture-ui" in OS.get_cmdline_user_args(): return
	scene.coal_view.board.queue_redraw()
	for frame in 4: await get_tree().process_frame
	scene.application_focused = true
	scene._update_modal_feedback()
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/ui/mining_workshop"))
	get_viewport().get_texture().get_image().save_png("res://output/ui/mining_workshop/%s.png" % label)

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
	GameState.coins = 77
	Journey.ensure().arrived = true
	Journey.ensure().elapsed = 9.5
	await _switch(GameState.PHASE_TWO_SCENE)
	_freeze()
	scene.iron.data.stage = 1
	scene.iron.data.started = true
	scene.iron.data.route = 3
	scene._set_area("mine_face", Vector2(660, Art.FLOOR_Y))
	_check(scene.backdrop.texture == Art.EXTRACTION, "Workshop entry retains the separate right-hand gallery")
	_check(scene.player.scale.is_equal_approx(Vector2.ONE * Art.HERO_SCALE), "Gallery hero retains tunnel proportions")
	scene._interact("vein")
	var view: Control = scene.coal_view
	var model: Model = view.model
	_check(view.is_open() and scene._blocked() and model.step() == 0, "E opens step one and stops background movement")
	await _shot("01_reconocer")
	Driver.key(scene, KEY_SPACE)
	_check(bool(model.data.recognised[0]), "Keyboard marks the selected shiny coal vein")
	Driver.touch(view, Board.SPOTS[3], Board.SPOTS[3])
	_check(scene.dialogue.visible and Campaign.remaining() == 14, "Mistaking slate for coal uses the shared review")
	_check(bool(model.data.recognised[0]) and view.paused, "Review preserves accepted inspection and pauses the workshop")
	await _shot("01_revision")
	_resume()
	Driver.work_step(scene)
	Driver.key(scene, KEY_ENTER)
	_check(model.step() == 1 and not view.paused, "Confirm advances inspection to supports")
	await _shot("02_puntales")
	Driver.touch(view, view.board.support_stock(0).get_center(), Vector2(50, 60))
	_check(model.data.supports == [-1, -1, -1] and Campaign.remaining() == 14, "Dropping a support outside its slots cancels without penalty")
	for index in 3: model.place_support(index, index)
	view.confirm()
	_check(model.step() == 1 and scene.dialogue.visible, "Incorrect support geometry is reviewed before extraction")
	_check(model.data.supports == [0, 1, 2], "Review does not erase installed supports")
	_resume()
	# Unique replacement must leave displaced pieces available, including keyboard use.
	model.remove_support(0)
	model.remove_support(1)
	view.board.selected = 0
	Driver.key(scene, KEY_2)
	Driver.key(scene, KEY_SPACE)
	view.board.selected = 1
	Driver.key(scene, KEY_1)
	Driver.key(scene, KEY_SPACE)
	_check(model.data.supports == Model.SUPPORT_ORDER, "Keyboard places distinct matching supports without duplicates")
	Driver.touch(view, Board.SUPPORT_SLOTS[1].get_center(), Board.SUPPORT_SLOTS[0].get_center())
	_check(model.data.supports == [0, -1, 2], "Dragging an installed brace moves it rather than duplicating it")
	Driver.touch(view, Board.SUPPORT_SLOTS[0].get_center(), Board.SUPPORT_SLOTS[1].get_center())
	view.board.selected = 0
	Driver.key(scene, KEY_2)
	Driver.key(scene, KEY_SPACE)
	_check(model.data.supports == Model.SUPPORT_ORDER, "Displaced braces remain available to complete the puzzle")
	view.confirm()
	_check(model.step() == 2, "Safe supports unlock extraction")
	Driver.key(scene, KEY_SPACE)
	Driver.key(scene, KEY_SPACE)
	_check(int(model.data.damage[0]) == 1, "Rapid hits wait for recovery instead of consuming opportunities")
	scene._process(0.7)
	Driver.touch(view, Board.VEINS[0], Board.VEINS[0])
	_check(int(model.data.damage[0]) == 2, "Touch on a crack delivers the second blow")
	await _shot("03_extraer")
	scene._process(0.7)
	Driver.key(scene, KEY_SPACE)
	Driver.key(scene, KEY_RIGHT)
	_check(int(model.data.damage[0]) == 3 and view.board.selected == 0, "The trolley stays below the vein until the coal finishes falling")
	scene._process(0.9)
	Driver.work_step(scene)
	_check(model.data.damage == [3, 3, 3] and not GameState.has_item("costal_carbon"), "Nine separated blows finish the veins without early reward")
	view.confirm()
	_check(model.step() == 3, "Completed falls unlock the sorting bench")
	await _shot("04_separar")
	Driver.touch(view, Board.FRAGMENTS[0], Board.COAL_BIN.get_center())
	Driver.touch(view, Board.FRAGMENTS[1], Board.COAL_BIN.get_center())
	_check(scene.dialogue.visible and int(model.data.collected) == 4, "Wrong sorting preserves the correctly separated coal")
	_resume()
	Driver.work_step(scene)
	view.confirm()
	_check(model.step() == 4 and int(model.data.collected) == 12, "Six sorted pieces unlock weighing")
	await _shot("05_equilibrar")
	for index in 8: model.assign_piece(index, 0)
	view.confirm()
	_check(scene.dialogue.visible and model.step() == 4 and model.bag_mass(0) == 12, "Unequal sacks prompt redistribution without losing material")
	_resume()
	for bag_index in 4: model.empty_bag(bag_index)
	Driver.work_step(scene)
	_check(model.bags() == 4 and not GameState.has_item("costal_carbon"), "Balanced work sacks remain pending until delivery")
	# Closing/reopening preserves the exact step and weight assignments.
	var assignments: Array = model.data.assignments.duplicate()
	# Tab can focus the exit button; Enter must activate it instead of confirming.
	var back: Button
	for child in view.get_children():
		if child is Button and child.text == "Volver al escenario": back = child
	back.grab_focus()
	Driver.key(scene, KEY_ENTER)
	_check(not view.is_open(), "Focused exit button works with keyboard Enter")
	scene._interact("vein")
	model = view.model
	_check(model.step() == 4 and model.data.assignments == assignments, "Returning to the workshop preserves weighing progress")
	view.confirm()
	_check(model.step() == 5, "Balanced sacks unlock the rail puzzle")
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = view.board.rail_stock(0).get_center() * view.board.size / Board.NATIVE
	view.board._gui_input(press)
	var other := InputEventScreenTouch.new()
	other.index = 1
	other.pressed = true
	other.position = Board.SWITCHES[0].get_center() * view.board.size / Board.NATIVE
	view.board._gui_input(other)
	_check(view.board.touch_id == 0 and model.data.switches == [0, 1], "A second finger cannot steal an active rail drag")
	scene._show_inventory()
	_check(view.board.drag == -1 and view.board.touch_id == -1, "Opening inventory releases the captured finger and rail")
	scene.hud._close_inventory()
	scene._update_modal_feedback()
	await _shot("06_vias")
	Driver.work_step(scene)
	model.toggle_switch(0)
	view.confirm()
	_check(not bool(model.data.travelling) and scene.dialogue.visible, "A wrong switch blocks unsafe transport")
	_resume()
	model.toggle_switch(0)
	view.confirm()
	_check(bool(model.data.travelling), "Connected rails and both correct switches start transport")
	scene._process(2.25)
	var clock := float(model.data.route_time)
	var at := model.cart_position()
	await _shot("06_transporte")
	if "--capture-ui" in OS.get_cmdline_user_args():
		# Inspect both bends without changing the checkpoint tested below.
		for sample in [3.35, 3.75, 4.5]:
			model.data.route_time = sample
			await _shot("06_curva_%s" % str(sample).replace(".", "_"))
		model.data.route_time = clock
		view.board.queue_redraw()
	view.pointer_down(Driver.view_point(view, Vector2(200, 300)))
	scene._show_inventory()
	scene._process(20)
	_check(view.paused and view.board.drag == -1, "Inventory cancels gestures and pauses the workshop")
	_check(is_equal_approx(float(model.data.route_time), clock) and model.cart_position().is_equal_approx(at), "Inventory freezes the actual transport position and timer")
	scene.hud._close_inventory()
	scene._update_modal_feedback()
	scene.application_focused = false
	scene._process(20)
	_check(is_equal_approx(float(model.data.route_time), clock), "Focus loss freezes transport")
	scene.application_focused = true
	scene._update_modal_feedback()
	scene._show_journal()
	scene._process(20)
	_check(view.paused and is_equal_approx(float(model.data.route_time), clock), "Journal freezes transport before saving")
	GameState.save_progress()
	print("MINING WORKSHOP WRITE: %d checks, %d failures" % [checks, failures.size()])
	if not failures.is_empty(): _restore_files()
	get_tree().quit(0 if failures.is_empty() else 1)

func _read() -> void:
	_check(GameState.continue_saved_game(), "Continue reloads the saved chapter")
	await get_tree().scene_changed
	for frame in 4: await get_tree().process_frame
	_freeze()
	var view: Control = scene.coal_view
	var model: Model = view.model
	_check(scene.area == "mine_face" and view.is_open() and model.step() == 5, "Continue returns to the exact workshop step")
	_check(scene.journal_overlay.visible and view.paused, "Saved journal remains open and pauses transport")
	_check(bool(model.data.travelling) and is_equal_approx(float(model.data.route_time), 2.25), "Process restart retains transport time exactly")
	_check(model.data.rails == Model.RAIL_ORDER and model.data.switches == Model.SWITCH_ORDER and model.bags() == 4, "Rail positions, switches and balanced sacks survive restart")
	_check(view.board.drag == -1 and view.active_touch == -1, "Continue never restores a live drag")
	_check(GameState.coins == 77 and not GameState.has_item("costal_carbon"), "Pending shipment neither changes coins nor grants early sacks")
	scene._hide_journal()
	scene._process(3.1)
	_check(view.is_open() and not GameState.has_item("costal_carbon"), "Shipment remains pending until reaching the elevator")
	scene._process(0.2)
	_resume()
	_check(scene.iron.stage() == 2 and GameState.has_item("costal_carbon", 4) and not view.is_open(), "Arrival grants exactly four real sacks and unlocks engine assembly")
	_check(not GameState.has_item("hulla"), "Delivered sacks do not also grant a duplicate loose-coal reward")
	_check(Campaign.done("mine") and GameState.phase_two.glossary.any(func(entry): return entry.id == "hulla"), "Sack delivery still records mine completion and coal knowledge")
	_check(not model.hit() and not model.confirm(), "Completed workshop rejects further work")
	model.advance(20)
	_check(int(GameState.inventory.get("costal_carbon", 0)) == 4, "Extra clock advances cannot duplicate the shipment")
	# Migrate accepted work from both released extraction formats without issuing rewards.
	scene.iron.data.stage = 1
	scene.iron.data.extraction = {"version": 1, "ties": 0, "done": false}
	scene.iron.data.hits = 2
	scene.iron.data.sorted = [0, 1]
	var legacy := Model.new(scene.iron)
	_check(int(legacy.data.version) == 3 and int(legacy.data.collected) == 4 and int(legacy.data.damage[0]) == 3, "Legacy picking and sorting migrate without erasing accepted coal")
	scene.iron.data.extraction = {"version": 2, "damage": [3, 3, 3], "collected": 12, "done": false}
	legacy = Model.new(scene.iron)
	_check(legacy.step() == 5 and legacy.bags() == 4 and not bool(legacy.data.done), "Full former wagon loads migrate to the final delivery puzzle")
	_check(int(GameState.inventory.get("costal_carbon", 0)) == 4, "Migration never issues an additional shipment")
	scene.iron.data.extraction = {"version": 2, "damage": [0, 0, 0], "collected": 0, "done": false}
	scene.iron.data.hits = 0
	scene.iron.data.sorted = []
	legacy = Model.new(scene.iron)
	_check(legacy.step() == 0 and legacy.data.recognised == [false, false, false], "Unworked former saves start at inspection rather than skipping two steps")
	# Exhausted rounds retain approved workshop progress while renewing the shared budget.
	scene.iron.data.extraction = {}
	scene.iron.data.hits = 0
	scene.iron.data.sorted = []
	scene.coal_view.open(scene.iron)
	model = view.model
	model.recognise(0)
	for index in Campaign.remaining():
		model.recognise(3)
		_resume()
	_check(bool(model.data.recognised[0]) and model.step() == 0 and Campaign.remaining() == Campaign.total(), "A renewed opportunity round preserves approved inspection")
	# Repair already released saves without changing the purse, sacks or accepted work.
	GameState.inventory["hulla"] = 1
	GameState.save_progress()
	_check(GameState.load_progress() and not GameState.has_item("hulla"), "Loading a former shipment removes the obsolete loose-coal reward")
	_check(GameState.coins == 77 and int(GameState.inventory.get("costal_carbon", 0)) == 4 and bool(GameState.phase_two.iron_mission.extraction.recognised[0]), "Inventory repair preserves coins, exact sack count and workshop progress")
	var repaired_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(not repaired_save.inventory.has("hulla") and GameState.phase_two.glossary.any(func(entry): return entry.id == "hulla"), "Repair persists to disk and retains coal knowledge")
	GameState.inventory.erase("costal_carbon")
	GameState.inventory["hulla"] = 1
	GameState.save_progress()
	_check(GameState.load_progress() and not GameState.has_item("hulla") and not GameState.has_item("costal_carbon"), "Repair also removes obsolete rewards after fuel consumption without replenishing sacks")
	GameState.restart_phase_two()
	await get_tree().scene_changed
	for frame in 4: await get_tree().process_frame
	_check(GameState.coins == 87 and not GameState.has_item("costal_carbon"), "Restart restores entry coins and removes phase-two sacks")
	_check(not GameState.phase_two.has("iron_mission"), "Restart clears all workshop steps with the rest of phase two")
	_check(Campaign.reward("mine") and GameState.has_item("hulla"), "Reserved legacy workshops retain their original reward behavior")
	_check(GameState.load_progress() and GameState.has_item("hulla"), "Loading legacy workshop inventory without a sack delivery preserves its coal")
	_restore_files()
	print("MINING WORKSHOP READ: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _restore_files() -> void:
	if not FileAccess.file_exists(BACKUP): return
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
