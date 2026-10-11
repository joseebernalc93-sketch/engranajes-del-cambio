extends CanvasLayer
signal closed
const Mission := preload("res://scripts/core/iron_mission.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Board := preload("res://scripts/puzzles/iron_mission_board.gd")
const Notice := preload("res://scripts/ui/workshop_retry_notice.gd")
const Audio := preload("res://scripts/world/railway_audio.gd")
var mission: Mission
var overlay: ColorRect
var panel: Panel
var board: Board
var title: Label
var instruction: Label
var budget: Label
var actions: HFlowContainer
var notice: Notice
var refill: bool = false
var last_stage: int = -1
var application_focused: bool = true
var suspended: bool = false
var gear_test_time: float = 0.0

func _ready() -> void:
	layer = 20
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	add_child(overlay)
	panel = Panel.new()
	panel.size = Vector2(1060, 610)
	var frame := StyleBoxTexture.new()
	frame.texture = preload("res://assets/gba/ui/story_walnut_brass_panel.svg")
	frame.set_texture_margin_all(25)
	panel.add_theme_stylebox_override("panel", frame)
	overlay.add_child(panel)
	title = _label(Vector2(25, 18), Vector2(810, 34), 24)
	budget = _label(Vector2(760, 25), Vector2(250, 28), 14)
	instruction = _label(Vector2(25, 61), Vector2(990, 55), 15)
	board = Board.new()
	board.position = Vector2(30, 120)
	board.size = Vector2(1000, 390)
	board.requested.connect(_action)
	panel.add_child(board)
	actions = HFlowContainer.new()
	actions.position = Vector2(30, 521)
	actions.size = Vector2(1000, 70)
	actions.add_theme_constant_override("h_separation", 8)
	panel.add_child(actions)
	var exit := _button("×", close, panel)
	exit.position = Vector2(1010, 20)
	exit.custom_minimum_size = Vector2(28, 28)
	exit.size = Vector2(28, 28)
	notice = Notice.new()
	panel.add_child(notice)
	notice.continued.connect(_resume)
	get_viewport().size_changed.connect(_fit)
	overlay.hide()

func _label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("efd59a"))
	panel.add_child(label)
	return label

func _button(text: String, callback: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(95, 34)
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2c302d")
	style.border_color = Color("ad8348")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(9)
	button.add_theme_stylebox_override("normal", style)
	var focus := style.duplicate() as StyleBoxFlat
	focus.border_color = Color("efc879")
	focus.bg_color = Color("51412d")
	for state in ["hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, focus)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func open(model: Mission, replenish: bool = false) -> void:
	if not replenish and model.stage() == 2 and not bool(model.data.biela_installed): return
	mission = model
	refill = replenish
	board.mission = model
	board.refill = replenish
	board.selected = 0
	last_stage = -1
	suspended = false
	overlay.show()
	_sync()
	_fit()
	GameState.save_progress()

func is_open() -> bool:
	return is_instance_valid(overlay) and overlay.visible

func close() -> void:
	if not is_open(): return
	board.cancel_drag()
	gear_test_time = 0.0
	board.gears_turning = false
	board.tools_locked = false
	overlay.hide()
	closed.emit()
	GameState.save_progress()

func _fit() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf((viewport_size.x - 14) / panel.size.x, (viewport_size.y - 14) / panel.size.y)
	panel.scale = Vector2.ONE * factor
	panel.position = (viewport_size - panel.size * factor) * 0.5

func _process(delta: float) -> void:
	if not is_open() or suspended or not application_focused: return
	mission.tick(delta)
	if gear_test_time > 0.0:
		gear_test_time = maxf(0.0, gear_test_time - delta)
		if gear_test_time == 0.0:
			board.gears_turning = false
			board.tools_locked = false
			mission.test_gears()
	if mission.blocked(): board.cancel_drag()
	else: board.update_visual(delta)
	_sync()

func _sync() -> void:
	if mission == null: return
	title.text = ("Reponer carbón" if refill else "%d. %s" % [mission.stage() + 1, Mission.TITLES[mission.stage()]])
	budget.text = "%s · %d / %d oportunidades" % ["Fácil" if mission.easy else "Difícil", Campaign.remaining(), Campaign.total()]
	instruction.text = "Extrae seis fragmentos con golpes separados; después arrastra la hulla al costal y la piedra al descarte." if refill or mission.stage() == 1 else {2: "Arrastra las tres ruedas a los ejes del tamaño correspondiente. Prueba la manivela cuando todos los dientes engranen.", 3: "Gira los tubos. Cierra el circuito de alimentación de la caldera y el circuito separado de agua fría del condensador.", 4: "Prepara el agua, coloca carbón del inventario y enciende el hogar. Conserva combustible para el ensayo.", 5: "Alimenta el fuego y regula la descarga con la palanca. Mantén la aguja en verde durante dos minutos. Esc abre el cuaderno."}.get(mission.stage(), "")
	var effective_stage := 1 if refill else mission.stage()
	if effective_stage >= 4 and mission.fuel_available() == 0:
		instruction.text = "No quedan paladas de carbón. Vuelve a Caleb para reponer costales: conservarás el montaje y el tiempo estable."
	var needs_sort := effective_stage == 1 and int(mission.data.refill_hits if refill else mission.data.hits) >= 6
	var signature := effective_stage * 10 + (1 if needs_sort else 0)
	if signature != last_stage:
		last_stage = signature
		for child in actions.get_children():
			actions.remove_child(child)
			child.queue_free()
		if effective_stage == 1:
			if needs_sort:
				_button("Fragmento anterior", func(): _select(-1, 6), actions)
				_button("Siguiente fragmento", func(): _select(1, 6), actions)
				_button("Separar piedra", func(): _action("sort", board.selected, 0), actions)
				_button("Guardar carbón", func(): _action("sort", board.selected, 1), actions)
			else: _button("Golpear piqueta · Espacio", func(): _action("hit", -1, 0), actions)
		elif effective_stage == 2:
			_button("Cambiar rueda", func(): board.selected_gear = posmod(board.selected_gear + 1, 3); board.queue_redraw(), actions)
			_button("Cambiar eje", func(): _select(1, 3), actions)
			_button("Colocar rueda", func(): _action("place", board.selected, board.selected_gear), actions)
			_button("Retirar rueda", func(): mission.data.gears[board.selected] = -1; mission.persist(), actions)
			_button("Probar manivela", func(): _action("gears", -1, 0), actions)
		elif effective_stage == 3:
			_button("Tubo anterior", func(): _select(-1, 6), actions)
			_button("Siguiente tubo", func(): _select(1, 6), actions)
			_button("Girar tubo", func(): _action("pipe", board.selected, 0), actions)
			_button("Probar agua", func(): _action("water_test", -1, 0), actions)
		elif effective_stage == 4:
			_button("Preparar agua", func(): _action("water", -1, 0), actions)
			_button("Palear carbón", func(): _action("feed", -1, 0), actions)
			_button("Encender hogar", func(): _action("ignite", -1, 0), actions)
		elif effective_stage == 5:
			_button("Iniciar / detener ensayo", func(): _action("run", -1, 0), actions)
			_button("Palear carbón · Espacio", func(): _action("feed", -1, 0), actions)
			_button("Cerrar descarga · ←", func(): _action("valve", -1, float(mission.data.valve) - 0.05), actions)
			_button("Abrir descarga · →", func(): _action("valve", -1, float(mission.data.valve) + 0.05), actions)
		_button("Volver al escenario", close, actions)
		if is_open() and actions.get_child_count() > 0: (actions.get_child(0) as Button).grab_focus()
	if not str(mission.data.review).is_empty() and not notice.visible: show_review()
	board.update_visual(0.0)

func show_review() -> void:
	board.cancel_drag()
	notice.artisan = "Caleb" if mission.stage() <= 1 or refill else "Murdoch"
	notice.show_error(str(mission.data.review), Campaign.remaining(), Campaign.total())
	if Campaign.remaining() == 0:
		notice.heading.text = "Vamos a intentarlo de nuevo"
		notice.opportunities_label.text = "Una nueva ronda recupera las oportunidades. Conservas las etapas superadas, el montaje, el combustible restante y el tiempo estable."
		notice.continue_button.text = "Iniciar nueva ronda"

func _resume() -> void:
	mission.resume()
	notice.hide()
	_sync()

func _select(direction: int, count: int) -> void:
	board.selected = posmod(board.selected + direction, count)
	board.queue_redraw()

func _action(action_name: String, index: int, value: float) -> void:
	if mission == null or mission.blocked() or suspended or gear_test_time > 0.0: return
	match action_name:
		"hit": mission.hit(refill)
		"sort": mission.sort_fragment(index, value > 0.5, refill)
		"place": mission.place_gear(index, int(value))
		"gears":
			if mission.data.gears == Mission.GEAR_ORDER:
				gear_test_time = 1.2
				board.gears_turning = true
				board.tools_locked = true
			else: mission.test_gears()
		"pipe": mission.rotate_pipe(index)
		"water_test": mission.test_water()
		"water": mission.fill_water()
		"feed": mission.feed()
		"ignite": mission.ignite()
		"run": mission.run()
		"valve": mission.set_valve(value)
	board.queue_redraw()
	if DisplayServer.get_name() != "headless": Audio.mechanism(self)
	if refill and mission.data.refill_sorted.is_empty() and int(mission.data.refill_hits) == 0: close()
	elif not refill and mission.stage() == 2 and action_name == "sort": close()
	_sync()

func _input(event: InputEvent) -> void:
	if not is_open() or suspended or not application_focused: return
	if event is InputEventKey and event.pressed and not event.echo:
		if notice.visible:
			if event.keycode in [KEY_ENTER, KEY_SPACE]: _resume()
			elif event.keycode == KEY_TAB: notice.continue_button.grab_focus()
			else: return
		elif event.keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
			var direction := -1 if event.keycode in [KEY_LEFT, KEY_A] else 1
			if mission.stage() == 5: _action("valve", -1, float(mission.data.valve) + direction * 0.025)
			else: _select(direction, 3 if mission.stage() == 2 else 6)
		elif event.keycode in [KEY_UP, KEY_W, KEY_DOWN, KEY_S] and mission.stage() == 2:
			board.selected_gear = posmod(board.selected_gear + 1, 3)
			board.queue_redraw()
		elif event.keycode == KEY_SPACE:
			match 1 if refill else mission.stage():
				1:
					if int(mission.data.refill_hits if refill else mission.data.hits) < 6: _action("hit", -1, 0)
					else: _action("sort", board.selected, 1)
				2: _action("place", board.selected, board.selected_gear)
				3: _action("pipe", board.selected, 0)
				4, 5: _action("feed", -1, 0)
		else: return
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_focused = false
		if is_instance_valid(board): board.cancel_drag()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: application_focused = true
