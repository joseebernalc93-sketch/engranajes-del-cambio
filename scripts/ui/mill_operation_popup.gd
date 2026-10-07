extends CanvasLayer

const MAX_RPM := 80.0
const SAFE_MIN_RPM := 40.0
const SAFE_MAX_RPM := 58.0
const IDEAL_RPM := 49.0
const TRIP_RPM := 69.0
const JAM_RPM := 22.0
const READY_SECONDS := 1.4
const JAM_DELAY := 2.4
const TRIP_DELAY := 1.1
const REQUIRED_BATCHES := 3
const GATE_STEP := 2.0
const GATE_HOLD_RATE := 18.0
const GATE_REPEAT_DELAY := 0.3
const TIE_SECONDS := 1.4
const WHEAT_ICON := preload("res://assets/items/wheat_v2.png")
const FLOUR_ICON := preload("res://assets/items/flour_sack_v1.png")

@onready var overlay: ColorRect = %MillOperationOverlay
@onready var panel: PanelContainer = $MillOperationOverlay/Panel
@onready var workbench = %WorkbenchDisplay
@onready var speed_gauge: Control = %SpeedGauge
@onready var gate_slider: HSlider = %GateSlider
@onready var close_gate_button: Button = %CloseGateButton
@onready var open_gate_button: Button = %OpenGateButton
@onready var flow_value: Label = %FlowValue
@onready var rpm_value: Label = %RpmValue
@onready var load_value: Label = %LoadValue
@onready var stage_label: Label = %StageLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var historical_hint: Label = %HistoricalHint
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var load_button: Button = %LoadButton
@onready var recovery_button: Button = %RecoveryButton
@onready var brake_button: Button = %BrakeButton
@onready var tie_button: Button = %TieButton
@onready var result_button: Button = %ResultButton
@onready var key_hint: Label = %KeyHint
@onready var grain_dust: CPUParticles2D = %GrainDust
@onready var water_mist: CPUParticles2D = %WaterMist

var batch_panels: Array[PanelContainer]
var batch_icons: Array[TextureRect]
var batch_statuses: Array[Label]
var batch_bars: Array[ProgressBar]

var gate_opening := 0.0
var water_flow := 0.0
var rotation_speed := 0.0
var grain_remaining := 0.0
var batches_processed := 0
var processing_batch := false
var jammed := false
var safety_tripped := false
var completed := false
var ready_seconds := 0.0
var low_speed_seconds := 0.0
var high_speed_seconds := 0.0
var stable_seconds := 0.0
var incident_count := 0
var gate_adjustments := 0
var last_recorded_gate := 0.0
var finishing := false
var tie_seconds := 0.0
var space_held := false
var pointer_tie := false
var batch_pending_style: StyleBoxFlat
var batch_active_style: StyleBoxFlat
var batch_done_style: StyleBoxFlat
var stability_fill: StyleBoxFlat
var pointer_gate_direction := 0
var left_held := false
var right_held := false
var gate_repeat_delay := 0.0
var held_gate_fraction := 0.0
var player_was_enabled := true
var water_audio: AudioStreamPlayer
var mechanism_audio: AudioStreamPlayer
var audio_focused := true


func _ready() -> void:
	batch_panels = [%BatchOne, %BatchTwo, %BatchThree]
	batch_icons = [%BatchOneIcon, %BatchTwoIcon, %BatchThreeIcon]
	batch_statuses = [%BatchOneStatus, %BatchTwoStatus, %BatchThreeStatus]
	batch_bars = [%BatchOneBar, %BatchTwoBar, %BatchThreeBar]
	EventBus.mill_operation_requested.connect(open)
	%CloseButton.pressed.connect(close)
	gate_slider.value_changed.connect(_on_gate_changed)
	close_gate_button.button_down.connect(_hold_gate.bind(-1))
	open_gate_button.button_down.connect(_hold_gate.bind(1))
	close_gate_button.button_up.connect(_release_pointer_gate)
	open_gate_button.button_up.connect(_release_pointer_gate)
	load_button.pressed.connect(_load_next_batch)
	recovery_button.pressed.connect(_recover_mechanism)
	brake_button.pressed.connect(func(): _adjust_gate(-100.0))
	tie_button.button_down.connect(func(): pointer_tie = true)
	tie_button.button_up.connect(func(): pointer_tie = false)
	result_button.pressed.connect(close)
	workbench.gate_changed.connect(func(value: float):
		if overlay.visible and not completed:
			gate_slider.value = value)
	workbench.load_requested.connect(_load_next_batch)
	workbench.tie_requested.connect(func(pressed: bool): pointer_tie = pressed)
	_style_controls()
	_configure_particles()
	_configure_audio()
	_reset_minigame()
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel.call_deferred()
	set_process(true)


func _process(delta: float) -> void:
	if not overlay.visible:
		return
	_update_gate_controls(delta)
	_update_hydraulics(delta)
	_update_animation(delta)
	if finishing and not completed:
		if (space_held or pointer_tie) and _can_tie():
			tie_seconds = minf(TIE_SECONDS, tie_seconds + delta)
			if tie_seconds >= TIE_SECONDS:
				_complete_milling()
	elif not completed:
		_update_operation(delta)
	_update_interface()
	_update_audio()


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		_release_pointer_gate()
		pointer_tie = false
		var local_pos: Vector2 = workbench.get_global_transform_with_canvas().affine_inverse() * event.position
		workbench.release_pointer(local_pos)
	if not event is InputEventKey:
		return
	if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
		if not event.echo and not completed:
			var is_left: bool = event.keycode in [KEY_LEFT, KEY_A]
			var was_held := left_held if is_left else right_held
			if is_left:
				left_held = event.pressed
			else:
				right_held = event.pressed
			if event.pressed and not was_held and left_held != right_held:
				gate_repeat_delay = GATE_REPEAT_DELAY
				held_gate_fraction = 0.0
				_adjust_gate(-GATE_STEP if is_left else GATE_STEP)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_SPACE:
		space_held = event.pressed and finishing and not completed
		if event.pressed and not event.echo:
			if finishing:
				pass
			elif jammed or safety_tripped:
				_recover_mechanism()
			else:
				_load_next_batch()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_I:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		audio_focused = false
		_release_gate_controls()
		if is_node_ready():
			workbench.cancel_drag()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		audio_focused = true


func _hold_gate(direction: int) -> void:
	if not overlay.visible or completed:
		return
	pointer_gate_direction = direction
	gate_repeat_delay = GATE_REPEAT_DELAY
	held_gate_fraction = 0.0
	_adjust_gate(direction * GATE_STEP)


func _release_pointer_gate() -> void:
	pointer_gate_direction = 0
	held_gate_fraction = 0.0


func _release_gate_controls() -> void:
	_release_pointer_gate()
	left_held = false
	right_held = false
	gate_repeat_delay = 0.0
	space_held = false
	pointer_tie = false


func _update_gate_controls(delta: float) -> void:
	if completed:
		return
	var direction := signi(pointer_gate_direction + int(right_held) - int(left_held))
	if direction == 0:
		return
	var step_delta := clampf(delta, 0.0, 0.1)
	var held_delta := maxf(0.0, step_delta - gate_repeat_delay)
	gate_repeat_delay = maxf(0.0, gate_repeat_delay - step_delta)
	# Accumulate fractional movement because the slider advances in whole percent.
	held_gate_fraction += direction * GATE_HOLD_RATE * held_delta
	var adjustment := int(held_gate_fraction)
	if adjustment != 0:
		held_gate_fraction -= adjustment
		_adjust_gate(float(adjustment))


func _adjust_gate(amount: float) -> void:
	if not overlay.visible or completed:
		return
	gate_slider.value = clampf(gate_opening + amount, 0.0, 100.0)


func open() -> void:
	if overlay.visible:
		return
	if not GameState.flags.get("mill_repaired", false):
		EventBus.show_toast("Primero debes reparar el mecanismo del molino")
		return
	if not GameState.flags.get("flour_milled", false) and not GameState.has_item("trigo", REQUIRED_BATCHES):
		EventBus.show_toast("Necesitas tres puñados de trigo para preparar el costal")
		return
	var player = get_tree().get_first_node_in_group("player")
	player_was_enabled = player.controls_enabled if player else true
	_reset_minigame()
	overlay.visible = true
	workbench.active = true
	_set_player_controls(false)
	_fit_panel()
	open_gate_button.grab_focus()
	if GameState.flags.get("flour_milled", false):
		completed = true
		finishing = true
		batches_processed = REQUIRED_BATCHES
		tie_seconds = TIE_SECONDS
		_update_interface()


func close() -> void:
	if not overlay.visible:
		return
	_release_gate_controls()
	workbench.active = false
	workbench.cancel_drag()
	overlay.visible = false
	grain_dust.emitting = false
	water_mist.emitting = false
	water_audio.stop()
	mechanism_audio.stop()
	_set_player_controls(player_was_enabled)


func _reset_minigame() -> void:
	_release_gate_controls()
	gate_opening = 0.0
	water_flow = 0.0
	rotation_speed = 0.0
	grain_remaining = 0.0
	batches_processed = 0
	processing_batch = false
	jammed = false
	safety_tripped = false
	completed = false
	finishing = false
	tie_seconds = 0.0
	ready_seconds = 0.0
	low_speed_seconds = 0.0
	high_speed_seconds = 0.0
	stable_seconds = 0.0
	incident_count = 0
	gate_adjustments = 0
	last_recorded_gate = 0.0
	workbench.reset_machine()
	gate_slider.set_value_no_signal(0.0)
	gate_slider.editable = true
	%CloseButton.text = "X"
	historical_hint.text = "La compuerta regula el caudal. El agua impulsa la rueda y los engranajes transmiten el giro a las piedras."
	_update_interface()


func _on_gate_changed(value: float) -> void:
	gate_opening = value
	if absf(gate_opening - last_recorded_gate) >= 4.0:
		gate_adjustments += 1
		last_recorded_gate = gate_opening
	_update_interface()


func _update_hydraulics(delta: float) -> void:
	var gate_ratio := gate_opening / 100.0
	water_flow = pow(gate_ratio, 1.35) * 72.0
	var grinding_resistance := 18.0 if processing_batch else 0.0
	var target_rpm := clampf(water_flow * 1.05 - grinding_resistance, 0.0, MAX_RPM)
	if jammed or safety_tripped:
		target_rpm = 0.0
	var inertia_rate := 7.0 if target_rpm > rotation_speed else 5.5
	if finishing and gate_opening <= 2.0:
		inertia_rate = 12.0
	rotation_speed = move_toward(rotation_speed, target_rpm, inertia_rate * delta)
	if completed:
		rotation_speed = move_toward(rotation_speed, 0.0, 9.0 * delta)


func _update_operation(delta: float) -> void:
	if jammed or safety_tripped:
		ready_seconds = 0.0
		return
	if not processing_batch:
		if _rpm_is_safe():
			ready_seconds = minf(READY_SECONDS, ready_seconds + delta)
		else:
			ready_seconds = maxf(0.0, ready_seconds - delta * 1.8)
		if rotation_speed >= TRIP_RPM:
			high_speed_seconds += delta
			if high_speed_seconds >= TRIP_DELAY:
				_trip_safety()
		else:
			high_speed_seconds = maxf(0.0, high_speed_seconds - delta * 2.0)
		return

	if _rpm_is_safe():
		var precision := 1.0 - clampf(absf(rotation_speed - IDEAL_RPM) / (SAFE_MAX_RPM - IDEAL_RPM), 0.0, 1.0)
		var grind_rate := lerpf(0.115, 0.19, precision)
		grain_remaining = maxf(0.0, grain_remaining - grind_rate * delta)
		stable_seconds += delta
		low_speed_seconds = maxf(0.0, low_speed_seconds - delta * 2.0)
		high_speed_seconds = maxf(0.0, high_speed_seconds - delta * 2.0)
	elif rotation_speed < JAM_RPM:
		low_speed_seconds += delta
		high_speed_seconds = 0.0
		if low_speed_seconds >= JAM_DELAY:
			_trigger_jam()
	elif rotation_speed >= TRIP_RPM:
		high_speed_seconds += delta
		low_speed_seconds = 0.0
		if high_speed_seconds >= TRIP_DELAY:
			_trip_safety()
	else:
		low_speed_seconds = maxf(0.0, low_speed_seconds - delta)
		high_speed_seconds = maxf(0.0, high_speed_seconds - delta)
	if grain_remaining <= 0.0:
		_finish_batch()


func _load_next_batch() -> void:
	if not overlay.visible or completed or finishing or jammed or safety_tripped or processing_batch or ready_seconds < READY_SECONDS:
		return
	processing_batch = true
	grain_remaining = 1.0
	ready_seconds = 0.0
	low_speed_seconds = 0.0
	high_speed_seconds = 0.0
	historical_hint.text = "El grano añade resistencia: abre un poco más la compuerta para recuperar las revoluciones sin exceder el límite."
	workbench.load_age = 0.0
	_update_interface()


func _trigger_jam() -> void:
	jammed = true
	processing_batch = false
	incident_count += 1
	low_speed_seconds = 0.0
	recovery_button.text = "Levantar piedra y liberar tolva"
	historical_hint.text = "Con poco giro, el grano se acumula entre las piedras. Cierra el agua y espera a que el eje se detenga antes de liberarlo."
	EventBus.show_toast("Tolva atascada: detén el molino para liberarla")


func _trip_safety() -> void:
	safety_tripped = true
	processing_batch = false
	incident_count += 1
	high_speed_seconds = 0.0
	recovery_button.text = "Rearmar transmisión"
	historical_hint.text = "El exceso de velocidad activó el seguro. Cierra totalmente la compuerta y espera a que la rueda se detenga."
	EventBus.show_toast("Seguro activado por exceso de velocidad")


func _recover_mechanism() -> void:
	if not overlay.visible:
		return
	if not jammed and not safety_tripped:
		return
	if gate_opening > 2.0 or rotation_speed > 7.0:
		EventBus.show_toast("Cierra la compuerta y espera a que la rueda se detenga")
		return
	var had_grain := grain_remaining > 0.0
	jammed = false
	safety_tripped = false
	processing_batch = had_grain
	low_speed_seconds = 0.0
	high_speed_seconds = 0.0
	historical_hint.text = "Mecanismo recuperado. Abre la compuerta gradualmente para volver a la zona de trabajo."
	_update_interface()


func _finish_batch() -> void:
	if not overlay.visible or not processing_batch or finishing or completed:
		return
	batches_processed += 1
	processing_batch = false
	grain_remaining = 0.0
	ready_seconds = 0.0
	low_speed_seconds = 0.0
	high_speed_seconds = 0.0
	if batches_processed >= REQUIRED_BATCHES:
		finishing = true
		_release_gate_controls()
		historical_hint.text = "El costal está lleno. Detén el eje antes de retirarlo y ata su boca para proteger la harina durante el viaje."
	else:
		historical_hint.text = "Tanda terminada. Al desaparecer la carga, la rueda acelera: reduce el caudal y vuelve a estabilizarla."
		EventBus.show_toast("Puñado %d de %d convertido en harina" % [batches_processed, REQUIRED_BATCHES])


func _complete_milling() -> void:
	if not overlay.visible or not finishing or not _can_tie() or tie_seconds < TIE_SECONDS or completed:
		return
	completed = GameState.complete_mill_operation(stable_seconds, incident_count, gate_adjustments)
	if not completed:
		return
	gate_slider.set_value_no_signal(0.0)
	gate_opening = 0.0
	gate_slider.editable = false
	_release_gate_controls()
	processing_batch = false
	grain_remaining = 0.0
	%CloseButton.text = "Cerrar"
	historical_hint.text = "El control del caudal permitió convertir la energía del agua en una molienda continua y uniforme."
	_update_interface()


func _can_tie() -> bool:
	return finishing and gate_opening <= 2.0 and rotation_speed <= 0.8


func _rpm_is_safe() -> bool:
	return rotation_speed >= SAFE_MIN_RPM and rotation_speed <= SAFE_MAX_RPM


func _batch_progress() -> float:
	return 0.0 if not processing_batch and grain_remaining <= 0.0 else 1.0 - grain_remaining


func _update_interface() -> void:
	flow_value.text = "%d%%  ·  %.1f L/s" % [roundi(gate_opening), water_flow]
	rpm_value.text = "%d rpm" % roundi(rotation_speed)
	load_value.text = "Piedras con carga" if processing_batch else "Piedras sin carga"
	speed_gauge.set_reading(rotation_speed, safety_tripped)
	var readiness := ready_seconds / READY_SECONDS * 100.0
	stability_bar.value = tie_seconds / TIE_SECONDS * 100.0 if finishing else _batch_progress() * 100.0 if processing_batch else readiness
	if stability_fill:
		stability_fill.bg_color = Color("72a85a") if _rpm_is_safe() else (Color("b94b35") if rotation_speed >= TRIP_RPM else Color("c68a39"))
	_refresh_batches()
	var can_recover := (jammed or safety_tripped) and gate_opening <= 2.0 and rotation_speed <= 7.0
	recovery_button.visible = jammed or safety_tripped
	recovery_button.disabled = not can_recover
	load_button.visible = not jammed and not safety_tripped and not finishing
	load_button.disabled = completed or processing_batch or ready_seconds < READY_SECONDS
	load_button.text = "Moliendo tanda %d…" % (batches_processed + 1) if processing_batch else "Cargar puñado %d de %d" % [min(batches_processed + 1, REQUIRED_BATCHES), REQUIRED_BATCHES]
	gate_slider.editable = not completed
	close_gate_button.disabled = completed or gate_opening <= 0.0
	open_gate_button.disabled = completed or gate_opening >= 100.0
	brake_button.visible = not completed
	brake_button.disabled = gate_opening <= 0.0
	tie_button.visible = finishing and not completed
	tie_button.disabled = not _can_tie()
	tie_button.text = "Atando costal · %d%%" % roundi(tie_seconds / TIE_SECONDS * 100.0) if tie_seconds > 0.0 else "Mantener para atar costal"
	result_button.visible = completed
	key_hint.text = "Arrastra el trigo a la tolva o pulsa Cargar / ESPACIO · ← → / A D regulan el agua"
	%StatusLabel.text = "CAUDAL → RUEDA → ENGRANAJES → PIEDRAS → HARINA"
	%StepRail.text = "› Caudal   Molienda   Frenar   Costal" if not processing_batch and batches_processed == 0 else "✓ Caudal   › Molienda   Frenar   Costal"
	grain_dust.emitting = processing_batch and _rpm_is_safe()
	water_mist.emitting = water_flow > 7.0 and rotation_speed > 4.0
	if completed:
		stage_label.text = "Costal de harina terminado"
		instruction_label.text = "Las tres tandas están molidas y el costal está atado. Llévalo a Tomás para reunir el dinero del viaje."
		key_hint.text = "✓ Tres tandas molidas · ✓ Eje detenido · ✓ Costal protegido"
		%StepRail.text = "✓ Caudal   ✓ Molienda   ✓ Frenar   ✓ Costal"
		%StatusLabel.text = "COSTAL TERMINADO · HARINA LISTA PARA LLEVAR A TOMÁS"
		load_button.text = "3 de 3 tandas completadas"
		load_button.disabled = true
	elif finishing:
		stage_label.text = "3. Detener el molino y asegurar el costal"
		instruction_label.text = "Mantén el costal, su botón o ESPACIO para cerrar y atar su boca." if _can_tie() else "Cierra la compuerta y espera a que el eje se detenga antes de retirar la harina."
		key_hint.text = "Mantén el costal o ESPACIO · el avance de la ligadura se conserva al soltar"
		%StepRail.text = "✓ Caudal   ✓ Molienda   ✓ Frenar   › Costal" if _can_tie() else "✓ Caudal   ✓ Molienda   › Frenar   Costal"
		%StatusLabel.text = "LIGADURA %d%% · COSTAL LLENO" % roundi(tie_seconds / TIE_SECONDS * 100.0) if _can_tie() else "COSTAL LLENO · EL EJE TODAVÍA ESTÁ EN MOVIMIENTO"
	elif safety_tripped:
		stage_label.text = "Seguro de transmisión activado"
		instruction_label.text = "Cierra la compuerta al 0%, espera a llegar a 0 rpm y rearma la transmisión."
	elif jammed:
		stage_label.text = "Tolva y piedras atascadas"
		instruction_label.text = "Detén por completo la rueda antes de retirar el grano acumulado."
	elif processing_batch:
		stage_label.text = "2. Moler la cosecha · tanda %d de %d" % [batches_processed + 1, REQUIRED_BATCHES]
		if _rpm_is_safe():
			instruction_label.text = "Molienda uniforme: mantén la aguja dentro del arco verde."
		elif rotation_speed < SAFE_MIN_RPM:
			instruction_label.text = "La carga frenó las piedras. Abre gradualmente la compuerta para recuperar fuerza."
		else:
			instruction_label.text = "Las piedras giran demasiado rápido. Reduce el caudal para no activar el seguro."
	else:
		stage_label.text = "1. Estabilizar el mecanismo" if batches_processed == 0 else "Preparar la siguiente tanda"
		if ready_seconds >= READY_SECONDS:
			instruction_label.text = "Rueda estable y tolva libre. Ya puedes cargar el siguiente puñado."
		elif rotation_speed < SAFE_MIN_RPM:
			instruction_label.text = "Abre la compuerta con los botones, las flechas o el deslizador hasta llevar la aguja al arco verde."
		else:
			instruction_label.text = "Reduce el caudal y mantén la velocidad estable antes de cargar grano."
	_sync_machine()


func _refresh_batches() -> void:
	for index in REQUIRED_BATCHES:
		var panel := batch_panels[index]
		var icon := batch_icons[index]
		var status := batch_statuses[index]
		var bar := batch_bars[index]
		if index < batches_processed:
			panel.add_theme_stylebox_override("panel", batch_done_style)
			icon.texture = FLOUR_ICON
			status.text = "Harina"
			status.add_theme_color_override("font_color", Color("9bd17e"))
			bar.value = 100.0
		elif index == batches_processed and processing_batch:
			panel.add_theme_stylebox_override("panel", batch_active_style)
			icon.texture = WHEAT_ICON
			status.text = "%d%%" % roundi(_batch_progress() * 100.0)
			status.add_theme_color_override("font_color", Color("f2c45e"))
			bar.value = _batch_progress() * 100.0
		else:
			panel.add_theme_stylebox_override("panel", batch_pending_style)
			icon.texture = WHEAT_ICON
			status.text = "Listo" if index == batches_processed else "Espera"
			status.add_theme_color_override("font_color", Color("b7ad98"))
			bar.value = 0.0


func _update_animation(delta: float) -> void:
	workbench.wheel_angle += rotation_speed / 60.0 * TAU * delta
	workbench.load_age += delta
	workbench.time += delta
	workbench.queue_redraw()


func _sync_machine() -> void:
	workbench.gate = gate_opening
	workbench.rpm = rotation_speed
	workbench.flow = water_flow
	workbench.grain = grain_remaining
	workbench.batches = batches_processed
	workbench.grinding = processing_batch and _rpm_is_safe()
	workbench.jammed = jammed
	workbench.tripped = safety_tripped
	workbench.can_load = not load_button.disabled and load_button.visible
	workbench.finishing = finishing
	workbench.can_tie = _can_tie() and not completed
	workbench.tie = tie_seconds / TIE_SECONDS
	workbench.completed = completed


func _style_controls() -> void:
	var action := StyleBoxFlat.new()
	action.bg_color = Color("895126")
	action.border_color = Color("e0ad52")
	action.set_border_width_all(3)
	action.set_corner_radius_all(4)
	var hover := action.duplicate()
	hover.bg_color = Color("ad682e")
	hover.border_color = Color("ffd27a")
	var disabled := action.duplicate()
	disabled.bg_color = Color("292722")
	disabled.border_color = Color("5d5547")
	for button in [load_button, recovery_button, close_gate_button, open_gate_button, brake_button, tie_button, result_button, %CloseButton]:
		button.add_theme_stylebox_override("normal", action)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_stylebox_override("disabled", disabled)
		button.add_theme_color_override("font_color", Color("f8e7c1"))
		button.add_theme_color_override("font_disabled_color", Color("8d877b"))
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("171513")
	bar_background.border_color = Color("65523a")
	bar_background.set_border_width_all(2)
	bar_background.set_corner_radius_all(4)
	stability_fill = StyleBoxFlat.new()
	stability_fill.bg_color = Color("c68a39")
	stability_fill.set_corner_radius_all(3)
	stability_bar.add_theme_stylebox_override("background", bar_background)
	stability_bar.add_theme_stylebox_override("fill", stability_fill)
	batch_pending_style = StyleBoxFlat.new()
	batch_pending_style.bg_color = Color("171815")
	batch_pending_style.border_color = Color("50483b")
	batch_pending_style.set_border_width_all(2)
	batch_pending_style.set_corner_radius_all(4)
	batch_active_style = batch_pending_style.duplicate()
	batch_active_style.bg_color = Color("3a2b17")
	batch_active_style.border_color = Color("d39c43")
	batch_done_style = batch_pending_style.duplicate()
	batch_done_style.bg_color = Color("21341f")
	batch_done_style.border_color = Color("77a75f")
	for bar in batch_bars:
		bar.add_theme_stylebox_override("background", bar_background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("d1a64d")
		fill.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fill)


func _configure_particles() -> void:
	grain_dust.direction = Vector2(1, -0.2)
	grain_dust.spread = 28.0
	grain_dust.initial_velocity_min = 18.0
	grain_dust.initial_velocity_max = 42.0
	grain_dust.gravity = Vector2(0, 34)
	grain_dust.scale_amount_min = 0.25
	grain_dust.scale_amount_max = 0.65
	water_mist.direction = Vector2(-0.4, -1)
	water_mist.spread = 52.0
	water_mist.initial_velocity_min = 20.0
	water_mist.initial_velocity_max = 55.0
	water_mist.gravity = Vector2(0, 28)
	water_mist.scale_amount_min = 0.22
	water_mist.scale_amount_max = 0.55


func _set_player_controls(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.controls_enabled = enabled


func _configure_audio() -> void:
	water_audio = AudioStreamPlayer.new()
	mechanism_audio = AudioStreamPlayer.new()
	add_child(water_audio)
	add_child(mechanism_audio)
	water_audio.stream = _make_loop(true)
	mechanism_audio.stream = _make_loop(false)


func _update_audio() -> void:
	if not audio_focused or not overlay.visible:
		water_audio.stop()
		mechanism_audio.stop()
		return
	if water_flow > 1.0:
		water_audio.volume_db = lerpf(-34.0, -24.0, water_flow / 72.0)
		if not water_audio.playing:
			water_audio.play()
	else:
		water_audio.stop()
	if rotation_speed > 1.0:
		mechanism_audio.volume_db = lerpf(-34.0, -24.0, rotation_speed / MAX_RPM)
		mechanism_audio.pitch_scale = clampf(rotation_speed / IDEAL_RPM, 0.4, 1.6)
		if not mechanism_audio.playing:
			mechanism_audio.play()
	else:
		mechanism_audio.stop()


func _make_loop(water: bool) -> AudioStreamWAV:
	var mix_rate := 22050
	var samples := mix_rate * 2
	var data := PackedByteArray()
	data.resize(samples * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 619 if water else 173
	var filtered := 0.0
	for index in samples:
		var t := float(index) / mix_rate
		filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), 0.17)
		var envelope := minf(1.0, minf(t * 40.0, (2.0 - t) * 40.0))
		var sample := filtered * (0.8 + sin(t * TAU * 2) * 0.12) if water else sin(t * TAU * 73) * 0.11 + filtered * pow(maxf(0.0, sin(t * TAU * 6)), 12) * 0.5
		data.encode_s16(index * 2, int(clampf(sample * envelope, -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	return stream


func _fit_panel() -> void:
	var available := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var factor := minf(1.0, minf(available.x / 1088.0, available.y / 614.0))
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * maxf(0.1, factor)
