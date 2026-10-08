extends Node

var previous_save := PackedByteArray()
var previous_report := PackedByteArray()
var had_save := false
var had_report := false


func _ready() -> void:
	had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	had_report = FileAccess.file_exists(GameState.REPORT_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	if had_report:
		previous_report = FileAccess.get_file_as_bytes(GameState.REPORT_PATH)
	GameState.reset_progress(false)

	# El molino solo puede consumir el trigo al completar sus tres tandas.
	GameState.inventory = {"trigo": 3}
	GameState.flags["mill_repaired"] = true
	GameState.flags["villager_spoken"] = true
	GameState.flags["wheelwright_forge_completed"] = true
	GameState.flags["lumber_puzzle_completed"] = true
	GameState.flags["rope_puzzle_completed"] = true
	GameState.metrics["wheat_harvested"] = 3
	var village = preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not village.get_node_or_null("World/VillageBackdrop/ElenaCartTurnout"))
	assert(village.get_node_or_null("World/ElenaMigrationCart"))
	assert(village.get_node_or_null("World/ElenaMigrationCartCollision"))
	village.queue_free()
	await get_tree().process_frame
	var mill_popup = preload("res://scenes/ui/mill_operation_popup.tscn").instantiate()
	add_child(mill_popup)
	await get_tree().process_frame
	mill_popup.open()
	assert(mill_popup.overlay.visible)
	for batch in 3:
		mill_popup.gate_slider.value = 70.0
		mill_popup.rotation_speed = mill_popup.IDEAL_RPM
		mill_popup.ready_seconds = mill_popup.READY_SECONDS
		mill_popup._load_next_batch()
		assert(mill_popup.processing_batch)
		if batch == 0:
			mill_popup.rotation_speed = 0.0
			mill_popup.low_speed_seconds = mill_popup.JAM_DELAY
			mill_popup._update_operation(0.01)
			assert(mill_popup.jammed)
			mill_popup.gate_slider.value = 0.0
			mill_popup.rotation_speed = 0.0
			mill_popup._recover_mechanism()
			assert(mill_popup.processing_batch)
		elif batch == 1:
			mill_popup.rotation_speed = mill_popup.TRIP_RPM
			mill_popup.high_speed_seconds = mill_popup.TRIP_DELAY
			mill_popup._update_operation(0.01)
			assert(mill_popup.safety_tripped)
			mill_popup.gate_slider.value = 0.0
			mill_popup.rotation_speed = 0.0
			mill_popup._recover_mechanism()
			assert(mill_popup.processing_batch)
		mill_popup.grain_remaining = 0.0
		mill_popup.stable_seconds += 6.0
		mill_popup._finish_batch()
	assert(mill_popup.finishing and not GameState.flags.get("flour_milled", false))
	mill_popup.brake_button.pressed.emit()
	mill_popup.rotation_speed = 0.0
	mill_popup.space_held = true
	mill_popup._process(mill_popup.TIE_SECONDS)
	assert(GameState.flags.get("flour_milled", false))
	assert(GameState.has_item("costal_harina"))
	assert(not GameState.has_item("trigo"))
	assert(int(GameState.metrics.get("mill_batches_processed", 0)) == 3)
	assert(float(GameState.metrics.get("mill_stable_seconds", 0.0)) >= 15.0)
	assert(int(GameState.metrics.get("mill_jams", 0)) == 2)
	mill_popup.free()

	# La harina financia ambos pasajes; Elena conserva su papel narrativo.
	GameState._sell_flour()
	assert(GameState.coins == 100)
	assert(GameState.get_objective().contains("carretas"))
	assert(GameState.book_passenger_coach("res://scenes/station.tscn"))
	assert(GameState.complete_passenger_coach_trip("res://scenes/station.tscn"))
	assert(GameState.coins == 97)
	assert(GameState.get_objective().contains("boleto"))

	EventBus.dialogue_action_selected.emit("buy_ticket")
	assert(GameState.flags.get("ticket_bought", false))
	assert(GameState.has_item("boleto"))
	var report := GameState.build_report()
	assert(int(report.get("tandas_trigo_molidas", 0)) == 3)
	assert(GameState.get_puzzle_progress().size() == 5)
	assert(not GameState.flags.get("cart_mission_completed", false))
	print("PHASE ONE EXPANSION TEST OK: molino operativo y harina para ambos pasajes")

	_restore_file(GameState.SAVE_PATH, previous_save, had_save)
	_restore_file(GameState.REPORT_PATH, previous_report, had_report)
	get_tree().quit()


func _restore_file(path: String, contents: PackedByteArray, existed: bool) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_buffer(contents)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
