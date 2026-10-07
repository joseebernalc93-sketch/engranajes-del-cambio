extends Node

func _ready() -> void:
	GameState.reset_progress(false)
	GameState.flags["mill_repaired"] = true
	GameState.inventory = {"trigo": 3}
	var mill = preload("res://scenes/mill_interior.tscn").instantiate()
	add_child(mill)
	await get_tree().process_frame
	mill.get_node("HUD")._select_dialogue_action("open_mill_operation")
	var popup = mill.get_node("MillOperationPopup")
	popup.set_process(false)
	popup.open_gate_button.button_down.emit()
	for frame in 240:
		popup._process(1.0 / 60.0)
	popup.open_gate_button.button_up.emit()
	for frame in 700:
		popup._process(1.0 / 60.0)
	assert(popup.ready_seconds >= popup.READY_SECONDS)
	await _capture("ready")
	popup.load_button.pressed.emit()
	popup.open_gate_button.button_down.emit()
	for frame in 75:
		popup._process(1.0 / 60.0)
	popup.open_gate_button.button_up.emit()
	for frame in 180:
		popup._process(1.0 / 60.0)
	assert(popup.processing_batch and popup._rpm_is_safe())
	await _capture("grinding")
	print("MILL CONTROLS SCREENSHOTS OK")
	get_tree().quit()

func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	assert(screenshot.save_png(ProjectSettings.globalize_path("res://tmp/mill_buttons_%s_preview.png" % name)) == OK)
