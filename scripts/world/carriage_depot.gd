extends Node2D

const BACKGROUND := preload("res://assets/gba/environment/carriage_depot_v1.png")
const COACH := preload("res://scenes/world/passenger_coach.tscn")
const WATER_SHADER := preload("res://assets/shaders/lake_dock_water.gdshader")

@export var travel_mode := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	material = water
	var spare := COACH.instantiate()
	spare.name = "WaitingCoach"
	spare.position = Vector2(890, 275)
	spare.driver_visible = false
	add_child(spare)
	if not travel_mode:
		var passenger_coach := COACH.instantiate()
		passenger_coach.name = "ScheduledCoach"
		passenger_coach.position = Vector2(600, 398)
		passenger_coach.driver_visible = false
		add_child(passenger_coach)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 1152, 648), false)
