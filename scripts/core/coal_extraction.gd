extends RefCounted
## Six persistent workshop steps; all clocks are advanced by the owning world.
const Mission := preload("res://scripts/core/iron_mission.gd")
const TITLES := ["Reconocer la veta", "Asegurar el tramo", "Extraer el carbón", "Separar el material", "Equilibrar costales", "Sacar la carga"]
const GUIDES := ["Mueve la lámpara y señala las tres zonas de hulla negra y brillante.", "Arrastra cada puntal a la abertura que tiene su misma forma. Comprueba el refuerzo.", "Sigue las tres grietas: tres golpes separados por veta. El carbón cae en la vagoneta.", "Arrastra la hulla brillante a la vagoneta y la pizarra gris al cajón de descarte.", "Reparte las piezas entre cuatro costales. Compara cada uno con el peso de referencia.", "Completa los tres tramos de vía, ajusta los dos desvíos y prueba el recorrido hasta el elevador."]
const LESSONS := ["La hulla aporta el calor que necesita la caldera. La pizarra gris acompaña a la veta, pero no sirve de combustible.", "Los puntales sostienen la galería antes de trabajar. Cada refuerzo debe apoyar en sus dos extremos.", "Las grietas permiten desprender la hulla con golpes separados. La vagoneta recoge el material al pie de la veta.", "Separar la piedra evita transportar material que no alimenta el fuego y deja sitio para el carbón útil.", "Costales del mismo peso permiten organizar una carga regular. Combina trozos pequeños y grandes.", "Los raíles y los desvíos permiten sacar una carga pesada con menos esfuerzo. Comprueba la ruta antes de moverla."]
const HINTS := ["Ratón: mueve la lámpara y señala. Teclado: ← → y Espacio.", "Arrastra; o elige pieza (1–3), abertura (← →) y pulsa Espacio.", "Elige una veta con ← → o un toque. Espacio da un golpe.", "Arrastra cada pieza a su destino. Teclado: ← →, C para hulla y X para piedra.", "Arrastra entre costales; o usa ← →, 1–4 y Espacio. Vaciar permite redistribuir.", "Arrastra las vías. Teclado: 1–3, ← → y Espacio; Q/W cambian los desvíos."]
const SUPPORT_ORDER := [1, 0, 2]
const RAIL_ORDER := [0, 1, 2]
const SWITCH_ORDER := [1, 0]
const ROUTE := [Vector2(155, 395), Vector2(380, 395), Vector2(650, 395), Vector2(760, 465), Vector2(820, 465), Vector2(930, 395), Vector2(1030, 395)]
const ROUTE_SECONDS: float = 5.5
var mission: Mission
var refill: bool
var data: Dictionary
var hint: String = ""

func _init(model: Mission, replenish: bool = false) -> void:
	mission = model
	refill = replenish
	var key := "refill_extraction" if refill else "extraction"
	var old: Dictionary = mission.data.get(key, {})
	if int(old.get("version", 0)) < 3: mission.data[key] = _migrate(old)
	data = mission.data[key]
	for key_name in ["step", "selected_vein", "collected"]: data[key_name] = int(data[key_name])
	for key_name in ["supports", "damage", "sorted", "assignments", "rails", "switches"]:
		for index in data[key_name].size(): data[key_name][index] = int(data[key_name][index])
	hint = HINTS[step()]

func _migrate(old: Dictionary) -> Dictionary:
	var fresh := {"version": 3, "step": 0, "recognised": [false, false, false], "supports": [-1, -1, -1], "damage": [0, 0, 0], "fall": [1.0, 1.0, 1.0], "sorted": [0, 0, 0, 0, 0, 0], "assignments": [-1, -1, -1, -1, -1, -1, -1, -1], "rails": [-1, -1, -1], "switches": [0, 1], "selected_vein": 0, "elapsed": 0.0, "impact_age": 2.0, "collected": 0, "cart_x": 620.0, "wheel_travel": 0.0, "travelling": false, "route_time": 0.0, "done": false}
	if old.is_empty() and int(mission.data.refill_hits if refill else mission.data.hits) == 0: return fresh
	var legacy_sorted: Array = mission.data.refill_sorted if refill else mission.data.sorted
	var coal := int(old.get("collected", 0))
	if int(old.get("version", 0)) < 2:
		for index in legacy_sorted:
			if int(index) % 2 == 0: coal += 4
		coal = maxi(coal, int(old.get("ties", 0)) * 3)
	var previous_hits := int(mission.data.refill_hits if refill else mission.data.hits)
	var damage: Array = old.get("damage", [])
	var cracked := false
	for value in damage:
		if int(value) > 0: cracked = true
	if previous_hits == 0 and coal == 0 and not cracked and legacy_sorted.is_empty(): return fresh
	fresh.recognised = [true, true, true]
	fresh.supports = SUPPORT_ORDER.duplicate()
	fresh.step = 2
	if int(old.get("version", 0)) == 2 and damage.size() == 3: fresh.damage = damage.duplicate()
	else:
		var work := previous_hits * 3 / 2
		for index in 3: fresh.damage[index] = clampi(work - index * 3, 0, 3)
	if coal > 0:
		fresh.damage = [3, 3, 3]
		fresh.step = 3
		# A partially filled old chunk is kept as a whole chunk rather than discarded.
		for index in mini(3, ceili(float(coal) / 4.0)): fresh.sorted[index * 2] = 1
		for index in legacy_sorted:
			if int(index) % 2 == 1: fresh.sorted[int(index)] = 2
		fresh.collected = mini(12, ceili(float(coal) / 4.0) * 4)
	if coal >= 12:
		fresh.sorted = [1, 2, 1, 2, 1, 2]
		fresh.collected = 12
		fresh.assignments = [0, 0, 1, 1, 2, 2, 3, 3] if mission.easy else [0, 1, 2, 3, 2, 3, 0, 1]
		fresh.step = 5
	return fresh

func step() -> int:
	return clampi(int(data.step), 0, 5)

func allowed() -> bool:
	return not mission.blocked() and not bool(data.done) and (mission.stage() == 1 or refill)

func recovery() -> float:
	return 0.48 if mission.easy else 0.65

func masses() -> Array:
	return [1, 2, 1, 2, 1, 2, 1, 2] if mission.easy else [1, 1, 2, 2, 3, 3, 4, 4]

func target_mass() -> int:
	return 3 if mission.easy else 5

func bag_mass(bag: int) -> int:
	var weight := 0
	var weights := masses()
	for index in 8:
		if int(data.assignments[index]) == bag: weight += int(weights[index])
	return weight

func bags() -> int:
	var balanced := 0
	for bag in 4:
		if bag_mass(bag) == target_mass(): balanced += 1
	return balanced

func recognise(index: int) -> bool:
	if not allowed() or step() != 0 or index < 0 or index >= 6: return false
	if index >= 3:
		mission.fail("Esa zona es pizarra gris. Busca la hulla negra con reflejos brillantes; conserva las zonas que ya reconociste.")
		return false
	data.recognised[index] = true
	hint = "Hulla reconocida. Busca las otras zonas brillantes." if not can_confirm() else "Las tres zonas están reconocidas. Puedes continuar."
	mission.persist()
	return true

func _place_unique(key: String, slot: int, piece: int) -> bool:
	if slot < 0 or slot >= 3 or piece < 0 or piece >= 3: return false
	for index in 3:
		if int(data[key][index]) == piece: data[key][index] = -1
	data[key][slot] = piece
	mission.persist()
	return true

func place_support(slot: int, piece: int) -> bool:
	return _place_unique("supports", slot, piece) if allowed() and step() == 1 else false

func remove_support(slot: int) -> void:
	if not allowed() or step() != 1 or slot < 0 or slot >= 3: return
	data.supports[slot] = -1
	mission.persist()

func hit(index: int = -1) -> bool:
	if not allowed() or step() != 2 or float(data.impact_age) < recovery(): return false
	if float(data.fall.min()) < 0.85: return false
	if index < 0: index = int(data.selected_vein)
	if index < 0 or index >= 3 or int(data.damage[index]) == 3: return false
	data.selected_vein = index
	data.damage[index] = int(data.damage[index]) + 1
	data.impact_age = 0.0
	if int(data.damage[index]) == 3: data.fall[index] = 0.0
	hint = "La hulla se desprendió y cayó en la vagoneta." if int(data.damage[index]) == 3 else "La grieta se abre. Deja volver la piqueta antes del siguiente golpe."
	mission.persist()
	return true

func sort(index: int, coal_bin: bool) -> bool:
	if not allowed() or step() != 3 or index < 0 or index >= 6 or int(data.sorted[index]) != 0: return false
	if coal_bin != (index % 2 == 0):
		mission.fail("Separa la hulla negra y brillante de la pizarra gris. La piedra va al cajón de descarte; el carbón, a la vagoneta. Conservas las piezas bien separadas.")
		return false
	data.sorted[index] = 1 if coal_bin else 2
	if coal_bin: data.collected = mini(12, int(data.collected) + 4)
	hint = "Material separado. Continúa con las otras piezas."
	mission.persist()
	return true

func assign_piece(piece: int, bag: int) -> bool:
	if not allowed() or step() != 4 or piece < 0 or piece >= 8 or bag < -1 or bag >= 4: return false
	data.assignments[piece] = bag
	mission.persist()
	return true

func empty_bag(bag: int) -> void:
	if not allowed() or step() != 4 or bag < 0 or bag >= 4: return
	for index in 8:
		if int(data.assignments[index]) == bag: data.assignments[index] = -1
	mission.persist()

func place_rail(slot: int, piece: int) -> bool:
	return _place_unique("rails", slot, piece) if allowed() and step() == 5 and not bool(data.travelling) else false

func remove_rail(slot: int) -> void:
	if not allowed() or step() != 5 or bool(data.travelling) or slot < 0 or slot >= 3: return
	data.rails[slot] = -1
	mission.persist()

func toggle_switch(index: int) -> void:
	if not allowed() or step() != 5 or bool(data.travelling) or index < 0 or index >= 2: return
	data.switches[index] = 1 - int(data.switches[index])
	mission.persist()

func can_confirm() -> bool:
	match step():
		0: return not false in data.recognised
		1: return not -1 in data.supports
		2: return data.damage == [3, 3, 3] and float(data.fall.min()) >= 0.85
		3: return not 0 in data.sorted
		4: return not -1 in data.assignments
		5: return not -1 in data.rails and not bool(data.travelling)
	return false

func confirm() -> bool:
	if not allowed() or not can_confirm():
		hint = "Completa el trabajo de esta etapa antes de comprobarlo."
		return false
	if step() == 1 and data.supports != SUPPORT_ORDER:
		mission.fail("Un puntal no apoya en sus dos anclajes. Compara la inclinación con la abertura y recoloca los refuerzos; no se borra el trabajo anterior.")
		return false
	if step() == 4 and bags() != 4:
		mission.fail("Los costales tienen pesos diferentes. Compara cada uno con la referencia de la balanza y combina piezas pequeñas y grandes. Conservas el carbón y puedes redistribuirlo.")
		return false
	if step() == 5:
		if data.rails != RAIL_ORDER:
			mission.fail("La vía no enlaza sus extremos. Recoloca el tramo recto y las dos curvas para formar un camino continuo hasta el elevador.")
			return false
		if data.switches != SWITCH_ORDER:
			mission.fail("Un desvío conduce hacia los escombros. Sigue los raíles con la vista y cambia las palancas antes de mover la carga.")
			return false
		data.travelling = true
		data.route_time = 0.0
		hint = "El camino está preparado. Llevando la carga al elevador…"
	else:
		data.step = step() + 1
		hint = HINTS[step()]
	mission.persist()
	return true

func cart_position() -> Vector2:
	if step() != 5: return Vector2(float(data.cart_x), 414)
	var total := 0.0
	for index in ROUTE.size() - 1: total += ROUTE[index].distance_to(ROUTE[index + 1])
	var distance := clampf(float(data.route_time) / ROUTE_SECONDS, 0, 1) * total
	for index in ROUTE.size() - 1:
		var segment: float = ROUTE[index].distance_to(ROUTE[index + 1])
		if distance <= segment: return ROUTE[index].lerp(ROUTE[index + 1], distance / segment)
		distance -= segment
	return ROUTE.back()

func advance(delta: float) -> void:
	if not allowed() or delta <= 0: return
	data.elapsed = float(data.elapsed) + delta
	data.impact_age = minf(2, float(data.impact_age) + delta)
	for index in 3: data.fall[index] = minf(1.2, float(data.fall[index]) + delta)
	if bool(data.travelling):
		data.route_time = minf(ROUTE_SECONDS, float(data.route_time) + delta)
		var point := cart_position()
		data.wheel_travel = float(data.wheel_travel) + point.x - float(data.cart_x)
		data.cart_x = point.x
		if float(data.route_time) >= ROUTE_SECONDS:
			data.done = true
			data.travelling = false
			mission.data["refill_hits" if refill else "hits"] = 6
			mission.data["refill_sorted" if refill else "sorted"] = [0, 1, 2, 3, 4, 5]
			mission.finish_coal_batch(refill)
