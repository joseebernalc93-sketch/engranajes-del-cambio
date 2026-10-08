extends RefCounted
## Deterministic workshop simulation, independent of rendering and input devices.
signal changed
signal mistake(reason: String)
signal finished
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
var workshop: String = "mine"
var easy: bool = false
var stage: int = 0
var clock: float = 0.0
var stable: float = 0.0
var danger: float = 0.0
var paused: bool = false
var complete: bool = false
var retry_reason: String = ""
var data: Dictionary = {}
var hint: String = ""
var pointer: Vector2 = Vector2(0.5, 0.5)

func _init(id: String = "mine", easy_mode: bool = false) -> void:
	workshop = id
	easy = easy_mode
	reset_stage()

func pace() -> float:
	return 0.25 if easy else 1.0

func tolerance() -> float:
	return 0.18 if easy else 0.02

func grace() -> float:
	return 4.0 if easy else 1.0

func phase_count() -> int:
	return 4 if workshop == "textile" else 6

func oscillator() -> float:
	return 0.5 + sin(clock * 2.4) * 0.45

func reset_stage() -> void:
	stable = 0.0
	danger = 0.0
	clock = 0.0
	data = {
		"count": 0,
		"selected": 0,
		"adjust": 0.2,
		"marks": [],
		"angle": 0.0,
		"heat": 0.85,
		"pressure": 0.5,
		"purged": false,
		"gates": [0.2, 0.2, 0.2],
		"crank": 0.0,
		"brake": 0.5,
		"sway": 0.0,
		"fuel": 0,
		"ore": 0,
		"packing": false,
		"bolts": [],
		"washers": [],
		"pipes": [],
		"belts": [],
		"tensions": [0.2, 0.2, 0.2, 0.2],
		"clutches": [],
		"elapsed": 0.0,
		"bales": 0.0,
		"stocks": [1.0, 1.0, 1.0, 1.0],
		"broken": [false, false, false, false],
		"stopped": [false, false, false, false],
		"break_at": [24.0, 50.0, 76.0, 100.0],
		"break_fired": [false, false, false, false],
		"running": false,
		"emergency": false,
		"inlet": 0.0,
	}
	hint = ""

func snapshot() -> Dictionary:
	return {"version": 1, "workshop": workshop, "stage": stage, "clock": clock, "stable": stable, "danger": danger, "paused": paused, "complete": complete, "retry_reason": retry_reason, "data": data.duplicate(true)}

func restore(saved: Dictionary) -> void:
	if str(saved.get("workshop", workshop)) != workshop: return
	stage = clampi(int(saved.get("stage", 0)), 0, phase_count() - 1)
	clock = maxf(0.0, float(saved.get("clock", 0.0)))
	stable = maxf(0.0, float(saved.get("stable", 0.0)))
	danger = maxf(0.0, float(saved.get("danger", 0.0)))
	paused = bool(saved.get("paused", false))
	complete = bool(saved.get("complete", false))
	retry_reason = str(saved.get("retry_reason", ""))
	var baseline := data.duplicate(true)
	baseline.merge(saved.get("data", {}), true)
	data = baseline
	# Drag holds and velocities are transient, never resumed unattended.
	data.sway = 0.0
	changed.emit()

func advance() -> void:
	if stage + 1 == phase_count():
		complete = true
		finished.emit()
	else:
		stage += 1
		reset_stage()
	changed.emit()

func fail(reason: String) -> void:
	if paused or complete: return
	paused = true
	retry_reason = reason
	danger = 0.0
	stable = 0.0
	mistake.emit(reason)
	changed.emit()

func resume() -> void:
	paused = false
	retry_reason = ""
	danger = 0.0
	stable = 0.0
	data.sway = 0.0
	# Recover a controllable neutral state; preserve successful assemblies and loads.
	if workshop == "mine" and stage == 5: data.brake = 0.5
	if workshop == "forge": data.heat = 0.85
	if workshop == "engine" and stage == 5:
		data.pressure = 0.5
		data.inlet = 0.5
	if workshop == "textile" and stage == 3:
		data.pressure = 0.5
		if float(data.elapsed) >= 120.0: data.elapsed = 0.0
	changed.emit()

func critical(condition: bool, delta: float, reason: String) -> void:
	danger = danger + delta if condition else 0.0
	if danger >= grace(): fail(reason)

func tick(delta: float) -> void:
	if paused or complete or delta <= 0.0: return
	clock += delta * pace()
	match workshop:
		"mine":
			if stage == 4:
				var cfm := airflow()
				stable = stable + delta if cfm >= 50.0 and cfm <= 75.0 else 0.0
				critical(data.marks.size() == 3 and (cfm < 50.0 or cfm > 75.0), delta, "El tiro de ventilación quedó fuera de 50–75 CFM. Reparte la apertura entre las tres compuertas: una lámpara no reemplaza el suministro de aire limpio.")
				if stable >= 1.2: advance()
			if stage == 5:
				data.sway = move_toward(float(data.sway), 0.0, delta * (0.2 + float(data.brake)))
				critical(absf(float(data.sway)) > 0.8, delta, "La vagoneta golpea los maderos. Frena antes de cada giro y eleva la carga sin tirones; los pozos dependían del cabrestante y de su operario.")
		"forge":
			if stage in [1, 2, 3]:
				data.heat = maxf(0.0, float(data.heat) - delta * pace() * 0.008)
				critical(absf(float(data.heat) - 0.85) > tolerance(), delta, "El hierro salió de su temperatura de trabajo. Reaviva el hogar para mantener la lupa amarilla; debe trabajarse caliente para expulsar escoria sin abrir grietas. Conservas lo ya trabajado.")
		"engine":
			if stage == 5:
				data.pressure = move_toward(float(data.pressure), float(data.inlet), delta * pace() * 0.25)
				var error := absf(float(data.pressure) - 0.5)
				stable = stable + delta if error <= tolerance() and bool(data.purged) and float(data.inlet) > 0.15 else 0.0
				critical(float(data.pressure) > 0.5 + tolerance(), delta, "La presión excede el régimen de 15 PSI. Cierra un poco la admisión y purga el condensado: el agua acumulada puede producir golpes en el cilindro.")
				if stable >= 1.2: advance()
		"textile":
			if stage == 3: _tick_textile(delta)
	changed.emit()

func airflow() -> float:
	return 25.0 + (float(data.gates[0]) + float(data.gates[1]) + float(data.gates[2])) * 25.0

func _tick_textile(delta: float) -> void:
	if not bool(data.running) or bool(data.emergency): return
	data.elapsed = minf(120.0, float(data.elapsed) + delta)
	data.pressure = maxf(0.0, float(data.pressure) - delta * pace() * 0.008)
	var active := 0
	for index in 4:
		if not bool(data.break_fired[index]) and float(data.elapsed) >= float(data.break_at[index]):
			data.broken[index] = true
			data.break_fired[index] = true
		if bool(data.broken[index]) or bool(data.stopped[index]) or float(data.stocks[index]) <= 0.0: continue
		active += 1
		data.stocks[index] = maxf(0.0, float(data.stocks[index]) - delta * pace() * 0.025)
	var error := absf(float(data.pressure) - 0.5)
	if error <= tolerance(): data.bales = minf(12.0, float(data.bales) + delta * float(active) * 0.027)
	critical(error > tolerance(), delta, "La caldera salió de su franja operativa. Alimenta el fuego cuando cae la presión y usa la descarga si sube. Conservas los fardos producidos.")
	if paused: return
	if float(data.elapsed) >= 120.0:
		data.running = false
		if float(data.bales) >= 10.0: advance()
		else: fail("Sonó el silbato antes de completar diez fardos. Revisa las lanzaderas y repara los hilos con cada telar detenido. Conservas la producción para un nuevo turno.")

func action(name: String, value: float = 0.0, index: int = -1) -> void:
	if paused or complete: return
	var selected := int(data.selected) if index < 0 else index
	match workshop:
		"mine": _mine(name, value, selected)
		"forge": _forge(name, value, selected)
		"engine": _engine(name, value, selected)
		"textile": _textile(name, value, selected)
	changed.emit()

func _mark(index: int, count: int) -> void:
	if index not in data.marks: data.marks.append(index)
	if data.marks.size() >= count: advance()

func _timed_hit() -> bool:
	if absf(oscillator() - 0.5) <= tolerance(): return true
	fail("La piqueta golpeó fuera del compás y desprendió escombros. Espera la zona verde: los golpes bruscos pueden desestabilizar una galería apuntalada." if workshop == "mine" else "El martinete impactó fuera del compás seguro. Espera la marca verde y compacta con regularidad; un golpe mal dirigido deforma la biela y pone en riesgo al operario.")
	return false

func _mine(name: String, value: float, index: int) -> void:
	match stage:
		0:
			if name == "adjust": data.adjust = clampf(value, 0.0, 1.0)
			if name == "vent": data.count = mini(3, int(data.count) + 1)
			if name == "confirm":
				if absf(float(data.adjust) - 0.5) <= tolerance() and int(data.count) >= 3: advance()
				else: fail("La malla no está ajustada o queda grisú. La malla de Davy disipa calor, pero no elimina metano: acciona el fuelle hasta recuperar una llama cálida y ajusta el cierre.")
		1:
			if name == "inspect":
				if index in [0, 2, 4]: _mark(index, 3)
				else: fail("Ese estrato es pizarra estéril. Busca brillo negro y capas compactas bajo la luz de la lámpara; transportar roca inútil consume trabajo y energía.")
		2:
			if name == "hit" and _timed_hit():
				data.count = int(data.count) + 1
				if int(data.count) >= 6: advance()
		3:
			if name == "sort":
				var coal := index % 2 == 0
				if (value > 0.5) == coal: _mark(index, 6)
				else: fail("La criba recibió material en el cajón equivocado. El carbón negro alimenta la caldera; las piedras claras se apartan para no reducir el poder calorífico.")
		4:
			if name == "adjust":
				var gate := clampi(index, 0, 2)
				data.gates[gate] = clampf(value, 0.0, 1.0)
				if gate not in data.marks: data.marks.append(gate)
		5:
			if name == "adjust": data.brake = clampf(value, 0.0, 1.0)
			if name == "crank":
				var turn := clampf(value, 0.0, 0.2)
				data.angle = float(data.angle) + turn * TAU
				data.sway = float(data.sway) + turn * (1.0 - float(data.brake)) * (1.0 if easy else 2.0)
				data.crank = minf(1.0, float(data.crank) + turn * (1.0 - float(data.brake) * 0.8))
				if float(data.crank) >= 1.0 and absf(float(data.sway)) < 0.8: advance()

func _forge(name: String, value: float, index: int) -> void:
	match stage:
		0:
			if name == "ore": data.ore = int(data.ore) + 1
			if name == "fuel": data.fuel = int(data.fuel) + 1
			if name == "confirm":
				if int(data.ore) == 3 and int(data.fuel) == 2: advance()
				else:
					data.ore = 0
					data.fuel = 0
					fail("La carga no respeta tres medidas de arrabio y dos de combustible. El coque va en el hogar separado: en la solera, el hierro recibe calor por reverberación y evita contaminarse con más carbono.")
		1:
			if name == "stir":
				data.angle = float(data.angle) + absf(value)
				if float(data.angle) >= TAU * 3.0: advance()
			if name == "heat": data.heat = move_toward(float(data.heat), 0.85, 0.06)
		2:
			if name == "skim": _mark(clampi(index, 0, 2), 3)
			if name == "heat": data.heat = move_toward(float(data.heat), 0.85, 0.06)
		3:
			if name == "heat": data.heat = move_toward(float(data.heat), 0.85, 0.06)
			if name == "transfer":
				if absf(float(data.heat) - 0.85) <= tolerance(): advance()
				else: fail("La lupa ya no está amarilla de forja. Recalienta antes de llevarla al yunque; el hierro frío resiste el conformado y puede agrietarse.")
		4:
			if name == "hit" and _timed_hit():
				if index == int(data.count) / 2:
					data.count = int(data.count) + 1
					if int(data.count) >= 8: advance()
				else: fail("Esa cara todavía no corresponde. Compacta dos golpes por cara y gira la lupa; el martinete expulsa escoria y forma una biela tenaz.")
		5:
			if name == "cool":
				if value > (0.3 if easy else 0.15): fail("La inmersión fue brusca. Enfría gradualmente para limitar tensiones en el hierro forjado; conservas la biela conformada.")
				else: data.heat = maxf(0.2, float(data.heat) - maxf(0.01, value))
			if name == "adjust": data.adjust = clampf(value, 0.0, 1.0)
			if name == "confirm":
				if float(data.heat) <= 0.3 and absf(float(data.adjust) - 0.5) <= tolerance(): advance()
				else: fail("La biela sigue caliente o el compás no coincide con el patrón. El ajuste de la transmisión requiere medir después del enfriamiento gradual.")

func _engine(name: String, value: float, index: int) -> void:
	match stage:
		0:
			if name == "piston": data.count = 1
			if name == "packing" and int(data.count) == 1: data.packing = true
			if name == "bolt":
				var order := [0, 2, 1, 3]
				if not bool(data.packing) or index != order[data.bolts.size()]: fail("Aprieta después de colocar el empaque y sigue el orden cruzado 1 → 3 → 2 → 4. Así la culata asienta sin fugas ni deformación.")
				else:
					data.bolts.append(index)
					if data.bolts.size() == 4: advance()
		1:
			if name == "washer" and index not in data.washers: data.washers.append(index)
			if name == "pipe":
				if index not in data.washers: fail("Falta la arandela de cobre. El condensador debe permanecer sellado para conservar el vacío sin enfriar el cilindro de trabajo.")
				elif index not in data.pipes:
					data.pipes.append(index)
					if data.pipes.size() == 3: advance()
		2:
			if name == "adjust": data.adjust = clampf(value, 0.0, 1.0)
			if name == "confirm":
				if absf(float(data.adjust) - 0.5) <= tolerance(): advance()
				else: fail("La distribución abre antes de tiempo. Centra la excéntrica: el vapor debe alternar entre las dos caras del émbolo.")
		3:
			if name == "adjust": data.adjust = clampf(value, 0.0, 1.0)
			if name == "arm":
				if absf(float(data.adjust) - 0.5) <= tolerance(): _mark(clampi(index, 0, 2), 3)
				else: fail("El vástago se desvía de la vertical. Alinea la articulación antes de fijarla; el movimiento paralelo de Watt guía el émbolo y reduce esfuerzos laterales.")
		4:
			if name == "ball":
				if index not in data.marks: data.marks.append(index)
			if name == "link":
				if data.marks.size() >= 2: advance()
				else: fail("El regulador necesita ambas esferas antes de enlazar la mariposa. Su equilibrio permite reducir el vapor cuando el motor acelera.")
		5:
			if name == "adjust": data.inlet = clampf(value, 0.0, 1.0)
			if name == "purge": data.purged = true

func _textile(name: String, value: float, index: int) -> void:
	index = clampi(index, 0, 3)
	match stage:
		0:
			if name == "belt":
				if index not in data.belts: data.belts.append(index)
				if data.belts.size() == 4: advance()
		1:
			if name == "adjust": data.tensions[index] = clampf(value, 0.0, 1.0)
			if name == "confirm":
				for tension in data.tensions:
					if absf(float(tension) - 0.5) > tolerance():
						fail("Una correa patina o está demasiado tirante. Centra cada polea intermedia: así la energía del árbol motor llega a los telares sin dañar sus cojinetes.")
						return
				advance()
		2:
			if name == "clutch": _mark(index, 4)
		3:
			if name == "start":
				data.running = true
				data.emergency = false
			if name == "feed":
				data.pressure = minf(1.0, float(data.pressure) + 0.025)
			if name == "vent": data.pressure = maxf(0.0, float(data.pressure) - 0.025)
			if name == "refill": data.stocks[index] = 1.0
			if name == "stop": data.stopped[index] = true
			if name == "knot":
				if not bool(data.stopped[index]): fail("Detén el telar antes de anudar. Acercar las manos a la lanzadera en movimiento era un peligro real del trabajo fabril. Conservas los fardos y el montaje.")
				else: data.broken[index] = false
			if name == "restart":
				if bool(data.broken[index]): hint = "Anuda la urdimbre antes de relanzar."
				else: data.stopped[index] = false
			if name == "emergency": data.emergency = true
