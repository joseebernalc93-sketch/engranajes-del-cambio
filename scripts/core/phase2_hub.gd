extends Control
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Journal := preload("res://scripts/ui/chapter_journal.gd")
const POPUPS := [preload("res://scenes/mine_puzzle.tscn"), preload("res://scenes/puddle_forge_puzzle.tscn"), preload("res://scenes/steam_engine_puzzle.tscn"), preload("res://scenes/textile_mill_puzzle.tscn")]
var content: Control
var player: CharacterBody2D
var workshop_buttons: Array[Button] = []
var workshops: Array[CanvasLayer] = []
var active_workshop: int = -1
var heading: Label
var guidance: Label
var prompt: Label
var journal_overlay: ColorRect
var journal: Journal
var dialogue: PanelContainer
var dialogue_text: RichTextLabel
var dialogue_kind: String = ""
var dialogue_continue: Button
var dialogue_cancel: Button
var reward_icon: TextureRect
var nearest: int = 0

func _ready() -> void:
	Campaign.ensure()
	GameState.phase_two.active = true
	GameState.phase_two.intro_seen = true
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()
	_refresh()
	GameState.restore_scene_session.call_deferred(self)

func _build() -> void:
	content = Control.new()
	content.size = Vector2(1152, 648)
	add_child(content)
	var image := TextureRect.new()
	image.texture = preload("res://assets/phase2/hub_pixel_v1.png")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.size = content.size
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(image)
	var world := Node2D.new()
	world.name = "World"
	content.add_child(world)
	player = preload("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(580, 440)
	world.add_child(player)
	heading = _label("", Vector2(20, 15), Vector2(930, 28), 21)
	guidance = _label("", Vector2(20, 47), Vector2(930, 54), 16)
	prompt = _label("", Vector2(210, 591), Vector2(750, 42), 16)
	for index in 4:
		var names := ["Caleb · Mina", "Cort · Fundición", "Murdoch · Vapor", "Cartwright · Telares"]
		var button := _button(names[index], Vector2(34 + index * 279, 337), Vector2(250, 40), _enter.bind(index))
		workshop_buttons.append(button)
		var popup: CanvasLayer = POPUPS[index].instantiate()
		add_child(popup)
		popup.closed.connect(_workshop_closed)
		popup.workshop_completed.connect(_reward_received)
		workshops.append(popup)
	_button("Cuaderno · Esc", Vector2(970, 17), Vector2(161, 38), _show_journal)
	_button("Inventario / glosario", Vector2(932, 60), Vector2(199, 35), _show_glossary)
	journal_overlay = ColorRect.new()
	journal_overlay.size = content.size
	journal_overlay.color = Color(0, 0, 0, 0.72)
	journal_overlay.z_index = 10
	content.add_child(journal_overlay)
	journal = Journal.new()
	journal_overlay.add_child(journal)
	journal.build()
	journal.enable_navigation()
	journal.show_page(2)
	journal.position = Vector2(76, 21)
	journal.continued.connect(_hide_journal)
	journal.restart_requested.connect(GameState.restart_phase)
	journal.page_changed.connect(func(_page: int): GameState.save_progress())
	journal_overlay.hide()
	var home := Button.new()
	journal._place_button(home, journal.future, "Menú principal", Rect2(546, 548, 169, 30), false)
	home.pressed.connect(_return_home)
	var restart_chapter := Button.new()
	journal._place_button(restart_chapter, journal.future, "Reiniciar fase 2", Rect2(726, 548, 169, 30), false)
	restart_chapter.pressed.connect(_request_restart)
	dialogue = PanelContainer.new()
	dialogue.position = Vector2(270, 160)
	dialogue.size = Vector2(612, 330)
	dialogue.z_index = 11
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/gba/ui/story_walnut_brass_panel.svg")
	style.set_texture_margin_all(30)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 24
	dialogue.add_theme_stylebox_override("panel", style)
	content.add_child(dialogue)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	dialogue.add_child(column)
	reward_icon = TextureRect.new()
	reward_icon.custom_minimum_size = Vector2(552, 60)
	reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reward_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(reward_icon)
	dialogue_text = RichTextLabel.new()
	dialogue_text.custom_minimum_size = Vector2(552, 245)
	dialogue_text.scroll_active = true
	dialogue_text.fit_content = false
	dialogue_text.bbcode_enabled = false
	dialogue_text.add_theme_font_size_override("normal_font_size", 17)
	dialogue_text.add_theme_color_override("default_color", Color("f3deac"))
	column.add_child(dialogue_text)
	var close := Button.new()
	close.text = "Continuar"
	close.custom_minimum_size = Vector2(250, 40)
	close.pressed.connect(_close_dialogue)
	column.add_child(close)
	dialogue_continue = close
	dialogue_cancel = Button.new()
	dialogue_cancel.text = "Cancelar"
	dialogue_cancel.custom_minimum_size = Vector2(250, 35)
	dialogue_cancel.pressed.connect(func(): dialogue.hide(); dialogue_kind = "")
	column.add_child(dialogue_cancel)
	dialogue.hide()

func _label(text: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f4dfac"))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("17150deb")
	plate.content_margin_left = 10
	plate.content_margin_right = 10
	label.add_theme_stylebox_override("normal", plate)
	content.add_child(label)
	return label

func _button(text: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/gba/ui/story_walnut_brass_button.svg")
	style.set_texture_margin_all(17)
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func _fit() -> void:
	var scale_factor := minf(size.x / 1152.0, size.y / 648.0)
	content.scale = Vector2.ONE * scale_factor
	content.position = (size - content.size * scale_factor) * 0.5

func _process(_delta: float) -> void:
	if player == null: return
	player.position = player.position.clamp(Vector2(30, 391), Vector2(1120, 520))
	nearest = clampi(int((player.position.x - 20.0) / 279.0), 0, 3)
	player.controls_enabled = active_workshop < 0 and not journal_overlay.visible and not dialogue.visible
	prompt.visible = player.controls_enabled
	prompt.text = "E / Espacio: " + ["hablar con Caleb", "entrar a la fundición", "visitar a Murdoch", "entrar a los telares"][nearest] + " · Flechas / WASD: caminar"

func _refresh() -> void:
	heading.text = "FASE 2 · EL CORAZÓN DE HIERRO   |   %s   |   %d / %d oportunidades" % ["Fácil" if GameState.is_easy_difficulty() else "Difícil", Campaign.remaining(), Campaign.total()]
	guidance.text = Campaign.objective()
	for index in 4:
		workshop_buttons[index].modulate = Color("a8c17f") if Campaign.done(Campaign.IDS[index]) else (Color.WHITE if Campaign.unlocked(Campaign.IDS[index]) else Color("aca297"))
	journal.refresh(GameState.build_report())

func _enter(index: int) -> void:
	if active_workshop >= 0 or dialogue.visible or journal_overlay.visible: return
	var id: String = Campaign.IDS[index]
	if Campaign.done(id):
		_message("ficha", Campaign.TUTORS[index] + "\n\n" + Campaign.FACTS[index] + "\n\nTrabajo completado. Tu pieza permanece en el inventario.")
		return
	if not Campaign.unlocked(id):
		_message("bloqueado", Campaign.TUTORS[index] + "\n\n" + Campaign.objective())
		return
	active_workshop = index
	player.controls_enabled = false
	workshops[index].open_workshop()
	GameState.save_progress()

func _workshop_closed() -> void:
	active_workshop = -1
	_refresh()

func _reward_received(id: String) -> void:
	var index := Campaign.IDS.find(id)
	_message("recompensa", "%s: trabajo completado\n\n%s\n\n%s" % [Campaign.TUTORS[index], ContentDB.get_item(Campaign.REWARDS[index]).get("name", id), Campaign.FACTS[index]], ContentDB.get_item_icon(Campaign.REWARDS[index]))
	if GameState.phase_two.completed.size() == 4:
		dialogue_kind = "final"
		dialogue_text.text = "Briggs: el corazón vuelve a latir\n\nHas unido carbón, hierro y vapor para mover cuatro telares y completar diez fardos. El puesto de fogonero es tuyo.\n\nLa producción depende ahora de la energía, el tiempo y la coordinación del trabajo. Abre el cuaderno para consultar tu balance."

func _message(kind: String, text: String, icon: Texture2D = null) -> void:
	dialogue_kind = kind
	dialogue_text.text = text
	reward_icon.texture = icon
	reward_icon.visible = icon != null
	dialogue_continue.text = "Sí, reiniciar fase 2" if kind == "restart" else "Continuar"
	dialogue_cancel.visible = kind == "restart"
	dialogue.show()
	dialogue.reset_size()
	dialogue.size.x = 612
	player.controls_enabled = false
	dialogue_continue.grab_focus()

func _close_dialogue() -> void:
	var final := dialogue_kind == "final"
	var restart := dialogue_kind == "restart"
	dialogue.hide()
	dialogue_kind = ""
	if restart:
		# Chapter 1 and its inventory/history stay intact.
		for reward in Campaign.REWARDS:
			GameState.inventory.erase(reward)
		GameState.phase_two = {}
		Campaign.ensure()
		GameState.phase_two.active = true
		GameState.phase_two.intro_seen = true
		_refresh()
	if final: _show_journal()
	GameState.save_progress()

func _show_glossary() -> void:
	if active_workshop >= 0: return
	var text := "INVENTARIO Y GLOSARIO · FASE 2\n\n"
	if GameState.phase_two.glossary.is_empty(): text += "Cada taller añadirá una pieza y su ficha histórica. Empieza en la mina de Caleb."
	for entry in GameState.phase_two.glossary:
		text += str(entry.title) + "\n" + str(entry.fact) + "\n\n"
	_message("glosario", text)

func _show_journal() -> void:
	if active_workshop >= 0 or dialogue.visible: return
	_refresh()
	journal_overlay.show()
	player.controls_enabled = false
	GameState.save_progress()

func _hide_journal() -> void:
	journal_overlay.hide()
	GameState.save_progress()

func _return_home() -> void:
	GameState.save_progress()
	Phase2Metrics.request_write()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if not is_instance_valid(journal_overlay) or not journal_overlay.visible or not event is InputEventKey or not event.pressed: return
	if event.keycode == KEY_LEFT: journal.turn_to(1)
	elif event.keycode == KEY_RIGHT: journal.turn_to(2)
	else: return
	get_viewport().set_input_as_handled()

func _request_restart() -> void:
	journal_overlay.hide()
	_message("restart", "Reiniciar Fase 2\n\nSe reiniciarán los cuatro talleres, sus oportunidades y su balance. La Fase 1 permanecerá guardada.\n\nPulsa Continuar para reiniciar o Escape para cancelar.")

func _unhandled_input(event: InputEvent) -> void:
	if active_workshop >= 0: return
	if event.is_action_pressed("pause"):
		if dialogue.visible:
			dialogue.hide()
			dialogue_kind = ""
		elif journal_overlay.visible: _hide_journal()
		else: _show_journal()
	elif event.is_action_pressed("inventory"): _show_glossary()
	elif event.is_action_pressed("interact") and not dialogue.visible and not journal_overlay.visible: _enter(nearest)
	elif event is InputEventKey and journal_overlay.visible:
		if event.keycode == KEY_LEFT and event.pressed: journal.turn_to(1)
		elif event.keycode == KEY_RIGHT and event.pressed: journal.turn_to(2)
		else: return
	else: return
	get_viewport().set_input_as_handled()

func get_session_state() -> Dictionary:
	if active_workshop >= 0 and workshops[active_workshop].work != null: workshops[active_workshop]._save()
	return {"position": [player.position.x, player.position.y], "active_workshop": active_workshop, "journal_open": journal_overlay.visible, "journal_page": journal.current_page, "dialogue_kind": dialogue_kind, "dialogue_text": dialogue_text.text if dialogue.visible else ""}

func restore_session_state(saved: Dictionary) -> void:
	var coordinates: Array = saved.get("position", [580, 440])
	if coordinates.size() == 2: player.position = Vector2(float(coordinates[0]), float(coordinates[1]))
	var open_index := int(saved.get("active_workshop", -1))
	if open_index >= 0 and open_index < 4: _enter(open_index)
	journal.show_page(int(saved.get("journal_page", 2)))
	journal_overlay.visible = bool(saved.get("journal_open", false)) and active_workshop < 0
	if not str(saved.get("dialogue_text", "")).is_empty(): _message(str(saved.get("dialogue_kind", "")), str(saved.dialogue_text))
	_refresh()
