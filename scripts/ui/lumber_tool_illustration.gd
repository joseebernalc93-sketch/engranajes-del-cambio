extends Node2D
## A separate canvas layer places tool illustrations above the timber mesh.
func _draw() -> void:
	get_parent().get_parent().draw_tools(self)
