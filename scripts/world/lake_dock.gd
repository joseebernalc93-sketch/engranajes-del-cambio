extends Node2D

const BACKGROUND := preload("res://assets/gba/environment/lake_dock_v2.png")
const FISHING_BOATS := preload("res://assets/gba/environment/fishing_boats_v2.png")
const EMPTY_BOAT_ATLAS := preload("res://assets/gba/environment/mill_boat_dock_v1.png")
const WATER_SHADER := preload("res://assets/shaders/lake_dock_water.gdshader")
const SHORE_SHADER := preload("res://assets/shaders/boat_travel_shore.gdshader")

var travel_mode := false
var boats: Array[Sprite2D] = []
var elapsed := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var water_material := ShaderMaterial.new()
	water_material.shader = SHORE_SHADER if travel_mode else WATER_SHADER
	material = water_material
	_add_boat("FishingBoatWest", FISHING_BOATS, Rect2(30, 190, 835, 550), Vector2(260, 553), Vector2(145, 95), false)
	_add_boat("FishingBoatEast", FISHING_BOATS, Rect2(917, 190, 835, 550), Vector2(965, 579), Vector2(145, 95), true)
	if not travel_mode:
		_add_boat("PassengerRowboat", EMPTY_BOAT_ATLAS, Rect2(884, 392, 173, 465), Vector2(735, 593), Vector2(40, 108), false)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 1152, 648), false)


func _process(delta: float) -> void:
	elapsed += delta
	for index in range(boats.size()):
		var boat := boats[index]
		var phase := elapsed * 1.65 + index * 1.8
		boat.position.y = float(boat.get_meta("mooring_y")) + sin(phase) * 1.7
		boat.rotation = sin(phase * 0.82) * 0.009


func _add_boat(node_name: String, atlas: Texture2D, region: Rect2, location: Vector2, display_size: Vector2, mirrored: bool) -> void:
	var boat := Sprite2D.new()
	boat.name = node_name
	boat.texture = atlas
	boat.region_enabled = true
	boat.region_rect = region
	boat.region_filter_clip_enabled = true
	boat.position = location
	boat.scale = display_size / region.size
	boat.flip_h = mirrored
	boat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boat.set_meta("mooring_y", location.y)
	boats.append(boat)
	add_child(boat)
