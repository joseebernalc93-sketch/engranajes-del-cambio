extends Node2D
const Art := preload("res://scripts/world/mining_cart_art.gd")
const Mission := preload("res://scripts/core/iron_mission.gd")
var mission: Mission

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mission.changed.connect(queue_redraw)

func _draw() -> void:
	var state: Dictionary = mission.data.get("refill_extraction" if mission.stage() > 1 and mission.data.has("refill_extraction") else "extraction", {})
	Art.rails(self)
	var loaded := int(state.get("collected", 0)) > 0 and not bool(state.get("done", false)) if int(state.get("version", 0)) >= 3 else int(state.get("collected", 0)) % 3 > 0
	Art.wagon(self, float(state.get("cart_x", 620)), 154 if mission.easy else 132, float(state.get("wheel_travel", 0)), loaded, int(state.get("stones", 0)) > 0)
