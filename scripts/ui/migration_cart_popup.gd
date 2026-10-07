extends CanvasLayer
## Elena's cart: preparation, balance, enclosure, a real journey and recovery.

const CAPACITY := 7
const ITEM_ORDER := ["alimentos", "mantas", "herramientas", "retrato", "olla", "semillas"]
const ITEMS := {
	"alimentos": {"name": "Alimentos", "weight": 2, "need": "sustento", "bias": -8.0},
	"mantas": {"name": "Mantas", "weight": 2, "need": "familia", "bias": 7.0},
	"herramientas": {"name": "Herramientas", "weight": 3, "need": "oficio", "bias": -12.0},
	"retrato": {"name": "Retrato", "weight": 1, "need": "familia", "bias": 4.0},
	"olla": {"name": "Olla de hierro", "weight": 2, "need": "oficio", "bias": 10.0},
	"semillas": {"name": "Semillas", "weight": 1, "need": "sustento", "bias": 6.0},
}
const STAGE_TRAVEL := 3
const STAGE_DECISION := 4
const STAGE_RECOVER := 5
const STAGE_COMPLETE := 6
const STABLE_SECONDS := 1.1
const MUD_POSITION := 0.42

@onready var overlay: ColorRect = %MigrationCartOverlay
@onready var panel: PanelContainer = $MigrationCartOverlay/Panel
@onready var stage_label: Label = %StageLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var historical_hint: Label = %HistoricalHint
@onready var illustration_status: Label = %IllustrationStatus
@onready var cart_display = %CartDisplay
@onready var packing_panel: Control = %PackingPanel
@onready var balance_panel: Control = %BalancePanel
@onready var route_panel: Control = %RoutePanel
@onready var decision_panel: Control = %DecisionPanel
@onready var journey_panel: Control = %JourneyPanel
@onready var complete_panel: Control = %CompletePanel
@onready var capacity_bar: ProgressBar = %CapacityBar
@onready var capacity_label: Label = %CapacityLabel
@onready var needs_label: Label = %NeedsLabel
@onready var balance_slider = %BalanceSlider
@onready var balance_label: Label = %BalanceLabel
@onready var continue_button: Button = %ContinueButton
@onready var push_button: Button = %PushButton
@onready var item_buttons: Array[Button] = [%FoodButton, %BlanketsButton, %ToolsButton, %PortraitButton, %PotButton, %SeedsButton]

var selected_items: Array[String] = []
var stage := 0
var balance := 50.0
var old_route_attempted := false
var alternate_route_selected := false
var protected_item := ""
var completed := false
var last_recorded_balance := 50.0
var stable_seconds := 0.0
var journey_progress := 0.0
var recovery_progress := 0.0
var wheel_speed := 0.0
var mud_recovered := false
var space_held := false
var pointer_held := false
var left_held := false
var right_held := false
var player_was_enabled := true
var item_style: StyleBoxFlat
var item_pressed_style: StyleBoxFlat


func _ready() -> void:
	EventBus.migration_cart_requested.connect(open)
	%CloseButton.pressed.connect(close)
	continue_button.pressed.connect(_continue_stage)
	balance_slider.value_changed.connect(_on_balance_changed)
	%OldRoadButton.pressed.connect(_try_old_road)
	%LongRoadButton.pressed.connect(_choose_long_road)
	%ProtectFoodButton.pressed.connect(_choose_priority.bind("alimentos"))
	%ProtectToolsButton.pressed.connect(_choose_priority.bind("herramientas"))
	%ProtectMemoryButton.pressed.connect(_choose_priority.bind("recuerdo familiar"))
	push_button.button_down.connect(func(): pointer_held = true)
	push_button.button_up.connect(func(): pointer_held = false)
	cart_display.load_shift_requested.connect(func(value: float): balance_slider.value = value)
	cart_display.preview_requested.connect(_preview_item)
	cart_display.item_requested.connect(func(id: String): _toggle_item(not selected_items.has(id), id))
	cart_display.gate_requested.connect(_try_old_road)
	cart_display.push_requested.connect(func(pressed: bool): pointer_held = pressed)
	for index in item_buttons.size():
		item_buttons[index].toggled.connect(_toggle_item.bind(ITEM_ORDER[index]))
		item_buttons[index].icon = cart_display.CARGO_ART.icon(ITEM_ORDER[index])
		item_buttons[index].expand_icon = true
		item_buttons[index].add_theme_constant_override("icon_max_width", 30)
		item_buttons[index].add_theme_constant_override("h_separation", 6)
		item_buttons[index].focus_entered.connect(_preview_item.bind(ITEM_ORDER[index]))
		item_buttons[index].mouse_entered.connect(_preview_item.bind(ITEM_ORDER[index]))
	get_viewport().size_changed.connect(_fit_panel)
	_style_controls()
	_reset_mission()
	_fit_panel.call_deferred()


func open() -> void:
	if overlay.visible:
		return
	if not GameState.flags.get("flour_sold", false):
		EventBus.show_toast("Primero debes reunir el dinero para el viaje")
		return
	var player = get_tree().get_first_node_in_group("player")
	player_was_enabled = player.controls_enabled if player else true
	_reset_mission()
	overlay.visible = true
	cart_display.active = true
	_set_player_controls(false)
	_fit_panel()
	if GameState.flags.get("cart_mission_completed", false):
		for id in GameState.metrics.get("cart_items_packed", []):
			if ITEMS.has(str(id)):
				selected_items.append(str(id))
		protected_item = str(GameState.metrics.get("cart_protected_item", ""))
		completed = true
		mud_recovered = true
		journey_progress = 1.0
		stage = STAGE_COMPLETE
		_refresh_stage()
	else:
		item_buttons[0].grab_focus()


func close() -> void:
	if not overlay.visible:
		return
	_release_controls()
	cart_display.active = false
	overlay.visible = false
	_set_player_controls(player_was_enabled)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_release_controls()


func _release_controls() -> void:
	space_held = false
	pointer_held = false
	left_held = false
	right_held = false
	wheel_speed = 0.0
	if is_node_ready():
		balance_slider.cancel_drag()
		cart_display.cancel_drag()
		cart_display.speed = 0.0


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		pointer_held = false
		balance_slider.cancel_drag()
		cart_display.cancel_drag()
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and stage in [STAGE_TRAVEL, STAGE_RECOVER]:
			space_held = event.pressed
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D] and stage == 1:
			if event.keycode in [KEY_LEFT, KEY_A]:
				left_held = event.pressed
			else:
				right_held = event.pressed
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I:
			get_viewport().set_input_as_handled()


func _reset_mission() -> void:
	_release_controls()
	selected_items.clear()
	stage = 0
	balance = 50.0
	last_recorded_balance = 50.0
	old_route_attempted = false
	alternate_route_selected = false
	protected_item = ""
	completed = false
	stable_seconds = 0.0
	journey_progress = 0.0
	recovery_progress = 0.0
	mud_recovered = false
	cart_display.reset_cart()
	%CloseButton.text = "X"
	%OldRoadButton.text = "Examinar el portón"
	%LongRoadButton.text = "Tomar el sendero del río"
	for button in item_buttons:
		button.set_pressed_no_signal(false)
	balance_slider.set_value_no_signal(balance)
	_refresh_stage()


func _process(delta: float) -> void:
	if not overlay.visible:
		return
	delta = minf(delta, 0.1)
	if stage == 1:
		if left_held != right_held:
			_adjust_balance((1.0 if right_held else -1.0) * delta * 22.0)
		stable_seconds = minf(STABLE_SECONDS, stable_seconds + delta) if _balance_is_safe() else 0.0
		_refresh_balance()
	elif stage in [STAGE_TRAVEL, STAGE_RECOVER]:
		_update_journey(delta)
	cart_display.speed = wheel_speed
	cart_display.recovery = recovery_progress
	cart_display.journey = journey_progress
	cart_display.pushing = (space_held or pointer_held) and stage in [STAGE_TRAVEL, STAGE_RECOVER]


func _toggle_item(pressed: bool, item_id: String) -> void:
	if not overlay.visible or stage != 0 or not ITEMS.has(item_id):
		return
	_preview_item(item_id)
	var button := item_buttons[ITEM_ORDER.find(item_id)]
	if pressed and not selected_items.has(item_id):
		if _packed_weight() + int(ITEMS[item_id].weight) > CAPACITY:
			button.set_pressed_no_signal(false)
			cart_display.show_feedback("El eje admite 7 unidades. Retira otra pertenencia.")
			return
		selected_items.append(item_id)
		cart_display.pulse_item(item_id)
	elif not pressed:
		selected_items.erase(item_id)
	button.set_pressed_no_signal(pressed)
	_update_packing()


func _packed_weight() -> int:
	var total := 0
	for id in selected_items:
		total += int(ITEMS[id].weight)
	return total


func _covered_needs() -> Dictionary:
	var covered := {"sustento": false, "oficio": false, "familia": false}
	for id in selected_items:
		covered[str(ITEMS[id].need)] = true
	return covered


func _packing_is_valid() -> bool:
	var covered := _covered_needs()
	return selected_items.size() >= 3 and _packed_weight() >= 5 and covered.sustento and covered.oficio and covered.familia


func _continue_stage() -> void:
	if not overlay.visible:
		return
	match stage:
		0:
			if not _packing_is_valid():
				return
			balance = _initial_balance_from_load()
			last_recorded_balance = balance
			balance_slider.set_value_no_signal(balance)
			stage = 1
		1:
			if not _balance_is_safe() or stable_seconds < STABLE_SECONDS:
				return
			stage = 2
		2:
			if not alternate_route_selected:
				return
			stage = STAGE_TRAVEL
		STAGE_COMPLETE:
			close()
	_release_controls()
	_refresh_stage()


func _initial_balance_from_load() -> float:
	var result := 50.0
	for id in selected_items:
		result += float(ITEMS[id].bias)
	result = clampf(result, 22.0, 78.0)
	return result + 14.0 if result >= 45.0 and result <= 55.0 else result


func _on_balance_changed(value: float) -> void:
	if not overlay.visible or stage != 1:
		return
	balance = value
	stable_seconds = 0.0
	if absf(balance - last_recorded_balance) >= 3.0:
		GameState.register_cart_action("balance_move")
		last_recorded_balance = balance
	_refresh_balance()


func _adjust_balance(amount: float) -> void:
	if overlay.visible and stage == 1:
		balance_slider.value = clampf(balance + amount, 0.0, 100.0)


func _balance_is_safe() -> bool:
	return balance >= 46.0 and balance <= 54.0


func _try_old_road() -> void:
	if not overlay.visible or stage != 2 or old_route_attempted:
		return
	old_route_attempted = true
	GameState.register_cart_action("route_attempt")
	cart_display.gate_shake = 0.65
	_refresh_stage()


func _choose_long_road() -> void:
	if not overlay.visible or stage != 2 or not old_route_attempted or alternate_route_selected:
		return
	alternate_route_selected = true
	_refresh_stage()


func _choose_priority(choice: String) -> void:
	if not overlay.visible or stage != STAGE_DECISION or not choice in ["alimentos", "herramientas", "recuerdo familiar"]:
		return
	protected_item = choice
	stage = STAGE_RECOVER
	_release_controls()
	_refresh_stage()


func _update_journey(delta: float) -> void:
	var held := space_held or pointer_held
	if stage == STAGE_RECOVER:
		wheel_speed = 0.0
		if held:
			recovery_progress = minf(1.0, recovery_progress + delta * 0.28)
		if recovery_progress >= 1.0:
			mud_recovered = true
			stage = STAGE_TRAVEL
			_release_controls()
			_refresh_stage()
	else:
		wheel_speed = move_toward(wheel_speed, 105.0 if held else 0.0, delta * (85.0 if held else 230.0))
		var distance := wheel_speed * delta
		journey_progress = minf(1.0, journey_progress + distance / 1100.0)
		cart_display.travelled += distance
		cart_display.wheel_angle += distance / 37.0
		if not mud_recovered and journey_progress >= MUD_POSITION:
			journey_progress = MUD_POSITION
			stage = STAGE_DECISION
			_release_controls()
			_refresh_stage()
		elif journey_progress >= 1.0:
			_finish_journey()
	if stage not in [STAGE_TRAVEL, STAGE_RECOVER]:
		return
	%JourneyBar.value = (recovery_progress if stage == STAGE_RECOVER else journey_progress) * 100.0
	%JourneyLabel.text = "Rampa y tracción: %d%%" % roundi(recovery_progress * 100.0) if stage == STAGE_RECOVER else "Sendero del río: %d%% · %s" % [roundi(journey_progress * 100.0), "en marcha" if wheel_speed > 1.0 else "en reposo"]
	illustration_status.text = "CARGA A SALVO · AVANZA CON ELENA" if mud_recovered else "RUEDAS EN MARCHA · RUMBO AL RÍO"
	if stage == STAGE_RECOVER:
		illustration_status.text = "CUERDA FIJADA · LA RAMPA SOSTIENE LA RUEDA"


func _finish_journey() -> void:
	if not overlay.visible or stage != STAGE_TRAVEL or not mud_recovered or not _packing_is_valid() or not _balance_is_safe() or not alternate_route_selected or protected_item.is_empty() or journey_progress < 1.0:
		return
	completed = GameState.complete_migration_cart(selected_items, protected_item)
	if not completed:
		return
	stage = STAGE_COMPLETE
	_release_controls()
	_refresh_stage()


func _refresh_stage() -> void:
	packing_panel.visible = stage == 0
	balance_panel.visible = stage == 1
	route_panel.visible = stage == 2
	decision_panel.visible = stage == STAGE_DECISION
	journey_panel.visible = stage in [STAGE_TRAVEL, STAGE_RECOVER]
	complete_panel.visible = stage == STAGE_COMPLETE
	continue_button.visible = stage in [0, 1, 2, STAGE_COMPLETE]
	continue_button.disabled = false
	%JourneyBar.value = (recovery_progress if stage == STAGE_RECOVER else journey_progress) * 100.0
	var step: int = [0, 1, 2, 3, 4, 4, 5][stage]
	var step_names := ["Carga", "Equilibrio", "Ruta", "Viaje", "Rescate"]
	var rail: Array[String] = []
	for index in step_names.size():
		rail.append(("✓ " if index < step else "› " if index == step else "") + step_names[index])
	%StepRail.text = "   ".join(rail)
	%StatusTitle.text = ["PREPARAR EL VIAJE", "REPARTIR EL PESO", "RECONOCER EL CERCAMIENTO", "ACOMPAÑAR A LA FAMILIA", "ELEGIR UNA PRIORIDAD", "LIBERAR LA RUEDA", "CAMINO SUPERADO"][stage]
	%ProgressLabel.text = "Paso %d de 5" % mini(step + 1, 5) if stage < STAGE_COMPLETE else "✓ Viaje verificado"
	match stage:
		0:
			stage_label.text = "1. Elegir lo que llevará la familia"
			instruction_label.text = "Pulsa las pertenencias o sus botones. Cubre sustento, trabajo y familia sin superar 7 unidades."
			historical_hint.text = "Migrar obligaba a elegir qué medios de vida y recuerdos podían acompañar a la familia."
			illustration_status.text = "CARRO VACÍO · ELIGE AL MENOS TRES PERTENENCIAS"
			%KeyHint.text = "Pulsa para cargar o retirar · Tab y Enter también funcionan"
			_update_packing()
		1:
			stage_label.text = "2. Centrar y estabilizar la carga"
			instruction_label.text = "Arrastra las pertenencias sobre el carro. Mantén el centro de gravedad en la franja verde."
			historical_hint.text = "Un peso mal repartido castigaba el eje y podía detener el carro en los caminos irregulares."
			%KeyHint.text = "Arrastra la carga o el indicador · ← → / A D ajustan el peso"
			_refresh_balance()
		2:
			stage_label.text = "3. Encontrar una salida hacia la estación"
			instruction_label.text = "Inspecciona el portón del antiguo camino comunal." if not old_route_attempted else "La cadena impide pasar: rodea el cercamiento por el sendero del río."
			historical_hint.text = "Los cercamientos privatizaron los caminos y pastos compartidos; el desvío exigía más tiempo y esfuerzo."
			illustration_status.text = "DESVÍO MARCADO · EL SENDERO SIGUE EL RÍO" if alternate_route_selected else ("PORTÓN CERRADO · PROPIEDAD PRIVADA" if old_route_attempted else "ANTIGUO CAMINO COMUNAL · EXAMINA LA CADENA")
			%OldRoadButton.disabled = old_route_attempted
			%OldRoadButton.text = "Portón cerrado · cercamiento" if old_route_attempted else "Examinar el portón"
			%LongRoadButton.disabled = not old_route_attempted or alternate_route_selected
			%LongRoadButton.text = "✓ Sendero del río elegido" if alternate_route_selected else "Tomar el sendero del río"
			continue_button.text = "Iniciar el desvío"
			continue_button.disabled = not alternate_route_selected
			%KeyHint.text = "Pulsa el portón o Examinar · después elige la ruta alternativa"
		STAGE_TRAVEL:
			stage_label.text = "4. Acompañar el carro por el sendero"
			instruction_label.text = "Guía al caballo con el botón, ESPACIO o pulsando su arnés. Elena acompaña la carreta."
			historical_hint.text = "La familia debe tomar el camino más largo. Las pertenencias son su sustento y sus oportunidades de trabajo."
			push_button.text = "Mantener para avanzar"
			%KeyHint.text = "Mantén ESPACIO, el caballo o el botón · suelta para detenerlo"
			%JourneyLabel.text = "Sendero del río: %d%%" % roundi(journey_progress * 100.0)
			illustration_status.text = "LA RUEDA ESTÁ LIBRE · CONTINÚA A LA ESTACIÓN" if mud_recovered else "EL PORTÓN QUEDA ATRÁS · AVANZA HACIA EL RÍO"
		STAGE_DECISION:
			stage_label.text = "5. Proteger la carga al hundirse una rueda"
			instruction_label.text = "El carro se atasca. Decide qué asegurar primero antes de colocar una rampa y ayudar al caballo."
			historical_hint.text = "Todas las prioridades son válidas: supervivencia, oficio y memoria importan de formas diferentes."
			illustration_status.text = "RUEDA HUNDIDA · ELIGE QUÉ ASEGURAR PRIMERO"
			%KeyHint.text = "Tu prioridad queda registrada · conserva todas las pertenencias"
			%ProtectMemoryButton.text = "Asegurar la familia\nMantas y recuerdos" if selected_items.has("mantas") else "Asegurar el retrato\nMemoria familiar"
		STAGE_RECOVER:
			stage_label.text = "5. Sacar la rueda del barro"
			instruction_label.text = "La prioridad está atada y la rampa colocada. Guía al caballo para sacar la rueda del barro."
			historical_hint.text = "Una tabla reparte el esfuerzo sobre el barro; asegurar la carga evita que se desplace durante el rescate."
			illustration_status.text = "CARGA ATADA · RAMPA COLOCADA · TRACCIÓN DEL CABALLO"
			push_button.text = "Mantener para liberar"
			%JourneyLabel.text = "Rampa y tracción: 0%"
			%KeyHint.text = "Mantén ESPACIO, el caballo o el botón · el progreso se conserva"
		STAGE_COMPLETE:
			stage_label.text = "Elena y su familia alcanzaron la estación"
			instruction_label.text = "Carga estable, desvío recorrido y rueda liberada. Ya puedes comprar el boleto."
			historical_hint.text = "La pérdida de las tierras llevó a numerosas familias rurales a buscar trabajo en las ciudades industriales."
			illustration_status.text = "✓ EQUILIBRIO   ✓ DESVÍO   ✓ CARGA PROTEGIDA   ✓ RESCATE"
			%CompleteSummary.text = "%d pertenencias · %d/7 de peso\nPrioridad: %s" % [selected_items.size(), _packed_weight(), protected_item.capitalize()]
			continue_button.text = "Volver a la aldea"
			%KeyHint.text = "Viaje completado · el boleto ya está disponible"
	_update_sidebar()
	_preview_item(cart_display.preview_item)
	%LoadList.visible = false
	%CargoDetail.visible = stage == 0
	historical_hint.visible = stage != 0
	%PriorityLabel.visible = not continue_button.visible
	_sync_display()


func _preview_item(id: String) -> void:
	cart_display.preview_item = id
	%CargoIcon.texture = cart_display.CARGO_ART.icon(id)
	%CargoName.text = cart_display.CARGO_ART.NAMES[id]
	%CargoDescription.text = cart_display.CARGO_ART.DETAILS[id]
	cart_display.queue_redraw()


func _update_packing() -> void:
	_update_sidebar()
	%LoadList.visible = false
	historical_hint.visible = false
	continue_button.text = "Asegurar y equilibrar"
	continue_button.disabled = not _packing_is_valid()
	for index in item_buttons.size():
		var id: String = ITEM_ORDER[index]
		item_buttons[index].text = "%s · %d peso · %s" % [ITEMS[id].name, ITEMS[id].weight, "trabajo" if ITEMS[id].need == "oficio" else ITEMS[id].need]
		item_buttons[index].set_pressed_no_signal(selected_items.has(id))
	illustration_status.text = "%d PERTENENCIAS CARGADAS · %d/7 DE PESO" % [selected_items.size(), _packed_weight()]
	_sync_display()


func _update_sidebar() -> void:
	capacity_bar.value = float(_packed_weight()) / CAPACITY * 100.0
	capacity_label.text = "Eje: %d / 7 · %d pertenencias" % [_packed_weight(), selected_items.size()]
	var covered := _covered_needs()
	needs_label.text = "Sustento %s\nTrabajo %s\nFamilia %s" % [_mark(covered.sustento), _mark(covered.oficio), _mark(covered.familia)]
	%LoadList.text = "\n".join(selected_items.map(func(id: String): return "• " + str(ITEMS[id].name))) if not selected_items.is_empty() else "El carro está vacío.\nElige lo que viajará con Elena."
	%PriorityLabel.text = "Primero: " + protected_item.capitalize() if not protected_item.is_empty() else "Cada pertenencia cuenta."


func _mark(value: bool) -> String:
	return "✓" if value else "○"


func _refresh_balance() -> void:
	var verified := stable_seconds >= STABLE_SECONDS
	balance_label.text = "✓ Carga estable sobre el eje" if verified else ("Mantén el centro: %d%%" % roundi(stable_seconds / STABLE_SECONDS * 100.0) if _balance_is_safe() else "Corrige hacia " + ("la derecha →" if balance < 46.0 else "← la izquierda"))
	balance_label.add_theme_color_override("font_color", Color("b8d68b") if _balance_is_safe() else Color("efba62"))
	continue_button.text = "Comprobar el camino"
	continue_button.disabled = not verified
	illustration_status.text = "CENTRO DE GRAVEDAD %d%% · %s" % [roundi(balance), "ESTABLE" if verified else "ESTABILIZANDO" if _balance_is_safe() else "PESO DESCENTRADO"]
	_sync_display()


func _sync_display() -> void:
	cart_display.stage = stage
	cart_display.items = selected_items.duplicate()
	cart_display.balance = balance
	cart_display.gate_checked = old_route_attempted
	cart_display.alternate_route = alternate_route_selected
	cart_display.priority = protected_item
	cart_display.recovery = recovery_progress
	cart_display.journey = journey_progress
	cart_display.queue_redraw()


func _fit_panel() -> void:
	var available := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var factor := minf(1.0, minf(available.x / 1088.0, available.y / 614.0))
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * maxf(0.1, factor)


func _style_controls() -> void:
	item_style = StyleBoxFlat.new()
	item_style.bg_color = Color("533723")
	item_style.border_color = Color("ad8044")
	item_style.set_border_width_all(2)
	item_style.set_corner_radius_all(4)
	item_pressed_style = item_style.duplicate()
	item_pressed_style.bg_color = Color("926039")
	item_pressed_style.border_color = Color("f4c15e")
	var hover := item_pressed_style.duplicate()
	hover.bg_color = Color("79512e")
	var disabled := item_style.duplicate()
	disabled.bg_color = Color("23251e")
	disabled.border_color = Color("514a36")
	var buttons: Array[Button] = []
	buttons.append_array(item_buttons)
	buttons.append_array([%CloseButton, continue_button, push_button, %OldRoadButton, %LongRoadButton, %ProtectFoodButton, %ProtectToolsButton, %ProtectMemoryButton])
	for button in buttons:
		button.add_theme_stylebox_override("normal", item_style)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", item_pressed_style)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_stylebox_override("disabled", disabled)
		button.add_theme_color_override("font_color", Color("f2dfbf"))
		button.add_theme_color_override("font_disabled_color", Color("867f6b"))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("16150f")
	bar_bg.border_color = Color("725b36")
	bar_bg.set_border_width_all(2)
	bar_bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("d9a94e")
	fill.set_corner_radius_all(3)
	for bar in [capacity_bar, %JourneyBar]:
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", fill)


func _set_player_controls(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.controls_enabled = enabled
