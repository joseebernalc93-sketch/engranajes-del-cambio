extends Node2D
## Original train artwork; spoke rotation follows actual train displacement.
const WHEEL_SHADER := preload("res://shaders/train_wheels.gdshader")
const DRIVING_RADIUS := 28.0
var wheel_angle := 0.0
var travelled := 0.0
var speed := 0.0
var last_x := 0.0
var wheel_material: ShaderMaterial


func _ready() -> void:
	last_x = get_parent().position.x
	wheel_material = ShaderMaterial.new()
	wheel_material.shader = WHEEL_SHADER
	get_parent().get_node("Sprite2D").material = wheel_material


func _process(delta: float) -> void:
	var current_x: float = get_parent().position.x
	var displacement := current_x - last_x
	last_x = current_x
	travelled += displacement
	wheel_angle = fmod(travelled / DRIVING_RADIUS, TAU)
	speed = absf(displacement) / maxf(delta, 0.001)
	wheel_material.set_shader_parameter("wheel_angle", wheel_angle)
