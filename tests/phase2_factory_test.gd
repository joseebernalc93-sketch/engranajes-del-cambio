extends Node
## Integration through real workshop controllers, with deterministic simulation time.
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Work := preload("res://scripts/puzzles/factory_work_state.gd")
var backups: Dictionary = {}
var checks: int = 0
var failed: bool = false
var hub: Control
var popup: CanvasLayer
var capture: bool = false
var prefix: String = ""
var aborting: bool = false

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).contains("Validation"):
		push_error("Run in tmp/cart_validation_project to protect player saves.")
		get_tree().quit(1)
		return
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	capture = "--capture-phase2" in OS.get_cmdline_user_args()
	GameState.reset_progress(false)
	GameState.phase_complete = true
	hub = preload("res://scenes/phase2_hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub.set_process(false)
	for direction in [[KEY_LEFT, "move_left"], [KEY_RIGHT, "move_right"], [KEY_UP, "move_up"], [KEY_DOWN, "move_down"]]:
		var arrow := InputEventKey.new()
		arrow.physical_keycode = int(direction[0])
		arrow.pressed = true
		_check(arrow.is_action_pressed(str(direction[1])), "Global movement map accepts " + str(direction[1]))
	for mode in ["facil", "dificil"]:
		GameState.reset_progress(false)
		GameState.set_difficulty(mode)
		Campaign.ensure()
		GameState.phase_two.active = true
		prefix = mode
		_check(Campaign.total() == (15 if mode == "facil" else 10), "Shared chapter budget " + mode)
		_check(not Campaign.unlocked("forge"), "Foundry requires mine")
		await _mine()
		await _forge()
		await _engine()
		await _textile()
		_check(GameState.phase_two.completed.size() == 4, "All four workshops completed")
		_check(GameState.phase_two.glossary.size() == 4, "Four historical entries")
		for reward in Campaign.REWARDS: _check(int(GameState.inventory.get(reward, 0)) == 1, "Unique reward " + reward)
		_check(not Campaign.reward("mine"), "Repeated completion awards nothing")
		_save_load()
		_exhaustion()
		_fault_recovery()
		Phase2Metrics.flush()
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phase2Metrics.PATH))
		_check(bool(report.completada) and int(report.balance_productivo.fardos) >= 10, "Background teacher report has completion and output")
		_check(float(report.precision_presion_porcentaje) > 90.0, "Pressure accuracy report")
		_check(int(report.paradas_emergencia) >= 1, "Emergency stops recorded")
		_check(Phase2Metrics.last_write_error == OK, "Atomic worker file write succeeds")
	await _intro_and_journal()
	await _small_window()
	hub.queue_free()
	await get_tree().process_frame
	Phase2Metrics.set_process(false)
	Phase2Metrics.flush()
	GameState.run_started = false
	_restore_files()
	print("PHASE 2 FACTORY ", "FAILED" if failed else "OK", ": ", checks, " checks · easy/hard · 6+6+6+4 stages · shared budget · input · review · save/load · 120-second shift · unique inventory · report · journal")
	get_tree().quit(1 if failed else 0)

func _open(index: int) -> void:
	hub.dialogue.hide()
	hub.dialogue_kind = ""
	hub.journal_overlay.hide()
	hub.active_workshop = index
	popup = hub.workshops[index]
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	popup.open_workshop()
	popup.set_process(false)
	_check(popup.overlay.visible, "Workshop opens")
	_check(_sliders(popup) == 0, "Diegetic controls replace sliders")
	_check(is_equal_approx(popup.work.pace(), 0.25 if GameState.is_easy_difficulty() else 1.0), "Oscillation difficulty speed")

func _act(name: String, value: float = 0.0, index: int = -1) -> void:
	popup._act(name, value, index)

func _roundtrip() -> void:
	var encoded := JSON.stringify(popup.work.snapshot())
	var copy := Work.new(popup.work.workshop, popup.work.easy)
	copy.restore(JSON.parse_string(encoded))
	_check(JSON.parse_string(JSON.stringify(copy.snapshot())) == JSON.parse_string(encoded), "Every stage checkpoint round-trips as JSON")

func _stage(expected: int) -> void:
	_check(popup.work.stage == expected and not popup.work.paused, "Reached stage " + str(expected + 1))
	_roundtrip()

func _review() -> void:
	var stage: int = popup.work.stage
	var clock: float = popup.work.clock
	var remaining := Campaign.remaining()
	_check(popup.work.paused and popup.retry_notice.visible, "Error opens frozen technical review")
	popup._process(20.0)
	_act("confirm")
	_check(popup.work.clock == clock and Campaign.remaining() == remaining, "Review cannot drain timers or repeated chances")
	_roundtrip()
	popup._resume()
	_check(not popup.work.paused and popup.work.stage == stage, "Continue preserves current stage")

func _mine() -> void:
	_open(0)
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.keycode = KEY_TAB
	tab.pressed = true
	popup._input(tab)
	_check(popup.actions.is_ancestor_of(get_viewport().gui_get_focus_owner()) and popup.chosen_action == "confirm", "Tab selects the next actual tool")
	tab.shift_pressed = true
	popup._input(tab)
	_check(popup.chosen_action == "vent", "Shift-Tab selects the previous tool without leaving the modal")
	await _shot("01_mina_lampara")
	_act("confirm")
	_check(Campaign.remaining() == Campaign.total() - 1, "A mistake costs exactly one opportunity")
	await _shot("02_revision")
	_review()
	_act("adjust", 0.5)
	for index in 3: _act("vent")
	_act("confirm")
	_stage(1)
	for index in [0, 2, 4]: _act("inspect", 0.0, index)
	_stage(2)
	# The real hit control validates the oscillator; do not bypass the validation.
	popup.work.clock = 0.4
	_act("hit")
	_review()
	for index in 6:
		popup.work.clock = 0.0
		_act("hit")
	_stage(3)
	for index in 6: _act("sort", 1.0 if index % 2 == 0 else 0.0, index)
	_stage(4)
	# Exercise touch using the same physical gate hit area as the renderer.
	popup.bench.zones.clear()
	popup.bench.zones.append({"rect": Rect2(100, 50, 160, 230), "action": "gate", "index": 0})
	_touch(Vector2(165, 145), true)
	_drag(Vector2(165, 170))
	_touch(Vector2(165, 170), false)
	_check(is_equal_approx(float(popup.work.data.gates[0]), 0.5), "Touch drag adjusts a wooden gate")
	for index in 3: _act("adjust", 0.5, index)
	popup._process(1.3)
	_stage(5)
	await _shot("03_mina_cabrestante")
	_act("adjust", 0.5)
	for index in 24:
		if popup.work.complete: break
		_act("crank", 0.12)
		popup._process(0.2)
	_check(Campaign.done("mine") and Campaign.unlocked("forge"), "Coal unlocks foundry")
	_check(Campaign.remaining() == Campaign.total() - 2, "Budget keeps mine errors")

func _forge() -> void:
	_open(1)
	_check(Campaign.remaining() == Campaign.total() - 2, "Entering a workshop does not reset shared budget")
	for index in 3: _act("ore")
	for index in 2: _act("fuel")
	_act("confirm")
	_stage(1)
	await _shot("04_pudelado")
	for index in 100:
		if popup.work.stage != 1: break
		_act("stir", 0.2)
	_stage(2)
	for index in 3: _act("skim", 0.0, index)
	_stage(3)
	_act("transfer")
	_stage(4)
	for index in 8:
		popup.work.clock = 0.0
		_act("hit", 0.0, index / 2)
	_stage(5)
	for index in 6: _act("cool", 0.1)
	_act("adjust", 0.5)
	_act("confirm")
	_check(Campaign.done("forge") and Campaign.unlocked("engine"), "Forged connecting rod unlocks engine")

func _engine() -> void:
	_open(2)
	_act("piston")
	_act("packing")
	for index in [0, 2, 1, 3]: _act("bolt", 0.0, index)
	_stage(1)
	for index in 3:
		_act("washer", 0.0, index)
		_act("pipe", 0.0, index)
	_stage(2)
	# Public keyboard input, using the same adjustment as mouse/touch.
	popup.work.data.adjust = 0.49
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	popup._unhandled_key_input(key)
	key.pressed = false
	popup._input(key)
	_check(is_equal_approx(float(popup.work.data.adjust), 0.5), "Keyboard adjusts eccentric linkage")
	_act("confirm")
	_stage(3)
	_act("adjust", 0.5)
	for index in 3: _act("arm", 0.0, index)
	_stage(4)
	_act("ball", 0.0, 0)
	_act("ball", 0.0, 1)
	_act("link")
	_stage(5)
	await _shot("05_motor_presion")
	popup.work.data.pressure = 1.0
	popup.work.data.inlet = 1.0
	popup._process(popup.work.grace() - 0.1)
	_check(not popup.work.paused, "Critical correction grace period")
	popup._process(0.11)
	_review()
	_act("adjust", 0.5)
	_act("purge")
	popup._process(1.3)
	_check(Campaign.done("engine") and Campaign.unlocked("textile"), "Steady 15 PSI unlocks mechanical power")

func _textile() -> void:
	_open(3)
	await _shot("06a_telares_sin_correas")
	for index in 4:
		_act("belt", 0.0, index)
		if index == 1: await _shot("06b_telares_dos_correas")
	_stage(1)
	for index in 4: _act("adjust", 0.5, index)
	_act("confirm")
	_stage(2)
	for index in 4: _act("clutch", 0.0, index)
	_stage(3)
	_act("start")
	popup.work.data.broken[2] = true
	popup.bench.zones.clear()
	popup.bench.zones.append({"rect": Rect2(350, 145, 100, 100), "action": "loom", "index": 2})
	for operation in 3:
		_touch(Vector2(390, 180), true)
		_touch(Vector2(390, 180), false)
	_check(not bool(popup.work.data.broken[2]) and not bool(popup.work.data.stopped[2]), "Direct touch stops, knots and restarts a broken loom")
	_act("emergency")
	popup._process(10.0)
	_check(is_zero_approx(float(popup.work.data.elapsed)), "Emergency stop freezes production clock")
	_act("start")
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	popup._process(10.0)
	_check(is_zero_approx(float(popup.work.data.elapsed)), "Focus loss freezes shift")
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _shot("06_telares_turno")
	for step in 1200:
		var d: Dictionary = popup.work.data
		for index in 4:
			if bool(d.broken[index]):
				_act("stop", 0.0, index)
				_act("knot", 0.0, index)
				_act("restart", 0.0, index)
			if float(d.stocks[index]) < 0.2: _act("refill", 0.0, index)
		if float(d.pressure) < 0.49: _act("feed")
		popup._process(0.1)
		if step == 600:
			_roundtrip()
			_check(not popup.work.complete and is_equal_approx(float(d.elapsed), 60.1), "Shift uses real 120 simulation seconds in either difficulty")
	_check(not popup.work.paused, "Production has no unexplained failures")
	# Floating point clock may finish on the first frame after 120.0.
	if not popup.work.complete: popup._process(0.01)
	_check(Campaign.done("textile"), "Ten bales delivered at the two-minute whistle")
	_check(Campaign.remaining() == Campaign.total() - 3, "One shared budget survives all four workshops")

func _save_load() -> void:
	GameState.phase_summary = {"fase": "El éxodo rural", "tiempo_segundos": 123, "puzzles": []}
	GameState.checkpoint = {"scene": GameState.PHASE_TWO_SCENE, "journal_open": true, "journal_page": 1}
	GameState.save_progress()
	var encoded := JSON.stringify(GameState.phase_two)
	GameState.phase_two = {}
	_check(GameState.load_progress(), "Saved chapter can be read")
	_check(JSON.parse_string(JSON.stringify(GameState.phase_two)) == JSON.parse_string(encoded), "All chapter state, metrics and inventory survive save/load")
	_check(int(GameState.phase_summary.tiempo_segundos) == 123, "Chapter 1 historical summary stays intact")
	_check(str(GameState.checkpoint.scene) == GameState.PHASE_TWO_SCENE, "Continue points to factory hub")

func _exhaustion() -> void:
	var completed: Array = GameState.phase_two.completed.duplicate()
	var state := Work.new("mine", GameState.is_easy_difficulty())
	state.stage = 4
	while Campaign.remaining() > 0: Campaign.fail("mine", "Prueba de agotamiento")
	_check(Campaign.remaining() == 0, "Budget stops at zero")
	Campaign.new_round()
	_check(Campaign.remaining() == Campaign.total() and GameState.phase_two.completed == completed, "New round restores budget and preserves finished workshops")
	state.paused = true
	state.data.marks = [0, 2]
	state.resume()
	_check(state.stage == 4 and state.data.marks == [0, 2], "Reattempt preserves finished substeps")

func _intro_and_journal() -> void:
	var intro := preload("res://scenes/story/phase2_intro.tscn").instantiate()
	add_child(intro)
	await get_tree().process_frame
	_check(intro.STORY_IMAGES.size() == 4, "Four illustrated introduction pages")
	intro.current_index = 3
	intro.is_overlay = false
	intro._show_page(false)
	_check(intro.next_button.text == "Empezar segunda fase", "Final intro button label")
	intro.queue_free()
	hub.dialogue.hide()
	hub._show_journal()
	_check(hub.journal.current_page == 2, "Pause opens live factory page")
	hub.journal.turn_to(1)
	_check(hub.journal.current_page == 1, "Previous chapter remains readable")
	hub.journal.turn_to(2)
	await _shot("07_cuaderno_fase2", true)
	_check(hub.journal.factory_statuses.size() == 4, "Journal tracks four industrial workshops")
	hub._hide_journal()

func _fault_recovery() -> void:
	var easy := GameState.is_easy_difficulty()
	var transfer := Work.new("forge", easy)
	transfer.stage = 3
	transfer.data.heat = 0.85 - transfer.tolerance() - 0.01
	transfer.action("transfer")
	_check(transfer.paused, "Confirmed transfer respects the difficulty thermal margin")
	transfer.resume()
	transfer.action("transfer")
	_check(transfer.stage == 4 and not transfer.paused, "Reheated iron remains transferable after review")
	var cases: Array = [
		["mine", 1, "inspect", 0.0, 1], ["mine", 3, "sort", 0.0, 0],
		["forge", 0, "confirm", 0.0, 0], ["forge", 4, "hit", 0.0, 3], ["forge", 5, "cool", 0.5, 0],
		["engine", 0, "bolt", 0.0, 0], ["engine", 1, "pipe", 0.0, 0], ["engine", 2, "confirm", 0.0, 0], ["engine", 3, "arm", 0.0, 0], ["engine", 4, "link", 0.0, 0],
		["textile", 1, "confirm", 0.0, 0], ["textile", 3, "knot", 0.0, 0]
	]
	for specification in cases:
		var state := Work.new(str(specification[0]), easy)
		state.stage = int(specification[1])
		state.action(str(specification[2]), float(specification[3]), int(specification[4]))
		_check(state.paused and not state.retry_reason.is_empty(), "Technical cause for " + str(specification[0]) + " stage " + str(specification[1]))
		var snapshot := state.snapshot()
		state.tick(100.0)
		_check(state.snapshot() == snapshot, "Failure freezes every simulation field")
		state.resume()
		_check(not state.paused and state.stage == int(specification[1]), "Recovery never restarts an earlier stage")
	# Timed hazards allow correction, then penalize only once at the profile deadline.
	for id in ["mine", "forge"]:
		var state := Work.new(id, easy)
		state.stage = 4 if id == "mine" else 1
		if id == "mine":
			for gate in 3: state.action("adjust", 1.0, gate)
		else: state.data.heat = 0.2
		state.tick(state.grace() - 0.1)
		_check(not state.paused, "Thermal/airflow hazard offers correction grace")
		state.tick(0.11)
		_check(state.paused, "Thermal/airflow hazard eventually triggers review")
		state.resume()
		if id == "mine":
			for gate in 3: state.action("adjust", 0.5, gate)
		else: state.action("heat")
		state.tick(0.1)
		_check(not state.paused, "Corrected hazard stays controllable after retry")

func _small_window() -> void:
	var old := get_window().size
	get_window().size = Vector2i(720, 480)
	await get_tree().process_frame
	await get_tree().process_frame
	popup._fit()
	var end: Vector2 = popup.panel.position + popup.panel.size * popup.panel.scale
	var visible := get_viewport().get_visible_rect().size
	_check(popup.panel.position.x >= 0 and popup.panel.position.y >= 0 and end.x <= visible.x and end.y <= visible.y, "Workshop fits small window")
	get_window().size = old

func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	popup.bench._gui_input(event)

func _drag(point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	popup.bench._gui_input(event)

func _sliders(node: Node) -> int:
	var count := 1 if node is Slider else 0
	for child in node.get_children(): count += _sliders(child)
	return count

func _shot(name: String, journal_only: bool = false) -> void:
	if not capture: return
	if not journal_only: popup._sync()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://output/ui/phase2")
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder + "/" + prefix + "_" + name + ".png")
	# The user's desktop may take foreground focus during a screenshot. Simulation
	# steps below are deliberate test input; restore focus deterministically.
	if popup != null: popup._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("PHASE 2 CHECK FAILED: " + description)
		if not aborting:
			aborting = true
			_abort.call_deferred()

func _abort() -> void:
	GameState.run_started = false
	Phase2Metrics.set_process(false)
	Phase2Metrics.flush()
	_restore_files()
	get_tree().quit(1)

func _restore_files() -> void:
	for path in backups:
		if backups[path] != null: FileAccess.open(path, FileAccess.WRITE).store_buffer(backups[path])
		elif FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
