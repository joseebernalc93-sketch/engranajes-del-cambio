extends CanvasLayer

const STAGE_INSPECT := 0
const STAGE_MEASURE := 1
const STAGE_SECURE := 2
const STAGE_SAW := 3
const STAGE_PLANE := 4
const STAGE_TEST := 5
const STAGE_COMPLETE := 6

const REQUIRED_SETUP_PARTS := 3
const REQUIRED_CUTS := 5
const REQUIRED_PLANING_PASSES := 4
const REQUIRED_LOAD_SACKS := 3
const SAFE_DEVIATION := 0.52
const SAW_VISUAL_LEFT := 466.0
const SAW_VISUAL_RIGHT := 636.0
const SAW_START_Y := 101.0
const SAW_DEPTH_PER_STROKE := 10.0
const CUT_GROOVE_START_Y := 109.0
const PLANE_VISUAL_LEFT := 96.0
const PLANE_VISUAL_RIGHT := 520.0
const PLANE_BASE_Y := 94.0
const SACK_REST_Y := 91.0
const LOG_WORKSHOP := preload("res://assets/gba/ui/bruno_workshop_backdrop_v2.png")
const BOARD_WORKSHOP := preload("res://assets/gba/ui/bruno_workshop_backdrop_v2.png")
const RETRY_NOTICE := preload("res://scripts/ui/workshop_retry_notice.gd")

@onready var overlay: ColorRect = %LumberOverlay
@onready var close_button: Button = %CloseButton
@onready var stage_label: Label = %StageLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel
@onready var wood_hint: Label = %WoodHint

@onready var workbench = %WorkbenchDisplay
@onready var continue_button: Button = %ContinueButton
@onready var panel: PanelContainer = $LumberOverlay/Panel
@onready var workshop_texture: TextureRect = %WorkshopTexture
@onready var workshop_shade: ColorRect = %WorkshopShade
@onready var saw_sprite: Sprite2D = %SawSprite
@onready var plane_sprite: Sprite2D = %PlaneSprite
@onready var cut_groove: ColorRect = %CutGroove

@onready var inspect_container: GridContainer = %InspectContainer
@onready var straight_grain: Button = %StraightGrain
@onready var radial_crack: Button = %RadialCrack
@onready var large_knot: Button = %LargeKnot
@onready var wet_section: Button = %WetSection

@onready var secure_container: HBoxContainer = %SecureContainer
@onready var left_support: Button = %LeftSupport
@onready var center_wedge: Button = %CenterWedge
@onready var right_clamp: Button = %RightClamp
@onready var stability_test: Button = %StabilityTest

@onready var saw_container: Control = %SawContainer
@onready var saw_drag_area: Control = %SawDragArea
@onready var stroke_marker: ColorRect = %StrokeMarker
@onready var planing_container: Control = %PlaningContainer
@onready var plane_drag_area: Control = %PlaneDragArea
@onready var plane_marker: ColorRect = %PlaneMarker
@onready var planed_strips: Array[ColorRect] = [%PlanedStrip1, %PlanedStrip2, %PlanedStrip3, %PlanedStrip4]

@onready var load_container: HBoxContainer = %LoadContainer
@onready var sack_one: Button = %SackOne
@onready var sack_two: Button = %SackTwo
@onready var sack_three: Button = %SackThree
@onready var sack_visual_1: Sprite2D = %SackVisual1
@onready var sack_visual_2: Sprite2D = %SackVisual2
@onready var sack_visual_3: Sprite2D = %SackVisual3
@onready var sack_shadows: Array[Polygon2D] = [%SackShadow1, %SackShadow2, %SackShadow3]

@onready var quality_title: Label = %QualityTitle
@onready var quality_bar: ProgressBar = %QualityBar
@onready var quality_value: Label = %QualityValue

@onready var step_inspect: Label = %StepInspect
@onready var step_secure: Label = %StepSecure
@onready var step_saw: Label = %StepSaw
@onready var step_plane: Label = %StepPlane
@onready var step_test: Label = %StepTest

@onready var sawdust: CPUParticles2D = %Sawdust
@onready var shavings: CPUParticles2D = %Shavings
@onready var action_audio: AudioStreamPlayer = %ActionAudio
@onready var tool_audio: AudioStreamPlayer = %ToolAudio

@onready var opportunities_label: Label = %OpportunitiesLabel
@onready var measure_container: Control = %MeasureContainer
@onready var length_slider: HSlider = %LengthSlider
@onready var angle_slider: HSlider = %AngleSlider
@onready var mark_button: Button = %MarkButton
@onready var marking_meter = %MarkingMeter
@onready var clamp_controls: Control = %ClampControls
@onready var clamp_slider: HSlider = %ClampSlider
@onready var depth_controls: Control = %DepthControls
@onready var depth_slider: HSlider = %DepthSlider
@onready var plane_hold_button: Button = %PlaneHoldButton
@onready var brace_controls: Control = %BraceControls
@onready var brace_slider: HSlider = %BraceSlider
@onready var load_meter = %LoadMeter
var marked_lines := 0
var secured_verified := false
var work_clock := 0.0
var load_seconds := 0.0
var load_danger := 0.0
var load_drop_age := 0.0
var restoring_work := false
var awaiting_retry := false
var retry_notice: Control
var session_id := 0
var player_was_enabled := true
var verified_loads := 0
var animations: Array[Tween] = []
var left_held := false
var right_held := false
var space_held := false
var keyboard_tool := false
var plane_key_armed := false
var motion_age := 1.0
var dust_cooldown := 0.0

var stage := STAGE_INSPECT
var setup_parts := 0
var saw_successes := 0
var planing_passes := 0
var load_sacks := 0
var action_locked := false

var dragging_saw := false
var saw_expected_edge := 1
var saw_deviation_total := 0.0
var saw_deviation_samples := 0
var saw_drag_offset_x := 0.0
var saw_drag_anchor_y := 0.0

var dragging_plane := false
var plane_started_left := false
var plane_wrong_direction := false
var plane_last_x := 0.0
var plane_pressure_total := 0.0
var plane_pressure_samples := 0
var plane_drag_offset_x := 0.0
var plane_drag_anchor_y := 0.0


func _ready() -> void:
	retry_notice = RETRY_NOTICE.new()
	panel.get_node("Content").add_child(retry_notice)
	retry_notice.artisan = "Bruno"
	retry_notice.continued.connect(_continue_current_phase)
	EventBus.lumber_puzzle_requested.connect(open)
	close_button.pressed.connect(close)
	continue_button.pressed.connect(close)
	workbench.section_selected.connect(func(index: int):
		[straight_grain, radial_crack, large_knot, wet_section][index].pressed.emit())
	workbench.fixation_selected.connect(func(index: int):
		[left_support, center_wedge, right_clamp][index].pressed.emit())
	workbench.sack_requested.connect(func(index: int):
		_on_sack_pressed([sack_one, sack_two, sack_three][index], index + 1))
	get_viewport().size_changed.connect(_fit_panel)

	straight_grain.pressed.connect(_on_wood_section_pressed.bind(straight_grain, true, "La veta recta repartirá la carga a lo largo de toda la tabla."))
	radial_crack.pressed.connect(_on_wood_section_pressed.bind(radial_crack, false, "La grieta crecería con la vibración continua del molino."))
	large_knot.pressed.connect(_on_wood_section_pressed.bind(large_knot, false, "Un nudo grande desvía la veta y concentra el esfuerzo en un solo punto."))
	wet_section.pressed.connect(_on_wood_section_pressed.bind(wet_section, false, "La madera húmeda cambia de forma al secarse y aflojaría la estructura."))

	left_support.pressed.connect(_on_setup_part_pressed.bind(left_support, "Apoyo izquierdo colocado"))
	center_wedge.pressed.connect(_on_setup_part_pressed.bind(center_wedge, "La cuña impide que el tronco ruede"))
	right_clamp.pressed.connect(_on_setup_part_pressed.bind(right_clamp, "La abrazadera inmoviliza el extremo"))
	stability_test.pressed.connect(_on_stability_test)

	saw_drag_area.gui_input.connect(_on_saw_drag_input)
	plane_drag_area.gui_input.connect(_on_plane_drag_input)
	sack_one.pressed.connect(_on_sack_pressed.bind(sack_one, 1))
	sack_two.pressed.connect(_on_sack_pressed.bind(sack_two, 2))
	sack_three.pressed.connect(_on_sack_pressed.bind(sack_three, 3))

	workbench.mark_requested.connect(_on_mark_requested)
	mark_button.pressed.connect(func(): _on_mark_requested(marked_lines))
	plane_hold_button.button_down.connect(_hold_plane)
	plane_hold_button.button_up.connect(_release_plane)
	for slider in [length_slider, angle_slider, clamp_slider, depth_slider, brace_slider]:
		slider.value_changed.connect(func(_value: float):
			_update_adjustments()
			_save_work())
	_style_controls()
	_configure_particles()
	_configure_audio()
	_reset_minigame()
	_fit_panel.call_deferred()


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if awaiting_retry:
		if event is InputEventKey:
			var retry_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if retry_key == KEY_SPACE:
				if event.pressed and not event.echo:
					_continue_current_phase()
				get_viewport().set_input_as_handled()
			elif retry_key != KEY_TAB and retry_key != KEY_ENTER and retry_key != KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
		return
	if ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
		or (event is InputEventScreenTouch and not event.pressed)) and not keyboard_tool:
		_finish_saw_stroke()
		_finish_plane_pass()
		_release_plane()
	if event.is_action_pressed("inventory") and not (event is InputEventKey and event.keycode == KEY_TAB):
		get_viewport().set_input_as_handled()
	if event is InputEventKey and stage == STAGE_MEASURE and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		if event.pressed and not event.echo:
			_on_mark_requested(marked_lines)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and stage in [STAGE_SAW, STAGE_PLANE]:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_SPACE or (stage == STAGE_SAW and key in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]):
			if not event.echo:
				match key:
					KEY_LEFT, KEY_A: left_held = event.pressed
					KEY_RIGHT, KEY_D: right_held = event.pressed
					KEY_SPACE:
						space_held = event.pressed
						plane_key_armed = event.pressed
				if not event.pressed and keyboard_tool:
					_finish_saw_stroke()
					_finish_plane_pass()
					keyboard_tool = false
			get_viewport().set_input_as_handled()


func open() -> void:
	if overlay.visible or GameState.flags.get("lumber_puzzle_completed", false):
		return
	if GameState.get_lumber_attempts_left() <= 0:
		GameState.show_lumber_encouragement()
		return
	var player = get_tree().get_first_node_in_group("player")
	player_was_enabled = player.controls_enabled if player else true
	_reset_minigame()
	overlay.visible = true
	workbench.active = true
	_restore_work()
	_refresh_opportunities()
	_update_adjustments()
	_fit_panel()
	_set_player_controls(false)
	if stage == STAGE_INSPECT:
		straight_grain.grab_focus()


func close() -> void:
	if not overlay.visible:
		return
	_save_work()
	session_id += 1
	_cancel_tools()
	awaiting_retry = false
	retry_notice.hide()
	_stop_animations()
	workbench.active = false
	sawdust.emitting = false
	shavings.emitting = false
	action_audio.stop()
	overlay.visible = false
	_set_player_controls(player_was_enabled)


func _reset_minigame() -> void:
	awaiting_retry = false
	retry_notice.hide()
	session_id += 1
	_cancel_tools()
	_stop_animations()
	workbench.reset_workbench()
	workbench.session_id = session_id
	verified_loads = 0
	marked_lines = 0
	secured_verified = false
	work_clock = 0.0
	load_seconds = 0.0
	load_danger = 0.0
	load_drop_age = 0.0
	measure_container.hide()
	marking_meter.hide()
	clamp_controls.hide()
	depth_controls.hide()
	brace_controls.hide()
	load_meter.hide()
	quality_bar.show()
	quality_value.position.y = 397
	length_slider.set_value_no_signal(120)
	angle_slider.set_value_no_signal(82)
	clamp_slider.set_value_no_signal(30)
	depth_slider.set_value_no_signal(25)
	brace_slider.set_value_no_signal(30)
	mark_button.text = "Marcar · ESPACIO"
	continue_button.visible = false
	status_label.modulate = Color.WHITE
	for index in 3:
		var sack_button = [sack_one, sack_two, sack_three][index]
		sack_button.sack_index = index
		sack_button.session_id = session_id
	stage = STAGE_INSPECT
	setup_parts = 0
	saw_successes = 0
	planing_passes = 0
	load_sacks = 0
	action_locked = false
	dragging_saw = false
	saw_expected_edge = 1
	saw_deviation_total = 0.0
	saw_deviation_samples = 0
	saw_drag_offset_x = 0.0
	dragging_plane = false
	plane_started_left = false
	plane_wrong_direction = false
	plane_last_x = 0.0
	plane_pressure_total = 0.0
	plane_pressure_samples = 0
	plane_drag_offset_x = 0.0

	stage_label.text = "1. Inspeccionar la madera y elegir la veta"
	instruction_label.text = "Escoge la sección que soportará el esfuerzo continuo del molino sin desperdiciar el tronco."
	progress_label.text = "Busca una sección aprovechable"
	status_label.text = "Explora las marcas sobre el tronco"
	wood_hint.text = "La veta recta distribuye mejor las cargas y permite aprovechar más madera."
	quality_title.text = "APROVECHAMIENTO"
	quality_bar.value = 0.0
	quality_value.text = "Sin marcar"
	quality_value.modulate = Color.WHITE
	close_button.text = "X"

	inspect_container.visible = true
	secure_container.visible = false
	saw_container.visible = false
	planing_container.visible = false
	load_container.visible = false
	saw_sprite.visible = false
	plane_sprite.visible = false
	workshop_texture.position = Vector2(2, 2)
	workshop_texture.scale = Vector2.ONE
	workshop_texture.texture = LOG_WORKSHOP
	workshop_texture.modulate = Color.WHITE
	workshop_shade.color = Color(0.03, 0.02, 0.01, 0.06)

	straight_grain.text = "Veta recta y seca"
	radial_crack.text = "Grieta radial"
	large_knot.text = "Nudo grande en el centro"
	wet_section.text = "Sección húmeda"
	left_support.text = "Apoyo izquierdo"
	center_wedge.text = "Cuña central"
	right_clamp.text = "Abrazadera"
	stability_test.text = "Probar estabilidad"
	sack_one.text = "Colocar saco 1"
	sack_two.text = "Colocar saco 2"
	sack_three.text = "Colocar saco 3"

	for button in _all_buttons():
		button.disabled = false
		button.modulate = Color.WHITE
	stability_test.disabled = false
	sack_two.disabled = true
	sack_three.disabled = true
	stroke_marker.position = Vector2.ZERO
	plane_marker.position = Vector2.ZERO
	saw_sprite.position = Vector2(SAW_VISUAL_LEFT, SAW_START_Y)
	plane_sprite.position = Vector2(PLANE_VISUAL_LEFT, PLANE_BASE_Y)
	cut_groove.visible = false
	cut_groove.position.y = CUT_GROOVE_START_Y
	cut_groove.size.y = 0.0
	for strip in planed_strips:
		strip.visible = false
		strip.size.x = 0.0
		strip.self_modulate.a = 0.0
	for sack_visual in [sack_visual_1, sack_visual_2, sack_visual_3]:
		sack_visual.visible = false
		sack_visual.position.y = SACK_REST_Y
		sack_visual.scale = Vector2.ONE * 0.045
	for shadow in sack_shadows:
		shadow.visible = false
		shadow.scale = Vector2.ONE
	_set_step_rail()


func _on_wood_section_pressed(button: Button, correct: bool, explanation: String) -> void:
	if stage != STAGE_INSPECT or action_locked or button.disabled:
		return
	button.disabled = true
	var section_index := [straight_grain, radial_crack, large_knot, wet_section].find(button)
	workbench.inspected[section_index] = true
	workbench.show_feedback("Veta recta: tramo marcado" if correct else "Defecto detectado: descarta esta zona", Color("bfdc95") if correct else Color("e69b58"))
	if not correct:
		button.disabled = false
		button.modulate = Color("d98262")
		status_label.text = explanation
		GameState.register_lumber_action("wood_defect")
		_pulse_status(Color("e69b58"))
		_register_mistake()
		return

	workbench.selected = true
	button.text = "✓ Veta recta marcada con tiza"
	button.modulate = Color("b9e58d")
	status_label.text = explanation
	progress_label.text = "Sección estructural seleccionada"
	quality_bar.value = 92.0
	quality_value.text = "92% del tramo aprovechable"
	action_locked = true
	_emit_wood_particles(false, Vector2(380, 225))
	action_audio.play()
	_save_work()
	_schedule_transition(0.7, _start_measure_stage)


func _start_secure_stage() -> void:
	if stage != STAGE_MEASURE:
		return
	stage = STAGE_SECURE
	action_locked = false
	stage_label.text = "3. Asegurar el tronco antes de cortar"
	instruction_label.text = "Coloca las tres fijaciones y regula la presión de la abrazadera en verde. Comprueba que el tronco no pueda rodar."
	progress_label.text = "0 de %d fijaciones colocadas" % REQUIRED_SETUP_PARTS
	status_label.text = "Empieza por cualquiera de los tres puntos"
	wood_hint.text = "Una pieza suelta desvía la sierra y puede herir al carpintero o desperdiciar la madera."
	quality_title.text = "ESTABILIDAD"
	quality_bar.value = 0.0
	quality_value.text = "Pieza sin asegurar"
	inspect_container.visible = false
	secure_container.visible = true
	measure_container.hide()
	marking_meter.hide()
	clamp_controls.show()
	workshop_texture.modulate = Color.WHITE
	workshop_shade.color = Color(0.02, 0.015, 0.01, 0.08)
	_set_step_rail()
	left_support.grab_focus()
	_update_adjustments()
	_save_work()


func _on_setup_part_pressed(button: Button, message: String) -> void:
	if stage != STAGE_SECURE or button.disabled or action_locked:
		return
	button.disabled = true
	button.text = "✓ %s" % button.text
	button.modulate = Color("b9e58d")
	workbench.fixations[[left_support, center_wedge, right_clamp].find(button)] = true
	workbench.show_feedback(message)
	setup_parts += 1
	GameState.register_lumber_action("setup_part")
	progress_label.text = "%d de %d fijaciones colocadas" % [setup_parts, REQUIRED_SETUP_PARTS]
	status_label.text = message
	quality_bar.value = (float(setup_parts) / REQUIRED_SETUP_PARTS) * 100.0
	quality_value.text = "%d / 3 fijaciones montadas" % setup_parts
	_emit_wood_particles(false, Vector2(170 + setup_parts * 145, 250))
	action_audio.pitch_scale = 0.9 + setup_parts * 0.08
	action_audio.play()
	if setup_parts >= REQUIRED_SETUP_PARTS:
		stability_test.disabled = false
		stability_test.modulate = Color("ffe2a0")
		status_label.text = "Fijaciones listas: prueba la estabilidad"
		stability_test.grab_focus()
	_save_work()


func _on_stability_test() -> void:
	if stage != STAGE_SECURE or action_locked:
		return
	if setup_parts < REQUIRED_SETUP_PARTS or absf(clamp_slider.value - 60) > _clamp_tolerance():
		status_label.text = "Coloca las tres fijaciones y lleva la presión a la franja verde."
		_register_mistake("Faltan fijaciones: coloca el apoyo izquierdo, la cuña central y la abrazadera antes de comprobar la estabilidad." if setup_parts < REQUIRED_SETUP_PARTS else "La presión de la abrazadera está fuera de la franja verde. Regúlala antes de comprobar la estabilidad.")
		return
	secured_verified = true
	_save_work()
	action_locked = true
	stability_test.disabled = true
	stability_test.text = "✓ Tronco inmóvil"
	stability_test.modulate = Color("b9e58d")
	status_label.text = "La pieza no rueda: puedes seguir la línea de tiza"
	workbench.stability_pulse = 1.0
	workbench.show_feedback("Tres fijaciones comprobadas: la pieza no rueda", Color("bfdc95"))
	_schedule_transition(0.65, _start_saw_stage)


func _start_saw_stage() -> void:
	if stage != STAGE_SECURE:
		return
	stage = STAGE_SAW
	action_locked = false
	stage_label.text = "4. Serrar siguiendo la línea marcada"
	instruction_label.text = "Arrastra el mango señalado o alterna las flechas ← → / A D. Mantén la hoja centrada en la marca de tiza."
	progress_label.text = "0 de %d recorridos precisos" % REQUIRED_CUTS
	status_label.text = "Empieza desde el mango izquierdo y tira hacia la derecha"
	wood_hint.text = "La sierra corta al alternar tracción y empuje; forzarla de lado abre una ranura torcida."
	quality_title.text = "PROFUNDIDAD DEL CORTE"
	quality_bar.value = 100.0
	quality_value.text = "Hoja apoyada en la marca"
	secure_container.visible = false
	clamp_controls.hide()
	saw_container.visible = true
	saw_sprite.visible = true
	cut_groove.visible = true
	cut_groove.position.y = CUT_GROOVE_START_Y
	cut_groove.size.y = 4.0
	saw_sprite.position = Vector2(SAW_VISUAL_LEFT, SAW_START_Y)
	_set_step_rail()
	_save_work()


func _on_saw_drag_input(event: InputEvent) -> void:
	if stage != STAGE_SAW or action_locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging_saw = true
			_begin_saw_stroke(event.position)
		else:
			_finish_saw_stroke()
	elif event is InputEventMouseMotion and dragging_saw:
		_move_saw(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			dragging_saw = true
			_begin_saw_stroke(event.position)
		else:
			_finish_saw_stroke()
	elif event is InputEventScreenDrag and dragging_saw:
		_move_saw(event.position)


func _begin_saw_stroke(local_position: Vector2) -> void:
	var pointer_work_x := saw_drag_area.position.x + local_position.x
	var active_handle_x := saw_sprite.position.x + (-94.0 if saw_expected_edge == 1 else 94.0)
	var begins_at_expected_edge := absf(pointer_work_x - active_handle_x) <= 62.0
	if not begins_at_expected_edge:
		dragging_saw = false
		status_label.text = "Agarra el mango exterior de la sierra antes de iniciar el recorrido"
		_pulse_status(Color("e69b58"))
		return
	dragging_saw = true
	saw_drag_offset_x = saw_sprite.position.x - pointer_work_x
	saw_drag_anchor_y = clampf(local_position.y, 0, saw_drag_area.size.y)
	saw_deviation_total = 0.0
	saw_deviation_samples = 0
	_move_saw(local_position)


func _move_saw(local_position: Vector2) -> void:
	var x := clampf(local_position.x, 0.0, saw_drag_area.size.x)
	var center_y := saw_drag_anchor_y
	var y := clampf(local_position.y, 0.0, saw_drag_area.size.y)
	var deviation := absf(y - center_y) / maxf(saw_drag_area.size.y * 0.5, 1.0)
	saw_deviation_total += deviation
	saw_deviation_samples += 1
	quality_bar.value = clampf((1.0 - deviation) * 100.0, 0.0, 100.0)
	quality_value.text = "%d%% de control" % int(quality_bar.value)
	var old_x := saw_sprite.position.x
	var pointer_work_x := saw_drag_area.position.x + x
	saw_sprite.position.x = clampf(pointer_work_x + saw_drag_offset_x, SAW_VISUAL_LEFT, SAW_VISUAL_RIGHT)
	var fraction := (saw_sprite.position.x - SAW_VISUAL_LEFT) / (SAW_VISUAL_RIGHT - SAW_VISUAL_LEFT)
	if saw_expected_edge == -1:
		fraction = 1.0 - fraction
	var cut_depth := (saw_successes + fraction) * SAW_DEPTH_PER_STROKE
	cut_groove.size.y = 4.0 + (saw_successes + fraction) * 12.0
	var hand_wobble := clampf((y - center_y) * 0.045, -2.5, 2.5)
	saw_sprite.position.y = SAW_START_Y + cut_depth + hand_wobble
	saw_sprite.rotation = hand_wobble * 0.004
	sawdust.position = Vector2(cut_groove.position.x + 2.0, saw_sprite.position.y + 19.0)
	if absf(saw_sprite.position.x - old_x) > 0.1:
		_tool_motion(false, sawdust.position)

	var reached_target := (
		(saw_expected_edge == 1 and saw_sprite.position.x >= SAW_VISUAL_RIGHT - 4.0)
		or (saw_expected_edge == -1 and saw_sprite.position.x <= SAW_VISUAL_LEFT + 4.0)
	)
	if reached_target and saw_deviation_samples >= 3:
		var average_deviation := saw_deviation_total / saw_deviation_samples
		_complete_saw_stroke(average_deviation <= (0.80 if GameState.is_easy_difficulty() else SAFE_DEVIATION))


func _finish_saw_stroke() -> void:
	if not dragging_saw:
		return
	dragging_saw = false
	if saw_deviation_samples >= 3:
		_complete_saw_stroke(false)
	else:
		_position_saw_at_expected_edge()
	tool_audio.stop()


func _complete_saw_stroke(success: bool) -> void:
	if stage != STAGE_SAW or action_locked:
		return
	dragging_saw = false
	keyboard_tool = false
	tool_audio.stop()
	saw_deviation_total = 0.0
	saw_deviation_samples = 0
	if not success:
		GameState.register_lumber_action("saw_miss")
		status_label.text = "Recorrido incompleto: vuelve al mango de inicio y mantén la hoja centrada"
		_position_saw_at_expected_edge()
		_pulse_status(Color("e69b58"))
		_register_mistake()
		return

	saw_successes += 1
	saw_expected_edge *= -1
	GameState.register_lumber_action("saw_success")
	progress_label.text = "%d de %d recorridos precisos" % [saw_successes, REQUIRED_CUTS]
	var depth_percent := int((float(saw_successes) / REQUIRED_CUTS) * 100.0)
	status_label.text = "La hoja penetró en la madera; ahora tira desde el mango opuesto"
	quality_bar.value = depth_percent
	quality_value.text = "%d%% de profundidad" % depth_percent
	cut_groove.size.y = 4.0 + saw_successes * 12.0
	saw_sprite.position.y = SAW_START_Y + saw_successes * SAW_DEPTH_PER_STROKE
	_emit_wood_particles(false, Vector2(cut_groove.position.x + 2.0, saw_sprite.position.y + 17.0))
	_pulse_status(Color("9fd56f"))
	if saw_successes >= REQUIRED_CUTS:
		action_locked = true
		status_label.text = "Corte completo: el sobrante se separa sin desperdiciar el tramo útil"
		workbench.saw_count = saw_successes
		workbench.show_feedback("Corte terminado · 92% del tramo aprovechado", Color("bfdc95"))
		_schedule_transition(1.05, _start_planing_stage)
	else:
		_position_saw_at_expected_edge()
	_save_work()


func _position_saw_at_expected_edge() -> void:
	saw_sprite.position.x = SAW_VISUAL_LEFT if saw_expected_edge == 1 else SAW_VISUAL_RIGHT
	saw_sprite.position.y = SAW_START_Y + saw_successes * SAW_DEPTH_PER_STROKE
	saw_sprite.rotation = 0.0
	cut_groove.size.y = 4.0 + saw_successes * 12.0


func _start_planing_stage() -> void:
	if stage != STAGE_SAW:
		return
	stage = STAGE_PLANE
	action_locked = false
	dragging_saw = false
	stage_label.text = "5. Cepillar respetando la dirección de la veta"
	instruction_label.text = "Ajusta la cuchilla en verde. Empuja a favor de veta o mantén ESPACIO / el botón; suelta entre las cuatro pasadas."
	progress_label.text = "0 de %d zonas niveladas" % REQUIRED_PLANING_PASSES
	status_label.text = "Coloca el cepillo en el extremo izquierdo de la primera franja"
	wood_hint.text = "Cepillar a favor de la veta corta las fibras limpiamente y conserva el espesor de la tabla."
	quality_title.text = "PLANITUD"
	quality_bar.value = 0.0
	quality_value.text = "Superficie áspera"
	saw_container.visible = false
	saw_sprite.visible = false
	cut_groove.visible = false
	planing_container.visible = true
	depth_controls.show()
	_update_adjustments()
	plane_sprite.visible = true
	workshop_texture.texture = BOARD_WORKSHOP
	plane_sprite.position = Vector2(PLANE_VISUAL_LEFT, PLANE_BASE_Y)
	for strip in planed_strips:
		strip.visible = false
		strip.size.x = 0.0
		strip.self_modulate.a = 0.0
	_set_step_rail()
	_save_work()


func _on_plane_drag_input(event: InputEvent) -> void:
	if stage != STAGE_PLANE or action_locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_plane_pass(event.position)
		else:
			_finish_plane_pass()
	elif event is InputEventMouseMotion and dragging_plane:
		_move_plane(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_plane_pass(event.position)
		else:
			_finish_plane_pass()
	elif event is InputEventScreenDrag and dragging_plane:
		_move_plane(event.position)


func _begin_plane_pass(local_position: Vector2) -> void:
	var x := clampf(local_position.x, 0.0, plane_drag_area.size.x)
	var pointer_work_x := plane_drag_area.position.x + x
	plane_started_left = (
		plane_sprite.position.x <= PLANE_VISUAL_LEFT + 5.0
		and absf(pointer_work_x - plane_sprite.position.x) <= 72.0
	)
	plane_wrong_direction = not plane_started_left
	if not plane_started_left:
		dragging_plane = false
		status_label.text = "Agarra primero el cepillo en el extremo izquierdo de la tabla"
		_pulse_status(Color("e69b58"))
		return
	dragging_plane = true
	plane_drag_offset_x = plane_sprite.position.x - pointer_work_x
	plane_drag_anchor_y = local_position.y
	plane_last_x = x
	plane_pressure_total = 0.0
	plane_pressure_samples = 0
	var current_strip := planed_strips[planing_passes]
	current_strip.visible = true
	current_strip.size.x = 3.0
	_move_plane(local_position)


func _move_plane(local_position: Vector2) -> void:
	var x := clampf(local_position.x, 0.0, plane_drag_area.size.x)
	if x < plane_last_x - 5.0:
		plane_wrong_direction = true
	plane_last_x = x
	var center_y := plane_drag_anchor_y
	var pressure_deviation := absf(local_position.y - center_y) / maxf(plane_drag_area.size.y * 0.5, 1.0)
	var pressure_quality := clampf(1.0 - pressure_deviation, 0.0, 1.0)
	plane_pressure_total += pressure_quality
	plane_pressure_samples += 1
	quality_bar.value = pressure_quality * 100.0
	quality_value.text = "%d%% de presión uniforme" % int(quality_bar.value)
	var old_x := plane_sprite.position.x
	var pointer_work_x := plane_drag_area.position.x + x
	plane_sprite.position.x = clampf(pointer_work_x + plane_drag_offset_x, PLANE_VISUAL_LEFT, PLANE_VISUAL_RIGHT)
	var lane_y := PLANE_BASE_Y + planing_passes * 5.0
	plane_sprite.position.y = lane_y + clampf((local_position.y - center_y) * 0.025, -2.0, 2.0)
	var current_strip := planed_strips[planing_passes]
	current_strip.size.x = 490.0 * (plane_sprite.position.x - PLANE_VISUAL_LEFT) / (PLANE_VISUAL_RIGHT - PLANE_VISUAL_LEFT)
	shavings.position = plane_sprite.position + Vector2(-34, 18)
	if absf(plane_sprite.position.x - old_x) > 0.1:
		_tool_motion(true, shavings.position)
	if plane_sprite.position.x >= PLANE_VISUAL_RIGHT - 4.0:
		dragging_plane = false
		var average_pressure := plane_pressure_total / maxf(float(plane_pressure_samples), 1.0)
		_complete_planing_pass(plane_started_left and not plane_wrong_direction and average_pressure >= (0.20 if GameState.is_easy_difficulty() else 0.42) and _depth_safe())


func _finish_plane_pass() -> void:
	if not dragging_plane:
		return
	dragging_plane = false
	_complete_planing_pass(false)


func _complete_planing_pass(success: bool = true) -> void:
	if stage != STAGE_PLANE or action_locked:
		return
	dragging_plane = false
	keyboard_tool = false
	plane_key_armed = false
	tool_audio.stop()
	plane_marker.position.x = 0.0
	if not success:
		GameState.register_lumber_action("plane_grain_error")
		var failed_strip := planed_strips[planing_passes]
		failed_strip.size.x = 0.0
		failed_strip.visible = false
		plane_sprite.position = Vector2(PLANE_VISUAL_LEFT, PLANE_BASE_Y + planing_passes * 5.0)
		status_label.text = "Revisa la cuchilla: avanza desde la izquierda con presión uniforme."
		_pulse_status(Color("e69b58"))
		_register_mistake()
		return
	var completed_strip := planed_strips[planing_passes]
	completed_strip.visible = true
	completed_strip.size.x = 490.0
	completed_strip.color = Color(0.93, 0.69, 0.27, 0.22)
	planing_passes += 1
	GameState.register_lumber_action("plane_pass")
	progress_label.text = "%d de %d zonas niveladas" % [planing_passes, REQUIRED_PLANING_PASSES]
	quality_bar.value = (float(planing_passes) / REQUIRED_PLANING_PASSES) * 100.0
	quality_value.text = "%d%% de superficie plana" % int(quality_bar.value)
	status_label.text = "Viruta continua: la superficie queda uniforme"
	_emit_wood_particles(true, plane_sprite.position + Vector2(-25, 18))
	_pulse_status(Color("9fd56f"))
	if planing_passes >= REQUIRED_PLANING_PASSES:
		action_locked = true
		_schedule_transition(0.65, _start_load_test_stage)
	else:
		plane_sprite.position = Vector2(PLANE_VISUAL_LEFT, PLANE_BASE_Y + planing_passes * 5.0)
		status_label.text = "Franja nivelada: levanta el cepillo y vuelve al extremo izquierdo"
	_save_work()


func _start_load_test_stage() -> void:
	if stage != STAGE_PLANE:
		return
	stage = STAGE_TEST
	action_locked = false
	dragging_plane = false
	stage_label.text = "6. Comprobar la tabla bajo carga"
	instruction_label.text = "Coloca cada saco en orden. Regula el apoyo para mantener la aguja en verde mientras la tabla soporta más peso."
	progress_label.text = "0 de %d sacos colocados" % REQUIRED_LOAD_SACKS
	status_label.text = "Comienza con una carga ligera"
	wood_hint.text = "La prueba gradual permite detectar flexión o grietas antes de confiar la pieza a la maquinaria."
	quality_title.text = "RESISTENCIA"
	quality_bar.value = 0.0
	quality_value.text = "Sin carga"
	planing_container.visible = false
	plane_sprite.visible = false
	load_container.visible = true
	depth_controls.hide()
	brace_controls.show()
	load_meter.show()
	quality_bar.hide()
	quality_value.position.y = 420
	_update_adjustments()
	_set_step_rail()
	sack_one.grab_focus()
	_save_work()


func _on_sack_pressed(button: Button, sack_number: int) -> void:
	if stage != STAGE_TEST or action_locked or button.disabled or sack_number != load_sacks + 1:
		return
	action_locked = true
	button.disabled = true
	button.text = "Comprobando saco %d…" % sack_number
	load_sacks += 1
	load_seconds = 0.0
	load_danger = 0.0
	load_drop_age = 0.0
	workbench.load_age = 0.0
	workbench.load_count = load_sacks
	workbench.load_locked = true
	var sack_visual: Sprite2D = [sack_visual_1, sack_visual_2, sack_visual_3][sack_number - 1]
	var sack_shadow := sack_shadows[sack_number - 1]
	sack_visual.visible = true
	sack_visual.position.y = 22.0
	sack_visual.scale = Vector2.ONE * 0.034
	sack_shadow.visible = true
	sack_shadow.scale = Vector2(0.25, 0.25)
	sack_shadow.modulate.a = 0.0
	var drop := _animation().set_parallel(true)
	drop.tween_property(sack_visual, "position:y", SACK_REST_Y, 0.60 if GameState.is_easy_difficulty() else 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_property(sack_visual, "scale", Vector2.ONE * 0.045, 0.27).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(sack_shadow, "scale", Vector2.ONE, 0.28)
	drop.tween_property(sack_shadow, "modulate:a", 1.0, 0.2)
	progress_label.text = "%d de 3 sacos · carga en observación" % load_sacks
	status_label.text = "Observa la flexión: la tabla debe recuperar su estabilidad"
	quality_value.text = "Comprobando la carga…"
	action_audio.pitch_scale = 0.82 + load_sacks * 0.08
	action_audio.play()
	_update_adjustments()


func _settle_load() -> void:
	if stage != STAGE_TEST or verified_loads >= load_sacks or load_seconds < 1.2:
		return
	verified_loads += 1
	GameState.register_lumber_action("load_sack")
	_save_work()
	workbench.verified_loads = verified_loads
	var button: Button = [sack_one, sack_two, sack_three][verified_loads - 1]
	button.text = "✓ Saco %d estable" % verified_loads
	button.modulate = Color("b9e58d")
	quality_bar.value = verified_loads / 3.0 * 100.0
	quality_value.text = "%d de 3 cargas verificadas" % verified_loads
	progress_label.text = "%d de 3 pruebas superadas" % verified_loads
	status_label.text = "Carga estable: puedes añadir el siguiente saco"
	workbench.show_feedback("✓ La tabla se estabiliza bajo carga", Color("bfdc95"))
	if verified_loads < REQUIRED_LOAD_SACKS:
		action_locked = false
		workbench.load_locked = false
		var next: Button = [sack_one, sack_two, sack_three][verified_loads]
		next.disabled = false
		next.grab_focus()
		_update_adjustments()
	else:
		status_label.text = "Tres cargas verificadas: la tabla es apta para el molino"
		_schedule_transition(0.7, _complete_lumber_puzzle)


func _complete_lumber_puzzle() -> void:
	if stage != STAGE_TEST or verified_loads != REQUIRED_LOAD_SACKS or load_sacks != REQUIRED_LOAD_SACKS:
		return
	stage = STAGE_COMPLETE
	action_locked = false
	stage_label.text = "Tabla estructural terminada"
	instruction_label.text = "La veta recta, el corte alineado y el cepillado uniforme produjeron una pieza estable para reforzar el molino."
	progress_label.text = "Prueba de carga superada"
	status_label.text = "Bruno te entrega la tabla"
	wood_hint.text = "La preparación cuidadosa reducía desperdicios y prolongaba la vida de las máquinas de madera."
	quality_title.text = "CALIDAD FINAL"
	quality_bar.value = 100.0
	quality_value.text = "Apta para el molino"
	load_container.visible = false
	brace_controls.hide()
	load_meter.hide()
	quality_bar.show()
	quality_value.position.y = 397
	continue_button.visible = true
	continue_button.grab_focus()
	GameState.complete_lumber_puzzle()
	_set_step_rail()
	_pulse_status(Color("a8df85"))


func _emit_wood_particles(use_shavings: bool, at_position: Vector2) -> void:
	var particles := shavings if use_shavings else sawdust
	particles.position = at_position
	particles.amount = 22 + saw_successes * 4 + planing_passes * 5
	particles.restart()


func _set_step_rail() -> void:
	_sync_workbench()
	workbench.feedback_time = 0.0
	var labels := [step_inspect, %StepMeasure, step_secure, step_saw, step_plane, step_test]
	for index in labels.size():
		var label := labels[index] as Label
		if stage == STAGE_COMPLETE or index < stage:
			label.modulate = Color("8fc96b")
		elif index == stage:
			label.modulate = Color("f2c45c")
		else:
			label.modulate = Color(0.48, 0.47, 0.42, 0.8)


func _all_buttons() -> Array[Button]:
	return [
		close_button, straight_grain, radial_crack, large_knot, wet_section,
		left_support, center_wedge, right_clamp, stability_test,
		sack_one, sack_two, sack_three, continue_button, mark_button, plane_hold_button,
	]


func _pulse_status(color: Color) -> void:
	status_label.modulate = color
	var pulse := _animation()
	pulse.tween_property(status_label, "modulate", Color.WHITE, 0.42)


func _style_controls() -> void:
	var action := StyleBoxFlat.new()
	action.bg_color = Color("6e4325")
	action.border_color = Color("ddb05a")
	action.set_border_width_all(2)
	action.set_corner_radius_all(4)
	var hover := action.duplicate()
	hover.bg_color = Color("986037")
	var disabled := action.duplicate()
	disabled.bg_color = Color("352b20")
	disabled.border_color = Color("625541")
	for button in _all_buttons():
		button.add_theme_color_override("font_disabled_color", Color("c5c3a8"))
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_stylebox_override("normal", action)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_stylebox_override("disabled", disabled)


func _configure_particles() -> void:
	var chip_texture := GradientTexture2D.new()
	var chip_gradient := Gradient.new()
	chip_gradient.colors = PackedColorArray([Color("f4cd78"), Color("a8642e"), Color(0.35, 0.2, 0.08, 0)])
	chip_gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	chip_texture.gradient = chip_gradient
	chip_texture.width = 9
	chip_texture.height = 4
	for particles in [sawdust, shavings]:
		particles.texture = chip_texture
		particles.direction = Vector2(0, -1)
		particles.spread = 68.0
		particles.initial_velocity_min = 50.0
		particles.initial_velocity_max = 120.0
		particles.gravity = Vector2(0, 165)
		particles.scale_amount_min = 0.4
		particles.scale_amount_max = 1.1
		particles.lifetime = 0.75
		particles.one_shot = true
		particles.explosiveness = 0.82


func _configure_audio() -> void:
	action_audio.stream = _make_wood_sound(220.0, 0.16, 0.5)
	tool_audio.stream = _make_wood_sound(155.0, 0.23, 0.72)


func _make_wood_sound(frequency: float, duration: float, noise_mix: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = int(frequency * 31.0)
	for index in sample_count:
		var time := float(index) / mix_rate
		var progress := time / duration
		var envelope := sin(PI * progress) * (1.0 - progress * 0.35)
		var rasp := sin(TAU * frequency * time) * 0.32 + sin(TAU * frequency * 2.7 * time) * 0.18
		var noise := random.randf_range(-1.0, 1.0)
		var sample := clampf((rasp * (1.0 - noise_mix) + noise * noise_mix) * envelope * 0.5, -1.0, 1.0)
		data.encode_s16(index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func _set_player_controls(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.controls_enabled = enabled


func _process(delta: float) -> void:
	if not overlay.visible or awaiting_retry:
		return
	motion_age += delta
	dust_cooldown = maxf(0, dust_cooldown - delta)
	if motion_age > 0.12:
		tool_audio.stop()
	if not action_locked:
		_process_keyboard(delta)
	if stage == STAGE_MEASURE and not action_locked:
		work_clock += delta * GameState.get_forge_indicator_speed()
		marking_meter.value = (sin(work_clock * 2.4) + 1) * 0.5
	if stage == STAGE_TEST:
		_process_load(delta)
	_sync_workbench()
	if stage >= STAGE_TEST:
		for index in load_sacks:
			if index == load_sacks - 1 and workbench.load_age < 0.33:
				continue
			var sack: Sprite2D = [sack_visual_1, sack_visual_2, sack_visual_3][index]
			var displacement: float = workbench.deflection_at(sack.position.x - 2)
			sack.position.y = SACK_REST_Y + displacement
			sack_shadows[index].position.y = 113 + displacement


func _process_keyboard(delta: float) -> void:
	if stage == STAGE_SAW:
		var direction := int(right_held) - int(left_held)
		if direction == saw_expected_edge and (not dragging_saw or keyboard_tool):
			if not dragging_saw:
				keyboard_tool = true
				_begin_saw_stroke(Vector2(saw_sprite.position.x + (-94 if direction == 1 else 94) - saw_drag_area.position.x, saw_drag_area.size.y / 2))
			_move_saw(Vector2(saw_sprite.position.x - saw_drag_offset_x - saw_drag_area.position.x + direction * delta * 215 * (0.5 if GameState.is_easy_difficulty() else 1.0), saw_drag_area.size.y / 2))
	elif stage == STAGE_PLANE and space_held and plane_key_armed and (not dragging_plane or keyboard_tool):
		if not dragging_plane:
			keyboard_tool = true
			_begin_plane_pass(Vector2(plane_sprite.position.x - plane_drag_area.position.x, plane_drag_area.size.y / 2))
		_move_plane(Vector2(plane_sprite.position.x - plane_drag_offset_x - plane_drag_area.position.x + delta * 280 * (0.5 if GameState.is_easy_difficulty() else 1.0), plane_drag_area.size.y / 2))


func _sync_workbench() -> void:
	workbench.stage = [0, 0, 1, 2, 3, 4, 5][stage]
	workbench.extra_mode = "measure" if stage == STAGE_MEASURE else ""
	workbench.marked_lines = marked_lines
	workbench.square_angle = angle_slider.value
	workbench.measured_length = length_slider.value
	workbench.difficulty_pace = GameState.get_forge_indicator_speed()
	workbench.saw_count = saw_successes
	workbench.saw_direction = saw_expected_edge
	workbench.saw_position = saw_sprite.position - Vector2(2, 2)
	workbench.plane_count = planing_passes
	for index in 4:
		workbench.lane_progress[index] = clampf(planed_strips[index].size.x / 490, 0, 1)
	workbench.load_count = load_sacks
	workbench.verified_loads = verified_loads
	workbench.load_locked = action_locked


func _tool_motion(is_plane: bool, point: Vector2) -> void:
	motion_age = 0.0
	if not tool_audio.playing:
		tool_audio.pitch_scale = 1.08 if is_plane else 0.95
		tool_audio.play()
	if dust_cooldown <= 0:
		var particles := shavings if is_plane else sawdust
		particles.position = point
		particles.amount = 8
		particles.restart()
		dust_cooldown = 0.16


func _cancel_tools() -> void:
	dragging_saw = false
	dragging_plane = false
	left_held = false
	right_held = false
	space_held = false
	keyboard_tool = false
	plane_key_armed = false
	tool_audio.stop()
	motion_age = 1.0
	dust_cooldown = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_cancel_tools()
		_position_saw_at_expected_edge()
		plane_sprite.position = Vector2(PLANE_VISUAL_LEFT, PLANE_BASE_Y + planing_passes * 5)
		if planing_passes < 4:
			planed_strips[planing_passes].size.x = 0
		_save_work()


func _schedule_transition(delay: float, callback: Callable) -> void:
	var requested_session := session_id
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self) and overlay.visible and requested_session == session_id:
			callback.call())


func _animation() -> Tween:
	animations = animations.filter(func(tween: Tween): return tween.is_valid())
	var tween := create_tween()
	animations.append(tween)
	return tween


func _stop_animations() -> void:
	for tween in animations:
		if tween.is_valid():
			tween.kill()
	animations.clear()


func _fit_panel() -> void:
	if not is_node_ready():
		return
	var available := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var factor := minf(1, minf(available.x / panel.size.x, available.y / panel.size.y))
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2.ONE * maxf(0.1, factor)


func _start_measure_stage() -> void:
	if stage != STAGE_INSPECT:
		return
	stage = STAGE_MEASURE
	action_locked = false
	inspect_container.hide()
	measure_container.show()
	marking_meter.show()
	marking_meter.low = 0.30 if GameState.is_easy_difficulty() else 0.38
	marking_meter.high = 0.75 if GameState.is_easy_difficulty() else 0.62
	stage_label.text = "2. Medir y marcar con regla y escuadra"
	instruction_label.text = "Mide 160 cm y ajusta la escuadra a 90°. Traza tres marcas en orden: pulsa ESPACIO o la marca cuando la aguja esté en verde."
	wood_hint.text = "Medir antes de cortar evita desperdicios. La escuadra mantiene el corte perpendicular a las fibras."
	quality_title.text = "MARCAS DE CORTE"
	_update_measure_progress()
	_update_adjustments()
	_set_step_rail()
	mark_button.grab_focus()
	_save_work()


func _on_mark_requested(index: int) -> void:
	if stage != STAGE_MEASURE or action_locked or not overlay.visible:
		return
	if index != marked_lines:
		status_label.text = "Sigue el orden de las marcas: 1, 2 y 3."
		return
	var length_tolerance := 8.0 if GameState.is_easy_difficulty() else 3.0
	var angle_tolerance := 3.0 if GameState.is_easy_difficulty() else 1.0
	if absf(length_slider.value - 160) > length_tolerance or absf(angle_slider.value - 90) > angle_tolerance:
		status_label.text = "Revisa la medida de 160 cm y el ángulo de 90°. Las marcas anteriores se conservan."
		_register_mistake()
		return
	if marking_meter.value < marking_meter.low or marking_meter.value > marking_meter.high:
		status_label.text = "Espera la zona verde para trazar una marca limpia."
		_register_mistake()
		return
	marked_lines += 1
	GameState.register_lumber_action("measurement_mark")
	_update_measure_progress()
	workbench.show_feedback("✓ Marca %d precisa" % marked_lines, Color("bfdc95"))
	action_audio.play()
	_save_work()
	if marked_lines == 3:
		action_locked = true
		_schedule_transition(0.65, _start_secure_stage)


func _update_measure_progress() -> void:
	progress_label.text = "%d de 3 marcas precisas" % marked_lines
	quality_bar.value = marked_lines / 3.0 * 100
	quality_value.text = "%d / 3 marcas de tiza" % marked_lines
	status_label.text = "Ajusta la regla y marca en verde."


func _clamp_tolerance() -> float:
	return 15.0 if GameState.is_easy_difficulty() else 7.0


func _depth_safe() -> bool:
	return absf(depth_slider.value - 50) <= (20.0 if GameState.is_easy_difficulty() else 5.0)


func _update_adjustments() -> void:
	%LengthLabel.text = "REGLA · %.0f cm / 160 cm" % length_slider.value
	%AngleLabel.text = "ESCUADRA · %.0f° / 90°" % angle_slider.value
	%ClampLabel.text = "PRESIÓN DE LA ABRAZADERA · %.0f%% · ajusta en verde" % clamp_slider.value
	%DepthLabel.text = "PROFUNDIDAD DE LA CUCHILLA · %.0f%%" % depth_slider.value
	var target: float = [42.0, 58.0, 72.0][mini(verified_loads, 2)]
	%BraceLabel.text = "APOYO · %.0f%% · carga %d / 3 · referencia %.0f%%" % [brace_slider.value, mini(3, verified_loads + 1), target]
	_set_slider_band(%ClampBand, clamp_slider, 60 - _clamp_tolerance(), 60 + _clamp_tolerance())
	var depth_tolerance := 20.0 if GameState.is_easy_difficulty() else 5.0
	_set_slider_band(%DepthBand, depth_slider, 50 - depth_tolerance, 50 + depth_tolerance)
	var tolerance := 15.0 if GameState.is_easy_difficulty() else 6.0
	_set_slider_band(%BraceBand, brace_slider, target - tolerance, target + tolerance)
	load_meter.low = (target - tolerance) / 100
	load_meter.high = (target + tolerance) / 100
	load_meter.queue_redraw()
	_sync_workbench()


func _set_slider_band(band: ColorRect, slider: HSlider, low: float, high: float) -> void:
	band.position.x = slider.position.x + 8 + (slider.size.x - 16) * low / 100
	band.size.x = (slider.size.x - 16) * (high - low) / 100


func _hold_plane() -> void:
	if stage != STAGE_PLANE or action_locked:
		return
	space_held = true
	plane_key_armed = true


func _release_plane() -> void:
	if plane_hold_button.button_pressed:
		return
	if stage == STAGE_PLANE and keyboard_tool:
		_finish_plane_pass()
	space_held = false
	plane_key_armed = false


func _process_load(delta: float) -> void:
	work_clock += delta * GameState.get_forge_indicator_speed()
	load_drop_age += delta
	var effective := clampf(brace_slider.value + sin(work_clock * 2.4) * 7, 0, 100)
	load_meter.value = effective / 100
	if load_sacks <= verified_loads or verified_loads == 3:
		return
	if load_drop_age < (0.65 if GameState.is_easy_difficulty() else 0.35):
		return
	var safe: bool = effective >= load_meter.low * 100 and effective <= load_meter.high * 100
	if safe:
		load_seconds += delta
		load_danger = 0
		status_label.text = "Apoyo estable: mantén la aguja en verde."
	else:
		load_seconds = 0
		load_danger += delta
		status_label.text = "Regula el apoyo: la aguja debe volver a la zona verde."
	quality_value.text = "%.1f / 1.2 s en verde" % minf(1.2, load_seconds)
	quality_value.modulate = Color("bfdc95") if safe else Color("e8bd70")
	if load_seconds >= 1.2:
		_settle_load()
	elif load_danger >= (4.0 if GameState.is_easy_difficulty() else 1.0):
		# Only the unverified sack is removed; earlier loads remain approved.
		var failed := load_sacks - 1
		[sack_visual_1, sack_visual_2, sack_visual_3][failed].hide()
		sack_shadows[failed].hide()
		load_sacks = verified_loads
		action_locked = false
		load_seconds = 0
		load_danger = 0
		var button: Button = [sack_one, sack_two, sack_three][failed]
		button.disabled = false
		button.text = "Reintentar saco %d" % (failed + 1)
		status_label.text = "Saco retirado: ajusta el apoyo y vuelve a probar esta carga."
		progress_label.text = "%d de 3 cargas verificadas" % verified_loads
		_register_mistake()


func _refresh_opportunities() -> void:
	opportunities_label.text = "Oportunidades: %d / %d" % [GameState.get_lumber_attempts_left(), GameState.get_lumber_opportunities()]
	opportunities_label.modulate = Color("e69b58") if GameState.get_lumber_attempts_left() <= 3 else Color("f2c45c")


func _register_mistake(reason: String = "") -> void:
	if not overlay.visible or awaiting_retry or GameState.get_lumber_attempts_left() <= 0:
		return
	var explanation := reason if not reason.is_empty() else status_label.text
	GameState.fail_lumber_attempt()
	_cancel_tools()
	sawdust.emitting = false
	shavings.emitting = false
	_refresh_opportunities()
	_save_work()
	_pulse_status(Color("e69b58"))
	if GameState.get_lumber_attempts_left() <= 0:
		close()
		GameState.show_lumber_encouragement()
		return
	awaiting_retry = true
	action_locked = true
	workbench.active = false
	retry_notice.show_error(explanation, GameState.get_lumber_attempts_left(), GameState.get_lumber_opportunities())


func _continue_current_phase() -> void:
	if not awaiting_retry or not overlay.visible:
		return
	_cancel_tools()
	awaiting_retry = false
	action_locked = false
	retry_notice.hide()
	workbench.active = true
	load_danger = 0
	match stage:
		STAGE_INSPECT: straight_grain.grab_focus()
		STAGE_MEASURE: mark_button.grab_focus()
		STAGE_SECURE: clamp_slider.grab_focus()
		STAGE_PLANE: depth_slider.grab_focus()
		STAGE_TEST: brace_slider.grab_focus()


func _save_work() -> void:
	if restoring_work or not overlay.visible or GameState.flags.get("lumber_puzzle_completed", false):
		return
	GameState.flags["lumber_progress"] = {
		"stage": stage, "selected": workbench.selected, "inspected": workbench.inspected.duplicate(),
		"marked_lines": marked_lines, "fixations": workbench.fixations.duplicate(), "secured": secured_verified,
		"cuts": saw_successes, "passes": planing_passes, "loads": verified_loads,
		"length": length_slider.value, "angle": angle_slider.value, "clamp": clamp_slider.value,
		"depth": depth_slider.value, "brace": brace_slider.value,
	}
	GameState.save_progress()


func _restore_work() -> void:
	var saved: Dictionary = GameState.flags.get("lumber_progress", {}).duplicate(true)
	if saved.is_empty():
		return
	restoring_work = true
	var restored_stage := clampi(int(saved.get("stage", 0)), 0, STAGE_TEST)
	if restored_stage >= STAGE_MEASURE: _start_measure_stage()
	if restored_stage >= STAGE_SECURE: _start_secure_stage()
	if restored_stage >= STAGE_SAW: _start_saw_stage()
	if restored_stage >= STAGE_PLANE: _start_planing_stage()
	if restored_stage >= STAGE_TEST: _start_load_test_stage()
	workbench.selected = bool(saved.get("selected", false))
	workbench.inspected = saved.get("inspected", [false, false, false, false]).duplicate()
	marked_lines = clampi(int(saved.get("marked_lines", 0)), 0, 3)
	workbench.fixations = saved.get("fixations", [false, false, false]).duplicate()
	setup_parts = 0
	for index in 3:
		if workbench.fixations[index]:
			setup_parts += 1
			workbench.fix_progress[index] = 1
			var button: Button = [left_support, center_wedge, right_clamp][index]
			button.disabled = true
			button.text = "✓ " + button.text
			button.modulate = Color("b9e58d")
	secured_verified = bool(saved.get("secured", false))
	saw_successes = clampi(int(saved.get("cuts", 0)), 0, 5)
	saw_expected_edge = 1 if saw_successes % 2 == 0 else -1
	_position_saw_at_expected_edge()
	planing_passes = clampi(int(saved.get("passes", 0)), 0, 4)
	for index in planing_passes:
		planed_strips[index].visible = true
		planed_strips[index].size.x = 490
	plane_sprite.position = Vector2(PLANE_VISUAL_LEFT, PLANE_BASE_Y + planing_passes * 5)
	verified_loads = clampi(int(saved.get("loads", 0)), 0, 3)
	load_sacks = verified_loads
	for index in 3:
		var button: Button = [sack_one, sack_two, sack_three][index]
		button.disabled = index != verified_loads
		if index < verified_loads:
			button.text = "✓ Saco %d estable" % (index + 1)
			button.modulate = Color("b9e58d")
			[sack_visual_1, sack_visual_2, sack_visual_3][index].show()
			sack_shadows[index].show()
	length_slider.set_value_no_signal(float(saved.get("length", 120)))
	angle_slider.set_value_no_signal(float(saved.get("angle", 82)))
	clamp_slider.set_value_no_signal(float(saved.get("clamp", 30)))
	depth_slider.set_value_no_signal(float(saved.get("depth", 25)))
	brace_slider.set_value_no_signal(float(saved.get("brace", 30)))
	# Resolve a closed transition without replaying actions or awarding a second item.
	if stage == STAGE_INSPECT and workbench.selected: _start_measure_stage()
	if stage == STAGE_MEASURE:
		_update_measure_progress()
		if marked_lines == 3: _start_secure_stage()
	if stage == STAGE_SECURE:
		progress_label.text = "%d de 3 fijaciones colocadas" % setup_parts
		quality_bar.value = setup_parts / 3.0 * 100
		quality_value.text = "%d / 3 fijaciones" % setup_parts
		if secured_verified: _start_saw_stage()
	if stage == STAGE_SAW:
		progress_label.text = "%d de 5 recorridos precisos" % saw_successes
		quality_bar.value = saw_successes / 5.0 * 100
		quality_value.text = "%d%% de profundidad" % int(quality_bar.value)
		_position_saw_at_expected_edge()
		if saw_successes == 5: _start_planing_stage()
	if stage == STAGE_PLANE:
		progress_label.text = "%d de 4 zonas niveladas" % planing_passes
		quality_bar.value = planing_passes / 4.0 * 100
		quality_value.text = "%d%% de superficie plana" % int(quality_bar.value)
		status_label.text = "Franja %d / 4: ajusta la cuchilla y avanza a favor de veta." % mini(4, planing_passes + 1)
		if planing_passes == 4: _start_load_test_stage()
	if stage == STAGE_TEST:
		progress_label.text = "%d de 3 cargas verificadas" % verified_loads
		if verified_loads == 3: _complete_lumber_puzzle()
	restoring_work = false
	_update_adjustments()
	_set_step_rail()
