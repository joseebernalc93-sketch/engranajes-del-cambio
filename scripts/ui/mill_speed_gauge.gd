extends Control

@export var maximum := 80.0
@export var safe_min := 40.0
@export var safe_max := 58.0

var value := 0.0
var tripped := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_reading(new_value: float, is_tripped: bool) -> void:
	value = clampf(new_value, 0.0, maximum)
	tripped = is_tripped
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y - 16.0)
	var radius := minf(size.x * 0.42, size.y - 30.0)
	var start := PI
	var finish := TAU
	draw_arc(center, radius, start, finish, 72, Color("302a22"), 18.0)
	_draw_range(center, radius, 0.0, safe_min, Color("b46f2e"))
	_draw_range(center, radius, safe_min, safe_max, Color("6fa45a"))
	_draw_range(center, radius, safe_max, maximum, Color("a9442e"))
	for tick in 9:
		var ratio := float(tick) / 8.0
		var angle := lerpf(start, finish, ratio)
		var outer := center + Vector2.RIGHT.rotated(angle) * (radius + 11.0)
		var inner := center + Vector2.RIGHT.rotated(angle) * (radius - (13.0 if tick % 2 == 0 else 7.0))
		draw_line(inner, outer, Color("d4bb83"), 2.0)
	var needle_angle := lerpf(start, finish, value / maximum)
	var needle_color := Color("ff6b45") if tripped else Color("f4d071")
	draw_line(center, center + Vector2.RIGHT.rotated(needle_angle) * (radius - 15.0), needle_color, 5.0)
	draw_circle(center, 10.0, Color("241b14"))
	draw_circle(center, 6.0, Color("d3a34d"))


func _draw_range(center: Vector2, radius: float, minimum_value: float, maximum_value: float, color: Color) -> void:
	var from_angle := lerpf(PI, TAU, minimum_value / maximum)
	var to_angle := lerpf(PI, TAU, maximum_value / maximum)
	draw_arc(center, radius, from_angle, to_angle, 28, color, 12.0)
