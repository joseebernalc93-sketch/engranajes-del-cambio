extends Node


func _ready() -> void:
	GameState.reset_progress(false)
	var yard = preload("res://scenes/spinner_yard.tscn").instantiate()
	add_child(yard)
	await get_tree().process_frame
	var popup = yard.get_node("RopePuzzlePopup")
	popup.open()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_prepare_preview.png")

	for button_name in ["HempLong", "HempFlexible", "HempClean"]:
		popup.get_node("%%%s" % button_name).pressed.emit()
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_combing_preview.png")
	for index in 3:
		popup._select_bundle(index)
		popup._perform_precision(0.5)
		popup._perform_precision(0.5)
	await get_tree().create_timer(0.75).timeout
	popup.feed_slider.value = 60
	popup.get_node("%HookTop").pressed.emit()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_strands_preview.png")
	for button_name in ["HookTop", "HookMiddle", "HookBottom"]:
		popup.get_node("%%%s" % button_name).pressed.emit()
	await get_tree().create_timer(0.75).timeout
	popup.carriage_slider.value = 45.0
	popup._set_cranking(true)
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_tension_preview.png")
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_rotation_preview.png")
	popup.carriage_slider.value = 79.0
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_overload_preview.png")
	popup._set_cranking(false)
	popup.carriage_slider.value = 45.0
	popup.tension = 57.0
	popup._set_cranking(true)
	for tick in 170:
		popup._process(0.1)
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_FINISH)
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_finish_preview.png")
	popup.seizing_knot.pressed.emit()
	for wrap in 3:
		popup._perform_precision(0.5)
	await get_tree().create_timer(1.15).timeout
	assert(popup.stage == popup.STAGE_PROOF)
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_proof_ready_preview.png")
	popup.proof_keyboard_held = true
	popup.set_process(false)
	popup._set_testing(true)
	for tick in 23:
		popup.proof_brake_slider.value = 50.0 + popup.proof_checks * 9.0 / 0.65
		popup._process(0.1)
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_proof_preview.png")
	for tick in 40:
		popup.proof_brake_slider.value = 50.0 + popup.proof_checks * 9.0 / 0.65
		popup._process(0.1)
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_COMPLETE)
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_complete_preview.png")
	DisplayServer.window_set_size(Vector2i(960, 540))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_save_capture("res://tmp/rope_puzzle_small_preview.png")
	print("ROPE CAPTURE OK: all stages, rotating wheel, warning, load proof, completion and small window")
	get_tree().quit()


func _save_capture(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	assert(image.save_png(ProjectSettings.globalize_path(path)) == OK)
