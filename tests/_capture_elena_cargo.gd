extends Node

var popup: Node
var frame := 0


func _ready() -> void:
	GameState.reset_progress(false)
	GameState.flags["flour_sold"] = true
	var village = preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	await get_tree().process_frame
	popup = village.get_node("MigrationCartPopup")
	popup.open()
	popup.set_process(false)
	popup.cart_display.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/elena_cargo_motion"))
	await _capture("selection")
	for index in popup.ITEM_ORDER.size():
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(65 + index * 115, 275) * popup.cart_display.size / popup.cart_display.DESIGN
		popup.cart_display._gui_input(motion)
		await _frames(22)
		await _capture(popup.ITEM_ORDER[index])
	for id in ["alimentos", "herramientas", "retrato"]:
		popup._toggle_item(true, id)
		await _frames(18)
	await _capture("loaded")
	popup._continue_stage()
	popup.balance_slider.value = 50
	await _frames(25)
	popup._continue_stage()
	popup._try_old_road()
	popup._choose_long_road()
	popup._continue_stage()
	popup.space_held = true
	await _frames(85)
	await _capture("travel")
	popup.close()
	popup.open()
	for id in ["mantas", "olla", "semillas"]:
		popup._toggle_item(true, id)
		await _frames(18)
	await _capture("alternate_load")
	popup._continue_stage()
	popup.balance_slider.value = 50
	await _frames(25)
	popup._continue_stage()
	popup._try_old_road()
	popup._choose_long_road()
	popup._continue_stage()
	popup.space_held = true
	await _frames(110)
	assert(popup.stage == popup.STAGE_DECISION)
	popup._choose_priority("herramientas")
	popup.space_held = true
	await _frames(28)
	await _capture("bound")
	print("ELENA CARGO CAPTURE OK: %d frames; six object previews, two loads, travel and bindings" % frame)
	get_tree().quit()


func _frames(count: int) -> void:
	for tick in count:
		popup._process(0.05)
		popup.cart_display._process(0.05)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_jpg(ProjectSettings.globalize_path("res://tmp/elena_cargo_motion/%04d.jpg" % frame), 0.94) == OK)
		frame += 1


func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/elena_cargo_%s_preview.png" % name)) == OK)
