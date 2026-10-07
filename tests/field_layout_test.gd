extends Node

var previous_save := PackedByteArray()
var had_save := false
var capture_ui := false


func _ready() -> void:
	had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	capture_ui = "--capture-ui" in OS.get_cmdline_user_args()
	GameState.reset_progress(false)
	var village = preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	await _settle()
	assert(village.get_node("World/Villager").interaction_id == "villager")
	assert(village.get_node("World/Baker").interaction_id == "baker")
	for index in range(1, 4):
		assert(not village.get_node_or_null("World/Wheat%d" % index))
	assert(village.get_node("World/ElenaMigrationCart").position == Vector2(300, 285))
	assert(not village.get_node_or_null("World/FieldFence"))
	var cart := village.get_node("World/ElenaMigrationCart") as Sprite2D
	assert((cart.texture.get_size() * cart.scale).is_equal_approx(Vector2(180, 120)))
	var village_player := village.get_node("World/Player") as CharacterBody2D
	village_player.set_physics_process(false)
	village_player.position = Vector2(275, 470)
	await _settle()
	# The driveway is open, and crossing the former corral boundary is unobstructed.
	await _walk_to(village_player, Vector2(275, 330))
	await _walk_to(village_player, Vector2(450, 330))
	await _walk_to(village_player, Vector2(450, 300))
	await _walk_to(village_player, Vector2(560, 300))
	await _walk_to(village_player, Vector2(425, 300))
	await _capture("village_carriage_station")
	GameState.flags["cart_mission_completed"] = true
	EventBus.objective_changed.emit(GameState.get_objective())
	await _settle()
	assert(village.get_node_or_null("World/ElenaMigrationCart"))
	assert(village.get_node_or_null("World/ElenaMigrationCartCollision"))
	assert(village.get_node_or_null("World/ElenaHorseCollision"))
	assert(village.get_node("World/BakeryOvenFire").is_playing())
	await _capture("village_departed")
	village.free()

	var field = preload("res://scenes/mill_field.tscn").instantiate()
	add_child(field)
	await _settle()
	await _capture("mill_wheat_before_repair")
	var player := field.get_node("World/Player") as CharacterBody2D
	player.set_physics_process(false)
	player.position = Vector2(275, 405)
	await _settle()
	# Enter through the real gap and walk between rows, using the player's collision shape.
	await _walk_to(player, Vector2(275, 270))
	await _walk_to(player, Vector2(165, 270))
	await _walk_to(player, Vector2(165, 165))
	await _harvest(field, player, "Wheat1")
	assert(GameState.has_item("trigo", 1))
	assert(GameState.flags["wheat_1"])
	field.free()
	assert(GameState.load_progress())

	# A previously harvested pickup stays consumed when the map or save is reloaded.
	field = preload("res://scenes/mill_field.tscn").instantiate()
	add_child(field)
	await _settle()
	assert(not field.get_node_or_null("World/Wheat1"))
	assert(field.get_node_or_null("World/Wheat2"))
	assert(field.get_node_or_null("World/Wheat3"))
	player = field.get_node("World/Player")
	player.set_physics_process(false)
	player.position = Vector2(165, 165)
	await _settle()
	await _walk_to(player, Vector2(290, 165))
	await _walk_to(player, Vector2(290, 235))
	await _harvest(field, player, "Wheat2")
	await _walk_to(player, Vector2(445, 235))
	await _walk_to(player, Vector2(445, 165))
	await _harvest(field, player, "Wheat3")
	assert(GameState.has_item("trigo", 3))
	assert(GameState.metrics["wheat_harvested"] == 3)
	await _walk_to(player, Vector2(275, 165))
	await _walk_to(player, Vector2(275, 405))
	field.free()

	GameState.flags["mill_repaired"] = true
	field = preload("res://scenes/mill_field.tscn").instantiate()
	add_child(field)
	await _settle()
	assert(field.get_node("World/BrokenMillInfo").get_prompt() == "E  Preparar costal de harina")
	var sails := field.get_node("World/RepairedWindmillSails") as Sprite2D
	var angle := sails.rotation
	await get_tree().create_timer(0.1).timeout
	assert(sails.rotation != angle)
	for index in range(1, 4):
		assert(not field.get_node_or_null("World/Wheat%d" % index))
	await _capture("mill_wheat_after_repair")
	field.free()
	if had_save:
		var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(previous_save)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	print("FIELD LAYOUT TEST OK: open carriage station, scaled cart, departure, walkable mill harvest, saved pickups, repaired sails")
	get_tree().quit()


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _walk_to(player: CharacterBody2D, target: Vector2) -> void:
	while player.position.distance_to(target) > 0.1:
		var motion := (target - player.position).limit_length(8.0)
		var collision := player.move_and_collide(motion)
		assert(collision == null, "Field path blocked at %s toward %s" % [player.position, target])
		if collision:
			get_tree().quit(1)
			return
		await get_tree().physics_frame


func _harvest(field: Node, player: CharacterBody2D, wheat_name: String) -> void:
	await _settle()
	player._update_interactable()
	var wheat := field.get_node("World/" + wheat_name)
	assert(player.nearest_interactable == wheat)
	assert(wheat.get_prompt() == "E  Cosechar trigo")
	wheat.interact()
	await get_tree().create_timer(0.22).timeout
	assert(not field.get_node_or_null("World/" + wheat_name))


func _capture(file_name: String) -> void:
	if not capture_ui:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/field_layout"))
	var screenshot := get_viewport().get_texture().get_image()
	assert(screenshot.save_png(ProjectSettings.globalize_path("res://tmp/field_layout/%s.png" % file_name)) == OK)
