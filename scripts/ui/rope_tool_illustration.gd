extends Node2D
func _draw() -> void:
	get_parent().get_parent().draw_tools(self)
