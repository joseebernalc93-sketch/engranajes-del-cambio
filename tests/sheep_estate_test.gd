extends Node

var failed := false
var had_save := false
var original_save := PackedByteArray()
var capture_ui := false
var last_dialogue: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	if had_save:
		original_save = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	GameState.reset_progress(false)
	capture_ui = "--capture-ui" in OS.get_cmdline_user_args()
	EventBus.dialogue_requested.connect(func(payload): last_dialogue = payload)
	var map := preload("res://scenes/sheep_farm.tscn").instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _settle()
	var player := map.get_node("World/Player") as CharacterBody2D
	player.set_physics_process(false)
	_check(player.position == GameState.PHASE_START_SPAWN, "Opening spawn must stay on the public approach road")
	await _capture("estate_opening")
	var backdrop := map.get_node("World/SheepFarmBackdrop")
	_check(backdrop.sheep_sprites.size() == 8, "The corral must retain eight animated sheep")
	var pasture := Rect2(508, 153, 195, 127)
	var seen_frames: Dictionary = {}
	var sheep_moved := false
	var original_sheep_position: Vector2 = backdrop.sheep_sprites[1].position
	var machine := map.get_node("World/SteamTextileMachine")
	var body := machine.get_node("StationaryMachine") as Sprite2D
	var body_origin := body.position
	var flywheel_origin: float = machine.flywheel.rotation
	var pulley_origin: float = machine.pulley.rotation
	for _tick in range(160):
		backdrop._process(0.15)
		machine._process(0.15)
		for sheep in backdrop.sheep_sprites:
			_check(pasture.has_point(sheep.position), "Sheep must stay inside the corral throughout their grazing cycle")
			_check(sheep.is_playing(), "Every sheep must keep its grazing animation")
			seen_frames[sheep.frame] = true
		sheep_moved = sheep_moved or not backdrop.sheep_sprites[1].position.is_equal_approx(original_sheep_position)
		if _tick % 16 == 0:
			await get_tree().process_frame
	_check(sheep_moved and seen_frames.size() > 1, "Grazing must combine different frames and gentle movement")
	_check(machine.flywheel.rotation != flywheel_origin and machine.pulley.rotation != pulley_origin, "Both transmission wheels must rotate")
	_check(body.position == body_origin and body.rotation == 0.0, "The carder body must remain stationary")
	_check(machine.is_playing() and machine.has_node("BoilerSteam") and map.has_node("World/FactorySteam"), "The carder and workshop must emit animated steam")
	player.position = Vector2(576, 525)
	await _settle()
	_check(player.move_and_collide(Vector2(0, -140)) != null, "The locked gate must block entry to the estate")
	_check(player.position.y >= 492.0, "The player must stop in front of the closed gate")
	await _settle()
	player._update_interactable()
	_check(player.nearest_interactable == map.get_node("World/IndustrialGate"), "The player must be able to inspect the locked gate")
	map.get_node("World/IndustrialGate").interact()
	_check(last_dialogue.speaker == "Puerta cerrada" and GameState.flags.industrial_gate_seen, "The gate must retain its historical interaction")
	map.get_node("HUD")._select_dialogue_action("close")
	await _capture("estate_locked_gate")
	await _walk_to(player, Vector2(638, 493.5))
	await _settle()
	player._update_interactable()
	_check(player.nearest_interactable == map.get_node("World/SteamTextileMachineInfo"), "The wool workshop must be observable from the public path")
	map.get_node("World/SteamTextileMachineInfo").interact()
	_check(last_dialogue.speaker == "Maquinaria textil temprana" and GameState.flags.steam_machine_seen, "Observing the carder must retain the historical clue")
	map.get_node("HUD")._select_dialogue_action("close")
	await _capture("estate_wool_workshop")
	player.position = Vector2(576, 550)
	await _settle()
	_check(player.test_move(player.transform, Vector2(-250, 0)) and player.test_move(player.transform, Vector2(250, 0)), "The public approach must retain its grass boundaries")
	player.position = Vector2(576, 585)
	await _settle()
	await _walk_to(player, Vector2(576, 603))
	for _tick in range(20):
		if not is_instance_valid(player) or not player.is_inside_tree():
			break
		player.move_and_collide(Vector2(0, 4))
		await get_tree().physics_frame
	await _settle()
	var village := get_tree().current_scene
	_check(village != null and village.scene_file_path == "res://scenes/game.tscn", "Leaving the opening estate must still lead to Elena's village")
	if village:
		_check(village.get_node("World/Player").controls_enabled, "Leaving the estate must restore player controls")
	_restore_save()
	if not failed:
		print("SHEEP ESTATE TEST OK: opening spawn, eight grazing/wandering sheep, stationary carder with rotating transmission, animated steam, locked gate, reachable historical clues, public path and village exit")
	get_tree().quit(1 if failed else 0)


func _walk_to(player: CharacterBody2D, target: Vector2) -> void:
	while player.position.distance_to(target) > 0.1:
		var collision := player.move_and_collide((target - player.position).limit_length(4.0))
		if collision:
			_check(false, "Estate approach blocked at %s toward %s" % [player.position, target])
			return
		await get_tree().physics_frame


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _capture(file_name: String) -> void:
	if not capture_ui:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/sheep_estate"))
	_check(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/sheep_estate/%s.png" % file_name)) == OK, "Estate preview must save")


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
