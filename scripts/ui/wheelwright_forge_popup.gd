extends CanvasLayer

const STAGE_ASSEMBLE := 0
const STAGE_HEAT := 1
const STAGE_RIVET := 2
const STAGE_COOL := 3
const STAGE_CENTER := 4
const STAGE_TEST := 5
const STAGE_COMPLETE := 6
const SCREW_TARGETS := [0.55, 0.45, 0.6]
const HEAT_PER_PUMP := 15.0
const RED_HOT_HEAT := 70.0
const MAX_WORK_HEAT := 96.0
const START_WORK_HEAT := 82.0
const COOL_HEAT := 4.0
const HEAT_PER_STRIKE := 4.5
const REQUIRED_RIVETS := 4
const HITS_PER_RIVET := 3
const PUMP_CYCLE := 0.65
const ALIGN_TOLERANCE := 0.18

@onready var overlay: ColorRect = %ForgeOverlay
@onready var panel: PanelContainer = $ForgeOverlay/Panel
@onready var workbench = %WorkbenchDisplay
@onready var hammer = %Hammer
@onready var stage_label: Label = %StageLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel
@onready var heat_bar: ProgressBar = %HeatBar
@onready var heat_value: Label = %HeatValue
@onready var quality_title: Label = %QualityTitle
@onready var bellows_button: Button = %BellowsButton
@onready var strike_button: Button = %StrikeButton
@onready var rotate_button: Button = %RotateButton
@onready var vent_button: Button = %VentButton
@onready var proof_button: Button = %ProofButton
@onready var continue_button: Button = %ContinueButton
@onready var tool_controls: HBoxContainer = %ToolControls
@onready var key_hint: Label = %KeyHint
@onready var close_button: Button = %CloseButton
@onready var forge_sparks: CPUParticles2D = %ForgeSparks
@onready var gear_sparks: CPUParticles2D = %GearSparks
@onready var bellows_audio: AudioStreamPlayer = %BellowsAudio
@onready var hammer_audio: AudioStreamPlayer = %HammerAudio
@onready var steps: Array[Label] = [%StepHeat, %StepRivet, %StepCool, %StepTest]

var forge_stage := STAGE_ASSEMBLE
var parts_placed := [false, false, false, false]
var piece_angles := [1, 2, 3, 1]
var clamps := [0.0, 0.0]
var selected_piece := 0
var selected_clamp := 0
var clamp_hold := false
var screws := [0.1, 0.85, 0.2]
var selected_screw := 0
var hold_adjust := 0
var heat_ready_seconds := 0.0
var danger_seconds := 0.0
var precision_time := 0.0
var cooling_elapsed := 0.0
var ventilation_strength := 25.0
var proof_level_radians := 0.0
var awaiting_retry := false
var exhaustion_notice_pending := false
var failure_reason := ""
var challenge: Control
var challenge_controls: Control
var assembly_group: Control
var cooling_group: Control
var center_group: Control
var assembly_status: Label
var cooling_slider: HSlider
var attempts_label: Label
var retry_panel: Panel
var retry_label: Label
var retry_button: Button
var heat_vent: Button
var extra_buttons: Array[Button] = []
var application_focused := true
var heat := 0.0
var rivet_index := 0
var rivet_hits := [0, 0, 0, 0]
var strike_order := [0, 2, 1, 3]
var session_id := 0
var player_was_enabled := true
var action_locked := false
var pending_rivet := -1
var pump_cooldown := 0.0
var seconds_since_pump := 0.0
var pointer_pump := false
var pointer_vent := false
var pointer_proof := false
var space_held := false
var f_held := false
var left_held := false
var right_held := false
var proof_radians := 0.0
var proof_checks := 0
var wheel_speed := 0.0
var cooling_verified := false
var animations: Array[Tween] = []
var heat_fill_style: StyleBoxFlat


func _ready() -> void:
	EventBus.wheelwright_forge_requested.connect(open)
	close_button.pressed.connect(close)
	continue_button.pressed.connect(close)
	bellows_button.button_down.connect(_hold_pump)
	bellows_button.button_up.connect(func(): pointer_pump = false)
	strike_button.pressed.connect(func(): _strike_rivet(strike_order[mini(rivet_index, 3)]))
	rotate_button.pressed.connect(_turn_to_next)
	vent_button.button_down.connect(func(): pointer_vent = true)
	vent_button.button_up.connect(func(): pointer_vent = false)
	proof_button.button_down.connect(func(): pointer_proof = true)
	proof_button.button_up.connect(func(): pointer_proof = false)
	workbench.bellows_pressed.connect(_hold_pump)
	workbench.rivet_pressed.connect(_strike_rivet)
	workbench.wheel_rotation_requested.connect(_move_wheel)
	hammer.impacted.connect(_on_hammer_impact)
	get_viewport().size_changed.connect(_fit_panel)
	_build_challenge_controls()
	_style_controls()
	_configure_particles()
	_configure_audio()
	_reset_minigame()
	_fit_panel.call_deferred()


func open() -> void:
	if overlay.visible:
		return
	if not GameState.flags.get("tools_given_to_mateo", false):
		EventBus.show_toast("Habla con Mateo para entregar el hierro de las herramientas")
		return
	var player = get_tree().get_first_node_in_group("player")
	player_was_enabled = player.controls_enabled if player else true
	if int(GameState.flags.get("forge_attempts_left", GameState.get_forge_opportunities())) <= 0 and not GameState.flags.get("wheelwright_forge_completed", false):
		GameState.show_forge_encouragement()
		return
	_reset_minigame()
	application_focused = true
	overlay.visible = true
	workbench.active = true
	_set_player_controls(false)
	_fit_panel()
	if GameState.flags.get("wheelwright_forge_completed", false):
		rivet_index = REQUIRED_RIVETS
		rivet_hits = [3, 3, 3, 3]
		proof_radians = TAU
		proof_checks = 3
		cooling_verified = true
		parts_placed = [true, true, true, true]
		clamps = [1.0, 1.0]
		screws = SCREW_TARGETS.duplicate()
		_present_complete()
	else:
		_restore_checkpoint()
		_focus_stage()


func close() -> void:
	if not overlay.visible:
		return
	_save_checkpoint()
	session_id += 1
	_release_all_controls()
	_stop_animations()
	hammer.cancel()
	pending_rivet = -1
	workbench.active = false
	forge_sparks.emitting = false
	gear_sparks.emitting = false
	bellows_audio.stop()
	hammer_audio.stop()
	overlay.visible = false
	_set_player_controls(player_was_enabled)
	if exhaustion_notice_pending:
		exhaustion_notice_pending = false
		GameState.show_forge_encouragement.call_deferred()


func _reset_minigame() -> void:
	session_id += 1
	_release_all_controls()
	_stop_animations()
	hammer.cancel()
	workbench.reset_workbench()
	forge_stage = STAGE_ASSEMBLE
	parts_placed = [false, false, false, false]
	piece_angles = [1, 2, 3, 1]
	clamps = [0.0, 0.0]
	screws = [0.1, 0.85, 0.2]
	selected_piece = 0
	selected_clamp = 0
	selected_screw = 0
	heat = 0.0
	rivet_index = 0
	rivet_hits = [0, 0, 0, 0]
	pending_rivet = -1
	action_locked = false
	awaiting_retry = false
	retry_panel.visible = false
	pump_cooldown = 0.0
	seconds_since_pump = 0.0
	heat_ready_seconds = 0
	danger_seconds = 0
	precision_time = 0
	cooling_elapsed = 0
	ventilation_strength = 25
	cooling_slider.value = 25
	proof_radians = 0.0
	proof_level_radians = 0
	proof_checks = 0
	cooling_verified = false
	_show_stage()


func _process(delta: float) -> void:
	if not overlay.visible or not application_focused or forge_stage == STAGE_COMPLETE or awaiting_retry:
		return
	var indicator_speed := GameState.get_forge_indicator_speed()
	var thermal_speed := 0.5 if GameState.is_easy_difficulty() else 1.0
	var correction_time := 4.0 if GameState.is_easy_difficulty() else 2.0
	precision_time += delta * indicator_speed
	pump_cooldown = maxf(0, pump_cooldown - delta)
	seconds_since_pump += delta
	if forge_stage == STAGE_ASSEMBLE:
		if (clamp_hold or space_held) and parts_placed.all(func(part): return part):
			clamps[selected_clamp] = minf(1, clamps[selected_clamp] + delta * 0.65)
			if clamps[selected_clamp] >= 1 and selected_clamp == 0:
				selected_clamp = 1
	elif forge_stage in [STAGE_HEAT, STAGE_RIVET]:
		if pointer_pump or f_held or (space_held and forge_stage == STAGE_HEAT):
			_pump_bellows()
		if pointer_vent:
			_set_heat(heat - delta * 12 * thermal_speed)
		elif seconds_since_pump > 0.85:
			_set_heat(heat - delta * thermal_speed * (1.0 if heat > MAX_WORK_HEAT else 0.9 if forge_stage == STAGE_HEAT else 2.1))
		if heat > MAX_WORK_HEAT:
			danger_seconds += delta
			workbench.show_feedback("¡Exceso de calor! Suelta el fuelle y ventila con V", Color("f3aa71"))
			if danger_seconds >= correction_time:
				_fail_attempt("El hierro se sobrecalentó. Suelta el fuelle y usa V para bajar el calor.")
				return
		else:
			danger_seconds = 0
		if forge_stage == STAGE_HEAT:
			heat_ready_seconds = heat_ready_seconds + delta if heat >= START_WORK_HEAT and heat <= MAX_WORK_HEAT else 0.0
			if heat_ready_seconds >= 2:
				_start_reinforcement()
		if forge_stage == STAGE_RIVET and not action_locked:
			var direction := int(right_held) - int(left_held)
			if direction != 0:
				_move_wheel(workbench.wheel_angle + direction * 1.9 * delta)
	elif forge_stage == STAGE_COOL and not action_locked:
		cooling_elapsed += delta * indicator_speed
		ventilation_strength = clampf(ventilation_strength + (int(right_held) - int(left_held)) * delta * 25, 0, 100)
		cooling_slider.set_value_no_signal(ventilation_strength)
		workbench.ventilating = ventilation_strength > 0
		_set_heat(heat - delta * cooling_rate() * thermal_speed)
		if heat <= COOL_HEAT:
			cooling_verified = true
			action_locked = true
			_release_all_controls()
			_schedule_transition(0.5, _start_centering)
		elif absf(cooling_rate() - cooling_target()) > 2:
			danger_seconds += delta
			workbench.show_feedback("Ajusta la ventilación: lleva el indicador a la franja verde", Color("f3aa71"))
			if danger_seconds >= correction_time:
				_fail_attempt("El enfriamiento fue irregular. Regula la ventilación dentro de la franja verde.")
				return
		else:
			danger_seconds = 0
	elif forge_stage == STAGE_CENTER:
		var direction := hold_adjust + int(right_held) - int(left_held)
		if direction != 0:
			adjust_screw(selected_screw, direction * delta * 0.17 * thermal_speed)
	elif forge_stage == STAGE_TEST and not action_locked:
		var drive: bool = pointer_proof or space_held or right_held
		wheel_speed = move_toward(wheel_speed, 2.8 if drive else 0.0, delta * indicator_speed * (0.9 if drive else 1.1))
		if workbench.dragging_wheel:
			wheel_speed = move_toward(wheel_speed, 0, delta * 0.7 * indicator_speed)
		var movement := wheel_speed * delta
		workbench.wheel_angle += movement
		_register_turn(movement)
		if wheel_speed > proof_target() + 0.28:
			danger_seconds += delta
			workbench.show_feedback("¡Demasiado rápido! Suelta la manivela para bajar la velocidad", Color("f3aa71"))
			if danger_seconds >= (5.2 if GameState.is_easy_difficulty() else 1.3):
				_fail_attempt("La rueda giró demasiado rápido bajo carga. Pulsa y suelta la manivela para regularla.")
				return
		else:
			danger_seconds = 0
	_sync_workbench()
	_refresh_rivets()
	_update_ui()


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and not (event is InputEventKey and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB)):
		get_viewport().set_input_as_handled()
		return
	if ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)):
		pointer_pump = false
		pointer_vent = false
		pointer_proof = false
		clamp_hold = false
		hold_adjust = 0
		workbench.release_pointer()
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_SPACE, KEY_F, KEY_V, KEY_Q, KEY_R, KEY_1, KEY_2, KEY_3, KEY_4, KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
			if not event.echo:
				if awaiting_retry:
					if event.pressed and key == KEY_SPACE: _retry_attempt()
				else:
					match key:
						KEY_F:
							f_held = event.pressed
							if f_held: _pump_bellows()
						KEY_V: pointer_vent = event.pressed
						KEY_SPACE:
							space_held = event.pressed
							if event.pressed:
								if forge_stage == STAGE_HEAT: _pump_bellows()
								elif forge_stage == STAGE_RIVET: _strike_rivet(strike_order[mini(rivet_index, 3)])
								elif forge_stage == STAGE_ASSEMBLE and not parts_placed.all(func(part): return part): place_part(selected_piece, selected_piece)
								elif forge_stage == STAGE_CENTER: _confirm_center()
						KEY_Q, KEY_R:
							if event.pressed and forge_stage == STAGE_ASSEMBLE: rotate_part(-1 if key == KEY_Q else 1)
						KEY_1, KEY_2, KEY_3, KEY_4:
							if event.pressed:
								if forge_stage == STAGE_ASSEMBLE: selected_piece = key - KEY_1
								elif forge_stage == STAGE_CENTER and key != KEY_4: selected_screw = key - KEY_1
						KEY_LEFT, KEY_A: left_held = event.pressed
						KEY_RIGHT, KEY_D: right_held = event.pressed
			get_viewport().set_input_as_handled()


func _hold_pump() -> void:
	pointer_pump = true
	_pump_bellows()


func _pump_bellows() -> void:
	if not overlay.visible or forge_stage not in [STAGE_HEAT, STAGE_RIVET] or awaiting_retry or pump_cooldown > 0 or heat >= 99.9:
		return
	pump_cooldown = PUMP_CYCLE
	seconds_since_pump = 0.0
	_set_heat(heat + HEAT_PER_PUMP * (0.5 if GameState.is_easy_difficulty() else 1.0))
	workbench.pump_age = 0.0
	GameState.register_forge_action("fuelle")
	bellows_audio.pitch_scale = 0.97 + heat * 0.0008
	bellows_audio.play()
	forge_sparks.amount = 8 + int(heat / 10)
	forge_sparks.restart()
	_update_ui()


func _start_reinforcement() -> void:
	if forge_stage != STAGE_HEAT or heat_ready_seconds < 2:
		return
	forge_stage = STAGE_RIVET
	_release_all_controls()
	_show_stage()
	strike_button.grab_focus()


func _aligned() -> bool:
	if rivet_index >= REQUIRED_RIVETS:
		return false
	return absf(wrapf(workbench.wheel_angle + strike_order[rivet_index] * PI / 2, -PI, PI)) <= ALIGN_TOLERANCE


func _strike_rivet(index: int) -> void:
	if not overlay.visible or forge_stage != STAGE_RIVET or action_locked or rivet_index >= REQUIRED_RIVETS:
		return
	if index != strike_order[rivet_index]:
		workbench.show_feedback("Sigue el refuerzo señalado: tocar otro lado no gasta oportunidades", Color("e6bf72"))
		return
	if heat < RED_HOT_HEAT or heat > MAX_WORK_HEAT:
		workbench.show_feedback("Regula el calor antes de remachar; este toque no gasta oportunidades", Color("e6bf72"))
		return
	if not _aligned():
		workbench.show_feedback("Alinea el remache con el marcador; este toque no gasta oportunidades", Color("e6bf72"))
		return
	if precision_value() < 0.38 or precision_value() > 0.62:
		_fail_attempt("El golpe cayó fuera de la zona verde. Espera el momento preciso antes de usar el martillo.")
		return
	action_locked = true
	pending_rivet = index
	workbench.strike_locked = true
	hammer.strike(workbench.rivet_position(index) + workbench.position)
	_refresh_rivets()


func _on_hammer_impact() -> void:
	if not overlay.visible or forge_stage != STAGE_RIVET or pending_rivet < 0:
		return
	var index := pending_rivet
	pending_rivet = -1
	if heat < RED_HOT_HEAT or heat > MAX_WORK_HEAT:
		workbench.show_feedback("Reajusta el calor: el remache no se fijó y conservas tus oportunidades", Color("e6bf72"))
		_schedule_transition(0.22, _unlock_tool)
		return
	rivet_hits[index] += 1
	GameState.register_forge_action("martillo")
	_set_heat(heat - HEAT_PER_STRIKE)
	workbench.impact_rivet = index
	workbench.impact_flash = 1.0
	gear_sparks.position = workbench.rivet_position(index) + workbench.position
	gear_sparks.restart()
	hammer_audio.pitch_scale = 0.95 + rivet_hits[index] * 0.05
	hammer_audio.play()
	if rivet_hits[index] == HITS_PER_RIVET:
		rivet_index += 1
		workbench.show_feedback("✓ Refuerzo fijado: la cabeza del remache queda plana", Color("bedc95"))
	if rivet_index == REQUIRED_RIVETS:
		_schedule_transition(0.45, _start_cooling)
	else:
		_schedule_transition(0.22, _unlock_tool)
	_sync_workbench()
	_update_ui()


func _unlock_tool() -> void:
	action_locked = false
	workbench.strike_locked = false
	_refresh_rivets()


func _turn_to_next() -> void:
	if forge_stage != STAGE_RIVET or action_locked or rivet_index >= REQUIRED_RIVETS:
		return
	var difference := wrapf(-strike_order[rivet_index] * PI / 2 - workbench.wheel_angle, -PI, PI)
	if absf(difference) <= ALIGN_TOLERANCE:
		return
	action_locked = true
	workbench.strike_locked = true
	var turn := _animation()
	turn.tween_property(workbench, "wheel_angle", workbench.wheel_angle + difference, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	turn.tween_callback(_unlock_tool)
	workbench.show_feedback("La rueda acerca el siguiente refuerzo al martillo")
	_refresh_rivets()


func _move_wheel(angle: float) -> void:
	if not overlay.visible or action_locked or forge_stage != STAGE_RIVET:
		return
	var difference: float = angle - workbench.wheel_angle
	workbench.wheel_angle = angle
	if forge_stage == STAGE_TEST:
		_register_turn(difference)
	_refresh_rivets()


func _start_cooling() -> void:
	if forge_stage != STAGE_RIVET or rivet_index != REQUIRED_RIVETS:
		return
	forge_stage = STAGE_COOL
	action_locked = false
	cooling_elapsed = 0
	danger_seconds = 0
	_release_all_controls()
	_show_stage()


func _start_test() -> void:
	if forge_stage != STAGE_CENTER or not cooling_verified or center_error() > 0.065:
		return
	forge_stage = STAGE_TEST
	action_locked = false
	danger_seconds = 0
	_release_all_controls()
	_show_stage()
	proof_button.grab_focus()


func _register_turn(radians: float) -> void:
	if forge_stage != STAGE_TEST or action_locked or not cooling_verified or radians <= 0:
		return
	if absf(wheel_speed - proof_target()) > 0.28:
		return
	proof_level_radians += radians
	proof_radians = minf(TAU, proof_checks * TAU / 3 + proof_level_radians)
	if proof_level_radians >= TAU / 3:
		proof_checks += 1
		proof_level_radians = 0
		workbench.show_feedback("✓ Nivel de carga %d comprobado" % proof_checks, Color("bedc95"))
		if proof_checks == 3:
			action_locked = true
			_release_all_controls()
			_schedule_transition(0.65, _complete_forge)


func _complete_forge() -> void:
	if forge_stage != STAGE_TEST or awaiting_retry or not parts_placed.all(func(part): return part) or clamps.min() < 1 or center_error() > 0.065 or not cooling_verified or proof_checks != 3 or rivet_index != REQUIRED_RIVETS:
		return
	for count in rivet_hits:
		if count != HITS_PER_RIVET:
			return
	if GameState.complete_wheelwright_forge():
		parts_placed = [true, true, true, true]
		clamps = [1.0, 1.0]
		screws = SCREW_TARGETS.duplicate()
		_present_complete()


func _present_complete() -> void:
	forge_stage = STAGE_COMPLETE
	action_locked = false
	_release_all_controls()
	proof_button.visible = false
	vent_button.visible = false
	tool_controls.visible = false
	continue_button.visible = true
	stage_label.text = "Rueda dentada terminada y comprobada"
	instruction_label.text = "El hierro de las herramientas viejas refuerza una rueda lista para transmitir el movimiento del molino."
	hint_label.text = "Recuperaste un material valioso y comprobaste el trabajo antes de instalarlo. Mateo te entrega la rueda dentada."
	key_hint.text = "Recoge la rueda y llévala al molino"
	_show_stage()
	continue_button.grab_focus()


func _set_heat(value: float) -> void:
	heat = clampf(value, 0, 100)
	workbench.heat = heat


func _refresh_rivets() -> void:
	if forge_stage != STAGE_RIVET:
		return
	strike_button.disabled = action_locked
	rotate_button.disabled = action_locked or _aligned()
	strike_button.text = "Golpear · %d / 3" % rivet_hits[strike_order[mini(rivet_index, 3)]]
	rotate_button.text = "Alinear refuerzo %d" % (strike_order[mini(rivet_index, 3)] + 1)


func _sync_workbench() -> void:
	workbench.stage = [0, 0, 1, 2, 3, 3, 4][forge_stage]
	workbench.allow_proof_drag = forge_stage != STAGE_TEST
	workbench.assembly_visible = forge_stage == STAGE_ASSEMBLE
	workbench.centering_visible = forge_stage == STAGE_CENTER
	workbench.parts_placed = parts_placed.duplicate()
	workbench.center_deviation = center_error() if forge_stage == STAGE_CENTER else 0.0
	workbench.heat = heat
	workbench.hits = rivet_hits.duplicate()
	workbench.active_rivet = strike_order[mini(rivet_index, 3)]
	workbench.strike_locked = action_locked
	workbench.proof_checks = proof_checks
	workbench.proof_progress = proof_radians / TAU
	workbench.wheel_speed = wheel_speed


func _update_ui() -> void:
	attempts_label.text = "Oportunidades: %d / %d" % [int(GameState.flags.get("forge_attempts_left", GameState.get_forge_opportunities())), GameState.get_forge_opportunities()]
	attempts_label.tooltip_text = "Compartidas entre las seis fases. Un error consume una oportunidad y conserva tu avance."
	%HeatSafeBand.visible = forge_stage in [STAGE_HEAT, STAGE_RIVET, STAGE_TEST]
	if forge_stage in [STAGE_HEAT, STAGE_RIVET, STAGE_COOL]:
		heat_bar.value = heat
		heat_value.text = "%d°C · %s" % [roundi(20 + heat * 10.8), "EXCESO" if heat > MAX_WORK_HEAT else "AL ROJO" if heat >= RED_HOT_HEAT else "ENFRIANDO" if forge_stage == STAGE_COOL else "FRÍO"]
		heat_fill_style.bg_color = Color("a5472c").lerp(Color("f4c16a"), heat / 100)
		quality_title.text = "TEMPERATURA DEL HIERRO"
		%HeatSafeBand.position.x = heat_bar.size.x * 0.7
		%HeatSafeBand.size.x = heat_bar.size.x * 0.26
	elif forge_stage == STAGE_CENTER:
		heat_bar.value = clampf(100 - center_error() * 100, 0, 100)
		heat_value.text = "Desvío: %.1f%% · meta 6.5%%" % (center_error() * 100)
		heat_fill_style.bg_color = Color("8bb269")
		quality_title.text = "CENTRADO DEL EJE"
	elif forge_stage == STAGE_TEST:
		heat_bar.value = wheel_speed / 3 * 100
		heat_value.text = "%.1f · objetivo %.1f" % [wheel_speed, proof_target()]
		heat_fill_style.bg_color = Color("8bb269")
		quality_title.text = "VELOCIDAD BAJO CARGA"
		%HeatSafeBand.position.x = heat_bar.size.x * (proof_target() - 0.28) / 3
		%HeatSafeBand.size.x = heat_bar.size.x * 0.56 / 3
	else:
		heat_bar.value = (parts_placed.count(true) / 4.0 * 70 + (clamps[0] + clamps[1]) * 15) if forge_stage == STAGE_ASSEMBLE else 100
		heat_value.text = "%d / 4 piezas · %d / 2 abrazaderas" % [parts_placed.count(true), int(clamps[0] >= 1) + int(clamps[1] >= 1)] if forge_stage == STAGE_ASSEMBLE else "Rueda comprobada"
		quality_title.text = "MONTAJE" if forge_stage == STAGE_ASSEMBLE else "CALIDAD FINAL"
	if awaiting_retry:
		return
	match forge_stage:
		STAGE_ASSEMBLE:
			progress_label.text = "Encaja cuatro refuerzos"
			status_label.text = "Pieza %d · orientación %d°" % [selected_piece + 1, piece_angles[selected_piece] * 90]
			assembly_status.text = "Pieza %d seleccionada · abrazadera %d · confirma solo cuando todas las marcas estén verdes" % [selected_piece + 1, selected_clamp + 1]
		STAGE_HEAT:
			progress_label.text = "Mantén el calor estable"
			status_label.text = "%.1f / 2 s en la zona de trabajo" % heat_ready_seconds if heat <= MAX_WORK_HEAT else "¡Exceso! Ventila con V antes de deformar el hierro"
		STAGE_RIVET:
			progress_label.text = "%d de 4 refuerzos fijados" % rivet_index
			status_label.text = "Martillo en movimiento…" if action_locked else "Alinea, regula el calor y golpea en la zona verde"
		STAGE_COOL:
			progress_label.text = "Enfriamiento uniforme"
			status_label.text = "Ventilación: %d%%\nRitmo: %.1f · objetivo %.1f" % [ventilation_strength, cooling_rate(), cooling_target()]
		STAGE_CENTER:
			progress_label.text = "Ajusta los tres tornillos"
			status_label.text = "Tornillo %d seleccionado\nLleva sus tres marcas a verde" % [selected_screw + 1]
		STAGE_TEST:
			progress_label.text = "%d / 3 cargas comprobadas" % proof_checks
			status_label.text = "Pulsa y suelta para mantener la velocidad en verde"
		STAGE_COMPLETE:
			progress_label.text = "Seis etapas comprobadas"
			status_label.text = "Mateo te entrega la rueda dentada"


func _set_step_rail() -> void:
	_sync_workbench()
	workbench.feedback_seconds = 0.0
	for index in steps.size():
		steps[index].modulate = Color("94c676") if index < forge_stage else Color("efc36c") if index == forge_stage else Color("817b67")


func _release_all_controls() -> void:
	pointer_pump = false
	pointer_vent = false
	pointer_proof = false
	space_held = false
	f_held = false
	left_held = false
	right_held = false
	wheel_speed = 0.0
	workbench.wheel_speed = 0.0
	workbench.ventilating = false
	workbench.release_pointer()
	clamp_hold = false
	hold_adjust = 0
	if is_instance_valid(challenge): challenge.release_pointer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		application_focused = false
		_release_all_controls()
		if pending_rivet >= 0:
			hammer.cancel()
			pending_rivet = -1
			_unlock_tool()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_focused = true


func _schedule_transition(delay: float, callback: Callable) -> void:
	var requested_session := session_id
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self) and overlay.visible and session_id == requested_session:
			callback.call())


func _animation() -> Tween:
	animations = animations.filter(func(tween: Tween): return tween.is_valid())
	var tween := create_tween()
	animations.append(tween)
	return tween


func _stop_animations() -> void:
	for tween in animations:
		if tween.is_valid(): tween.kill()
	animations.clear()


func _fit_panel() -> void:
	if not is_node_ready():
		return
	var available := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var factor := minf(1, minf(available.x / panel.size.x, available.y / panel.size.y))
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2.ONE * maxf(0.1, factor)


func _style_controls() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("734625")
	normal.border_color = Color("ddb05d")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = Color("986037")
	var disabled := normal.duplicate()
	disabled.bg_color = Color("30291f")
	disabled.border_color = Color("67563c")
	for button in [close_button, bellows_button, strike_button, rotate_button, vent_button, proof_button, continue_button, heat_vent] + extra_buttons:
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_color_override("font_disabled_color", Color("b0aa8b"))
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_stylebox_override("disabled", disabled)
	var background := normal.duplicate()
	background.bg_color = Color("14120d")
	background.border_color = Color("6c5633")
	heat_fill_style = StyleBoxFlat.new()
	heat_fill_style.bg_color = Color("ad512b")
	heat_fill_style.set_corner_radius_all(3)
	heat_bar.add_theme_stylebox_override("background", background)
	heat_bar.add_theme_stylebox_override("fill", heat_fill_style)


func _configure_particles() -> void:
	var spark_texture := GradientTexture2D.new()
	var spark_gradient := Gradient.new()
	spark_gradient.colors = PackedColorArray([Color("fff2a1"), Color("ff7b21"), Color(1, 0.1, 0.01, 0)])
	spark_gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	spark_texture.gradient = spark_gradient
	spark_texture.width = 10
	spark_texture.height = 10
	spark_texture.fill = GradientTexture2D.FILL_RADIAL
	spark_texture.fill_from = Vector2(0.5, 0.5)
	spark_texture.fill_to = Vector2(1.0, 0.5)
	for particles in [forge_sparks, gear_sparks]:
		particles.direction = Vector2(0, -1)
		particles.spread = 58.0
		particles.initial_velocity_min = 70.0
		particles.initial_velocity_max = 150.0
		particles.gravity = Vector2(0, 165)
		particles.scale_amount_min = 0.35
		particles.scale_amount_max = 0.9
		particles.texture = spark_texture
		particles.one_shot = true
		particles.explosiveness = 0.92
		particles.lifetime = 0.75


func _configure_audio() -> void:
	bellows_audio.stream = _make_effect_stream(95.0, 0.18, 0.52, false)
	hammer_audio.stream = _make_effect_stream(920.0, 0.22, 0.12, true)


func _make_effect_stream(frequency: float, duration: float, noise_mix: float, metallic: bool) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 731 if metallic else 193
	for index in sample_count:
		var time := float(index) / mix_rate
		var progress := time / duration
		var envelope := pow(1.0 - progress, 2.2 if metallic else 1.2)
		var tone := sin(TAU * frequency * time)
		if metallic:
			tone = tone * 0.62 + sin(TAU * frequency * 1.73 * time) * 0.28 + sin(TAU * frequency * 2.41 * time) * 0.1
		var noise := random.randf_range(-1.0, 1.0)
		var sample := clampf((tone * (1.0 - noise_mix) + noise * noise_mix) * envelope * 0.55, -1.0, 1.0)
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



func rotate_part(turn: int) -> void:
	if forge_stage != STAGE_ASSEMBLE or action_locked or parts_placed[selected_piece]: return
	piece_angles[selected_piece] = posmod(piece_angles[selected_piece] + turn, 4)


func place_part(piece: int, slot: int) -> void:
	if forge_stage != STAGE_ASSEMBLE or action_locked or piece < 0 or piece > 3 or parts_placed[piece]: return
	if piece != slot or piece_angles[piece] != slot:
		_fail_attempt("El refuerzo no encaja con su muesca. Gira la pieza y respeta su número antes de colocarla.")
		return
	parts_placed[piece] = true
	workbench.show_feedback("✓ Refuerzo %d encajado" % (piece + 1), Color("bedc95"))
	for index in range(4):
		if not parts_placed[index]:
			selected_piece = index
			break
	_sync_workbench()
	_update_ui()


func _confirm_assembly() -> void:
	if forge_stage != STAGE_ASSEMBLE or action_locked: return
	if not parts_placed.all(func(part): return part) or clamps.min() < 1:
		_fail_attempt("El montaje no estaba sujeto. Encaja las cuatro piezas y aprieta ambas abrazaderas antes de confirmar.")
		return
	forge_stage = STAGE_HEAT
	_release_all_controls()
	_show_stage()
	bellows_button.grab_focus()


func _start_centering() -> void:
	if forge_stage != STAGE_COOL or not cooling_verified: return
	forge_stage = STAGE_CENTER
	action_locked = false
	_release_all_controls()
	_show_stage()


func adjust_screw(index: int, amount: float) -> void:
	if forge_stage != STAGE_CENTER or action_locked or index < 0 or index > 2: return
	selected_screw = index
	screws[index] = clampf(screws[index] + amount, 0, 1)


func center_error() -> float:
	var error := 0.0
	for index in range(3): error = maxf(error, absf(screws[index] - SCREW_TARGETS[index]))
	return error


func _confirm_center() -> void:
	if forge_stage != STAGE_CENTER or action_locked: return
	if center_error() > 0.065:
		_fail_attempt("El eje quedó descentrado. Ajusta los tres tornillos hasta que sus marcas estén verdes.")
		return
	_start_test()


func precision_value() -> float:
	return (sin(precision_time * 2.4) + 1) / 2


func cooling_rate() -> float:
	return 2 + ventilation_strength * 0.15


func cooling_target() -> float:
	return 6 + sin(cooling_elapsed * 0.45) * 2


func proof_target() -> float:
	return [1.0, 1.25, 1.5][mini(proof_checks, 2)]


func _fail_attempt(reason: String) -> void:
	if awaiting_retry or not overlay.visible or forge_stage == STAGE_COMPLETE: return
	session_id += 1
	_release_all_controls()
	_stop_animations()
	hammer.cancel()
	pending_rivet = -1
	action_locked = true
	awaiting_retry = true
	failure_reason = reason
	var remaining: int = GameState.fail_forge_attempt(reason)
	workbench.impact_flash = 1
	workbench.show_feedback("Corrige este paso: conservas tu avance", Color("f3aa71"))
	retry_panel.visible = true
	retry_label.text = reason + "\n\n" + ("Quedan %d de %d oportunidades. Continúas en esta fase; conservas los pasos y ajustes completados." % [remaining, GameState.get_forge_opportunities()] if remaining > 0 else "Se agotaron las oportunidades de esta ronda. Mateo te espera fuera del taller.")
	retry_button.visible = remaining > 0
	retry_button.text = "Continuar esta fase · %d / %d" % [remaining, GameState.get_forge_opportunities()]
	_update_ui()
	_save_checkpoint()
	if remaining <= 0:
		exhaustion_notice_pending = true
		_schedule_transition(1.65, close)
	else:
		retry_button.grab_focus()


func _retry_attempt() -> void:
	if not awaiting_retry or int(GameState.flags.get("forge_attempts_left", GameState.get_forge_opportunities())) <= 0: return
	_resume_phase(true)
	_focus_stage()


func _resume_phase(recovering: bool) -> void:
	# Only release the failed action. Valid assembly, hits, screws and loads stay intact.
	session_id += 1
	_release_all_controls()
	_stop_animations()
	hammer.cancel()
	pending_rivet = -1
	action_locked = false
	awaiting_retry = false
	retry_panel.visible = false
	danger_seconds = 0
	if recovering:
		pump_cooldown = 0
		seconds_since_pump = 0
		if forge_stage == STAGE_HEAT:
			heat_ready_seconds = 0
		if forge_stage in [STAGE_HEAT, STAGE_RIVET] and heat > MAX_WORK_HEAT:
			_set_heat(START_WORK_HEAT + 3)
		if forge_stage == STAGE_RIVET and heat < RED_HOT_HEAT:
			_set_heat(START_WORK_HEAT + 3)
		if forge_stage == STAGE_COOL:
			ventilation_strength = clampf((cooling_target() - 2) / 0.15, 0, 100)
	cooling_slider.set_value_no_signal(ventilation_strength)
	_show_stage()
	_refresh_rivets()
	# Resume validated transitions if the player closed during their animation.
	if forge_stage == STAGE_RIVET and rivet_index == REQUIRED_RIVETS:
		_start_cooling()
	elif forge_stage == STAGE_COOL and cooling_verified:
		_start_centering()
	elif forge_stage == STAGE_TEST and proof_checks == 3:
		_complete_forge()


func _focus_stage() -> void:
	var target: Control = [assembly_group.get_child(0), bellows_button, strike_button, cooling_slider, center_group.get_child(0), proof_button, continue_button][forge_stage]
	target.grab_focus()


func _save_checkpoint() -> void:
	if not overlay.visible or GameState.flags.get("wheelwright_forge_completed", false): return
	var progress := {"stage": forge_stage, "wheel_angle": workbench.wheel_angle, "recovering": awaiting_retry}
	for field in ["parts_placed", "piece_angles", "clamps", "screws", "rivet_hits", "selected_piece", "selected_clamp", "selected_screw", "heat", "heat_ready_seconds", "rivet_index", "cooling_elapsed", "ventilation_strength", "cooling_verified", "proof_radians", "proof_level_radians", "proof_checks"]:
		var value: Variant = get(field)
		progress[field] = value.duplicate() if value is Array else value
	GameState.flags["forge_progress"] = progress
	GameState.save_progress()


func _restore_checkpoint() -> void:
	var progress: Dictionary = GameState.flags.get("forge_progress", {})
	if progress.is_empty(): return
	var stage: int = int(progress.get("stage", STAGE_ASSEMBLE))
	if stage < STAGE_ASSEMBLE or stage > STAGE_TEST: return
	for entry in [["parts_placed", 4], ["piece_angles", 4], ["clamps", 2], ["screws", 3], ["rivet_hits", 4]]:
		var value: Variant = progress.get(entry[0])
		if not value is Array or value.size() != entry[1]: return
	forge_stage = stage
	for field in ["parts_placed", "piece_angles", "clamps", "screws", "rivet_hits"]:
		set(field, progress[field].duplicate())
	# JSON numbers load as floats; discrete slots and hit counts remain integers.
	piece_angles = piece_angles.map(func(value): return int(value))
	rivet_hits = rivet_hits.map(func(value): return int(value))
	for field in ["selected_piece", "selected_clamp", "selected_screw", "rivet_index", "proof_checks"]:
		set(field, int(progress.get(field, get(field))))
	for field in ["heat", "heat_ready_seconds", "cooling_elapsed", "ventilation_strength", "proof_radians", "proof_level_radians"]:
		set(field, float(progress.get(field, get(field))))
	cooling_verified = bool(progress.get("cooling_verified", false))
	workbench.wheel_angle = float(progress.get("wheel_angle", 0))
	_resume_phase(bool(progress.get("recovering", false)))


func _show_stage() -> void:
	tool_controls.visible = forge_stage in [STAGE_HEAT, STAGE_RIVET]
	bellows_button.visible = tool_controls.visible
	heat_vent.visible = tool_controls.visible
	strike_button.visible = forge_stage == STAGE_RIVET
	rotate_button.visible = forge_stage == STAGE_RIVET
	vent_button.visible = false
	proof_button.visible = forge_stage == STAGE_TEST
	continue_button.visible = forge_stage == STAGE_COMPLETE
	assembly_group.visible = forge_stage == STAGE_ASSEMBLE
	cooling_group.visible = forge_stage == STAGE_COOL
	center_group.visible = forge_stage == STAGE_CENTER
	assembly_status.visible = forge_stage == STAGE_ASSEMBLE
	stage_label.text = ["1. Montar los refuerzos y sujetar la rueda", "2. Mantener el hierro en la zona de trabajo", "3. Remachar con precisión y en lados opuestos", "4. Enfriar de forma uniforme", "5. Centrar el eje con tres tornillos", "6. Probar el giro con tres niveles de carga", "Rueda dentada terminada y comprobada"][forge_stage]
	instruction_label.text = ["Gira y encaja cada pieza según su muesca. Sujeta las dos abrazaderas. Confirmar un montaje incorrecto consume una oportunidad.", "Mantén el calor estable durante 2 segundos. Si se pasa, suelta el fuelle y ventila con V: tienes tiempo para corregir.", "Alinea el remache y conserva el calor. Solo un golpe fuera de la franja verde gasta una oportunidad; tocar otro lado no penaliza.", "Regula la ventilación para seguir la franja verde. Un ritmo incorrecto durante 2 segundos consume una oportunidad.", "Ajusta cada tornillo hasta llevar sus marcas a verde. Confirma solo cuando el comparador marque un eje centrado.", "Pulsa y suelta la manivela para mantener la velocidad en verde. Un exceso sostenido de velocidad hace fallar la prueba.", "Seis etapas superadas. La rueda está lista para transmitir el movimiento al molino."][forge_stage]
	if forge_stage == STAGE_COOL and GameState.is_easy_difficulty():
		instruction_label.text = "Regula la ventilación para seguir la franja verde. Tienes 4 segundos para corregir un ritmo incorrecto antes de gastar una oportunidad."
	hint_label.text = ["Cada refuerzo lleva un número y una muesca. Puedes corregir su orientación antes de colocarlo. Mantén las abrazaderas para apretarlas.", "El fuelle aviva el carbón. La franja verde indica el calor de trabajo; ventilar permite corregir un exceso antes de dañar el hierro.", "Trabaja en orden 1 → 3 → 2 → 4. Ajusta la temperatura antes de golpear y espera la zona verde del indicador.", "La franja se mueve lentamente. Sigue su ritmo con el deslizador o las flechas. Las advertencias permiten corregir antes del fallo.", "Los tres tornillos deben quedar en sus zonas verdes. La oscilación de la rueda disminuye al centrarla.", "La carga aumenta en tres niveles. Soltar frena y permite corregir; la prueba solo avanza a una velocidad estable.", "Mateo conserva el hierro y entrega una sola rueda. Llévala al molino para instalarla."][forge_stage]
	key_hint.text = ["1–4: pieza · Q / R: girar · Espacio: encajar o apretar · también puedes arrastrar", "Espacio / F: fuelle · V: ventilar · suelta para regular", "F: fuelle · V: ventilar · Espacio: golpe · ← →: girar la rueda", "← →: regular ventilación · también puedes usar el deslizador", "1–3: tornillo · ← →: ajustar · Espacio: comprobar el eje", "Mantén y suelta Espacio / → o la manivela para regular la velocidad", "Recoge la rueda y llévala al molino"][forge_stage]
	_set_step_rail()
	_update_ui()
	_save_checkpoint()


func _extra_button(parent: Control, text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	parent.add_child(button)
	extra_buttons.append(button)
	return button


func _build_challenge_controls() -> void:
	var content: Control = panel.get_node("Content")
	attempts_label = Label.new()
	attempts_label.position = Vector2(360, 23)
	attempts_label.size = Vector2(242, 26)
	attempts_label.add_theme_font_size_override("font_size", 14)
	attempts_label.add_theme_color_override("font_color", Color("e6bf72"))
	content.add_child(attempts_label)
	for old_step in content.get_node("StepRail").get_children():
		content.get_node("StepRail").remove_child(old_step)
		old_step.queue_free()
	steps.clear()
	for text in ["1 Montar", "2 Calor", "3 Remaches", "4 Enfriar", "5 Eje", "6 Carga"]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 11)
		label.custom_minimum_size = Vector2(58, 26)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.get_node("StepRail").add_child(label)
		steps.append(label)
	challenge = Control.new()
	challenge.set_script(load("res://scripts/ui/forge_challenge_tools.gd"))
	challenge.puzzle = self
	workbench.add_child(challenge)
	var area: Control = workbench.get_parent()
	assembly_group = Control.new()
	area.add_child(assembly_group)
	_extra_button(assembly_group, "↶ Girar", Rect2(31, 351, 80, 52), rotate_part.bind(-1))
	_extra_button(assembly_group, "↷ Girar", Rect2(118, 351, 80, 52), rotate_part.bind(1))
	_extra_button(assembly_group, "Encajar pieza", Rect2(205, 351, 130, 52), func(): place_part(selected_piece, selected_piece))
	var clamp_button := _extra_button(assembly_group, "Apretar · mantener", Rect2(342, 351, 183, 52), func(): pass)
	clamp_button.button_down.connect(func(): clamp_hold = true)
	clamp_button.button_up.connect(func(): clamp_hold = false)
	_extra_button(assembly_group, "Comprobar montaje", Rect2(532, 351, 211, 52), _confirm_assembly)
	assembly_status = Label.new()
	assembly_status.position = Vector2(31, 330)
	assembly_status.size = Vector2(713, 21)
	assembly_status.add_theme_font_size_override("font_size", 11)
	assembly_status.add_theme_color_override("font_color", Color("d6c297"))
	area.add_child(assembly_status)
	cooling_group = Control.new()
	area.add_child(cooling_group)
	var cool_label := Label.new()
	cool_label.text = "Ventilación"
	cool_label.position = Vector2(45, 367)
	cooling_group.add_child(cool_label)
	cooling_slider = HSlider.new()
	cooling_slider.position = Vector2(155, 354)
	cooling_slider.size = Vector2(565, 46)
	cooling_slider.max_value = 100
	cooling_slider.value = 25
	cooling_slider.value_changed.connect(func(value): ventilation_strength = value)
	cooling_group.add_child(cooling_slider)
	center_group = Control.new()
	area.add_child(center_group)
	for index in range(3):
		_extra_button(center_group, "Tornillo %d" % (index + 1), Rect2(31 + index * 96, 351, 89, 52), func(): selected_screw = index)
	var minus := _extra_button(center_group, "− Aflojar", Rect2(326, 351, 111, 52), func(): pass)
	var plus := _extra_button(center_group, "+ Apretar", Rect2(444, 351, 111, 52), func(): pass)
	minus.button_down.connect(func(): hold_adjust = -1)
	minus.button_up.connect(func(): hold_adjust = 0)
	plus.button_down.connect(func(): hold_adjust = 1)
	plus.button_up.connect(func(): hold_adjust = 0)
	_extra_button(center_group, "Comprobar eje", Rect2(562, 351, 181, 52), _confirm_center)
	tool_controls.add_theme_constant_override("separation", 10)
	bellows_button.custom_minimum_size.x = 150
	strike_button.custom_minimum_size.x = 155
	rotate_button.custom_minimum_size.x = 173
	heat_vent = Button.new()
	heat_vent.text = "Ventilar · V"
	heat_vent.custom_minimum_size = Vector2(140, 52)
	heat_vent.button_down.connect(func(): pointer_vent = true)
	heat_vent.button_up.connect(func(): pointer_vent = false)
	tool_controls.add_child(heat_vent)
	retry_panel = Panel.new()
	retry_panel.position = Vector2(246, 192)
	retry_panel.size = Vector2(544, 250)
	retry_panel.z_index = 50
	var style := StyleBoxFlat.new()
	style.bg_color = Color("16140dfc")
	style.border_color = Color("bc8650")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	retry_panel.add_theme_stylebox_override("panel", style)
	content.add_child(retry_panel)
	var retry_title := Label.new()
	retry_title.text = "Mateo: revisemos el trabajo"
	retry_title.position = Vector2(25, 19)
	retry_title.add_theme_font_size_override("font_size", 22)
	retry_title.add_theme_color_override("font_color", Color("e6bf72"))
	retry_panel.add_child(retry_title)
	retry_label = Label.new()
	retry_label.position = Vector2(25, 60)
	retry_label.size = Vector2(494, 116)
	retry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_label.add_theme_font_size_override("font_size", 16)
	retry_panel.add_child(retry_label)
	retry_button = _extra_button(retry_panel, "Reintentar", Rect2(98, 188, 348, 43), _retry_attempt)
