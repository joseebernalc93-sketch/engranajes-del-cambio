extends CanvasLayer
## Silas's modal owns opportunities; the model and renderer pause together on review.
const State = preload("res://scripts/ui/rope_work_state.gd")
const RetryNotice = preload("res://scripts/ui/workshop_retry_notice.gd")
const STAGE_PREPARE := State.Stage.CARD
const STAGE_COMB := State.Stage.CARD
const STAGE_STRANDS := State.Stage.MOUNT
const STAGE_TWIST := State.Stage.TWIST
const STAGE_TENSION := State.Stage.TENSION
const STAGE_FINISH := State.Stage.BIND
const STAGE_PROOF := State.Stage.PROOF
const STAGE_COMPLETE := State.Stage.COMPLETE
const TITLES := ["Peinar y alinear el cáñamo", "Repartir y montar los cabos", "Torcer y acompañar el carro", "Compactar bajo tensión", "Cerrar la ligadura encerada", "Ensayar la carga", "Soga terminada"]
const GUIDES := [
	"Toma el rastrillo y peina cada manojo de izquierda a derecha. Completa dos pasadas suaves por manojo.",
	"Reparte la fibra con los calibres hasta igualar las tres porciones. Arrastra cada cabo a su gancho de latón.",
	"Gira la rueda en sentido horario. Acerca el carro siguiendo su marca: al torcerse, los cabos se acortan.",
	"Acciona la rueda y modula el freno. Conserva la tensión en la zona verde durante 3 segundos seguidos.",
	"Rodea el extremo tres veces en sentido horario. Suelta después de cada vuelta y tira del hilo para cerrar.",
	"Engancha cada saco en la polea y ajusta el freno. Mantén la aguja en verde durante 1,2 segundos por carga.",
	"Silas aprueba la soga de transmisión resistente. Llévala al molino e instálala en las poleas."]
const LESSONS := [
	"El rastrillo separa las fibras largas de la estopa. Peinar sin tirones conserva la resistencia del cáñamo.",
	"Tres cabos de grosor parejo comparten el esfuerzo. Compara cada mordaza con su marca verde antes de enganchar.",
	"La torsión acorta las fibras. El carro debe acompañarla: muy lejos rompe la cuerda; muy cerca la deja floja.",
	"La tensión compacta el cáñamo. El cordelero coordinaba a mano el giro, el freno y la cadencia del trabajo.",
	"La cera da agarre al hilo. Tres vueltas cerradas y un tirón firme evitan que la soga se abra al soltarla.",
	"El resorte revela el esfuerzo sobre las fibras. Usa el freno para amortiguar cada carga y evitar tirones.",
	"Seis operaciones artesanales transforman el cáñamo en una soga capaz de transmitir movimiento al molino."]
const TOOLS := [
	[["card0", "Manojo 1"], ["card1", "Manojo 2"], ["card2", "Manojo 3"]],
	[["portion0", "Calibre 1"], ["portion1", "Calibre 2"], ["portion2", "Calibre 3"]],
	[["crank", "Manivela"], ["carriage", "Carro móvil"]],
	[["crank", "Manivela"], ["brake", "Freno del carro"]],
	[["thread", "Hilo encerado"], ["pull", "Cerrar lazo"]],
	[["sack", "Saco de prueba"], ["lever", "Freno de carga"]], []]
@export var autosave_interval: float = 1.0
@onready var overlay: ColorRect = %RopeOverlay
@onready var panel: Panel = %Panel
@onready var workbench: RopewalkDisplay = %WorkbenchDisplay
@onready var stage_label: Label = %StageLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var opportunities_label: Label = %OpportunitiesLabel
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel
@onready var history_hint: Label = %HistoryHint
@onready var tool_row: HBoxContainer = %ToolRow
@onready var confirm_button: Button = %ConfirmButton
@onready var close_button: Button = %CloseButton
@onready var action_audio: AudioStreamPlayer = %ActionAudio
@onready var tool_audio: AudioStreamPlayer = %ToolAudio
var model: RopeWorkState
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
	retry_notice.artisan = "Silas"
	retry_notice.continued.connect(_continue_current_phase)
	EventBus.rope_puzzle_requested.connect(open)
	close_button.pressed.connect(close)
	confirm_button.pressed.connect(_confirm)
	workbench.tool_selected.connect(func(_tool: String): _refresh_tools())
	workbench.gesture_finished.connect(_save_work)
	get_viewport().size_changed.connect(_fit_panel)
	action_audio.stream = _work_sound(false)
	tool_audio.stream = _work_sound(true)
	_style_button(confirm_button)
	_style_button(close_button)
	_fit_panel.call_deferred()

func _exit_tree() -> void:
	# Release voices when a travelling player replaces the entire workshop scene.
	for player in [action_audio, tool_audio]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func open() -> void:
	if overlay.visible or GameState.flags.get("rope_puzzle_completed", false): return
	if GameState.get_rope_attempts_left() <= 0:
		GameState.show_rope_encouragement()
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	player_was_enabled = bool(player.get("controls_enabled")) if player else true
	model = State.new()
	model.initialize(GameState.is_easy_difficulty())
	model.restore(GameState.flags.get("rope_progress", {}))
	model.changed.connect(_on_changed)
	model.mistake.connect(_register_mistake)
	model.worked.connect(_on_worked)
	model.finished.connect(_complete_rope_puzzle)
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
	if stage == STAGE_COMPLETE: _complete_rope_puzzle()
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
		_confirm_stage()
		_refresh()
		_save_work()

func _physics_process(delta: float) -> void:
	step_workshop(delta)

func step_workshop(delta: float) -> void:
	if not overlay.visible or awaiting_retry or not application_focused or not model: return
	workbench.physics_step(delta)
	model.tick(delta)
	# A synchronous mistake signal may have opened the review during this tick.
	if awaiting_retry or not overlay.visible: return
	workbench.refresh()
	if stage in [STAGE_TWIST, STAGE_TENSION] and (model.cranking or model.wheel_velocity > 0.08) and not tool_audio.playing: tool_audio.play()
	status_label.text = _tool_help()
	if not model.tool_active and not model.cranking and model.wheel_velocity <= 0 and tool_audio.playing: tool_audio.stop()
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
		if key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
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
	if not overlay.visible or awaiting_retry or GameState.get_rope_attempts_left() <= 0: return
	model.paused = true
	workbench.cancel_gesture()
	tool_audio.stop()
	GameState.fail_rope_attempt()
	awaiting_retry = true
	action_locked = true
	workbench.active = false
	_save_work()
	_refresh()
	if GameState.get_rope_attempts_left() <= 0:
		close()
		GameState.show_rope_encouragement()
	else: retry_notice.show_error(reason if not reason.is_empty() else model.message, GameState.get_rope_attempts_left(), GameState.get_rope_opportunities())

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
	if model.stage == STAGE_TENSION:
		# Commit the five validated turns once, also when restoring an older checkpoint.
		var already := int(GameState.flags.get("rope_recorded_turns", 0))
		for _index in maxi(0, 5 - already): GameState.register_rope_action("rope_twist")
		GameState.flags["rope_recorded_turns"] = 5
	_refresh()
	# Commit validated work immediately; continuous adjustments use periodic/gesture saves.
	if saved_signature != _work_signature(): _save_work()

func _work_signature() -> String:
	return str([stage, model.comb_passes, model.mounted, model.binding_wraps, model.binding_locked, model.proof_checks])

func _on_worked(action: String, point: Vector2) -> void:
	workbench.emit_work(action, point)
	if action in ["card_pass", "mount", "wrap", "lock", "sack", "load"]: action_audio.play()
	if action == "card_pass" and model.comb_passes[model.selected_bundle] == 2: GameState.register_rope_action("fiber_cleaned")
	elif action == "mount": GameState.register_rope_action("braid_step")
	elif action == "card" and not tool_audio.playing: tool_audio.play()

func _complete_rope_puzzle() -> void:
	if not model or stage != STAGE_COMPLETE or model.proof_checks != 3: return
	GameState.complete_rope_puzzle()
	_refresh()
	confirm_button.grab_focus()

func _save_work() -> void:
	if restoring_work or not model or not overlay.visible or GameState.flags.get("rope_puzzle_completed", false): return
	var saved := model.snapshot()
	saved_signature = _work_signature()
	if awaiting_retry and GameState.get_rope_attempts_left() > 0: saved["retry_reason"] = model.message
	GameState.flags["rope_progress"] = saved
	GameState.save_progress()

func _sync_workbench() -> void:
	_refresh()

func restore_notice() -> void:
	var saved: Dictionary = GameState.flags.get("rope_progress", {})
	if saved.has("retry_reason"):
		awaiting_retry = true
		action_locked = true
		model.paused = true
		model.message = str(saved.retry_reason)
		workbench.active = false
		retry_notice.show_error(model.message, GameState.get_rope_attempts_left(), GameState.get_rope_opportunities())
		_refresh()

func _refresh() -> void:
	if not model: return
	opportunities_label.text = "%s · Oportunidades %d / %d" % ["Fácil" if model.easy else "Difícil", GameState.get_rope_attempts_left(), GameState.get_rope_opportunities()]
	stage_label.text = "%d. %s" % [mini(stage + 1, 6), TITLES[stage]]
	instruction_label.text = GUIDES[stage]
	history_hint.text = LESSONS[stage]
	progress_label.text = "OFICIO MANUAL\nCORDELERÍA DE SILAS"
	confirm_button.visible = stage in [STAGE_STRANDS, STAGE_FINISH, STAGE_PROOF, STAGE_COMPLETE]
	confirm_button.text = {1: "Enganchar este cabo", 4: "Trabar la ligadura", 5: "Izar saco", 6: "Llevar al molino"}.get(stage, "Continuar")
	confirm_button.disabled = awaiting_retry or (stage == STAGE_PROOF and model.load_active) or (stage == STAGE_FINISH and model.binding_wraps < 3)
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

func _confirm_stage() -> void:
	match stage:
		STAGE_STRANDS: model.mount(model.selected_bundle)
		STAGE_FINISH: model.pull_binding(100)
		STAGE_PROOF:
			model.place_sack()
			if model.load_active: workbench.set_tool("lever")

func _tool_help() -> String:
	if model.selected_tool.begins_with("card"): return "Arrastra el rastrillo de izquierda a derecha · mantén Espacio · suelta entre pasadas"
	if model.selected_tool.begins_with("portion"): return "Arrastra la mordaza del calibre · ← → repartir fibra · Espacio enganchar"
	match model.selected_tool:
		"crank": return "Gira la rueda en sentido horario · Espacio rueda + ← → carro / freno"
		"carriage": return "Arrastra el carro hacia la marca verde · Espacio rueda + ← → carro"
		"brake": return "Arrastra la manivela del freno · ← → regular · mantén Espacio para girar"
		"thread": return "Traza un círculo horario por vuelta · mantén Espacio · suelta al cerrar cada vuelta"
		"pull": return "Con tres vueltas listas, arrastra el hilo hacia abajo hasta la marca · Espacio cerrar"
		"sack": return "Arrastra el saco a la polea · Espacio izar · después ajusta el freno"
		"lever": return "← → o arrastra el freno · derecha baja la aguja; izquierda la sube · verde durante 1,2 s"
	return "La soga está lista para instalar en las poleas del molino."

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

func _work_sound(continuous: bool) -> AudioStreamWAV:
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
