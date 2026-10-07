extends Control
## Chapter two has its own saved screen; it never reopens the station.
const JOURNAL := preload("res://scripts/ui/chapter_journal.gd")
const BACKGROUND := preload("res://assets/gba/environment/phase_two_construction_v1.png")
var journal: Control
var journal_overlay: ColorRect
var copy: VBoxContainer
var serif := SystemFont.new()

func _ready() -> void:
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.04, 0.43)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy = VBoxContainer.new()
	copy.name = "ConstructionNotice"
	copy.add_theme_constant_override("separation", 16)
	add_child(copy)
	copy.add_child(_label("ENGRANAJES DEL CAMBIO  /  PRÓXIMO CAPÍTULO", 14, Color("#edbc73")))
	copy.add_child(_label("Fase 2\nen construcción", 45, Color("#f9e5b9")))
	copy.add_child(_label("Dificultad: " + GameState.get_difficulty_name(), 16, Color("#edbc73")))
	var message := _label("La ciudad abre sus puertas a una nueva historia. Estamos preparando la siguiente etapa de tu viaje.", 19, Color("#f5ead6"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(message)
	var open := Button.new()
	open.text = "Abrir cuaderno · Esc"
	_style_button(open)
	open.pressed.connect(open_journal)
	copy.add_child(open)
	var home := Button.new()
	home.text = "Volver al inicio"
	_style_button(home)
	home.pressed.connect(_return_home)
	copy.add_child(home)
	copy.add_child(_label("Tu recorrido de la fase 1 está guardado.", 14, Color("#e1cda9")))
	journal_overlay = ColorRect.new()
	journal_overlay.name = "JournalOverlay"
	journal_overlay.color = Color(0.015, 0.02, 0.025, 0.73)
	add_child(journal_overlay)
	journal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal = JOURNAL.new()
	journal_overlay.add_child(journal)
	journal.build()
	journal.enable_navigation()
	journal.refresh(GameState.build_report())
	journal.show_page(2)
	journal.continued.connect(close_journal)
	journal.restart_requested.connect(GameState.restart_phase)
	journal.page_changed.connect(func(_page): GameState.save_progress())
	journal_overlay.hide()
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout.call_deferred()
	GameState.restore_scene_session.call_deferred(self)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if journal_overlay.visible: close_journal()
		else: open_journal()
		get_viewport().set_input_as_handled()
	elif journal_overlay.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_RIGHT]:
			journal.turn_to(1 if event.keycode == KEY_LEFT else 2)
			get_viewport().set_input_as_handled()

func open_journal() -> void:
	journal.refresh(GameState.build_report())
	journal_overlay.show()
	_fit_layout()
	(journal.previous_button if journal.current_page == 2 else journal.next_button).grab_focus()
	GameState.save_progress()

func close_journal() -> void:
	journal_overlay.hide()
	get_viewport().gui_release_focus()
	GameState.save_progress()

func get_session_state() -> Dictionary:
	return {"journal_open": journal_overlay.visible, "journal_page": journal.current_page}

func restore_session_state(state: Dictionary) -> void:
	journal.show_page(clampi(int(state.get("journal_page", 2)), 1, 2))
	if bool(state.get("journal_open", false)): open_journal()
	else: journal_overlay.hide()

func _return_home() -> void:
	GameState.save_progress()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _fit_layout() -> void:
	if not is_inside_tree(): return
	var available := get_viewport_rect().size
	var scale_factor := minf(available.x / 1152.0, available.y / 648.0)
	copy.position = Vector2(available.x * 0.08, available.y * 0.20)
	copy.size = Vector2(470, 400)
	copy.scale = Vector2.ONE * scale_factor
	journal.size = journal.SPREAD_SIZE
	journal.position = (available - journal.size) * 0.5
	journal.pivot_offset = journal.size * 0.5
	journal.scale = Vector2.ONE * minf(1.0, minf((available.x - 24) / journal.size.x, (available.y - 24) / journal.size.y))

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", serif)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _style_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(260, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", serif)
	button.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "focus", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#3d2b20") if state == "normal" else Color("#655031")
		style.border_color = Color("#b88d49")
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("#f9e5b9"))
