extends RefCounted
## Six linked stages. All durable state lives in the chapter's JSON dictionary.
signal changed
signal mistake(reason: String)
signal stage_changed(stage: int)
signal finished
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const TITLES := ["Encontrar el camino", "Recolectar el combustible", "Ensamblar los engranajes", "Conectar las tuberías", "Encender la máquina", "Mantener la presión"]
const GEAR_ORDER := [1, 0, 2]
# N/E/S/W bit flags. Each circuit has two elbows and a straight section.
const PIPE_BASE := [3, 5, 9, 3, 5, 9]
const PIPE_SOLUTION := [2, 0, 1, 2, 0, 1]
const COAL_ITEM := "costal_carbon"
const REQUIRED_SECONDS: float = 120.0
var data: Dictionary
var easy: bool

func _init() -> void:
	Campaign.ensure()
	easy = GameState.is_easy_difficulty()
	var defaults := {"version": 1, "stage": 0, "started": false, "route": 0, "hazard_clock": 0.0, "review": "", "hits": 0, "hit_clock": 0.0, "sorted": [], "refill_sorted": [], "refill_hits": 0, "batch_issued": false, "gears": [-1, -1, -1], "pipes": [0, 1, 0, 1, 0, 1], "water_tested": false, "water": false, "lit": false, "fuel": 0.0, "pressure": 0.35, "valve": 0.5, "portion": 0, "fed": 0, "stable_seconds": 0.0, "danger_seconds": 0.0, "running": false, "complete": false, "production_seconds": 0.0}
	var saved: Dictionary = GameState.phase_two.get("iron_mission", {})
	var legacy_installed: bool = int(saved.get("stage", 0)) >= 3
	for gear in saved.get("gears", []):
		if int(gear) >= 0: legacy_installed = true
	if saved.is_empty(): GameState.phase_two.iron_mission = defaults
	else:
		for key in defaults:
			if not saved.has(key): saved[key] = defaults[key]
	data = GameState.phase_two.iron_mission
	if not data.has("biela_installed"): data.biela_installed = legacy_installed
	# JSON decodes numbers as floats; normalize discrete identities before comparisons.
	for key in ["gears", "pipes", "sorted", "refill_sorted"]:
		for index in data[key].size(): data[key][index] = int(data[key][index])

func stage() -> int:
	return clampi(int(data.stage), 0, 5)

func blocked() -> bool:
	return not str(data.review).is_empty() or bool(data.complete)

func persist() -> void:
	changed.emit()
	GameState.save_progress()

func start() -> void:
	data.started = true
	persist()

func advance() -> void:
	if blocked(): return
	data.danger_seconds = 0.0
	if stage() == 5:
		data.complete = true
		data.running = false
		# Mark first: inventory callbacks and repeated completion cannot duplicate rewards.
		if not Campaign.done("engine"): Campaign.reward("engine")
		finished.emit()
	else:
		data.stage = stage() + 1
		stage_changed.emit(stage())
	persist()

func fail(reason: String) -> void:
	if blocked(): return
	data.review = reason
	data.running = false
	data.danger_seconds = 0.0
	Campaign.fail("iron_mission", reason)
	mistake.emit(reason)
	persist()

func resume() -> void:
	if str(data.review).is_empty(): return
	if Campaign.remaining() == 0: Campaign.new_round()
	data.review = ""
	data.danger_seconds = 0.0
	# Keep passed stages, placed parts, classified fragments and stable seconds.
	# Restart with usable controls, without manufacturing or restoring consumed coal.
	if stage() == 5:
		data.pressure = 0.5
		data.valve = 0.5
		data.running = false
	persist()

func reach_route(index: int) -> void:
	if blocked() or not bool(data.started) or stage() != 0 or index != int(data.route): return
	data.route = index + 1
	if int(data.route) == 3: advance()
	else: persist()

func hit(refill: bool = false) -> void:
	if blocked() or (stage() != 1 and not refill): return
	var key := "refill_hits" if refill else "hits"
	if int(data[key]) >= 6: return
	var elapsed := float(data.hit_clock)
	if int(data[key]) > 0 and elapsed < (0.25 if easy else 0.45):
		fail("Los golpes demasiado seguidos desprenden roca suelta. Espera a que la piqueta vuelva a su posición; conservas los fragmentos extraídos.")
		return
	data[key] = int(data[key]) + 1
	data.hit_clock = 0.0
	persist()

func sort_fragment(index: int, coal_bin: bool, refill: bool = false) -> void:
	if blocked() or (stage() != 1 and not refill) or index < 0 or index >= 6: return
	var hit_key := "refill_hits" if refill else "hits"
	var marks_key := "refill_sorted" if refill else "sorted"
	if int(data[hit_key]) < 6 or index in data[marks_key]: return
	if coal_bin != (index % 2 == 0):
		fail("Ese fragmento pertenece al otro cajón. La hulla es negra y brillante; la pizarra es gris. Separarlas evita transportar piedra que no alimenta el fuego.")
		return
	data[marks_key].append(index)
	if data[marks_key].size() == 6:
		finish_coal_batch(refill)
	persist()

func finish_coal_batch(refill: bool = false) -> void:
	if blocked(): return
	if refill:
		if data.refill_sorted.size() != 6: return
		data.refill_hits = 0
		data.refill_sorted = []
		data.erase("refill_extraction")
		_give_coal(maxi(0, 4 - int(GameState.inventory.get(COAL_ITEM, 0))))
	elif stage() == 1 and data.sorted.size() == 6 and not bool(data.batch_issued):
		data.batch_issued = true
		data.stage = 2
		# The fuel is already packed into sacks; keep the old coal reward as knowledge only.
		GameState.inventory.erase("hulla")
		_give_coal(4)
		if not Campaign.done("mine"): Campaign.reward("mine", false)
		stage_changed.emit(stage())
	persist()

func _give_coal(amount: int) -> void:
	if amount <= 0: return
	# One atomic game save for both inventory and classification checkpoint.
	GameState.inventory[COAL_ITEM] = int(GameState.inventory.get(COAL_ITEM, 0)) + amount
	EventBus.inventory_changed.emit()

func install_biela() -> bool:
	if stage() != 2 or bool(data.biela_installed) or not GameState.has_item("biela"): return false
	data.biela_installed = true
	var count := int(GameState.inventory.biela) - 1
	if count <= 0: GameState.inventory.erase("biela")
	else: GameState.inventory.biela = count
	EventBus.inventory_changed.emit()
	persist()
	return true

func place_gear(slot: int, gear: int) -> void:
	if blocked() or stage() != 2 or not bool(data.biela_installed) or slot < 0 or slot >= 3 or gear < 0 or gear >= 3: return
	if gear in data.gears and int(data.gears[slot]) != gear: return
	data.gears[slot] = gear
	persist()

func test_gears() -> void:
	if blocked() or stage() != 2 or not bool(data.biela_installed): return
	if data.gears == GEAR_ORDER: advance()
	else: fail("Los dientes no engranan en todos los ejes. Compara los diámetros con las marcas del bastidor: una rueda pequeña no puede cubrir la distancia de una grande. Puedes retirar y recolocar las piezas.")

func rotate_pipe(index: int) -> void:
	if blocked() or stage() != 3 or index < 0 or index >= 6: return
	data.pipes[index] = posmod(int(data.pipes[index]) + 1, 4)
	persist()

static func pipe_ports(index: int, turns: int) -> int:
	var mask: int = PIPE_BASE[index]
	for step in posmod(turns, 4): mask = ((mask << 1) & 15) | (mask >> 3)
	return mask

func circuit_connected(row: int) -> bool:
	var start := row * 3
	# Left inlet -> down/up detour -> right outlet. Intermediate vertical straight.
	var first := pipe_ports(start, int(data.pipes[start]))
	var middle := pipe_ports(start + 1, int(data.pipes[start + 1]))
	var last := pipe_ports(start + 2, int(data.pipes[start + 2]))
	return (first & 8) != 0 and (first & 4) != 0 and (middle & 1) != 0 and (middle & 4) != 0 and (last & 1) != 0 and (last & 2) != 0

func test_water() -> void:
	if blocked() or stage() != 3: return
	data.water_tested = true
	if circuit_connected(0) and circuit_connected(1): advance()
	else: fail("El agua encuentra una unión abierta. Sigue ambos circuitos: depósito a caldera y agua fría al condensador. El condensador enfría el vapor separado del cilindro caliente; gira los tubos hasta cerrar cada recorrido.")

func fill_water() -> void:
	if blocked() or stage() != 4: return
	data.water = true
	persist()

func fuel_available() -> int:
	return int(data.portion) + int(GameState.inventory.get(COAL_ITEM, 0)) * 6

func feed() -> bool:
	if blocked() or stage() < 4: return false
	if int(data.portion) <= 0:
		if not GameState.has_item(COAL_ITEM): return false
		var count := int(GameState.inventory[COAL_ITEM]) - 1
		if count == 0: GameState.inventory.erase(COAL_ITEM)
		else: GameState.inventory[COAL_ITEM] = count
		data.portion = 6
	data.portion = int(data.portion) - 1
	data.fed = int(data.fed) + 1
	data.fuel = minf(1.5, float(data.fuel) + 0.24)
	GameState.phase_two.metrics.coal_used = int(GameState.phase_two.metrics.coal_used) + 1
	EventBus.inventory_changed.emit()
	persist()
	return true

func ignite() -> void:
	if blocked() or stage() != 4: return
	if not bool(data.water) or float(data.fuel) <= 0.0:
		fail("Antes de encender comprueba el agua y coloca carbón en el hogar. El combustible aporta calor y el agua produce vapor: la caldera necesita ambos insumos.")
		return
	# Require reserve before spending time on the two-minute trial.
	if fuel_available() < 8:
		fail("Necesitas una reserva para sostener el ensayo. Vuelve a Caleb y repón los costales; conservas los engranajes, las tuberías y el agua preparada.")
		return
	data.lit = true
	data.pressure = 0.5
	advance()

func set_valve(value: float) -> void:
	if blocked() or stage() != 5: return
	data.valve = clampf(value, 0.0, 1.0)
	changed.emit()

func run() -> void:
	if blocked() or stage() != 5: return
	data.running = not bool(data.running)
	persist()

func pressure_band() -> float:
	return 0.18 if easy else 0.10

func tick(delta: float) -> void:
	if blocked() or delta <= 0.0: return
	var metrics: Dictionary = GameState.phase_two.metrics
	metrics.active_seconds = float(metrics.active_seconds) + delta
	metrics.workshop_seconds.iron_mission = float(metrics.workshop_seconds.get("iron_mission", 0.0)) + delta
	data.hit_clock = minf(2.0, float(data.hit_clock) + delta)
	if stage() != 5 or not bool(data.running): return
	# Fixed substeps make a 120-second test and real frame time use identical physics.
	var remaining := delta
	while remaining > 0.00001 and not blocked() and bool(data.running):
		var step := minf(remaining, 0.05)
		remaining -= step
		data.fuel = maxf(0.0, float(data.fuel) - step * 0.012)
		# Closing the discharge retains steam but cannot create heat without fuel.
		var heat := minf(float(data.fuel) / 0.24, 1.0) * 0.20 + minf(float(data.fuel), 0.65) * 0.65
		var target := heat * (1.0 - (float(data.valve) - 0.5) * 0.84)
		data.pressure = move_toward(float(data.pressure), target, step * 0.075)
		var safe := absf(float(data.pressure) - 0.5) <= pressure_band()
		metrics.pressure_samples = int(metrics.pressure_samples) + 1
		metrics.pressure_duration = float(metrics.pressure_duration) + step
		metrics.pressure_error = float(metrics.pressure_error) + absf(float(data.pressure) - 0.5) * step
		data.danger_seconds = 0.0 if safe else float(data.danger_seconds) + step
		if safe: data.stable_seconds = minf(REQUIRED_SECONDS, float(data.stable_seconds) + step)
		if float(data.danger_seconds) >= (4.0 if easy else 2.0):
			fail("La presión salió de la franja segura. Si cae, añade una palada de carbón; si sube, abre un poco la descarga de vapor. El reloj solo cuenta con la aguja en verde. Conservas el tiempo estable y el montaje.")
		elif float(data.stable_seconds) >= REQUIRED_SECONDS - 0.0001:
			data.stable_seconds = REQUIRED_SECONDS
			advance()
	changed.emit()

func objective() -> String:
	if bool(data.complete): return "La máquina mueve la fábrica. Observa los telares y revisa tu trabajo en el cuaderno."
	if stage() == 2 and not bool(data.biela_installed):
		return "Entrega la biela de Cort a Murdoch en Ensamble del motor." if GameState.has_item("biela") else "Visita a Cort en la forja y fundición para fabricar la biela; conserva el carbón para Murdoch."
	return ["Habla con Caleb, baja en el elevador y cruza el túnel esperando ante los desprendimientos.", "Completa el taller del minero: reconoce, refuerza, extrae, separa, equilibra y transporta cuatro costales hasta el elevador.", "Lleva el carbón a Ensamble del motor y monta la transmisión de engranajes.", "Conecta el agua de la caldera y el circuito separado del condensador.", "Comprueba el agua, carga carbón y enciende la máquina.", "Mantén la presión estable durante dos minutos alimentando el fuego."][stage()]
