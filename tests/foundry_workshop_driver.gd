extends RefCounted
const Board := preload("res://scripts/puzzles/foundry_workshop_board.gd")

static func key(scene: Control, code: Key) -> void:
	press(scene, code, true)
	press(scene, code, false)

static func press(scene: Control, code: Key, down: bool) -> void:
	scene.foundry_view.grab_focus()
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	scene._input(event)

static func touch(scene: Control, from: Vector2, to: Vector2) -> void:
	var board: Control = scene.foundry_view.board
	var ratio := board.size / Board.NATIVE
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = from * ratio
	board._gui_input(press)
	var motion := InputEventScreenDrag.new()
	motion.position = to * ratio
	board._gui_input(motion)
	var release := InputEventScreenTouch.new()
	release.position = to * ratio
	board._gui_input(release)

static func work_step(scene: Control) -> void:
	var view: Control = scene.foundry_view
	var model: RefCounted = view.model
	match model.step():
		0:
			touch(scene, Board.billet_rect(1).get_center(), Board.GAUGE.get_center())
			if model.easy:
				touch(scene, view.board.ruler_rect().get_center(), Vector2(500, 340))
				touch(scene, view.board.caliper_rect().get_center(), Vector2(680, 315))
				for clamp in 2:
					view.board.pointer_down(view.board.clamp_center(clamp))
					scene._process(1.6)
					view.board.pointer_up(view.board.clamp_center(clamp))
			else:
				key(scene, KEY_R)
				key(scene, KEY_C)
				for code in [KEY_Q, KEY_E]:
					press(scene, code, true)
					scene._process(1.6)
					press(scene, code, false)
			key(scene, KEY_ENTER)
		1:
			key(scene, KEY_SPACE)
			var board: Control = view.board
			board.pointer_down(Vector2(420, 330))
			for tick in 900:
				if bool(model.data.heat_approved): break
				var coldest := 0
				for zone in 3:
					if float(model.data.heat_zones[zone]) < float(model.data.heat_zones[coldest]): coldest = zone
				board.pointer_move(Vector2(535 - coldest * 115, 330))
				scene._process(0.1)
			board.pointer_up(Vector2(420, 330))
			key(scene, KEY_ENTER)
		2:
			for index in 3:
				if int(model.data.zone) != index: key(scene, KEY_RIGHT)
				touch(scene, Board.die_rect(index).get_center(), Vector2(580, 410))
				for strike in 2:
					key(scene, KEY_SPACE)
					scene._process(0.8)
			key(scene, KEY_ENTER)
		3:
			key(scene, KEY_C)
			while int(model.data.position) > 0: key(scene, KEY_LEFT)
			for eye in 2:
				if eye == 1:
					for move in 4: key(scene, KEY_RIGHT)
				touch(scene, Vector2(890 + eye * 120, 565), Vector2(600, 285))
				for pulse in 10:
					if bool(model.data.holes[eye]): break
					press(scene, KEY_SPACE, true)
					scene._process(0.5)
					press(scene, KEY_SPACE, false)
					scene._process(0.4)
				scene._process(0.6)
			key(scene, KEY_ENTER)
		4:
			for index in 3:
				while int(model.data.zone) != index: key(scene, KEY_RIGHT)
				for stroke in (3 if model.easy else 4):
					key(scene, KEY_SPACE)
					scene._process(0.2)
			touch(scene, view.board.piece_rect().get_center(), Board.TEMPLATE.get_center())
			key(scene, KEY_ENTER)
		5:
			touch(scene, Vector2(260, 570), Vector2(580, 315))
			var eyes: Array = view.board.mechanism_eyes()
			touch(scene, Vector2(660, 575), eyes[0])
			touch(scene, Vector2(830, 575), eyes[1])
			# A real circular gesture, with light load, never an automatic timer.
			view.board.pointer_down(Vector2(992, 495))
			view.board.pointer_move(Vector2(992, 472))
			view.board.pointer_up(Vector2(992, 472))
			view.board.pointer_down(view.board.crank_point(0))
			for sample in 160:
				if bool(model.data.done): break
				view.board.pointer_move(view.board.crank_point((sample + 1) * 0.18))
				scene._process(0.025)
			view.board.pointer_up(view.board.crank_point(0))

static func finish(scene: Control) -> void:
	for index in 7:
		if not scene.foundry_view.is_open(): break
		work_step(scene)
