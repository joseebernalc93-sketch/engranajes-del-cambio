extends Node

func _ready() -> void:
	var watcher = preload("res://tests/completed_chapter_return_watcher.gd").new()
	EventBus.add_child(watcher)
	watcher.begin.call_deferred()
