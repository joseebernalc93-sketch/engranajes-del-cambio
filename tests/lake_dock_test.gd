extends Node

var capture_ui := false
var failed := false
var last_dialogue: Dictionary = {}
var original_save := PackedByteArray()
var had_save := false


func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	capture_ui = "--capture-ui" in OS.get_cmdline_user_args()
	had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	if had_save:
		original_save = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	GameState.reset_progress(false)
	EventBus.dialogue_requested.connect(func(payload): last_dialogue = payload)
	var spinner := await _load_map("res://scenes/spinner_yard.tscn")
	var player := spinner.get_node("World/Player") as CharacterBody2D
	player.set_physics_process(false)
	await _walk_to(player, Vector2(75, 470))
	await _capture("silas_west_road")
	await _walk_through_exit(player, Vector2(38, 470))
	var harbor := await _wait_map("res://scenes/lake_dock.tscn")
	if failed:
		return
	player = harbor.get_node("World/Player")
	_check(player.position.is_equal_approx(Vector2(1070, 470)), "The west exit must lead to the harbor's east entrance")
	player.set_physics_process(false)
	await _capture("lake_dock_entrance")
	await _walk_to(player, Vector2(930, 470))
	await _walk_to(player, Vector2(865, 430))
	await _walk_to(player, Vector2(700, 395))
	await _walk_to(player, Vector2(580, 395))
	await _walk_to(player, Vector2(580, 480))
	await _settle()
	player._update_interactable()
	_check(player.nearest_interactable == harbor.get_node("World/BoatToWoodIsland"), "The boat interaction must be reachable on the pier")
	var renderer := harbor.get_node("World/HarborBackdrop")
	_check(renderer.boats.size() == 3, "The harbor must contain two fishing boats and the passenger boat")
	var previous_height: float = renderer.boats[0].position.y
	await get_tree().create_timer(0.15).timeout
	_check(not is_equal_approx(previous_height, renderer.boats[0].position.y), "Moored boats must bob on the water")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(430, 460)
	query.collision_mask = 1
	_check(not get_world_2d_for(harbor).direct_space_state.intersect_point(query).is_empty(), "The water beside the pier must block walking")
	_check(player.test_move(player.transform, Vector2(0, 150)), "The end of the pier must block walking into the lake")
	await _capture("lake_dock_pier")
	harbor.get_node("World/BoatToWoodIsland").interact()
	_check(last_dialogue.speaker == "Embarcadero del lago", "Embark dialogue must refer to the new harbor")
	_check(last_dialogue.options[0].action == "sail_to_wood_island", "Embark must retain the island destination")
	EventBus.dialogue_action_selected.emit("sail_to_wood_island")
	await _finish_voyage("res://scenes/wood_island.tscn")
	var island := get_tree().current_scene
	_check(island.get_node("World/Player").controls_enabled, "Island arrival must restore player controls")
	island.get_node("World/BoatToLakeDock").interact()
	_check(last_dialogue.options[0].action == "sail_to_lake_dock", "The island must return to the new harbor")
	EventBus.dialogue_action_selected.emit("sail_to_lake_dock")
	await _finish_voyage("res://scenes/lake_dock.tscn")
	harbor = get_tree().current_scene
	player = harbor.get_node("World/Player")
	_check(player.position.is_equal_approx(Vector2(580, 480)), "Returning must spawn safely on the new pier")
	_check(player.controls_enabled and GameState.metrics.boat_trips == 2, "Both trips must complete once and restore controls")
	player.set_physics_process(false)
	await _walk_to(player, Vector2(580, 395))
	await _walk_to(player, Vector2(700, 395))
	await _walk_to(player, Vector2(865, 430))
	await _walk_to(player, Vector2(930, 470))
	await _walk_to(player, Vector2(1070, 470))
	await _walk_through_exit(player, Vector2(1115, 470))
	spinner = await _wait_map("res://scenes/spinner_yard.tscn")
	_check(spinner.get_node("World/Player").position.is_equal_approx(Vector2(75, 470)), "The harbor must connect back to Silas's west road")
	var mill := await _load_map("res://scenes/mill_field.tscn")
	_check(not mill.has_node("World/BoatToWoodIsland") and not mill.has_node("World/MillFieldBackdrop/BoatDock"), "The mill must have no dock or boat interaction")
	_check(mill.has_node("World/Wheat1") and mill.has_node("World/Wheat2") and mill.has_node("World/Wheat3"), "Removing the dock must preserve the wheat harvest")
	await _capture("mill_without_dock")
	_restore_save()
	if not failed:
		print("LAKE DOCK TEST OK: west road, automatic exits, walkable harbor/pier, water collisions, animated boats, outbound/return voyages, safe spawns, mill without dock and preserved harvest")
	get_tree().quit(1 if failed else 0)


func _load_map(path: String) -> Node:
	var previous := get_tree().current_scene
	get_tree().current_scene = null
	if previous:
		previous.free()
	var map: Node = load(path).instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _settle()
	return map


func _wait_map(path: String) -> Node:
	for _tick in range(90):
		await get_tree().process_frame
		var map := get_tree().current_scene
		if map and map.scene_file_path == path:
			await _settle()
			return map
	_check(false, "Map transition did not load %s" % path)
	return null


func _finish_voyage(destination: String) -> void:
	var voyage := await _wait_map("res://scenes/boat_travel.tscn")
	if not voyage:
		return
	voyage.elapsed = 0.8
	voyage._finish_travel()
	await get_tree().create_timer(0.55).timeout
	await _wait_map(destination)


func _walk_to(player: CharacterBody2D, target: Vector2) -> void:
	while player.position.distance_to(target) > 0.1:
		var collision := player.move_and_collide((target - player.position).limit_length(8.0))
		if collision:
			_check(false, "Harbor path blocked at %s toward %s" % [player.position, target])
			return
		await get_tree().physics_frame


func _walk_through_exit(player: CharacterBody2D, target: Vector2) -> void:
	while is_instance_valid(player) and player.is_inside_tree() and player.position.distance_to(target) > 0.1:
		var collision := player.move_and_collide((target - player.position).limit_length(4.0))
		if collision:
			_check(false, "Connecting road is blocked")
			return
		await get_tree().physics_frame
	await get_tree().process_frame


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func get_world_2d_for(map: Node2D) -> World2D:
	return map.get_world_2d()


func _capture(file_name: String) -> void:
	if not capture_ui:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/lake_dock"))
	var screenshot := get_viewport().get_texture().get_image()
	_check(screenshot.save_png(ProjectSettings.globalize_path("res://tmp/lake_dock/%s.png" % file_name)) == OK, "Scene preview must save")


func _restore_save() -> void:
	if had_save:
		var save := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		save.store_buffer(original_save)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
		_restore_save()
		get_tree().quit(1)
