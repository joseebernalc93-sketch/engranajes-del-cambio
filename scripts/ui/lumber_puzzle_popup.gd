extends CanvasLayer
## Bruno's modal owns opportunity accounting and integrates the simulated bench with saves.
const State = preload("res://scripts/ui/lumber_work_state.gd")
const RetryNotice = preload("res://scripts/ui/workshop_retry_notice.gd")
const STAGE_INSPECT := State.Stage.INSPECT
const STAGE_MEASURE := State.Stage.MEASURE
const STAGE_SECURE := State.Stage.SECURE
const STAGE_SAW := State.Stage.SAW
const STAGE_PLANE := State.Stage.PLANE
const STAGE_TEST := State.Stage.LOAD
const STAGE_COMPLETE := State.Stage.COMPLETE
const TITLES := ["Inspeccionar la veta", "Medir y trazar", "Inmovilizar la tabla", "Serrar a mano", "Cepillar a favor de veta", "Ensayar la flexión", "Tabla terminada"]
const GUIDES := [
	"Mueve la plantilla sobre un tramo sin defectos. La lupa revela nudos, fisuras y porosidad.",
	"Desliza el tope hasta 160 cm, gira la escuadra a 90° y traza las dos incisiones de arriba abajo.",
	"Encaja las tres cuñas y asiéntalas con tres golpes. Gira la mordaza a verde y comprueba la rigidez.",
	"Alterna cinco recorridos completos, sin tirones. Una hoja forzada se encalla; una muy lenta resbala.",
	"Ajusta la cuchilla a verde. Avanza por las cuatro franjas desde la izquierda, sin volver contra la veta.",
	"Coloca los sacos en el centro. Compensa con la palanca y mantén la aguja en verde durante 1,2 s.",
	"Bruno te entrega una tabla de soporte de la bancada. Llévala al molino para instalarla."]
const LESSONS := [
	"Los nudos desvían las fibras; las grietas concentran esfuerzos. Seleccionar bien evita desperdiciar madera.",
	"Antes de mecanizar el taller, cada unión dependía del trazado cuidadoso del artesano.",
	"Las cuñas y el tornillo convierten fuerza manual en sujeción. Una pieza estable permite trabajar con precisión.",
	"El serrado exige tiempo, alineación y cadencia. La mecanización transformó el ritmo de este trabajo.",
	"Una viruta fina deja una superficie uniforme. El cepillo trabaja mejor siguiendo la dirección de las fibras.",
	"La madera se deforma bajo carga. El ensayo es una representación educativa de su respuesta elástica.",
	"Seis operaciones manuales convierten una materia prima en una pieza que permite mover otras máquinas."]
const TOOLS := [
	[["template", "Plantilla"], ["lens", "Lupa"]],
	[["rule", "Regla"], ["square", "Escuadra"], ["scribe", "Gramil"]],
	[["wedge0", "Cuña 1"], ["wedge1", "Cuña 2"], ["wedge2", "Cuña 3"], ["vice", "Mordaza"]],
	[["saw", "Sierra de bastidor"]],
	[["depth", "Rueda de cuchilla"], ["plane", "Garlopa"]],
	[["sack", "Saco de prueba"], ["lever", "Palanca"]], []]

@export var autosave_interval: float = 1.0
@onready var overlay: ColorRect = %LumberOverlay
@onready var panel: Panel = %Panel
@onready var workbench: LumberWorkbenchDisplay = %WorkbenchDisplay
@onready var stage_label: Label = %StageLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var opportunities_label: Label = %OpportunitiesLabel
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel
@onready var wood_hint: Label = %WoodHint
@onready var tool_row: HBoxContainer = %ToolRow
@onready var confirm_button: Button = %ConfirmButton
@onready var close_button: Button = %CloseButton
@onready var action_audio: AudioStreamPlayer = %ActionAudio
@onready var tool_audio: AudioStreamPlayer = %ToolAudio
var model: LumberWorkState
var retry_notice: Control
var awaiting_retry: bool = false
var action_locked: bool = false
var player_was_enabled: bool = true
var application_focused: bool = true
var restoring_work: bool = false
var save_age: float = 0.0
var shown_stage: int = -1
var saved_signature: String = ""
var stage: int:
	get: return model.stage if model else 0

func _ready() -> void:
	retry_notice = RetryNotice.new()
	panel.add_child(retry_notice)
	retry_notice.artisan = "Bruno"
	retry_notice.continued.connect(_continue_current_phase)
	EventBus.lumber_puzzle_requested.connect(open)
	close_button.pressed.connect(close)
	confirm_button.pressed.connect(_confirm)
	workbench.tool_selected.connect(func(_tool: String): _refresh_tools())
	workbench.gesture_finished.connect(_save_work)
	workbench.offcut_landed.connect(func(): action_audio.play())
	get_viewport().size_changed.connect(_fit_panel)
	action_audio.stream = _wood_sound(false)
	tool_audio.stream = _wood_sound(true)
	_style_button(confirm_button)
	_style_button(close_button)
	_fit_panel.call_deferred()

func open() -> void:
	if overlay.visible or GameState.flags.get("lumber_puzzle_completed", false): return
	if GameState.get_lumber_attempts_left() <= 0:
		GameState.show_lumber_encouragement()
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	player_was_enabled = bool(player.get("controls_enabled")) if player else true
	model = State.new()
	model.initialize(GameState.is_easy_difficulty(), randi_range(1, 2147483646))
	model.restore(GameState.flags.get("lumber_progress", {}))
	model.changed.connect(_on_changed)
	model.mistake.connect(_register_mistake)
	model.worked.connect(_on_worked)
	model.finished.connect(_complete_lumber_puzzle)
	awaiting_retry = false
	action_locked = false
	application_focused = true
	retry_notice.hide()
	overlay.show()
	workbench.active = true
	workbench.bind(model)
	shown_stage = -1
	_refresh()
	_fit_panel()
	_set_player_controls(false)
	restore_notice()
	if stage == STAGE_COMPLETE: _complete_lumber_puzzle()
	else: _save_work()
	if not awaiting_retry: workbench.grab_focus()

func close() -> void:
	if not overlay.visible: return
	_save_work()
	workbench.cancel_gesture()
	workbench.active = false
	model.paused = true
	workbench.refresh()
	retry_notice.hide()
	awaiting_retry = false
	action_locked = false
	tool_audio.stop()
	action_audio.stop()
	overlay.hide()
	_set_player_controls(player_was_enabled)

func _confirm() -> void:
	if not overlay.visible or awaiting_retry: return
	if stage == STAGE_COMPLETE: close()
	else:
		model.confirm()
		_refresh()
		_save_work()

func _physics_process(delta: float) -> void:
	step_workshop(delta)

func step_workshop(delta: float) -> void:
	if not overlay.visible or awaiting_retry or not application_focused or not model: return
	model.tick(delta)
	workbench.physics_step(delta)
	status_label.text = model.message if not model.message.is_empty() else _tool_help()
	if not model.tool_active and tool_audio.playing: tool_audio.stop()
	save_age += delta
	if save_age >= autosave_interval:
		save_age = 0
		_save_work()

func _input(event: InputEvent) -> void:
	if not overlay.visible: return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if workbench.release_from_viewport(event.position, -1): get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		if workbench.release_from_viewport(event.position, event.index): get_viewport().set_input_as_handled()
	if not event is InputEventKey: return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if awaiting_retry:
		if key == KEY_SPACE:
			if event.pressed and not event.echo: _continue_current_phase()
			get_viewport().set_input_as_handled()
		elif key not in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER]: get_viewport().set_input_as_handled()
		return
	if key == KEY_ENTER and event.pressed and get_viewport().gui_get_focus_owner() == workbench:
		_confirm()
		get_viewport().set_input_as_handled()
	elif workbench.handle_key(event): get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what not in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN]: return
	if not is_node_ready() or not is_instance_valid(overlay) or not overlay.visible: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_focused = false
		workbench.cancel_gesture()
		model.paused = true
		workbench.refresh()
		tool_audio.stop()
		_save_work()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_focused = true
		model.paused = awaiting_retry
		workbench.refresh()

func _register_mistake(reason: String = "") -> void:
	if not overlay.visible or awaiting_retry or GameState.get_lumber_attempts_left() <= 0: return
	model.paused = true
	workbench.cancel_gesture()
	tool_audio.stop()
	GameState.fail_lumber_attempt()
	awaiting_retry = true
	action_locked = true
	workbench.active = false
	_save_work()
	_refresh()
	if GameState.get_lumber_attempts_left() <= 0:
		close()
		GameState.show_lumber_encouragement()
	else: retry_notice.show_error(reason if not reason.is_empty() else model.message, GameState.get_lumber_attempts_left(), GameState.get_lumber_opportunities())

func _continue_current_phase() -> void:
	if not awaiting_retry or not overlay.visible: return
	awaiting_retry = false
	action_locked = false
	model.resume()
	model.message = ""
	workbench.cancel_gesture()
	workbench.active = true
	retry_notice.hide()
	_refresh()
	_save_work()
	workbench.grab_focus()

func _on_changed() -> void:
	_refresh()
	# Commit validated work immediately; continuous adjustments use periodic/gesture saves.
	if saved_signature != _work_signature(): _save_work()

func _work_signature() -> String:
	return "%d/%d/%s/%s/%d/%d/%d" % [stage, model.marked_lines, str(model.wedge_hits), str(model.wedge_inserted), model.cuts, model.passes, model.verified_loads]

func _on_worked(action: String, point: Vector2) -> void:
	workbench.emit_work(action, point)
	if action in ["insert", "hammer", "cut", "sack", "load"]:
		action_audio.play()
		if action == "cut": GameState.register_lumber_action("saw_success")
		if action == "load": GameState.register_lumber_action("load_sack")
	elif action == "plane_pass": GameState.register_lumber_action("plane_pass")
	elif action == "mark": GameState.register_lumber_action("measurement_mark")
	elif action in ["plane", "saw", "scribe"] and not tool_audio.playing: tool_audio.play()

func _complete_lumber_puzzle() -> void:
	if not model or stage != STAGE_COMPLETE or model.verified_loads != 3: return
	GameState.complete_lumber_puzzle()
	_refresh()
	confirm_button.grab_focus()

func _save_work() -> void:
	if restoring_work or not model or not overlay.visible or GameState.flags.get("lumber_puzzle_completed", false): return
	var saved := model.snapshot()
	saved_signature = _work_signature()
	if awaiting_retry and GameState.get_lumber_attempts_left() > 0: saved["retry_reason"] = model.message
	GameState.flags["lumber_progress"] = saved
	GameState.save_progress()

func _sync_workbench() -> void:
	_refresh()

func restore_notice() -> void:
	var saved: Dictionary = GameState.flags.get("lumber_progress", {})
	if saved.has("retry_reason"):
		awaiting_retry = true
		action_locked = true
		model.paused = true
		model.message = str(saved.retry_reason)
		workbench.active = false
		retry_notice.show_error(model.message, GameState.get_lumber_attempts_left(), GameState.get_lumber_opportunities())
		workbench.refresh()

func _refresh() -> void:
	if not model: return
	opportunities_label.text = "%s  ·  Oportunidades %d / %d" % ["Fácil" if model.easy else "Difícil", GameState.get_lumber_attempts_left(), GameState.get_lumber_opportunities()]
	stage_label.text = "%d. %s" % [mini(stage + 1, 6), TITLES[stage]]
	instruction_label.text = GUIDES[stage]
	wood_hint.text = LESSONS[stage]
	progress_label.text = "OFICIO MANUAL\nCARPINTERÍA DE BRUNO"
	confirm_button.visible = stage in [STAGE_INSPECT, STAGE_SECURE, STAGE_TEST, STAGE_COMPLETE]
	confirm_button.text = {0: "Confirmar selección", 2: "Probar rigidez", 5: "Colocar saco", 6: "Llevar al molino"}.get(stage, "Continuar")
	confirm_button.disabled = awaiting_retry or (stage == STAGE_TEST and model.load_active)
	if shown_stage != stage:
		shown_stage = stage
		for child in tool_row.get_children():
			tool_row.remove_child(child)
			child.queue_free()
		for definition in TOOLS[stage]:
			var button := Button.new()
			button.text = str(definition[1])
			button.set_meta("tool", str(definition[0]))
			button.custom_minimum_size = Vector2(110, 39)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_button(button)
			tool_row.add_child(button)
			button.pressed.connect(workbench.set_tool.bind(str(definition[0])))
	_refresh_tools()
	workbench.refresh()

func _refresh_tools() -> void:
	for child in tool_row.get_children():
		var button := child as Button
		button.modulate = Color("ffe0a0") if button.get_meta("tool") == model.selected_tool else Color("a89b83")
	status_label.text = _tool_help()

func _tool_help() -> String:
	match model.selected_tool:
		"template": return "Arrastra la plantilla · ← → mover · Enter confirmar"
		"lens": return "Arrastra la lupa · WASD / flechas para examinar"
		"rule": return "Arrastra el tope de latón · ← → ajustar a 160 cm"
		"square": return "Gira el brazo de la escuadra · ← → ajustar a 90°"
		"scribe": return "Arrastra desde el punto de latón hacia abajo · mantén Espacio"
		"vice": return "Gira la manivela en sentido horario · ← → presión"
		"saw": return "Arrastra en el sentido indicado · Espacio + ← → · suelta entre pasadas"
		"depth": return "Gira la rueda a verde · ← → profundidad de la cuchilla"
		"plane": return "Arrastra hacia la derecha · mantén Espacio · suelta para volver"
		"sack": return "Arrastra el saco al centro · Espacio para colocar"
		"lever": return "Arrastra la empuñadura · ← → compensar · Tab para cambiar herramienta"
		"done": return "La tabla está lista. Instálala en la bancada del molino."
	if model.selected_tool.begins_with("wedge") and not model.wedge_inserted[int(model.selected_tool.right(1))]:
		return "Arrastra la cuña a su ranura · Espacio para encajar"
	return "Arrastra el mazo hacia abajo sobre la cuña · pulsa Espacio tres veces"

func _style_button(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4c3423")
	style.border_color = Color("b48a4c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("795332")
	hover.border_color = Color("edcb87")
	button.add_theme_stylebox_override("normal", style)
	for mode in ["hover", "pressed", "focus"]: button.add_theme_stylebox_override(mode, hover)
	button.add_theme_color_override("font_color", Color("f2e4c4"))
	button.add_theme_font_size_override("font_size", 14)

func _fit_panel() -> void:
	if not is_node_ready(): return
	panel.size = Vector2(1100, 620)
	panel.position = (overlay.size - panel.size) * 0.5
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * minf(1.0, minf((overlay.size.x - 20) / 1100, (overlay.size.y - 20) / 620))

func _set_player_controls(enabled: bool) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player: player.set("controls_enabled", enabled)

func _wood_sound(continuous: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := 4410 if continuous else 3307
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 440
	for index in samples:
		var t := index / 22050.0
		var envelope := 0.3 if continuous else exp(-index / float(samples) * 7)
		var wave := sin(t * TAU * 135) * 0.35 + random.randf_range(-0.4, 0.4)
		bytes.encode_s16(index * 2, int(wave * envelope * 17000))
	stream.data = bytes
	if continuous:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples
	return stream
