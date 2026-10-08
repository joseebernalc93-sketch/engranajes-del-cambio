extends Node

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).contains("Validation"):
		push_error("Use the isolated validation project to protect player saves.")
		get_tree().quit(1)
		return
	var watcher := preload("res://tests/london_coach_watcher.gd").new()
	EventBus.add_child(watcher)
	watcher.begin.call_deferred()
