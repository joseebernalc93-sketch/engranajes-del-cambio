extends Node

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).contains("Validation"):
		push_error("Use the isolated validation project.")
		get_tree().quit(1)
		return
	var watcher := preload("res://tests/engine_house_watcher.gd").new()
	EventBus.add_child(watcher)
	watcher.begin.call_deferred()
