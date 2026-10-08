class_name LumberWorkState
extends RefCounted
## Deterministic workshop simulation. Coordinates are in the 800 × 420 work surface.
## Rendering, inventory and opportunity accounting belong to the popup, never to physics.
signal changed
signal mistake(reason: String)
signal worked(action: String, point: Vector2)
signal finished

enum Stage { INSPECT, MEASURE, SECURE, SAW, PLANE, LOAD, COMPLETE }
const BOARD := Rect2(72, 184, 620, 88)
const CUT_X := 568.0
const TEMPLATE_WIDTH := 280.0
const LOAD_TARGETS := [0.36, 0.56, 0.76]

var easy: bool = true
var stage: int = Stage.INSPECT
var paused: bool = false
var seed_value: int = 0
var defects: Array[Dictionary] = []
var template_x: float = 0.0
var lens_position: Vector2 = Vector2(230, 218)
var length_cm: float = 120.0
var square_angle: float = 82.0
var marked_lines: int = 0
var mark_progress: float = 0.0
var wedge_hits: Array[int] = [0, 0, 0]
var wedge_inserted: Array[bool] = [false, false, false]
var pressure: float = 0.25
var cuts: int = 0
var passes: int = 0
var blade_depth: float = 0.22
var verified_loads: int = 0
var load_active: bool = false
var counterforce: float = 0.25
var deflection: float = 0.0
var stable_seconds: float = 0.0
var danger_seconds: float = 0.0
var clock: float = 0.0
var tool_position: Vector2 = Vector2(72, 202)
var tool_active: bool = false
var stroke_start: Vector2 = Vector2.ZERO
var stroke_age: float = 0.0
var stroke_distance: float = 0.0
var last_motion_clock: float = 0.0
var selected_tool: String = "template"
var message: String = "Arrastra la plantilla y examina la madera con la lupa."
var impact_age: float = 1.0
var last_hammer_clock: float = -10.0

func initialize(is_easy: bool, board_seed: int) -> void:
	easy = is_easy
	seed_value = board_seed
	var random := RandomNumberGenerator.new()
	random.seed = board_seed
	# Reserve an entire clean span, then distribute defects outside it.
	var clean_start := random.randf_range(100, 210)
	for index in 9:
		var x := random.randf_range(18, 602)
		while x > clean_start - 26 and x < clean_start + TEMPLATE_WIDTH + 26:
			x = random.randf_range(18, 602)
		defects.append({"x": x, "y": random.randf_range(14, 72), "radius": random.randf_range(8, 15), "kind": index % 3})

func template_safe() -> bool:
	for defect in defects:
		var x := float(defect.x)
		if x + float(defect.radius) >= template_x and x - float(defect.radius) <= template_x + TEMPLATE_WIDTH:
			return false
	return true

func angle_tolerance() -> float:
	return 3.5 if easy else 1.5

func pressure_safe() -> bool:
	return absf(pressure - 0.60) <= (0.18 if easy else 0.07)

func depth_safe() -> bool:
	return absf(blade_depth - 0.50) <= (0.18 if easy else 0.05)

func load_tolerance() -> float:
	return 2.4 if easy else 1.1

func adjust(tool: String, amount: float) -> void:
	if paused or is_zero_approx(amount): return
	match tool:
		"template": template_x = clampf(template_x + amount, 0, BOARD.size.x - TEMPLATE_WIDTH)
		"rule": length_cm = clampf(length_cm + amount, 100, 190)
		"square": square_angle = clampf(square_angle + amount, 78, 102)
		"vice": pressure = clampf(pressure + amount, 0, 1)
		"depth": blade_depth = clampf(blade_depth + amount, 0, 1)
		"lever": counterforce = clampf(counterforce + amount, 0, 1)
	changed.emit()

func confirm() -> void:
	if paused: return
	match stage:
		Stage.INSPECT:
			if not template_safe():
				_fail("La plantilla cruza un nudo, una fisura o una zona porosa. Estas discontinuidades debilitan la pieza: busca un tramo de veta continua antes de marcar.")
			else: _advance()
		Stage.SECURE:
			impact_age = 0
			if wedge_hits.min() < 3:
				_fail("La tabla oscila: una cuña todavía no está asentada. Revisa las tres ranuras y golpea la cuña del lado inestable antes de serrar.")
			elif not pressure_safe():
				_fail("La mordaza no tiene la presión adecuada. Gira la manivela hasta la marca verde: una sujeción floja permite vibraciones y apretar demasiado marca la madera.")
			else: _advance()
		Stage.LOAD: place_sack()

func hammer(index: int) -> void:
	if paused or stage != Stage.SECURE or index < 0 or index > 2 or wedge_hits[index] == 3: return
	if not wedge_inserted[index]:
		insert_wedge(index)
		return
	# A rapid repeated click never costs opportunities; the mallet must recover.
	if clock - last_hammer_clock < (0.12 if easy else 0.22): return
	last_hammer_clock = clock
	wedge_hits[index] += 1
	impact_age = 0
	worked.emit("hammer", Vector2(150 + index * 210, 265))
	changed.emit()

func insert_wedge(index: int) -> void:
	if paused or stage != Stage.SECURE or index < 0 or index > 2 or wedge_inserted[index]: return
	wedge_inserted[index] = true
	worked.emit("insert", Vector2(150 + index * 210, 282))
	changed.emit()

func begin_tool(point: Vector2) -> void:
	if paused or tool_active: return
	if stage == Stage.MEASURE:
		if absf(length_cm - 160) > (4.0 if easy else 1.0) or absf(square_angle - 90) > angle_tolerance():
			_fail("Ajusta el tope a 160 cm y la escuadra a 90° antes de incidir. Una medida incorrecta impide que la tabla encaje en la bancada del molino.")
			return
		var mark_x := 98.0 if marked_lines == 0 else CUT_X
		if point.distance_to(Vector2(mark_x, BOARD.position.y)) > (36 if easy else 24):
			message = "Comienza el trazo en el punto de latón, en el canto superior."
			return
	elif stage == Stage.SAW:
		var start_x := 466.0 if cuts % 2 == 0 else 636.0
		if absf(point.x - start_x) > 38:
			message = "Toma la sierra por el extremo iluminado. Alterna el recorrido."
			return
	elif stage == Stage.PLANE:
		if absf(point.x - BOARD.position.x) > 38 or absf(point.y - lane_y()) > 25:
			message = "Empieza en el canto izquierdo de la franja iluminada."
			return
	else: return
	tool_active = true
	stroke_start = point
	tool_position = point
	stroke_age = 0
	stroke_distance = 0
	last_motion_clock = clock
	mark_progress = 0

func lane_y() -> float:
	return 196.0 + mini(passes, 3) * 19.0

func move_tool(point: Vector2) -> void:
	if paused or not tool_active: return
	var travel := point - tool_position
	# Multiple pointer samples may arrive within one physics tick on fast touch screens.
	var sample_dt := maxf(1.0 / 120.0, clock - last_motion_clock)
	last_motion_clock = clock
	match stage:
		Stage.MEASURE:
			var distance_y := maxf(0, point.y - stroke_start.y)
			var expected_x := stroke_start.x + tan(deg_to_rad(square_angle - 90)) * distance_y
			# Pixel floor absorbs device jitter; angular error dominates longer strokes.
			var margin := maxf(3.0 if easy else 1.5, distance_y * tan(deg_to_rad(angle_tolerance())))
			if absf(point.x - expected_x) > margin or point.y < tool_position.y - 8:
				_fail("El gramil salió de la guía y el trazo quedó oblicuo. Deslízalo suavemente junto a la escuadra: la precisión del trazado determina la del corte.")
				return
			tool_position = Vector2(expected_x, clampf(point.y, BOARD.position.y, BOARD.end.y))
			mark_progress = clampf(distance_y / BOARD.size.y, 0, 1)
			worked.emit("scribe", tool_position)
			if mark_progress >= 1:
				marked_lines += 1
				worked.emit("mark", tool_position)
				cancel_tool()
				changed.emit()
				if marked_lines == 2: _advance()
		Stage.SAW:
			var direction := 1.0 if cuts % 2 == 0 else -1.0
			if absf(point.y - 202) > (30 if easy else 14):
				_fail("La hoja se apartó del trazo. Mantén la sierra alineada para no desperdiciar la pieza.")
				return
			if travel.x * direction < -(18.0 if easy else 7.0) or (stroke_age > 0.08 and absf(travel.x) / sample_dt > (1400.0 if easy else 850.0)):
				_fail("La hoja se encalló al forzar el movimiento. Reduce la velocidad y cambia de sentido al terminar el recorrido; la fricción exige una cadencia uniforme.")
				return
			tool_position = Vector2(clampf(point.x, 466, 636), 202)
			stroke_distance = absf(tool_position.x - stroke_start.x)
			worked.emit("saw", Vector2(CUT_X, 220))
			if (direction > 0 and point.x >= 636) or (direction < 0 and point.x <= 466):
				if stroke_age < (0.40 if easy else 0.65):
					_fail("El recorrido fue demasiado brusco: la sierra mordió la madera. Haz una pasada completa y uniforme.")
				elif stroke_age > (6.0 if easy else 3.6):
					message = "La hoja resbaló sin profundizar. Repite con un movimiento continuo."
					cancel_tool()
				else:
					cuts += 1
					cancel_tool()
					worked.emit("cut", Vector2(CUT_X, 245))
					changed.emit()
					if cuts == 5: _advance()
		Stage.PLANE:
			if blade_depth > (0.68 if easy else 0.55):
				_fail("La cuchilla sobresale demasiado y la garlopa se clavó. Retrae el hierro con la rueda de latón para retirar virutas finas sin arrancar la veta.")
				return
			if point.x < tool_position.x - (22 if easy else 9) or absf(point.y - lane_y()) > (24 if easy else 12):
				_fail("La garlopa se cruzó o volvió contra la veta. Avanza longitudinalmente por la franja iluminada y levanta la herramienta para regresar.")
				return
			tool_position = Vector2(clampf(point.x, BOARD.position.x, CUT_X), lane_y())
			stroke_distance = tool_position.x - stroke_start.x
			if not depth_safe():
				message = "La cuchilla está retraída: resbala sin retirar madera. Ajusta la rueda."
			else: worked.emit("plane", tool_position)
			if point.x >= CUT_X:
				if depth_safe():
					passes += 1
					worked.emit("plane_pass", tool_position)
					changed.emit()
				cancel_tool()
				if passes == 4: _advance()

func cancel_tool() -> void:
	tool_active = false
	mark_progress = 0
	stroke_age = 0
	stroke_distance = 0

func place_sack() -> void:
	if paused or stage != Stage.LOAD or load_active or verified_loads >= 3: return
	load_active = true
	stable_seconds = 0
	danger_seconds = 0
	impact_age = 0
	worked.emit("sack", Vector2(320, 184))
	changed.emit()

func tick(delta: float) -> void:
	if paused: return
	clock += delta
	impact_age += delta
	if tool_active: stroke_age += delta
	if stage != Stage.LOAD or not load_active: return
	var target := float(LOAD_TARGETS[verified_loads])
	var oscillation := sin(clock * (0.8 if easy else 2.4)) * (0.018 if easy else 0.045)
	var desired := (target + oscillation - counterforce) * 30.0
	# Damped elastic response, independent of rendering frame rate.
	deflection = lerpf(deflection, desired, 1.0 - exp(-delta * (4.0 if easy else 7.0)))
	if absf(deflection) <= load_tolerance():
		stable_seconds += delta
		danger_seconds = maxf(0, danger_seconds - delta)
	else:
		stable_seconds = 0
		danger_seconds += delta
	if danger_seconds > (4.0 if easy else 1.2):
		load_active = false
		_fail("La flecha superó el margen elástico. Compensa el peso con la palanca hasta que la aguja vuelva a verde. Conservas los sacos ya verificados; repetiremos únicamente esta carga.")
	elif stable_seconds >= 1.2:
		verified_loads += 1
		load_active = false
		stable_seconds = 0
		worked.emit("load", Vector2(320, 184))
		changed.emit()
		if verified_loads == 3: _advance()

func _fail(reason: String) -> void:
	if paused: return
	cancel_tool()
	paused = true
	message = reason
	mistake.emit(reason)

func resume() -> void:
	paused = false
	danger_seconds = 0
	cancel_tool()

func _advance() -> void:
	cancel_tool()
	stage += 1
	selected_tool = ["template", "rule", "wedge0", "saw", "depth", "lever", "done"][stage]
	message = ""
	changed.emit()
	if stage == Stage.COMPLETE: finished.emit()

func snapshot() -> Dictionary:
	return {"version": 2, "stage": stage, "seed": seed_value, "defects": defects.duplicate(true),
		"template_x": template_x, "lens": [lens_position.x, lens_position.y], "length": length_cm,
		"angle": square_angle, "marked_lines": marked_lines, "wedge_hits": wedge_hits.duplicate(), "wedge_inserted": wedge_inserted.duplicate(),
		"clamp": pressure, "cuts": cuts, "passes": passes, "depth": blade_depth,
		"loads": verified_loads, "load_active": load_active, "brace": counterforce,
		"deflection": deflection, "stable_seconds": stable_seconds, "danger_seconds": danger_seconds,
		"clock": clock, "selected_tool": selected_tool}

func restore(saved: Dictionary) -> void:
	if saved.is_empty(): return
	stage = clampi(int(saved.get("stage", 0)), 0, Stage.COMPLETE)
	var modern := int(saved.get("version", 1)) >= 2
	seed_value = int(saved.get("seed", seed_value))
	if modern and saved.get("defects") is Array:
		defects.assign(saved.defects)
	template_x = clampf(float(saved.get("template_x", 150)), 0, 340)
	var lens: Array = saved.get("lens", [230, 218])
	lens_position = Vector2(float(lens[0]), float(lens[1]))
	length_cm = clampf(float(saved.get("length", 120)), 100, 190)
	square_angle = clampf(float(saved.get("angle", 82)), 78, 102)
	marked_lines = clampi(int(saved.get("marked_lines", 0)), 0, 2)
	if modern:
		var hits: Array = saved.get("wedge_hits", [0, 0, 0])
		for index in 3: wedge_hits[index] = clampi(int(hits[index]), 0, 3)
	else:
		var fixings: Array = saved.get("fixations", [false, false, false])
		for index in 3: wedge_hits[index] = 3 if bool(fixings[index]) else 0
	var inserted: Array = saved.get("wedge_inserted", [wedge_hits[0] > 0, wedge_hits[1] > 0, wedge_hits[2] > 0])
	for index in 3: wedge_inserted[index] = bool(inserted[index])
	pressure = clampf(float(saved.get("clamp", 0.25)) / (1.0 if modern else 100.0), 0, 1)
	blade_depth = clampf(float(saved.get("depth", 0.22)) / (1.0 if modern else 100.0), 0, 1)
	counterforce = clampf(float(saved.get("brace", 0.25)) / (1.0 if modern else 100.0), 0, 1)
	cuts = clampi(int(saved.get("cuts", 0)), 0, 5)
	passes = clampi(int(saved.get("passes", 0)), 0, 4)
	verified_loads = clampi(int(saved.get("loads", 0)), 0, 3)
	load_active = bool(saved.get("load_active", false)) and stage == Stage.LOAD and verified_loads < 3
	deflection = float(saved.get("deflection", 0))
	stable_seconds = clampf(float(saved.get("stable_seconds", 0)), 0, 1.2)
	danger_seconds = maxf(0, float(saved.get("danger_seconds", 0)))
	clock = maxf(0, float(saved.get("clock", 0)))
	selected_tool = str(saved.get("selected_tool", ["template", "rule", "wedge0", "saw", "depth", "lever", "done"][stage]))
	# Old checkpoints may have been saved during a validated transition.
	if not modern and stage == Stage.INSPECT and bool(saved.get("selected", false)): stage = Stage.MEASURE
	if stage == Stage.MEASURE and marked_lines == 2: stage = Stage.SECURE
	if not modern and stage == Stage.SECURE and bool(saved.get("secured", false)): stage = Stage.SAW
	if stage == Stage.SAW and cuts == 5: stage = Stage.PLANE
	if stage == Stage.PLANE and passes == 4: stage = Stage.LOAD
	if stage == Stage.LOAD and verified_loads == 3: stage = Stage.COMPLETE
	var allowed: Array = [["template", "lens"], ["rule", "square", "scribe"], ["wedge0", "wedge1", "wedge2", "vice"], ["saw"], ["depth", "plane"], ["sack", "lever"], ["done"]][stage]
	if selected_tool not in allowed: selected_tool = str(allowed[0])
	cancel_tool()
