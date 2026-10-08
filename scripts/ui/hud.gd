extends CanvasLayer

signal local_dialogue_action(action: String)

const DIALOGUE_PANEL_BASE_HEIGHT := 104.0
const INDUSTRIAL_SURFACE := preload("res://scripts/ui/industrial_surface.gd")
@export var inventory_only := false

@onready var objective_label: Label = %ObjectiveLabel
@onready var coins_label: Label = %CoinsLabel
@onready var prompt_panel: PanelContainer = %PromptPanel
@onready var prompt_label: Label = %PromptLabel
@onready var dialogue_panel: PanelContainer = %DialoguePanel
@onready var dialogue_speaker: Label = %DialogueSpeaker
@onready var dialogue_text: Label = %DialogueText
@onready var dialogue_options: HBoxContainer = %DialogueOptions
@onready var inventory_overlay: ColorRect = %InventoryOverlay
@onready var item_list: GridContainer = %ItemList
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var item_description: Label = %ItemDescription
@onready var toast: PanelContainer = %Toast
@onready var toast_label: Label = %ToastLabel
@onready var completion_overlay: ColorRect = %CompletionOverlay
@onready var report_label: Label = %ReportLabel
@onready var pause_overlay: ColorRect = %PauseOverlay
@onready var pause_objective_label: Label = %PauseObjectiveLabel

var pause_board := preload("res://scripts/ui/pause_journey_board.gd").new()
var completion_journal: Control

var active_dialogue: Dictionary = {}

var toast_tween: Tween
var inventory_tween: Tween
var inventory_mode := "inventory"
var selected_item_id := ""
var slot_buttons: Dictionary = {}


func _ready() -> void:
	for node in $Root.find_children("*", "Button", true, false):
		_style_pixel_button(node as Button)
	for node in %PauseOverlay.find_children("*", "Button", true, false):
		_style_industrial_button(node as Button)
	if not inventory_only:
		pause_board.setup(self)
		_setup_completion_journal()
	_style_hud_tab_button(%InventoryButton)
	_style_inventory_close_button(%CloseInventoryButton)
	_style_inventory_tab(%InventoryTab)
	_style_inventory_tab(%GlossaryTab)
	%InventoryTab.pressed.connect(_set_inventory_mode.bind("inventory"))
	%GlossaryTab.pressed.connect(_set_inventory_mode.bind("glossary"))
	get_viewport().size_changed.connect(_fit_inventory_panel)
	if not inventory_only:
		get_viewport().size_changed.connect(_fit_pause_panel)
		get_viewport().size_changed.connect(_fit_completion_panel)
	call_deferred("_fit_inventory_panel")
	if not inventory_only:
		EventBus.objective_changed.connect(_set_objective)
		EventBus.interaction_prompt_changed.connect(_set_prompt)
		EventBus.dialogue_requested.connect(_show_dialogue)
		EventBus.toast_requested.connect(_show_toast)
		EventBus.phase_completed.connect(_show_completion)
	EventBus.coins_changed.connect(_set_coins)
	EventBus.inventory_changed.connect(_refresh_inventory)
	%InventoryButton.pressed.connect(_toggle_inventory)
	%CloseInventoryButton.pressed.connect(_close_inventory)
	if not inventory_only:
		%ContinueButton.pressed.connect(_close_completion)
		%RestartButton.pressed.connect(GameState.restart_phase)
		%ResumeButton.pressed.connect(_close_pause)
		%PauseStoryButton.pressed.connect(_show_story_overlay)
		%PauseRestartButton.pressed.connect(GameState.restart_phase)
		_set_objective(GameState.get_objective())
	_set_coins(GameState.coins)
	_refresh_inventory()


func _unhandled_input(event: InputEvent) -> void:
	# London owns navigation, Escape and I; this instance supplies the shared UI.
	if inventory_only: return
	if event.is_action_pressed("inventory"):
		if not dialogue_panel.visible and not completion_overlay.visible and not pause_overlay.visible:
			_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if $Root.has_node("EnclosureStory"):
			$Root.get_node("EnclosureStory")._close_overlay()
		elif dialogue_panel.visible:
			_select_dialogue_action("close")
		elif inventory_overlay.visible:
			_close_inventory()
		elif completion_overlay.visible:
			_close_completion()
		elif pause_overlay.visible:
			_close_pause()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()


func _set_objective(text: String) -> void:
	objective_label.text = text
	pause_objective_label.text = text
	_refresh_pause_guidance()


func _set_coins(value: int) -> void:
	coins_label.text = str(value)


func _set_prompt(text: String) -> void:
	if not is_inside_tree(): return
	prompt_label.text = text
	var font := prompt_label.get_theme_font("font")
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, prompt_label.get_theme_font_size("font_size")).x + 28
	var width := minf(get_viewport().get_visible_rect().size.x - 32, maxf(360, text_width))
	prompt_panel.offset_left = -width * 0.5
	prompt_panel.offset_right = width * 0.5
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_panel.visible = not text.is_empty() and not dialogue_panel.visible


func _show_dialogue(payload: Dictionary) -> void:
	active_dialogue = payload.duplicate(true)
	dialogue_speaker.text = str(payload.get("speaker", ""))
	dialogue_text.text = str(payload.get("text", ""))
	for child in dialogue_options.get_children():
		dialogue_options.remove_child(child)
		child.queue_free()
	var options: Array = payload.get("options", [])
	if options.is_empty():
		options = [{"label": "Continuar", "action": "close"}]
	for option in options:
		var button := Button.new()
		button.text = str(option.get("label", "Continuar"))
		button.custom_minimum_size = Vector2(150, 34)
		button.add_theme_font_size_override("font_size", 15)
		_style_industrial_button(button)
		button.pressed.connect(_select_dialogue_action.bind(str(option.get("action", "close"))))
		dialogue_options.add_child(button)
	dialogue_text.custom_minimum_size.y = 20.0
	dialogue_panel.offset_top = -170.0
	dialogue_panel.visible = true
	call_deferred("_fit_dialogue_panel", dialogue_text.text)
	prompt_panel.visible = false
	_set_player_controls(false)


func _fit_dialogue_panel(expected_text: String) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	if not dialogue_panel.visible or dialogue_text.text != expected_text:
		return
	var line_count := maxi(dialogue_text.get_line_count(), 1)
	var text_height := float(dialogue_text.get_line_height() * line_count)
	dialogue_text.custom_minimum_size.y = text_height
	dialogue_panel.offset_top = dialogue_panel.offset_bottom - DIALOGUE_PANEL_BASE_HEIGHT - text_height


func _select_dialogue_action(action: String) -> void:
	dialogue_panel.visible = false
	_set_player_controls(true)
	if inventory_only:
		local_dialogue_action.emit(action)
	else:
		EventBus.dialogue_action_selected.emit(action)


func _toggle_inventory() -> void:
	if inventory_overlay.visible:
		_close_inventory()
	else:
		_refresh_inventory()
		inventory_overlay.visible = true
		_set_player_controls(false)
		_fit_inventory_panel()
		if inventory_tween and inventory_tween.is_valid():
			inventory_tween.kill()
		inventory_overlay.modulate.a = 0.0
		inventory_tween = create_tween()
		inventory_tween.tween_property(inventory_overlay, "modulate:a", 1.0, 0.14)
		%CloseInventoryButton.grab_focus()


func _close_inventory() -> void:
	if inventory_tween and inventory_tween.is_valid():
		inventory_tween.kill()
	inventory_overlay.visible = false
	_set_player_controls(true)


func _fit_inventory_panel() -> void:
	if not is_inside_tree(): return
	var panel: Control = $Root/InventoryOverlay/Panel
	var available := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var fit := minf(1.0, minf(available.x / panel.size.x, available.y / panel.size.y))
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * maxf(fit, 0.1)


func _set_inventory_mode(mode: String) -> void:
	if inventory_mode == mode:
		%InventoryTab.set_pressed_no_signal(mode == "inventory")
		%GlossaryTab.set_pressed_no_signal(mode == "glossary")
		return
	inventory_mode = mode
	selected_item_id = ""
	_refresh_inventory()


func _refresh_inventory() -> void:
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()
	slot_buttons.clear()
	%InventoryTab.set_pressed_no_signal(inventory_mode == "inventory")
	%GlossaryTab.set_pressed_no_signal(inventory_mode == "glossary")
	var first_id := ""
	var total := 0
	var ids: Array = ContentDB.ITEMS.keys() if inventory_mode == "glossary" else GameState.inventory.keys()
	for item_id in ids:
		var amount := int(GameState.inventory.get(item_id, 0))
		if amount <= 0 and inventory_mode == "inventory":
			continue
		total += amount
		if first_id.is_empty():
			first_id = item_id
		var item: Dictionary = ContentDB.get_item(item_id)
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(78, 78)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.tooltip_text = str(item.get("name", item_id))
		button.icon = ContentDB.get_item_icon(item_id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 46)
		button.expand_icon = true
		_style_inventory_slot_button(button)
		var surface := Control.new()
		surface.set_script(INDUSTRIAL_SURFACE)
		surface.surface = 3
		surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(surface)
		_add_quantity_badge(button, "×%d" % amount if inventory_mode == "inventory" else "%02d" % (slot_buttons.size() + 1))
		button.pressed.connect(_show_item.bind(item_id))
		item_list.add_child(button)
		slot_buttons[item_id] = button
	var object_word := "objeto" if slot_buttons.size() == 1 else "objetos"
	var unit_word := "unidad" if total == 1 else "unidades"
	%InventorySummary.text = "%d %s · %d %s" % [slot_buttons.size(), object_word, total, unit_word] if inventory_mode == "inventory" else "%d fichas históricas" % slot_buttons.size()
	# Empty compartments keep the grid quiet and ordered; they are never interactive.
	for index in range(slot_buttons.size(), maxi(12, ceili(slot_buttons.size() / 4.0) * 4)):
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(78, 78)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot := StyleBoxFlat.new()
		slot.bg_color = Color("#141e22")
		slot.border_color = Color("#2a3538")
		slot.set_border_width_all(1)
		slot.set_corner_radius_all(5)
		empty.add_theme_stylebox_override("panel", slot)
		var number := Label.new()
		number.text = "%02d" % (index + 1)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 11)
		number.add_theme_color_override("font_color", Color("#3f4c4e"))
		empty.add_child(number)
		item_list.add_child(empty)
	if slot_buttons.has(selected_item_id):
		_show_item(selected_item_id)
	elif not first_id.is_empty():
		_show_item(first_id)
	else:
		selected_item_id = ""
		item_name.text = "Mochila vacía"
		item_description.text = "Recoge objetos en el campo y los talleres para preparar tu viaje. Consulta sus historias en el Glosario."
		item_icon.texture = null
		%EmptyPreview.visible = true
		%DetailEyebrow.text = "TU VIAJE COMIENZA AQUÍ"


func _show_item(item_id: String) -> void:
	selected_item_id = item_id
	for id in slot_buttons:
		(slot_buttons[id] as Button).set_pressed_no_signal(id == item_id)
	var item: Dictionary = ContentDB.get_item(item_id)
	item_name.text = str(item.get("name", item_id))
	item_description.text = str(item.get("description", ""))
	item_icon.texture = ContentDB.get_item_icon(item_id)
	%EmptyPreview.visible = false
	var amount := int(GameState.inventory.get(item_id, 0))
	var quantity_text := "1 UNIDAD" if amount == 1 else "%d UNIDADES" % amount
	%DetailEyebrow.text = "MEMORIA DE LA REVOLUCIÓN INDUSTRIAL" if inventory_mode == "glossary" else "EN TU MOCHILA  /  " + quantity_text
	item_description.get_parent().scroll_vertical = 0


func _add_quantity_badge(button: Button, text: String) -> void:
	var badge := PanelContainer.new()
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -maxf(27, text.length() * 7 + 8)
	badge.offset_top = -22
	badge.offset_right = -5
	badge.offset_bottom = -5
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("#111b1f")
	plate.border_color = Color("#73604a")
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(3)
	plate.content_margin_left = 3
	plate.content_margin_right = 3
	badge.add_theme_stylebox_override("panel", plate)
	var quantity := Label.new()
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity.text = text
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity.add_theme_font_size_override("font_size", 11)
	quantity.add_theme_color_override("font_color", Color("#ead0a8"))
	badge.add_child(quantity)
	button.add_child(badge)


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast.modulate.a = 1.0
	toast.visible = true
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.35)
	toast_tween.tween_callback(func(): toast.visible = false)


func _show_completion(report: Dictionary) -> void:
	var seconds := int(report.get("tiempo_segundos", 0))
	var minutes := seconds / 60
	var remainder := seconds % 60
	report_label.text = "Tiempo: %02d:%02d\nInteracciones: %d\nTrigo recolectado: %d\nCostales de harina: %d\nMolino: %d tandas · %.1f s estables · %d atascos\nAcciones de fuelle: %d\nGolpes de refuerzo: %d\nViajes en bote: %d\nCortes de sierra: %d\nPasadas de cepillo: %d\nPiezas instaladas: %d\nPistas históricas: %d\nIntentos de compra sin dinero: %d" % [
		minutes,
		remainder,
		int(report.get("interacciones", 0)),
		int(report.get("trigo_recolectado", 0)),
		int(report.get("costales_harina", 0)),
		int(report.get("tandas_trigo_molidas", 0)),
		float(report.get("segundos_estables_molino", 0.0)),
		int(report.get("atascos_molino", 0)),
		int(report.get("acciones_fuelle", 0)),
		int(report.get("golpes_refuerzo", 0)),
		int(report.get("viajes_bote", 0)),
		int(report.get("cortes_sierra", 0)),
		int(report.get("pasadas_cepillo", 0)),
		int(report.get("piezas_molino_instaladas", 0)),
		int(report.get("pistas_historicas", 0)),
		int(report.get("intentos_compra_sin_dinero", 0)),
	]
	completion_overlay.visible = true
	completion_journal.refresh(report)
	_fit_completion_panel()
	_set_player_controls(false)
	%ContinueButton.grab_focus()


func _close_completion() -> void:
	if not completion_overlay.visible: return
	completion_overlay.visible = false
	GameState.open_phase_two()


func _setup_completion_journal() -> void:
	var panel: PanelContainer = $Root/CompletionOverlay/Panel
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.get_node("Margin").hide()
	completion_journal = preload("res://scripts/ui/chapter_journal.gd").new()
	panel.add_child(completion_journal)
	completion_journal.build(%ContinueButton, %RestartButton)


func _fit_completion_panel() -> void:
	if not is_inside_tree(): return
	var panel: Control = $Root/CompletionOverlay/Panel
	panel.size = completion_journal.SPREAD_SIZE
	panel.position = (completion_overlay.size - panel.size) * 0.5
	panel.pivot_offset = panel.size * 0.5
	var available := completion_overlay.size - Vector2(24, 24)
	panel.scale = Vector2.ONE * maxf(0.1, minf(1.0, minf(available.x / panel.size.x, available.y / panel.size.y)))


func _open_pause() -> void:
	_refresh_pause_guidance()
	pause_overlay.visible = true
	_set_player_controls(false)


func _close_pause() -> void:
	pause_overlay.visible = false
	_set_player_controls(true)


func _show_story_overlay() -> void:
	var story_scene = load("res://scenes/ui/enclosure_story.tscn").instantiate()
	$Root.add_child(story_scene)
	_close_pause()
	_set_player_controls(false)


func _set_player_controls(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.controls_enabled = enabled


func _style_pixel_button(button: Button, compact := false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#174633")
	normal.border_color = Color("#8f622b")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 5 if compact else 12
	normal.content_margin_right = 5 if compact else 12

	var hover := normal.duplicate()
	hover.bg_color = Color("#286447")
	hover.border_color = Color("#dfb64b")

	var pressed := normal.duplicate()
	pressed.bg_color = Color("#b9812f")
	pressed.border_color = Color("#f3d070")

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("#fff1c7"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#1a2026"))


func _style_industrial_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#1e2328")
	normal.border_color = Color("#a47035")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	normal.content_margin_left = 16
	normal.content_margin_right = 16

	var hover := normal.duplicate()
	hover.bg_color = Color("#2e373d")
	hover.border_color = Color("#f0b852")

	var pressed := normal.duplicate()
	pressed.bg_color = Color("#8c571e")
	pressed.border_color = Color("#ffd77a")

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("#f7ebd2"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#14181c"))


func _style_hud_tab_button(button: Button) -> void:
	var normal := StyleBoxEmpty.new()
	normal.content_margin_left = 4
	normal.content_margin_right = 4

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.7, 0.48, 0.24, 0.16)
	hover.border_color = Color(0.78, 0.58, 0.32, 0.7)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(3)
	hover.content_margin_left = 4
	hover.content_margin_right = 4

	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.04, 0.07, 0.07, 0.42)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("#ead4ad"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#f4c878"))
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_constant_override("outline_size", 0)


func _style_inventory_slot_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#202c30")
	normal.border_color = Color("#53605b")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12

	var hover := normal.duplicate()
	hover.bg_color = Color("#303c3c")
	hover.border_color = Color("#c28f64")

	var pressed := normal.duplicate()
	pressed.bg_color = Color("#3a332a")
	pressed.border_color = Color("#e1ac77")
	pressed.set_border_width_all(2)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#f3d3a5")
	focus.set_border_width_all(2)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Color("#f1dfbd"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _style_inventory_close_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#202b2e")
	normal.border_color = Color("#5b5146")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.68, 0.4, 0.18, 0.18)
	hover.border_color = Color(0.95, 0.68, 0.34, 0.8)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)

	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.75, 0.45, 0.2, 0.3)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("#f7ebd2"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 20)


func _style_inventory_tab(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#172226")
	normal.border_color = Color("#3b4645")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2c3635")
	hover.border_color = Color("#b58259")
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color("#44362a")
	selected.border_color = Color("#ce986a")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("#9da7a2"))
	button.add_theme_color_override("font_hover_color", Color("#fae7c8"))
	button.add_theme_color_override("font_pressed_color", Color("#f3d4ad"))


func _refresh_pause_guidance() -> void:
	pause_objective_label.text = GameState.get_objective()
	%PauseDifficultyLabel.text = "Dificultad: " + GameState.get_difficulty_name()
	%PauseInfo.text = GameState.get_phase_guidance()
	pause_board.refresh()
	call_deferred("_fit_pause_panel")


func _fit_pause_panel() -> void:
	if not is_inside_tree(): return
	pause_board.schedule_fit(self)


func _apply_pause_panel_fit() -> void:
	if not is_inside_tree(): return
	var panel: Control = $Root/PauseOverlay/Panel
	panel.size = Vector2(1000, maxf(606, panel.get_combined_minimum_size().y))
	pause_board.fit_crest(panel.size)
	panel.position = (pause_overlay.size - panel.size) * 0.5
	var available := pause_overlay.size - Vector2(24, 24)
	var fit := minf(1.0, minf(available.x / panel.size.x, available.y / panel.size.y))
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * maxf(fit, 0.1)


func get_session_state() -> Dictionary:
	var state := {"pause": pause_overlay.visible, "inventory": inventory_overlay.visible, "inventory_mode": inventory_mode, "selected_item": selected_item_id, "completion": completion_overlay.visible}
	if dialogue_panel.visible:
		state["dialogue"] = active_dialogue.duplicate(true)
	var story := $Root.get_node_or_null("EnclosureStory")
	if story:
		state["story_index"] = story.current_index
	return state


func restore_session_state(state: Dictionary) -> void:
	if state.has("dialogue"):
		_show_dialogue(state.dialogue)
	elif bool(state.get("pause", false)):
		_open_pause()
	elif bool(state.get("inventory", false)):
		_set_inventory_mode(str(state.get("inventory_mode", "inventory")))
		_toggle_inventory()
		var selected := str(state.get("selected_item", ""))
		if not selected.is_empty() and slot_buttons.has(selected):
			slot_buttons[selected].pressed.emit()
	if state.has("story_index"):
		_show_story_overlay()
		var story = $Root.get_node("EnclosureStory")
		story.current_index = clampi(int(state.story_index), 0, 3)
		story._show_page(false)
	if bool(state.get("completion", false)):
		_show_completion(GameState.build_report())
