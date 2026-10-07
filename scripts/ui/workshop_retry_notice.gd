extends Control
## Shared, content-sized error notice for the rope and timber workshops.
signal continued

var heading: Label
var reason_label: Label
var opportunities_label: Label
var continue_button: Button
var card: PanelContainer
var artisan := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(544, 0)
	card.size = Vector2(544, 250)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("19150dee")
	frame.border_color = Color("b78a4c")
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(5)
	frame.shadow_color = Color(0, 0, 0, 0.65)
	frame.shadow_size = 12
	frame.content_margin_left = 24
	frame.content_margin_right = 24
	frame.content_margin_top = 20
	frame.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", frame)
	add_child(card)
	card.resized.connect(_center_card)
	card.minimum_size_changed.connect(func(): _fit_card.call_deferred())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("e6bf72"))
	column.add_child(heading)
	reason_label = _paragraph(column)
	opportunities_label = _paragraph(column)
	var row := CenterContainer.new()
	column.add_child(row)
	continue_button = Button.new()
	continue_button.custom_minimum_size = Vector2(348, 43)
	continue_button.add_theme_font_size_override("font_size", 14)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("926038")
	button_style.border_color = Color("ddb05a")
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(3)
	var hover := button_style.duplicate()
	hover.bg_color = Color("ac7545")
	continue_button.add_theme_stylebox_override("normal", button_style)
	for state in ["hover", "pressed", "focus"]:
		continue_button.add_theme_stylebox_override(state, hover)
	row.add_child(continue_button)
	continue_button.focus_next = continue_button.get_path()
	continue_button.focus_previous = continue_button.get_path()
	continue_button.pressed.connect(func(): continued.emit())
	resized.connect(_fit_card)
	hide()


func _paragraph(parent: VBoxContainer) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("f1eee5"))
	parent.add_child(label)
	return label


func show_error(reason: String, remaining: int, total: int) -> void:
	heading.text = "%s: revisemos el trabajo" % artisan
	reason_label.text = reason
	opportunities_label.text = "Quedan %d de %d oportunidades. Continúas en esta fase; conservas los pasos y ajustes completados." % [remaining, total]
	continue_button.text = "Continuar esta fase · %d / %d" % [remaining, total]
	show()
	_fit_card.call_deferred()
	continue_button.grab_focus()


func _fit_card() -> void:
	if not is_instance_valid(card):
		return
	card.reset_size()
	card.size.x = minf(544, size.x - 32)
	_center_card()


func _center_card() -> void:
	card.position = (size - card.size) * 0.5
