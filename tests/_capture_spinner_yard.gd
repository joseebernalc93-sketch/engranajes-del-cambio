extends Node


func _ready() -> void:
	GameState.reset_progress(false)
	var yard = preload("res://scenes/spinner_yard.tscn").instantiate()
	add_child(yard)
	await get_tree().process_frame
	await get_tree().process_frame
	var silas := yard.get_node("World/Silas")
	assert(silas.texture.resource_path.ends_with("silas_idle_v2.png"))
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.save_png(ProjectSettings.globalize_path("res://tmp/spinner_yard_v2_preview.png")) == OK)
	get_tree().quit()

