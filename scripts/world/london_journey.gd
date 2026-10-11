extends RefCounted
## Narrative progress is independent of the reserved workshop checkpoints.
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const AREAS := ["platform", "hall", "street", "coach_depot", "industrial", "mine_yard", "mine_house", "mine_gallery", "mine_face", "engine_hall", "engine_room", "textile_view", "forge_yard", "forge_hall"]
const COACH_STOPS := ["industrial", "mine_yard", "forge_yard"]
const COACH_ROUTES := {"engine": "industrial", "mine": "mine_yard", "forge": "forge_yard"}
const COACH_FARE: int = 10
const TITLES := ["Los andenes de Londres", "El vestíbulo de boleterías", "Londres · El primer paso"]

static func ensure() -> Dictionary:
	Campaign.ensure()
	if not GameState.phase_two.get("arrival", {}) is Dictionary or GameState.phase_two.get("arrival", {}).is_empty():
		GameState.phase_two["arrival"] = {"version": 1, "area": "platform", "elapsed": 0.0, "arrived": false, "guide_spoken": false, "clerk_spoken": false, "city_reached": false, "talked": [], "positions": {}}
	if not GameState.phase_two.has("city_transport"):
		GameState.phase_two["city_transport"] = {"outbound_trips": 0, "fares_paid": 0, "industrial_reached": false}
	return GameState.phase_two.arrival

static func objective() -> String:
	var state := ensure()
	if state.area in ["forge_yard", "forge_hall"]:
		if Campaign.done("forge"):
			return "La biela está lista: entrégala a Murdoch en Ensamble del motor." if GameState.has_item("biela") else "Cort terminó la biela. Continúa el montaje y el ensayo en Ensamble del motor."
		if state.area == "forge_yard": return "Entra en la fundición y fabrica la biela con Cort. El camino de la derecha vuelve al distrito industrial."
		var work: Dictionary = GameState.phase_two.get("foundry", {})
		var stage := clampi(int(work.get("step", 0)), 0, 5)
		return "Taller de Cort · %d / 6: %s. Conserva los costales para la caldera de Murdoch." % [stage + 1, preload("res://scripts/core/foundry_workshop.gd").TITLES[stage]]
	if state.area == "engine_hall": return "Habla con Murdoch. El arco del fondo conduce a la sala de montaje del motor."
	if state.area == "industrial": return "Entra por la puerta central de la casa de máquinas. Los caminos laterales llevan a la fundición y al pozo."
	if bool(GameState.phase_two.get("iron_mission", {}).get("started", false)):
		return preload("res://scripts/core/iron_mission.gd").new().objective()
	if state.area == "mine_yard": return "Habla con Caleb junto al pozo para preparar la extracción del carbón."
	if state.area == "engine_room": return "Acércate al motor para trabajar. La puerta de la izquierda vuelve a la nave de Murdoch."
	if bool(GameState.phase_two.city_transport.industrial_reached): return "Explora Ensamble del motor. El cochero puede llevarte de regreso a la estación."
	if not state.arrived: return "Llegas a Londres. Espera a que el tren se detenga y baja al andén."
	if state.area == "coach_depot": return "Habla con William y elige el motor, el pozo minero o la fundición. El pasaje cuesta 10 monedas."
	if state.city_reached: return "Explora Londres. Camina hacia abajo para encontrar la parada de coches al distrito industrial."
	if not state.guide_spoken: return "Habla con Henry, el guía del andén, y pregunta dónde está la salida."
	if not state.city_reached:
		if state.area == "platform": return "Sigue el andén hacia la derecha y cruza al vestíbulo de boleterías."
		return "Recorre el vestíbulo. La salida a Londres está a tu derecha."
	return "Explora los alrededores de la estación y conversa con los habitantes de Londres."

static func steps() -> Array[bool]:
	var state := ensure()
	return [bool(state.arrived), bool(state.guide_spoken), "hall" in state.positions or state.area in ["hall", "street", "coach_depot", "industrial"], bool(state.city_reached)]
