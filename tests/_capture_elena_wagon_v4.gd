extends Node

var popup: Node
var frame := 0


func _ready() -> void:
	GameState.reset_progress(false)
	GameState.flags["flour_sold"] = true
	var village = preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().process_frame
	popup = village.get_node("MigrationCartPopup")
	popup.set_process(false)
	popup.cart_display.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/elena_wagon_v4_motion"))
	await _frames(30)
	await _capture("village_before")
	popup.open()
	await _frames(18)
	for id in ["alimentos", "herramientas", "retrato", "semillas"]:
		popup._toggle_item(true, id)
		await _frames(17)
	await _capture("cargo")
	assert(popup._packed_weight() == 7 and popup._packing_is_valid())
	popup._continue_stage()
	await _frames(15)
	popup.balance_slider.value = 50.0
	await _frames(26)
	await _capture("balance")
	popup._continue_stage()
	popup._try_old_road()
	await _frames(22)
	popup._choose_long_road()
	await _frames(22)
	await _capture("route")
	popup._continue_stage()
	popup.space_held = true
	await _frames(64)
	await _capture("horse_walk")
	popup.space_held = false
	await _frames(18)
	await _capture("rest")
	popup.space_held = true
	while popup.stage == popup.STAGE_TRAVEL:
		await _frames(1)
	await _frames(25)
	popup._choose_priority("recuerdo familiar")
	popup.pointer_held = true
	await _frames(38)
	await _capture("recovery")
	while popup.stage == popup.STAGE_RECOVER:
		await _frames(1)
	popup.pointer_held = true
	while popup.stage == popup.STAGE_TRAVEL:
		await _frames(1)
	assert(popup.completed)
	await _frames(28)
	await _capture("arrival")
	popup.close()
	await _frames(30)
	await _capture("village_after")
	for prop in ["ElenaMigrationCart", "ElenaMigrationCartCollision", "ElenaHorseCollision"]:
		assert(not village.has_node("World/" + prop))
	print("ELENA WAGON V4 CAPTURE OK: %d frames, courtyard, four contained objects, walking horse, rescue and departure" % frame)
	get_tree().quit()


func _frames(count: int) -> void:
	for tick in count:
		popup._process(0.05)
		popup.cart_display._process(0.05)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_jpg(ProjectSettings.globalize_path("res://tmp/elena_wagon_v4_motion/%04d.jpg" % frame), 0.94) == OK)
		frame += 1


func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/elena_wagon_v4_%s.png" % name)) == OK)
