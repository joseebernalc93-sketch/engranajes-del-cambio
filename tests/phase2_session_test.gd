extends Node

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).contains("Validation"):
		get_tree().quit(1)
		return
	var watcher := preload("res://tests/phase2_session_watcher.gd").new()
	EventBus.add_child(watcher)
	watcher.begin.call_deferred()
