extends Node

const WATCHER := preload("res://tests/restart_phase_flow_watcher.gd")


func _ready() -> void:
	var watcher = WATCHER.new()
	EventBus.add_child(watcher)
	watcher.begin()
