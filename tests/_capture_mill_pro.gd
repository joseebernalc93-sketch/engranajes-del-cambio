extends Node

var popup: Node
var frame := 0
var drag_age := -1

func _ready() -> void:
	GameState.reset_progress(false)
	GameState.flags["mill_repaired"] = true
	GameState.inventory = {"trigo": 3}
	var mill = preload("res://scenes/mill_interior.tscn").instantiate()
	add_child(mill)
	await get_tree().process_frame
	var player = mill.get_node("World/Player")
	player.position = Vector2(590, 336)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await _capture("prompt")
	mill.get_node("HUD")._select_dialogue_action("open_mill_operation")
	popup = mill.get_node("MillOperationPopup")
	popup.set_process(false)
	popup.workbench.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/mill_pro_motion"))
	var caught_grinding := false
	var caught_stopping := false
	var caught_tie := false
	var complete_frames := 0
	while frame < 1800:
		if popup.completed:
			complete_frames += 1
			if complete_frames == 3:
				await _capture("complete")
			if complete_frames > 38:
				break
		elif popup.finishing:
			if not caught_stopping:
				await _capture("stopping")
				caught_stopping = true
			popup._adjust_gate(-2.0)
			if popup._can_tie():
				popup.pointer_tie = true
				if popup.tie_seconds > 0.7 and not caught_tie:
					await _capture("tie")
					caught_tie = true
		elif popup.processing_batch:
			popup.gate_slider.value = move_toward(popup.gate_opening, 86.0, 1.0)
			if popup.grain_remaining < 0.6 and not caught_grinding:
				await _capture("grinding")
				caught_grinding = true
		elif drag_age >= 0:
			drag_age += 1
			var from: Vector2 = popup.workbench.WHEAT_TARGET.get_center()
			var to: Vector2 = popup.workbench.HOPPER_TARGET.get_center()
			popup.workbench._drag(from.lerp(to, clampf(drag_age / 16.0, 0.0, 1.0)))
			if drag_age >= 18:
				popup.workbench.release_pointer(to * popup.workbench.size / popup.workbench.DESIGN)
				drag_age = -1
		elif popup.ready_seconds >= popup.READY_SECONDS:
			popup.workbench._press(popup.workbench.WHEAT_TARGET.get_center())
			drag_age = 0
		else:
			popup.gate_slider.value = move_toward(popup.gate_opening, 64.0, 1.0)
		popup._process(0.05)
		popup.workbench._process(0.05)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		assert(screenshot.save_jpg(ProjectSettings.globalize_path("res://tmp/mill_pro_motion/%04d.jpg" % frame), 0.94) == OK)
		frame += 1
	assert(popup.completed)
	print("MILL PRO CAPTURE OK: %d frames, proximity, wheat drag, hydraulics, grain, braking and tie" % frame)
	get_tree().quit()

func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	assert(screenshot.save_png(ProjectSettings.globalize_path("res://tmp/mill_pro_%s_preview.png" % name)) == OK)
