extends Node2D

const DOCK_SCRIPT := preload("res://scripts/world/lake_dock.gd")
const ISLAND := preload("res://assets/gba/environment/wood_island_v2.png")
const BRUNO := preload("res://assets/gba/bruno_lumberjack_sheet_v1.png")
const SHORE_SHADER := preload("res://assets/shaders/boat_travel_shore.gdshader")

var island := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shore_material := ShaderMaterial.new()
	shore_material.shader = SHORE_SHADER
	material = shore_material
	if island:
		var bruno := Sprite2D.new()
		bruno.name = "Bruno"
		bruno.texture = BRUNO
		bruno.region_enabled = true
		bruno.region_rect = Rect2(296, 0, 295, 442)
		bruno.region_filter_clip_enabled = true
		bruno.scale = Vector2.ONE * 0.16
		bruno.position = Vector2(830, 205)
		bruno.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(bruno)
	else:
		var harbor := Node2D.new()
		harbor.set_script(DOCK_SCRIPT)
		harbor.name = "HarborBackdrop"
		harbor.travel_mode = true
		add_child(harbor)
	queue_redraw()


func _draw() -> void:
	if island:
		draw_texture_rect(ISLAND, Rect2(0, 0, 1152, 648), false)
