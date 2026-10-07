extends Node

var popup: Node
var previous_save := PackedByteArray()
var had_save := false


func _ready() -> void:
	had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	GameState.reset_progress(false)
	var interior = preload("res://scenes/mill_interior.tscn").instantiate()
	add_child(interior)
	await get_tree().process_frame
	var player = interior.get_node("World/Player")
	player.position = Vector2(590, 336)
	popup = interior.get_node("MillRepairPopup")
	popup.set_process(false)
	assert(interior.get_node("World/MillExit").automatic)
	assert(interior.get_node_or_null("World/GearPickup") == null)
	GameState.interact("mill_mechanism")
	await get_tree().process_frame
	assert(popup.overlay.visible and not player.controls_enabled)
	# Missing pieces and incorrect drops never consume anything.
	popup.get_node("%GearPiece").pressed.emit()
	assert(popup.stage == "select")
	for part in popup.PARTS:
		GameState.add_item(part)
	popup._refresh()
	popup.workbench._press(popup.workbench.TRAYS.rueda_dentada.get_center())
	popup.workbench._drag(popup.workbench.TARGETS.tabla.get_center())
	popup.workbench.release_pointer(popup.workbench.TARGETS.tabla.get_center() * popup.workbench.size / popup.workbench.DESIGN)
	assert(popup.stage == "select" and GameState.get_mill_repair_progress() == 0)
	assert(GameState.has_item("rueda_dentada"))
	# A correctly dropped gear still needs alignment and a complete seating action.
	popup.workbench._press(popup.workbench.TRAYS.rueda_dentada.get_center())
	popup.workbench.release_pointer(popup.workbench.TARGETS.rueda_dentada.get_center() * popup.workbench.size / popup.workbench.DESIGN)
	assert(popup.stage == "gear" and not popup._gear_aligned())
	_key(KEY_SPACE, true)
	popup._process(2)
	_key(KEY_SPACE, false)
	assert(popup.mounting == 0 and not GameState.is_mill_part_installed("rueda_dentada"))
	# Rotate through an actual touch arc, then release outside the workbench.
	var center: Vector2 = popup.workbench.GEAR_CENTER
	_touch(center + Vector2(60, 0), true, 7)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = (center + Vector2.from_angle(-popup.gear_angle) * 60) * popup.workbench.size / popup.workbench.DESIGN
	popup.workbench._gui_input(drag)
	assert(popup._gear_aligned())
	_global_release(Vector2(-25, -25), 7)
	assert(not popup.workbench.turning_gear and not popup.pointer_held)
	popup.action_button.button_down.emit()
	popup._process(0.5)
	assert(GameState.has_item("rueda_dentada"))
	popup.close()
	assert(player.controls_enabled and GameState.has_item("rueda_dentada"))
	popup.open()
	popup.get_node("%GearPiece").pressed.emit()
	for tick in 5:
		popup.get_node("%DecreaseButton").pressed.emit()
	assert(popup._gear_aligned())
	popup.action_button.grab_focus()
	_enter(true)
	await get_tree().process_frame
	assert(popup.pointer_held)
	for tick in 22:
		popup._process(0.05)
	_enter(false)
	await get_tree().process_frame
	assert(not popup.pointer_held)
	assert(GameState.is_mill_part_installed("rueda_dentada") and not GameState.has_item("rueda_dentada"))
	assert(popup.stage == "select")
	popup.close()
	popup.open()
	assert(popup.workbench.installed.rueda_dentada)
	# Install the board second. A held control cannot accidentally fasten both ends.
	popup.get_node("%PlankPiece").pressed.emit()
	assert(popup.stage == "plank")
	_touch(popup.workbench.BOLTS[0], true, 9)
	popup._process(1.2)
	assert(popup.bolts == 1 and popup.awaiting_release)
	popup._process(3)
	assert(popup.bolts == 1 and GameState.has_item("tabla"))
	_global_release(Vector2(-40, -40), 9)
	_touch(popup.workbench.BOLTS[1], true, 10)
	popup._process(1.2)
	_global_release(Vector2(-40, -40), 10)
	assert(GameState.is_mill_part_installed("tabla") and not GameState.has_item("tabla"))
	# The rope cannot be fixed while slack or over-tightened.
	popup.get_node("%RopePiece").pressed.emit()
	assert(popup.stage == "rope")
	popup.adjustment_slider.value = 100
	_hold_button(40)
	assert(popup.mounting == 0 and GameState.has_item("cuerda"))
	popup.adjustment_slider.value = 20
	_key(KEY_D, true)
	popup._process(2)
	_key(KEY_D, false)
	assert(popup._rope_safe() and popup.tension == 68)
	_touch(Vector2(565, 206), true, 11)
	var tensor_drag := InputEventScreenDrag.new()
	tensor_drag.index = 11
	tensor_drag.position = Vector2(608, 206) * popup.workbench.size / popup.workbench.DESIGN
	popup.workbench._gui_input(tensor_drag)
	_global_release(Vector2(-40, -40), 11)
	assert(popup._rope_safe() and not popup.workbench.dragging_tension)
	popup.action_button.button_down.emit()
	popup._process(0.5)
	var knot_progress: float = popup.mounting
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	popup._process(3)
	assert(popup.mounting == knot_progress and not popup.pointer_held)
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_hold_button(20)
	assert(GameState.get_mill_repair_progress() == 3 and popup.stage == "proof")
	assert(not GameState.flags.get("mill_repaired", false))
	assert(not GameState.has_item("cuerda"))
	assert(not interior.get_node("World/MillMechanism").get_prompt().contains("Preparar"))
	# Three installed parts are a saved checkpoint; a fresh visit resumes at proof.
	popup.close()
	GameState.load_progress()
	popup.open()
	assert(popup.stage == "proof" and GameState.get_mill_repair_progress() == 3)
	popup._complete_repair()
	assert(not GameState.flags.get("mill_repaired", false))
	_key(KEY_SPACE, true)
	for tick in 50:
		popup._process(0.05)
	assert(popup.proof_checks == 1 and popup.shaft_angle > 0)
	_key(KEY_SPACE, false)
	var angle: float = popup.shaft_angle
	var progress: float = popup.proof_radians
	popup._process(2)
	assert(popup.shaft_angle == angle and popup.proof_radians == progress)
	popup.action_button.button_down.emit()
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	popup._process(2)
	assert(popup.proof_radians == progress and not popup.gear_audio.playing)
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	popup.action_button.grab_focus()
	_enter(true)
	await get_tree().process_frame
	assert(popup.pointer_held)
	for tick in 90:
		popup._process(0.05)
	_enter(false)
	await get_tree().process_frame
	assert(popup.completed and popup.proof_checks == 3)
	assert(popup.overlay.visible and popup.get_node("%ReturnButton").visible)
	assert(GameState.flags.get("mill_repaired", false))
	assert(GameState.build_report().prueba_giro_molino_completada)
	assert(popup.status_label.text == "Molino reparado")
	assert(interior.get_node("World/MillMechanism").get_prompt() == "E  Preparar costal de harina")
	var events: int = GameState.metrics.events.size()
	popup._complete_repair()
	assert(GameState.metrics.events.size() == events)
	popup.close()
	popup.open()
	assert(popup.completed and popup.stage == "complete")
	popup.get_node("%ReturnButton").pressed.emit()
	assert(not popup.overlay.visible and player.controls_enabled)
	interior.free()
	var field = preload("res://scenes/mill_field.tscn").instantiate()
	add_child(field)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(field.get_node("World/BrokenMillInfo").get_prompt() == "E  Preparar costal de harina")
	var sails := field.get_node("World/RepairedWindmillSails") as Sprite2D
	var initial := sails.rotation
	await get_tree().create_timer(0.1).timeout
	assert(sails.rotation != initial)
	field.free()
	_restore_save()
	print("MILL REPAIR TEST OK: missing/wrong parts, mouse/touch, alignment, tension, two fixings, saved checkpoints, held proof, single completion, proximity and safe release")
	get_tree().quit()


func _hold_button(ticks: int) -> void:
	popup.action_button.button_down.emit()
	for tick in ticks:
		popup._process(0.05)
	popup.action_button.button_up.emit()


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	popup._input(event)


func _enter(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	Input.parse_input_event(event)


func _touch(pos: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = pos * popup.workbench.size / popup.workbench.DESIGN
	popup.workbench._gui_input(event)


func _global_release(pos: Vector2, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = false
	event.position = pos
	popup._input(event)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(previous_save)
	elif FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
