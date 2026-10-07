extends Node
## Controls must run the real hydraulic model and deliver flour only after three batches.

var popup: Node

func _ready() -> void:
	GameState.reset_progress(false)
	GameState.flags["mill_repaired"] = true
	GameState.inventory = {"trigo": 3}
	var mill = preload("res://scenes/mill_interior.tscn").instantiate()
	add_child(mill)
	await get_tree().process_frame
	popup = mill.get_node("MillOperationPopup")
	var mechanism = mill.get_node("World/MillMechanism")
	GameState.flags["mill_repaired"] = false
	assert(mechanism.get_prompt() == "E  Reparar mecanismo")
	var player = get_tree().get_first_node_in_group("player")
	player.position = Vector2(590, 336)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player._update_interactable()
	assert(mill.get_node("HUD").prompt_label.text == "E  Reparar mecanismo")
	popup.open()
	assert(not popup.overlay.visible)
	GameState.flags["mill_repaired"] = true
	assert(mechanism.get_prompt() == "E  Preparar costal de harina")
	player._update_interactable()
	assert(mill.get_node("HUD").prompt_label.text == "E  Preparar costal de harina")
	mill.get_node("HUD")._select_dialogue_action("open_mill_operation")
	assert(popup.overlay.visible and not player.controls_enabled)
	popup.set_process(false)
	assert(popup.workbench.wheel_angle == 0.0)
	var gate_touch := InputEventScreenTouch.new()
	gate_touch.pressed = true
	gate_touch.index = 0
	gate_touch.position = popup.workbench.GATE_TARGET.get_center() * popup.workbench.size / popup.workbench.DESIGN
	popup.workbench._gui_input(gate_touch)
	assert(popup.workbench.dragging_gate and absf(popup.gate_opening - 50) <= 1)
	var gate_drag := InputEventScreenDrag.new()
	gate_drag.index = 0
	gate_drag.position = Vector2(110, 160) * popup.workbench.size / popup.workbench.DESIGN
	popup.workbench._gui_input(gate_drag)
	assert(popup.gate_opening == 0)
	gate_touch.pressed = false
	gate_touch.position = Vector2(1100, 600)
	popup._input(gate_touch)
	assert(not popup.workbench.dragging_gate)
	popup.open_gate_button.button_down.emit()
	assert(popup.gate_opening == 2)
	_tick(120)
	assert(popup.gate_opening >= 32 and popup.rotation_speed > 0)
	assert(popup.workbench.wheel_angle > 0)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(1100, 600)
	popup._input(release)
	var released_gate: float = popup.gate_opening
	_tick(30)
	assert(popup.gate_opening == released_gate)
	_key(KEY_RIGHT, true)
	_tick(80)
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_gate: float = popup.gate_opening
	_tick(20)
	assert(popup.gate_opening == focus_gate and not popup.right_held)
	# Only controls are used to center the hydraulics, load grain and grind all batches.
	for batch in 3:
		_set_gate_with_buttons(64)
		for tick in 400:
			popup._process(1.0 / 60.0)
			if popup.ready_seconds >= popup.READY_SECONDS:
				break
		assert(popup.ready_seconds >= popup.READY_SECONDS and popup._rpm_is_safe())
		if batch == 0:
			# Drag wheat into the actual hopper. Releasing elsewhere cannot load.
			var touch := InputEventScreenTouch.new()
			touch.pressed = true
			touch.index = 0
			touch.position = popup.workbench.WHEAT_TARGET.get_center() * popup.workbench.size / popup.workbench.DESIGN
			popup.workbench._gui_input(touch)
			assert(popup.workbench.dragging_wheat)
			popup.workbench.release_pointer(Vector2.ZERO)
			assert(not popup.processing_batch)
			popup.workbench._gui_input(touch)
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = popup.workbench.HOPPER_TARGET.get_center() * popup.workbench.size / popup.workbench.DESIGN
			popup.workbench._gui_input(drag)
			touch.pressed = false
			touch.position = popup.workbench.get_global_transform_with_canvas() * drag.position
			popup._input(touch)
			assert(not popup.workbench.dragging_wheat)
		else:
			_key(KEY_SPACE, true)
			_key(KEY_SPACE, false)
		assert(popup.processing_batch and not GameState.flags["flour_milled"])
		_set_gate_with_buttons(86)
		for tick in 1000:
			popup._process(1.0 / 60.0)
			if popup.batches_processed == batch + 1:
				break
		assert(popup.batches_processed == batch + 1 and not popup.jammed and not popup.safety_tripped)
	assert(popup.finishing and not popup.completed and not GameState.has_item("costal_harina"))
	_key(KEY_SPACE, true)
	_tick(10)
	_key(KEY_SPACE, false)
	assert(popup.tie_seconds == 0.0)
	popup.brake_button.pressed.emit()
	_tick(300)
	assert(popup._can_tie())
	# Tie progress is preserved, but releasing or losing focus cannot finish it.
	popup.workbench._press(popup.workbench.SACK_TARGET.get_center())
	assert(popup.pointer_tie)
	_tick(30)
	popup._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var saved_tie: float = popup.tie_seconds
	_tick(60)
	assert(popup.tie_seconds == saved_tie and not popup.completed)
	_key(KEY_SPACE, true)
	_tick(100)
	_key(KEY_SPACE, false)
	assert(popup.completed and GameState.has_item("costal_harina") and not GameState.has_item("trigo"))
	assert(popup.gate_opening == 0 and popup.close_gate_button.disabled and popup.open_gate_button.disabled)
	popup._hold_gate(1)
	_key(KEY_RIGHT, true)
	_tick(20)
	assert(popup.gate_opening == 0)
	popup.close()
	assert(player.controls_enabled)
	var flour_count: int = GameState.inventory.get("costal_harina", 0)
	GameState.interact("mill_mechanism")
	mill.get_node("HUD")._select_dialogue_action("open_mill_operation")
	assert(popup.completed and popup.workbench.tie == 1.0)
	assert(GameState.inventory.get("costal_harina", 0) == flour_count)
	popup.close()
	# A jam can be recovered with Space only after closing the gate and braking.
	GameState.reset_progress(false)
	GameState.flags["mill_repaired"] = true
	GameState.inventory = {"trigo": 3}
	popup.open()
	_set_gate_with_buttons(64)
	popup.rotation_speed = popup.IDEAL_RPM
	popup.ready_seconds = popup.READY_SECONDS
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_set_gate_with_buttons(0)
	_tick(800)
	assert(popup.jammed and popup.rotation_speed == 0 and not popup.recovery_button.disabled)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	assert(not popup.jammed and popup.processing_batch)
	# Touch release and closing never leave a held action behind.
	popup.open_gate_button.button_down.emit()
	var touch := InputEventScreenTouch.new()
	touch.pressed = false
	popup._input(touch)
	assert(popup.pointer_gate_direction == 0)
	popup.open_gate_button.button_down.emit()
	popup.close()
	var closed_gate: float = popup.gate_opening
	_tick(30)
	assert(popup.gate_opening == closed_gate and popup.pointer_gate_direction == 0)
	var closed_angle: float = popup.workbench.wheel_angle
	_tick(60)
	assert(popup.workbench.wheel_angle == closed_angle and GameState.has_item("trigo", 3))
	print("MILL OPERATION CONTROLS TEST OK: buttons, held keys, release, focus, hydraulics, three batches, recovery and flour")
	get_tree().quit()

func _set_gate_with_buttons(target: float) -> void:
	for step in 60:
		if is_equal_approx(popup.gate_opening, target):
			return
		if popup.gate_opening < target:
			popup.open_gate_button.button_down.emit()
			popup.open_gate_button.button_up.emit()
		else:
			popup.close_gate_button.button_down.emit()
			popup.close_gate_button.button_up.emit()
	assert(false, "Gate target was not reached")

func _tick(frames: int) -> void:
	for tick in frames:
		popup._process(1.0 / 60.0)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	popup._input(event)
