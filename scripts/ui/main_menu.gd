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

func _ready() -> void:
	pending_difficulty = GameState.difficulty
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_continue_game)
	difficulty_button.pressed.connect(_open_difficulty)
	easy_button.pressed.connect(func(): _select_difficulty(GameState.DIFFICULTY_EASY))
	hard_button.pressed.connect(func(): _select_difficulty(GameState.DIFFICULTY_HARD))
	difficulty_close_button.pressed.connect(_confirm_difficulty)
	%CancelRestartButton.pressed.connect(_cancel_restart)
	%ConfirmRestartButton.pressed.connect(_begin_new_game)
	_refresh_difficulty()
	_show_home()

func _show_home() -> void:
	choosing_new_game = false
	difficulty_overlay.hide()
	restart_overlay.hide()
	difficulty_button.hide()
	start_button.show()
	continue_button.visible = GameState.has_saved_game()
	_set_background_focus(true)
	(continue_button if continue_button.visible else start_button).grab_focus()

func _on_start_button_pressed() -> void:
	if starting or difficulty_overlay.visible or restart_overlay.visible:
		return
	choosing_new_game = true
	pending_difficulty = GameState.difficulty
	start_button.hide()
	continue_button.hide()
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
		difficulty_overlay.hide()
		restart_overlay.show()
		%CancelRestartButton.grab_focus()
	else:
		_begin_new_game()

func _cancel_restart() -> void:
	restart_overlay.hide()
	difficulty_overlay.show()
	difficulty_close_button.grab_focus()

func _begin_new_game() -> void:
	if starting:
		return
	starting = true
	GameState.start_new_game(pending_difficulty)

func _set_background_focus(enabled: bool) -> void:
	for button in [start_button, continue_button, difficulty_button]:
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
	elif difficulty_overlay.visible:
		_close_difficulty()
	elif choosing_new_game:
		_show_home()
	get_viewport().set_input_as_handled()
