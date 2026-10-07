extends Control

signal impacted

var swing: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	pivot_offset = Vector2(48, 22)
	queue_redraw()


func strike(target: Vector2) -> void:
	cancel()
	position = target - Vector2(48, 22) + Vector2(-30, -46)
	rotation = -0.65
	scale = Vector2.ONE * 1.08
	visible = true
	swing = create_tween()
	swing.set_trans(Tween.TRANS_QUAD)
	swing.set_ease(Tween.EASE_IN)
	swing.set_parallel(true)
	swing.tween_property(self, "position", target - Vector2(48, 22), 0.15)
	swing.tween_property(self, "rotation", 0.0, 0.15)
	swing.tween_property(self, "scale", Vector2.ONE, 0.15)
	swing.chain().tween_callback(func(): impacted.emit())
	swing.set_parallel(false)
	swing.tween_property(self, "position", target - Vector2(48, 22) + Vector2(-6, -14), 0.08)
	swing.tween_property(self, "modulate:a", 0.0, 0.12)
	swing.tween_callback(_hide_hammer)


func cancel() -> void:
	if swing and swing.is_valid():
		swing.kill()
	_hide_hammer()


func _hide_hammer() -> void:
	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE


func _draw() -> void:
	draw_line(Vector2(48, 72), Vector2(48, 25), Color("8a4f25"), 9.0, true)
	draw_line(Vector2(48, 72), Vector2(48, 25), Color("d28a43"), 3.0, true)
	draw_rect(Rect2(19, 10, 58, 25), Color("30343a"), true)
	draw_rect(Rect2(19, 10, 58, 25), Color("c6ccd0"), false, 3.0)
	draw_line(Vector2(27, 17), Vector2(68, 17), Color(1, 1, 1, 0.35), 2.0)
