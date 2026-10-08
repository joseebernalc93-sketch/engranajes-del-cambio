extends Node
## Public controls, fixed simulation steps, versioned saves and both difficulty profiles.
const State = preload("res://scripts/ui/lumber_work_state.gd")
var backups: Dictionary = {}
var popup: CanvasLayer
var hud: CanvasLayer
var capture: bool = false
var prefix: String = ""
var checks: int = 0
var failed: bool = false

func _ready() -> void:
	assert(str(ProjectSettings.get_setting("application/config/name")).contains("Validation"), "Run in the isolated validation project, never with player saves.")
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	capture = capture or "--capture-lumber" in OS.get_cmdline_user_args()
	if "--read-bruno" in OS.get_cmdline_user_args():
		_read_checkpoint()
		return
	var island := preload("res://scenes/wood_island.tscn").instantiate()
	add_child(island)
	await get_tree().process_frame
	popup = island.get_node("LumberPuzzlePopup")
	hud = island.get_node("HUD")
	popup.set_physics_process(false)
	_solvable_boards()
	_frame_rates()
	for mode in [GameState.DIFFICULTY_EASY, GameState.DIFFICULTY_HARD]:
		await _round(mode)
		_exhaustion(mode)
	await _small_window()
	_migrate_checkpoint()
	GameState.reset_progress(false)
	GameState.set_difficulty(GameState.DIFFICULTY_EASY)
	GameState.flags.lumber_attempts_spent = 9
	GameState.set_difficulty(GameState.DIFFICULTY_HARD)
	_check(GameState.get_lumber_attempts_left() == 1, "Difficulty changes retain spent opportunities")
	if "--write-bruno" in OS.get_cmdline_user_args():
		_write_checkpoint()
		return
	_restore_files()
	if failed:
		get_tree().quit(1)
		return
	print("LUMBER SIX PHASES OK: ", checks, " checks; easy/hard, touch/keyboard, geometry, friction, pause, checkpoint, exhaustion, unique reward and installation")
	get_tree().quit()

func _solvable_boards() -> void:
	for seed_value in range(1, 101):
		var state := State.new()
		state.initialize(true, seed_value)
		var valid := false
		for x in range(341):
			state.template_x = x
			if state.template_safe():
				valid = true
				break
		_check(valid, "Every generated board has a usable span")

func _round(mode: String) -> void:
	GameState.reset_progress(false)
	GameState.set_difficulty(mode)
	popup.open()
	var budget := GameState.get_lumber_opportunities()
	prefix = "facil" if budget == 15 else "dificil"
	_check(popup.stage == State.Stage.INSPECT and budget in [10, 15], "Correct opening profile")
	_check(_count_sliders(popup) == 0, "No generic sliders remain in the puzzle")
	# A confirmed structural defect costs once; merely moving over it costs nothing.
	popup.model.template_x = clampf(float(popup.model.defects[0].x) - 120, 0, 340)
	_check(not popup.model.template_safe(), "Defect intersects template")
	popup._confirm()
	await _shot("01_revision")
	_review(State.Stage.INSPECT, budget - 1)
	var chosen := _clean_span()
	popup.workbench.set_tool("template")
	_touch(Vector2(100, 215), true)
	_drag(Vector2(100 + chosen - popup.model.template_x, 215))
	_touch(Vector2(100 + chosen, 215), false)
	_check(popup.model.template_safe(), "Touch moves template to valid span")
	popup.workbench.set_tool("lens")
	_mouse(Vector2(230, 215), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(380, 220) * popup.workbench.size / Vector2(800, 420)
	popup.workbench._gui_input(motion)
	_mouse(Vector2(380, 220), false)
	_check(popup.model.lens_position == Vector2(380, 220), "Lens follows mouse; tools also support touch")
	await _shot("02_inspeccion")
	popup._confirm()
	_check(popup.stage == State.Stage.MEASURE, "Inspection advances")
	# Drag the actual stop and rotating square; there is no numerical menu.
	popup.workbench.set_tool("rule")
	_touch(Vector2(444, 147), true)
	_drag(Vector2(568, 147))
	_touch(Vector2(568, 147), false)
	popup.workbench.set_tool("square")
	_touch(Vector2(568, 105), true)
	_drag(Vector2(568, 104))
	_touch(Vector2(568, 104), false)
	_check(is_equal_approx(popup.model.length_cm, 160) and is_equal_approx(popup.model.square_angle, 90), "Diegetic measuring tools")
	popup.workbench.set_tool("scribe")
	_touch(Vector2(98, 184), true)
	_step(0.1)
	_drag(Vector2(118, 216))
	_touch(Vector2(118, 216), false)
	_review(State.Stage.MEASURE, budget - 2)
	popup.workbench.set_tool("scribe")
	_key_stroke(1.6)
	_check(popup.model.marked_lines == 1, "First incision preserved")
	_checkpoint()
	_check(popup.stage == State.Stage.MEASURE and popup.model.marked_lines == 1, "Incision and measuring tools recover")
	await _shot("03_trazado")
	popup.workbench.set_tool("scribe")
	_key_stroke(1.6)
	_check(popup.stage == State.Stage.SECURE, "Both incisions complete")
	popup._confirm()
	_review(State.Stage.SECURE, budget - 3)
	popup.workbench.set_tool("wedge0")
	_touch(Vector2(150, 360), true)
	_drag(Vector2(150, 282))
	_touch(Vector2(150, 282), false)
	_check(popup.model.wedge_inserted[0], "Wood wedge is dragged into its slot before hammering")
	for wedge in 3:
		popup.workbench.set_tool("wedge%d" % wedge)
		for hit in (3 if popup.model.wedge_inserted[wedge] else 4):
			_step(0.3)
			_key(KEY_SPACE, true)
			_key(KEY_SPACE, false)
	_check(popup.model.wedge_hits == [3, 3, 3], "Three wedges seated through rhythmic keyboard input")
	popup.workbench.set_tool("vice")
	# A clockwise arc increases jaw pressure; arrows finish the adjustment.
	var previous: float = popup.model.pressure
	_touch(Vector2(752, 295), true)
	_drag(Vector2(718, 329))
	_touch(Vector2(718, 329), false)
	_check(popup.model.pressure > previous, "Clockwise crank increases pressure")
	popup.model.pressure = 0.60
	await _shot("04_fijacion")
	popup._confirm()
	_check(popup.stage == State.Stage.SAW, "Rigid board advances")
	# Rapid stroke binding and partial cancellation are independent of the render FPS.
	popup.workbench.set_tool("saw")
	_touch(Vector2(466, 202), true)
	_step(0.1)
	_drag(Vector2(636, 202))
	_touch(Vector2(636, 202), false)
	_review(State.Stage.SAW, budget - 4)
	for index in 5:
		popup.workbench.set_tool("saw")
		_key_stroke(1.65 if budget == 15 else 1.15)
		_check(popup.model.cuts == index + 1, "Uniform alternating saw stroke")
		if index == 1:
			_checkpoint()
			await _shot("05_serrado")
	_check(popup.stage == State.Stage.PLANE, "Five strokes separate offcut")
	_check(popup.workbench.offcut_released, "Offcut is released to 2D physics")
	popup.model.blade_depth = 0.95
	popup.workbench.set_tool("plane")
	_touch(Vector2(72, 196), true)
	_step(0.1)
	_drag(Vector2(100, 196))
	_touch(Vector2(100, 196), false)
	_review(State.Stage.PLANE, budget - 5)
	popup.model.blade_depth = 0.10
	popup.workbench.set_tool("plane")
	_key_stroke(3)
	_check(popup.model.passes == 0 and GameState.get_lumber_attempts_left() == budget - 5, "Retracted blade slips without damage or penalty")
	popup.model.blade_depth = 0.5
	for lane in 4:
		popup.workbench.set_tool("plane")
		_key_stroke(2.85 if budget == 15 else 1.95)
		_check(popup.model.passes == lane + 1, "Each band planes once")
		if lane == 1:
			_checkpoint()
			await _shot("06_cepillado")
	_check(popup.stage == State.Stage.LOAD, "Four bands complete")
	popup.model.counterforce = 0
	popup.model.place_sack()
	_step(5.0)
	_review(State.Stage.LOAD, budget - 6)
	_check(popup.model.verified_loads == 0 and not popup.model.load_active, "Failed sack can be retried")
	for index in 3:
		popup.model.counterforce = State.LOAD_TARGETS[index]
		popup.workbench.set_tool("sack")
		_touch(Vector2(338, 110), true)
		_drag(Vector2(320, 190))
		_touch(Vector2(320, 190), false)
		_check(popup.model.load_active, "Sack drops on the central support")
		if index == 1:
			_step(0.2)
			var saved_clock: float = popup.model.clock
			popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			_step(8)
			_check(popup.model.clock == saved_clock, "Focus loss freezes all work without penalty")
			popup._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			_checkpoint()
			_check(popup.model.load_active and popup.model.verified_loads == 1, "Active load and validated sack survive closing")
			await _shot("07_flexion")
		_balance_load(2.0)
		_check(popup.model.verified_loads == index + 1, "Load held within elastic tolerance")
	_check(popup.stage == State.Stage.COMPLETE and GameState.has_item("tabla"), "Six stages award the board")
	_check(GameState.metrics.saw_successes == 5 and GameState.metrics.planing_passes == 4 and GameState.metrics.lumber_load_sacks == 3, "Recorded work matches actual operations")
	_check(not GameState.complete_lumber_puzzle(), "Reward cannot be duplicated")
	await _shot("08_terminada")
	_check(GameState.install_mill_part("tabla"), "Board installs in the mill")
	_check(not GameState.has_item("tabla") and GameState.flags.mill_plank_installed, "Installation consumes the board once")
	popup.close()
	print("LUMBER PROFILE OK: ", mode)

func _review(expected_stage: int, remaining: int) -> void:
	_check(popup.awaiting_retry and popup.retry_notice.visible, "Technical review opens")
	_check(popup.stage == expected_stage and GameState.get_lumber_attempts_left() == remaining, "Only one opportunity consumed; stage retained")
	var before: float = popup.model.clock
	_step(30)
	popup._register_mistake("duplicate")
	_check(popup.model.clock == before and GameState.get_lumber_attempts_left() == remaining, "Review pauses simulation and guards duplicate penalties")
	var board: Array = popup.model.defects.duplicate(true)
	popup.close()
	popup.open()
	_check(popup.awaiting_retry and popup.model.defects == board, "Review and board layout persist")
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(not popup.awaiting_retry and not popup.model.tool_active, "Continue dismisses notice without starting a tool")

func _exhaustion(mode: String) -> void:
	GameState.reset_progress(false)
	GameState.set_difficulty(mode)
	popup.open()
	for attempt in GameState.get_lumber_opportunities():
		popup.model.template_x = clampf(float(popup.model.defects[0].x) - 120, 0, 340)
		popup._confirm()
		if popup.awaiting_retry: popup._continue_current_phase()
	_check(not popup.overlay.visible and GameState.get_lumber_attempts_left() == 0, "Exhaustion exits the puzzle")
	popup.open()
	_check(not popup.overlay.visible, "No attempt without a new round")
	hud._select_dialogue_action("restart_lumber_round")
	_check(popup.overlay.visible and popup.stage == State.Stage.INSPECT and GameState.get_lumber_attempts_left() == GameState.get_lumber_opportunities(), "Bruno permits a fresh round")
	popup.close()
	# Failure late in a phase preserves its completed bands, even at exhaustion.
	GameState.flags.lumber_attempts_spent = GameState.get_lumber_opportunities() - 2
	GameState.flags.lumber_progress = {"version": 2, "stage": 4, "cuts": 5, "passes": 2, "depth": 0.95}
	popup.open()
	for attempt in 2:
		popup.model.blade_depth = 0.95
		popup.workbench.set_tool("plane")
		var y: float = popup.model.lane_y()
		_touch(Vector2(72, y), true)
		_step(0.1)
		_drag(Vector2(100, y))
		_touch(Vector2(100, y), false)
		if attempt == 0: _review(State.Stage.PLANE, 1)
	_check(not popup.overlay.visible and GameState.flags.lumber_progress.passes == 2, "Late exhaustion preserves completed bands until a new round is chosen")
	hud._select_dialogue_action("restart_lumber_round")
	_check(popup.stage == State.Stage.INSPECT, "New round discards only the exhausted piece")
	popup.close()

func _migrate_checkpoint() -> void:
	GameState.reset_progress(false)
	GameState.flags.lumber_progress = {"stage": 4, "selected": true, "marked_lines": 3, "fixations": [true, true, true], "secured": true, "cuts": 5, "passes": 2, "length": 160, "angle": 90, "clamp": 60, "depth": 50, "brace": 42}
	popup.open()
	_check(popup.stage == State.Stage.PLANE and popup.model.passes == 2 and popup.model.depth_safe(), "Old checkpoint retains completed work and adjustments")
	popup.close()

func _checkpoint() -> void:
	var before: Dictionary = popup.model.snapshot()
	popup.close()
	popup.open()
	popup.set_physics_process(false)
	_check(popup.model.snapshot() == before, "Explicit checkpoint round trip")

func _clean_span() -> float:
	var original: float = popup.model.template_x
	for x in range(341):
		popup.model.template_x = x
		if popup.model.template_safe():
			popup.model.template_x = original
			return x
	assert(false, "Unsolvable board")
	return 0

func _step(seconds: float) -> void:
	for tick in int(ceil(seconds * 60)):
		popup.step_workshop(1.0 / 60.0)

func _balance_load(seconds: float) -> void:
	popup.workbench.set_tool("lever")
	_touch(popup.workbench.lever_grip(popup.model.counterforce), true)
	for tick in int(ceil(seconds * 60)):
		if not popup.model.load_active: break
		var clock: float = popup.model.clock
		var speed := 0.8 if popup.model.easy else 2.4
		var amplitude := 0.018 if popup.model.easy else 0.045
		var target: float = State.LOAD_TARGETS[popup.model.verified_loads] + sin((clock + 1.0 / 60) * speed) * amplitude
		_drag(popup.workbench.lever_grip(target))
		_step(1.0 / 60)
	_touch(popup.workbench.lever_grip(popup.model.counterforce), false)

func _key_stroke(seconds: float) -> void:
	var arrow: int = KEY_RIGHT if popup.model.cuts % 2 == 0 else KEY_LEFT
	var saw: bool = popup.stage == State.Stage.SAW
	if saw: _key(arrow, true)
	_key(KEY_SPACE, true)
	_step(seconds)
	_key(KEY_SPACE, false)
	if saw: _key(arrow, false)

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	popup._input(event)

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point * popup.workbench.size / Vector2(800, 420)
	event.pressed = pressed
	popup.workbench._gui_input(event)

func _frame_rates() -> void:
	for hz in [30, 60, 120]:
		var state := State.new()
		state.initialize(false, 5)
		state.stage = State.Stage.SAW
		state.begin_tool(Vector2(466, 202))
		for sample in hz:
			state.tick(1.0 / hz)
			state.move_tool(Vector2(466 + 170.0 * (sample + 1) / hz, 202))
		_check(state.cuts == 1 and not state.paused, "Saw friction is consistent at 30/60/120 simulation steps")

func _small_window() -> void:
	GameState.reset_progress(false)
	popup.open()
	var previous := get_window().size
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	await get_tree().process_frame
	popup._fit_panel()
	var origin: Vector2 = popup.panel.get_global_transform() * Vector2.ZERO
	var end: Vector2 = popup.panel.get_global_transform() * popup.panel.size
	_check(origin.x >= 0 and origin.y >= 0 and end.x <= popup.overlay.size.x and end.y <= popup.overlay.size.y, "Workshop fits a small window")
	await _shot("09_ventana_pequena")
	get_window().size = previous
	await get_tree().process_frame
	popup.close()

func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point * popup.workbench.size / Vector2(800, 420)
	event.pressed = pressed
	popup.workbench._gui_input(event)

func _drag(point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = point * popup.workbench.size / Vector2(800, 420)
	popup.workbench._gui_input(event)

func _count_sliders(node: Node) -> int:
	var count := 1 if node is Slider else 0
	for child in node.get_children(): count += _count_sliders(child)
	return count

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("BRUNO CHECK FAILED: " + description)

func _shot(name: String) -> void:
	if not capture: return
	popup.workbench.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://output/ui/bruno_artesanal")
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder + "/" + prefix + "_" + name + ".png")

func _write_checkpoint() -> void:
	GameState.reset_progress(false)
	GameState.flags.lumber_progress = {"version": 2, "stage": 5, "loads": 1, "load_active": true, "stable_seconds": 0.4, "deflection": 0.2, "brace": 0.56, "cuts": 5, "passes": 4, "marked_lines": 2, "wedge_hits": [3, 3, 3], "seed": 31}
	popup.open()
	popup._save_work()
	print("BRUNO CHECKPOINT WRITTEN")
	get_tree().quit()

func _read_checkpoint() -> void:
	var saved: Dictionary = GameState.flags.get("lumber_progress", {})
	_check(saved.get("version") == 2 and saved.get("loads") == 1 and saved.get("load_active") == true, "Independent process recovers active load")
	var state := State.new()
	state.initialize(GameState.is_easy_difficulty(), 1)
	state.restore(saved)
	_check(state.verified_loads == 1 and state.load_active and is_equal_approx(state.stable_seconds, 0.4), "Elastic trial checkpoint matches")
	print("BRUNO CHECKPOINT READ OK")
	get_tree().quit()

func _restore_files() -> void:
	for path in backups:
		if backups[path] != null: FileAccess.open(path, FileAccess.WRITE).store_buffer(backups[path])
		elif FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
