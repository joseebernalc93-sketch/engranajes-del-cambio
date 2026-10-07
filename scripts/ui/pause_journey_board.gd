extends RefCounted
## An illustrated traveler journal with live progress and native controls.
const BOOK := preload("res://assets/gba/ui/pause_traveler_journal_v1.png")
const ILLUSTRATIONS := preload("res://assets/gba/ui/pause_journal_illustrations_v1.png")
const INK := Color("#382515")
const SOFT_INK := Color("#61472c")
var cards: Dictionary = {}
var counter: Label
var left_page: VBoxContainer
var right_page: VBoxContainer
var objective: Label
var guidance: Label
var serif := SystemFont.new()
var fit_generation := 0

func setup(hud: CanvasLayer) -> void:
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	var panel: PanelContainer = hud.get_node("Root/PauseOverlay/Panel")
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var previous: MarginContainer = panel.get_node("Margin")
	previous.hide()
	var illustration := TextureRect.new()
	illustration.name = "JournalArtwork"
	illustration.texture = BOOK
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_SCALE
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustration.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.add_child(illustration)
	var spread := Control.new()
	spread.name = "TravelerJournal"
	spread.custom_minimum_size = Vector2(1000, 606)
	spread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(spread)
	left_page = VBoxContainer.new()
	left_page.name = "LeftPage"
	left_page.position = Vector2(93, 194)
	left_page.size = Vector2(370, 218)
	left_page.add_theme_constant_override("separation", 5)
	spread.add_child(left_page)
	var title: Label = previous.get_node("VBox/Title")
	title.reparent(left_page)
	title.text = "Fase 1 · El Éxodo Rural"
	_style_label(title, 23)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var difficulty: Label = hud.get_node("%PauseDifficultyLabel")
	difficulty.reparent(left_page)
	_style_label(difficulty, 16)
	difficulty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	difficulty.custom_minimum_size = Vector2(230, 25)
	difficulty.add_theme_stylebox_override("normal", _paper_plate(Color("#d7d3a2"), Color("#7d8152")))
	left_page.add_child(_label("────  OBJETIVO ACTUAL  ────", 14))
	objective = hud.get_node("%PauseObjectiveLabel")
	objective.reparent(left_page)
	_style_label(objective, 18)
	objective.custom_minimum_size.y = 66
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_page.add_child(_label("──────  ◇  ──────", 12, SOFT_INK))
	guidance = hud.get_node("%PauseInfo")
	guidance.reparent(left_page)
	_style_label(guidance, 13, SOFT_INK)
	guidance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	guidance.custom_minimum_size = Vector2(264, 42)
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_page = VBoxContainer.new()
	right_page.name = "RightPage"
	right_page.position = Vector2(519, 168)
	right_page.size = Vector2(386, 377)
	right_page.add_theme_constant_override("separation", 7)
	spread.add_child(right_page)
	counter = _label("PUZZLES · 0 / 4", 19)
	counter.name = "PuzzleCounter"
	right_page.add_child(counter)
	var rows := VBoxContainer.new()
	rows.name = "PuzzleCards"
	rows.add_theme_constant_override("separation", 7)
	right_page.add_child(rows)
	var upper := HBoxContainer.new()
	var lower := HBoxContainer.new()
	for row in [upper, lower]:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 7)
		rows.add_child(row)
	var puzzles := GameState.get_puzzle_progress()
	for index in puzzles.size():
		var puzzle := puzzles[index]
		var card := PanelContainer.new()
		card.name = str(puzzle.id).capitalize() + "Card"
		card.custom_minimum_size = Vector2(184, 110)
		card.add_theme_stylebox_override("panel", _paper_plate(Color(0.86, 0.74, 0.55, 0.22), Color("#9d7647")))
		(upper if index < 2 else lower).add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 1)
		card.add_child(content)
		var icon := TextureRect.new()
		var region := AtlasTexture.new()
		region.atlas = ILLUSTRATIONS
		var cell := Vector2(ILLUSTRATIONS.get_width() / 3.0, ILLUSTRATIONS.get_height() / 2.0)
		region.region = Rect2(Vector2(index % 3, index / 3) * cell, cell)
		icon.texture = region
		icon.custom_minimum_size = Vector2(130, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		content.add_child(icon)
		content.add_child(_label(str(puzzle.label), 15))
		var status := _label("○ Pendiente", 12, SOFT_INK)
		content.add_child(status)
		cards[puzzle.id] = status
	var actions: VBoxContainer = hud.get_node("%ResumeButton").get_parent()
	actions.reparent(right_page)
	actions.add_theme_constant_override("separation", 5)
	for button in [hud.get_node("%ResumeButton"), hud.get_node("%PauseStoryButton"), hud.get_node("%PauseRestartButton")]:
		var primary: bool = button == hud.get_node("%ResumeButton")
		button.custom_minimum_size = Vector2(332 if primary else 310, 45 if primary else 31)
		button.add_theme_font_override("font", serif)
		button.add_theme_font_size_override("font_size", 24 if primary else 16)
		for state in ["normal", "hover", "pressed", "focus"]:
			var background := Color("#4c2f22") if primary else Color("#e5c894")
			if state in ["hover", "focus"]: background = background.lightened(0.10)
			if state == "pressed": background = background.darkened(0.12)
			var style := _paper_plate(background, Color("#a77d3e"))
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.set_corner_radius_all(5)
			style.shadow_color = Color(0.20, 0.10, 0.04, 0.3)
			style.shadow_size = 2
			button.add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			button.add_theme_color_override(state, Color("#f9e4b9") if primary else INK)
		button.draw.connect(_draw_button_ornaments.bind(button, primary))

func _draw_button_ornaments(button: Button, primary: bool) -> void:
	var brass := Color("#c89d59") if primary else Color("#a47b43")
	if primary:
		button.draw_rect(Rect2(Vector2(5, 5), button.size - Vector2(10, 10)), Color("#927049"), false, 1)
	for x in [14.0, button.size.x - 14.0]:
		var center := Vector2(x, button.size.y * 0.5)
		button.draw_circle(center + Vector2(0, 1), 4, Color("#54361e"))
		button.draw_circle(center, 3, brass)
		button.draw_circle(center + Vector2(-0.8, -0.8), 1, Color("#efce8b"))

func refresh() -> void:
	var completed := 0
	for puzzle in GameState.get_puzzle_progress():
		var status: Label = cards[puzzle.id]
		var done: bool = puzzle.completed
		completed += int(done)
		status.text = "✓ Completado" if done else "○ Pendiente"
		status.add_theme_color_override("font_color", Color("#335b36") if done else SOFT_INK)
	counter.text = "PUZZLES · %d / %d" % [completed, cards.size()]
	objective.add_theme_font_size_override("font_size", 17 if objective.text.length() > 125 else 18)
	guidance.add_theme_font_size_override("font_size", 13)

func fit_crest(_panel_size: Vector2) -> void:
	pass # The journal's brass crest and binding are part of its artwork.

func schedule_fit(hud: CanvasLayer) -> void:
	# The callbacks own this RefCounted helper, while the scene is held weakly.
	# A replaced HUD can disappear between either layout frame without resuming
	# a coroutine on a freed CanvasLayer.
	fit_generation += 1
	var requested := fit_generation
	var owner: WeakRef = weakref(hud)
	var tree := hud.get_tree()
	tree.process_frame.connect(func():
		if requested != fit_generation: return
		tree.process_frame.connect(func():
			if requested != fit_generation: return
			var current = owner.get_ref()
			if is_instance_valid(current) and current.is_inside_tree():
				current._apply_pause_panel_fit()
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)

func _label(text: String, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	_style_label(label, font_size, color)
	return label

func _style_label(label: Label, font_size: int, color := INK) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", serif)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size", 0)

func _paper_plate(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
