extends Control
## A six-step artisan workshop. The world owns the clock and modal pause state.
signal closed
signal completed
const Model := preload("res://scripts/core/foundry_workshop.gd")
const Board := preload("res://scripts/puzzles/foundry_workshop_board.gd")
const Audio := preload("res://scripts/world/railway_audio.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const GOLD := Color("e7bf70")
var model: Model
var paused: bool = false
var board: Board
var title: Label
var guide: Label
var budget: Label
var progress: Label
var instruction: Label
var lesson: Label
var confirm_button: Button
var shown_step: int = -1
var save_clock: float = 0.0
var active_touch: int = -1
var step_marks: Array[Label] = []
var help_open := false
var sound_stamp := ""
var last_notice := ""
var notice_age := 0.0

func _ready() -> void:
	size = Vector2(1152, 648)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wood := StyleBoxTexture.new()
	wood.texture = preload("res://assets/gba/ui/story_walnut_brass_panel.svg")
	wood.set_texture_margin_all(18)
	frame.add_theme_stylebox_override("panel", wood)
	add_child(frame)
	title = _label(Rect2(24, 14, 610, 36), 24)
	guide = _label(Rect2(24, 55, 860, 38), 17)
	budget = _label(Rect2(906, 68, 222, 28), 14)
	board = Board.new()
	board.position = Vector2(20, 100)
	board.size = Vector2(1112, 454)
	board.worked.connect(_worked)
	add_child(board)
	progress = _label(Rect2(305, 607, 590, 30), 15)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction = _label(Rect2(35, 563, 1080, 28), 15)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_color_override("font_color", Color("efe3c9"))
	lesson = _label(Rect2(190, 165, 770, 245), 20)
	lesson.add_theme_color_override("font_color", Color("fff0d0"))
	var help_style := StyleBoxFlat.new()
	help_style.bg_color = Color("171e1bf5")
	help_style.border_color = GOLD
	help_style.set_border_width_all(2)
	help_style.set_content_margin_all(20)
	lesson.add_theme_stylebox_override("normal", help_style)
	lesson.hide()
	_button("‹ Volver", Rect2(20, 603, 145, 33), close)
	_button("Ayuda · H", Rect2(176, 603, 116, 33), toggle_help)
	confirm_button = _button("Comprobar · Enter", Rect2(913, 603, 218, 33), confirm)
	for index in 6:
		var mark := _label(Rect2(640 + index * 39, 18, 35, 32), 20)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.text = str(index + 1)
		step_marks.append(mark)
	hide()

func _label(rect: Rect2, height: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", height)
	label.add_theme_color_override("font_color", GOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(text: String, rect: Rect2, action: Callable, parent: Node = self) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3c3021")
	style.border_color = Color("b18548")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("685034")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func open(saved: Dictionary = {}) -> void:
	model = Model.new()
	paused = false
	shown_step = -1
	help_open = false
	lesson.hide()
	board.modulate = Color.WHITE
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	sound_stamp = ""
	board.configure(model, saved.get("board", {}))
	cancel_gesture()
	show()
	grab_focus()
	_sync()
	GameState.save_progress()

func is_open() -> bool:
	return visible and model != null

func close() -> void:
	cancel_gesture()
	hide()
	closed.emit()
	GameState.save_progress()

func snapshot() -> Dictionary:
	return {"version": 2, "board": board.snapshot()}

func cancel_gesture() -> void:
	active_touch = -1
	if board != null: board.cancel_drag()

func set_paused(value: bool) -> void:
	if value and not paused: cancel_gesture()
	paused = value
	if board != null: board.paused = value
	if value: _stop_audio()

func _stop_audio() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.queue_free()

func _exit_tree() -> void:
	_stop_audio()

func _worked() -> void:
	if model == null: return
	_sync()
	var stamp := "%s/%s/%s/%s/%s" % [str(model.data.strikes), str(model.data.filed), str(model.data.holes), str(model.data.pins), str(model.data.link)]
	if stamp != sound_stamp:
		if not paused and model.allowed() and not sound_stamp.is_empty() and DisplayServer.get_name() != "headless": Audio.mechanism(self)
		sound_stamp = stamp
	if bool(model.data.done): _complete()

func _complete() -> void:
	if not is_open(): return
	cancel_gesture()
	hide()
	completed.emit()
	closed.emit()
	GameState.save_progress()

func toggle_help() -> void:
	help_open = not help_open
	cancel_gesture()
	lesson.text = "CORT · %s\n\n%s\n\n%s" % [Model.TITLES[model.step()], Model.LESSONS[model.step()], model.hint]
	lesson.visible = help_open
	board.modulate = Color("64645c") if help_open else Color.WHITE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE if help_open else Control.MOUSE_FILTER_STOP
	grab_focus()

func confirm() -> void:
	if paused or help_open or not is_open(): return
	var previous := model.step()
	model.confirm()
	if model.step() != previous:
		board.selected = 0
		board.cancel_drag()
	grab_focus()
	_sync()
	GameState.save_progress()

func _sync() -> void:
	if model == null: return
	if shown_step != model.step():
		shown_step = model.step()
		for index in 6:
			step_marks[index].add_theme_color_override("font_color", Color("b9df89") if index < shown_step else GOLD if index == shown_step else Color("88745a"))
			var marker_style := StyleBoxFlat.new()
			marker_style.bg_color = Color("34402b") if index < shown_step else Color("584028") if index == shown_step else Color("211f19")
			marker_style.border_color = Color("758452") if index < shown_step else GOLD if index == shown_step else Color("635139")
			marker_style.set_border_width_all(1)
			marker_style.set_corner_radius_all(14)
			step_marks[index].add_theme_stylebox_override("normal", marker_style)
	title.text = "%d. %s" % [model.step() + 1, Model.TITLES[model.step()]]
	guide.text = Model.GUIDES[model.step()]
	budget.text = "%s · %d / %d oportunidades" % ["Fácil" if model.easy else "Difícil", Campaign.remaining(), Campaign.total()]
	if last_notice != model.feedback:
		last_notice = model.feedback
		notice_age = 0.0
	instruction.text = model.feedback if not model.feedback.is_empty() and notice_age < 4 else board.hover_hint if not board.hover_hint.is_empty() else board.tool_hint(Vector2.ZERO)
	match model.step():
		0: progress.text = "%d / 2 medidas · %d / 2 mordazas fijas" % [int(bool(model.data.measured[0])) + int(bool(model.data.measured[1])), int(float(model.data.clamps[0]) >= 0.95) + int(float(model.data.clamps[1]) >= 0.95)]
		1: progress.text = "✓ Calor uniforme aprobado · Pulsa Continuar" if bool(model.data.heat_approved) else "Reparte el calor entre las tres zonas"
		2: progress.text = "%d / 6 golpes · %s" % [int(model.data.strikes[0]) + int(model.data.strikes[1]) + int(model.data.strikes[2]), ["Ojo pequeño", "Cuello", "Ojo grande"][int(model.data.zone)]]
		3: progress.text = "%d / 2 ojos perforados" % [int(bool(model.data.holes[0])) + int(bool(model.data.holes[1]))]
		4: progress.text = "Ajuste correcto" if bool(model.data.fitted) else "Lima las rebabas; la plantilla indica dónde roza"
		5: progress.text = "%.1f / 3 vueltas · %.1f / 1 con freno" % [float(model.data.turns), float(model.data.loaded_turns)]
	confirm_button.text = "Revisar montaje" if model.step() == 5 else "Continuar · Enter"
	confirm_button.disabled = paused or help_open or not model.can_confirm() or not model.allowed()
	board.sync()

func advance(delta: float) -> void:
	if not is_open() or paused or help_open: return
	if bool(model.data.done):
		_complete()
		return
	if not model.allowed(): return
	notice_age += delta
	board.advance(delta)
	var previous := model.step()
	var heat_was_approved := bool(model.data.heat_approved)
	model.advance(delta)
	if model.step() != previous or (not heat_was_approved and bool(model.data.heat_approved)):
		board.cancel_drag()
		board.hover_hint = ""
		grab_focus()
	_sync()
	save_clock += delta
	if bool(model.data.done):
		_complete()
	elif save_clock >= 1:
		save_clock = 0
		GameState.save_progress()

func pointer_down(at: Vector2) -> void:
	if paused or help_open or not is_open(): return
	if Rect2(board.position, board.size).has_point(at): board.pointer_down((at - board.position) * Board.NATIVE / board.size)

func pointer_move(at: Vector2) -> void:
	if not paused and not help_open and is_open(): board.pointer_move((at - board.position) * Board.NATIVE / board.size)

func pointer_up(at: Vector2) -> void:
	if not paused and not help_open and is_open(): board.pointer_up((at - board.position) * Board.NATIVE / board.size)
	active_touch = -1

func keyboard(event: InputEventKey) -> void:
	if paused or not is_open() or event.echo or not model.allowed(): return
	if event.pressed and event.keycode == KEY_H:
		toggle_help()
		get_viewport().set_input_as_handled()
		return
	if help_open: return
	var focused := get_viewport().gui_get_focus_owner()
	if event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and focused is Button and is_ancestor_of(focused) and focused.is_visible_in_tree():
		if not focused.disabled: focused.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		confirm()
		get_viewport().set_input_as_handled()
	elif board.keyboard(event): get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		keyboard(event)
		return
	if paused: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: pointer_down(event.position)
		else: pointer_up(event.position)
	elif event is InputEventMouseMotion: pointer_move(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			pointer_down(event.position)
		elif not event.pressed and event.index == active_touch: pointer_up(event.position)
	elif event is InputEventScreenDrag:
		if event.index == active_touch: pointer_move(event.position)
	else: return
	accept_event()
