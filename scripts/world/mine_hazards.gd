extends Node2D
## Three timed roof falls on a single lane. Analytic stones restore from one clock.
const Mission := preload("res://scripts/core/iron_mission.gd")
const Art := preload("res://scripts/world/mine_art.gd")
const ZONES := [Rect2(345, 188, 94, 226), Rect2(605, 188, 94, 226), Rect2(860, 188, 94, 226)]
const CYCLE: float = 10.0
const FALL_SECONDS: float = 2.3
const SAFE_STOPS := [240.0, 510.0, 765.0]
const CHECKPOINTS := [460.0, 725.0, 1000.0]
var mission: Mission
var last_phases: Array[int] = [0, 0, 0]
signal warned

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func advance(delta: float) -> void:
	mission.data.hazard_clock = float(mission.data.hazard_clock) + maxf(0, delta)
	for index in 3:
		var current := phase(index)
		if current == 1 and last_phases[index] != 1:
			warned.emit()
		last_phases[index] = current
	queue_redraw()

func local_time(index: int) -> float:
	return fposmod(float(mission.data.hazard_clock) + index * 3.2, CYCLE)

func warning_seconds() -> float:
	return 2.5 if mission.easy else 1.6

func phase(index: int) -> int:
	var time := local_time(index)
	if time < warning_seconds(): return 1
	if time < warning_seconds() + FALL_SECONDS: return 2
	if time < warning_seconds() + FALL_SECONDS + 0.5: return 3
	return 0

func collision_at(point: Vector2) -> bool:
	for index in 3:
		if phase(index) == 2 and local_time(index) - warning_seconds() > 0.55 and ZONES[index].grow(8).has_point(point - Vector2(0, 5)):
			return true
	return false

func safe_position(point: Vector2) -> Vector2:
	for index in 3:
		if ZONES[index].grow(20).has_point(point - Vector2(0, 5)):
			return Vector2(SAFE_STOPS[index], Art.FLOOR_Y)
	return Vector2(240, Art.FLOOR_Y)

func stone_size(index: int) -> float:
	return 8.0 + (index * 7 % 11)

func _draw() -> void:
	if mission == null: return
	for index in 3:
		var state := phase(index)
		if state == 0: continue
		var rect: Rect2 = ZONES[index]
		var time := local_time(index)
		for grain in 16:
			var x := rect.position.x + 8 + fposmod(grain * 23.0 + index * 7, rect.size.x - 16)
			if state == 1:
				var y := Art.ROOF_Y + fposmod(time * 80 + grain * 21, 215)
				draw_rect(Rect2(x, y, 2, 3), Color(0.74, 0.66, 0.50, 0.65))
			else:
				var age := time - warning_seconds() - grain * 0.08
				if age < 0: continue
				var impact := sqrt(2.0 * (Art.FLOOR_Y - Art.ROOF_Y - 8) / 650.0)
				var y := Art.ROOF_Y + 325.0 * age * age
				if age >= impact:
					var bounce := age - impact
					y = Art.FLOOR_Y - 6 - maxf(0, 90 * bounce - 325 * bounce * bounce)
				var size_value := stone_size(grain)
				var alpha := 1.0 - smoothstep(warning_seconds() + FALL_SECONDS, warning_seconds() + FALL_SECONDS + 0.5, time)
				draw_set_transform(Vector2(x, y), age * (1 if grain % 2 == 0 else -1) * 2.5)
				draw_texture_rect(Art.part(3), Rect2(-Vector2.ONE * size_value * 0.5, Vector2.ONE * size_value), false, Color(1, 1, 1, alpha))
				draw_set_transform(Vector2.ZERO)
