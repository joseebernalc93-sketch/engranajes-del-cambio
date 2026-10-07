extends Node

const TRAVEL := preload("res://scenes/boat_travel.tscn")
var capture_ui := false
var completion_count := 0
var failed := false


func _ready() -> void:
	# Keep this harness alive when exercising real destination scene changes.
	get_tree().current_scene = null
	capture_ui = "--capture-ui" in OS.get_cmdline_user_args()
	var original_flags: Dictionary = GameState.flags.duplicate(true)
	var original_spawn: Vector2 = GameState.pending_spawn
	var original_destination: String = GameState.pending_travel_scene
	var original_inventory: Dictionary = GameState.inventory.duplicate(true)
	var original_metrics: Dictionary = GameState.metrics.duplicate(true)
	for route in [{"returning": false, "repaired": false}, {"returning": false, "repaired": true}, {"returning": true, "repaired": true}]:
		await _test_route(route.returning, route.repaired)
		if failed:
			return
	await _test_real_arrival(false)
	await _test_real_arrival(true)
	GameState.flags = original_flags
	GameState.pending_spawn = original_spawn
	GameState.pending_travel_scene = original_destination
	_check(GameState.inventory == original_inventory, "Travel must preserve inventory")
	_check(GameState.metrics == original_metrics, "Travel must not duplicate trip metrics")
	if failed:
		return
	print("BOAT TRAVEL TEST OK: dedicated harbor, forward/return paths, camera continuity, oars/wake, guarded skip, one completion, real destinations and spawn points")
	get_tree().quit()


func _test_route(returning: bool, repaired: bool) -> void:
	GameState.flags["mill_repaired"] = repaired
	GameState.pending_travel_scene = "res://scenes/lake_dock.tscn" if returning else "res://scenes/wood_island.tscn"
	var travel = TRAVEL.instantiate()
	travel.auto_change_destination = false
	add_child(travel)
	travel.set_process(false)
	await get_tree().process_frame
	completion_count = 0
	travel.travel_finished.connect(func(_destination): completion_count += 1)
	_check(travel.boat.flip_h == returning, "Boat must face the route direction")
	_check(travel.has_node("LakeDockShore/HarborBackdrop") and travel.has_node("IslandShore/Bruno"), "Both real shores must be present")
	_check(not travel.has_node("MillShore"), "The voyage must use the dedicated lake harbor")
	_check(travel.boat.position.is_equal_approx(travel.ISLAND_BERTH if returning else travel.DOCK_BERTH), "Boat must start next to its departure dock")
	var stages: Dictionary = {}
	var frames: Dictionary = {}
	var captured: Dictionary = {}
	var had_wake := false
	var had_ripples := false
	var previous_position: Vector2 = travel.boat.position
	var previous_camera: Vector2 = travel.camera.position
	for tick in range(int(ceil(travel.TOTAL_TIME * 60.0)) + 1):
		travel._process(1.0 / 60.0)
		stages[travel.stage] = true
		frames[int(travel.boat.region_rect.position.x)] = true
		had_wake = had_wake or not travel.effects.wake.is_empty()
		had_ripples = had_ripples or not travel.effects.ripples.is_empty()
		_check(travel.boat.position.distance_to(previous_position) < 14.0, "Boat path must not jump between stages")
		_check(travel.camera.position.distance_to(previous_camera) < 15.0, "Camera must not jump between stages")
		var screen: Vector2 = (travel.boat.position - travel.camera.position - travel.camera.offset) * travel.camera.zoom + get_viewport().get_visible_rect().size * 0.5
		_check(screen.y > 80.0 and screen.y < get_viewport().get_visible_rect().size.y - 95.0, "Boat must stay inside the cinematic frame")
		previous_position = travel.boat.position
		previous_camera = travel.camera.position
		if failed:
			travel.free()
			return
		if capture_ui and not returning and not repaired:
			var key := ""
			if travel.elapsed > 0.6 and travel.elapsed < 0.75:
				key = "departure"
			elif travel.elapsed > 1.75 and travel.elapsed < 1.9:
				key = "leaving_dock"
			elif travel.elapsed > 4.1 and travel.elapsed < 4.3:
				key = "crossing"
			elif travel.elapsed > 7.8 and travel.elapsed < 8.0:
				key = "arrival"
			elif travel.stage == "mooring":
				key = "moored"
			if not key.is_empty() and not captured.has(key):
				captured[key] = true
				await _capture(key)
		if tick % 30 == 0:
			await get_tree().process_frame
	_check(stages.size() == 4 and frames.size() == 4, "All voyage stages and rowing frames must run")
	_check(had_wake and had_ripples, "Rowing must leave a wake and oar ripples")
	_check(travel.boat.position.is_equal_approx(travel.DOCK_BERTH if returning else travel.ISLAND_BERTH), "Boat must finish at the destination dock")
	_check(travel.boat.region_rect.position.x == 0.0, "Rowing must stop at the dock")
	travel._finish_travel()
	await get_tree().create_timer(0.45).timeout
	_check(completion_count == 1 and travel.completed, "Travel must complete once")
	travel._change_destination()
	_check(completion_count == 1, "Repeated callbacks must not repeat completion")
	travel.free()


func _test_real_arrival(returning: bool) -> void:
	GameState.pending_travel_scene = "res://scenes/lake_dock.tscn" if returning else "res://scenes/wood_island.tscn"
	GameState.pending_spawn = Vector2(-999, -999)
	var travel = TRAVEL.instantiate()
	add_child(travel)
	travel.set_process(false)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	travel._unhandled_input(event)
	_check(not travel.finishing, "The embark input must not skip the opening")
	travel._process(0.8)
	travel._unhandled_input(event)
	_check(travel.finishing, "Space must let the player continue")
	travel._finish_travel()
	await get_tree().create_timer(0.55).timeout
	var map := get_tree().current_scene
	_check(map != null and map.scene_file_path == travel.destination, "The real destination scene must load")
	if map:
		var player := map.get_node("World/Player") as CharacterBody2D
		_check(player.position.is_equal_approx(Vector2(580, 480) if returning else Vector2(576, 535)), "Arrival spawn must be next to the correct dock")
		_check(player.controls_enabled, "The player must be able to continue after arrival")
		_check(GameState.pending_spawn == Vector2.ZERO and GameState.pending_travel_scene.is_empty(), "Arrival must consume pending travel state")
		get_tree().current_scene = null
		map.free()
	travel.free()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/boat_voyage"))
	var screenshot := get_viewport().get_texture().get_image()
	_check(screenshot.save_png(ProjectSettings.globalize_path("res://tmp/boat_voyage/%s.png" % file_name)) == OK, "Screenshot must save")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
		get_tree().quit(1)
