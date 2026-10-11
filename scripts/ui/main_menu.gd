extends Control

@onready var start_button: Button = %StartButton
@onready var continue_button: Button = %ContinueGameButton
@onready var difficulty_button: Button = %DifficultyButton
@onready var difficulty_overlay: ColorRect = %DifficultyOverlay
@onready var easy_button: Button = %EasyButton
@onready var hard_button: Button = %HardButton
@onready var difficulty_description: Label = %DifficultyDescription
@onready var difficulty_close_button: Button = %DifficultyCloseButton
@onready var restart_overlay: ColorRect = %RestartConfirmOverlay

var pending_difficulty := GameState.DIFFICULTY_HARD
var choosing_new_game := false
var starting := false
var chapter_button: Button
var chapter_overlay: ColorRect
var chapter_panel: PanelContainer
var phase_one_button: Button
var phase_two_button: Button
var restart_two_button: Button
var pending_chapter_restart := false

func _ready() -> void:
	pending_difficulty = GameState.difficulty
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_continue_game)
	difficulty_button.pressed.connect(_open_difficulty)
	easy_button.pressed.connect(func(): _select_difficulty(GameState.DIFFICULTY_EASY))
	hard_button.pressed.connect(func(): _select_difficulty(GameState.DIFFICULTY_HARD))
	difficulty_close_button.pressed.connect(_confirm_difficulty)
	%CancelRestartButton.pressed.connect(_cancel_restart)
	%ConfirmRestartButton.pressed.connect(_confirm_restart_choice)
	_build_chapter_menu()
	_refresh_difficulty()
	_show_home()

func _show_home() -> void:
	choosing_new_game = false
	difficulty_overlay.hide()
	restart_overlay.hide()
	difficulty_button.hide()
	chapter_overlay.hide()
	chapter_button.visible = GameState.has_saved_game() and GameState.is_phase_two_unlocked()
	pending_chapter_restart = false
	start_button.show()
	continue_button.visible = GameState.has_saved_game()
	_set_background_focus(true)
	(continue_button if continue_button.visible else start_button).grab_focus()

func _on_start_button_pressed() -> void:
	if starting or difficulty_overlay.visible or restart_overlay.visible or chapter_overlay.visible:
		return
	choosing_new_game = true
	pending_difficulty = GameState.difficulty
	start_button.hide()
	continue_button.hide()
	chapter_button.hide()
	difficulty_button.show()
	difficulty_button.grab_focus()

func _continue_game() -> void:
	if starting:
		return
	starting = true
	if not GameState.continue_saved_game():
		starting = false
		_show_home()

func _open_difficulty() -> void:
	if not choosing_new_game or starting:
		return
	difficulty_overlay.show()
	_set_background_focus(false)
	_refresh_difficulty()
	(easy_button if pending_difficulty == GameState.DIFFICULTY_EASY else hard_button).grab_focus()

func _close_difficulty() -> void:
	difficulty_overlay.hide()
	_set_background_focus(true)
	difficulty_button.grab_focus()

func _select_difficulty(value: String) -> void:
	pending_difficulty = value
	_refresh_difficulty()

func _confirm_difficulty() -> void:
	if starting:
		return
	if GameState.has_saved_game():
		pending_chapter_restart = false
		_set_restart_copy(false)
		difficulty_overlay.hide()
		restart_overlay.show()
		%CancelRestartButton.grab_focus()
	else:
		_begin_new_game()

func _cancel_restart() -> void:
	restart_overlay.hide()
	if pending_chapter_restart:
		pending_chapter_restart = false
		_open_chapters()
		return
	difficulty_overlay.show()
	difficulty_close_button.grab_focus()

func _begin_new_game() -> void:
	if starting:
		return
	starting = true
	GameState.start_new_game(pending_difficulty)

func _set_background_focus(enabled: bool) -> void:
	for button in [start_button, continue_button, difficulty_button, chapter_button]:
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _refresh_difficulty() -> void:
	var easy := pending_difficulty == GameState.DIFFICULTY_EASY
	easy_button.set_pressed_no_signal(easy)
	hard_button.set_pressed_no_signal(not easy)
	difficulty_description.text = "Disfruta la historia y resuelve los desafíos con mayor tranquilidad. Ideal para comenzar tu aventura." if easy else "Pon a prueba tu precisión y habilidad para superar los desafíos. Ideal si buscas un reto mayor."

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or starting:
		return
	if restart_overlay.visible:
		_cancel_restart()
	elif chapter_overlay.visible:
		_close_chapters()
	elif difficulty_overlay.visible:
		_close_difficulty()
	elif choosing_new_game:
		_show_home()
	get_viewport().set_input_as_handled()

func _build_chapter_menu() -> void:
	chapter_button = Button.new()
	chapter_button.name = "UnlockedChaptersButton"
	chapter_button.text = "Fases desbloqueadas"
	chapter_button.add_theme_font_override("font", start_button.get_theme_font("font"))
	chapter_button.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "focus"]:
		chapter_button.add_theme_stylebox_override(state, start_button.get_theme_stylebox(state))
	chapter_button.add_theme_color_override("font_color", Color("f4dfac"))
	start_button.get_parent().add_child(chapter_button)
	chapter_button.anchor_left = 0.716
	chapter_button.anchor_right = 0.977
	chapter_button.anchor_top = 0.821
	chapter_button.anchor_bottom = 0.938
	chapter_button.pressed.connect(_open_chapters)
	chapter_overlay = ColorRect.new()
	chapter_overlay.name = "UnlockedChaptersOverlay"
	chapter_overlay.color = Color(0.02, 0.015, 0.01, 0.74)
	chapter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(chapter_overlay)
	chapter_panel = PanelContainer.new()
	chapter_panel.add_theme_stylebox_override("panel", %DifficultyOverlay.get_node("Center/Panel").get_theme_stylebox("panel"))
	chapter_overlay.add_child(chapter_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 26)
	chapter_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Tus fases desbloqueadas"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", start_button.get_theme_font("font"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f4dfac"))
	column.add_child(title)
	var info := Label.new()
	info.text = "Fase 1 completada · Dificultad: " + ("Fácil" if GameState.is_easy_difficulty() else "Difícil")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color("cbd39d"))
	column.add_child(info)
	phase_one_button = _chapter_action(column, "Volver a fase 1 · Completada", _visit_phase_one)
	phase_two_button = _chapter_action(column, "Continuar fase 2 · Londres", _continue_phase_two)
	restart_two_button = _chapter_action(column, "Reiniciar fase 2", _request_phase_two_restart)
	_chapter_action(column, "Volver al menú", _close_chapters)
	chapter_overlay.hide()
	resized.connect(_fit_chapters)
	_fit_chapters.call_deferred()

func _chapter_action(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(464, 43)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, difficulty_close_button.get_theme_stylebox(state))
	button.add_theme_font_override("font", start_button.get_theme_font("font"))
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("f4dfac"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _fit_chapters() -> void:
	chapter_panel.reset_size()
	var factor := minf(1.0, minf((size.x - 24) / chapter_panel.size.x, (size.y - 24) / chapter_panel.size.y))
	chapter_panel.scale = Vector2.ONE * factor
	chapter_panel.position = (size - chapter_panel.size * factor) * 0.5

func _open_chapters() -> void:
	if starting or not GameState.is_phase_two_unlocked(): return
	chapter_overlay.show()
	_set_background_focus(false)
	_fit_chapters()
	phase_two_button.grab_focus()

func _close_chapters() -> void:
	chapter_overlay.hide()
	_set_background_focus(true)
	chapter_button.grab_focus()

func _visit_phase_one() -> void:
	if starting: return
	starting = true
	GameState.revisit_phase_one()

func _continue_phase_two() -> void:
	if starting: return
	starting = true
	GameState.open_phase_two()

func _request_phase_two_restart() -> void:
	chapter_overlay.hide()
	pending_chapter_restart = true
	_set_restart_copy(true)
	restart_overlay.show()
	%CancelRestartButton.grab_focus()

func _set_restart_copy(chapter_two: bool) -> void:
	var column: VBoxContainer = restart_overlay.get_node("Center/Panel/Margin/VBox")
	column.get_node("Title").text = "¿Volver al inicio de la fase 2?" if chapter_two else "¿Comenzar una nueva historia?"
	column.get_node("Message").text = "La Fase 2 comenzará desde la historia y la llegada a Londres. Se borrarán sus puzzles, descubrimientos y objetos, y recuperarás las monedas y pertenencias con las que terminaste la Fase 1. La Fase 1 seguirá completada y conservarás la dificultad. Para seguir donde estabas, elige Cancelar y Continuar fase 2." if chapter_two else "Se reiniciará el juego desde el inicio y perderás tu partida guardada. Para conservarla, elige Cancelar."
	%ConfirmRestartButton.text = "Reiniciar fase 2" if chapter_two else "Comenzar de nuevo"

func _confirm_restart_choice() -> void:
	if pending_chapter_restart:
		if starting: return
		starting = true
		GameState.restart_phase_two()
	else: _begin_new_game()
