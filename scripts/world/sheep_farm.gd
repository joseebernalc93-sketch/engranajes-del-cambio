extends Node2D

const ESTATE := preload("res://assets/gba/environment/sheep_estate_v5.png")
const SHEEP_SHEET := preload("res://assets/gba/environment/sheep_graze_sheet.png")
const STEAM_TEXTILE_MACHINE := preload("res://scripts/world/wool_carder.gd")
const STEAM_SCRIPT := preload("res://scripts/world/estate_steam.gd")

const SHEEP_FRAME_SIZE := Vector2(543.0, 724.0)
const SHEEP_POSITIONS := [
	Vector2(530, 181), Vector2(594, 171), Vector2(667, 181),
	Vector2(534, 208), Vector2(603, 210), Vector2(680, 214),
	Vector2(553, 260), Vector2(645, 264),
]

var sheep_sprites: Array[AnimatedSprite2D] = []
var elapsed := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()
	call_deferred("_populate_farm")


func _draw() -> void:
	draw_texture_rect(ESTATE, Rect2(0, 0, 1152, 648), false)


func _process(delta: float) -> void:
	elapsed += delta
	for index in range(sheep_sprites.size()):
		var sheep := sheep_sprites[index]
		var cycle := elapsed / (13.0 + float(index % 3)) + float(index) * 0.23
		var period := int(floor(cycle))
		var part := fposmod(cycle, 1.0)
		var previous := _grazing_offset(index, period - 1)
		var next := _grazing_offset(index, period)
		var movement := smoothstep(0.0, 0.24, part)
		sheep.position = SHEEP_POSITIONS[index] + previous.lerp(next, movement)
		if part < 0.24 and absf(next.x - previous.x) > 0.5:
			sheep.flip_h = next.x < previous.x


func _grazing_offset(index: int, period: int) -> Vector2:
	var phase := float(index) * 2.1 + float(period) * 1.7
	return Vector2(sin(phase) * 5.0, cos(phase * 0.8) * 3.0)


func _populate_farm() -> void:
	var world := get_parent()
	if not world:
		return
	_spawn_sheep(world)
	_spawn_steam_textile_machine(world)
	var steam := Node2D.new()
	steam.set_script(STEAM_SCRIPT)
	steam.name = "FactorySteam"
	steam.position = Vector2(1002, 39)
	steam.height = 48.0
	steam.drift = 12.0
	steam.strength = 0.28
	world.add_child(steam)


func _spawn_sheep(world: Node2D) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("graze")
	frames.set_animation_loop("graze", true)
	frames.set_animation_speed("graze", 2.3)
	for frame_index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = SHEEP_SHEET
		frame.region = Rect2(frame_index * SHEEP_FRAME_SIZE.x, 0, SHEEP_FRAME_SIZE.x, SHEEP_FRAME_SIZE.y)
		frames.add_frame("graze", frame)

	for index in range(SHEEP_POSITIONS.size()):
		var sheep := AnimatedSprite2D.new()
		sheep.name = "Sheep%02d" % (index + 1)
		sheep.sprite_frames = frames
		sheep.animation = "graze"
		sheep.position = SHEEP_POSITIONS[index]
		var scale_factor := 0.078 + float(index % 4) * 0.003
		sheep.scale = Vector2(scale_factor, scale_factor)
		sheep.flip_h = index % 2 == 1
		sheep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sheep.modulate = Color(1.0, 0.98 - float(index % 3) * 0.025, 0.92, 1.0)
		world.add_child(sheep)
		sheep_sprites.append(sheep)
		sheep.play("graze", 0.88 + float(index % 5) * 0.055)
		sheep.set_frame_and_progress(index % 4, float(index % 3) / 3.0)


func _spawn_steam_textile_machine(world: Node2D) -> void:
	var machine := Node2D.new()
	machine.set_script(STEAM_TEXTILE_MACHINE)
	machine.name = "SteamTextileMachine"
	machine.position = Vector2(900, 263)
	world.add_child(machine)
