extends Area2D

@export var interaction_id := ""
@export var prompt := "Interactuar"
@export var texture: Texture2D
@export var sprite_scale := Vector2.ONE
@export var sprite_offset := Vector2.ZERO
@export var texture_region := Rect2()
@export var consumed_on_use := false
@export var blocks_movement := false
@export var blocking_size := Vector2(24, 20)
@export var blocking_offset := Vector2(0, -10)
@export var interaction_radius := 0.0
@export var interaction_offset := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("interactable")
	sprite.texture = texture
	sprite.scale = sprite_scale
	sprite.position = sprite_offset
	if texture_region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = texture_region
		sprite.region_filter_clip_enabled = true
	if interaction_radius > 0.0:
		var circle := CircleShape2D.new()
		circle.radius = interaction_radius
		$CollisionShape2D.shape = circle
	if interaction_offset != Vector2.ZERO:
		$CollisionShape2D.position = interaction_offset
	if blocks_movement:
		_add_movement_blocker()
	if consumed_on_use and GameState.flags.get(interaction_id, false):
		queue_free()


func _add_movement_blocker() -> void:
	var body := StaticBody2D.new()
	body.name = "MovementBlocker"
	body.position = blocking_offset
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = blocking_size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func get_prompt() -> String:
	if interaction_id in ["mill_mechanism", "broken_mill"] and GameState.flags.get("mill_repaired", false):
		return "E  Preparar costal de harina"
	return "E  %s" % prompt


func interact() -> void:
	var consumed := GameState.interact(interaction_id)
	if consumed and consumed_on_use:
		monitorable = false
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.18)
		tween.tween_property(self, "modulate:a", 0.0, 0.18)
		tween.chain().tween_callback(queue_free)
