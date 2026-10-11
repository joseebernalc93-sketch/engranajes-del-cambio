extends Node2D

const PARTS := preload("res://assets/gba/environment/passenger_coach_components_v1.png")
const HORSE := preload("res://assets/gba/ui/elena_draft_horse_walk_v4.png")
const BODY_REGION := Rect2(30, 200, 1060, 610)
const BODY_RECT := Rect2(-104, -122, 190, 110)
const WHEEL_REGION := Rect2(1119, 124, 391, 391)
const DRIVER_REGION := Rect2(1070, 575, 256, 372)
const PASSENGER_REGION := Rect2(1330, 582, 203, 369)
const REAR_AXLE := Vector2(-76, -25)
const FRONT_AXLE := Vector2(36, -20)

@export var passenger_visible := false
@export var driver_visible := true
@export var facing_left := false
@export var driver_portrait: Texture2D
@export var driver_portrait_region: Rect2

var speed := 0.0
var travelled := 0.0
var elapsed := 0.0
var wheel_angle := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	travelled += maxf(speed, 0.0) * delta / maxf(absf(scale.x), 0.01)
	wheel_angle = fmod(travelled / 23.0, TAU)
	queue_redraw()


func horse_frame() -> int:
	return int(travelled / 11.0) % 4 if speed > 1.0 else 0


func _draw() -> void:
	var direction := -1.0 if facing_left else 1.0
	var bounce := sin(travelled * 0.15) * minf(speed / 100.0, 1.0) * 0.9
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1))
	_shadow(Vector2(-8, -2), Vector2(106, 7))
	_shadow(Vector2(141, -1), Vector2(46, 5))
	draw_set_transform(Vector2(0, bounce), 0.0, Vector2(direction, 1))
	draw_texture_rect_region(PARTS, BODY_RECT, BODY_REGION)
	if passenger_visible:
		draw_texture_rect_region(PARTS, Rect2(-51, -119, 34, 53), PASSENGER_REGION)
	if driver_visible:
		if driver_portrait != null:
			draw_texture_rect_region(driver_portrait, Rect2(31, -126, 41, 49), driver_portrait_region)
		else:
			draw_texture_rect_region(PARTS, Rect2(34, -121, 35, 52), DRIVER_REGION)
	# The near side hides the seated passenger's knees below the rail.
	var side_panel := Rect2(210, 490, 610, 235)
	var scale_factor := BODY_RECT.size / BODY_REGION.size
	draw_texture_rect_region(PARTS, Rect2(BODY_RECT.position + (side_panel.position - BODY_REGION.position) * scale_factor, side_panel.size * scale_factor), side_panel)
	for axle in [REAR_AXLE, FRONT_AXLE]:
		draw_set_transform(Vector2(axle.x * direction, axle.y + bounce), wheel_angle * direction, Vector2(direction, 1))
		draw_texture_rect_region(PARTS, Rect2(-23, -23, 46, 46), WHEEL_REGION)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1))
	for offset in [0.0, 8.0]:
		draw_line(Vector2(75, -37 + offset + bounce), Vector2(138, -30 + offset), Color("543722"), 3.0)
		draw_line(Vector2(75, -38 + offset + bounce), Vector2(138, -31 + offset), Color("c29859"), 1.0)
	draw_texture_rect_region(HORSE, Rect2(87, -78, 100, 75), Rect2(horse_frame() * 543, 158, 543, 399))
	if driver_visible:
		draw_polyline(PackedVector2Array([Vector2(63, -90 + bounce), Vector2(99, -82), Vector2(171, -57)]), Color("3a2b1b"), 1.0)
	draw_set_transform(Vector2.ZERO)


func _shadow(center: Vector2, size: Vector2) -> void:
	var direction := -1.0 if facing_left else 1.0
	draw_set_transform(Vector2(center.x * direction, center.y), 0.0, size)
	draw_circle(Vector2.ZERO, 1.0, Color(0.07, 0.06, 0.035, 0.19))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1))
