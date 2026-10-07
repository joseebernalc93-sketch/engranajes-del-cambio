extends Node

const STEAM_TEXTURE := preload("res://assets/gba/steam_puff_v2.png")
const RAIL_AUDIO := preload("res://scripts/world/railway_audio.gd")

@onready var world: Node2D = get_parent().get_node("World")
@onready var train: Area2D = world.get_node("Train")
@onready var train_model: Node2D = train.get_node("SteamTrain")
@onready var player: CharacterBody2D = world.get_node("Player")

var boarded := false
var departing := false
var wheel_speed := 0.0
var steam_elapsed := 0.0
var complete_phase_on_departure := true
var wheel_angle := 0.0
var departure_elapsed := 0.0
var departure_start := Vector2.ZERO
var departure_finished := false


func _ready() -> void:
	EventBus.dialogue_action_selected.connect(_on_dialogue_action)
	_spawn_steam()


func _process(delta: float) -> void:
	if departing and not departure_finished:
		departure_elapsed += delta
		var progress := clampf((departure_elapsed - 0.45) / 5.0, 0, 1)
		train.position = departure_start.lerp(Vector2(-1050, departure_start.y), progress * progress)
		if progress >= 1:
			departure_finished = true
			wheel_speed = 0.0
			if complete_phase_on_departure:
				GameState.complete_train_departure()
	steam_elapsed += delta
	var steam_interval := 0.16 if departing else 0.72
	if steam_elapsed >= steam_interval:
		steam_elapsed = 0.0
		_spawn_steam()
	wheel_angle = train_model.wheel_angle
	wheel_speed = train_model.speed / 24.0


func _on_dialogue_action(action: String) -> void:
	match action:
		"board_train":
			_board_train()
		"depart_train":
			call_deferred("_depart_train")
		"leave_train":
			_leave_train()
		"close":
			if boarded and not departing:
				_leave_train()


func _board_train() -> void:
	if boarded or departing:
		return
	if not GameState.flags.get("ticket_bought", false):
		GameState.interact("train")
		return
	boarded = true
	player.visible = false
	player.controls_enabled = false
	EventBus.interaction_prompt_changed.emit("")
	EventBus.show_dialogue(
		"A bordo del tren",
		"¿Quieres partir a la ciudad?",
		[
			{"label": "Partir a la ciudad", "action": "depart_train"},
			{"label": "Bajar del tren", "action": "leave_train"},
		]
	)


func _leave_train() -> void:
	if departing:
		return
	boarded = false
	player.position = Vector2(680, 400)
	player.visible = true
	player.controls_enabled = true
	train.monitorable = true
	EventBus.interaction_prompt_changed.emit("")


func _depart_train() -> void:
	if departing or not boarded:
		return
	departing = true
	RAIL_AUDIO.tone(self, false)
	player.controls_enabled = false
	train.monitoring = false
	train.monitorable = false
	EventBus.interaction_prompt_changed.emit("")

	departure_elapsed = 0.0
	departure_start = train.position
	departure_finished = false


func _spawn_steam() -> void:
	if not is_instance_valid(train) or train.position.x < -400.0:
		return
	var puff := Sprite2D.new()
	puff.texture = STEAM_TEXTURE
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	puff.z_index = 4
	puff.position = train.position + Vector2(-403, -102)
	var puff_scale := randf_range(0.018, 0.024)
	puff.scale = Vector2.ONE * puff_scale
	puff.rotation = randf_range(-0.12, 0.12)
	puff.modulate = Color(1.0, 0.98, 0.94, 0.86)
	world.add_child(puff)

	var drift := Vector2(randf_range(28.0, 48.0) if departing else randf_range(-8.0, 10.0), randf_range(-48.0, -36.0))
	var tween := puff.create_tween().set_parallel(true)
	tween.tween_property(puff, "position", puff.position + drift, 1.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(puff, "scale", puff.scale * randf_range(1.7, 2.1), 1.35)
	tween.tween_property(puff, "modulate:a", 0.0, 1.35)
	tween.chain().tween_callback(puff.queue_free)


func get_session_state() -> Dictionary:
	return {"boarded": boarded, "departing": departing, "elapsed": departure_elapsed, "finished": departure_finished, "start": [departure_start.x, departure_start.y], "position": [train.position.x, train.position.y], "travelled": train_model.travelled}


func restore_session_state(state: Dictionary) -> void:
	boarded = bool(state.get("boarded", false))
	departing = bool(state.get("departing", false))
	departure_elapsed = float(state.get("elapsed", 0))
	departure_finished = bool(state.get("finished", false))
	var start: Array = state.get("start", [train.position.x, train.position.y])
	var position: Array = state.get("position", [train.position.x, train.position.y])
	if start.size() == 2: departure_start = Vector2(float(start[0]), float(start[1]))
	if position.size() == 2: train.position = Vector2(float(position[0]), float(position[1]))
	train_model.travelled = float(state.get("travelled", 0))
	train_model.last_x = train.position.x
	train_model.wheel_angle = fmod(train_model.travelled / train_model.DRIVING_RADIUS, TAU)
	train_model.wheel_material.set_shader_parameter("wheel_angle", train_model.wheel_angle)
	player.visible = not boarded
	if boarded: player.controls_enabled = false
	train.monitoring = not departing
	train.monitorable = not departing
