extends Node

var popup: Node
var frame := 0


func _ready() -> void:
	GameState.reset_progress(false)
	for part in ["rueda_dentada", "cuerda", "tabla"]:
		GameState.add_item(part)
	var mill = preload("res://scenes/mill_interior.tscn").instantiate()
	add_child(mill)
	await get_tree().process_frame
	mill.get_node("World/Player").position = Vector2(590, 336)
	popup = mill.get_node("MillRepairPopup")
	popup.open()
	popup.set_process(false)
	popup.workbench.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/repair_pro_motion"))
	await _capture("initial")
	await _frames(30)
	var from: Vector2 = popup.workbench.TRAYS.rueda_dentada.get_center()
	var to: Vector2 = popup.workbench.TARGETS.rueda_dentada.get_center()
	popup.workbench._press(from)
	for tick in 20:
		popup.workbench._drag(from.lerp(to, tick / 19.0))
		await _frames(1)
	popup.workbench.release_pointer(to * popup.workbench.size / popup.workbench.DESIGN)
	await _capture("gear")
	await _frames(22)
	for tick in 5:
		popup.get_node("%DecreaseButton").pressed.emit()
		await _frames(6)
	await _frames(15)
	popup.action_button.button_down.emit()
	await _frames(22)
	popup.action_button.button_up.emit()
	assert(GameState.is_mill_part_installed("rueda_dentada"))
	await _frames(22)
	popup.get_node("%RopePiece").pressed.emit()
	await _frames(25)
	for tick in 10:
		popup.get_node("%IncreaseButton").pressed.emit()
		await _frames(4)
	await _capture("rope")
	await _frames(15)
	popup.action_button.button_down.emit()
	await _frames(27)
	popup.action_button.button_up.emit()
	assert(GameState.is_mill_part_installed("cuerda"))
	await _frames(25)
	from = popup.workbench.TRAYS.tabla.get_center()
	to = popup.workbench.TARGETS.tabla.get_center()
	popup.workbench._press(from)
	for tick in 22:
		popup.workbench._drag(from.lerp(to, tick / 21.0))
		await _frames(1)
	popup.workbench.release_pointer(to * popup.workbench.size / popup.workbench.DESIGN)
	await _frames(20)
	popup.action_button.button_down.emit()
	await _frames(13)
	await _capture("plank")
	await _frames(11)
	popup.action_button.button_up.emit()
	await _frames(14)
	popup.action_button.button_down.emit()
	await _frames(24)
	popup.action_button.button_up.emit()
	assert(popup.stage == "proof" and not GameState.flags.mill_repaired)
	await _frames(24)
	popup.action_button.button_down.emit()
	await _frames(56)
	await _capture("proof")
	popup.action_button.button_up.emit()
	await _frames(15)
	popup.action_button.button_down.emit()
	await _frames(67)
	popup.action_button.button_up.emit()
	assert(popup.completed)
	await _capture("complete")
	await _frames(45)
	popup.close()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _capture("prompt")
	await _frames(25)
	print("MILL REPAIR PRO CAPTURE OK: %d frames; drag, gear seating, rope tension, fixings, proof and preparation prompt" % frame)
	get_tree().quit()


func _frames(count: int) -> void:
	for tick in count:
		popup._process(0.05)
		popup.workbench._process(0.05)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_jpg(ProjectSettings.globalize_path("res://tmp/repair_pro_motion/%04d.jpg" % frame), 0.94) == OK)
		frame += 1


func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/repair_pro_%s_preview.png" % name)) == OK)
