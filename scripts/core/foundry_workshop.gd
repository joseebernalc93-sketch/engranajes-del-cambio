extends RefCounted
## Durable work, never durable held inputs. Version 1 sessions migrate in place.
signal changed
signal mistake(reason: String)
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const TITLES := ["Medir y sujetar el hierro", "Repartir el calor", "Forjar con matrices", "Taladrar con control", "Limar y comprobar", "Probar con la manivela"]
const GUIDES := ["Mide largo y grosor; gira las dos mordazas para fijar la barra.", "Reparte el calor hasta tener las tres zonas en punto; después pulsa Continuar.", "Encaja una matriz, alinea la zona y baja la palanca del martillo.", "Sujeta la biela, alinea cada ojo y baja la broca poco a poco.", "Lima hacia delante sobre las rebabas y comprueba el encaje.", "Monta la biela y sus pasadores; gira tres vueltas y prueba el freno."]
const LESSONS := ["Medir antes de cortar evita desperdiciar hierro. Sujeta la pieza para trabajar con precisión.", "El hierro se ablanda, pero permanece sólido. Reparte el calor por toda la barra.", "Las matrices dan forma al hierro; el martillo de vapor sustituye el esfuerzo de muchos golpes manuales.", "La correa transmite movimiento. Una broca centrada y un avance suave producen un ojo preciso.", "Las rebabas impiden el ajuste. Una plantilla permite comprobar si las piezas son compatibles.", "La biela une el vaivén del pistón con el giro del volante. El freno comprueba el movimiento bajo carga."]
var data: Dictionary
var easy: bool
var hint := ""
var feedback := ""
var feed_held := false
var crank_held := false

func _init() -> void:
	Campaign.ensure()
	easy = GameState.is_easy_difficulty()
	var defaults := {"version": 2, "step": 0, "billet": -1, "billet_placed": false, "measured": [false, false], "ruler": 0.0, "caliper": 1.35, "clamps": [0.0, 0.0], "heat": 0.0, "heat_zones": [0.0, 0.0, 0.0], "heat_position": 0.5, "ready_seconds": 0.0, "air": 0.5, "heating": false, "zone": 0, "die": 0, "die_mounted": false, "aligned": true, "blank_offset": 0.0, "strikes": [0, 0, 0], "impact_age": 2.0, "position": 2, "bit": 0, "bit_mounted": false, "drill_clamped": false, "holes": [false, false], "depths": [0.0, 0.0], "drilling": -1, "drill_clock": 0.0, "feed": 0.0, "chatter": 0.0, "filed": [0, 0, 0], "file_age": 1.0, "interference": -1, "fitted": false, "link": false, "pins": [-1, -1], "running": false, "test_seconds": 0.0, "angle": 0.0, "turns": 0.0, "loaded_turns": 0.0, "brake": 0.0, "speed": 0.0, "review": "", "done": false, "reward_issued": false}
	var saved: Dictionary = GameState.phase_two.get("foundry", {})
	var old := not saved.is_empty() and int(saved.get("version", 1)) < 2
	if saved.is_empty():
		GameState.phase_two.foundry = defaults
		if Campaign.done("forge"):
			defaults.done = true
			defaults.reward_issued = true
	else:
		for key in defaults:
			if not saved.has(key): saved[key] = defaults[key].duplicate(true) if defaults[key] is Array else defaults[key]
	data = GameState.phase_two.foundry
	for key in ["strikes", "filed", "pins"]:
		for index in data[key].size(): data[key][index] = int(data[key][index])
	if old:
		data.heat_zones = [float(data.heat), float(data.heat), float(data.heat)]
		data.measured = [bool(data.billet_placed), bool(data.billet_placed)]
		data.clamps = [1.0, 1.0] if bool(data.billet_placed) else [0.0, 0.0]
		data.die_mounted = true
		data.bit_mounted = true
		data.drill_clamped = true
		data.depths = [1.0 if bool(data.holes[0]) else 0.0, 1.0 if bool(data.holes[1]) else 0.0]
		var old_drilling := int(data.drilling)
		if old_drilling in [0, 1] and not bool(data.holes[old_drilling]):
			data.depths[old_drilling] = clampf(float(data.drill_clock) / 1.2, 0, 1)
		data.turns = minf(3, float(data.test_seconds) * 0.6)
		data.version = 2
	if not data.has("heat_approved"): data.heat_approved = false
	stop_tools()
	data.feed = 0.0
	update_hint()

func step() -> int:
	return clampi(int(data.step), 0, 5)

func allowed() -> bool:
	return not bool(data.done) and str(data.review).is_empty()

func persist() -> void:
	update_hint()
	changed.emit()
	GameState.save_progress()

func stop_tools() -> void:
	feed_held = false
	crank_held = false
	data.drilling = -1
	data.running = false
	data.speed = 0.0

func fail(reason: String) -> void:
	if not allowed(): return
	stop_tools()
	data.review = reason
	Campaign.fail("forge", reason)
	mistake.emit(reason)
	persist()

func resume() -> void:
	if str(data.review).is_empty(): return
	if Campaign.remaining() == 0: Campaign.new_round()
	data.review = ""
	persist()

func select_billet(index: int) -> void:
	if not allowed() or step() != 0 or index not in [0, 1, 2]: return
	if int(data.billet) != index:
		data.measured = [false, false]
		data.clamps = [0.0, 0.0]
		data.caliper = 1.35
	data.billet = index
	data.billet_placed = false
	feedback = ""
	persist()

func place_billet() -> void:
	if not allowed() or step() != 0 or int(data.billet) < 0: return
	data.billet_placed = true
	persist()

func measure_length(value: float) -> void:
	if not allowed() or step() != 0 or not bool(data.billet_placed): return
	data.ruler = clampf(value, 0, 1)
	if absf(value - 0.5) < (0.13 if easy else 0.07):
		data.measured[0] = true
		feedback = "Largo: %s / pedido: 120" % ("80" if int(data.billet) == 0 else "120")
	changed.emit()

func measure_thickness(value: float) -> void:
	if not allowed() or step() != 0 or not bool(data.billet_placed): return
	var thickness := 0.5 if int(data.billet) == 2 else 1.0
	data.caliper = clampf(value, thickness, 1.4)
	if float(data.caliper) <= thickness + (0.09 if easy else 0.045):
		data.measured[1] = true
		feedback = "Grosor: %s / pedido: 30" % ("15" if int(data.billet) == 2 else "30")
	changed.emit()

func tighten(index: int, amount: float) -> void:
	if not allowed() or step() != 0 or not bool(data.billet_placed) or index not in [0, 1]: return
	data.clamps[index] = clampf(float(data.clamps[index]) + amount, 0, 1)
	changed.emit()

func set_air(value: float) -> void:
	if not allowed() or step() != 1 or bool(data.heat_approved): return
	data.air = clampf(value, 0, 1)
	changed.emit()

func heat_bar() -> void:
	if not allowed() or step() != 1 or bool(data.heat_approved): return
	data.heating = true
	persist()

func move_heat(value: float) -> void:
	if not allowed() or step() != 1 or bool(data.heat_approved): return
	data.heat_position = clampf(value, 0, 1)
	changed.emit()

func heat_ready() -> bool:
	for value in data.heat_zones:
		if float(value) < (0.65 if easy else 0.72) or float(value) > (0.94 if easy else 0.89): return false
	return true

func approve_heat() -> void:
	if not allowed() or step() != 1 or bool(data.heat_approved) or not heat_ready(): return
	data.heat_approved = true
	data.heating = false
	stop_tools()
	feedback = "Calor uniforme aprobado. Pulsa Continuar para pasar al martillo."
	persist()

func remove_bar() -> void:
	if not allowed() or step() != 1: return
	if not heat_ready():
		feedback = "Todavía falta repartir el calor. Las tenazas mantienen la barra sujeta; no pierdes oportunidades."
		changed.emit()
	else:
		approve_heat()

func choose_zone(value: int) -> void:
	if not allowed() or step() not in [2, 4]: return
	data.zone = clampi(value, 0, 2)
	data.aligned = true
	data.blank_offset = 0.0
	persist()

func align_blank(offset: float) -> void:
	if not allowed() or step() != 2: return
	var candidate := clampi(roundi(1.0 - offset / 155.0), 0, 2)
	var error := offset - (1 - candidate) * 155.0
	data.zone = candidate
	data.aligned = absf(error) <= (35 if easy else 19)
	data.blank_offset = 0.0 if bool(data.aligned) else error
	changed.emit()

func choose_die(value: int) -> void:
	if not allowed() or step() != 2: return
	data.die = clampi(value, 0, 2)
	data.die_mounted = true
	persist()

func strike() -> void:
	if not allowed() or step() != 2 or float(data.impact_age) < (0.55 if easy else 0.75): return
	if not bool(data.die_mounted) or not bool(data.aligned):
		feedback = "Encaja la matriz y alinea el hierro con un tope antes de golpear."
		return
	var zone := int(data.zone)
	if int(data.strikes[zone]) >= 2: return
	if int(data.die) != zone:
		fail("La matriz no corresponde a la zona bajo el martillo. Compara los huecos con el ojo pequeño, el cuello o el ojo grande. Conservas lo ya forjado.")
		return
	data.strikes[zone] = int(data.strikes[zone]) + 1
	data.impact_age = 0.0
	feedback = "La matriz ha dado forma al hierro."
	persist()

func move_jig(value: int) -> void:
	if not allowed() or step() != 3 or feed_held or float(data.feed) > 0.1: return
	data.position = clampi(value, 0, 4)
	persist()

func clamp_drill() -> void:
	if not allowed() or step() != 3: return
	data.drill_clamped = true
	persist()

func choose_bit(value: int) -> void:
	if not allowed() or step() != 3 or feed_held or float(data.feed) > 0.1: return
	data.bit = clampi(value, 0, 1)
	data.bit_mounted = true
	persist()

func drill() -> void:
	if not allowed() or step() != 3 or feed_held: return
	if not bool(data.drill_clamped) or not bool(data.bit_mounted):
		feedback = "Sujeta la biela y monta una broca antes de bajar la palanca."
		return
	var eye := 0 if int(data.position) == 0 else 1 if int(data.position) == 4 else -1
	if eye < 0:
		fail("El ojo debe coincidir con el eje del taladro. Gira el tornillo de avance hasta uno de los topes.")
		return
	if bool(data.holes[eye]): return
	if int(data.bit) != eye:
		fail("Compara diámetros: broca fina para el ojo pequeño y gruesa para el grande. El otro agujero se conserva.")
		return
	feed_held = true
	data.drilling = eye
	feedback = "Mantén para avanzar; suelta para retirar la broca."
	changed.emit()

func release_drill() -> void:
	feed_held = false
	data.drilling = -1
	changed.emit()

func file_zone(zone: int) -> void:
	if not allowed() or step() != 4 or zone not in [0, 1, 2] or float(data.file_age) < 0.16: return
	data.zone = zone
	data.filed[zone] = mini(3 if easy else 4, int(data.filed[zone]) + 1)
	data.file_age = 0.0
	data.interference = -1
	feedback = "Pasada útil: las rebabas se reducen."
	persist()

func fit_piece() -> void:
	if not allowed() or step() != 4: return
	for index in 3:
		if int(data.filed[index]) < (3 if easy else 4):
			data.interference = index
			feedback = "Roza en %s: lima la zona marcada y vuelve a probar." % ["el ojo pequeño", "el cuello", "el ojo grande"][index]
			persist()
			return
	data.fitted = true
	feedback = "La biela se asienta en ambos pasadores."
	persist()

func mount_link() -> void:
	if not allowed() or step() != 5: return
	data.link = true
	persist()

func place_pin(eye: int, pin: int) -> void:
	if not allowed() or step() != 5 or not bool(data.link) or crank_held or eye not in [0, 1] or pin not in [0, 1]: return
	for index in 2:
		if index != eye and int(data.pins[index]) == pin: data.pins[index] = -1
	data.pins[eye] = pin
	persist()

func lift_pin(eye: int) -> int:
	if not allowed() or step() != 5 or crank_held or eye not in [0, 1]: return -1
	var pin := int(data.pins[eye])
	data.pins[eye] = -1
	persist()
	return pin

func set_brake(value: float) -> void:
	if not allowed() or step() != 5: return
	data.brake = clampf(value, 0, 1)
	changed.emit()

func crank(amount: float) -> void:
	if not allowed() or step() != 5 or amount <= 0: return
	if not bool(data.link) or data.pins != [0, 1]:
		feedback = "Monta la biela y ajusta cada pasador en su ojo."
		return
	if float(data.brake) > (0.85 if easy else 0.72):
		feedback = "El freno está muy apretado. Aflójalo para recuperar el giro."
		data.speed = 0.0
		return
	var travel := minf(amount, 0.35) * (1.0 - float(data.brake) * 0.35)
	data.angle = float(data.angle) + travel
	data.turns = minf(3.0, float(data.turns) + travel / TAU)
	if float(data.brake) >= 0.2: data.loaded_turns = minf(1.0, float(data.loaded_turns) + travel / TAU)
	data.test_seconds = float(data.turns) / 0.6
	data.speed = travel * 20
	data.running = true
	feedback = "Giro libre comprobado. Aplica un poco de freno." if float(data.turns) >= 2 and float(data.loaded_turns) < 1 else "El pistón y el volante se mueven unidos."
	if float(data.turns) >= 3 and float(data.loaded_turns) >= 1:
		data.done = true
		stop_tools()
		if not bool(data.reward_issued):
			data.reward_issued = true
			Campaign.reward("forge")
		persist()
	changed.emit()

func can_confirm() -> bool:
	match step():
		0: return bool(data.billet_placed) and data.measured == [true, true] and float(data.clamps[0]) >= 0.95 and float(data.clamps[1]) >= 0.95
		1: return bool(data.heat_approved) or heat_ready()
		2: return data.strikes == [2, 2, 2]
		3: return bool(data.holes[0]) and bool(data.holes[1]) and not feed_held and float(data.feed) < 0.1
		4: return bool(data.fitted)
		5: return bool(data.link) and int(data.pins[0]) >= 0 and int(data.pins[1]) >= 0
	return false

func confirm() -> void:
	if not allowed() or not can_confirm(): return
	if step() == 0 and int(data.billet) != 1:
		fail("La barra no coincide con el pedido: 120 de largo y 30 de grosor. Elige otra y comprueba ambas medidas.")
		return
	if step() == 1:
		approve_heat()
		data.step = 2
		feedback = ""
		persist()
		return
	if step() == 5:
		if data.pins != [0, 1]:
			fail("Los pasadores están intercambiados. Pequeño junto al pistón y grande en el volante. Conservas la biela montada.")
		else: feedback = "Gira la manivela o mantén Espacio. Prueba una vuelta con freno ligero."
	else:
		data.step = step() + 1
		feedback = ""
	persist()

func advance(delta: float) -> void:
	if not allowed() or delta <= 0: return
	data.impact_age = minf(2.0, float(data.impact_age) + delta)
	data.file_age = minf(1.0, float(data.file_age) + delta)
	var metrics: Dictionary = GameState.phase_two.metrics
	metrics.active_seconds = float(metrics.active_seconds) + delta
	metrics.workshop_seconds.forge = float(metrics.workshop_seconds.get("forge", 0.0)) + delta
	# Approve a ready checkpoint before heating, even if its tools were stopped.
	if step() == 1 and bool(data.heat_approved): return
	if step() == 1 and heat_ready():
		approve_heat()
		return
	if step() == 1 and bool(data.heating):
		for index in 3:
			var distance := absf(index * 0.5 - (1.0 - float(data.heat_position)))
			var exposure := maxf(0.0, 1.0 - distance * 2.2)
			var rate := (0.025 + exposure * 0.12) * float(data.air) * 1.5 - (1.0 - float(data.air)) * 0.035
			data.heat_zones[index] = clampf(float(data.heat_zones[index]) + rate * delta, 0, 1.12)
		data.heat = (float(data.heat_zones[0]) + float(data.heat_zones[1]) + float(data.heat_zones[2])) / 3.0
		var orange := true
		for value in data.heat_zones:
			if float(value) < (0.65 if easy else 0.72) or float(value) > (0.94 if easy else 0.89): orange = false
		data.ready_seconds = float(data.ready_seconds) + delta if orange else 0.0
		if orange:
			approve_heat()
			return
		for index in 3:
			if float(data.heat_zones[index]) >= 1.08:
				data.heat_zones[index] = 0.5
				data.heating = false
				fail("Una zona se ha calentado demasiado. Cort ha recuperado la barra. Baja el aire y reparte el calor hacia las zonas más oscuras.")
				break
	if step() == 3:
		if feed_held and int(data.drilling) >= 0:
			data.feed = minf(1.0, float(data.feed) + delta * 0.9)
			var eye := int(data.drilling)
			data.depths[eye] = minf(1.0, float(data.depths[eye]) + delta * (0.22 if float(data.chatter) > 0.05 else 0.45))
			data.drill_clock = float(data.depths[eye]) * 1.2
			data.chatter = maxf(0.0, float(data.feed) - (0.78 if easy else 0.6))
			if float(data.depths[eye]) >= 1.0:
				data.holes[eye] = true
				release_drill()
				feedback = "Ojo perforado. Retira la broca antes de mover la mesa."
				persist()
		else:
			data.feed = maxf(0.0, float(data.feed) - delta * 2)
			data.chatter = maxf(0.0, float(data.chatter) - delta)
	if step() == 5:
		if crank_held:
			var remaining := minf(delta, 1.0)
			while remaining > 0 and allowed():
				var dt := minf(remaining, 0.05)
				crank(dt * 2.8)
				remaining -= dt
		else:
			data.speed = move_toward(float(data.speed), 0, delta * 8)
			data.running = false
	update_hint()
	changed.emit()

func update_hint() -> void:
	hint = ["1–3: barra · Espacio: colocar · R: regla · C: calibre · Q / E: mordazas", "Espacio: introducir · ← →: tenazas · ↑ ↓: aire · Tres zonas listas: Continuar", "← →: alinear · 1–3: matriz · Espacio: bajar y soltar palanca", "C: sujetar · ← →: avance · 1 / 2: broca · Mantén Espacio: perforar", "← →: zona · Espacio: pasada de lima · T: comprobar encaje", "E: montar · 1 / 2: pasadores · ↑ ↓: freno · Mantén Espacio: girar"][step()]
