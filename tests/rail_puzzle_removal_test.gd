extends Node

func _ready() -> void:
	var watcher := preload("res://tests/rail_puzzle_removal_watcher.gd").new()
	EventBus.add_child(watcher)
	watcher.begin.call_deferred()
