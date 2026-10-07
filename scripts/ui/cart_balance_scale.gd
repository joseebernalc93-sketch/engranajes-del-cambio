extends Control

signal value_changed(value: float)

var value := 50.0:
	set(new_value):
		value = clampf(new_value, 0.0, 100.0)
		queue_redraw()
		if not suppress_signal:
			value_changed.emit(value)

var dragging := false
var suppress_signal := false
var touch_index := -1


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	focus_mode = Control.FOCUS_ALL
	queue_redraw()


func set_value_no_signal(new_value: float) -> void:
	suppress_signal = true
	value = new_value
	suppress_signal = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			_set_from_mouse(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_set_from_mouse(event.position.x)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			dragging = true
			_set_from_mouse(event.position.x)
		elif event.index == touch_index and not event.pressed:
			cancel_drag()
		accept_event()
	elif event is InputEventScreenDrag and event.index == touch_index and dragging:
		_set_from_mouse(event.position.x)
		accept_event()


func cancel_drag() -> void:
	dragging = false
	touch_index = -1


func _set_from_mouse(mouse_x: float) -> void:
	value = inverse_lerp(18.0, size.x - 18.0, clampf(mouse_x, 18.0, size.x - 18.0)) * 100.0


func _draw() -> void:
	var left := 18.0
	var right := size.x - 18.0
	var center_y := size.y * 0.5
	var safe_left := lerpf(left, right, 0.46)
	var safe_right := lerpf(left, right, 0.54)
	draw_line(Vector2(left, center_y), Vector2(safe_left, center_y), Color("a66a32"), 12.0)
	draw_line(Vector2(safe_left, center_y), Vector2(safe_right, center_y), Color("73a85b"), 12.0)
	draw_line(Vector2(safe_right, center_y), Vector2(right, center_y), Color("a66a32"), 12.0)
	draw_line(Vector2(left, center_y), Vector2(right, center_y), Color("d2ae6c"), 2.0)
	for tick in 11:
		var tick_x := lerpf(left, right, float(tick) / 10.0)
		var height := 9.0 if tick % 5 == 0 else 5.0
		draw_line(Vector2(tick_x, center_y - height), Vector2(tick_x, center_y + height), Color("34291d"), 2.0)
	var marker_x := lerpf(left, right, value / 100.0)
	draw_circle(Vector2(marker_x, center_y), 12.0, Color("241b14"))
	draw_circle(Vector2(marker_x, center_y), 8.0, Color("e3b85f"))
	draw_line(Vector2(marker_x, center_y - 19.0), Vector2(marker_x, center_y + 19.0), Color("f4d27d"), 3.0)

