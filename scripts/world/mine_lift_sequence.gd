extends Control
## Three deterministic shots: board indoors, travel in a dedicated shaft, alight.
## Elapsed time is the only animation clock, including after a saved-game restore.
const Art := preload("res://scripts/world/mine_art.gd")
const Audio := preload("res://scripts/world/railway_audio.gd")
const DURATION: float = 9.4
const TRAVEL_BEGIN: float = 2.0
const TRAVEL_END: float = 7.6
const DEPTH_Y: float = 1800.0
const SIZE := Vector2(1152, 648)
const SHAFT_FEET := Vector2(576, 432)
var elapsed: float = 0.0
var returning: bool = false
var hero_height: float = 60.0
var person: Texture2D
var walking_left: Array[Texture2D] = []
var walking_right: Array[Texture2D] = []
var start := Vector2.ZERO
var camera_origin := Vector2.ZERO
var cage_feet := Vector2.ZERO
var gate_closed: float = 0.0
var wheel_angle: float = 0.0
var audio_step: int = -1

func _ready() -> void:
	size = SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hide()

func configure(body: CharacterBody2D, height: float, from: Vector2, going_up: bool) -> void:
	var sprite := body.get_node("Sprite2D") as Sprite2D
	person = Art.hero(sprite.texture, Rect2(362, 0, 362, 362))
	walking_left.clear()
	walking_right.clear()
	for column in 3:
		walking_left.append(Art.hero(sprite.texture, Rect2(column * 362, 362, 362, 362)))
		walking_right.append(Art.hero(sprite.texture, Rect2(column * 362, 724, 362, 362)))
	hero_height = height
	start = from
	returning = going_up
	audio_step = -1

func pose(time: float) -> void:
	elapsed = clampf(time, 0.0, DURATION)
	var travel := smoothstep(TRAVEL_BEGIN, TRAVEL_END, elapsed)
	var depth := 1.0 - travel if returning else travel
	cage_feet = Vector2(576, lerpf(Art.HOUSE_LANDING.y, DEPTH_Y, depth))
	camera_origin = cage_feet - SHAFT_FEET
	gate_closed = smoothstep(1.3, TRAVEL_BEGIN, elapsed) * (1.0 - smoothstep(TRAVEL_END, 8.2, elapsed))
	wheel_angle = depth * TAU * 5.0
	var step := floori(elapsed * 4)
	if in_shaft() and step != audio_step and DisplayServer.get_name() != "headless":
		Audio.mechanism(self)
	audio_step = step
	show()
	queue_redraw()

func in_shaft() -> bool:
	return elapsed >= TRAVEL_BEGIN and elapsed < TRAVEL_END

func pause_audio(paused: bool) -> void:
	for child in get_children():
		if child is AudioStreamPlayer: child.stream_paused = paused

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stream_paused = false
			child.stop()
			child.stream = null

func _draw() -> void:
	if person == null: return
	if in_shaft():
		_draw_shaft()
	else:
		_draw_landing()
	# Short fades hide the camera cut while retaining one passenger in each shot.
	var cut_distance := minf(absf(elapsed - TRAVEL_BEGIN), absf(elapsed - TRAVEL_END))
	var darkness := 1.0 - smoothstep(0.0, 0.18, cut_distance)
	if darkness > 0.0: draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, darkness))

func _draw_shaft() -> void:
	var scroll := fposmod(camera_origin.y * 1.15, SIZE.y)
	for row in range(-1, 2):
		draw_texture_rect(Art.SHAFT, Rect2(0, row * SIZE.y - scroll, SIZE.x, SIZE.y), false)
	var height := hero_height * 2.65
	var dimensions := Art.cage_size(height)
	# Braided rope pixels stay attached to the cage while the walls scroll.
	var rope_bottom := SHAFT_FEET.y - dimensions.y + 8
	draw_line(Vector2(573, 0), Vector2(573, rope_bottom), Color("584020"), 6)
	draw_line(Vector2(576, 0), Vector2(576, rope_bottom), Color("c6a46a"), 3)
	for knot in range(0, ceili(rope_bottom), 6):
		draw_line(Vector2(573, knot), Vector2(579, knot + 3), Color("8c6837"), 2)
	Art.draw_cage(self, SHAFT_FEET, height, 1.0, person)

func _draw_landing() -> void:
	var boarding := elapsed < TRAVEL_BEGIN
	var in_house := not returning if boarding else returning
	draw_texture_rect(Art.HOUSE if in_house else Art.TUNNEL, Rect2(Vector2.ZERO, SIZE), false)
	var feet := Art.HOUSE_LANDING if in_house else Vector2(Art.LIFT_X, Art.FLOOR_Y)
	var offset := Vector2.ZERO
	if boarding:
		offset = (start - feet) * (1.0 - smoothstep(0.0, 1.3, elapsed))
	else:
		var destination := Art.HOUSE_EXIT - feet if in_house else Vector2(100, 0)
		offset = destination * smoothstep(8.2, DURATION, elapsed)
	var frame: int = [0, 1, 2, 1][floori(elapsed * 7.5) % 4]
	var pose_texture := person
	var moving := elapsed < 1.3 or elapsed > 8.2
	if moving and absf(offset.x) > 1.0:
		var going_left := offset.x > 0 if boarding else offset.x < 0
		pose_texture = walking_left[frame] if going_left else walking_right[frame]
	var height := hero_height * Art.HERO_SCALE
	var dimensions := Art.cage_size(height)
	draw_line(Vector2(feet.x, 0), feet - Vector2(0, dimensions.y - 8), Color("9f804e"), 3)
	Art.draw_cage(self, feet, height, gate_closed, pose_texture, offset)
