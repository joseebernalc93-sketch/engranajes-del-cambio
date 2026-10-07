extends Node


func _ready() -> void:
	GameState.reset_progress(false)
	GameState.flags["cart_mission_completed"] = false
	var village = preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not village.get_node_or_null("World/VillageBackdrop/ElenaCartTurnout"))
	assert(village.get_node_or_null("World/ElenaMigrationCart"))
	assert(village.get_node_or_null("World/ElenaMigrationCartCollision"))
	assert(village.get_node_or_null("World/Baker"))
	assert(village.get_node("World/Baker").interaction_id == "baker")
	assert(village.get_node("World/Baker").texture.resource_path == "res://assets/gba/tomas_baker_idle_v1.png")
	assert(village.get_node_or_null("World/BakeryOvenFire"))
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.save_png(ProjectSettings.globalize_path("res://tmp/village_elena_cart_preview.png")) == OK)
	get_tree().quit()
