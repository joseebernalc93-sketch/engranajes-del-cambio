extends CharacterBody2D

@export var speed := 205.0

const FRAME_SIZE := Vector2(362.0, 362.0)
const COLUMN_X := [0.0, 362.0, 724.0]
const WALK_SEQUENCE := [0, 1, 2, 1]
const DIRECTION_Y := {
	"down": 0.0,
	"left": 362.0,
	"right": 724.0,
	"up": 1086.0,
}
const FOOT_Y := {
	"down": 361.0,
	"left": 361.0,
	"right": 348.0,
	"up": 312.0,
}

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

var nearest_interactable: Area2D
var displayed_prompt := ""
var controls_enabled := true
var facing := "down"
var animation_elapsed := 0.0


func _ready() -> void:
	EventBus.dialogue_requested.connect(func(_payload): controls_enabled = false)
	EventBus.phase_completed.connect(func(_report): controls_enabled = false)
	_set_sprite_frame(1)


func _physics_process(delta: float) -> void:
	if controls_enabled:
		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = direction * speed
		_update_walk_animation(direction, delta)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		_set_sprite_frame(1)
	_update_interactable()
	if controls_enabled and Input.is_action_just_pressed("interact") and nearest_interactable:
		nearest_interactable.interact()


func _update_interactable() -> void:
	var candidate: Area2D
	var best_distance := INF
	for area in interaction_area.get_overlapping_areas():
		if not area.has_method("interact"):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < best_distance:
			best_distance = distance
			candidate = area
	var current_prompt: String = candidate.get_prompt() if candidate else ""
	if candidate == nearest_interactable and current_prompt == displayed_prompt:
		return
	nearest_interactable = candidate
	displayed_prompt = current_prompt
	EventBus.interaction_prompt_changed.emit(current_prompt)


func enable_controls() -> void:
	controls_enabled = true


func _update_walk_animation(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		animation_elapsed = 0.0
		_set_sprite_frame(1)
		return

	if absf(direction.x) > absf(direction.y):
		facing = "left" if direction.x < 0.0 else "right"
	else:
		facing = "up" if direction.y < 0.0 else "down"

	animation_elapsed += delta
	var sequence_index := int(animation_elapsed * 7.5) % WALK_SEQUENCE.size()
	_set_sprite_frame(WALK_SEQUENCE[sequence_index])


func _set_sprite_frame(column: int) -> void:
	sprite.region_rect = Rect2(
		COLUMN_X[column],
		DIRECTION_Y[facing],
		FRAME_SIZE.x,
		FRAME_SIZE.y
	)
	# Each generated direction has different transparent padding; keep feet grounded.
	sprite.position.y = -(FOOT_Y[facing] - FRAME_SIZE.y * 0.5) * absf(sprite.scale.y)
