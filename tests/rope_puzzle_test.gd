extends Node

var backups: Dictionary = {}
var capturing := false
var hard_precision_window := 0.0
const OUTPUT := "D:/UG/Tesis/Balla/Juego/engranajes-del-cambio/output/ui/rope_six_phases/"

func _ready() -> void:
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	capturing = "--capture-rope" in OS.get_cmdline_user_args()
	await _workshop(GameState.DIFFICULTY_HARD)
	await _workshop(GameState.DIFFICULTY_EASY)
	await _exhaustion_and_restart()
	for path in backups:
		if backups[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backups[path])
	print("ROPE SIX PHASES OK: both profiles, full workshop, controls, timing, partial recovery, saves, exhaustion/restart, unique reward and mill installation")
	get_tree().quit()

func _workshop(mode: String) -> void:
	GameState.set_difficulty(mode)
	GameState.reset_progress(false)
	var yard = preload("res://scenes/spinner_yard.tscn").instantiate()
	add_child(yard)
	await get_tree().process_frame
	var popup = yard.get_node("RopePuzzlePopup")
	popup.set_process(false)
	GameState.interact("spinner")
	yard.get_node("HUD")._select_dialogue_action("open_rope_puzzle")
	assert(popup.overlay.visible and popup.stage == popup.STAGE_PREPARE)
	var maximum := 15 if mode == GameState.DIFFICULTY_EASY else 10
	assert(GameState.get_rope_attempts_left() == maximum)
	assert(not yard.get_node("World/Player").controls_enabled)
	await _image("01_fibras")
	popup.dry_straw.pressed.emit()
	await _image("08_error_fibras")
	assert(GameState.get_rope_attempts_left() == maximum - 1 and popup.stage == popup.STAGE_PREPARE)
	_continue_after_error(popup)
	popup.hemp_long.pressed.emit()
	popup.close()
	assert(yard.get_node("World/Player").controls_enabled)
	popup.open()
	assert(popup.cleaned_fibers == 1 and GameState.get_rope_attempts_left() == maximum - 1)
	_continue_after_error(popup)
	popup.hemp_flexible.pressed.emit()
	popup.hemp_clean.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_COMB)
	await _image("02_peinado")
	var available_window := _measure_green_window(popup)
	if mode == GameState.DIFFICULTY_HARD:
		hard_precision_window = available_window
	else:
		assert(available_window >= hard_precision_window * 3.0)
	popup._perform_precision(0.0)
	await _image("09_error_peinado")
	assert(GameState.get_rope_attempts_left() == maximum - 2)
	_continue_after_error(popup)
	popup._perform_precision(0.5)
	popup.close()
	assert(GameState.load_progress())
	popup.open()
	assert(popup.stage == popup.STAGE_COMB and int(popup.comb_passes[0]) == 1)
	# Direct dragging and Space share validation, without double actions on release.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(30, 46)
	popup.craft_display.cursor = 0.0
	popup.craft_display._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = Vector2(220, 46)
	popup.craft_display._gui_input(motion)
	press.pressed = false
	popup._input(press)
	popup.craft_display._gui_input(press)
	assert(int(popup.comb_passes[0]) == 2)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	for bundle in [1, 2]:
		popup._select_bundle(bundle)
		for pass_index in 2:
			popup.craft_display.cursor = 0.5
			popup._input(space)
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_STRANDS and popup.comb_passes == [2, 2, 2])
	assert(popup.get_node("%FeedSafeBand").is_visible_in_tree())
	assert(popup.get_node("%FeedSafeBand").size.x > 0)
	await _image("03_cabos")
	popup.feed_slider.value = 15
	popup.hook_top.pressed.emit()
	assert(popup.mounted_strands == 0 and GameState.get_rope_attempts_left() == maximum - 3)
	_continue_after_error(popup)
	popup.feed_slider.value = 60
	popup.machine_display.hook_selected.emit(1)
	popup.hook_top.pressed.emit()
	popup.feed_slider.value = 95
	popup.hook_bottom.pressed.emit()
	assert(popup.mounted_strands == 2 and GameState.get_rope_attempts_left() == maximum - 4)
	_continue_after_error(popup)
	popup.close()
	popup.open()
	assert(popup.stage == popup.STAGE_STRANDS and popup.mounted_strands == 2)
	popup.feed_slider.value = 60
	popup.hook_bottom.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_TENSION)
	await _image("04_torsion")
	# An overload uses one chance and engages the brake without erasing the twist.
	popup.carriage_slider.value = 100
	popup.tension = 90
	popup._set_cranking(true)
	for tick in (45 if mode == GameState.DIFFICULTY_EASY else 15):
		popup._process(0.1)
	assert(not popup.crank_held and GameState.get_rope_attempts_left() == maximum - 5)
	_continue_after_error(popup)
	popup._process(1.1)
	popup.carriage_slider.value = 45
	popup.tension = 55
	popup._set_cranking(true)
	for tick in 35:
		popup._process(0.1)
	var partial: float = popup.twist_progress
	popup._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not popup.crank_held and not popup.proof_held)
	popup.close()
	popup.open()
	assert(popup.stage == popup.STAGE_TENSION and is_equal_approx(popup.twist_progress, partial))
	popup._set_cranking(true)
	for tick in 160:
		popup._process(0.1)
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_FINISH and popup.twist_progress == 100)
	assert(int(GameState.metrics.get("rope_twists", 0)) == popup.REQUIRED_TWISTS)
	await _image("05_remate")
	popup.loose_knot.pressed.emit()
	assert(GameState.get_rope_attempts_left() == maximum - 6 and popup.stage == popup.STAGE_FINISH)
	_continue_after_error(popup)
	popup.seizing_knot.pressed.emit()
	assert(popup.binding_started and popup.stage == popup.STAGE_FINISH and not GameState.has_item("cuerda"))
	popup._perform_precision(0.5)
	popup._perform_precision(0.0)
	assert(popup.binding_wraps == 1 and GameState.get_rope_attempts_left() == maximum - 7)
	_continue_after_error(popup)
	popup.close()
	popup.open()
	assert(popup.stage == popup.STAGE_FINISH and popup.binding_wraps == 1 and popup.binding_button.visible)
	await _image("05_ligadura")
	popup._perform_precision(0.5)
	popup._perform_precision(0.5)
	await get_tree().create_timer(1.05).timeout
	assert(popup.stage == popup.STAGE_PROOF and popup.machine_display.binding >= 0.99)
	popup._complete_rope_puzzle()
	assert(not GameState.has_item("cuerda"))
	await _image("06_carga")
	popup.proof_brake_slider.value = 100
	popup._set_testing(true)
	for tick in (75 if mode == GameState.DIFFICULTY_EASY else 35):
		popup._process(0.1)
	assert(not popup.proof_held and popup.proof_checks == 0)
	assert(GameState.get_rope_attempts_left() == maximum - 8)
	_continue_after_error(popup)
	popup.proof_brake_slider.value = 50
	popup._set_testing(true)
	for tick in (34 if mode == GameState.DIFFICULTY_EASY else 21):
		popup._process(0.1)
	assert(popup.proof_checks == 1)
	popup._release_all_controls()
	popup.close()
	popup.open()
	assert(popup.stage == popup.STAGE_PROOF and popup.proof_checks == 1)
	popup._set_testing(true)
	for tick in 60:
		popup.proof_brake_slider.value = 50.0 + popup.proof_checks * 9.0 / 0.65
		popup._process(0.1)
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_COMPLETE)
	assert(GameState.flags["rope_puzzle_completed"] and GameState.inventory.get("cuerda", 0) == 1)
	await _image("07_terminada")
	popup._complete_rope_puzzle()
	assert(GameState.inventory.get("cuerda", 0) == 1)
	assert(GameState.install_mill_part("cuerda") and not GameState.has_item("cuerda"))
	assert(GameState.flags["rope_progress"].is_empty())
	popup.close()
	assert(not popup.machine_display.active and not popup.mechanism_audio.playing)
	yard.queue_free()
	await get_tree().process_frame

func _exhaustion_and_restart() -> void:
	for mode in [GameState.DIFFICULTY_EASY, GameState.DIFFICULTY_HARD]:
		GameState.set_difficulty(mode)
		GameState.reset_progress(false)
		var popup = preload("res://scenes/ui/rope_puzzle_popup.tscn").instantiate()
		add_child(popup)
		popup.set_process(false)
		popup.open()
		var maximum := GameState.get_rope_opportunities()
		var dialogue := {}
		EventBus.dialogue_requested.connect(func(payload: Dictionary): dialogue.merge(payload), CONNECT_ONE_SHOT)
		for index in maximum:
			popup.dry_straw.pressed.emit()
			_continue_after_error(popup)
		assert(GameState.get_rope_attempts_left() == 0 and not popup.overlay.visible)
		assert(dialogue.get("speaker", "").contains("Silas") and dialogue.get("text", "").contains("no te rindas"))
		popup.open()
		assert(not popup.overlay.visible)
		GameState._on_dialogue_action("restart_rope_round")
		assert(popup.overlay.visible and popup.stage == popup.STAGE_PREPARE)
		assert(GameState.get_rope_attempts_left() == maximum)
		# A timer belonging to the closed session cannot overwrite resumed work.
		for button in [popup.hemp_long, popup.hemp_flexible, popup.hemp_clean]:
			button.pressed.emit()
		popup.close()
		popup.open()
		await get_tree().create_timer(0.75).timeout
		assert(popup.stage == popup.STAGE_COMB)
		popup._perform_precision(0.0)
		GameState.set_difficulty(GameState.DIFFICULTY_HARD)
		assert(GameState.get_rope_attempts_left() == 9)
		GameState.set_difficulty(GameState.DIFFICULTY_EASY)
		assert(GameState.get_rope_attempts_left() == 14)
		popup.close()
		popup.queue_free()
		await get_tree().process_frame

func _image(suffix: String) -> void:
	if not capturing:
		return
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	# Initial notices must fit too, before any later phase changes their text.
	for child in get_children():
		var workshop = child.get_node_or_null("RopePuzzlePopup")
		if workshop and workshop.awaiting_retry:
			assert(workshop.retry_notice.card.size.y < 400)
			assert(workshop.retry_notice.card.position.y > 0)
	var prefix := "facil" if GameState.is_easy_difficulty() else "dificil"
	get_viewport().get_texture().get_image().save_png(OUTPUT + prefix + "_" + suffix + ".png")

func _measure_green_window(popup) -> float:
	popup.timing_clock = 0
	var duration := 0.0
	for tick in 200:
		popup._process(0.01)
		if popup.craft_display.cursor > popup.craft_display.green_max:
			break
		duration += 0.01
	return duration

func _continue_after_error(popup) -> void:
	if not popup.awaiting_retry:
		return
	assert(popup.retry_notice.visible and popup.action_locked)
	assert(popup.retry_notice.heading.text.contains("Silas"))
	assert(not popup.retry_notice.reason_label.text.is_empty())
	var remaining := GameState.get_rope_attempts_left()
	var old_stage: int = popup.stage
	var old_clock: float = popup.work_clock
	var old_timing: float = popup.timing_clock
	assert(popup.retry_notice.continue_button.text.ends_with("%d / %d" % [remaining, GameState.get_rope_opportunities()]))
	popup._process(30)
	popup._register_mistake()
	assert(GameState.get_rope_attempts_left() == remaining and popup.stage == old_stage)
	assert(popup.work_clock == old_clock and popup.timing_clock == old_timing)
	popup.retry_notice.continue_button.pressed.emit()
	assert(not popup.awaiting_retry and not popup.retry_notice.visible and not popup.action_locked)
