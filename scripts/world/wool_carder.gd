extends Node2D

const COMPONENTS := preload("res://assets/gba/environment/wool_carder_components_v1.png")
const STEAM_SCRIPT := preload("res://scripts/world/estate_steam.gd")
const FLYWHEEL_CENTER := Vector2(-67, 9)
const PULLEY_CENTER := Vector2(-4, 43)
const FLYWHEEL_RADIUS := 28.0
const PULLEY_RADIUS := 10.0

var elapsed := 0.0
var flywheel: Sprite2D
var pulley: Sprite2D
var running := true
var transmission: Node2D


class TransmissionVisual:
	extends Node2D
	var carder: Node2D

	func _draw() -> void:
		carder.draw_transmission(self)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_component("StationaryMachine", Rect2(0, 0, 1130, 1024), Vector2.ZERO, Vector2(180.8, 163.84))
	transmission = TransmissionVisual.new()
	transmission.name = "MovingTransmission"
	transmission.carder = self
	add_child(transmission)
	flywheel = _component("Flywheel", Rect2(1090, 104, 440, 440), FLYWHEEL_CENTER, Vector2(61, 61))
	pulley = _component("DrivePulley", Rect2(1195, 678, 234, 234), PULLEY_CENTER, Vector2(24, 24))
	var steam := Node2D.new()
	steam.set_script(STEAM_SCRIPT)
	steam.name = "BoilerSteam"
	steam.position = Vector2(-67, -76)
	steam.height = 36.0
	steam.drift = 6.0
	steam.strength = 0.22
	add_child(steam)
	transmission.queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	flywheel.rotation = fmod(elapsed * 1.85, TAU)
	pulley.rotation = fmod(elapsed * 1.85 * FLYWHEEL_RADIUS / PULLEY_RADIUS, TAU)
	transmission.queue_redraw()


func draw_transmission(canvas: Node2D) -> void:
	var axis := (PULLEY_CENTER - FLYWHEEL_CENTER).normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	var slope := (FLYWHEEL_RADIUS - PULLEY_RADIUS) / FLYWHEEL_CENTER.distance_to(PULLEY_CENTER)
	for side in [-1.0, 1.0]:
		var normal: Vector2 = axis * slope + perpendicular * sqrt(1.0 - slope * slope) * side
		var start := FLYWHEEL_CENTER + normal * FLYWHEEL_RADIUS
		var end := PULLEY_CENTER + normal * PULLEY_RADIUS
		canvas.draw_line(start, end, Color(0.20, 0.13, 0.075), 3.0)
		canvas.draw_line(start + normal * 0.5, end + normal * 0.5, Color(0.65, 0.40, 0.18), 1.0)
		for index in range(4):
			var part := fposmod(elapsed * 0.7 * side + float(index) / 4.0, 1.0)
			var seam := start.lerp(end, part)
			canvas.draw_line(seam - normal, seam + normal, Color(0.82, 0.64, 0.34), 1.0)
	var crank := PULLEY_CENTER + Vector2(cos(pulley_angle()), sin(pulley_angle())) * 5.0
	var piston := Vector2(25 + sin(pulley_angle()) * 4.0, 51)
	canvas.draw_line(crank, piston, Color(0.23, 0.24, 0.22), 3.0)
	canvas.draw_line(crank + Vector2(0, -0.6), piston + Vector2(0, -0.6), Color(0.66, 0.57, 0.35), 1.0)
	canvas.draw_circle(piston, 2.0, Color(0.73, 0.51, 0.18))
	# Small tufts travel down the feed apron while the machine stays fixed.
	for index in range(6):
		var part := fposmod(elapsed * 0.23 + float(index) / 6.0, 1.0)
		var tuft := Vector2(6 + float(index % 3) * 8, 5).lerp(Vector2(17 + float(index % 3) * 8, 37), part)
		canvas.draw_circle(tuft, 1.4, Color(0.97, 0.91, 0.72, sin(part * PI) * 0.8))


func pulley_angle() -> float:
	return elapsed * 1.85 * FLYWHEEL_RADIUS / PULLEY_RADIUS


func is_playing() -> bool:
	return running


func _component(node_name: String, region: Rect2, location: Vector2, display_size: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = COMPONENTS
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.region_filter_clip_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = location
	sprite.scale = display_size / region.size
	add_child(sprite)
	return sprite
