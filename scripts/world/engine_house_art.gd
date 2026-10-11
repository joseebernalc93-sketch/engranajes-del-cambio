extends RefCounted
## Approved three-space engine house. Actors and the coach remain independent sprites.
const YARD := preload("res://assets/phase2/engine_house_yard_v1.png")
const HALL := preload("res://assets/phase2/engine_house_hall_v1.png")
const ASSEMBLY := preload("res://assets/phase2/engine_house_assembly_v1.png")
const MURDOCH := preload("res://assets/phase2/murdoch_engineer_pixel_v1.png")
const HERO_SCALE: float = 1.55
const COACH_BERTH := Vector2(920, 445)
const COACHMAN_POSITION := Vector2(760, 470)
const COACH_LANDING := Vector2(625, 525)
const YARD_DOOR := Vector2(674, 395)
const HALL_OUTSIDE := Vector2(105, 435)
const HALL_LANDING := Vector2(225, 470)
const MURDOCH_POSITION := Vector2(580, 535)
const HALL_MOUNTING := Vector2(910, 390)
const ROOM_DOOR := Vector2(135, 435)
const ROOM_LANDING := Vector2(235, 485)
const BENCH := Vector2(700, 490)
const TEXTILE_EXIT := Vector2(1100, 430)

static func safe_position(area: String, at: Vector2) -> Vector2:
	# Earlier saves had a different footprint. Only relocate positions now inside scenery.
	if area == "industrial":
		if at.y >= 475 and (at.x < 385 or at.x > 760):
			return COACH_LANDING if at.y > 540 else Vector2(at.x, 445)
	elif area == "engine_room":
		if at.x >= 760 and at.y >= 465: return Vector2(700, at.y)
		if at.x <= 180 and at.y >= 465: return Vector2(235, at.y)
	elif area == "engine_hall":
		if at.x >= 210 and at.x <= 810 and at.y < 430: return Vector2(at.x, 450)
	return at
