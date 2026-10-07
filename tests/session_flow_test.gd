extends Node

func _ready() -> void:
	var watcher = preload("res://tests/session_flow_watcher.gd").new()
	EventBus.add_child(watcher)
	watcher.begin.call_deferred()
