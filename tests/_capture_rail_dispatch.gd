extends Node
var backups: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	GameState.reset_progress(false)
	for flag in ["cart_mission_completed", "ticket_bought", "coach_station_reached", "flour_sold", "mill_repaired"]:
		GameState.flags[flag] = true
	GameState.inventory = {"boleto": 1}
	var map = preload("res://scenes/station_platform.tscn").instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	var player: CharacterBody2D = map.get_node("World/Player")
	player.set_physics_process(false)
	player.position = Vector2(90, 440)
	await get_tree().create_timer(1.2).timeout
	EventBus.rail_dispatch_requested.emit()
	var popup: CanvasLayer = map.get_node("RailDispatchHost").popup
	await get_tree().create_timer(0.9).timeout
	popup.start_inspection()
	while popup.moving:
		await get_tree().process_frame
	popup.request_pass(0)
	await get_tree().create_timer(0.9).timeout
	for index in range(popup.LAYOUT.COUNT):
		popup.select_segment(index)
		if index == 5:
			popup.request_pass(index)
			await get_tree().create_timer(0.8).timeout
		if index in popup.LAYOUT.SWITCHES:
			var lever: Vector2 = popup.board.lever_position(index) * popup.board.size.x / 1000
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = lever
			click.pressed = true
			popup.board._board_input(click)
			var drag := InputEventMouseMotion.new()
			drag.position = lever + Vector2((popup.LAYOUT.TARGETS[index] - 1) * 18, -12) * popup.board.size.x / 1000
			popup.board._board_input(drag)
			click.position = drag.position
			click.pressed = false
			popup.board._board_input(click)
		else:
			var turns: int = posmod(popup.LAYOUT.TARGETS[index] - popup.angles[index], 4)
			if turns == 3:
				popup.rotate_segment(index, -1)
			else:
				for turn in range(turns):
					popup.rotate_segment(index, 1)
					await get_tree().create_timer(0.45).timeout
		await get_tree().create_timer(0.75).timeout
		popup.request_pass(index)
		while popup.gate_opening or popup.moving:
			await get_tree().process_frame
		await get_tree().create_timer(0.45).timeout
	popup._primary_action()
	while popup.stage < 2:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	popup._close()
	for destination in [Vector2(680, 440), Vector2(680, 400)]:
		while player.position.distance_to(destination) > 2:
			var direction: Vector2 = (destination - player.position).normalized()
			player._update_walk_animation(direction, 1.0 / 30.0)
			player.move_and_collide((destination - player.position).limit_length(205.0 / 30.0))
			await get_tree().process_frame
	player._update_walk_animation(Vector2.ZERO, 0.1)
	map.get_node("HUD")._select_dialogue_action("board_train")
	await get_tree().create_timer(0.7).timeout
	map.get_node("TrainDepartureController").complete_phase_on_departure = false
	map.get_node("HUD")._select_dialogue_action("depart_train")
	await get_tree().create_timer(5.9).timeout
	for path in backups:
		if backups[path] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backups[path])
	print("RAIL ALIGNMENT DEMO OK")
	get_tree().quit()

