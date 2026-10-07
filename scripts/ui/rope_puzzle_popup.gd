extends CanvasLayer

const STAGE_PREPARE := 0
const STAGE_COMB := 1
const STAGE_STRANDS := 2
const STAGE_TENSION := 3
const STAGE_FINISH := 4
const STAGE_PROOF := 5
const STAGE_COMPLETE := 6

const REQUIRED_CLEAN_FIBERS := 3
const REQUIRED_BRAID_STEPS := 3
const REQUIRED_TWISTS := 5
const SAFE_TENSION_MIN := 45.0
const SAFE_TENSION_MAX := 70.0
const CRITICAL_TENSION := 82.0
const TWIST_RATE := 9.0
const PROOF_HOLD_SECONDS := 2.5
const RETRY_NOTICE := preload("res://scripts/ui/workshop_retry_notice.gd")

@onready var overlay: ColorRect = %RopeOverlay
@onready var close_button: Button = %CloseButton
@onready var stage_label: Label = %StageLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel

@onready var machine_texture: TextureRect = %MachineTexture
@onready var machine_shade: ColorRect = %MachineShade
@onready var machine_display = %MachineDisplay
@onready var tension_meter = %TensionMeter
@onready var carriage_safe_band: ColorRect = %CarriageSafeBand
@onready var continue_button: Button = %ContinueButton
@onready var proof_button: Button = %ProofButton
@onready var panel: PanelContainer = $RopeOverlay/Panel
@onready var rope_progress_bar: ProgressBar = %RopeProgressBar
@onready var preparation_container: GridContainer = %PreparationContainer
@onready var strand_container: HBoxContainer = %StrandContainer
@onready var tension_container: Control = %TensionContainer
@onready var finish_container: HBoxContainer = %FinishContainer

@onready var hemp_long: Button = %HempLong
@onready var dry_straw: Button = %DryStraw
@onready var hemp_flexible: Button = %HempFlexible
@onready var knotted_fiber: Button = %KnottedFiber
@onready var hemp_clean: Button = %HempClean
@onready var wet_waste: Button = %WetWaste

@onready var hook_top: Button = %HookTop
@onready var hook_middle: Button = %HookMiddle
@onready var hook_bottom: Button = %HookBottom

@onready var carriage_slider: HSlider = %CarriageSlider
@onready var safe_zone_label: Label = %SafeZoneLabel
@onready var crank_button: Button = %CrankButton
@onready var tension_title: Label = %TensionTitle
@onready var tension_bar: ProgressBar = %TensionBar
@onready var tension_value: Label = %TensionValue

@onready var loose_knot: Button = %LooseKnot
@onready var seizing_knot: Button = %SeizingKnot
@onready var cut_loose: Button = %CutLoose

@onready var step_prepare: Label = %StepPrepare
@onready var step_strands: Label = %StepStrands
@onready var step_tension: Label = %StepTension
@onready var step_finish: Label = %StepFinish

@onready var fiber_dust: CPUParticles2D = %FiberDust
@onready var action_audio: AudioStreamPlayer = %ActionAudio
@onready var mechanism_audio: AudioStreamPlayer = %MechanismAudio
@onready var opportunities_label: Label = %OpportunitiesLabel
@onready var craft_display = %CraftDisplay
@onready var comb_container: Control = %CombContainer
@onready var comb_button: Button = %CombButton
@onready var bundle_buttons: Array[Button] = [%BundleOne, %BundleTwo, %BundleThree]
@onready var feed_slider: HSlider = %FeedSlider
@onready var feed_controls: Control = %FeedControls
@onready var feed_label: Label = %FeedLabel
@onready var binding_button: Button = %BindingButton
@onready var proof_controls: Control = %ProofControls
@onready var proof_brake_slider: HSlider = %ProofBrakeSlider

var stage := STAGE_PREPARE
var cleaned_fibers := 0
var mounted_strands := 0
var braid_step := 0
var twist_count := 0
var twist_progress := 0.0
var tension := 0.0
var stable_seconds := 0.0
var mistakes := 0
var crank_held := false
var action_locked := false
var overload_timer := 0.0
var tension_zone := ""
var session_id := 0
var work_clock := 0.0
var brake_cooldown := 0.0
var left_held := false
var right_held := false
var keyboard_crank := false
var pointer_crank := false
var player_was_enabled := true
var status_tween: Tween
var proof_held := false
var proof_keyboard_held := false
var proof_pointer_held := false
var proof_force := 0.0
var proof_seconds := 0.0
var proof_checks := 0
var comb_passes: Array = [0, 0, 0]
var selected_bundle := 0
var timing_clock := 0.0
var binding_started := false
var binding_wraps := 0
var proof_danger := 0.0
var material_selected: Array = [false, false, false, false, false, false]
var restoring_work := false
var awaiting_retry := false
var retry_notice: Control


func _ready() -> void:
	retry_notice = RETRY_NOTICE.new()
	panel.get_node("Content").add_child(retry_notice)
	retry_notice.artisan = "Silas"
	retry_notice.continued.connect(_continue_current_phase)
	EventBus.rope_puzzle_requested.connect(open)
	close_button.pressed.connect(close)
	continue_button.pressed.connect(close)
	proof_button.button_down.connect(_hold_proof_pointer)
	proof_button.button_up.connect(_release_proof_pointer)
	comb_button.pressed.connect(func(): _perform_precision(craft_display.cursor))
	binding_button.pressed.connect(func(): _perform_precision(craft_display.cursor))
	craft_display.precision_requested.connect(_perform_precision)
	for index in 3:
		bundle_buttons[index].pressed.connect(_select_bundle.bind(index))
	feed_slider.value_changed.connect(func(_value: float): _update_feed_label())
	machine_display.hook_selected.connect(_on_machine_hook)
	machine_display.crank_pressed.connect(_hold_pointer_crank)
	machine_display.carriage_moved.connect(func(value: float): carriage_slider.value = value)
	get_viewport().size_changed.connect(_fit_panel)

	hemp_long.pressed.connect(_on_material_pressed.bind(hemp_long, true, "Las fibras largas repartirán bien la carga."))
	dry_straw.pressed.connect(_on_material_pressed.bind(dry_straw, false, "La paja seca se quiebra al torcerla; debe retirarse."))
	hemp_flexible.pressed.connect(_on_material_pressed.bind(hemp_flexible, true, "La flexibilidad permite torcer sin romper las fibras."))
	knotted_fiber.pressed.connect(_on_material_pressed.bind(knotted_fiber, false, "Los nudos crean puntos débiles y una tensión desigual."))
	hemp_clean.pressed.connect(_on_material_pressed.bind(hemp_clean, true, "Este manojo está limpio y listo para formar un cabo."))
	wet_waste.pressed.connect(_on_material_pressed.bind(wet_waste, false, "La humedad pudre la fibra y reduce su resistencia."))

	hook_top.pressed.connect(_on_hook_pressed.bind(hook_top, "superior"))
	hook_middle.pressed.connect(_on_hook_pressed.bind(hook_middle, "central"))
	hook_bottom.pressed.connect(_on_hook_pressed.bind(hook_bottom, "inferior"))

	carriage_slider.value_changed.connect(_on_carriage_changed)
	crank_button.button_down.connect(_hold_pointer_crank)
	crank_button.button_up.connect(_release_pointer_crank)

	loose_knot.pressed.connect(_on_finish_pressed.bind(loose_knot, false, "El nudo simple puede deslizarse bajo una carga continua."))
	seizing_knot.pressed.connect(_on_finish_pressed.bind(seizing_knot, true, "La ligadura inmoviliza el extremo sin deformar los cabos."))
	cut_loose.pressed.connect(_on_finish_pressed.bind(cut_loose, false, "Si se corta sin asegurar, la torsión se deshace desde el extremo."))

	_style_controls()
	_configure_particles()
	_configure_audio()
	_reset_minigame()
	_fit_panel.call_deferred()


func _process(delta: float) -> void:
	if not overlay.visible or awaiting_retry:
		return
	_sync_machine()
	if stage == STAGE_COMB or (stage == STAGE_FINISH and binding_started):
		if not action_locked:
			timing_clock += delta * GameState.get_forge_indicator_speed()
			if not craft_display.dragging:
				craft_display.cursor = (sin(timing_clock * 2.4) + 1.0) * 0.5
			craft_display.queue_redraw()
		return
	if stage == STAGE_PROOF:
		if not action_locked:
			_process_proof(delta)
		return
	if stage != STAGE_TENSION or action_locked:
		return
	var pace := GameState.get_forge_indicator_speed()
	work_clock += delta * pace
	brake_cooldown = maxf(0.0, brake_cooldown - delta)
	var direction := float(int(right_held) - int(left_held))
	if not is_zero_approx(direction):
		carriage_slider.value = clampf(carriage_slider.value + direction * 28.0 * delta * (0.5 if GameState.is_easy_difficulty() else 1.0), 0, 100)

	var target_tension := float(carriage_slider.value) + (_working_load() if crank_held else -12.0)
	tension = move_toward(tension, clampf(target_tension, 0.0, 100.0), delta * 34.0 * (0.5 if GameState.is_easy_difficulty() else 1.0))

	if crank_held:
		_animate_mechanism()
		if tension >= SAFE_TENSION_MIN and tension <= SAFE_TENSION_MAX:
			stable_seconds += delta
			twist_progress = minf(100.0, twist_progress + delta * TWIST_RATE)
			status_label.text = "Torsión uniforme. ¡Así se unen los cabos!"
			overload_timer = 0.0
			_register_twist_milestones()
		elif tension < SAFE_TENSION_MIN:
			status_label.text = "Cuerda floja: aleja el carro de la rueda →"
			overload_timer = 0.0
		else:
			status_label.text = "Demasiada tensión: acerca el carro a la rueda ←"
			if tension >= CRITICAL_TENSION:
				overload_timer += delta
				if overload_timer >= _correction_seconds():
					overload_timer = 0.0
					_register_mistake("La cuerda estuvo demasiado tensa. Acerca el carro a la rueda antes de volver a girar; la torsión correcta se conserva.")
					if not overlay.visible:
						return
					brake_cooldown = 1.0
					keyboard_crank = false
					pointer_crank = false
					_set_cranking(false)
					machine_display.warning_flash = 1.0
					machine_display.show_feedback("Silas frena la rueda: afloja el carro", Color("f4aa7c"))
	else:
		status_label.text = "Freno de seguridad: acerca el carro" if brake_cooldown > 0.0 else "Mantén ESPACIO o la rueda para girar"
		overload_timer = 0.0

	_update_tension_ui()
	if twist_progress >= 100.0 and not action_locked:
		action_locked = true
		_set_cranking(false)
		_schedule_transition(0.65, _start_finish_stage)
	_sync_machine()


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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		craft_display.release_grip()
		_release_pointer_crank()
		_release_proof_pointer()
		machine_display.dragging_carriage = false
	if event.is_action_pressed("inventory"):
		# Keep Tab available for focus navigation, but don't open another modal with I.
		if not (event is InputEventKey and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB)):
			get_viewport().set_input_as_handled()
	if event is InputEventKey and not action_locked:
		var craft_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if (stage == STAGE_COMB or (stage == STAGE_FINISH and binding_started)) and craft_key in [KEY_SPACE, KEY_1, KEY_2, KEY_3]:
			if event.pressed and not event.echo:
				if craft_key == KEY_SPACE:
					_perform_precision(craft_display.cursor)
				elif stage == STAGE_COMB:
					_select_bundle(craft_key - KEY_1)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and stage in [STAGE_TENSION, STAGE_PROOF]:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if stage == STAGE_PROOF:
			if key in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
				if not event.echo:
					if key in [KEY_LEFT, KEY_A]:
						left_held = event.pressed
					else:
						right_held = event.pressed
				get_viewport().set_input_as_handled()
			if key == KEY_SPACE:
				if not event.echo:
					proof_keyboard_held = event.pressed
					_set_testing(proof_keyboard_held or proof_pointer_held)
				get_viewport().set_input_as_handled()
			return
		if key in [KEY_SPACE, KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
			if not event.echo:
				match key:
					KEY_SPACE:
						keyboard_crank = event.pressed
						_set_cranking(keyboard_crank or pointer_crank)
					KEY_LEFT, KEY_A:
						left_held = event.pressed
					KEY_RIGHT, KEY_D:
						right_held = event.pressed
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_release_all_controls()


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if overlay.visible:
		return
	if GameState.flags.get("rope_puzzle_completed", false):
		return
	if GameState.get_rope_attempts_left() <= 0:
		GameState.show_rope_encouragement()
		return
	var player = get_tree().get_first_node_in_group("player")
	player_was_enabled = player.controls_enabled if player else true
	_reset_minigame()
	overlay.visible = true
	_restore_work()
	machine_display.active = true
	_fit_panel()
	_set_player_controls(false)
	_refresh_opportunities()
	_focus_stage()


func close() -> void:
	if not overlay.visible:
		return
	_save_work()
	session_id += 1
	_release_all_controls()
	awaiting_retry = false
	retry_notice.hide()
	machine_display.active = false
	machine_display.wheel_speed = 0.0
	fiber_dust.emitting = false
	action_audio.stop()
	overlay.visible = false
	_set_player_controls(player_was_enabled)


func _reset_minigame() -> void:
	awaiting_retry = false
	retry_notice.hide()
	session_id += 1
	_release_all_controls()
	machine_display.reset_machine()
	if status_tween and status_tween.is_running():
		status_tween.kill()
	status_label.modulate = Color.WHITE
	tension_value.modulate = Color.WHITE
	work_clock = 0.0
	brake_cooldown = 0.0
	proof_force = 0.0
	proof_seconds = 0.0
	proof_checks = 0
	comb_passes = [0, 0, 0]
	selected_bundle = 0
	timing_clock = 0.0
	binding_started = false
	binding_wraps = 0
	proof_danger = 0.0
	material_selected = [false, false, false, false, false, false]
	stage = STAGE_PREPARE
	cleaned_fibers = 0
	mounted_strands = 0
	braid_step = 0
	twist_count = 0
	twist_progress = 0.0
	tension = 0.0
	stable_seconds = 0.0
	mistakes = 0
	crank_held = false
	action_locked = false
	overload_timer = 0.0
	tension_zone = ""

	stage_label.text = "1. Seleccionar y limpiar el cáñamo"
	instruction_label.text = "Selecciona solo las fibras largas, flexibles y limpias de cáñamo. Elegir un material que debilite la cuerda consume una oportunidad."
	progress_label.text = "0 de %d manojos útiles" % REQUIRED_CLEAN_FIBERS
	status_label.text = "Examina los seis materiales"
	hint_label.text = "El cáñamo largo y flexible soporta mejor la torsión que la paja seca."
	close_button.text = "X"

	preparation_container.visible = true
	strand_container.visible = false
	tension_container.visible = false
	finish_container.visible = false
	comb_container.visible = false
	craft_display.visible = false
	craft_display.dragging = false
	feed_controls.visible = false
	binding_button.visible = false
	proof_controls.visible = false
	feed_slider.value = 35
	proof_brake_slider.value = 30
	continue_button.visible = false
	proof_button.visible = false
	proof_button.disabled = false
	tension_meter.visible = false
	tension_bar.visible = true
	tension_value.position.y = 397.0
	var meter_fill := StyleBoxFlat.new()
	meter_fill.bg_color = Color("6fac50")
	meter_fill.set_corner_radius_all(2)
	tension_bar.add_theme_stylebox_override("fill", meter_fill)
	tension_value.add_theme_font_size_override("font_size", 13)
	rope_progress_bar.visible = false
	rope_progress_bar.value = 0.0
	machine_shade.color = Color(0.03, 0.02, 0.01, 0.08)
	machine_texture.position = Vector2(2, 2)
	machine_texture.scale = Vector2.ONE
	machine_texture.modulate = Color.WHITE
	hemp_long.text = "🌿 Cáñamo largo"
	dry_straw.text = "Paja quebradiza"
	hemp_flexible.text = "🌿 Cáñamo flexible"
	knotted_fiber.text = "Fibras anudadas"
	hemp_clean.text = "🌿 Cáñamo limpio"
	wet_waste.text = "Restos húmedos"
	hook_top.text = "Montar cabo superior"
	hook_middle.text = "Montar cabo central"
	hook_bottom.text = "Montar cabo inferior"
	loose_knot.text = "Nudo simple"
	seizing_knot.text = "Ligadura de remate"
	cut_loose.text = "Cortar sin asegurar"

	for button in _material_buttons() + _hook_buttons() + _finish_buttons():
		button.disabled = false
		button.modulate = Color.WHITE
	crank_button.disabled = false
	crank_button.text = "GIRAR MANIVELA\nMantén ESPACIO"
	carriage_slider.value = 28.0
	tension_bar.value = 0.0
	tension_title.text = "SELECCIÓN DE FIBRAS"
	tension_value.text = "0/%d fibras limpias" % REQUIRED_CLEAN_FIBERS
	_set_step_rail()
	_sync_machine()
	_refresh_opportunities()


func _on_material_pressed(button: Button, useful: bool, explanation: String) -> void:
	if stage != STAGE_PREPARE or button.disabled or action_locked:
		return
	button.disabled = true
	if useful:
		material_selected[_material_buttons().find(button)] = true
		cleaned_fibers += 1
		machine_display.fibers = cleaned_fibers
		machine_display.show_feedback("+ Manojo limpio y preparado", Color("c5df99"))
		GameState.register_rope_action("fiber_cleaned")
		button.text = "✓  %s" % button.text.replace("🌿 ", "")
		button.modulate = Color("b9e58d")
		status_label.text = explanation
		progress_label.text = "%d de %d manojos útiles" % [cleaned_fibers, REQUIRED_CLEAN_FIBERS]
		tension_bar.value = (float(cleaned_fibers) / REQUIRED_CLEAN_FIBERS) * 100.0
		tension_value.text = "%d/%d fibras limpias" % [cleaned_fibers, REQUIRED_CLEAN_FIBERS]
		_emit_fiber_feedback(Color("d9bd6a"))
		if cleaned_fibers >= REQUIRED_CLEAN_FIBERS:
			action_locked = true
			status_label.text = "Cáñamo limpio: ya puedes formar los tres cabos"
			_schedule_transition(0.65, _start_combing_stage)
	else:
		button.disabled = false
		button.modulate = Color("d98262")
		status_label.text = explanation
		_register_mistake()
		if not overlay.visible:
			return
		_pulse_status(Color("e69b58"))
		machine_display.show_feedback("Impureza retirada", Color("f2b47e"))

	action_audio.pitch_scale = randf_range(0.94, 1.08)
	action_audio.play()
	_save_work()


func _start_strand_stage() -> void:
	if stage != STAGE_COMB or not overlay.visible:
		return
	stage = STAGE_STRANDS
	action_locked = false
	stage_label.text = "3. Igualar el grosor y montar los tres cabos"
	instruction_label.text = "Regula la cantidad de fibra en la franja verde y fija cada cabo en su gancho. Los tres deben tener un grosor uniforme."
	progress_label.text = "0 de %d cabos montados" % REQUIRED_BRAID_STEPS
	status_label.text = "Elige cualquiera de los tres ganchos"
	hint_label.text = "Cada cabo debe tener un grosor semejante para que ninguno soporte más fuerza que los demás."
	tension_title.text = "CABOS MONTADOS"
	tension_bar.value = 0.0
	tension_value.text = "0/%d cabos preparados" % REQUIRED_BRAID_STEPS
	preparation_container.visible = false
	comb_container.visible = false
	craft_display.visible = false
	feed_controls.visible = true
	strand_container.visible = true
	machine_shade.color = Color(0.02, 0.015, 0.01, 0.04)
	machine_texture.modulate = Color.WHITE
	_set_step_rail()
	hook_top.grab_focus()
	_update_feed_label()
	_sync_machine()
	_save_work()


func _on_hook_pressed(button: Button, hook_name: String) -> void:
	if stage != STAGE_STRANDS or button.disabled or action_locked:
		return
	if absf(feed_slider.value - 60.0) > (10.0 if GameState.is_easy_difficulty() else 4.0):
		status_label.text = "Este cabo no tiene el grosor de referencia. Regula la cantidad de fibra."
		_register_mistake()
		return
	button.disabled = true
	button.text = "✓ Cabo %s" % hook_name
	button.modulate = Color("b9e58d")
	mounted_strands += 1
	var hook_index := _hook_buttons().find(button)
	machine_display.mounted[hook_index] = true
	machine_display.show_feedback("Cabo %s tendido" % hook_name, Color("e8d297"))
	braid_step = mounted_strands
	GameState.register_rope_action("braid_step")
	progress_label.text = "%d de %d cabos montados" % [mounted_strands, REQUIRED_BRAID_STEPS]
	tension_bar.value = (float(mounted_strands) / REQUIRED_BRAID_STEPS) * 100.0
	tension_value.text = "%d/%d cabos preparados" % [mounted_strands, REQUIRED_BRAID_STEPS]
	status_label.text = "Cabo %s fijado con tensión inicial" % hook_name
	_emit_fiber_feedback(Color("f0d18a"))
	fiber_dust.position = machine_display.position + Vector2(182, 89 + hook_index * 25)
	action_audio.pitch_scale = 0.92 + mounted_strands * 0.06
	action_audio.play()
	if mounted_strands >= REQUIRED_BRAID_STEPS:
		action_locked = true
		status_label.text = "Los tres cabos están alineados con la guía"
		_schedule_transition(0.65, _start_tension_stage)
	_save_work()


func _start_tension_stage() -> void:
	if stage != STAGE_STRANDS or not overlay.visible:
		return
	stage = STAGE_TENSION
	action_locked = false
	stage_label.text = "4. Girar la rueda y encontrar el equilibrio"
	instruction_label.text = "Mantén ESPACIO para girar y ajusta el carro con ← → o el ratón. Conserva la aguja en la zona verde (45–70)."
	progress_label.text = "0% de cuerda torcida"
	status_label.text = "El carro está demasiado cerca: desplázalo"
	hint_label.text = "La rueda aporta torsión; el carro móvil mantiene los cabos estirados mientras se unen."
	tension_title.text = "TENSIÓN DE LA CUERDA"
	strand_container.visible = false
	feed_controls.visible = false
	tension_container.visible = true
	rope_progress_bar.visible = true
	tension_meter.visible = true
	tension_bar.visible = false
	tension_value.position.y = 423.0
	machine_shade.color = Color.TRANSPARENT
	carriage_slider.value = 28.0
	_update_tension_ui()
	_set_step_rail()
	carriage_slider.grab_focus()
	_sync_machine()
	_save_work()


func _on_carriage_changed(_value: float) -> void:
	if stage == STAGE_TENSION:
		safe_zone_label.text = "Carro: %d — %s" % [int(carriage_slider.value), _carriage_hint()]


func _set_cranking(pressed: bool) -> void:
	crank_held = pressed and overlay.visible and stage == STAGE_TENSION and not action_locked and brake_cooldown <= 0.0
	machine_display.driving = crank_held
	if not crank_held:
		mechanism_audio.stop()
	if is_instance_valid(crank_button):
		crank_button.text = "GIRANDO…\n←  Regula el carro  →" if crank_held else "GIRAR MANIVELA\nMantén ESPACIO"


func _hold_pointer_crank() -> void:
	pointer_crank = true
	_set_cranking(true)


func _release_pointer_crank() -> void:
	pointer_crank = false
	_set_cranking(keyboard_crank)


func _release_all_controls() -> void:
	keyboard_crank = false
	pointer_crank = false
	left_held = false
	right_held = false
	_set_cranking(false)
	proof_keyboard_held = false
	proof_pointer_held = false
	_set_testing(false)
	machine_display.dragging_carriage = false
	craft_display.dragging = false


func _register_twist_milestones() -> void:
	var reached := mini(REQUIRED_TWISTS, int(floor(twist_progress / (100.0 / REQUIRED_TWISTS))))
	while twist_count < reached:
		twist_count += 1
		GameState.register_rope_action("rope_twist")
		_emit_fiber_feedback(Color("f4c85b"))
		machine_display.show_feedback(["Los cabos empiezan a unirse", "La cuerda toma forma", "La torsión reparte la carga", "¡Ya casi está! Mantén el equilibrio", "Torsión completa: asegura el extremo"][twist_count - 1], Color("cfe7a4"))
	progress_label.text = "%d%% de cuerda torcida" % int(twist_progress)


func _update_tension_ui() -> void:
	tension_bar.value = tension
	tension_meter.value = tension
	rope_progress_bar.value = twist_progress
	var next_zone := "safe"
	if tension < SAFE_TENSION_MIN:
		next_zone = "low"
		tension_value.text = "%d%% — FLOJA" % int(tension)
	elif tension > SAFE_TENSION_MAX:
		next_zone = "high"
		tension_value.text = "%d%% — EXCESIVA" % int(tension)
	else:
		tension_value.text = "%d%% — ESTABLE" % int(tension)
	if next_zone != tension_zone:
		tension_zone = next_zone
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(2)
		match tension_zone:
			"low":
				fill.bg_color = Color("b58a38")
				tension_value.modulate = Color("e9c46a")
			"high":
				fill.bg_color = Color("b84d3f")
				tension_value.modulate = Color("ef806d")
			_:
				fill.bg_color = Color("6fac50")
				tension_value.modulate = Color("a8df85")
		tension_bar.add_theme_stylebox_override("fill", fill)
	safe_zone_label.text = "Carro: %d — %s" % [int(carriage_slider.value), _carriage_hint()]
	var slider_width := carriage_slider.size.x - 16.0
	carriage_safe_band.position.x = 8.0 + slider_width * clampf((SAFE_TENSION_MIN - _working_load()) / 100.0, 0.0, 1.0)
	carriage_safe_band.size.x = slider_width * (SAFE_TENSION_MAX - SAFE_TENSION_MIN) / 100.0


func _carriage_hint() -> String:
	var working_tension := carriage_slider.value + _working_load()
	if working_tension < SAFE_TENSION_MIN:
		return "aleja el carro →"
	if working_tension > SAFE_TENSION_MAX:
		return "← acerca el carro"
	return "posición de trabajo"


func _working_load() -> float:
	# The growing twist shortens the rope: a small correction becomes necessary.
	return 10.0 + twist_progress * 0.10 + sin(work_clock * 1.8) * 2.0


func _animate_mechanism() -> void:
	if not mechanism_audio.playing:
		mechanism_audio.play()
	mechanism_audio.pitch_scale = 0.82 + tension * 0.004


func _start_finish_stage() -> void:
	if stage != STAGE_TENSION or not overlay.visible:
		return
	_release_all_controls()
	stage = STAGE_FINISH
	action_locked = false
	tension = 62.0
	stage_label.text = "5. Asegurar el extremo con una ligadura firme"
	instruction_label.text = "Elige el acabado que evita que los cabos se separen bajo carga. Un remate incorrecto consume una oportunidad."
	progress_label.text = "Cuerda torcida al 100%"
	status_label.text = "Selecciona el remate adecuado"
	hint_label.text = "Una ligadura de remate abraza el extremo y conserva la torsión conseguida en la cordelería."
	tension_title.text = "TORSIÓN CONSERVADA"
	tension_container.visible = false
	tension_meter.visible = false
	tension_bar.visible = true
	tension_value.position.y = 397.0
	finish_container.visible = true
	rope_progress_bar.visible = true
	rope_progress_bar.value = 100.0
	_update_tension_ui()
	_set_step_rail()
	loose_knot.grab_focus()
	_sync_machine()
	_save_work()


func _on_finish_pressed(button: Button, correct: bool, explanation: String) -> void:
	if stage != STAGE_FINISH or button.disabled or action_locked:
		return
	button.disabled = true
	if not correct:
		button.disabled = false
		button.modulate = Color("d98262")
		status_label.text = explanation
		_register_mistake()
		_pulse_status(Color("e69b58"))
		machine_display.warning_flash = 0.5
		machine_display.loose_end_flash = 1.0
		machine_display.show_feedback("El extremo necesita una ligadura", Color("edab7a"))
		return
	button.text = "✓ Ligadura asegurada"
	button.modulate = Color("b9e58d")
	status_label.text = explanation
	binding_started = true
	finish_container.visible = false
	binding_button.visible = true
	craft_display.visible = true
	craft_display.mode = "bind"
	instruction_label.text = "Da tres vueltas de ligadura. Pulsa ESPACIO en la franja verde o arrastra el hilo y suéltalo en esa zona."
	status_label.text = "Aprieta cada vuelta sin estrangular la cuerda."
	progress_label.text = "%d de 3 vueltas firmes" % binding_wraps
	_sync_machine()
	binding_button.grab_focus()
	_emit_fiber_feedback(Color("ffe08a"))
	action_audio.pitch_scale = 1.2
	action_audio.play()
	_save_work()


func _start_proof_stage() -> void:
	if stage != STAGE_FINISH or not overlay.visible:
		return
	_release_all_controls()
	stage = STAGE_PROOF
	action_locked = false
	proof_force = 0.0
	proof_seconds = 0.0
	proof_checks = 0
	proof_danger = 0.0
	tension = 18.0
	carriage_slider.value = 45.0
	stage_label.text = "6. Probar la cuerda con tres cargas progresivas"
	instruction_label.text = "Mantén ESPACIO para levantar el saco. Regula el freno con ← → o el deslizador y conserva la aguja en verde al aumentar la carga."
	progress_label.text = "0 de 3 comprobaciones"
	status_label.text = "La ligadura está lista. Ahora aplica una carga."
	hint_label.text = "La carga pone a prueba el conjunto: fibras limpias, cabos uniformes y un remate que no se desliza."
	tension_title.text = "CARGA DE PRUEBA"
	finish_container.visible = false
	binding_button.visible = false
	craft_display.visible = false
	proof_controls.visible = true
	proof_brake_slider.value = 30
	proof_button.visible = true
	proof_button.grab_focus()
	tension_bar.visible = false
	tension_meter.visible = true
	tension_value.position.y = 423.0
	tension_value.modulate = Color("e9c46a")
	tension_value.text = "Saco apoyado"
	tension_meter.value = tension
	rope_progress_bar.value = 0.0
	machine_display.show_feedback("Remate listo. ¡Vamos a probarlo!", Color("d9e9ad"))
	_set_step_rail()
	_sync_machine()
	_save_work()


func _hold_proof_pointer() -> void:
	proof_pointer_held = true
	_set_testing(true)


func _release_proof_pointer() -> void:
	proof_pointer_held = false
	_set_testing(proof_keyboard_held)


func _set_testing(pressed: bool) -> void:
	proof_held = pressed and overlay.visible and stage == STAGE_PROOF and not action_locked
	proof_button.text = "SOSTENIENDO LA CARGA…\nMantén para comprobar la cuerda" if proof_held else "LEVANTAR EL SACO DE PRUEBA\nMantén ESPACIO o este botón"


func _process_proof(delta: float) -> void:
	var pace := GameState.get_forge_indicator_speed()
	work_clock += delta * pace
	var direction := float(int(right_held) - int(left_held))
	proof_brake_slider.value = clampf(proof_brake_slider.value + direction * delta * 28 * (0.5 if GameState.is_easy_difficulty() else 1.0), 0, 100)
	var response := 0.5 if GameState.is_easy_difficulty() else 1.0
	proof_force = move_toward(proof_force, 1.0 if proof_held else 0.0, delta * 0.85 * response)
	var load_tension := 62.0 + proof_checks * 9.0 - (proof_brake_slider.value - 50.0) * 0.65 + sin(work_clock * 1.8) * 2.0
	tension = move_toward(tension, lerpf(18.0, load_tension, proof_force), delta * 34.0 * response)
	var safe := tension >= SAFE_TENSION_MIN and tension <= SAFE_TENSION_MAX
	if proof_held and proof_force >= 0.95 and safe:
		proof_seconds = minf(PROOF_HOLD_SECONDS, proof_seconds + delta)
		status_label.text = "La cuerda sostiene el saco. Continúa un momento."
		proof_danger = 0.0
	elif proof_held and proof_force >= 0.95:
		status_label.text = "Regula el freno: más freno reduce la tensión; menos freno la aumenta."
		proof_danger += delta
		if proof_danger >= _correction_seconds():
			proof_seconds = float(proof_checks) * PROOF_HOLD_SECONDS / 3.0
			proof_force = 0.0
			proof_danger = 0.0
			_release_all_controls()
			_register_mistake()
			if not overlay.visible:
				return
			machine_display.show_feedback("Carga apoyada: ajusta el freno y continúa", Color("edab7a"))
	elif proof_held:
		status_label.text = "El saco se eleva: los cabos comparten la carga."
	else:
		status_label.text = "Mantén para levantar el saco y continuar la prueba."
		proof_danger = 0.0
	var reached := mini(3, int(floor(proof_seconds / PROOF_HOLD_SECONDS * 3.0)))
	if reached > proof_checks:
		proof_checks = reached
		var checks := ["La ligadura no se desliza", "Los tres cabos reparten la carga", "¡La cuerda ha superado la prueba!"]
		machine_display.show_feedback(checks[proof_checks - 1], Color("d9e9ad"))
		action_audio.pitch_scale = 1.0 + proof_checks * 0.12
		action_audio.play()
		_save_work()
	progress_label.text = "%d de 3 comprobaciones" % proof_checks
	tension_meter.value = tension
	tension_value.text = "%d%% · carga %d / 3" % [int(tension), mini(3, proof_checks + 1)]
	tension_value.modulate = Color("a8df85") if safe else Color("e9c46a")
	rope_progress_bar.value = proof_seconds / PROOF_HOLD_SECONDS * 100.0
	if proof_seconds >= PROOF_HOLD_SECONDS:
		action_locked = true
		_release_all_controls()
		proof_button.disabled = true
		proof_button.text = "✓ PRUEBA SUPERADA"
		status_label.text = "¡Resiste! Silas comprueba la ligadura."
		_schedule_transition(0.65, _complete_rope_puzzle)
	_sync_machine()


func _complete_rope_puzzle() -> void:
	if stage != STAGE_PROOF or not overlay.visible or proof_seconds < PROOF_HOLD_SECONDS:
		return
	stage = STAGE_COMPLETE
	action_locked = false
	stage_label.text = "Cuerda de cáñamo resistente terminada"
	instruction_label.text = "La torsión uniforme y la ligadura mantienen unidos los cabos. Ya puedes instalarla en las poleas del molino."
	progress_label.text = "Trabajo terminado"
	status_label.text = "Silas te entrega la cuerda"
	hint_label.text = "La resistencia no proviene de una sola fibra, sino de muchas fibras que comparten la carga."
	tension_title.text = "CUERDA TERMINADA"
	finish_container.visible = false
	proof_controls.visible = false
	proof_button.visible = false
	tension_meter.visible = false
	tension_bar.visible = true
	tension_value.position.y = 397.0
	continue_button.visible = true
	continue_button.grab_focus()
	rope_progress_bar.visible = false
	tension_bar.value = 100.0
	tension_value.text = "3 comprobaciones superadas"
	tension_value.add_theme_font_size_override("font_size", 12)
	machine_display.show_feedback("Ligadura firme. ¡Buen trabajo!", Color("d9e9ad"))
	GameState.metrics["rope_stable_seconds"] = float(GameState.metrics.get("rope_stable_seconds", 0.0)) + stable_seconds
	GameState.complete_rope_puzzle()
	_set_step_rail()
	_pulse_status(Color("a8df85"))
	_sync_machine()


func _register_mistake(reason: String = "") -> void:
	if not overlay.visible or awaiting_retry or GameState.get_rope_attempts_left() <= 0:
		return
	var explanation := reason if not reason.is_empty() else status_label.text
	mistakes += 1
	GameState.fail_rope_attempt()
	_release_all_controls()
	mechanism_audio.stop()
	_refresh_opportunities()
	_save_work()
	if GameState.get_rope_attempts_left() <= 0:
		close()
		GameState.show_rope_encouragement()
		return
	awaiting_retry = true
	action_locked = true
	machine_display.active = false
	machine_display.wheel_speed = 0
	craft_display.active = false
	fiber_dust.emitting = false
	retry_notice.show_error(explanation, GameState.get_rope_attempts_left(), GameState.get_rope_opportunities())


func _continue_current_phase() -> void:
	if not awaiting_retry or not overlay.visible:
		return
	_release_all_controls()
	awaiting_retry = false
	action_locked = false
	retry_notice.hide()
	machine_display.active = true
	overload_timer = 0
	proof_danger = 0
	_sync_machine()
	_focus_stage()


func _emit_fiber_feedback(color: Color) -> void:
	fiber_dust.position = Vector2(randf_range(270.0, 510.0), randf_range(195.0, 270.0))
	fiber_dust.modulate = color
	fiber_dust.amount = 18 + mini(28, cleaned_fibers * 4 + mounted_strands * 5)
	fiber_dust.restart()


func _set_step_rail() -> void:
	var labels := [step_prepare, %StepComb, step_strands, step_tension, step_finish, %StepProof]
	var active_step := mini(stage, STAGE_PROOF)
	for index in labels.size():
		var label := labels[index] as Label
		if stage == STAGE_COMPLETE or index < active_step:
			label.modulate = Color("8fc96b")
		elif index == active_step:
			label.modulate = Color("f2c45c")
		else:
			label.modulate = Color(0.48, 0.47, 0.42, 0.8)


func _material_buttons() -> Array[Button]:
	return [hemp_long, dry_straw, hemp_flexible, knotted_fiber, hemp_clean, wet_waste]


func _hook_buttons() -> Array[Button]:
	return [hook_top, hook_middle, hook_bottom]


func _finish_buttons() -> Array[Button]:
	return [loose_knot, seizing_knot, cut_loose]


func _pulse_status(color: Color) -> void:
	if status_tween and status_tween.is_running():
		status_tween.kill()
	status_label.modulate = color
	status_tween = create_tween()
	status_tween.tween_property(status_label, "modulate", Color.WHITE, 0.42)


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

	for button in [close_button, crank_button, continue_button, proof_button, comb_button, binding_button] + bundle_buttons + _material_buttons() + _hook_buttons() + _finish_buttons():
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_color_override("font_disabled_color", Color("f1e6c9"))
		button.add_theme_stylebox_override("normal", action)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_stylebox_override("disabled", disabled)


func _configure_particles() -> void:
	var fiber_texture := GradientTexture2D.new()
	var fiber_gradient := Gradient.new()
	fiber_gradient.colors = PackedColorArray([Color("ffe2a0"), Color("b58434"), Color(0.4, 0.25, 0.1, 0)])
	fiber_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	fiber_texture.gradient = fiber_gradient
	fiber_texture.width = 9
	fiber_texture.height = 3
	fiber_dust.texture = fiber_texture
	fiber_dust.direction = Vector2(0, -1)
	fiber_dust.spread = 75.0
	fiber_dust.initial_velocity_min = 45.0
	fiber_dust.initial_velocity_max = 105.0
	fiber_dust.gravity = Vector2(0, 145)
	fiber_dust.scale_amount_min = 0.35
	fiber_dust.scale_amount_max = 1.0
	fiber_dust.lifetime = 0.72
	fiber_dust.one_shot = true
	fiber_dust.explosiveness = 0.85


func _configure_audio() -> void:
	action_audio.stream = _make_workshop_sound(265.0, 0.15, 0.55)
	var mechanism := _make_workshop_sound(105.0, 0.4, 0.28)
	mechanism.loop_mode = AudioStreamWAV.LOOP_FORWARD
	mechanism.loop_end = int(0.4 * mechanism.mix_rate)
	mechanism_audio.stream = mechanism
	mechanism_audio.volume_db = -17.0
	action_audio.volume_db = -12.0


func _make_workshop_sound(frequency: float, duration: float, noise_mix: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = int(frequency * 29.0)
	for index in sample_count:
		var time := float(index) / mix_rate
		var progress := time / duration
		var envelope := sin(PI * progress) * (1.0 - progress * 0.25)
		var tone := sin(TAU * frequency * time) * 0.38
		var noise := random.randf_range(-1.0, 1.0)
		var sample := clampf((tone * (1.0 - noise_mix) + noise * noise_mix) * envelope * 0.48, -1.0, 1.0)
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


func _sync_machine() -> void:
	machine_display.stage = [0, 0, 1, 2, 3, 4, 5][stage]
	machine_display.tension = tension
	machine_display.progress = twist_progress
	machine_display.driving = crank_held
	machine_display.carriage_target = carriage_slider.value
	machine_display.proof_load = proof_force
	machine_display.proof_checks = proof_checks
	machine_display.difficulty_pace = GameState.get_forge_indicator_speed()
	craft_display.active = overlay.visible and not action_locked and not awaiting_retry
	craft_display.green_min = 0.30 if GameState.is_easy_difficulty() else 0.38
	craft_display.green_max = 0.75 if GameState.is_easy_difficulty() else 0.62
	craft_display.bundle = selected_bundle
	craft_display.passes = comb_passes
	craft_display.wraps = binding_wraps
	craft_display.mode = "comb" if stage == STAGE_COMB else "bind" if stage == STAGE_FINISH and binding_started else ""
	machine_display.craft_mode = craft_display.mode
	craft_display.queue_redraw()


func _on_machine_hook(index: int) -> void:
	var names := ["superior", "central", "inferior"]
	_on_hook_pressed(_hook_buttons()[index], names[index])


func _schedule_transition(delay: float, callback: Callable) -> void:
	var requested_session := session_id
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self) and overlay.visible and requested_session == session_id:
			callback.call()
	)


func _fit_panel() -> void:
	if not is_node_ready():
		return
	var available := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var factor := minf(1.0, minf(available.x / panel.size.x, available.y / panel.size.y))
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * maxf(0.1, factor)


func _start_combing_stage() -> void:
	if stage != STAGE_PREPARE or not overlay.visible:
		return
	stage = STAGE_COMB
	action_locked = false
	craft_display.cursor = 0.5
	preparation_container.visible = false
	comb_container.visible = true
	craft_display.visible = true
	stage_label.text = "2. Peinar y alinear los tres manojos"
	instruction_label.text = "Selecciona un manojo (1–3). Haz dos pasadas: pulsa ESPACIO cuando el rastrillo esté en verde o arrástralo y suéltalo allí."
	hint_label.text = "El rastrillo retira las fibras cortas y alinea las largas para formar cabos uniformes. Conservas las pasadas correctas."
	tension_title.text = "FIBRAS ALINEADAS"
	_select_bundle(selected_bundle)
	_set_step_rail()
	_sync_machine()
	_save_work()


func _select_bundle(index: int) -> void:
	if stage != STAGE_COMB or action_locked or index < 0 or index > 2:
		return
	selected_bundle = index
	for item in 3:
		bundle_buttons[item].text = "Manojo %d · %d/2" % [item + 1, int(comb_passes[item])]
		bundle_buttons[item].modulate = Color("b9e58d") if int(comb_passes[item]) == 2 else Color("f2c45c") if item == index else Color.WHITE
	comb_button.disabled = int(comb_passes[index]) >= 2
	status_label.text = "Manojo %d: %d de 2 pasadas" % [index + 1, int(comb_passes[index])]
	var total := int(comb_passes[0]) + int(comb_passes[1]) + int(comb_passes[2])
	progress_label.text = "%d de 6 pasadas limpias" % total
	tension_value.text = "%d / 6 pasadas" % total
	tension_bar.value = total / 6.0 * 100.0
	_sync_machine()


func _perform_precision(value: float) -> void:
	if not overlay.visible or action_locked:
		return
	if stage != STAGE_COMB and not (stage == STAGE_FINISH and binding_started):
		return
	if stage == STAGE_COMB and int(comb_passes[selected_bundle]) >= 2:
		return
	var low := 0.30 if GameState.is_easy_difficulty() else 0.38
	var high := 0.75 if GameState.is_easy_difficulty() else 0.62
	if value < low or value > high:
		status_label.text = "Espera a la franja verde. Conservas el trabajo correcto."
		_register_mistake("La pasada del rastrillo se hizo fuera de la franja verde. Repite solo esta pasada; conservas las fibras que ya alineaste." if stage == STAGE_COMB else "La vuelta de ligadura se ajustó fuera de la franja verde. Repite esta vuelta; las anteriores siguen aseguradas.")
		if overlay.visible:
			machine_display.show_feedback("Demasiado pronto o demasiado tarde", Color("edab7a"))
		return
	action_audio.play()
	_emit_fiber_feedback(Color("d9bd6a"))
	if stage == STAGE_COMB:
		comb_passes[selected_bundle] = int(comb_passes[selected_bundle]) + 1
		_select_bundle(selected_bundle)
		machine_display.show_feedback("Fibras más largas y alineadas", Color("b9df94"))
		if comb_passes == [2, 2, 2]:
			action_locked = true
			_schedule_transition(0.65, _start_strand_stage)
	elif stage == STAGE_FINISH:
		binding_wraps += 1
		machine_display.binding_target = binding_wraps / 3.0
		progress_label.text = "%d de 3 vueltas firmes" % binding_wraps
		tension_value.text = "%d / 3 vueltas" % binding_wraps
		tension_bar.value = binding_wraps / 3.0 * 100.0
		status_label.text = "Vuelta firme: el extremo conserva su torsión."
		if binding_wraps >= 3:
			action_locked = true
			_schedule_transition(0.95, _start_proof_stage)
	_sync_machine()
	_save_work()


func _update_feed_label() -> void:
	if not is_instance_valid(feed_label):
		return
	var band: ColorRect = %FeedSafeBand
	var tolerance := 10.0 if GameState.is_easy_difficulty() else 4.0
	feed_label.text = "GROSOR: %d     ·     REFERENCIA: 60     ·     FRANJA VÁLIDA: %d–%d" % [int(feed_slider.value), int(60 - tolerance), int(60 + tolerance)]
	band.position.x = 8.0 + (feed_slider.size.x - 16.0) * (60.0 - tolerance) / 100.0
	band.size.x = (feed_slider.size.x - 16.0) * tolerance * 2.0 / 100.0


func _correction_seconds() -> float:
	return 4.0 if GameState.is_easy_difficulty() else 1.0


func _refresh_opportunities() -> void:
	opportunities_label.text = "Oportunidades: %d / %d" % [GameState.get_rope_attempts_left(), GameState.get_rope_opportunities()]


func _focus_stage() -> void:
	match stage:
		STAGE_PREPARE: hemp_long.grab_focus()
		STAGE_COMB: comb_button.grab_focus()
		STAGE_STRANDS: feed_slider.grab_focus()
		STAGE_TENSION: carriage_slider.grab_focus()
		STAGE_FINISH:
			(binding_button if binding_started else seizing_knot).grab_focus()
		STAGE_PROOF: proof_button.grab_focus()


func _save_work() -> void:
	if restoring_work or not overlay.visible or GameState.flags.get("rope_puzzle_completed", false):
		return
	GameState.flags["rope_progress"] = {
		"stage": stage, "materials": material_selected.duplicate(), "comb_passes": comb_passes.duplicate(),
		"selected_bundle": selected_bundle, "mounted": machine_display.mounted.duplicate(),
		"twist_progress": twist_progress, "twist_count": twist_count, "stable_seconds": stable_seconds,
		"binding_started": binding_started, "binding_wraps": binding_wraps,
		"proof_seconds": proof_seconds, "proof_checks": proof_checks,
		"carriage": carriage_slider.value, "feed": feed_slider.value, "brake": proof_brake_slider.value,
	}
	GameState.save_progress()


func _restore_work() -> void:
	var saved: Dictionary = GameState.flags.get("rope_progress", {}).duplicate(true)
	if saved.is_empty():
		return
	restoring_work = true
	var restored_stage := clampi(int(saved.get("stage", 0)), STAGE_PREPARE, STAGE_PROOF)
	# Build the controls for the saved phase, then restore its actual work.
	if restored_stage >= STAGE_COMB:
		_start_combing_stage()
	if restored_stage >= STAGE_STRANDS:
		_start_strand_stage()
	if restored_stage >= STAGE_TENSION:
		_start_tension_stage()
	if restored_stage >= STAGE_FINISH:
		_start_finish_stage()
	if restored_stage >= STAGE_PROOF:
		_start_proof_stage()
	material_selected = saved.get("materials", [false, false, false, false, false, false]).duplicate()
	cleaned_fibers = 0
	for index in 6:
		if material_selected[index]:
			cleaned_fibers += 1
			var button := _material_buttons()[index]
			button.disabled = true
			button.modulate = Color("b9e58d")
			button.text = "✓ " + button.text.replace("🌿 ", "")
	comb_passes = saved.get("comb_passes", [0, 0, 0]).duplicate()
	selected_bundle = int(saved.get("selected_bundle", 0))
	mounted_strands = 0
	var mounted: Array = saved.get("mounted", [false, false, false])
	for index in 3:
		machine_display.mounted[index] = bool(mounted[index])
		machine_display.strand_reveal[index] = 1.0 if mounted[index] else 0.0
		if mounted[index]:
			mounted_strands += 1
			_hook_buttons()[index].disabled = true
			_hook_buttons()[index].modulate = Color("b9e58d")
	braid_step = mounted_strands
	machine_display.fibers = cleaned_fibers
	twist_progress = float(saved.get("twist_progress", 0))
	twist_count = int(saved.get("twist_count", 0))
	stable_seconds = float(saved.get("stable_seconds", 0))
	binding_started = bool(saved.get("binding_started", false))
	binding_wraps = int(saved.get("binding_wraps", 0))
	machine_display.binding = binding_wraps / 3.0
	machine_display.binding_target = machine_display.binding
	proof_checks = int(saved.get("proof_checks", 0))
	proof_seconds = float(saved.get("proof_seconds", 0))
	carriage_slider.value = float(saved.get("carriage", 28))
	feed_slider.value = float(saved.get("feed", 35))
	proof_brake_slider.value = float(saved.get("brake", 30))
	if stage == STAGE_PREPARE:
		progress_label.text = "%d de 3 manojos útiles" % cleaned_fibers
		tension_bar.value = cleaned_fibers / 3.0 * 100.0
		tension_value.text = "%d / 3 fibras limpias" % cleaned_fibers
		if cleaned_fibers == 3:
			_start_combing_stage()
	if stage == STAGE_COMB:
		_select_bundle(selected_bundle)
		if comb_passes == [2, 2, 2]:
			_start_strand_stage()
	if stage == STAGE_STRANDS:
		progress_label.text = "%d de 3 cabos montados" % mounted_strands
		tension_bar.value = mounted_strands / 3.0 * 100.0
		tension_value.text = "%d / 3 cabos preparados" % mounted_strands
		if mounted_strands == 3:
			_start_tension_stage()
	if stage == STAGE_TENSION and twist_progress >= 100:
		_start_finish_stage()
	if stage == STAGE_FINISH and binding_started:
		# Restore binding controls without selecting the correct finish twice.
		finish_container.visible = false
		binding_button.visible = true
		craft_display.visible = true
		instruction_label.text = "Da tres vueltas de ligadura. Pulsa ESPACIO en la franja verde o arrastra el hilo y suéltalo en esa zona."
		progress_label.text = "%d de 3 vueltas firmes" % binding_wraps
		tension_value.text = "%d / 3 vueltas" % binding_wraps
		status_label.text = "%d / 3 vueltas aseguradas. Ajusta las restantes en verde." % binding_wraps
		if binding_wraps == 3:
			_start_proof_stage()
	if stage == STAGE_PROOF:
		progress_label.text = "%d de 3 comprobaciones" % proof_checks
		rope_progress_bar.value = proof_seconds / PROOF_HOLD_SECONDS * 100.0
	restoring_work = false
	_sync_machine()
	_set_step_rail()
