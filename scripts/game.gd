extends Node2D

@onready var player = $World/Player


func _ready() -> void:
	GameState.restore_scene_session.call_deferred(self)
	EventBus.dialogue_action_selected.connect(_on_dialogue_action)
	if GameState.pending_spawn != Vector2.ZERO:
		player.position = GameState.pending_spawn
		GameState.pending_spawn = Vector2.ZERO


func _on_dialogue_action(action: String) -> void:
	match action:
		"go_station":
			GameState.pending_spawn = Vector2(90, 480)
			call_deferred("_change_map", "res://scenes/carriage_depot.tscn")
		"take_passenger_coach", "return_by_coach":
			var destination := "res://scenes/station.tscn" if action == "take_passenger_coach" else "res://scenes/carriage_depot.tscn"
			if GameState.book_passenger_coach(destination):
				player.controls_enabled = false
				call_deferred("_change_map", "res://scenes/coach_travel.tscn")
		"go_station_platform":
			GameState.pending_spawn = Vector2(640, 410)
			call_deferred("_change_map", "res://scenes/station_platform.tscn")
		"go_station_interior":
			GameState.pending_spawn = Vector2(576, 310) if scene_file_path == "res://scenes/station_platform.tscn" else Vector2(576, 560)
			call_deferred("_change_map", "res://scenes/station_interior.tscn")
		"go_station_exterior":
			GameState.pending_spawn = Vector2(610, 420)
			call_deferred("_change_map", "res://scenes/station.tscn")
		"go_village":
			GameState.pending_spawn = Vector2(1070, 480)
			call_deferred("_change_map", "res://scenes/game.tscn")
		"go_mill_field":
			GameState.pending_spawn = Vector2(1070, 470)
			call_deferred("_change_map", "res://scenes/mill_field.tscn")
		"go_village_from_mill":
			GameState.pending_spawn = Vector2(70, 470)
			call_deferred("_change_map", "res://scenes/game.tscn")
		"go_mill_interior":
			GameState.pending_spawn = Vector2(576, 470)
			call_deferred("_change_map", "res://scenes/mill_interior.tscn")
		"go_mill_field_from_interior":
			GameState.pending_spawn = Vector2(965, 405)
			call_deferred("_change_map", "res://scenes/mill_field.tscn")
		"go_wheelwright_yard":
			GameState.pending_spawn = Vector2(720, 580)
			call_deferred("_change_map", "res://scenes/wheelwright_yard.tscn")
		"go_mill_field_from_wheelwright":
			GameState.pending_spawn = Vector2(780, 72)
			call_deferred("_change_map", "res://scenes/mill_field.tscn")
		"sail_to_wood_island":
			GameState.pending_spawn = Vector2(576, 535)
			GameState.pending_travel_scene = "res://scenes/wood_island.tscn"
			GameState.register_boat_trip("isla de la madera")
			call_deferred("_change_map", "res://scenes/boat_travel.tscn")
		"sail_to_lake_dock", "sail_to_mill":
			GameState.pending_spawn = Vector2(580, 480)
			GameState.pending_travel_scene = "res://scenes/lake_dock.tscn"
			GameState.register_boat_trip("embarcadero del lago")
			call_deferred("_change_map", "res://scenes/boat_travel.tscn")
		"go_sheep_farm":
			GameState.pending_spawn = Vector2(576, 585)
			call_deferred("_change_map", "res://scenes/sheep_farm.tscn")
		"go_village_from_farm":
			GameState.pending_spawn = Vector2(816, 78)
			call_deferred("_change_map", "res://scenes/game.tscn")
		"go_spinner_yard":
			GameState.pending_spawn = Vector2(1080, 470)
			call_deferred("_change_map", "res://scenes/spinner_yard.tscn")
		"go_mill_from_spinner":
			GameState.pending_spawn = Vector2(70, 470)
			call_deferred("_change_map", "res://scenes/mill_field.tscn")
		"go_lake_dock":
			GameState.pending_spawn = Vector2(1070, 470)
			call_deferred("_change_map", "res://scenes/lake_dock.tscn")
		"go_spinner_from_dock":
			GameState.pending_spawn = Vector2(75, 470)
			call_deferred("_change_map", "res://scenes/spinner_yard.tscn")
		"open_rope_puzzle", "open_lumber_puzzle", "begin_wheelwright_forge", "open_wheelwright_forge", "restart_forge_round", "open_mill_operation", "board_train", "depart_train":
			# The puzzle owns the movement lock until the workshop panel is closed.
			pass
		_:
			player.enable_controls()


func _change_map(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
