extends Node


func _ready() -> void:
	GameState.reset_progress(false)
	for part in ["rueda_dentada", "cuerda", "tabla"]:
		GameState.add_item(part)
	GameState.install_mill_part("rueda_dentada", true)
	var mill = preload("res://scenes/mill_interior.tscn").instantiate()
	add_child(mill)
	await get_tree().process_frame
	var popup = mill.get_node("MillRepairPopup")
	popup.open()
	popup.get_node("%RopePiece").pressed.emit()
	popup.adjustment_slider.value = 71
	popup.workbench.placement_age = 2
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/repair_pro_small_preview.png")) == OK)
	print("MILL REPAIR SMALL CAPTURE OK")
	get_tree().quit()
