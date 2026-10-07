extends Node

var popup: Node
var frame := 0
var stage_age := 0
var previous_stage := -1

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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/elena_motion"))
	while frame < 700:
		if popup.stage != previous_stage:
			stage_age = 0
			previous_stage = popup.stage
		match popup.stage:
			0:
				if frame == 22:
					popup._toggle_item(true, "alimentos")
				elif frame == 38:
					popup._toggle_item(true, "herramientas")
				elif frame == 54:
					popup._toggle_item(true, "retrato")
				elif frame == 76:
					popup._continue_stage()
			1:
				if stage_age >= 12 and stage_age <= 44:
					popup.balance_slider.value = lerpf(34.0, 50.0, (stage_age - 12) / 32.0)
				if stage_age == 73:
					popup._continue_stage()
			2:
				if stage_age == 12:
					popup._try_old_road()
				elif stage_age == 34:
					popup._choose_long_road()
				elif stage_age == 62:
					popup._continue_stage()
			3:
				popup.space_held = stage_age >= 10
			4:
				if stage_age == 29:
					popup._choose_priority("recuerdo familiar")
			5:
				popup.space_held = stage_age >= 10
			6:
				if stage_age == 39:
					break
		popup._process(0.05)
		popup.cart_display._process(0.05)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		assert(screenshot.save_png(ProjectSettings.globalize_path("res://tmp/elena_motion/%04d.png" % frame)) == OK)
		frame += 1
		stage_age += 1
	assert(popup.completed)
	print("ELENA MOTION OK: %d frames" % frame)
	get_tree().quit()
