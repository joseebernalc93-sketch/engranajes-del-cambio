extends Node
var popup: Node
var failures: Array[String] = []
var backups: Dictionary = {}
var dialogue: Dictionary = {}
var capture_ui := false
var demo := false


func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	GameState.set_difficulty(GameState.DIFFICULTY_HARD)
	GameState.reset_progress(false)
	capture_ui = capture_ui or "--capture-ui" in OS.get_cmdline_user_args()
	demo = demo or "--demo" in OS.get_cmdline_user_args()
	var yard = preload("res://scenes/wheelwright_yard.tscn").instantiate()
	get_tree().root.add_child(yard)
	get_tree().current_scene = yard
	await get_tree().process_frame
	popup = yard.get_node("WheelwrightForgePopup")
	popup.set_process(false)
	EventBus.dialogue_requested.connect(func(payload): dialogue = payload)
	GameState.interact("wheelwright")
	_check(dialogue.options[0].action == "begin_wheelwright_forge", "Mateo must accept the original tools")
	yard.get_node("HUD")._select_dialogue_action("begin_wheelwright_forge")
	var player: Node = yard.get_node("World/Player")
	_check(popup.overlay.visible and not player.controls_enabled and popup.forge_stage == popup.STAGE_ASSEMBLE, "The six-stage puzzle must begin at assembly with movement locked")
	_check(GameState.flags.tools_given_to_mateo and not GameState.has_item("herramientas"), "The handed-in iron must remain with Mateo")
	_check(GameState.flags.forge_attempts_left == 10 and popup.attempts_label.text == "Oportunidades: 10 / 10", "The workshop must begin with one shared pool of ten opportunities")
	await _capture("assembly")
	popup.piece_angles[3] = 3
	popup.place_part(3, 3)
	# Incorrect orientation is a confirmed placement error; pointer motion alone is safe.
	popup.place_part(0, 0)
	_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 9, "A bad placement must consume one attempt and display its cause")
	popup.place_part(0, 0)
	_check(GameState.flags.forge_attempts_left == 9, "A locked failure must not consume duplicate opportunities")
	await _capture("retry_explanation")
	popup.retry_button.pressed.emit()
	_check(popup.forge_stage == popup.STAGE_ASSEMBLE and popup.parts_placed[3], "Retry must preserve a correctly installed part in the current assembly")
	popup._confirm_assembly()
	_check(GameState.flags.forge_attempts_left == 8, "Confirming an unsecured assembly must consume only one opportunity")
	popup.close()
	_check(GameState.load_progress() and GameState.flags.forge_attempts_left == 8, "Closing and save/load must preserve remaining attempts")
	popup.open()
	_check(GameState.flags.forge_attempts_left == 8 and popup.parts_placed[3], "Reopening must retain both the installed part and the spent opportunities")
	await _assemble_and_heat()
	await _capture("heat_stable")
	await _capture("precision_rivets")
	await _finish_rivets()
	_check(popup.forge_stage == popup.STAGE_COOL and not GameState.has_item("rueda_dentada"), "Twelve real impacts must lead to regulated cooling")
	popup.ventilation_strength = 100
	await _step(2.1)
	var failed_heat: float = popup.heat
	_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 5, "Cooling must use the same opportunities already spent in assembly, heat and riveting")
	popup.retry_button.pressed.emit()
	_check(popup.forge_stage == popup.STAGE_COOL and popup.heat == failed_heat and popup.rivet_hits == [3, 3, 3, 3], "A cooling retry must retain completed rivets and cooling progress")
	await _capture("cooling")
	await _cool_and_center()
	await _proof()
	_check(popup.forge_stage == popup.STAGE_COMPLETE and GameState.has_item("rueda_dentada"), "All six stages must award one wheel")
	_check(GameState.metrics.forge_hammer_actions == 12 and GameState.build_report().intentos_fallidos_fragua == 7 and GameState.flags.forge_attempts_left == 3, "Seven failures across six stages must consume the same ten-opportunity pool without discarding successful impacts")
	await _capture("complete")
	var previous_size: Vector2i = get_viewport().size
	var previous_content: Vector2i = get_window().content_scale_size
	get_window().content_scale_size = Vector2i(640, 360)
	get_viewport().size = Vector2i(640, 360)
	await get_tree().process_frame
	popup._fit_panel()
	var top_left: Vector2 = popup.panel.get_global_transform() * Vector2.ZERO
	var bottom_right: Vector2 = popup.panel.get_global_transform() * popup.panel.size
	_check(top_left.x >= -0.1 and top_left.y >= -0.1 and bottom_right.x <= 640.1 and bottom_right.y <= 360.1, "All six stages and controls must fit a small viewport")
	await _capture("small_window")
	get_viewport().size = previous_size
	get_window().content_scale_size = previous_content
	popup.close()
	_check(player.controls_enabled, "Closing a successful workshop must restore movement")
	_check(GameState.install_mill_part("rueda_dentada"), "The wheel must still install in the existing mill")
	popup.open()
	_check(popup.forge_stage == popup.STAGE_COMPLETE and not GameState.has_item("rueda_dentada"), "Reopening a completed workshop must not duplicate the installed wheel")
	popup.close()
	if not demo:
		await _exhaustion(yard)
		await _hazards_and_cancellation()
		await _legacy_save()
		await _difficulty_modes()
	_restore()
	if failures.is_empty(): print("FORGE CHALLENGE TEST OK: hard/easy menu and persistence, 10/15 shared opportunities, slower easy gauges, safe wrong-side touches, timing-only strike penalties, same-phase recovery, exhaustion/new round, one wheel and old-save migration")
	get_tree().quit(0 if failures.is_empty() else 1)


func _assemble_and_heat() -> void:
	for index in range(4):
		if popup.parts_placed[index]: continue
		popup.selected_piece = index
		while popup.piece_angles[index] != index: popup.rotate_part(1)
		# Real mouse/touch drag from the tray onto the numbered wheel position.
		if index % 2 == 0:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = popup.challenge.TRAY[index]
			click.pressed = true
			popup.challenge._gui_input(click)
			var motion := InputEventMouseMotion.new()
			motion.position = popup.challenge.target(index)
			popup.challenge._gui_input(motion)
			click.position = motion.position
			click.pressed = false
			popup.challenge._gui_input(click)
		else:
			var touch := InputEventScreenTouch.new()
			touch.position = popup.challenge.TRAY[index]
			touch.pressed = true
			popup.challenge._gui_input(touch)
			var drag := InputEventScreenDrag.new()
			drag.position = popup.challenge.target(index)
			popup.challenge._gui_input(drag)
			touch.position = drag.position
			touch.pressed = false
			popup.challenge._gui_input(touch)
		await _step(0.15)
	_check(popup.parts_placed.all(func(part): return part), "Mouse/touch dragging must install all four correctly oriented pieces")
	popup.assembly_group.get_child(3).button_down.emit()
	await _step(3.3)
	popup.assembly_group.get_child(3).button_up.emit()
	_check(popup.clamps.min() >= 1, "Both independently tightened clamps must secure the assembly")
	popup._confirm_assembly()
	_check(GameState.flags.forge_attempts_left == 8, "A successful phase must not refill the shared pool")
	popup._set_heat(100)
	popup.seconds_since_pump = 0
	await _step(2.1)
	_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 7, "Overheating must consume one shared opportunity")
	popup.retry_button.pressed.emit()
	_check(popup.forge_stage == popup.STAGE_HEAT and popup.parts_placed.all(func(part): return part) and popup.clamps.min() >= 1, "A heat retry must stay in heat and preserve the secured assembly")
	# Recovery leaves the iron in the work band; mounting is already completed.
	await _capture("heat")
	await _step(2.1)
	_check(popup.forge_stage == popup.STAGE_RIVET, "Recovered heat must unlock riveting without mounting again")


func _finish_rivets() -> void:
	for index in popup.strike_order:
		popup._turn_to_next()
		await _wait(0.76)
		for hit in range(3):
			if popup.heat < 78:
				await _step(0.7)
				popup._pump_bellows()
			var safety := 0
			while (popup.precision_value() < 0.40 or popup.precision_value() > 0.60) and safety < 240:
				await _step(0.025)
				safety += 1
			popup._strike_rivet(index)
			_check(popup.rivet_hits[index] == hit, "The rivet must flatten only at the physical hammer impact")
			await _wait(0.43)
			_check(popup.rivet_hits[index] == hit + 1, "A correctly timed impact must flatten one rivet head")
			if index == 0 and hit == 0:
				popup.precision_time = PI / 4.8
				popup._strike_rivet(0)
				_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 6, "A badly timed strike must consume exactly one opportunity")
				popup.retry_button.pressed.emit()
				_check(popup.forge_stage == popup.STAGE_RIVET and popup.rivet_hits[0] == 1 and popup.parts_placed.count(true) == 4, "A riveting retry must preserve the first valid impact and all prior phases")
	# Close during the final impact's transition: validated work must still advance.
	popup.close()
	popup.open()
	_check(popup.forge_stage == popup.STAGE_COOL and popup.rivet_hits == [3, 3, 3, 3], "Reopening after the last impact must preserve all hits and continue to cooling")
	await _wait(0.25)


func _cool_and_center() -> void:
	var ticks := 0
	while popup.forge_stage == popup.STAGE_COOL and not popup.action_locked and ticks < 500:
		popup.cooling_slider.value = clampf((popup.cooling_target() - 2) / 0.15, 0, 100)
		await _step(0.05)
		ticks += 1
	popup.close()
	popup.open()
	await _wait(0.6)
	_check(popup.forge_stage == popup.STAGE_CENTER and popup.cooling_verified, "Uniform cooling must unlock the centering tools")
	await _capture("centering")
	for index in range(3):
		popup.center_group.get_child(index).pressed.emit()
		_check(popup.selected_screw == index, "Each centering selector must address its own screw")
	# Keyboard adjusts the first screw; mouse and touch adjust the other two.
	_key(KEY_1, true)
	_key(KEY_RIGHT, true)
	await _step((popup.SCREW_TARGETS[0] - popup.screws[0]) / 0.17)
	_key(KEY_RIGHT, false)
	popup._confirm_center()
	_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 4, "Confirming an incomplete axle must consume one shared opportunity")
	var corrected_screw: float = popup.screws[0]
	popup.retry_button.pressed.emit()
	_check(popup.forge_stage == popup.STAGE_CENTER and popup.screws[0] == corrected_screw and popup.cooling_verified, "An axle retry must preserve an already centered screw and completed cooling")
	for index in [1, 2]:
		var point: Vector2 = popup.challenge.screw_position(index)
		var destination := point + Vector2((popup.SCREW_TARGETS[index] - popup.screws[index]) * 140, 0)
		if index == 1:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = point
			click.pressed = true
			popup.challenge._gui_input(click)
			var motion := InputEventMouseMotion.new()
			motion.position = destination
			popup.challenge._gui_input(motion)
			click.position = destination
			click.pressed = false
			popup.challenge._gui_input(click)
		else:
			var touch := InputEventScreenTouch.new()
			touch.position = point
			touch.pressed = true
			popup.challenge._gui_input(touch)
			var drag := InputEventScreenDrag.new()
			drag.position = destination
			popup.challenge._gui_input(drag)
			touch.position = destination
			touch.pressed = false
			popup.challenge._gui_input(touch)
	_check(popup.center_error() <= 0.065, "All three independent screws must center the wheel")
	popup._confirm_center()
	_check(popup.forge_stage == popup.STAGE_TEST, "A verified axle must unlock the loaded crank test")


func _proof() -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = popup.workbench.CENTER
	touch.pressed = true
	popup.challenge._gui_input(touch)
	_check(popup.pointer_proof, "Touching the physical crank must start its drive")
	touch.pressed = false
	popup.challenge._gui_input(touch)
	_check(not popup.pointer_proof, "Releasing the crank must release its drive")
	var ticks := 0
	var tested_failure := false
	while popup.proof_checks < 3 and not popup.awaiting_retry and ticks < 1500:
		popup.pointer_proof = popup.wheel_speed < popup.proof_target()
		await _step(0.025)
		ticks += 1
		if ticks == 110: await _capture("loaded_crank")
		if popup.proof_checks == 1 and not tested_failure:
			tested_failure = true
			popup.wheel_speed = 2.8
			popup.pointer_proof = true
			await _step(1.4)
			_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 3, "Failing under the second load must use the existing pool rather than resetting it")
			var previous_turn: float = popup.proof_level_radians
			await _capture("load_retry")
			popup.retry_button.pressed.emit()
			_check(popup.forge_stage == popup.STAGE_TEST and popup.proof_checks == 1 and popup.proof_level_radians == previous_turn and popup.center_error() <= 0.065, "A load retry must preserve the first checked load, partial turn, axle and all preceding work")
			popup.close()
			_check(GameState.load_progress(), "Load-stage progress must be saved")
			popup.open()
			_check(popup.forge_stage == popup.STAGE_TEST and popup.proof_checks == 1 and popup.proof_level_radians == previous_turn and GameState.flags.forge_attempts_left == 3, "Closing and reloading must resume the current load without replenishing opportunities")
			await _capture("load_resumed")
	await _wait(0.75)


func _exhaustion(yard: Node) -> void:
	GameState.reset_progress(false)
	GameState.flags.tools_given_to_mateo = true
	popup.open()
	for error in range(10):
		if error == 9:
			# The same exhaustion rule also applies after all five preceding phases.
			popup.forge_stage = popup.STAGE_TEST
			popup.parts_placed = [true, true, true, true]
			popup.clamps = [1.0, 1.0]
			popup.rivet_index = 4
			popup.rivet_hits = [3, 3, 3, 3]
			popup.screws = popup.SCREW_TARGETS.duplicate()
			popup.cooling_verified = true
			popup.wheel_speed = 2.8
			popup.pointer_proof = true
			await _step(1.4)
		else:
			popup._confirm_assembly()
		_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 9 - error, "Every error must remove one opportunity until the tenth")
		popup._confirm_assembly()
		_check(GameState.flags.forge_attempts_left == 9 - error, "Repeated input during the error message must not count twice")
		if error < 9:
			popup.retry_button.pressed.emit()
			_check(popup.overlay.visible and popup.forge_stage == popup.STAGE_ASSEMBLE, "The first nine failures must allow same-phase continuation")
	await _wait(1.85)
	_check(not popup.overlay.visible and dialogue.text.contains("no te rindas") and not GameState.has_item("rueda_dentada"), "Only the tenth failure must close the workshop and show Mateo's encouragement")
	await _capture("mateo_encouragement")
	EventBus.wheelwright_forge_requested.emit()
	_check(not popup.overlay.visible and GameState.flags.forge_attempts_left == 0, "Opening directly must not bypass exhaustion")
	yard.get_node("HUD")._select_dialogue_action("restart_forge_round")
	_check(popup.overlay.visible and GameState.flags.forge_attempts_left == 10 and popup.forge_stage == popup.STAGE_ASSEMBLE and not popup.parts_placed.has(true), "Only Mateo's new round must refill ten opportunities and clear prior work")
	popup.close()


func _hazards_and_cancellation() -> void:
	for hazard in ["heat", "cooling", "centering", "speed"]:
		GameState.reset_progress(false)
		GameState.flags.tools_given_to_mateo = true
		popup.open()
		match hazard:
			"heat":
				popup.forge_stage = popup.STAGE_HEAT
				popup._set_heat(100)
				popup.seconds_since_pump = 0
				await _step(1.0)
				_check(not popup.awaiting_retry, "Thermal warnings must allow a correction interval")
				await _step(1.1)
			"cooling":
				popup.forge_stage = popup.STAGE_COOL
				popup._set_heat(85)
				popup.ventilation_strength = 100
				await _step(1.0)
				_check(not popup.awaiting_retry, "Cooling warnings must allow correction")
				await _step(1.1)
			"centering":
				popup.forge_stage = popup.STAGE_CENTER
				popup._confirm_center()
			"speed":
				popup.forge_stage = popup.STAGE_TEST
				popup.cooling_verified = true
				popup.wheel_speed = 2.8
				popup.pointer_proof = true
				await _step(1.4)
		var failed_stage: int = popup.forge_stage
		_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 9, "A confirmed %s hazard must consume one opportunity" % hazard)
		popup.retry_button.pressed.emit()
		_check(popup.forge_stage == failed_stage and not popup.awaiting_retry, "A %s hazard must resume the same phase" % hazard)
		await _step(0.25)
		_check(GameState.flags.forge_attempts_left == 9, "A %s retry must release held controls and clear its failure timer" % hazard)
		popup.close()
	# Closing while a hammer/timer is pending cannot alter the next visit.
	GameState.reset_progress(false)
	GameState.flags.tools_given_to_mateo = true
	popup.open()
	popup.forge_stage = popup.STAGE_RIVET
	popup._set_heat(85)
	popup.precision_time = 0
	popup._strike_rivet(0)
	popup.close()
	popup.open()
	await _wait(0.45)
	_check(popup.forge_stage == popup.STAGE_RIVET and popup.rivet_hits[0] == 0 and not popup.action_locked, "Reopening must retain the riveting phase but cancel an uncompleted hammer impact")
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var previous_heat: float = popup.heat
	await _step(3)
	_check(popup.heat == previous_heat and not popup.challenge.dragging_piece, "Losing focus must release tools and pause failure timers")
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	popup.close()


func _legacy_save() -> void:
	GameState.flags.wheelwright_forge_completed = true
	GameState.flags.mill_repaired = true
	GameState.flags.ticket_bought = true
	GameState.save_progress()
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	old.save_version = 8
	old.flags.erase("forge_attempts_left")
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	_check(GameState.load_progress() and GameState.flags.forge_attempts_left == 10 and GameState.flags.wheelwright_forge_completed and GameState.flags.mill_repaired and GameState.flags.ticket_bought, "Older completed puzzles and inventory must survive the expanded opportunity pool")
	for old_remaining in range(4):
		old.save_version = 9
		old.flags.forge_attempts_left = old_remaining
		var saved := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		saved.store_string(JSON.stringify(old))
		saved.close()
		_check(GameState.load_progress() and GameState.flags.forge_attempts_left == old_remaining + 7, "A version-nine save must receive seven extra opportunities while retaining already spent chances")
		_check(GameState.load_progress() and GameState.flags.forge_attempts_left == old_remaining + 7, "Loading a migrated save twice must not grant more opportunities")
	old.erase("difficulty")
	old.flags.erase("forge_attempts_spent")
	old.flags.forge_progress = {"stage": 3, "heat": 50.0, "rivet_hits": [3, 3, 3, 3]}
	for old_remaining in [0, 4, 10]:
		old.save_version = 10
		old.flags.forge_attempts_left = old_remaining
		var saved := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		saved.store_string(JSON.stringify(old))
		saved.close()
		_check(GameState.load_progress() and GameState.difficulty == GameState.DIFFICULTY_HARD and GameState.flags.forge_attempts_left == old_remaining and GameState.flags.forge_progress.stage == 3, "A version-ten save must retain its hard allowance and partial forge work")
		GameState.set_difficulty(GameState.DIFFICULTY_EASY)
		_check(GameState.flags.forge_attempts_left == old_remaining + 5, "Selecting easy on an older save must add only the five additional chances, preserving spent attempts")
		_check(GameState.load_progress() and GameState.flags.forge_attempts_left == old_remaining + 5, "Reloading an upgraded easy save must not refill its opportunity pool")
	GameState.set_difficulty(GameState.DIFFICULTY_HARD)


func _difficulty_modes() -> void:
	GameState.reset_progress(false)
	var menu = preload("res://scenes/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	menu._on_start_button_pressed()
	menu.difficulty_button.pressed.emit()
	_check(menu.difficulty_overlay.visible and menu.hard_button.button_pressed, "Difficulty must open a small selector showing the saved hard mode")
	menu.easy_button.pressed.emit()
	_check(not GameState.is_easy_difficulty(), "A pending selection must leave the current save untouched")
	menu._close_difficulty()
	GameState.set_difficulty(menu.pending_difficulty)
	_check(not menu.difficulty_overlay.visible and GameState.is_easy_difficulty() and GameState.flags.forge_attempts_left == 15, "Choosing Easy in the menu must grant fifteen opportunities")
	GameState.flags.tools_given_to_mateo = true
	popup.open()
	_check(popup.attempts_label.text == "Oportunidades: 15 / 15", "The easy workshop must show the selected pool")
	popup.forge_stage = popup.STAGE_RIVET
	popup._set_heat(85)
	popup.workbench.wheel_angle = 0
	popup.precision_time = PI / 4.8
	popup._strike_rivet(2)
	_check(not popup.awaiting_retry and GameState.flags.forge_attempts_left == 15 and popup.rivet_hits[2] == 0, "Touching the wrong side must be harmless even outside the green timing band")
	popup.precision_time = 0
	popup.workbench.wheel_angle = 0.6
	popup._strike_rivet(0)
	_check(not popup.awaiting_retry and GameState.flags.forge_attempts_left == 15, "An unaligned touch must guide the player without spending an opportunity")
	popup.workbench.wheel_angle = 0
	popup._set_heat(60)
	popup._strike_rivet(0)
	_check(not popup.awaiting_retry and GameState.flags.forge_attempts_left == 15, "A strike before the iron is ready must give guidance without spending a timing opportunity")
	popup._set_heat(85)
	popup._strike_rivet(0)
	popup._set_heat(60)
	await _wait(0.5)
	_check(popup.rivet_hits[0] == 0 and not popup.action_locked and GameState.flags.forge_attempts_left == 15, "Losing heat during the hammer animation must cancel the hit safely without penalizing timing")
	popup._set_heat(85)
	popup.precision_time = PI / 4.8
	popup._strike_rivet(0)
	_check(popup.awaiting_retry and GameState.flags.forge_attempts_left == 14, "A validly targeted strike outside green must spend exactly one easy opportunity")
	popup.retry_button.pressed.emit()
	popup.precision_time = 0
	popup._strike_rivet(0)
	await _wait(0.5)
	_check(popup.rivet_hits[0] == 1 and GameState.flags.forge_attempts_left == 14, "A corrected easy strike must count at impact without replenishing opportunities")
	var easy_window := _initial_green_window()
	popup.close()
	menu.difficulty_button.pressed.emit()
	menu.hard_button.pressed.emit()
	menu._close_difficulty()
	GameState.set_difficulty(menu.pending_difficulty)
	_check(GameState.flags.forge_attempts_left == 9, "Changing to hard must preserve the opportunity already spent")
	popup.open()
	_check(popup.forge_stage == popup.STAGE_RIVET and popup.rivet_hits[0] == 1, "Changing difficulty must retain the completed hit and current stage")
	var hard_window := _initial_green_window()
	_check(easy_window >= hard_window * 3, "The easy moving indicator must provide substantially more real time in green")
	popup.precision_time = PI / 4.8
	popup._strike_rivet(2)
	_check(not popup.awaiting_retry and GameState.flags.forge_attempts_left == 9, "Wrong-side touches must also be safe in hard mode")
	popup.close()
	menu.difficulty_button.pressed.emit()
	menu.easy_button.pressed.emit()
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	menu._unhandled_input(escape)
	_check(not menu.difficulty_overlay.visible and menu.start_button.focus_mode == Control.FOCUS_ALL, "Escape must dismiss the selector and restore menu keyboard navigation")
	GameState.set_difficulty(GameState.DIFFICULTY_EASY)
	_check(GameState.load_progress() and GameState.is_easy_difficulty() and GameState.flags.forge_attempts_left == 14 and GameState.flags.forge_progress.rivet_hits[0] == 1, "Difficulty, spent opportunities and partial work must persist together")
	# A depleted easy pool cannot be replenished by repeatedly changing modes.
	GameState.flags.forge_attempts_left = 0
	GameState.flags.forge_attempts_spent = 15
	GameState.set_difficulty(GameState.DIFFICULTY_HARD)
	GameState.set_difficulty(GameState.DIFFICULTY_EASY)
	_check(GameState.flags.forge_attempts_left == 0, "Switching modes must not refund previously spent opportunities")
	GameState.reset_progress(false)
	GameState.flags.tools_given_to_mateo = true
	popup.open()
	popup.forge_stage = popup.STAGE_HEAT
	popup._pump_bellows()
	_check(is_equal_approx(popup.heat, 7.5), "Easy bellows must raise the heat gradually")
	popup.forge_stage = popup.STAGE_TEST
	popup.wheel_speed = 0
	popup.pointer_proof = true
	await _step(0.5)
	var easy_speed: float = popup.wheel_speed
	popup.close()
	GameState.set_difficulty(GameState.DIFFICULTY_HARD)
	GameState.reset_progress(false)
	GameState.flags.tools_given_to_mateo = true
	popup.open()
	popup.forge_stage = popup.STAGE_HEAT
	popup._pump_bellows()
	_check(is_equal_approx(popup.heat, 15.0), "Hard bellows must keep their original behavior")
	popup.forge_stage = popup.STAGE_TEST
	popup.wheel_speed = 0
	popup.pointer_proof = true
	await _step(0.5)
	_check(is_equal_approx(popup.wheel_speed, easy_speed * 4), "The easy loaded-speed gauge must rise four times more slowly")
	popup.close()
	GameState.set_difficulty(GameState.DIFFICULTY_EASY)
	GameState.reset_progress(false)
	GameState.flags.tools_given_to_mateo = true
	popup.open()
	for attempt in range(15):
		popup._confirm_assembly()
		_check(GameState.flags.forge_attempts_left == 14 - attempt, "Each easy error must spend one of the fifteen shared opportunities")
		if attempt < 14: popup.retry_button.pressed.emit()
	await _wait(1.85)
	_check(not popup.overlay.visible and dialogue.options[0].label.contains("15 oportunidades"), "Easy exhaustion must close the puzzle and offer a fifteen-opportunity new round")
	GameState.restart_forge_round()
	_check(popup.overlay.visible and GameState.flags.forge_attempts_left == 15 and GameState.flags.forge_attempts_spent == 0, "Mateo must restart with the selected easy allowance")
	await _finish_easy_workshop()
	popup.close()
	menu.queue_free()


func _finish_easy_workshop() -> void:
	for index in range(4):
		popup.piece_angles[index] = index
		popup.place_part(index, index)
	popup.clamp_hold = true
	await _step(3.3)
	popup.clamp_hold = false
	popup._confirm_assembly()
	while popup.heat < 85:
		popup._pump_bellows()
		await _step(0.7)
	await _step(2.1)
	_check(popup.forge_stage == popup.STAGE_RIVET, "The slower easy heat controls must still unlock riveting")
	for index in popup.strike_order:
		popup._turn_to_next()
		await _wait(0.76)
		for hit in range(3):
			var ticks := 0
			while ticks < 700:
				if popup.heat < 80: popup._pump_bellows()
				if popup.heat >= 78 and popup.precision_value() >= 0.40 and popup.precision_value() <= 0.60: break
				await _step(0.025)
				ticks += 1
			popup._strike_rivet(index)
			await _wait(0.45)
			_check(popup.rivet_hits[index] == hit + 1, "Each easy timed strike must produce a real successful hammer impact")
	popup.close()
	popup.open()
	_check(popup.forge_stage == popup.STAGE_COOL, "Easy riveting must preserve all twelve hits and continue to cooling")
	var cooling_ticks := 0
	while not popup.cooling_verified and cooling_ticks < 1200:
		popup.cooling_slider.value = clampf((popup.cooling_target() - 2) / 0.15, 0, 100)
		await _step(0.05)
		cooling_ticks += 1
	await _wait(0.6)
	_check(popup.forge_stage == popup.STAGE_CENTER, "Easy cooling must reach the next stage with the slower moving target")
	for index in range(3):
		popup.adjust_screw(index, popup.SCREW_TARGETS[index] - popup.screws[index])
	popup._confirm_center()
	var proof_ticks := 0
	while popup.proof_checks < 3 and proof_ticks < 2000:
		popup.pointer_proof = popup.wheel_speed < popup.proof_target()
		await _step(0.025)
		proof_ticks += 1
	await _wait(0.75)
	_check(popup.forge_stage == popup.STAGE_COMPLETE and GameState.has_item("rueda_dentada") and GameState.flags.forge_attempts_left == 15, "All six easy stages must be solvable without spending opportunities or duplicating the wheel")


func _initial_green_window() -> float:
	popup.precision_time = 0
	popup._set_heat(85)
	var elapsed := 0.0
	while popup.precision_value() <= 0.62 and elapsed < 2.0:
		popup._process(1.0 / 60)
		elapsed += 1.0 / 60
	return elapsed


func _step(seconds: float) -> void:
	for tick in range(int(ceil(seconds * 60))):
		popup._process(1.0 / 60)
		if demo: await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	popup._input(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _capture(name: String) -> void:
	if not capture_ui: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/forge_challenge"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/forge_challenge/%s.png" % name))


func _restore() -> void:
	for path in backups:
		if backups[path] == null: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backups[path])
