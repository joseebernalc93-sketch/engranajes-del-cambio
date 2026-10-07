extends Node2D

@export var height := 48.0
@export var drift := 10.0
@export var strength := 0.24
@export var cycle_speed := 0.19

var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	for index in range(10):
		var progress := fposmod(elapsed * cycle_speed + float(index) / 10.0, 1.0)
		var radius := 2.2 + progress * 7.0
		var center := Vector2(sin(progress * 4.8 + elapsed * 0.3) * progress * 4.0 + progress * drift, -progress * height)
		var opacity := sin(progress * PI) * strength
		draw_circle(center, radius, Color(0.80, 0.83, 0.80, opacity * 0.5))
		draw_circle(center + Vector2(-radius * 0.25, -radius * 0.15), radius * 0.78, Color(0.96, 0.94, 0.88, opacity))
