extends Button

var sack_index := 0
var session_id := 0


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or not is_visible_in_tree():
		return null
	var preview := TextureRect.new()
	preview.texture = preload("res://assets/items/flour_sack_v1.png")
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(52, 70)
	preview.size = Vector2(52, 70)
	preview.position = Vector2(-26, -35)
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"kind": "lumber_sack", "index": sack_index, "session": session_id}
