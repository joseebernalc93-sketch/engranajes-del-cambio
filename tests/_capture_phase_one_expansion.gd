extends Node


func _ready() -> void:
	GameState.reset_progress(false)
	GameState.inventory = {"trigo": 3}
	GameState.flags["mill_repaired"] = true
	var mill_popup = preload("res://scenes/ui/mill_operation_popup.tscn").instantiate()
	add_child(mill_popup)
	await get_tree().process_frame
	mill_popup.open()
	mill_popup.gate_slider.value = 70.0
	mill_popup.rotation_speed = mill_popup.IDEAL_RPM
	mill_popup.ready_seconds = mill_popup.READY_SECONDS
	mill_popup._load_next_batch()
	mill_popup.grain_remaining = 0.62
	mill_popup._update_interface()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var mill_image := get_viewport().get_texture().get_image()
	assert(mill_image.save_png(ProjectSettings.globalize_path("res://tmp/mill_operation_preview.png")) == OK)
	mill_popup.free()
	await get_tree().process_frame

	GameState.flags["flour_sold"] = true
	var cart_popup = preload("res://scenes/ui/migration_cart_popup.tscn").instantiate()
	add_child(cart_popup)
	await get_tree().process_frame
	cart_popup.open()
	cart_popup.set_process(false)
	cart_popup._toggle_item(true, "alimentos")
	cart_popup._toggle_item(true, "herramientas")
	cart_popup._toggle_item(true, "retrato")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var cart_image := get_viewport().get_texture().get_image()
	assert(cart_image.save_png(ProjectSettings.globalize_path("res://tmp/migration_cart_preview.png")) == OK)
	cart_popup._continue_stage()
	cart_popup.balance_slider.value = 50.0
	for tick in 12:
		cart_popup._process(0.1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var balance_image := get_viewport().get_texture().get_image()
	assert(balance_image.save_png(ProjectSettings.globalize_path("res://tmp/migration_cart_balance_preview.png")) == OK)
	cart_popup._continue_stage()
	cart_popup._try_old_road()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var route_image := get_viewport().get_texture().get_image()
	assert(route_image.save_png(ProjectSettings.globalize_path("res://tmp/migration_cart_route_preview.png")) == OK)
	cart_popup._choose_long_road()
	cart_popup._continue_stage()
	cart_popup.space_held = true
	for tick in 80:
		cart_popup._process(0.1)
	assert(cart_popup.stage == cart_popup.STAGE_DECISION)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var decision_image := get_viewport().get_texture().get_image()
	assert(decision_image.save_png(ProjectSettings.globalize_path("res://tmp/migration_cart_decision_preview.png")) == OK)
	get_tree().quit()
