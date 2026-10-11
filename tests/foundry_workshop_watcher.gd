extends Node
const EngineHouse := preload("res://scripts/world/engine_house_art.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Journey := preload("res://scripts/world/london_journey.gd")
const Model := preload("res://scripts/core/foundry_workshop.gd")
const Mission := preload("res://scripts/core/iron_mission.gd")
const Art := preload("res://scripts/world/foundry_art.gd")
const Driver := preload("res://tests/foundry_workshop_driver.gd")
const Board := preload("res://scripts/puzzles/foundry_workshop_board.gd")
const BACKUP := "user://foundry_workshop_backup.json"
var scene: Control
var checks := 0
var failures: Array[String] = []

func begin() -> void:
	if "--restore-workshop" in OS.get_cmdline_user_args():
		_restore_files()
		get_tree().quit()
	elif "--read-workshop" in OS.get_cmdline_user_args(): await _read()
	else: await _write()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("FOUNDRY WORKSHOP: " + message)

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

func _shot(name: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args(): return
	await _settle()
	RenderingServer.force_draw(false)
	var directory := "res://output/ui/foundry_workshop_v2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")

func _write() -> void:
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	FileAccess.open(BACKUP, FileAccess.WRITE).store_string(JSON.stringify(backups))
	for difficulty in ["facil", "dificil"]:
		await _switch("res://scenes/ui/main_menu.tscn")
		GameState.reset_progress(false)
		GameState.difficulty = difficulty
		GameState.run_started = true
		GameState.phase_complete = true
		GameState.coins = 87
		GameState.ensure_phase_two_entry()
		GameState.inventory.costal_carbon = 4
		var arrival := Journey.ensure()
		arrival.arrived = true
		arrival.elapsed = 9.5
		await _switch(GameState.PHASE_TWO_SCENE)
		_freeze()
		scene.iron.data.stage = 2
		scene.iron.data.batch_issued = true
		scene._set_area("forge_hall", Art.CORT_POSITION + Vector2(-65, 18))
		scene._interact("cort")
		scene._close_dialogue()
		var view: Control = scene.foundry_view
		var model: Model = view.model
		_check(view.is_open() and model.step() == 0 and scene._blocked(), "Cort opens the interactive workbench")
		await _shot(difficulty + "_01_hierro")
		Driver.touch(scene, Board.billet_rect(0).get_center(), Board.GAUGE.get_center())
		Driver.key(scene, KEY_ENTER)
		_check(model.step() == 0 and Campaign.remaining() == Campaign.total(), "Unmeasured loose stock cannot advance or lose opportunities")
		Driver.key(scene, KEY_R)
		Driver.key(scene, KEY_C)
		for code in [KEY_Q, KEY_E]:
			Driver.press(scene, code, true)
			scene._process(1.5)
			Driver.press(scene, code, false)
		Driver.key(scene, KEY_ENTER)
		_check(scene.dialogue_kind == "forge_review" and view.paused and Campaign.remaining() == Campaign.total() - 1, "Measured wrong stock is reviewed once")
		var remaining := Campaign.remaining()
		scene._process(20)
		model.confirm()
		_check(Campaign.remaining() == remaining and model.step() == 0, "Review freezes tools and repeated penalties")
		scene._return_home()
		await get_tree().scene_changed
		await _settle()
		_check(GameState.continue_saved_game(), "Menu Continue resumes a workshop review")
		await get_tree().scene_changed
		await _settle()
		_freeze()
		view = scene.foundry_view
		model = view.model
		_check(view.is_open() and view.paused and model.data.measured == [true, true] and Campaign.remaining() == remaining, "Measurements and budget survive menu roundtrip")
		scene._close_dialogue()
		Driver.work_step(scene)
		_check(model.step() == 1, "Measured and clamped correct billet advances")
		Driver.key(scene, KEY_SPACE)
		scene._process(1.0)
		_check(float(model.data.heat_zones[1]) > float(model.data.heat_zones[0]), "Position independently heats the middle before the ends")
		var heat: Array = model.data.heat_zones.duplicate()
		scene._show_inventory()
		scene._process(3)
		_check(model.data.heat_zones == heat, "Inventory pauses every heat zone")
		scene.hud._close_inventory()
		scene._update_modal_feedback()
		scene.application_focused = false
		scene._process(3)
		_check(model.data.heat_zones == heat, "Focus loss pauses the furnace")
		scene.application_focused = true
		view.toggle_help()
		scene._process(3)
		_check(model.data.heat_zones == heat, "Optional Cort help pauses workshop simulation")
		view.toggle_help()
		await _shot(difficulty + "_02_horno")
		await _verify_heat_fix(view, difficulty)
		var heat_budget := Campaign.remaining()
		Driver.work_step(scene)
		_check(model.step() == 2 and GameState.has_item("costal_carbon", 4) and Campaign.remaining() == heat_budget, "Approved heat advances with Continue without penalty or consuming player coal")
		Driver.key(scene, KEY_SPACE)
		_check(model.data.strikes == [0, 0, 0], "Hammer requires a mounted die")
		Driver.touch(scene, Board.die_rect(0).get_center(), Vector2(580, 410))
		view.board.pointer_down(Vector2(975, 310))
		view.board.pointer_move(Vector2(975, 400))
		view.board.pointer_move(Vector2(975, 450))
		scene._process(1)
		view.board.pointer_move(Vector2(975, 460))
		_check(model.data.strikes == [1, 0, 0], "One lever pull gives only one blow even if held")
		view.board.pointer_up(Vector2(975, 460))
		Driver.key(scene, KEY_RIGHT)
		Driver.touch(scene, Vector2(580, 365), Vector2(735, 365))
		_check(int(model.data.zone) == 0 and bool(model.data.aligned), "Dragging iron snaps its small eye to the hammer stop")
		model.align_blank(75)
		Driver.key(scene, KEY_SPACE)
		_check(model.data.strikes == [1, 0, 0], "Misaligned blank blocks a damaging blow without penalty")
		Driver.key(scene, KEY_RIGHT)
		Driver.key(scene, KEY_SPACE)
		_check(scene.dialogue_kind == "forge_review" and model.data.strikes == [1, 0, 0], "Wrong matrix preserves previously shaped metal")
		scene._close_dialogue()
		await _shot(difficulty + "_03_martillo")
		Driver.work_step(scene)
		_check(model.step() == 3 and model.data.strikes == [2, 2, 2], "All three zones are forged using matched dies")
		Driver.key(scene, KEY_C)
		Driver.key(scene, KEY_1)
		Driver.key(scene, KEY_SPACE)
		_check(scene.dialogue_kind == "forge_review" and model.data.holes == [false, false], "Off-center drill cannot create a hole")
		scene._close_dialogue()
		view.board.pointer_down(Vector2(830, 550))
		view.board.pointer_move(Vector2(780, 550) + Vector2.from_angle(-1.4) * 50)
		view.board.pointer_up(Vector2(780, 550) + Vector2.from_angle(-1.4) * 50)
		_check(int(model.data.position) == 0, "Turning the physical screw aligns the small eye under the spindle")
		_check(view.board.drill_eyes()[0].is_equal_approx(Board.DRILL_AXIS), "Visible small-eye centre coincides exactly with spindle axis at first stop")
		model.move_jig(4)
		_check(view.board.drill_eyes()[1].is_equal_approx(Board.DRILL_AXIS), "Visible large-eye centre coincides exactly with spindle axis at last stop")
		model.move_jig(0)
		Driver.press(scene, KEY_SPACE, true)
		scene._process(0.5)
		_check(is_equal_approx(view.board.drill_tip().x, Board.DRILL_AXIS.x) and view.board.drill_tip().y >= Board.DRILL_AXIS.y and view.board.spindle_speed > 0, "Rotating bit remains in the chuck axis and physically touches the centred eye while cutting")
		await _shot(difficulty + "_04_perforando")
		Driver.press(scene, KEY_SPACE, false)
		var depth := float(model.data.depths[0])
		scene._process(2)
		_check(depth > 0 and is_equal_approx(float(model.data.depths[0]), depth) and not model.feed_held, "Releasing the drill preserves partial depth and stops cutting")
		await _shot(difficulty + "_04_taladro")
		model.move_jig(4)
		Driver.touch(scene, Vector2(1010, 565), Vector2(575, 285))
		Driver.press(scene, KEY_SPACE, true)
		scene._process(0.5)
		_check(model.feed_held and int(model.data.drilling) == 1 and view.board.drill_eyes()[1].is_equal_approx(Board.DRILL_AXIS), "Large bit also cuts at the actual large-eye centre")
		await _shot(difficulty + "_04_perforando_gruesa")
		Driver.press(scene, KEY_SPACE, false)
		scene._process(2)
		Driver.work_step(scene)
		_check(model.step() == 4 and model.data.holes == [true, true], "Pulse feed drills both eyes and retracts before moving")
		var budget := Campaign.remaining()
		Driver.touch(scene, view.board.piece_rect().get_center(), Board.TEMPLATE.get_center())
		_check(not bool(model.data.fitted) and int(model.data.interference) == 0 and Campaign.remaining() == budget, "Dry fit identifies interference without charging an opportunity")
		view.board.pointer_down(Vector2(280, 570))
		view.board.pointer_move(Vector2(140, 390))
		_check(int(model.data.filed[0]) == 0, "Backward repositioning does not count as filing")
		view.board.pointer_move(Vector2(200, 390))
		scene._process(0.2)
		view.board.pointer_move(Vector2(260, 390))
		_check(int(model.data.filed[0]) == 1, "One forward stroke removes one burr; continuing the same stroke does not spam")
		view.board.pointer_up(Vector2(260, 390))
		await _shot(difficulty + "_05_ajuste")
		Driver.work_step(scene)
		_check(model.step() == 5 and bool(model.data.fitted), "Finished surfaces fit the template")
		Driver.key(scene, KEY_E)
		model.place_pin(0, 1)
		model.place_pin(1, 0)
		Driver.key(scene, KEY_ENTER)
		_check(scene.dialogue_kind == "forge_review" and not bool(model.data.running), "Interchanged pins block the mechanism")
		scene._close_dialogue()
		var eyes: Array = view.board.mechanism_eyes()
		Driver.touch(scene, eyes[0], Vector2(660, 575))
		Driver.touch(scene, eyes[1], eyes[0])
		Driver.touch(scene, Vector2(830, 575), eyes[1])
		_check(model.data.pins == [0, 1], "Mouse-only correction can lift swapped pins and reinstall both")
		Driver.key(scene, KEY_ENTER)
		scene._process(8)
		_check(float(model.data.turns) == 0 and not GameState.has_item("biela"), "Confirm and elapsed time cannot run or reward the mechanism")
		Driver.press(scene, KEY_SPACE, true)
		for turn in 8: scene._process(1)
		Driver.press(scene, KEY_SPACE, false)
		_check(float(model.data.turns) == 3 and float(model.data.loaded_turns) == 0 and not GameState.has_item("biela"), "Three free turns still require one turn under load")
		var free_turns := float(model.data.turns)
		model.set_brake(1)
		Driver.press(scene, KEY_SPACE, true)
		scene._process(1)
		Driver.press(scene, KEY_SPACE, false)
		_check(is_equal_approx(float(model.data.turns), free_turns) and float(model.data.loaded_turns) == 0, "Excess brake stalls safely until loosened")
		model.set_brake(0.3)
		Driver.press(scene, KEY_SPACE, true)
		scene._process(1)
		Driver.press(scene, KEY_SPACE, false)
		var turns := float(model.data.turns)
		scene._process(4)
		_check(turns > 0 and is_equal_approx(float(model.data.turns), turns), "Holding turns the mechanism, releasing stops earned travel")
		await _shot(difficulty + "_06_transmision")
		await _verify_transmission_geometry(view, difficulty)
		_check(Phase2Metrics.report().taller_de_cort.etapa == 6, "Teacher report tracks the redesigned work")
		Driver.press(scene, KEY_SPACE, true)
		scene._show_journal()
		scene._process(4)
		_check(is_equal_approx(float(model.data.turns), turns) and not model.crank_held, "Journal cancels held crank and freezes trial")
		if difficulty == "dificil":
			GameState.save_progress()
			_check(bool(GameState.checkpoint.foundry_open) and bool(GameState.checkpoint.journal_open), "Save records open workshop and journal")
		else:
			scene._hide_journal()
			await _finish_and_deliver()
	if not failures.is_empty(): _restore_files()
	print("FOUNDRY WORKSHOP WRITE: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _verify_heat_fix(view: Control, difficulty: String) -> void:
	var model: Model = view.model
	var saved := model.data.duplicate(true)
	var remaining := Campaign.remaining()
	Driver.key(scene, KEY_T)
	_check(model.step() == 1 and model.allowed() and Campaign.remaining() == remaining and bool(model.data.heating), "Early removal is guidance only; it preserves the bar and opportunities")
	var ratio: Vector2 = view.board.size / Board.NATIVE
	var wheel := Vector2(945, 320)
	var radius: float = 87 * ratio.x
	_check(view.board.air_wheel_hit(wheel + Vector2(radius / ratio.x, 0)) and view.board.air_wheel_hit(wheel + Vector2(0, radius / ratio.y)), "Round wheel hit area includes equal screen radii horizontally and vertically")
	_check(not view.board.air_wheel_hit(wheel + Vector2(0, radius * 1.2 / ratio.y)), "Wheel hit area stops outside the visible circular rim")
	# Partial heat fixtures expose both jaw positions and wheel angles in native captures.
	for variant in 2:
		model.data.heat_zones = [0.78, 0.46, 0.80]
		model.data.heat_position = 0.25 if variant == 0 else 0.75
		model.data.air = 0.25 if variant == 0 else 0.75
		view._sync()
		await _shot(difficulty + "_02_pinza_" + str(variant + 1))
	# At the upper edge, a long frame used to overheat a successfully finished bar.
	model.data.heat_zones = [0.93, 0.93, 0.93] if model.easy else [0.88, 0.88, 0.88]
	model.data.air = 1.0
	model.data.ready_seconds = 0.0
	view.board.pointer_down(Vector2(420, 330))
	view.advance(5.0)
	_check(model.step() == 1 and bool(model.data.heat_approved) and model.allowed() and Campaign.remaining() == remaining, "Ready zones approve and stay in the furnace before any extra heat on a long frame")
	_check(view.board.drag.is_empty() and view.board.held_key == KEY_NONE and not bool(model.data.heating) and not view.confirm_button.disabled, "Approval releases tools, stops heating and enables Continue")
	var approved_zones: Array = model.data.heat_zones.duplicate()
	Driver.key(scene, KEY_SPACE)
	Driver.key(scene, KEY_UP)
	view.advance(30)
	_check(model.step() == 1 and model.data.heat_zones == approved_zones and Campaign.remaining() == remaining, "Waiting and tool input cannot overheat an approved bar or jump to forging")
	var durable: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(bool(durable.phase_two.foundry.heat_approved) and int(durable.phase_two.foundry.step) == 1 and not bool(durable.phase_two.foundry.heating), "Safe approved heat and pending Continue are saved durably")
	await _shot(difficulty + "_02_aprobado")
	view.confirm_button.pressed.emit()
	_check(model.step() == 2, "Continue button explicitly advances approved heat to forging")
	model.data.step = 1
	model.data.heat_approved = false
	view.advance(0.1)
	_check(model.step() == 1 and bool(model.data.heat_approved) and Campaign.remaining() == remaining, "Ready checkpoint restores safe approval and waits for Continue")
	# Continue the rest of the test from its genuine partially heated work.
	model.data.clear()
	model.data.merge(saved, true)
	model.feedback = ""
	model.update_hint()
	view._sync()

func _verify_transmission_geometry(view: Control, difficulty: String) -> void:
	var model: Model = view.model
	var angle := float(model.data.angle)
	var uniform: float = view.board.size.x / Board.NATIVE.x
	for sample in [0.0, PI / 2, PI, PI * 1.5]:
		model.data.angle = sample
		var eyes: Array = view.board.mechanism_eyes()
		var radius: Vector2 = (eyes[1] - Board.FLYWHEEL) * view.board.size / Board.NATIVE
		var link: Vector2 = (eyes[1] - eyes[0]) * view.board.size / Board.NATIVE
		_check(is_equal_approx(radius.length(), 62 * uniform) and is_equal_approx(link.length(), 260 * uniform), "Circular crank and constant-length link stay attached through quarter-turn " + str(sample))
		view._sync()
		if sample == PI / 2: await _shot(difficulty + "_06_articulacion")
	model.data.angle = angle
	view._sync()

func _finish_and_deliver() -> void:
	Driver.work_step(scene)
	_check(Campaign.done("forge") and GameState.has_item("biela") and scene.dialogue_kind == "forge_complete" and not scene.foundry_view.is_open(), "Manual trial grants one biela and Cort completion dialogue")
	scene.foundry_view.model.advance(20)
	_check(int(GameState.inventory.get("biela", 0)) == 1 and GameState.has_item("costal_carbon", 4) and GameState.coins == 87, "Repeated completion cannot duplicate rewards or spend coal and coins")
	scene._close_dialogue()
	scene._set_area("engine_room", EngineHouse.BENCH + Vector2(-50, 35))
	scene._interact("engine_bench")
	_check(scene.dialogue_kind == "motor_biela" and GameState.has_item("biela"), "Murdoch offers installation")
	scene._cancel_dialogue()
	_check(GameState.has_item("biela") and not bool(scene.iron.data.biela_installed), "Cancelling delivery keeps the link")
	scene._interact("engine_bench")
	scene._close_dialogue()
	_check(scene.iron_popup.is_open() and bool(scene.iron.data.biela_installed) and not GameState.has_item("biela"), "Delivery installs the finished link once")
	scene.iron_popup.close()

func _read() -> void:
	_check(GameState.continue_saved_game(), "Fresh process continues a partially hand-tested link")
	await get_tree().scene_changed
	await _settle()
	_freeze()
	var model: Model = scene.foundry_view.model
	_check(scene.area == "forge_hall" and scene.foundry_view.is_open() and scene.journal_overlay.visible, "Continue restores hall, workshop and journal")
	_check(model.step() == 5 and float(model.data.turns) > 0 and not model.crank_held and not bool(model.data.running), "Manual progress survives JSON; held inputs never do")
	_check(model.data.strikes == [2, 2, 2] and model.data.pins == [0, 1] and model.data.holes == [true, true], "Discrete identities survive JSON")
	_check(bool(model.data.heat_approved), "Furnace approval latch survives a fresh process")
	var turns := float(model.data.turns)
	scene._process(5)
	_check(is_equal_approx(float(model.data.turns), turns) and scene.foundry_view.board.drag.is_empty(), "Restored journal freezes progress and gestures")
	scene._hide_journal()
	await _finish_and_deliver()
	var original: Dictionary = GameState.phase_two.duplicate(true)
	GameState.phase_two.foundry = {"version": 1, "step": 3, "strikes": [2, 2, 2], "holes": [true, false], "drilling": 1, "drill_clock": 0.6}
	var legacy := Model.new()
	_check(legacy.step() == 3 and legacy.data.holes == [true, false] and legacy.data.depths == [1.0, 0.5] and not legacy.feed_held, "Version 1 full and partial drill depths migrate without unattended input")
	GameState.phase_two.foundry = {"version": 1, "step": 5, "link": true, "pins": [0, 1], "test_seconds": 2.5, "running": true}
	legacy = Model.new()
	_check(is_equal_approx(float(legacy.data.turns), 1.5) and not bool(legacy.data.running) and not legacy.crank_held, "Old timed trial migrates its travel and requires manual continuation")
	GameState.phase_two.foundry = {"step": 2, "strikes": [2, 1, 0]}
	var exhausted := Model.new()
	GameState.phase_two.spent = Campaign.total() - 1
	exhausted.fail("Shared budget test")
	_check(Campaign.remaining() == 0 and exhausted.data.strikes == [2, 1, 0], "Exhausting shared budget preserves shaped metal")
	exhausted.resume()
	_check(Campaign.remaining() == Campaign.total() and exhausted.data.strikes == [2, 1, 0], "New round restores budget without resetting work")
	GameState.phase_two = original.duplicate(true)
	GameState.phase_two.erase("foundry")
	var completed_legacy := Model.new()
	_check(bool(completed_legacy.data.done) and bool(completed_legacy.data.reward_issued) and not GameState.has_item("biela"), "Older completed forge does not reissue its consumed reward")
	GameState.phase_two = original
	GameState.restart_phase_two()
	await get_tree().scene_changed
	await _settle()
	_check(GameState.coins == 87 and not GameState.phase_two.has("foundry") and not GameState.has_item("biela") and not GameState.has_item("costal_carbon") and GameState.phase_complete, "Restart clears chapter two and restores entry money")
	_restore_files()
	print("FOUNDRY WORKSHOP READ: %d checks, %d failures" % [checks, failures.size()])
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
