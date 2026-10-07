extends CanvasLayer

const PARTS := {
	"rueda_dentada": {"button": "GearPiece", "name": "Rueda dentada", "maker": "Mateo, en la fragua"},
	"cuerda": {"button": "RopePiece", "name": "Soga", "maker": "Silas, en la cordelería"},
	"tabla": {"button": "PlankPiece", "name": "Tabla", "maker": "Bruno, en la carpintería"},
}
const SEAT_SECONDS := 1.0
const KNOT_SECONDS := 1.25
const BOLT_SECONDS := 1.1
const TENSION_MIN := 64.0
const TENSION_MAX := 78.0

@onready var overlay: ColorRect = %RepairOverlay
@onready var panel: PanelContainer = $RepairOverlay/Panel
@onready var workbench = %WorkbenchDisplay
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel
@onready var action_button: Button = %ActionButton
@onready var adjustment_slider: HSlider = %AdjustmentSlider

var selected_part := ""
var stage := "select"
var gear_angle := deg_to_rad(38.0)
var tension := 20.0
var mounting := 0.0
var bolts := 0
var bolt_progress := 0.0
var awaiting_release := false
var proof_radians := 0.0
var proof_speed := 0.0
var shaft_angle := 0.0
var proof_checks := 0
var completed := false
var pointer_held := false
var space_held := false
var left_held := false
var right_held := false
var focused := true
var player_was_enabled := true
var tool_audio: AudioStreamPlayer
var gear_audio: AudioStreamPlayer
var progress_fill: StyleBoxFlat


func _ready() -> void:
	EventBus.mill_repair_requested.connect(open)
	%CloseButton.pressed.connect(close)
	%ReturnButton.pressed.connect(close)
	%CancelButton.pressed.connect(_cancel_part)
	for part in PARTS:
		var piece := get_node(NodePath("%" + PARTS[part].button)) as Button
		piece.pressed.connect(_select_and_place.bind(part))
		piece.icon = workbench._texture(part)
		piece.expand_icon = true
		piece.add_theme_constant_override("icon_max_width", 34)
	%DecreaseButton.pressed.connect(_adjust.bind(-7.5))
	%IncreaseButton.pressed.connect(_adjust.bind(7.5))
	action_button.button_down.connect(_set_pointer_hold.bind(true))
	action_button.button_up.connect(_set_pointer_hold.bind(false))
	adjustment_slider.value_changed.connect(_set_tension)
	workbench.part_selected.connect(_select_part)
	workbench.part_dropped.connect(_drop_part)
	workbench.target_pressed.connect(_place_selected_part)
	workbench.gear_turned.connect(_turn_gear)
	workbench.tension_changed.connect(_set_tension)
	workbench.action_held.connect(_set_pointer_hold)
	_style_controls()
	_configure_audio()
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel.call_deferred()
	_refresh()


func open() -> void:
	if overlay.visible:
		return
	var player = get_tree().get_first_node_in_group("player")
	player_was_enabled = bool(player.controls_enabled) if player else true
	selected_part = ""
	completed = bool(GameState.flags.get("mill_repaired", false))
	stage = "complete" if completed else ("proof" if GameState.get_mill_repair_progress() == 3 else "select")
	proof_radians = 0
	proof_checks = 0
	shaft_angle = 0
	proof_speed = 0
	_release_controls()
	focused = true
	overlay.visible = true
	workbench.active = true
	workbench.time = 0
	workbench.settle_age = 2
	workbench.placement_age = 2
	workbench.feedback_seconds = 0
	_set_player_controls(false)
	_refresh()


func close() -> void:
	if not overlay.visible:
		return
	_release_controls()
	workbench.cancel_drag()
	workbench.active = false
	overlay.visible = false
	tool_audio.stop()
	gear_audio.stop()
	selected_part = ""
	_set_player_controls(player_was_enabled)


func _process(delta: float) -> void:
	if not overlay.visible:
		return
	var direction := int(right_held) - int(left_held)
	if focused and direction != 0:
		if stage == "gear":
			_turn_gear(direction * deg_to_rad(90) * delta)
		elif stage == "rope":
			_set_tension(tension + direction * 24 * delta)
	var held := focused and (pointer_held or space_held) and not awaiting_release
	proof_speed = 0.0
	if stage == "gear":
		if held and _gear_aligned():
			mounting = minf(1, mounting + delta / SEAT_SECONDS)
			if mounting >= 1:
				_install_part("rueda_dentada")
		elif not _gear_aligned():
			mounting = 0
	elif stage == "rope":
		if held and _rope_safe():
			mounting = minf(1, mounting + delta / KNOT_SECONDS)
			if mounting >= 1:
				_install_part("cuerda")
		elif not _rope_safe():
			mounting = 0
	elif stage == "plank" and held:
		bolt_progress = minf(1, bolt_progress + delta / BOLT_SECONDS)
		if bolt_progress >= 1:
			bolts += 1
			bolt_progress = 0
			_release_controls()
			awaiting_release = true
			if bolts >= 2:
				_install_part("tabla")
			else:
				workbench.show_feedback("Primera fijación firme · suelta y continúa")
	elif stage == "proof" and held and GameState.get_mill_repair_progress() == 3:
		proof_speed = 1.05
		var advance := minf(delta * proof_speed, TAU - proof_radians)
		proof_radians += advance
		shaft_angle += advance
		proof_checks = mini(3, int((proof_radians + 0.00001) / (TAU / 3)))
		if proof_radians >= TAU - 0.00001:
			_complete_repair()
	_refresh()
	_update_audio(held)


func _select_and_place(part: String) -> void:
	_select_part(part)
	_place_selected_part(part)


func _select_part(part: String) -> void:
	if not overlay.visible or stage != "select" or not PARTS.has(part) or GameState.is_mill_part_installed(part):
		return
	if not GameState.has_item(part):
		workbench.show_feedback("Falta esta pieza: visita el taller")
		EventBus.show_toast("Consigue %s con %s." % [PARTS[part].name.to_lower(), PARTS[part].maker])
		return
	selected_part = part
	_refresh()


func _drop_part(part: String, target: String) -> void:
	_select_part(part)
	_place_selected_part(target)


func _place_selected_part(part: String) -> void:
	if not overlay.visible or stage != "select" or not PARTS.has(part) or GameState.is_mill_part_installed(part):
		return
	if selected_part.is_empty():
		_select_part(part)
	if selected_part != part:
		workbench.show_feedback("Esta pieza no corresponde a ese lugar")
		return
	if not GameState.has_item(part):
		return
	_release_controls()
	mounting = 0
	bolts = 0
	bolt_progress = 0
	gear_angle = deg_to_rad(38)
	tension = 20
	stage = {"rueda_dentada": "gear", "cuerda": "rope", "tabla": "plank"}[part]
	workbench.placement_age = 0
	workbench.cancel_drag()
	_refresh()


func _install_part(part: String) -> void:
	if not GameState.install_mill_part(part, true):
		workbench.show_feedback("La pieza no está disponible")
		_cancel_part()
		return
	workbench.settled_part = part
	workbench.settle_age = 0
	workbench.show_feedback("✓ %s instalada" % PARTS[part].name)
	selected_part = ""
	_release_controls()
	awaiting_release = true
	stage = "proof" if GameState.get_mill_repair_progress() == 3 else "select"
	_refresh()


func _cancel_part() -> void:
	if stage not in ["gear", "rope", "plank"]:
		return
	_release_controls()
	workbench.cancel_drag()
	selected_part = ""
	stage = "select"
	mounting = 0
	bolts = 0
	bolt_progress = 0
	_refresh()


func _complete_repair() -> void:
	if stage != "proof" or proof_checks != 3 or proof_radians < TAU - 0.00001:
		return
	if not GameState.complete_mill_repair():
		return
	GameState.metrics["mill_repair_verified"] = true
	GameState.save_progress()
	completed = true
	stage = "complete"
	_release_controls()
	_refresh()


func _gear_aligned() -> bool:
	return absf(wrapf(gear_angle, -PI / 4, PI / 4)) <= deg_to_rad(6)


func _rope_safe() -> bool:
	return tension >= TENSION_MIN and tension <= TENSION_MAX


func _turn_gear(angle: float) -> void:
	if stage == "gear" and overlay.visible:
		gear_angle = wrapf(gear_angle + angle, -PI, PI)
		_refresh()


func _set_tension(value: float) -> void:
	if stage != "rope" or not overlay.visible:
		return
	tension = clampf(value, 0, 100)
	adjustment_slider.set_value_no_signal(tension)
	_refresh()


func _adjust(value: float) -> void:
	if stage == "gear":
		_turn_gear(deg_to_rad(value))
	elif stage == "rope":
		_set_tension(tension + signf(value) * 5)


func _set_pointer_hold(pressed: bool) -> void:
	if not pressed:
		pointer_held = false
		awaiting_release = false
	elif overlay.visible and not completed and not awaiting_release:
		pointer_held = true


func _release_controls() -> void:
	pointer_held = false
	space_held = false
	left_held = false
	right_held = false
	awaiting_release = false
	proof_speed = 0


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		workbench.release_pointer(workbench.get_global_transform_with_canvas().affine_inverse() * event.position)
		_set_pointer_hold(false)
	if not event is InputEventKey:
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not event.pressed:
		# A hidden or disabled action button may not receive its own key release.
		_set_pointer_hold(false)
	if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
		if event.keycode in [KEY_LEFT, KEY_A]:
			left_held = event.pressed
		else:
			right_held = event.pressed
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_SPACE:
		if not event.echo:
			space_held = event.pressed and not awaiting_release
			if not event.pressed:
				awaiting_release = false
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_1, KEY_2, KEY_3] and event.pressed and not event.echo:
		_select_and_place(PARTS.keys()[event.keycode - KEY_1])
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_I:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		_release_controls()
		if is_node_ready():
			workbench.cancel_drag()
			tool_audio.stop()
			gear_audio.stop()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true


func _refresh() -> void:
	if not is_node_ready():
		return
	var count: int = GameState.get_mill_repair_progress()
	status_label.text = "Molino reparado" if completed else "%d de 3 piezas instaladas" % count
	var checklist := PackedStringArray()
	for part in PARTS:
		var fitted: bool = GameState.is_mill_part_installed(part)
		workbench.installed[part] = fitted
		workbench.available[part] = GameState.has_item(part)
		checklist.append("%s %s" % ["✓" if fitted else "○", PARTS[part].name])
		var button := get_node(NodePath("%" + PARTS[part].button)) as Button
		button.visible = stage == "select"
		button.disabled = fitted
		button.button_pressed = selected_part == part
		button.text = "%s%s" % [PARTS[part].name, "  ✓" if fitted else (" · falta" if not GameState.has_item(part) else "")]
	%CheckList.text = "\n".join(checklist)
	var adjusting := stage in ["gear", "rope"]
	%DecreaseButton.visible = adjusting
	%IncreaseButton.visible = adjusting
	%CancelButton.visible = stage in ["gear", "rope", "plank"]
	adjustment_slider.visible = stage == "rope"
	%TensionGuide.visible = stage == "rope"
	action_button.visible = stage != "select" and not completed
	%ReturnButton.visible = completed
	action_button.disabled = (stage == "gear" and not _gear_aligned()) or (stage == "rope" and not _rope_safe()) or awaiting_release
	%StepRail.text = "✓ Molino listo" if completed else "Rueda   Soga   Tabla   › Prueba" if stage == "proof" else "› Rueda   Soga   Tabla   Prueba"
	var progress := 0.0
	var safe := true
	match stage:
		"select":
			%StageLabel.text = "1. Reconstruir la transmisión"
			%InstructionLabel.text = "Arrastra las piezas a las marcas o pulsa sus botones. Puedes instalarlas en cualquier orden."
			%ValueLabel.text = "ELIGE UNA PIEZA"
			%MeterCaption.text = "Piezas montadas"
			%HistoricalHint.text = "Mateo refuerza la rueda; Silas trenza la soga; Bruno prepara la tabla. Sus oficios se unen aquí."
			hint_label.text = "1 · Rueda   2 · Soga   3 · Tabla\nArrastra desde la mesa o usa los botones."
			progress = count / 3.0
		"gear":
			var error := absf(rad_to_deg(wrapf(gear_angle, -PI / 4, PI / 4)))
			safe = _gear_aligned()
			%StageLabel.text = "Encajar la rueda dentada en el eje"
			%InstructionLabel.text = "Gira la rueda hasta alinear su ranura cuadrada; después mantenla presionada para asentarla."
			%ValueLabel.text = "✓ Ranura alineada" if safe else "Desajuste: %.0f°" % error
			%DecreaseButton.text = "↶ Girar"
			%IncreaseButton.text = "Girar ↷"
			%MeterCaption.text = "Asiento sobre el eje"
			action_button.text = "Mantener para encajar la rueda"
			hint_label.text = "← → / A D giran · ESPACIO asienta\nTambién puedes arrastrar el borde de la rueda."
			%HistoricalHint.text = "La ranura debe coincidir con el eje: así transmite el movimiento sin resbalar."
			progress = mounting
		"rope":
			safe = _rope_safe()
			%StageLabel.text = "Tensar la soga entre las poleas"
			%InstructionLabel.text = "Ajusta el tensor hasta la franja verde (64–78%) y mantén el amarre para fijar la unión."
			%ValueLabel.text = "%d%% · %s" % [roundi(tension), "Tensión correcta" if safe else ("Muy floja" if tension < TENSION_MIN else "Demasiado tensa")]
			%DecreaseButton.text = "− Aflojar"
			%IncreaseButton.text = "+ Tensar"
			%MeterCaption.text = "Amarre de la soga"
			action_button.text = "Mantener para asegurar la soga"
			hint_label.text = "← → / A D ajustan · ESPACIO amarra\nPuedes arrastrar el tensor de la máquina."
			%HistoricalHint.text = "La soga floja patina; una tensión excesiva carga los ejes. El amarre conserva la tensión útil."
			progress = mounting
		"plank":
			%StageLabel.text = "Fijar la tabla que sostiene la bancada"
			%InstructionLabel.text = "Mantén la fijación iluminada para apretarla. Suelta antes de trabajar la siguiente."
			%ValueLabel.text = "%d de 2 fijaciones firmes" % bolts
			%MeterCaption.text = "Fijación %d de 2" % mini(2, bolts + 1)
			action_button.text = "Suelta para continuar" if awaiting_release else "Mantener para apretar fijación %d" % mini(2, bolts + 1)
			hint_label.text = "ESPACIO aprieta · suelta entre fijaciones\nTambién puedes mantener la marca sobre la tabla."
			%HistoricalHint.text = "La tabla reparte el esfuerzo del mecanismo. Ambas fijaciones deben sujetarla antes de probar el giro."
			progress = bolt_progress
		"proof":
			%StageLabel.text = "2. Comprobar el movimiento del molino"
			%InstructionLabel.text = "Da una vuelta completa al eje. La rueda debe transmitir el giro sin que la soga o la tabla cedan."
			%ValueLabel.text = "%d de 3 comprobaciones" % proof_checks
			%MeterCaption.text = "Vuelta de comprobación"
			action_button.text = "Mantener para probar el mecanismo"
			hint_label.text = "Mantén ESPACIO, el eje o el botón\nSoltar detiene el giro y conserva el avance."
			%HistoricalHint.text = "%s Engranaje engranado\n%s Soga transmite el giro\n%s Bancada firme" % ["✓" if proof_checks >= 1 else "○", "✓" if proof_checks >= 2 else "○", "✓" if proof_checks >= 3 else "○"]
			progress = proof_radians / TAU
		"complete":
			%StageLabel.text = "El molino vuelve a trabajar para la aldea"
			%InstructionLabel.text = "Las tres piezas están firmes y la transmisión ha superado la prueba. Ya puedes preparar la harina."
			%ValueLabel.text = "✓ Mecanismo verificado"
			%MeterCaption.text = "Reparación terminada"
			action_button.text = "Volver al molino"
			hint_label.text = "Al acercarte: Preparar costal de harina"
			%HistoricalHint.text = "El trabajo de los tres artesanos permite que la comunidad vuelva a moler su cosecha."
			progress = 1
	%ProgressBar.value = progress * 100
	progress_fill.bg_color = Color("9aae67") if safe else Color("c08740")
	workbench.stage = stage
	workbench.selected = selected_part
	workbench.gear_angle = gear_angle
	workbench.shaft_angle = shaft_angle
	workbench.tension = tension if stage == "rope" else 71.0
	workbench.mounting = mounting
	workbench.bolts = bolts
	workbench.bolt_progress = bolt_progress
	workbench.proof = proof_radians / TAU
	workbench.held = focused and (pointer_held or space_held) and not awaiting_release
	workbench.completed = completed
	workbench.queue_redraw()


func _style_controls() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("895126")
	normal.border_color = Color("e0ad52")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = Color("ad682e")
	hover.border_color = Color("ffd27a")
	var disabled := normal.duplicate()
	disabled.bg_color = Color("292722")
	disabled.border_color = Color("5d5547")
	for button in [%GearPiece, %RopePiece, %PlankPiece, %DecreaseButton, %IncreaseButton, action_button, %ReturnButton, %CancelButton, %CloseButton]:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, normal if state == "normal" else disabled if state == "disabled" else hover)
		button.add_theme_color_override("font_color", Color("f8e7c1"))
		button.add_theme_color_override("font_disabled_color", Color("8d877b"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color("171513")
	background.border_color = Color("65523a")
	background.set_border_width_all(2)
	background.set_corner_radius_all(3)
	progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color("9aae67")
	progress_fill.set_corner_radius_all(3)
	%ProgressBar.add_theme_stylebox_override("background", background)
	%ProgressBar.add_theme_stylebox_override("fill", progress_fill)


func _configure_audio() -> void:
	tool_audio = AudioStreamPlayer.new()
	gear_audio = AudioStreamPlayer.new()
	add_child(tool_audio)
	add_child(gear_audio)
	for player in [tool_audio, gear_audio]:
		var data := PackedByteArray()
		data.resize(16000 * 2)
		var random := RandomNumberGenerator.new()
		random.seed = 362
		var filtered := 0.0
		for index in 16000:
			var t := float(index) / 16000
			filtered = lerpf(filtered, random.randf_range(-1, 1), 0.13)
			var sample := sin(t * TAU * 83) * 0.12 + filtered * pow(maxf(0, sin(t * TAU * (5 if player == gear_audio else 9))), 10) * 0.7
			data.encode_s16(index * 2, int(sample * 24000 * minf(1, minf(t * 50, (1 - t) * 50))))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 16000
		stream.data = data
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = 16000
		player.stream = stream
		player.volume_db = -27


func _update_audio(held: bool) -> void:
	var working := held and ((stage == "gear" and _gear_aligned()) or (stage == "rope" and _rope_safe()) or stage == "plank")
	if working and not tool_audio.playing:
		tool_audio.play()
	elif not working:
		tool_audio.stop()
	if proof_speed > 0 and focused and not gear_audio.playing:
		gear_audio.play()
	elif proof_speed == 0 or not focused:
		gear_audio.stop()


func _fit_panel() -> void:
	var available := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var factor := minf(1, minf(available.x / 1088, available.y / 614))
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * maxf(0.1, factor)
	workbench.cancel_drag()


func _set_player_controls(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.controls_enabled = enabled
