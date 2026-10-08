extends RefCounted
## One budget for the entire chapter. Checkpoints contain JSON values only.
const IDS := ["mine", "forge", "engine", "textile"]
const LABELS := ["La galería subterránea", "La fundición de pudelado", "El motor de Watt", "La nave textil de Cartwright"]
const TUTORS := ["Old Caleb", "Maese Cort", "Ingeniero Murdoch", "Maestro Cartwright"]
const REWARDS := ["hulla", "biela", "potencia_vapor", "pano_industrial"]
const FACTS := [
	"La hulla concentró energía para las calderas. La minería exigía ventilar el grisú; una lámpara de seguridad no sustituía el aire limpio.",
	"Darby empleó coque, obtenido de la hulla, para fundir hierro. En el pudelado de Cort, el fuego calienta el arrabio sin mezclarlo con el combustible. El batido reduce el carbono; el martillado expulsa escoria.",
	"El condensador separado de Watt evitaba enfriar el cilindro en cada carrera. El regulador ajustaba la entrada de vapor cuando cambiaba la velocidad.",
	"Un árbol motor y correas distribuían energía a muchos telares. Aumentó la producción, pero también la dependencia del reloj, el combustible y el mantenimiento."
]

static func ensure() -> void:
	if not GameState.phase_two.is_empty(): return
	GameState.phase_two = {"version": 1, "active": false, "intro_seen": false, "spent": 0, "round": 1, "completed": [], "work": {}, "glossary": [], "metrics": {"active_seconds": 0.0, "workshop_seconds": {}, "pressure_samples": 0, "pressure_duration": 0.0, "pressure_error": 0.0, "emergency_stops": 0, "coal_used": 0, "bales": 0, "errors": [], "events": []}}

static func total() -> int:
	return 15 if GameState.is_easy_difficulty() else 10

static func remaining() -> int:
	ensure()
	return maxi(0, total() - int(GameState.phase_two.spent))

static func done(id: String) -> bool:
	ensure()
	return id in GameState.phase_two.completed

static func unlocked(id: String) -> bool:
	var index := IDS.find(id)
	return index >= 0 and (index == 0 or done(IDS[index - 1]))

static func save_work(id: String, state: Dictionary) -> void:
	ensure()
	GameState.phase_two.work[id] = state.duplicate(true)

static func fail(id: String, reason: String) -> void:
	ensure()
	GameState.phase_two.spent = mini(total(), int(GameState.phase_two.spent) + 1)
	GameState.phase_two.metrics.errors.append({"workshop": id, "cause": reason, "remaining": remaining()})

static func new_round() -> void:
	ensure()
	GameState.phase_two.spent = 0
	GameState.phase_two.round = int(GameState.phase_two.round) + 1

static func reward(id: String) -> bool:
	if done(id): return false
	var index := IDS.find(id)
	if index < 0: return false
	GameState.phase_two.completed.append(id)
	GameState.phase_two.glossary.append({"id": REWARDS[index], "title": ContentDB.get_item(REWARDS[index]).get("name", id), "fact": FACTS[index]})
	if not GameState.has_item(REWARDS[index]): GameState.add_item(REWARDS[index])
	GameState.phase_two.metrics.events.append({"workshop": id, "event": "completed"})
	GameState.save_progress()
	return true

static func objective() -> String:
	for index in IDS.size():
		if not done(IDS[index]):
			return ["Visita a Caleb junto al canal y extrae hulla para la caldera.", "Lleva la hulla a la fundición. Fabrica la biela con Maese Cort.", "Entrega la biela a Murdoch y devuelve el movimiento a la fábrica.", "Conecta los cuatro telares y produce diez fardos durante el turno."][index]
	return "La fábrica vuelve a trabajar. Consulta tu balance y tus fichas en el cuaderno."
