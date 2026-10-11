extends Control
## A six-step artisan workshop. The world owns the clock and modal pause state.
signal closed
signal completed
const Model := preload("res://scripts/core/coal_extraction.gd")
const Mission := preload("res://scripts/core/iron_mission.gd")
const Board := preload("res://scripts/puzzles/mining_workshop_board.gd")
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
var tools: Control
var shown_step: int = -1
var save_clock: float = 0.0
var active_touch: int = -1

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
	title = _label(Rect2(24, 14, 865, 36), 25)
	guide = _label(Rect2(24, 55, 850, 49), 17)
	budget = _label(Rect2(906, 68, 222, 28), 14)
	board = Board.new()
	board.position = Vector2(20, 112)
	board.size = Vector2(865, 478)
	board.worked.connect(_worked)
	add_child(board)
	var sidebar := Panel.new()
	sidebar.position = Vector2(903, 112)
	sidebar.size = Vector2(228, 478)
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("121916f5")
	style.border_color = Color("79633c")
	style.set_border_width_all(1)
	sidebar.add_theme_stylebox_override("panel", style)
	add_child(sidebar)
	_label(Rect2(920, 130, 194, 55), 16).text = "OFICIO MANUAL\nTALLER DEL MINERO"
	lesson = _label(Rect2(920, 200, 194, 155), 16)
	progress = _label(Rect2(920, 367, 194, 57), 16)
	instruction = _label(Rect2(920, 435, 194, 103), 14)
	instruction.add_theme_color_override("font_color", Color("e6dfce"))
	_button("Volver al escenario", Rect2(918, 548, 198, 32), close)
	tools = Control.new()
	tools.position = Vector2(20, 600)
	tools.size = Vector2(865, 36)
	add_child(tools)
	confirm_button = _button("Continuar", Rect2(903, 600, 228, 36), confirm)
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

func open(mission: Mission, refill: bool = false, saved: Dictionary = {}) -> void:
	model = Model.new(mission, refill)
	if refill: mission.data.running = false
	paused = false
	shown_step = -1
	board.configure(model, saved.get("board", {}) if int(saved.get("version", 0)) == 3 else {})
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
	return {"version": 3, "board": board.snapshot()}

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
	if not paused and not model.mission.blocked(): Audio.mechanism(self)

func confirm() -> void:
	if paused or not is_open(): return
	var previous := model.step()
	if model.confirm(): Audio.mechanism(self)
	if model.step() != previous:
		board.selected = 0
		board.cancel_drag()
		grab_focus()
	_sync()
	GameState.save_progress()

func _choose_piece(index: int) -> void:
	if paused: return
	grab_focus()
	board.piece = index
	board.sync()

func _choose_bag(index: int) -> void:
	if paused: return
	grab_focus()
	board.bag = index
	board.sync()

func _sort(coal: bool) -> void:
	if paused: return
	grab_focus()
	board.coal_bin = coal
	model.sort(board.selected % 6, coal)
	_worked()

func _hit() -> void:
	if paused: return
	grab_focus()
	model.hit()
	_worked()

func _empty_bag() -> void:
	if paused: return
	grab_focus()
	model.empty_bag(board.bag)
	_worked()

func _toggle(index: int) -> void:
	if paused: return
	grab_focus()
	model.toggle_switch(index)
	_worked()

func _make_tools() -> void:
	for child in tools.get_children():
		tools.remove_child(child)
		child.queue_free()
	var labels: Array = []
	var actions: Array[Callable] = []
	match model.step():
		0:
			labels = ["Señalar hulla · Espacio"]
			actions = [func():
				if not paused:
					model.recognise(board.selected % 6)
					_worked()]
		1:
			labels = ["1 · Puntal inclinado /", "2 · Puntal vertical", "3 · Puntal inclinado \\"]
			for index in 3: actions.append(_choose_piece.bind(index))
		2:
			labels = ["Golpear piqueta · Espacio"]
			actions = [_hit]
		3:
			labels = ["Hulla → vagoneta · C", "Piedra → descarte · X"]
			actions = [_sort.bind(true), _sort.bind(false)]
		4:
			labels = ["Costal 1", "Costal 2", "Costal 3", "Costal 4", "Vaciar costal"]
			for index in 4: actions.append(_choose_bag.bind(index))
			actions.append(_empty_bag)
		5:
			labels = ["1 · Recta", "2 · Bajada", "3 · Subida", "Desvío · Q", "Desvío · W"]
			for index in 3: actions.append(_choose_piece.bind(index))
			actions.append(_toggle.bind(0))
			actions.append(_toggle.bind(1))
	var width := minf(260, 865.0 / labels.size())
	for index in labels.size():
		_button(str(labels[index]), Rect2(index * width, 0, width - 8, 36), actions[index], tools)

func _sync() -> void:
	if model == null: return
	if shown_step != model.step():
		shown_step = model.step()
		_make_tools()
	title.text = "%d. %s" % [model.step() + 1, Model.TITLES[model.step()]]
	guide.text = Model.GUIDES[model.step()]
	budget.text = "%s · %d / %d oportunidades" % ["Fácil" if model.mission.easy else "Difícil", Campaign.remaining(), Campaign.total()]
	lesson.text = Model.LESSONS[model.step()]
	instruction.text = model.hint
	var count := 0
	match model.step():
		0:
			for value in model.data.recognised: count += int(bool(value))
			progress.text = "%d / 3 vetas reconocidas" % count
		1:
			for value in model.data.supports: count += int(int(value) >= 0)
			progress.text = "%d / 3 puntales colocados" % count
		2:
			for value in model.data.damage: count += int(value)
			progress.text = "%d / 9 golpes\n← → Cambiar veta" % count
		3:
			for value in model.data.sorted: count += int(int(value) > 0)
			progress.text = "%d / 6 piezas separadas" % count
		4: progress.text = "%d / 4 costales equilibrados" % model.bags()
		5: progress.text = "Carga en camino…" if bool(model.data.travelling) else "4 costales listos\nDestino: elevador"
	confirm_button.text = "Transportando…" if bool(model.data.travelling) else "Probar recorrido · Enter" if model.step() == 5 else "Comprobar · Enter" if model.step() in [1, 4] else "Continuar · Enter"
	confirm_button.disabled = paused or not model.can_confirm() or not model.allowed()
	board.sync()

func advance(delta: float) -> void:
	if not is_open() or paused or model.mission.blocked(): return
	model.advance(delta)
	_sync()
	save_clock += delta
	if bool(model.data.done):
		cancel_gesture()
		hide()
		completed.emit()
		closed.emit()
		GameState.save_progress()
	elif save_clock >= 1:
		save_clock = 0
		GameState.save_progress()

func pointer_down(at: Vector2) -> void:
	if paused or not is_open(): return
	if Rect2(board.position, board.size).has_point(at): board.pointer_down((at - board.position) * Board.NATIVE / board.size)

func pointer_move(at: Vector2) -> void:
	if not paused and is_open(): board.pointer_move((at - board.position) * Board.NATIVE / board.size)

func pointer_up(at: Vector2) -> void:
	if not paused and is_open(): board.pointer_up((at - board.position) * Board.NATIVE / board.size)
	active_touch = -1

func keyboard(event: InputEventKey) -> void:
	if paused or not is_open() or event.echo or model.mission.blocked(): return
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
