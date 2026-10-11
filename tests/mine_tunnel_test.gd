extends Node

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).contains("Validation"):
		push_error("Run in tmp/cart_validation_project to protect player saves.")
		get_tree().quit(1)
		return
	var watcher := preload("res://tests/mine_tunnel_watcher.gd").new()
	EventBus.add_child(watcher)
	watcher.begin.call_deferred()
