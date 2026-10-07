extends Node
## Exercise the six phases through native controls in both difficulty profiles.
var backups := {}
var popup: Node
var hud: Node
var capture := false
var green_windows := {}

func _ready() -> void:
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	capture = capture or "--capture-lumber" in OS.get_cmdline_user_args()
	var island = preload("res://scenes/wood_island.tscn").instantiate()
	add_child(island)
	await get_tree().process_frame
	assert(island.get_node_or_null("World/Bruno"))
	assert(island.get_node_or_null("World/BoatToLakeDock"))
	popup = island.get_node("LumberPuzzlePopup")
	hud = island.get_node("HUD")
	# Deterministic tool stepping; real timers still drive guarded phase transitions.
	popup.set_process(false)
	for mode in [GameState.DIFFICULTY_HARD, GameState.DIFFICULTY_EASY]:
		await _round(mode)
		await _exhaustion(mode)
	await _cancelled_transition()
	# A difficulty change retains spent attempts rather than granting a fresh pool.
	GameState.reset_progress(false)
	GameState.set_difficulty(GameState.DIFFICULTY_EASY)
	GameState.flags["lumber_attempts_spent"] = 9
	GameState.set_difficulty(GameState.DIFFICULTY_HARD)
	assert(GameState.get_lumber_attempts_left() == 1)
	GameState.set_difficulty(GameState.DIFFICULTY_EASY)
	assert(GameState.get_lumber_attempts_left() == 6)
	for path in backups:
		if backups[path] != null:
			FileAccess.open(path, FileAccess.WRITE).store_buffer(backups[path])
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LUMBER SIX PHASES OK: both profiles, native tools, persistence, budgets, recovery, unique reward and mill installation")
	get_tree().quit()


func _round(mode: String) -> void:
	GameState.reset_progress(false)
	GameState.set_difficulty(mode)
	var budget := 15 if mode == GameState.DIFFICULTY_EASY else 10
	var prefix := "facil" if budget == 15 else "dificil"
	var dialogue := {}
	EventBus.dialogue_requested.connect(func(payload: Dictionary): dialogue.merge(payload), CONNECT_ONE_SHOT)
	GameState.interact("lumberjack")
	assert(dialogue.get("speaker", "").contains("Bruno"))
	hud._select_dialogue_action("open_lumber_puzzle")
	assert(popup.overlay.visible and popup.stage == popup.STAGE_INSPECT)
	assert(not get_tree().get_first_node_in_group("player").controls_enabled)
	assert(GameState.get_lumber_attempts_left() == budget)
	assert(popup.workshop_texture.texture.resource_path.ends_with("bruno_workshop_backdrop_v2.png"))
	await _shot(prefix + "_01_veta")
	_click_workbench(Vector2(290, 90))
	await _shot(prefix + "_08_error_veta")
	assert(popup.workbench.inspected[1] and popup.stage == popup.STAGE_INSPECT)
	assert(GameState.get_lumber_attempts_left() == budget - 1)
	_continue_after_error()
	popup.straight_grain.pressed.emit()
	await get_tree().create_timer(0.8).timeout
	assert(popup.stage == popup.STAGE_MEASURE)
	# Confirming an incorrect measurement costs one; clicking another chalk target does not.
	popup.marking_meter.value = 0.5
	popup.mark_button.pressed.emit()
	await _shot(prefix + "_09_error_medicion")
	assert(GameState.get_lumber_attempts_left() == budget - 2)
	_continue_after_error()
	popup.length_slider.value = 160
	popup.angle_slider.value = 90
	_click_workbench(Vector2(550, 78))
	assert(GameState.get_lumber_attempts_left() == budget - 2)
	_continue_after_error()
	popup.marking_meter.value = 0.5
	_click_workbench(Vector2(90, 78))
	assert(popup.marked_lines == 1)
	popup.close()
	assert(GameState.load_progress())
	popup.open()
	assert(popup.stage == popup.STAGE_MEASURE and popup.marked_lines == 1)
	assert(popup.length_slider.value == 160 and popup.angle_slider.value == 90)
	assert(GameState.get_lumber_attempts_left() == budget - 2)
	_continue_after_error()
	# Measure the real moving needle's first safe interval: Easy takes > 3x as long.
	popup.work_clock = 0
	var ticks := 0
	while popup.marking_meter.value <= popup.marking_meter.high and ticks < 500:
		popup._process(0.01)
		ticks += 1
	assert(ticks > (70 if budget == 15 else 5))
	green_windows[mode] = ticks
	if budget == 15:
		assert(ticks > int(green_windows[GameState.DIFFICULTY_HARD]) * 3)
	await _shot(prefix + "_02_medicion")
	popup.marking_meter.value = 1
	popup.mark_button.pressed.emit()
	assert(popup.marked_lines == 1 and GameState.get_lumber_attempts_left() == budget - 3)
	_continue_after_error()
	popup.marking_meter.value = 0.5
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	assert(popup.marked_lines == 2)
	popup.marking_meter.value = 0.5
	_click_workbench(Vector2(550, 78))
	await get_tree().create_timer(0.8).timeout
	assert(popup.stage == popup.STAGE_SECURE)
	popup.stability_test.pressed.emit()
	assert(GameState.get_lumber_attempts_left() == budget - 4)
	_continue_after_error()
	for point in popup.workbench.FIX_POINTS:
		_click_workbench(point)
	assert(popup.setup_parts == 3)
	popup.clamp_slider.value = 60
	await _shot(prefix + "_03_fijacion")
	popup.stability_test.pressed.emit()
	await get_tree().create_timer(0.8).timeout
	assert(popup.stage == popup.STAGE_SAW)
	popup._complete_saw_stroke(false)
	assert(GameState.get_lumber_attempts_left() == budget - 5 and popup.saw_successes == 0)
	_continue_after_error()
	var grip_y: float = popup.saw_sprite.position.y - popup.saw_drag_area.position.y
	popup._begin_saw_stroke(Vector2(308, grip_y))
	popup._move_saw(Vector2(393, grip_y))
	popup._move_saw(Vector2(478, grip_y))
	assert(popup.saw_successes == 1)
	# Focus loss cancels only an unfinished gesture without charging an attempt.
	popup._begin_saw_stroke(Vector2(666, 60))
	popup._move_saw(Vector2(630, 60))
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not popup.dragging_saw and popup.saw_successes == 1)
	assert(GameState.get_lumber_attempts_left() == budget - 5)
	_continue_after_error()
	popup.close()
	popup.open()
	assert(popup.stage == popup.STAGE_SAW and popup.saw_successes == 1)
	assert(is_equal_approx(popup.cut_groove.size.y, 16))
	await _shot(prefix + "_04_serrar")
	for cut in range(1, 5):
		var key := KEY_RIGHT if popup.saw_expected_edge == 1 else KEY_LEFT
		_key(key, true)
		for tick in 55:
			popup._process(0.04)
		_key(key, false)
		assert(popup.saw_successes == cut + 1)
	await get_tree().create_timer(1.2).timeout
	assert(popup.stage == popup.STAGE_PLANE)
	popup._complete_planing_pass(false)
	assert(GameState.get_lumber_attempts_left() == budget - 6)
	_continue_after_error()
	popup.depth_slider.value = 50
	# Touch reversals are rejected without discarding completed lanes.
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(48, 26)
	popup._on_plane_drag_input(touch)
	var drag := InputEventScreenDrag.new()
	for x in [200, 140, 472]:
		drag.position = Vector2(x, 26)
		popup._on_plane_drag_input(drag)
	assert(popup.planing_passes == 0 and GameState.get_lumber_attempts_left() == budget - 7)
	_continue_after_error()
	# Pointer-held accessible control and Space both drive the real plane tool.
	popup._hold_plane()
	for tick in 85:
		popup._process(0.04)
	popup._release_plane()
	assert(popup.planing_passes == 1 and popup.planed_strips[0].size.x == 490)
	popup.close()
	popup.open()
	assert(popup.stage == popup.STAGE_PLANE and popup.planing_passes == 1)
	assert(popup.depth_slider.value == 50 and popup.planed_strips[0].size.x == 490)
	await _shot(prefix + "_05_cepillar")
	for lane in range(1, 4):
		_key(KEY_SPACE, true)
		for tick in 85:
			popup._process(0.04)
		_key(KEY_SPACE, false)
		assert(popup.planing_passes == lane + 1)
	await get_tree().create_timer(0.8).timeout
	assert(popup.stage == popup.STAGE_TEST)
	popup.sack_three.pressed.emit()
	assert(popup.load_sacks == 0)
	var sack_drag := {"kind": "lumber_sack", "index": 0, "session": popup.session_id}
	assert(not popup.workbench._can_drop_data(Vector2(50, 50), sack_drag))
	sack_drag.session -= 1
	assert(not popup.workbench._can_drop_data(Vector2(210, 95), sack_drag))
	sack_drag.session = popup.session_id
	assert(popup.workbench._can_drop_data(Vector2(210, 95), sack_drag))
	popup.workbench._drop_data(Vector2(210, 95), sack_drag)
	assert(popup.load_sacks == 1 and popup.action_locked)
	popup.brace_slider.value = 0
	for tick in 110:
		popup._process(0.05)
	assert(popup.verified_loads == 0 and popup.load_sacks == 0)
	assert(GameState.get_lumber_attempts_left() == budget - 8)
	_continue_after_error()
	for index in 3:
		popup.brace_slider.value = [42, 58, 72][index]
		[popup.sack_one, popup.sack_two, popup.sack_three][index].pressed.emit()
		popup._complete_lumber_puzzle()
		assert(not GameState.has_item("tabla"))
		if index == 1:
			await get_tree().create_timer(0.7).timeout
			popup._process(0.1)
			await _shot(prefix + "_06_carga")
		for tick in 90:
			# Adjust the support to compensate for the actual oscillating load.
			popup.brace_slider.value = [42, 58, 72][index] - sin((popup.work_clock + 0.05 * GameState.get_forge_indicator_speed()) * 2.4) * 7
			popup._process(0.05)
		assert(popup.verified_loads == index + 1)
		if index == 0:
			popup.close()
			popup.open()
			assert(popup.stage == popup.STAGE_TEST and popup.verified_loads == 1)
			assert(popup.sack_one.disabled and not popup.sack_two.disabled)
			popup.brace_slider.value = 0
			popup.sack_two.pressed.emit()
			for tick in 110:
				popup._process(0.05)
			assert(popup.verified_loads == 1 and popup.load_sacks == 1)
			assert(popup.sack_one.disabled and not popup.sack_two.disabled)
			assert(GameState.get_lumber_attempts_left() == budget - 9)
			_continue_after_error()
	await get_tree().create_timer(0.9).timeout
	assert(popup.stage == popup.STAGE_COMPLETE)
	assert(GameState.has_item("tabla") and GameState.flags.get("lumber_puzzle_completed", false))
	assert(int(GameState.metrics.get("saw_successes", 0)) == 5)
	assert(int(GameState.metrics.get("planing_passes", 0)) == 4)
	assert(int(GameState.metrics.get("lumber_load_sacks", 0)) == 3)
	assert(GameState.build_report().oportunidades_carpinteria == budget - 9)
	assert(GameState.get_rope_attempts_left() == budget and int(GameState.flags.forge_attempts_left) == budget)
	await _shot(prefix + "_07_terminada")
	assert(not GameState.complete_lumber_puzzle())
	assert(GameState.install_mill_part("tabla"))
	assert(not GameState.has_item("tabla") and GameState.flags.get("mill_plank_installed", false))
	popup.close()
	assert(get_tree().get_first_node_in_group("player").controls_enabled)
	print("LUMBER PROFILE OK: ", mode)


func _exhaustion(mode: String) -> void:
	GameState.reset_progress(false)
	GameState.set_difficulty(mode)
	popup.open()
	var budget := GameState.get_lumber_opportunities()
	var dialogue := {}
	EventBus.dialogue_requested.connect(func(payload: Dictionary): dialogue.merge(payload), CONNECT_ONE_SHOT)
	for attempt in budget:
		popup.radial_crack.pressed.emit()
		assert(GameState.get_lumber_attempts_left() == budget - attempt - 1)
		_continue_after_error()
	assert(not popup.overlay.visible)
	assert(dialogue.get("speaker", "").contains("Bruno"))
	assert(str(dialogue).contains("no te rindas"))
	popup.open()
	assert(not popup.overlay.visible)
	hud._select_dialogue_action("restart_lumber_round")
	assert(popup.overlay.visible and popup.stage == popup.STAGE_INSPECT)
	assert(GameState.get_lumber_attempts_left() == budget)
	popup.close()
	# Exhaust the last remaining attempt in a later phase, retaining finished work.
	GameState.flags.lumber_attempts_spent = budget - 1
	GameState.flags.lumber_progress = {"stage": popup.STAGE_PLANE, "selected": true, "marked_lines": 3, "fixations": [true, true, true], "secured": true, "cuts": 5, "passes": 2}
	popup.open()
	assert(popup.stage == popup.STAGE_PLANE and popup.planing_passes == 2)
	popup._complete_planing_pass(false)
	assert(not popup.overlay.visible and GameState.get_lumber_attempts_left() == 0)
	assert(GameState.flags.lumber_progress.passes == 2)
	hud._select_dialogue_action("restart_lumber_round")
	assert(popup.overlay.visible and popup.stage == popup.STAGE_INSPECT)
	popup.close()


func _cancelled_transition() -> void:
	GameState.reset_progress(false)
	popup.open()
	popup.straight_grain.pressed.emit()
	popup.close()
	popup.open()
	await get_tree().create_timer(0.9).timeout
	assert(popup.stage == popup.STAGE_MEASURE and not popup.action_locked)
	# A callback from a closed session cannot award a board in a fresh round.
	popup.stage = popup.STAGE_TEST
	popup.load_sacks = 3
	popup.verified_loads = 3
	popup._schedule_transition(0.1, popup._complete_lumber_puzzle)
	popup.close()
	GameState.reset_progress(false)
	popup.open()
	await get_tree().create_timer(0.2).timeout
	assert(popup.stage == popup.STAGE_INSPECT and not GameState.has_item("tabla"))
	popup.close()


func _click_workbench(point: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	popup.workbench._gui_input(click)


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	popup._input(event)


func _shot(name: String) -> void:
	if not capture:
		return
	var directory := "res://output/ui/lumber_six_phases"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if popup.awaiting_retry:
		assert(popup.retry_notice.card.size.y < 400)
		assert(popup.retry_notice.card.position.y > 0)
	assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(directory + "/" + name + ".png")) == OK)

func _continue_after_error() -> void:
	if not popup.awaiting_retry:
		return
	assert(popup.retry_notice.visible and popup.action_locked)
	assert(popup.retry_notice.heading.text.contains("Bruno"))
	assert(not popup.retry_notice.reason_label.text.is_empty())
	var remaining := GameState.get_lumber_attempts_left()
	var old_stage: int = popup.stage
	var old_clock: float = popup.work_clock
	assert(popup.retry_notice.continue_button.text.ends_with("%d / %d" % [remaining, GameState.get_lumber_opportunities()]))
	popup._process(30)
	popup._register_mistake()
	assert(GameState.get_lumber_attempts_left() == remaining and popup.stage == old_stage)
	assert(popup.work_clock == old_clock)
	# Space dismisses only the notice; it does not also start a tool stroke.
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	assert(not popup.awaiting_retry and not popup.retry_notice.visible and not popup.action_locked)
	assert(not popup.dragging_saw and not popup.dragging_plane)
