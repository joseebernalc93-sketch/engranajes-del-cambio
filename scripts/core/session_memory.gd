extends RefCounted
## Serializable session state. Nodes, resources, input holds and animations never enter the save.
const POPUPS := ["WheelwrightForgePopup", "RopePuzzlePopup", "LumberPuzzlePopup", "MillRepairPopup", "MillOperationPopup"]
const TRANSIENT := ["session_id", "action_locked", "awaiting_retry", "awaiting_release", "restoring_work", "application_focused", "audio_focused", "focused", "player_was_enabled", "closing", "exhaustion_notice_pending", "pending_rivet", "hold_adjust", "pointer_gate_direction", "keyboard_crank", "keyboard_tool", "plane_key_armed", "crank_held", "dragging_saw", "dragging_plane"]

static func capture(scene: Node) -> Dictionary:
	if not is_instance_valid(scene) or scene.scene_file_path.is_empty() or scene.scene_file_path == "res://scenes/ui/main_menu.tscn":
		return {}
	var saved := {"scene": scene.scene_file_path}
	if scene.scene_file_path == GameState.PHASE_TWO_SCENE:
		saved.merge(scene.get_session_state())
		return saved
	if scene.scene_file_path == GameState.PHASE_INTRO_SCENE:
		saved["story_index"] = scene.current_index
		return saved
	if scene.has_method("_apply_timeline"):
		saved["travel_elapsed"] = scene.elapsed
		saved["boat_destination"] = GameState.pending_travel_scene
		saved["coach_destination"] = GameState.pending_coach_destination
		return saved
	var player := scene.get_node_or_null("World/Player")
	if player == null:
		return {}
	saved["position"] = [player.position.x, player.position.y]
	saved["facing"] = player.facing
	var departure := scene.get_node_or_null("TrainDepartureController")
	if departure:
		saved["train"] = departure.get_session_state()
	var hud := scene.get_node_or_null("HUD")
	if hud:
		saved["hud"] = hud.get_session_state()
	for popup_name in POPUPS:
		var popup := scene.get_node_or_null(NodePath(popup_name))
		if popup == null or not popup.overlay.visible:
			continue
		if popup.has_method("_save_work"): popup._save_work()
		if popup.has_method("_save_checkpoint"): popup._save_checkpoint()
		var state := _properties(popup)
		if popup.has_method("_sync_workbench"):
			state["display"] = _properties(popup.workbench)
		if popup_name == "RopePuzzlePopup":
			state["display"] = _properties(popup.machine_display)
		if popup_name in ["MillRepairPopup", "MillOperationPopup"]:
			state["display"] = _properties(popup.workbench)
		if popup.get("awaiting_retry") == true:
			state["retry_reason"] = popup.failure_reason if popup_name == "WheelwrightForgePopup" else popup.retry_notice.reason_label.text
		saved["popup"] = {"name": popup_name, "state": state}
		break
	return saved

static func restore(scene: Node, saved: Dictionary) -> void:
	if scene.scene_file_path == GameState.PHASE_TWO_SCENE:
		scene.restore_session_state(saved)
		return
	if saved.has("travel_elapsed") and scene.has_method("_apply_timeline"):
		scene.elapsed = clampf(float(saved.travel_elapsed), 0, scene.TOTAL_TIME - 0.01)
		scene._apply_timeline(scene.elapsed)
		if scene.scene_file_path.ends_with("boat_travel.tscn"):
			scene.last_position = scene.boat.position
		else:
			scene.last_coach_position = scene.coach.position
			scene.last_stage = scene.stage
		return
	var player := scene.get_node_or_null("World/Player")
	if player == null:
		return
	var coordinates: Array = saved.get("position", [player.position.x, player.position.y])
	if coordinates.size() == 2:
		player.position = Vector2(float(coordinates[0]), float(coordinates[1]))
	var facing := str(saved.get("facing", "down"))
	player.facing = facing if facing in ["up", "down", "left", "right"] else "down"
	player.velocity = Vector2.ZERO
	player._set_sprite_frame(1)
	var departure := scene.get_node_or_null("TrainDepartureController")
	if departure and saved.has("train"):
		departure.restore_session_state(saved.train)
	var hud := scene.get_node_or_null("HUD")
	if hud:
		hud.restore_session_state(saved.get("hud", {}))
	var active: Dictionary = saved.get("popup", {})
	if active.is_empty() or str(active.get("name", "")) not in POPUPS:
		return
	var popup_name := str(active.name)
	var popup := scene.get_node_or_null(NodePath(popup_name))
	if popup:
		popup.open()
		if not popup.overlay.visible: return
	if not is_instance_valid(popup):
		return
	var state: Dictionary = active.get("state", {}).duplicate(true)
	if popup_name in ["RopePuzzlePopup", "LumberPuzzlePopup", "WheelwrightForgePopup"]:
		# Their authored checkpoints also finish any already validated phase transition.
		state.erase("stage")
		state.erase("forge_stage")
	_apply_properties(popup, state)
	# Closing a resumed popup must restore movement, regardless of the old modal.
	popup.player_was_enabled = true
	if state.has("display"):
		var display: Node = popup.machine_display if popup_name == "RopePuzzlePopup" else popup.workbench
		_apply_properties(display, state.display)
	match popup_name:
		"WheelwrightForgePopup":
			popup._show_stage()
			popup._sync_workbench()
		"RopePuzzlePopup":
			popup._sync_machine()
			popup._set_step_rail()
		"LumberPuzzlePopup":
			popup._update_adjustments()
			popup._sync_workbench()
		"MillOperationPopup":
			popup.gate_slider.set_value_no_signal(popup.gate_opening)
			popup._sync_machine()
			popup._update_interface()
		"MillRepairPopup":
			popup.adjustment_slider.set_value_no_signal(popup.tension)
			popup._refresh()
	player.controls_enabled = false
	if state.has("retry_reason"):
		popup.awaiting_retry = true
		popup.action_locked = true
		if popup_name == "WheelwrightForgePopup":
			popup.failure_reason = str(state.retry_reason)
			popup.retry_label.text = "%s\n\nQuedan %d de %d oportunidades. Continúas en esta fase; conservas los pasos y ajustes completados." % [state.retry_reason, GameState.flags.forge_attempts_left, GameState.get_forge_opportunities()]
			popup.retry_panel.show()
			popup.retry_button.grab_focus()
			popup.retry_button.text = "Continuar esta fase · %d / %d" % [GameState.flags.forge_attempts_left, GameState.get_forge_opportunities()]
		else:
			popup.retry_notice.show_error(str(state.retry_reason), GameState.get_rope_attempts_left() if popup_name == "RopePuzzlePopup" else GameState.get_lumber_attempts_left(), GameState.get_forge_opportunities())

static func _properties(node: Node) -> Dictionary:
	var saved := {}
	for property in node.get_property_list():
		var field := str(property.name)
		if not int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE or field in TRANSIENT or "held" in field or field.begins_with("pointer_") or field.begins_with("dragging"):
			continue
		var value: Variant = node.get(field)
		if _serializable(value): saved[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return saved

static func _serializable(value: Variant) -> bool:
	if value is Array or value is Dictionary:
		for item in value.values() if value is Dictionary else value:
			if not _serializable(item): return false
		return true
	return typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]

static func _apply_properties(node: Node, saved: Dictionary) -> void:
	for property in node.get_property_list():
		var field := str(property.name)
		if not saved.has(field) or field in TRANSIENT or "held" in field or field.begins_with("pointer_") or field.begins_with("dragging"):
			continue
		var current: Variant = node.get(field)
		var value: Variant = saved[field]
		if not _serializable(current) or not _serializable(value): continue
		match typeof(current):
			TYPE_INT: node.set(field, int(value))
			TYPE_FLOAT: node.set(field, float(value))
			TYPE_BOOL: node.set(field, bool(value))
			TYPE_STRING, TYPE_STRING_NAME: node.set(field, str(value))
			TYPE_ARRAY:
				if value is Array: current.assign(value)
			TYPE_DICTIONARY:
				if value is Dictionary: node.set(field, value.duplicate(true))
