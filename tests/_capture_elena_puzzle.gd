extends Node

var popup: Node

func _ready() -> void:
	GameState.reset_progress(false)
	GameState.flags["flour_sold"] = true
	var village = preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	await get_tree().process_frame
	popup = village.get_node("MigrationCartPopup")
	popup.open()
	popup.set_process(false)
	await _capture("packing")
	for id in ["alimentos", "herramientas", "retrato"]:
		popup._toggle_item(true, id)
	await get_tree().create_timer(0.75).timeout
	popup._continue_stage()
	await _capture("balance")
	popup.balance_slider.value = 50.0
	for tick in 12:
		popup._process(0.1)
	popup._continue_stage()
	popup._try_old_road()
	await _capture("gate")
	popup._choose_long_road()
	await _capture("route")
	popup._continue_stage()
	popup.space_held = true
	for tick in 80:
		popup._process(0.1)
	assert(popup.stage == popup.STAGE_DECISION)
	await _capture("mud")
	popup._choose_priority("recuerdo familiar")
	popup.space_held = true
	for tick in 19:
		popup._process(0.1)
	await _capture("recovery")
	for tick in 22:
		popup._process(0.1)
	assert(popup.mud_recovered)
	popup.space_held = true
	for tick in 90:
		popup._process(0.1)
	assert(popup.completed)
	await _capture("complete")
	print("ELENA SCREENSHOTS OK")
	get_tree().quit()

func _capture(stage_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	assert(screenshot.save_png(ProjectSettings.globalize_path("res://tmp/elena_%s_preview.png" % stage_name)) == OK)
