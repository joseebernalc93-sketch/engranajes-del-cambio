extends Control
## Live chapter pages over the selected illustrated traveler journal.
signal continued
signal restart_requested
signal page_changed(page: int)

const BOOK := preload("res://assets/gba/ui/chapter_completion_journal_v1.png")
const FUTURE_BOOK := preload("res://assets/gba/ui/pause_traveler_journal_v1.png")
const ATLAS := preload("res://assets/gba/ui/pause_journal_illustrations_v1.png")
const WHEAT := preload("res://assets/items/wheat_v2.png")
const FLOUR := preload("res://assets/items/flour_sack_v1.png")
const GEAR := preload("res://assets/gba/ui/mill_gear_piece_v1.png")
const INK := Color("#382515")
const GREEN := Color("#345938")
const Factory := preload("res://scripts/core/phase2_campaign.gd")
const Journey := preload("res://scripts/world/london_journey.gd")
const FACTORY_ART := preload("res://assets/phase2/tools_pixel_v1.png")
const SPREAD_SIZE := Vector2(1000, 606)
var serif := SystemFont.new()
var artwork: TextureRect
var summary: Control
var future: Control
var wheat_label: Label
var flour_label: Label
var mill_label: Label
var stats: Label
var accounts: Label
var future_difficulty: Label
var statuses: Dictionary = {}
var previous_button: Button
var next_button: Button
var page_label: Label
var continue_button: Button
var current_page := 1
var navigation_enabled := false
var turn_tween: Tween
var factory_objective: Label
var factory_balance: Label
var factory_statuses: Array[Label] = []
var journey_mode: bool = false
var journey_page: Control
var factory_nodes: Array[Node] = []
var journey_objective: Label
var journey_difficulty: Label
var journey_balance: Label
var journey_statuses: Array[Label] = []
var journey_continue: Button
var journey_title: Label
var journey_heading: Label
var arrival_cards: Control
var mission_cards: Control
var mission_statuses: Array[Label] = []

func build(existing_continue: Button = null, existing_restart: Button = null) -> void:
	name = "ChapterJournal"
	custom_minimum_size = SPREAD_SIZE
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	artwork = _image(self, BOOK, Rect2(Vector2.ZERO, SPREAD_SIZE))
	summary = _page("PhaseOnePage")
	_label(summary, "FASE 1 · EL ÉXODO RURAL", Rect2(83, 62, 388, 25), 16)
	_label(summary, "La ciudad espera", Rect2(83, 86, 388, 45), 33)
	var stamp := _label(summary, "✓  FASE COMPLETADA", Rect2(215, 137, 240, 28), 16, GREEN)
	stamp.add_theme_stylebox_override("normal", _plate(Color(0.91, 0.87, 0.65, 0.85), GREEN))
	wheat_label = _achievement("Cosechaste trigo", WHEAT, 352)
	mill_label = _achievement("Reparaste el molino", _atlas(3), 397)
	flour_label = _achievement("Vendiste harina", FLOUR, 442)
	_label(summary, "Los cercamientos cambiaron la vida en el campo.\nLa ciudad abre un nuevo camino.", Rect2(92, 493, 375, 43), 15)
	_label(summary, "────  TU RECORRIDO  ────", Rect2(527, 66, 381, 28), 21)
	for index in 4:
		var puzzle: Dictionary = GameState.get_puzzle_progress()[index]
		var position := Vector2(530 + (index % 2) * 192, 107 + (index / 2) * 155)
		var card := Panel.new()
		card.name = str(puzzle.id).capitalize() + "Card"
		card.position = position
		card.size = Vector2(183, 147)
		card.add_theme_stylebox_override("panel", _plate(Color(0.86, 0.74, 0.55, 0.18)))
		summary.add_child(card)
		_label(card, str(puzzle.label), Rect2(4, 7, 175, 23), 18)
		_image(card, _atlas(index), Rect2(14, 31, 155, 82))
		statuses[puzzle.id] = _label(card, "✓ Completado", Rect2(10, 115, 163, 23), 14, GREEN)
	stats = _label(summary, "", Rect2(530, 425, 375, 35), 16)
	stats.add_theme_stylebox_override("normal", _plate(Color(0.94, 0.85, 0.67, 0.5)))
	accounts = _label(summary, "", Rect2(530, 469, 375, 38), 15)
	continue_button = existing_continue if existing_continue != null else Button.new()
	var restart := existing_restart if existing_restart != null else Button.new()
	_place_button(continue_button, summary, "Seguir explorando", Rect2(530, 518, 226, 42), true)
	_place_button(restart, summary, "Volver a fase 1", Rect2(764, 518, 142, 42), false)
	if existing_continue == null: continue_button.pressed.connect(func(): continued.emit())
	if existing_restart == null: restart.pressed.connect(func(): restart_requested.emit())
	_build_future()
	factory_nodes = future.get_children()
	_build_journey()
	previous_button = Button.new()
	next_button = Button.new()
	_place_button(previous_button, self, "‹  Fase anterior", Rect2(93, 540, 174, 30), false)
	_place_button(next_button, self, "Fase siguiente  ›", Rect2(291, 540, 174, 30), false)
	previous_button.pressed.connect(turn_to.bind(1))
	next_button.pressed.connect(turn_to.bind(2))
	page_label = _label(self, "", Rect2(680, 571, 155, 19), 11)
	page_label.add_theme_color_override("font_color", Color("#e5c894"))
	show_page(1)

func _build_future() -> void:
	future = _page("PhaseTwoPage")
	_label(future, "FASE 2 · TECNOLOGÍA Y MECANIZACIÓN", Rect2(83, 194, 388, 25), 14)
	_label(future, "El corazón de hierro", Rect2(83, 222, 388, 40), 29)
	future_difficulty = _label(future, "", Rect2(112, 267, 330, 28), 16, GREEN)
	_label(future, "────  OBJETIVO ACTUAL  ────", Rect2(91, 306, 377, 26), 18)
	factory_objective = _label(future, "", Rect2(105, 342, 346, 88), 19)
	factory_balance = _label(future, "", Rect2(109, 443, 340, 87), 15)
	factory_balance.add_theme_stylebox_override("normal", _plate(Color(0.94, 0.85, 0.67, 0.94)))
	_label(future, "────  CARBÓN · HIERRO · VAPOR  ────", Rect2(522, 170, 390, 28), 16)
	for index in 4:
		var pos := Vector2(532 + (index % 2) * 191, 211 + (index / 2) * 133)
		var card := Panel.new()
		card.position = pos
		card.size = Vector2(181, 125)
		card.add_theme_stylebox_override("panel", _plate(Color(0.94, 0.85, 0.67, 0.85)))
		future.add_child(card)
		_label(card, ["Mina", "Fundición", "Motor de Watt", "Telares"][index], Rect2(2, 3, 177, 23), 17)
		var illustration := AtlasTexture.new()
		illustration.atlas = FACTORY_ART
		var cell := Vector2(FACTORY_ART.get_width() / 4.0, FACTORY_ART.get_height() / 3.0)
		var frame: int = [0, 6, 9, 10][index]
		illustration.region = Rect2(Vector2(frame % 4, frame / 4) * cell, cell)
		if frame == 6: illustration.region = Rect2(cell.x * 2.16, cell.y * 1.06, cell.x * 0.74, cell.y * 0.93)
		_image(card, illustration, Rect2(38, 29, 105, 65))
		factory_statuses.append(_label(card, "Pendiente", Rect2(5, 98, 171, 22), 14))
	var close := Button.new()
	_place_button(close, future, "Volver a la fábrica", Rect2(546, 498, 347, 43), true)
	close.pressed.connect(func(): continued.emit())

func _build_journey() -> void:
	journey_page = Control.new()
	journey_page.size = SPREAD_SIZE
	journey_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	future.add_child(journey_page)
	_label(journey_page, "FASE 2 · EL CORAZÓN DE HIERRO", Rect2(83, 194, 388, 25), 15)
	journey_title = _label(journey_page, "Llegada a Londres", Rect2(83, 224, 388, 40), 29)
	journey_difficulty = _label(journey_page, "", Rect2(112, 270, 330, 28), 16, GREEN)
	_label(journey_page, "────  OBJETIVO ACTUAL  ────", Rect2(91, 309, 377, 26), 18)
	journey_objective = _label(journey_page, "", Rect2(105, 345, 346, 89), 19)
	journey_objective.add_theme_stylebox_override("normal", _plate(Color(0.94, 0.85, 0.67, 0.96)))
	journey_balance = _label(journey_page, "", Rect2(109, 449, 340, 80), 15)
	journey_balance.add_theme_stylebox_override("normal", _plate(Color(0.94, 0.85, 0.67, 0.96)))
	journey_heading = _label(journey_page, "────  TU LLEGADA A LA CIUDAD  ────", Rect2(522, 170, 390, 28), 15)
	arrival_cards = Control.new()
	arrival_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journey_page.add_child(arrival_cards)
	var textures: Array[Texture2D] = [preload("res://assets/phase2/london_platform_pixel_v1.png"), preload("res://assets/phase2/london_staff_pixel_v2.png"), preload("res://assets/phase2/london_ticket_hall_pixel_v1.png"), preload("res://assets/phase2/london_street_pixel_v1.png")]
	for index in 4:
		var card := Panel.new()
		card.position = Vector2(532 + (index % 2) * 191, 211 + (index / 2) * 133)
		card.size = Vector2(181, 125)
		card.add_theme_stylebox_override("panel", _plate(Color(0.94, 0.85, 0.67, 0.85)))
		arrival_cards.add_child(card)
		_label(card, ["Llegar en tren", "Conocer al guía", "La boletería", "Salir a Londres"][index], Rect2(2, 3, 177, 23), 16)
		var illustration: Texture2D = textures[index]
		if index == 1:
			var atlas := AtlasTexture.new()
			atlas.atlas = illustration
			atlas.region = Rect2(0, 0, illustration.get_width() / 2.0, illustration.get_height())
			illustration = atlas
		_image(card, illustration, Rect2(11, 29, 159, 65))
		journey_statuses.append(_label(card, "Por descubrir", Rect2(5, 98, 171, 22), 14))
	mission_cards = Control.new()
	mission_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journey_page.add_child(mission_cards)
	var parts := preload("res://assets/phase2/iron_mission_parts_pixel_v2.png")
	var cell := parts.get_size() / Vector2(4, 2)
	var names := ["La galería", "El carbón", "Engranajes", "Agua", "Encendido", "Presión · 2 min"]
	for index in 6:
		var card := Panel.new()
		card.position = Vector2(532 + (index % 2) * 191, 207 + (index / 2) * 94)
		card.size = Vector2(181, 88)
		card.add_theme_stylebox_override("panel", _plate(Color(0.94, 0.85, 0.67, 0.85)))
		mission_cards.add_child(card)
		_label(card, names[index], Rect2(3, 2, 175, 22), 16)
		var illustration: Texture2D
		if index == 0: illustration = preload("res://assets/phase2/mine_pixel_v1.png")
		elif index == 4: illustration = preload("res://assets/phase2/engine_pixel_v1.png")
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = parts
			var frame: int = {1: 5, 2: 1, 3: 4, 5: 7}[index]
			atlas.region = Rect2(Vector2(frame % 4, frame / 4) * cell, cell)
			illustration = atlas
		_image(card, illustration, Rect2(10, 25, 59, 55))
		mission_statuses.append(_label(card, "Pendiente", Rect2(72, 28, 103, 47), 13))
	mission_cards.hide()
	var resume := Button.new()
	journey_continue = resume
	_place_button(resume, journey_page, "Continuar la aventura", Rect2(546, 498, 347, 43), true)
	resume.pressed.connect(func(): continued.emit())

func refresh(report: Dictionary) -> void:
	wheat_label.text = "Cosechaste %d de trigo" % int(report.get("trigo_recolectado", 0))
	mill_label.text = "Reparaste el molino" if bool(report.get("molino_reparado", GameState.flags.get("mill_repaired", false))) else "Tu trabajo en el molino"
	flour_label.text = "Produjiste %d costal de harina\nVenta: %d monedas" % [int(report.get("costales_harina", 0)), int(report.get("monedas_harina", 0))]
	var completed := 0
	var puzzles: Array = report.get("puzzles", GameState.get_puzzle_progress())
	for puzzle in puzzles:
		if not statuses.has(str(puzzle.id)): continue
		var done := bool(puzzle.completed)
		completed += int(done)
		statuses[str(puzzle.id)].text = "✓ Completado" if done else "○ Pendiente"
		statuses[str(puzzle.id)].add_theme_color_override("font_color", GREEN if done else INK)
	var seconds := int(report.get("tiempo_segundos", 0))
	var difficulty := "Fácil" if str(report.get("dificultad", GameState.difficulty)) == "facil" else "Difícil"
	stats.text = "%d / 4 puzzles   ·   %02d:%02d   ·   %s" % [completed, seconds / 60, seconds % 60, difficulty]
	accounts.text = "%d ganadas · %d carreta · %d boleto" % [int(report.get("monedas_harina", 0)), int(report.get("monedas_carretas", 0)), int(report.get("monedas_boleto", 0))]
	future_difficulty.text = "Dificultad: " + difficulty
	Factory.ensure()
	factory_objective.text = Factory.objective()
	var factory_metrics: Dictionary = GameState.phase_two.metrics
	factory_balance.text = "%d / 4 talleres · %d / %d oportunidades\nTiempo de trabajo: %02d:%02d\nFardos: %d / 10 · Paradas: %d" % [GameState.phase_two.completed.size(), Factory.remaining(), Factory.total(), int(float(factory_metrics.active_seconds)) / 60, int(float(factory_metrics.active_seconds)) % 60, int(factory_metrics.bales), int(factory_metrics.emergency_stops)]
	for index in 4:
		factory_statuses[index].text = "✓ Completado" if Factory.done(Factory.IDS[index]) else ("○ Disponible" if Factory.unlocked(Factory.IDS[index]) else "○ Pendiente")
		factory_statuses[index].add_theme_color_override("font_color", GREEN if Factory.done(Factory.IDS[index]) else INK)
	for node in factory_nodes: node.visible = not journey_mode
	journey_page.visible = journey_mode
	if journey_mode:
		journey_difficulty.text = "Dificultad: " + difficulty
		journey_objective.text = Journey.objective()
		var state := Journey.ensure()
		journey_balance.text = "Saldo: %d monedas · Coche: 10 monedas\nConversaciones: %d · Exploración libre" % [GameState.coins, state.talked.size()]
		var iron_data: Dictionary = GameState.phase_two.get("iron_mission", {})
		var mission_active := bool(iron_data.get("started", false))
		arrival_cards.visible = not mission_active
		mission_cards.visible = mission_active
		journey_title.text = "Carbón, hierro y vapor" if mission_active else "Llegada a Londres"
		journey_heading.text = "────  TU MISIÓN · SEIS ETAPAS  ────" if mission_active else "────  TU LLEGADA A LA CIUDAD  ────"
		if mission_active:
			journey_balance.text = "Etapa %d / 6 · %d / %d oportunidades\nCarbón: %d costales + %d paladas\nEnsayo: %d / 120 s" % [mini(6, int(iron_data.get("stage", 0)) + 1), Factory.remaining(), Factory.total(), int(GameState.inventory.get("costal_carbon", 0)), int(iron_data.get("portion", 0)), int(float(iron_data.get("stable_seconds", 0)))]
			for index in 6:
				var passed := index < int(iron_data.get("stage", 0)) or bool(iron_data.get("complete", false))
				mission_statuses[index].text = "✓ Completado" if passed else ("En curso" if index == int(iron_data.get("stage", 0)) else "Pendiente")
				mission_statuses[index].add_theme_color_override("font_color", GREEN if passed else INK)
		var steps := Journey.steps()
		for index in 4:
			journey_statuses[index].text = "✓ Descubierto" if steps[index] else "○ Por descubrir"
			journey_statuses[index].add_theme_color_override("font_color", GREEN if steps[index] else INK)

func enable_navigation() -> void:
	navigation_enabled = true
	continue_button.text = "Volver a fase 2"
	show_page(current_page)

func show_page(page: int) -> void:
	current_page = clampi(page, 1, 2) if navigation_enabled else 1
	summary.visible = current_page == 1
	future.visible = current_page == 2
	artwork.texture = BOOK if current_page == 1 else FUTURE_BOOK
	previous_button.visible = navigation_enabled and current_page == 2
	next_button.visible = navigation_enabled and current_page == 1
	page_label.text = "FASE %d · %d / 2" % [current_page, current_page] if navigation_enabled else "FASE 1 · COMPLETADA"

func turn_to(page: int) -> void:
	if page == current_page: return
	if turn_tween and turn_tween.is_running(): turn_tween.kill()
	show_page(page)
	var content: Control = summary if current_page == 1 else future
	content.modulate.a = 0.0
	turn_tween = create_tween()
	turn_tween.tween_property(content, "modulate:a", 1.0, 0.18)
	page_changed.emit(current_page)
	(next_button if current_page == 1 else previous_button).grab_focus()

func _page(node_name: String) -> Control:
	var page := Control.new()
	page.name = node_name
	page.size = SPREAD_SIZE
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	return page

func _achievement(text: String, texture: Texture2D, y: float) -> Label:
	var row := Panel.new()
	row.position = Vector2(93, y)
	row.size = Vector2(369, 44 if texture == FLOUR else 40)
	row.add_theme_stylebox_override("panel", _plate(Color(0.94, 0.84, 0.64, 0.35)))
	summary.add_child(row)
	_image(row, texture, Rect2(9, 2, 65, 36))
	return _label(row, text, Rect2(77, 2, 287, 40 if texture == FLOUR else 36), 15 if texture == FLOUR else 16)

func _atlas(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	var cell := Vector2(ATLAS.get_width() / 3.0, ATLAS.get_height() / 2.0)
	texture.region = Rect2(Vector2(index % 3, index / 3) * cell, cell)
	return texture

func _image(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE if texture in [BOOK, FUTURE_BOOK] else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = texture
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# TextureRect initially adopts the source image's intrinsic dimensions.
	# Apply the authored rectangle after disabling that minimum size.
	parent.add_child(image)
	image.position = rect.position
	image.size = rect.size
	return image

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color := INK) -> Label:
	var label := Label.new()
	# Establish the wrap width before assigning text; otherwise a zero-width
	# label computes a tall minimum with every word on its own line.
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", serif)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size", 0)
	# Wrapping and font overrides must precede the final page rectangle.
	parent.add_child(label)
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.set_meta("page_rectangle", rect)
	return label

func _place_button(button: Button, parent: Node, text: String, rect: Rect2, primary: bool) -> void:
	if button.get_parent(): button.reparent(parent)
	else: parent.add_child(button)
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.custom_minimum_size = Vector2.ZERO
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.add_theme_font_override("font", serif)
	button.add_theme_font_size_override("font_size", 18 if primary else 15)
	for state in ["normal", "hover", "pressed", "focus"]:
		var color := Color("#4c2f22") if primary else Color("#e5c894")
		if state in ["hover", "focus"]: color = color.lightened(0.13)
		if state == "pressed": color = color.darkened(0.13)
		var style := _plate(color, Color("#a77d3e"))
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("#f9e4b9") if primary else INK)
	button.position = rect.position
	button.size = rect.size
	if primary: button.draw.connect(_draw_button.bind(button))

func _draw_button(button: Button) -> void:
	button.draw_rect(Rect2(Vector2(5, 5), button.size - Vector2(10, 10)), Color("#967246"), false, 1)
	for x in [12.0, button.size.x - 12.0]:
		var center := Vector2(x, button.size.y * 0.5)
		button.draw_circle(center, 3, Color("#c69c55"))
		button.draw_circle(center + Vector2(-0.7, -0.7), 1, Color("#f4d695"))

func _plate(fill: Color, border := Color("#9d7647")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
