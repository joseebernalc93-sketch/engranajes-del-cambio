extends CanvasLayer
signal closed
signal workshop_completed(id: String)
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Work := preload("res://scripts/puzzles/factory_work_state.gd")
const Catalog := preload("res://scripts/puzzles/factory_stage_catalog.gd")
const Bench := preload("res://scripts/puzzles/factory_workbench.gd")
const Notice := preload("res://scripts/ui/workshop_retry_notice.gd")
@export_enum("mine", "forge", "engine", "textile") var workshop_id: String = "mine"
var work: Work
var overlay: ColorRect
var panel: Panel
var bench: Bench
var title: Label
var subtitle: Label
var instruction: Label
var budget: Label
var status: Label
var sidebar: Label
var actions: HFlowContainer
var selectors: HBoxContainer
var retry_notice: Notice
var last_stage: int = -1
var focused: bool = true
var chosen_action: String = ""
var audio: AudioStreamPlayer
var audio_generator: AudioStreamGenerator
var audio_remaining: float = 0.0
var audio_phase: float = 0.0
var held_adjust: float = 0.0
var held_tool: bool = false

func _ready() -> void:
	_build()
	overlay.hide()
	set_process(false)

func open_workshop() -> void:
	if not Campaign.unlocked(workshop_id) or Campaign.done(workshop_id): return
	work = Work.new(workshop_id, GameState.is_easy_difficulty())
	var saved: Dictionary = GameState.phase_two.work.get(workshop_id, {})
	if not saved.is_empty(): work.restore(saved)
	work.mistake.connect(_mistake)
	work.finished.connect(_finished)
	bench.work = work
	last_stage = -1
	overlay.show()
	_start_audio()
	set_process(true)
	_sync()
	if work.paused: _show_review()
	_fit()

func close_workshop() -> void:
	if work != null: Campaign.save_work(workshop_id, work.snapshot())
	bench.cancel_drag()
	audio.stop()
	held_adjust = 0.0
	held_tool = false
	overlay.hide()
	set_process(false)
	closed.emit()
	GameState.save_progress()
	Phase2Metrics.request_write()

func _build() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	add_child(overlay)
	panel = Panel.new()
	panel.size = Vector2(1100, 680)
	var frame := StyleBoxTexture.new()
	frame.texture = load("res://assets/gba/ui/story_walnut_brass_panel.svg")
	frame.set_texture_margin_all(30)
	panel.add_theme_stylebox_override("panel", frame)
	overlay.add_child(panel)
	title = _label(Vector2(27, 18), Vector2(650, 33), 25)
	budget = _label(Vector2(685, 22), Vector2(325, 30), 16)
	subtitle = _label(Vector2(27, 56), Vector2(1010, 30), 21)
	instruction = _label(Vector2(27, 90), Vector2(1040, 53), 15)
	bench = Bench.new()
	bench.position = Vector2(27, 147)
	bench.size = Vector2(800, 358)
	bench.workshop_id = workshop_id
	bench.requested.connect(_act)
	bench.selected.connect(_select)
	panel.add_child(bench)
	sidebar = _label(Vector2(845, 153), Vector2(222, 342), 15)
	sidebar.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	selectors = HBoxContainer.new()
	selectors.position = Vector2(27, 511)
	selectors.size = Vector2(800, 29)
	panel.add_child(selectors)
	actions = HFlowContainer.new()
	actions.position = Vector2(27, 552)
	actions.size = Vector2(1036, 88)
	actions.add_theme_constant_override("h_separation", 7)
	panel.add_child(actions)
	status = _label(Vector2(27, 649), Vector2(1040, 20), 12)
	var exit := _button("×", _exit, panel)
	exit.position = Vector2(1034, 23)
	exit.size = Vector2(38, 35)
	retry_notice = Notice.new()
	retry_notice.artisan = Campaign.TUTORS[Campaign.IDS.find(workshop_id)]
	panel.add_child(retry_notice)
	retry_notice.continued.connect(_resume)
	audio = AudioStreamPlayer.new()
	audio_generator = AudioStreamGenerator.new()
	audio_generator.mix_rate = 22050
	audio_generator.buffer_length = 0.1
	audio.stream = audio_generator
	audio.volume_db = -24
	add_child(audio)
	get_viewport().size_changed.connect(_fit)

func _start_audio() -> void:
	if DisplayServer.get_name() != "headless" and focused and not audio.playing: audio.play()

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
	button.custom_minimum_size = Vector2(48, 40)
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/gba/ui/story_walnut_brass_button.svg")
	style.set_texture_margin_all(15)
	style.content_margin_left = 23
	style.content_margin_right = 23
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.2, 1.15, 1.05)
	for state in ["hover", "focus", "pressed"]: button.add_theme_stylebox_override(state, hover)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _fit() -> void:
	if not is_instance_valid(panel): return
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := minf((viewport_size.x - 14.0) / panel.size.x, (viewport_size.y - 14.0) / panel.size.y)
	panel.scale = Vector2.ONE * fit
	panel.position = (viewport_size - panel.size * fit) * 0.5

func _sync() -> void:
	var index := Campaign.IDS.find(workshop_id)
	title.text = Campaign.LABELS[index]
	budget.text = "%s · %d / %d oportunidades" % ["Fácil" if work.easy else "Difícil", Campaign.remaining(), Campaign.total()]
	subtitle.text = "%d. %s" % [work.stage + 1, Catalog.titles(workshop_id)[work.stage]]
	instruction.text = Catalog.instructions(workshop_id, work.stage)
	sidebar.text = "%s\n\n%s\n\n%s" % [Campaign.TUTORS[index].to_upper(), bench.readout(), Campaign.FACTS[index]]
	status.text = "← → / A D: ajustar · ↑ ↓: elegir pieza · Tab: herramientas · Espacio: usar · Enter: confirmar · Esc: volver" + (" · " + work.hint if not work.hint.is_empty() else "")
	if work.danger > 0.0: status.text = "⚠ CORRIGE EL AJUSTE · %.1f s de margen · %s" % [maxf(0.0, work.grace() - work.danger), bench.readout()]
	if last_stage != work.stage:
		last_stage = work.stage
		bench.cancel_drag()
		for node in actions.get_children(): node.free()
		for node in selectors.get_children(): node.free()
		chosen_action = ""
		for specification in Catalog.buttons(workshop_id, work.stage):
			var parts := str(specification).split("|")
			if chosen_action.is_empty(): chosen_action = parts[0]
			var button := _button(parts[1], _act.bind(parts[0], 0.0, -1), actions)
			button.focus_entered.connect(func(): chosen_action = parts[0])
		for selected_index in Catalog.selectors(workshop_id, work.stage):
			var choice := _button("%s %d" % [Catalog.selection_name(workshop_id, work.stage), selected_index + 1], _select.bind(selected_index), selectors)
			choice.toggle_mode = true
			choice.set_meta("piece_index", selected_index)
		if Catalog.adjustable(workshop_id, work.stage):
			_button("− Ajustar", _nudge.bind(-0.02), selectors)
			_button("Ajustar +", _nudge.bind(0.02), selectors)
		if actions.get_child_count() > 0 and not work.paused:
			(actions.get_child(0) as Button).grab_focus()
	for choice in selectors.get_children():
		if choice.has_meta("piece_index"): (choice as Button).set_pressed_no_signal(int(choice.get_meta("piece_index")) == int(work.data.selected))
	bench.queue_redraw()

func _select(index: int) -> void:
	if work == null or work.paused: return
	work.data.selected = index
	_save()
	_sync()

func _nudge(delta: float) -> void:
	var current := float(work.data.adjust)
	if workshop_id == "mine" and work.stage == 4: current = float(work.data.gates[int(work.data.selected)])
	if workshop_id == "mine" and work.stage == 5: current = float(work.data.brake)
	if workshop_id == "engine" and work.stage == 5: current = float(work.data.inlet)
	if workshop_id == "textile" and work.stage == 1: current = float(work.data.tensions[int(work.data.selected)])
	_act("adjust", current + delta, -1)

func _act(action_name: String, value: float = 0.0, selected: int = -1) -> void:
	if work == null or work.paused or not focused: return
	if action_name == "sort_stone":
		action_name = "sort"
		value = 0.0
	elif action_name == "sort_coal":
		action_name = "sort"
		value = 1.0
	elif value == 0.0:
		if action_name == "stir": value = 0.2
		if action_name == "crank": value = 0.12
		if action_name == "cool": value = 0.1
	if workshop_id == "textile":
		if action_name == "emergency" and not bool(work.data.emergency): GameState.phase_two.metrics.emergency_stops = int(GameState.phase_two.metrics.emergency_stops) + 1
		if action_name == "feed": GameState.phase_two.metrics.coal_used = int(GameState.phase_two.metrics.coal_used) + 1
	work.action(action_name, value, selected)
	if action_name in ["hit", "crank", "bolt", "clutch", "skim"]: audio_remaining = 0.07
	_save()
	_sync()

func _process(delta: float) -> void:
	if not focused or work == null or work.paused or work.complete: return
	if not is_zero_approx(held_adjust): _nudge(held_adjust * delta * 0.25)
	if held_tool and chosen_action in ["stir", "crank"]:
		_act(chosen_action, delta * (2.1 if chosen_action == "stir" else 0.24))
	var stats: Dictionary = GameState.phase_two.metrics
	stats.active_seconds = float(stats.active_seconds) + delta
	stats.workshop_seconds[workshop_id] = float(stats.workshop_seconds.get(workshop_id, 0.0)) + delta
	if (workshop_id == "engine" and work.stage == 5) or (workshop_id == "textile" and work.stage == 3 and bool(work.data.running) and not bool(work.data.emergency)):
		stats.pressure_samples = int(stats.pressure_samples) + 1
		stats.pressure_duration = float(stats.get("pressure_duration", 0.0)) + delta
		stats.pressure_error = float(stats.pressure_error) + absf(float(work.data.pressure) - 0.5) * 2.0 * delta
	work.tick(delta)
	if workshop_id == "textile": stats.bales = maxi(int(stats.bales), int(float(work.data.bales)))
	_audio_tick(delta)
	_save()
	_sync()

func _audio_tick(delta: float) -> void:
	if not audio.playing: return
	var playback := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null: return
	audio_remaining = maxf(0.0, audio_remaining - delta)
	for frame in mini(playback.get_frames_available(), 2205):
		audio_phase += 1.0 / 22050.0
		var sample := sin(audio_phase * TAU * 125.0) * 0.18 if audio_remaining > 0.0 else 0.0
		playback.push_frame(Vector2.ONE * sample)

func _save() -> void:
	Campaign.save_work(workshop_id, work.snapshot())

func _mistake(reason: String) -> void:
	Campaign.fail(workshop_id, reason)
	bench.cancel_drag()
	audio.stop()
	held_adjust = 0.0
	held_tool = false
	audio_remaining = 0.0
	_save()
	_show_review()
	GameState.save_progress()

func _show_review() -> void:
	retry_notice.show_error(work.retry_reason, Campaign.remaining(), Campaign.total())
	if Campaign.remaining() == 0:
		retry_notice.heading.text = Campaign.TUTORS[Campaign.IDS.find(workshop_id)] + ": aprendemos practicando"
		retry_notice.opportunities_label.text = "Los oficios se aprendían con práctica y acompañamiento. Abriremos una nueva ronda; conservas los talleres y las etapas superadas."
		retry_notice.continue_button.text = "Comenzar nueva ronda"

func _resume() -> void:
	if Campaign.remaining() == 0: Campaign.new_round()
	work.resume()
	_start_audio()
	retry_notice.hide()
	_save()
	GameState.save_progress()
	_sync()

func _finished() -> void:
	if workshop_id == "textile": GameState.phase_two.metrics.bales = maxi(10, int(GameState.phase_two.metrics.bales))
	_save()
	Campaign.reward(workshop_id)
	workshop_completed.emit(workshop_id)
	close_workshop()

func _exit() -> void:
	if work != null and work.paused: return
	close_workshop()

func _unhandled_key_input(event: InputEvent) -> void:
	if overlay == null or not overlay.visible or not event.is_pressed() or event.is_echo(): return
	var key: int = event.physical_keycode if event is InputEventKey else 0
	if key == 0 and event is InputEventKey: key = event.keycode
	if key == KEY_ESCAPE:
		_exit()
	elif work.paused: return
	elif key in [KEY_LEFT, KEY_A]:
		held_adjust = -1.0
		_nudge(-0.01)
	elif key in [KEY_RIGHT, KEY_D]:
		held_adjust = 1.0
		_nudge(0.01)
	elif key in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
		var count := maxi(1, Catalog.selectors(workshop_id, work.stage))
		_select(posmod(int(work.data.selected) + (-1 if key in [KEY_UP, KEY_W] else 1), count))
	elif key == KEY_ENTER:
		_activate_focused()
	elif key in [KEY_SPACE, KEY_E] and not chosen_action.is_empty():
		var focus_owner := get_viewport().gui_get_focus_owner()
		held_tool = focus_owner != null and actions.is_ancestor_of(focus_owner)
		_activate_focused()
	elif key == KEY_TAB:
		var controls: Array[Control] = []
		for row in [selectors, actions]:
			for child in row.get_children():
				if child is Button and child.visible: controls.append(child)
		if not controls.is_empty():
			var current := controls.find(get_viewport().gui_get_focus_owner())
			controls[posmod(current + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
	else: return
	get_viewport().set_input_as_handled()

func _activate_focused() -> void:
	var control := get_viewport().gui_get_focus_owner()
	if control is Button and (actions.is_ancestor_of(control) or selectors.is_ancestor_of(control)):
		(control as Button).pressed.emit()
	else: _act(chosen_action if not chosen_action.is_empty() else "confirm")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if not event.pressed:
		if event.physical_keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D] or event.keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]: held_adjust = 0.0
		if event.physical_keycode in [KEY_SPACE, KEY_E] or event.keycode in [KEY_SPACE, KEY_E]: held_tool = false
	_unhandled_key_input(event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		if audio != null: audio.stop()
		if bench != null: bench.paused_visual = true
		held_adjust = 0.0
		held_tool = false
		if bench != null: bench.cancel_drag()
		audio_remaining = 0.0
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		if bench != null: bench.paused_visual = false
		if overlay != null and overlay.visible and work != null and not work.paused: _start_audio()
