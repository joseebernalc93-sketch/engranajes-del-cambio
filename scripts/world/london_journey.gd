extends RefCounted
## Narrative progress is independent of the reserved workshop checkpoints.
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const AREAS := ["platform", "hall", "street", "coach_depot", "industrial"]
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
	if bool(GameState.phase_two.city_transport.industrial_reached): return "Explora el distrito industrial. El cochero puede llevarte de regreso a la estación."
	if not state.arrived: return "Llegas a Londres. Espera a que el tren se detenga y baja al andén."
	if state.area == "coach_depot": return "Habla con William, el cochero. El viaje al distrito industrial cuesta 10 monedas."
	if state.city_reached: return "Explora Londres. Camina hacia abajo para encontrar la parada de coches al distrito industrial."
	if not state.guide_spoken: return "Habla con Henry, el guía del andén, y pregunta dónde está la salida."
	if not state.city_reached:
		if state.area == "platform": return "Sigue el andén hacia la derecha y cruza al vestíbulo de boleterías."
		return "Recorre el vestíbulo. La salida a Londres está a tu derecha."
	return "Explora los alrededores de la estación y conversa con los habitantes de Londres."

static func steps() -> Array[bool]:
	var state := ensure()
	return [bool(state.arrived), bool(state.guide_spoken), "hall" in state.positions or state.area in ["hall", "street", "coach_depot", "industrial"], bool(state.city_reached)]
