extends Node2D

var ripples: Array[Dictionary] = []
var wake: Array[Dictionary] = []
var wake_distance := 0.0
var heading := Vector2.RIGHT


func add_oar_splash(location: Vector2) -> void:
	ripples.append({"position": location, "age": 0.0})


func update_motion(location: Vector2, motion: Vector2, speed: float, delta: float) -> void:
	for ripple in ripples:
		ripple.age += delta
	for point in wake:
		point.age += delta
	ripples = ripples.filter(func(ripple: Dictionary): return float(ripple.age) < 1.1)
	wake = wake.filter(func(point: Dictionary): return float(point.age) < 1.25)
	if motion.length() > 0.05:
		heading = motion.normalized()
	wake_distance += motion.length()
	if speed > 12.0 and wake_distance > 11.0:
		wake_distance = 0.0
		wake.append({"position": location - heading * 36.0, "age": 0.0, "heading": heading})
	queue_redraw()


func _draw() -> void:
	for point in wake:
		var age := float(point.age)
		var center: Vector2 = point.position
		var tangent: Vector2 = point.heading
		var side := tangent.orthogonal()
		var width := 10.0 + age * 14.0
		var color := Color(0.76, 0.96, 1.0, (1.0 - age / 1.25) * 0.33)
		draw_polyline(PackedVector2Array([center + side * width - tangent * 10, center, center - side * width - tangent * 10]), color, 1.7, true)
	for ripple in ripples:
		var age := float(ripple.age)
		var radius := 5.0 + age * 23.0
		var color := Color(0.84, 0.98, 1.0, (1.0 - age / 1.1) * 0.48)
		var points := PackedVector2Array()
		for index in range(33):
			var angle := float(index) / 32.0 * TAU
			points.append(ripple.position + Vector2(cos(angle) * radius, sin(angle) * radius * 0.38))
		draw_polyline(points, color, 1.5, true)
