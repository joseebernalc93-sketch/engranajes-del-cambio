extends Node


func _ready() -> void:
	var returning := "--return" in OS.get_cmdline_user_args()
	GameState.pending_coach_destination = "res://scenes/carriage_depot.tscn" if returning else "res://scenes/station.tscn"
	var travel = preload("res://scenes/coach_travel.tscn").instantiate()
	travel.auto_change_destination = false
	add_child(travel)
	await travel.travel_finished
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()
