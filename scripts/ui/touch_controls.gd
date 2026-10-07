extends CanvasLayer

const ACTIONS := {
	"Menu": "pause",
	"Up": "move_up",
	"Down": "move_down",
	"Left": "move_left",
	"Right": "move_right",
	"Interact": "interact",
}

var held_actions: Dictionary = {}


func _ready() -> void:
	visible = OS.has_feature("mobile")
	if not visible:
		return
	for button_name in ACTIONS:
		var button: Button = get_node("Root/%s" % button_name)
		_style_button(button, button_name == "Interact")
		button.button_down.connect(_press_action.bind(ACTIONS[button_name]))
		button.button_up.connect(_release_action.bind(ACTIONS[button_name]))
	EventBus.dialogue_requested.connect(func(_payload): _release_all())
	EventBus.phase_completed.connect(func(_report): _release_all())


func _exit_tree() -> void:
	_release_all()


func _press_action(action: String) -> void:
	held_actions[action] = true
	Input.action_press(action)


func _release_action(action: String) -> void:
	held_actions.erase(action)
	Input.action_release(action)


func _release_all() -> void:
	for action in held_actions:
		Input.action_release(action)
	held_actions.clear()


func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 28 if primary else 24)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.08, 0.09, 0.68)
	normal.border_color = Color("#d5a23f") if primary else Color(0.82, 0.84, 0.78, 0.78)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(6)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.72, 0.48, 0.16, 0.9)
	pressed.border_color = Color("#f5d477")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#171b1c"))
