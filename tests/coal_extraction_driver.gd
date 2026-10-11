extends RefCounted
## Exercise the same touch, keyboard and confirmation controls as a player.
const Board := preload("res://scripts/puzzles/mining_workshop_board.gd")
const Model := preload("res://scripts/core/coal_extraction.gd")

static func view_point(view: Control, native: Vector2) -> Vector2:
	return view.board.position + native * view.board.size / Board.NATIVE

static func touch(view: Control, from: Vector2, to: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = from * view.board.size / Board.NATIVE
	view.board._gui_input(press)
	var move := InputEventScreenDrag.new()
	move.index = 0
	move.position = to * view.board.size / Board.NATIVE
	view.board._gui_input(move)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = move.position
	view.board._gui_input(release)

static func key(scene: Control, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	scene._input(event)

static func work_step(scene: Control) -> void:
	var view: Control = scene.coal_view
	var board: Control = view.board
	match view.model.step():
		0:
			for index in 3: touch(view, Board.SPOTS[index], Board.SPOTS[index])
		1:
			for index in 3: touch(view, board.support_stock(Model.SUPPORT_ORDER[index]).get_center(), Board.SUPPORT_SLOTS[index].get_center())
		2:
			for index in 3:
				board.selected = index
				view.model.data.selected_vein = index
				while int(view.model.data.damage[index]) < 3:
					key(scene, KEY_SPACE)
					scene._process(0.7)
				scene._process(0.9)
		3:
			for index in 6:
				if int(view.model.data.sorted[index]) == 0:
					touch(view, Board.FRAGMENTS[index], (Board.COAL_BIN if index % 2 == 0 else Board.STONE_BIN).get_center())
		4:
			var solution := [0, 0, 1, 1, 2, 2, 3, 3] if view.model.mission.easy else [0, 1, 2, 3, 2, 3, 0, 1]
			for index in 8: touch(view, board.weight_position(index), board.bag_rect(solution[index]).get_center())
		5:
			for index in 3:
				if int(view.model.data.rails[index]) != Model.RAIL_ORDER[index]:
					touch(view, board.rail_stock(Model.RAIL_ORDER[index]).get_center(), Board.RAIL_SLOTS[index].get_center())
			for index in 2:
				if int(view.model.data.switches[index]) != Model.SWITCH_ORDER[index]:
					touch(view, Board.SWITCHES[index].get_center(), Board.SWITCHES[index].get_center())

static func extract(scene: Control, stop_at_packing: bool = false) -> void:
	var view: Control = scene.coal_view
	scene.application_focused = true
	scene._update_modal_feedback()
	for step_index in 7:
		if not view.is_open(): break
		if bool(view.model.data.travelling):
			if stop_at_packing: break
			scene._process(Model.ROUTE_SECONDS)
			break
		work_step(scene)
		if stop_at_packing and view.model.step() == 5: break
		view.confirm_button.pressed.emit()
	if view.is_open() and not stop_at_packing: push_error("WORKSHOP DRIVER INCOMPLETE: " + JSON.stringify(view.model.data))
	if scene.dialogue.visible and scene.dialogue_kind == "coal_ready": scene._close_dialogue()

static func classify_and_tie(scene: Control) -> void:
	if scene.coal_view.is_open(): extract(scene)
