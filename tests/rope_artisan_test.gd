extends Node
const State = preload("res://scripts/ui/rope_work_state.gd")
var backups: Dictionary = {}
var popup: CanvasLayer
var yard: Node
var checks: int = 0
var failed: bool = false
var capturing: bool = false
var prefix: String = ""

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).contains("Validation"):
		push_error("Run only in the isolated validation project.")
		get_tree().quit(1)
		return
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	capturing = capturing or "--capture-rope" in OS.get_cmdline_user_args()
	yard = preload("res://scenes/spinner_yard.tscn").instantiate()
	add_child(yard)
	popup = yard.get_node("RopePuzzlePopup")
	popup.set_physics_process(false)
	await get_tree().process_frame
	if "--read-silas" in OS.get_cmdline_user_args():
		_check(GameState.load_progress(), "Separate process loads checkpoint")
		popup.open()
		_check(popup.stage == State.Stage.PROOF and popup.model.proof_checks == 1 and popup.model.load_active, "Active second sack persists across processes")
		_check(is_equal_approx(popup.model.proof_brake, 0.55), "Exact saved brake")
		popup.close()
	else:
		for mode in [GameState.DIFFICULTY_EASY, GameState.DIFFICULTY_HARD]:
			await _round(mode)
			_brake_inputs(mode)
			await _proof_retry_regression(mode)
			_exhaustion(mode)
			_keyboard_round(mode)
		_model_checks()
		await _small_window()
		if "--write-silas" in OS.get_cmdline_user_args():
			GameState.reset_progress(false)
			popup.open()
			popup.model.stage = State.Stage.PROOF
			popup.model.proof_checks = 1
			popup.model.load_active = true
			popup.model.proof_brake = 0.55
			popup._save_work()
			popup.close()
		else: _restore_files()
	yard.queue_free()
	await get_tree().process_frame
	# Let the audio server drain queued one-shot commands from the accelerated simulation.
	await get_tree().create_timer(0.2).timeout
	print("ROPE ARTISAN SIX PHASES OK: %d checks" % checks if not failed else "ROPE ARTISAN FAILED")
	get_tree().quit(1 if failed else 0)

func _round(mode: String) -> void:
	GameState.reset_progress(false)
	GameState.set_difficulty(mode)
	popup.open()
	var maximum := GameState.get_rope_opportunities()
	prefix = "facil" if maximum == 15 else "dificil"
	_check(maximum == (15 if popup.model.easy else 10), "Shared budget")
	_check(_sliders(popup) == 0, "No generic sliders or progress bars")
	_check(not yard.get_node("World/Player").controls_enabled, "World locked during puzzle")
	await _shot("01_peinado")
	_pointer(Vector2(180, 145), "press")
	_pointer(Vector2(260, 250), "move")
	await _shot("09_revision")
	_review(State.Stage.CARD, maximum - 1)
	_pointer(Vector2(180, 145), "press")
	popup.step_workshop(0.1)
	_pointer(Vector2(600, 145), "move")
	_review(State.Stage.CARD, maximum - 2)
	for bundle in 3:
		popup.workbench.set_tool("card%d" % bundle)
		for pass_index in 2:
			if bundle == 0 and pass_index == 0:
				_pointer(Vector2(180, 145), "press", 0)
				for step in 90:
					popup.step_workshop(1.0 / 60)
					_pointer(Vector2(180 + (step + 1) * 460.0 / 90, 145), "move", 0)
				_pointer(Vector2(640, 145), "release", 0)
			elif bundle == 1 and pass_index == 0:
				_pointer(Vector2(180, 172), "press", 0)
				for step in 150:
					popup.step_workshop(1.0 / 60)
					_pointer(Vector2(180 + (step + 1) * 460.0 / 150, 172), "move", 0)
				_pointer(Vector2(640, 172), "release", 0)
				_check(popup.model.comb_passes[1] == 1, "Grabbing the second rake handle preserves its grip offset")
			else:
				_key(KEY_SPACE, true)
				_step(240)
				_key(KEY_SPACE, false)
			if bundle == 0 and pass_index == 0:
				_checkpoint()
				_check(popup.model.comb_passes[0] == 1, "Carding pass saved")
	_check(popup.stage == State.Stage.MOUNT and int(GameState.metrics.rope_fibers_cleaned) == 3, "Six passes prepare three bundles")
	await _shot("02_cabos")
	popup.model.mount(0)
	_review(State.Stage.MOUNT, maximum - 3)
	popup.workbench.set_tool("portion0")
	_pointer(Vector2(245, 292), "press", 0)
	_pointer(Vector2(275, 292), "move", 0)
	_pointer(Vector2(275, 292), "release", 0)
	_check(is_equal_approx(popup.model.portions[0], 1) and is_equal_approx(popup.model.portions[1], 1), "Caliper redistributes equal mass")
	for index in 3:
		popup.workbench.set_tool("portion%d" % index)
		if index == 0:
			_pointer(Vector2(230, 320), "press", 0)
			_pointer(popup.workbench.HEAD_HOOKS[0], "move", 0)
			_pointer(popup.workbench.HEAD_HOOKS[0], "release", 0)
			_check(popup.model.mounted[0] and is_equal_approx(popup.model.portions[0], 1), "Dragging a bundle mounts it without changing its mass")
		else:
			_key(KEY_SPACE, true)
			_key(KEY_SPACE, false)
		if index == 0: _checkpoint()
	_check(popup.stage == State.Stage.TWIST, "Three symmetric hooks mounted")
	_machine_connections()
	await _shot("03_torsion")
	popup.model.carriage = 710
	popup.model.tension = 100
	_step(270 if popup.model.easy else 80)
	_review(State.Stage.TWIST, maximum - 4)
	popup.model.carriage = 500
	popup.model.tension = 0
	_step(270 if popup.model.easy else 80)
	_review(State.Stage.TWIST, maximum - 5)
	popup.model.tension = 55
	popup.model.carriage = 660
	_pointer(Vector2(162, 200), "press", 0)
	_pointer(Vector2(660, 250), "press", 1)
	_pointer(Vector2(102, 260), "move", 0)
	_pointer(Vector2(popup.model.ideal_carriage(), 250), "move", 1)
	_pointer(Vector2(102, 260), "release", 0)
	_pointer(Vector2(popup.model.carriage, 250), "release", 1)
	_check(popup.model.twists >= 0.24 and popup.workbench.pointers.is_empty(), "Two fingers coordinate crank and carriage")
	_key(KEY_SPACE, true)
	var captured_twist := false
	for step in 1000:
		popup.model.adjust("carriage", popup.model.ideal_carriage() - popup.model.carriage)
		popup.step_workshop(1.0 / 60)
		if not captured_twist and popup.model.twists >= 4.5 and popup.stage == State.Stage.TWIST:
			captured_twist = true
			await _shot("03_torsion_en_marcha")
		if popup.stage != State.Stage.TWIST: break
	_key(KEY_SPACE, false)
	_check(popup.stage == State.Stage.TENSION and popup.model.twists == 5, "Five turns shorten the carriage")
	_machine_connections()
	await _shot("04_tension")
	popup.model.brake = 1
	popup.model.tension = 95
	_key(KEY_SPACE, true)
	_step(270 if popup.model.easy else 80)
	_key(KEY_SPACE, false)
	_review(State.Stage.TENSION, maximum - 6)
	popup.model.brake = 0.5
	popup.model.tension = 55
	_key(KEY_SPACE, true)
	_step(150)
	_check(popup.stage == State.Stage.TENSION and popup.model.stable_seconds > 2, "Three continuous seconds required")
	var old_time: float = popup.model.stable_seconds
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_step(120)
	_check(popup.model.stable_seconds == old_time, "Focus loss freezes simulation")
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_checkpoint()
	_key(KEY_SPACE, true)
	_step(55)
	_key(KEY_SPACE, false)
	_check(popup.stage == State.Stage.BIND, "Stable compaction advances")
	await _shot("05_ligadura")
	_pointer(Vector2(400, 141), "press")
	_pointer(Vector2(474, 215), "move")
	_pointer(Vector2(474, 215), "release")
	_review(State.Stage.BIND, maximum - 7)
	_key(KEY_SPACE, true)
	_step(160 if popup.model.easy else 45)
	_key(KEY_SPACE, false)
	_check(popup.model.binding_wraps == 1, "Keyboard completes full wrap")
	_pointer(Vector2(400, 141), "press")
	_pointer(Vector2(326, 215), "move")
	_review(State.Stage.BIND, maximum - 8)
	_check(popup.model.binding_wraps == 1, "Wrong direction retains secured wrap")
	_checkpoint()
	for wrap in 2:
		_pointer(Vector2(400, 141), "press")
		for segment in range(1, 65):
			var angle := segment / 64.0 * TAU
			_pointer(Vector2(400 + sin(angle) * 74, 215 - cos(angle) * 74), "move")
		_pointer(Vector2(400, 141), "release")
	_check(popup.model.binding_wraps == 3, "Three secured wraps")
	await _shot("05_remate_cerrado")
	_pointer(Vector2(430, 250), "press")
	_pointer(Vector2(430, 350), "move")
	_pointer(Vector2(430, 350), "release")
	_check(popup.stage == State.Stage.PROOF and popup.model.binding_locked, "Final pull locks binding")
	popup._complete_rope_puzzle()
	_check(not GameState.has_item("cuerda"), "No premature reward")
	await _shot("06_carga")
	popup.model.proof_brake = 1
	popup.model.proof_force = 0.9
	popup.model.place_sack()
	_step(270 if popup.model.easy else 80)
	_review(State.Stage.PROOF, maximum - 9)
	for load_index in 3:
		popup.workbench.set_tool("sack")
		if load_index == 0:
			_pointer(Vector2(152, 250), "press", 0)
			_pointer(Vector2(395, 295), "move", 0)
			_pointer(Vector2(395, 295), "release", 0)
		else:
			_key(KEY_SPACE, true)
			_key(KEY_SPACE, false)
		_check(popup.model.load_active and popup.model.selected_tool == "lever", "Sack hands control to brake")
		for step in 300:
			var target: float = popup.model.load_target() + sin(popup.model.clock * 4) * (0.025 if popup.model.easy else 0.055) / 0.85
			var grip: Vector2 = popup.workbench.brake_grip(target, true)
			_pointer(grip, "press")
			_pointer(grip, "move")
			_pointer(grip, "release")
			popup.step_workshop(1.0 / 60)
			if load_index == 0 and step == 60: await _shot("06_carga_activa")
			if not popup.model.load_active: break
		_check(popup.model.proof_checks == load_index + 1, "Spring balance validates load")
		if load_index == 0: _checkpoint()
	_check(popup.stage == State.Stage.COMPLETE and GameState.inventory.get("cuerda", 0) == 1, "Unique reward after six stages")
	await _shot("07_terminada")
	popup._complete_rope_puzzle()
	_check(GameState.inventory.get("cuerda", 0) == 1 and not GameState.complete_rope_puzzle(), "Duplicate reward prevented")
	_check(GameState.install_mill_part("cuerda") and not GameState.has_item("cuerda"), "Rope installs and consumes once")
	_check(not GameState.install_mill_part("cuerda"), "Installation cannot repeat")
	popup.close()
	_check(not popup.tool_audio.playing and not popup.workbench.active, "Tools and audio stop")

func _brake_inputs(mode: String) -> void:
	GameState.reset_progress(false)
	GameState.set_difficulty(mode)
	popup.open()
	for stage_index in [State.Stage.TENSION, State.Stage.PROOF]:
		popup.model.stage = stage_index
		popup._refresh()
		for value in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var proof: bool = stage_index == State.Stage.PROOF
			var grip: Vector2 = popup.workbench.brake_grip(value, proof)
			_pointer(popup.workbench.brake_grip(0.5, proof), "press", 0)
			_pointer(grip, "move", 0)
			_pointer(grip, "release", 0)
			var actual: float = popup.model.proof_brake if proof else popup.model.brake
			_check(absf(actual - value) < 0.0001, "Touching the illustrated lever grip sets the matching brake angle")
		if stage_index == State.Stage.PROOF:
			popup.workbench.refresh()
			_check(popup.workbench.ropes[0].points[0] == popup.workbench.PROOF_PULLEY_EXIT and popup.workbench.ropes[0].points[-1] == popup.workbench.proof_sack_hook(), "Load rope joins the real pulley rim to the sack mouth")
	var maximum: int = 15 if popup.model.easy else 10
	_check(GameState.get_rope_attempts_left() == maximum, "Moving idle levers costs no opportunity")
	popup.close()

func _proof_retry_regression(mode: String) -> void:
	for approved in 3:
		GameState.reset_progress(false)
		GameState.set_difficulty(mode)
		popup.open()
		prefix = "facil" if popup.model.easy else "dificil"
		popup.model.stage = State.Stage.PROOF
		popup.model.proof_checks = approved
		popup.model.comb_passes.assign([2, 2, 2])
		popup.model.mounted.assign([true, true, true])
		popup.model.binding_wraps = 3
		popup.model.binding_locked = true
		popup.model.load_active = true
		popup.model.proof_brake = 0
		popup.model.proof_force = 1.4
		popup.model.spring_velocity = 10
		popup._refresh()
		var remaining: int = GameState.get_rope_attempts_left() - 1
		popup.step_workshop(1.0 / 60)
		_check(popup.model.proof_checks == approved and not popup.model.load_active, "Overload unloads only the failed sack")
		_check(popup.status_label.text != popup.model.message and popup.status_label.max_lines_visible == 5, "Long review stays in its own modal")
		await _shot("10_carga_revision_%d" % approved)
		_review(State.Stage.PROOF, remaining)
		_check(not popup.confirm_button.disabled and popup.confirm_button.text == "Izar saco", "Review unlocks the real hoist button")
		_check(popup.model.spring_velocity == 0 and popup.model.proof_force < 1.05, "Retry clears spring overload and momentum")
		_check(popup.model.binding_locked and popup.model.comb_passes == [2, 2, 2], "Retry preserves earlier phases")
		_step(600)
		_check(GameState.get_rope_attempts_left() == remaining and not popup.model.load_active, "Waiting for a new hoist never consumes opportunities")
		popup.confirm_button.pressed.emit()
		_check(popup.model.load_active and popup.model.selected_tool == "lever", "Real button starts a fresh attempt")
		var spring_before: float = popup.model.spring_velocity
		popup.confirm_button.pressed.emit()
		_check(popup.model.spring_velocity == spring_before, "Repeated hoist cannot reset an active load")
		for frame in 300:
			var target: float = popup.model.load_target() + sin(popup.model.clock * 4) * (0.025 if popup.model.easy else 0.055) / 0.85
			popup.model.adjust("lever", target - popup.model.proof_brake)
			popup.step_workshop(1.0 / 60)
			if not popup.model.load_active: break
		_check(popup.model.proof_checks == approved + 1 and not popup.awaiting_retry, "Failed sack can be approved on the very next try")
		_check(GameState.get_rope_attempts_left() == remaining, "Successful retry costs no extra opportunity")
		await _shot("11_carga_recuperada_%d" % approved)
		popup.close()
	# Existing saves may already contain the broken spring from the former implementation.
	var repaired := State.new()
	repaired.restore({"version": 3, "stage": State.Stage.PROOF, "proof_checks": 2, "proof_force": 1.4, "spring_velocity": 10, "load_active": true, "retry_reason": "Overload"})
	_check(repaired.proof_checks == 2 and not repaired.load_active and repaired.spring_velocity == 0 and is_equal_approx(repaired.proof_force, 0.55), "Old overload checkpoint is repaired without losing approved sacks")

func _review(expected_stage: int, remaining: int) -> void:
	_check(popup.awaiting_retry and popup.retry_notice.visible and popup.model.paused, "Review pauses tools")
	_check(popup.stage == expected_stage and GameState.get_rope_attempts_left() == remaining, "One shared opportunity in current phase")
	var saved: Dictionary = popup.model.snapshot()
	_step(120)
	popup._register_mistake("duplicate")
	_check(popup.model.snapshot() == saved and GameState.get_rope_attempts_left() == remaining, "Review freezes timers and prevents repeat charges")
	popup.close()
	popup.open()
	_check(popup.awaiting_retry and popup.stage == expected_stage, "Review persists on reopen")
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	_check(not popup.awaiting_retry and not popup.model.paused, "Enter resumes current phase")

func _checkpoint() -> void:
	var before: Dictionary = popup.model.snapshot()
	popup.close()
	_check(GameState.load_progress(), "Checkpoint loads from disk")
	popup.open()
	for field in ["stage", "comb_passes", "portions", "mounted", "twists", "carriage", "binding_wraps", "proof_checks", "proof_brake", "load_active"]:
		var actual: Variant = popup.model.snapshot()[field]
		_check(is_equal_approx(float(actual), float(before[field])) if actual is float else actual == before[field], "Persistent field: " + field)

func _exhaustion(mode: String) -> void:
	GameState.reset_progress(false)
	GameState.set_difficulty(mode)
	popup.open()
	popup.model.stage = State.Stage.BIND
	popup.model.binding_wraps = 2
	var encouragement := {}
	EventBus.dialogue_requested.connect(func(payload: Dictionary): encouragement.assign(payload), CONNECT_ONE_SHOT)
	var maximum := GameState.get_rope_opportunities()
	for index in maximum:
		popup.model.begin_wrap()
		popup.model.turn_wrap(-0.3)
		if popup.awaiting_retry: popup._continue_current_phase()
	_check(GameState.get_rope_attempts_left() == 0 and not popup.overlay.visible, "Exhaustion exits puzzle")
	_check(str(encouragement.get("speaker", "")).contains("Silas") and str(encouragement.get("text", "")).contains("paciencia"), "Silas offers the encouragement dialogue")
	_check(not GameState.has_item("cuerda") and int(GameState.flags.rope_progress.binding_wraps) == 2, "Exhaustion retains work until explicit new round")
	popup.open()
	_check(not popup.overlay.visible, "Exhausted round cannot reopen")
	GameState.restart_rope_round()
	_check(popup.overlay.visible and popup.stage == State.Stage.CARD and GameState.get_rope_attempts_left() == maximum, "Retry gives full active difficulty budget")
	popup.close()

func _model_checks() -> void:
	for hz in [30, 60, 120]:
		var state := State.new()
		state.initialize(false)
		state.stage = State.Stage.PROOF
		state.proof_brake = 0.36
		state.place_sack()
		for step in hz * 3: state.tick(1.0 / hz)
		_check(state.proof_checks == 1 and not state.paused, "Spring stable at %d Hz" % hz)
	var slow := State.new()
	var fast := State.new()
	slow.initialize(true)
	fast.initialize(false)
	slow.tick(1)
	fast.tick(1)
	_check(is_equal_approx(fast.clock, slow.clock * 4), "Easy indicators exactly four times slower")
	_check(slow.grace() == 4 and fast.grace() == 1 and slow.mass_tolerance() == 0.12 and fast.mass_tolerance() == 0.04, "Difficulty tolerances")
	slow.restore({"stage": 4, "binding_wraps": 2, "twist_progress": 100})
	_check(slow.stage == State.Stage.BIND and slow.binding_wraps == 2 and slow.comb_passes == [2, 2, 2], "Old save migration")
	slow.restore({"stage": 5, "proof_checks": 2})
	_check(slow.stage == State.Stage.PROOF and slow.proof_checks == 2 and slow.binding_locked, "Old load checks migrate")
	var legacy := State.new()
	legacy.restore({"stage": 2, "mounted": [true, false, true], "brake": 60})
	_check(legacy.stage == State.Stage.MOUNT and legacy.mounted == [true, false, true] and legacy.proof_brake == 0.6, "Legacy mounted hooks and brake are preserved")
	fast.stage = State.Stage.BIND
	fast.binding_wraps = 3
	fast.pull_binding(10)
	_check(fast.paused and fast.binding_wraps == 3, "Weak pull retains completed wraps")

func _machine_connections() -> void:
	popup.workbench.refresh()
	var display: Control = popup.workbench
	var wheel_contact: float = display.CART_RECT.position.y + display.CART_RECT.size.y * 978.0 / 1060.0
	_check(absf(wheel_contact - display.TRACK_CONTACT_Y) < 1.0, "Wheel tread rests on the backdrop rail")
	_check(not display.QUALITY_COIL_RECT.intersects(display.QUALITY_TITLE_RECT), "Pixel-art rope leaves the quality heading clear")
	_check(display.ropes[0].material.get_shader_parameter("hemp_texture") == display.BRAID and not display.ropes[0].antialiased, "Machine uses the illustrated pixel-art braid")
	if popup.stage == State.Stage.TWIST:
		for index in 3:
			var line: Line2D = display.ropes[index]
			_check(line.points[0] == display.HEAD_HOOKS[index], "Each strand starts on its actual iron hook")
			_check(line.points[-1].x == display.GUIDE_FACE.x, "Strands enter the cone instead of crossing directly to the carriage")
	var joined: Line2D = display.ropes[3]
	_check(joined.points[0] == display.GUIDE_EXIT and joined.points[-1] == display.carriage_anchor(), "Unified rope connects guide exit to the carriage eye")
	var previous: Vector2 = joined.points[-1]
	popup.model.carriage -= 10
	display.refresh()
	_check(joined.points[-1] == previous - Vector2(10, 0), "The rope attachment follows carriage movement exactly")
	popup.model.carriage += 10
	display.refresh()

func _keyboard_round(mode: String) -> void:
	GameState.reset_progress(false)
	GameState.set_difficulty(mode)
	popup.open()
	for bundle in 3:
		popup.workbench.set_tool("card%d" % bundle)
		for pass_index in 2:
			_key(KEY_SPACE, true)
			_step(240)
			_key(KEY_SPACE, false)
	popup.workbench.set_tool("portion0")
	_key(KEY_D, true)
	_step(48)
	_key(KEY_D, false)
	for bundle in 3:
		popup.workbench.set_tool("portion%d" % bundle)
		_key(KEY_SPACE, true)
		_key(KEY_SPACE, false)
	_key(KEY_SPACE, true)
	for tick in 1000:
		_key(KEY_A, popup.model.carriage > popup.model.ideal_carriage() + 1)
		popup.step_workshop(1.0 / 60)
		if popup.stage != State.Stage.TWIST: break
	_key(KEY_A, false)
	_key(KEY_SPACE, false)
	_check(popup.stage == State.Stage.TENSION, "Keyboard wheel/carriage coordination is solvable")
	_key(KEY_SPACE, true)
	_step(200)
	_key(KEY_SPACE, false)
	_check(popup.stage == State.Stage.BIND, "Keyboard compaction is solvable")
	for wrap in 3:
		_key(KEY_SPACE, true)
		_step(160 if popup.model.easy else 45)
		_key(KEY_SPACE, false)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(popup.stage == State.Stage.PROOF, "Keyboard whipping and final pull are solvable")
	for load_index in 3:
		popup.workbench.set_tool("sack")
		_key(KEY_SPACE, true)
		_key(KEY_SPACE, false)
		for tick in 500:
			var error: float = popup.model.load_target() - popup.model.proof_brake
			_key(KEY_A, error < -0.004)
			_key(KEY_D, error > 0.004)
			popup.step_workshop(1.0 / 60)
			if not popup.model.load_active: break
		_key(KEY_A, false)
		_key(KEY_D, false)
	_check(popup.stage == State.Stage.COMPLETE and GameState.get_rope_attempts_left() == GameState.get_rope_opportunities(), "All six stages solvable using only keyboard without losing a chance")
	popup.close()

func _small_window() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	GameState.reset_progress(false)
	popup.open()
	popup._fit_panel()
	var transform: Transform2D = popup.panel.get_global_transform_with_canvas()
	var viewport: Rect2 = get_viewport().get_visible_rect()
	_check(viewport.has_point(transform * Vector2.ZERO) and viewport.has_point(transform * popup.panel.size), "Entire modal fits inside small viewport")
	await _shot("08_ventana_pequena")
	popup.close()

func _sliders(node: Node) -> int:
	var count := 1 if node is Slider or node is ProgressBar else 0
	for child in node.get_children(): count += _sliders(child)
	return count

func _step(count: int) -> void:
	for tick in count: popup.step_workshop(1.0 / 60)

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	popup._input(event)

func _pointer(point: Vector2, action: String, id: int = -1) -> void:
	var local: Vector2 = point * popup.workbench.size / Vector2(800, 420)
	var event: InputEvent
	if id < 0:
		if action == "move":
			event = InputEventMouseMotion.new()
			event.position = local
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = action == "press"
			event.position = local
	elif action == "move":
		event = InputEventScreenDrag.new()
		event.index = id
		event.position = local
	else:
		event = InputEventScreenTouch.new()
		event.index = id
		event.pressed = action == "press"
		event.position = local
	popup.workbench._gui_input(event)

func _shot(suffix: String) -> void:
	if not capturing or DisplayServer.get_name() == "headless": return
	popup.workbench.refresh()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://output/ui/silas_artesanal"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	get_viewport().get_texture().get_image().save_png(directory + "/" + prefix + "_" + suffix + ".png")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error(message)

func _restore_files() -> void:
	for path in backups:
		if backups[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backups[path])
