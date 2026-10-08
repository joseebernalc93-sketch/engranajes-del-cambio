class_name RopeWorkState
extends RefCounted
## Guided ropewalk mechanics. All time advances explicitly, never in rendering or input callbacks.
signal changed
signal mistake(reason: String)
signal worked(action: String, point: Vector2)
signal finished
enum Stage { CARD, MOUNT, TWIST, TENSION, BIND, PROOF, COMPLETE }
const LOAD_TARGETS := [0.36, 0.55, 0.74]
var easy: bool = true
var stage: int = Stage.CARD
var paused: bool = false
var clock: float = 0.0
var selected_tool: String = "card0"
var comb_passes: Array[int] = [0, 0, 0]
var portions: Array[float] = [0.8, 1.2, 1.0]
var mounted: Array[bool] = [false, false, false]
var twists: float = 0.0
var wheel_angle: float = 0.0
var wheel_velocity: float = 0.0
var carriage: float = 660.0
var brake: float = 0.5
var tension: float = 55.0
var stable_seconds: float = 0.0
var danger_seconds: float = 0.0
var binding_wraps: int = 0
var wrap_angle: float = 0.0
var binding_locked: bool = false
var proof_checks: int = 0
var load_active: bool = false
var proof_brake: float = 0.25
var proof_force: float = 0.0
var spring_velocity: float = 0.0
var message: String = ""
var tool_active: bool = false
var tool_position: Vector2 = Vector2(180, 150)
var stroke_start: Vector2 = Vector2.ZERO
var stroke_age: float = 0.0
var last_motion_clock: float = 0.0
var selected_bundle: int = 0
var cranking: bool = false
var wrap_active: bool = false
var pull_start: Vector2 = Vector2.ZERO

func initialize(is_easy: bool) -> void:
	easy = is_easy

func pace() -> float:
	return 0.25 if easy else 1.0

func grace() -> float:
	return 4.0 if easy else 1.0

func mass_tolerance() -> float:
	return 0.12 if easy else 0.04

func ideal_carriage() -> float:
	return 660.0 - minf(twists, 5.0) * 20.0

func load_target() -> float:
	return float(LOAD_TARGETS[mini(proof_checks, 2)])

func load_green() -> float:
	return 0.095 if easy else 0.045

func select_tool(tool: String) -> void:
	if paused: return
	selected_tool = tool
	if tool.begins_with("card") or tool.begins_with("portion"):
		selected_bundle = int(tool.right(1))
	changed.emit()

func adjust(tool: String, amount: float) -> void:
	if paused or is_zero_approx(amount): return
	if tool.begins_with("portion") and stage == Stage.MOUNT:
		var index := int(tool.right(1))
		if mounted[index]: return
		var other := -1
		for offset in [1, 2]:
			var candidate: int = (index + int(offset)) % 3
			if not mounted[candidate]:
				other = candidate
				break
		if other >= 0:
			var transfer := clampf(amount, maxf(0.4 - portions[index], portions[other] - 1.6), minf(1.6 - portions[index], portions[other] - 0.4))
			portions[index] += transfer
			portions[other] -= transfer
	elif tool == "carriage" and stage in [Stage.TWIST, Stage.TENSION]: carriage = clampf(carriage + amount, 500, 710)
	elif tool == "brake" and stage == Stage.TENSION: brake = clampf(brake + amount, 0, 1)
	elif tool == "lever" and stage == Stage.PROOF: proof_brake = clampf(proof_brake + amount, 0, 1)
	changed.emit()

func mount(index: int) -> void:
	if paused or stage != Stage.MOUNT or index < 0 or index > 2 or mounted[index]: return
	if absf(portions[index] - 1.0) > mass_tolerance() + 0.0001:
		_fail("Este cabo tiene un grosor desigual. Reparte la fibra con el calibre: tres cabos equilibrados comparten la carga; uno más grueso retuerce el conjunto de forma irregular.")
		return
	mounted[index] = true
	worked.emit("mount", Vector2(220, 145 + index * 42))
	if mounted.all(func(value: bool) -> bool: return value): _advance()
	else: changed.emit()

func begin_card(point: Vector2, index: int) -> void:
	if paused or stage != Stage.CARD or index < 0 or index > 2 or comb_passes[index] >= 2: return
	var y := 145.0 + index * 82
	if absf(point.x - 180) > 45 or absf(point.y - y) > 30:
		message = "Toma el rastrillo a la izquierda del manojo y avanza hacia la derecha."
		return
	selected_bundle = index
	stroke_start = Vector2(180, y)
	tool_position = stroke_start
	stroke_age = 0
	last_motion_clock = clock
	tool_active = true

func move_card(point: Vector2) -> void:
	if paused or not tool_active or stage != Stage.CARD: return
	var elapsed := maxf(1.0 / 120.0, clock - last_motion_clock)
	var velocity := point.distance_to(tool_position) / elapsed
	var angular_margin := tan(deg_to_rad(18.0 if easy else 8.0)) * maxf(point.x - stroke_start.x, 0)
	if absf(point.y - stroke_start.y) > 10.0 + angular_margin or point.x < tool_position.x - (20 if easy else 8) or (stroke_age > 0.06 and velocity > (1100 if easy else 650)):
		_fail("El rastrillo se trabó en la estopa. Peina a favor de las fibras, sin tirones ni inclinaciones: las púas separan el cáñamo largo de los restos cortos sin romperlo.")
		return
	tool_position = Vector2(clampf(point.x, 180, 640), point.y)
	last_motion_clock = clock
	worked.emit("card", tool_position)
	if point.x >= 635:
		tool_active = false
		comb_passes[selected_bundle] += 1
		worked.emit("card_pass", tool_position)
		if comb_passes == [2, 2, 2]: _advance()
		else: changed.emit()

func turn_wheel(radians: float) -> void:
	if paused or stage not in [Stage.TWIST, Stage.TENSION]: return
	if radians < -0.15:
		_fail("La rueda giró al revés y comenzó a destorcer los cabos. Mantén el sentido horario y acompaña el acortamiento con el carro.")
		return
	var turn := maxf(0, radians)
	wheel_angle = fposmod(wheel_angle + turn, TAU)
	if stage == Stage.TWIST: twists = minf(5, twists + turn / TAU)
	# Inertia gives a single pointer time to change from crank to carriage/brake.
	wheel_velocity = minf(2.0, wheel_velocity + turn * 0.4)

func begin_wrap() -> void:
	if paused or stage != Stage.BIND or binding_wraps >= 3: return
	wrap_active = true
	wrap_angle = 0

func turn_wrap(radians: float) -> void:
	if paused or not wrap_active or stage != Stage.BIND: return
	if radians < -0.09:
		wrap_active = false
		wrap_angle = 0
		_fail("El hilo retrocedió y la vuelta quedó suelta. Rodea el extremo en sentido horario; las vueltas ya aseguradas se conservan. El hilo encerado impide que los cabos se abran al soltar el banco.")
		return
	wrap_angle += maxf(0, radians)
	if wrap_angle >= TAU - 0.001:
		binding_wraps += 1
		wrap_angle = 0
		wrap_active = false
		worked.emit("wrap", Vector2(400, 215))
		message = "Vuelta asegurada. Suelta y toma el hilo para la siguiente." if binding_wraps < 3 else "Tres vueltas listas. Tira del hilo hacia abajo para trabar el lazo."
		changed.emit()

func release_wrap() -> void:
	if paused: return
	if wrap_active and wrap_angle > 0.12:
		wrap_angle = 0
		wrap_active = false
		_fail("Soltaste el hilo antes de cerrar la vuelta. Se ha aflojado únicamente esta vuelta; conserva las anteriores y completa el círculo antes de soltar.")
	wrap_active = false

func pull_binding(distance: float) -> void:
	if paused or stage != Stage.BIND or binding_wraps != 3: return
	if distance < 90:
		_fail("El lazo no quedó trabado. Tira del hilo hacia abajo hasta la marca: la ligadura necesita un cierre firme para resistir sin deshilacharse.")
		return
	binding_locked = true
	worked.emit("lock", Vector2(400, 315))
	_advance()

func place_sack() -> void:
	if paused or stage != Stage.PROOF or load_active or proof_checks >= 3: return
	# Each hoist starts from the last approved load, never from a failed spring impulse.
	proof_force = float(LOAD_TARGETS[proof_checks - 1]) if proof_checks > 0 else 0.0
	load_active = true
	stable_seconds = 0
	danger_seconds = 0
	spring_velocity = 0.3
	worked.emit("sack", Vector2(395, 288))
	changed.emit()

func tick(delta: float) -> void:
	if paused or delta <= 0: return
	clock += delta * pace()
	stroke_age += delta
	if stage in [Stage.TWIST, Stage.TENSION]:
		var driving := cranking or wheel_velocity > 0.08
		var speed := (1.6 if cranking else wheel_velocity) * pace()
		if speed > 0:
			wheel_angle = fposmod(wheel_angle + delta * TAU * speed, TAU)
			if stage == Stage.TWIST: twists = minf(5, twists + speed * delta)
		if not cranking: wheel_velocity = move_toward(wheel_velocity, 0, delta * 0.35)
		var desired := 55.0 + (carriage - ideal_carriage()) * 0.65
		if stage == Stage.TENSION: desired = 32.0 + brake * 40.0 + (8.0 if driving else -8.0) + sin(clock * 3) * 4.0 + (carriage - 560) * 0.3
		tension = lerpf(tension, clampf(desired, 0, 110), 1 - exp(-delta * 4))
		var critical := tension > (82 if stage == Stage.TWIST else 70) or tension < (22 if stage == Stage.TWIST else 35)
		danger_seconds = danger_seconds + delta if critical else maxf(0, danger_seconds - delta * 2)
		if danger_seconds > grace():
			danger_seconds = 0
			_fail("La cuerda sufrió sobretensión: acerca el carro o libera el freno. El cáñamo fatigado pierde resistencia; el artesano acompañaba el acortamiento para evitar la rotura." if tension > 70 else "Los cabos quedaron flojos y comenzaron a destorcerse. Aleja un poco el carro y recupera el giro: una cuerda sin tensión no mantiene su estructura helicoidal.")
			return
		if stage == Stage.TWIST and twists >= 5 and tension >= 45 and tension <= 70:
			carriage = 560
			_advance()
		elif stage == Stage.TENSION:
			stable_seconds = stable_seconds + delta if tension >= 45 and tension <= 70 and driving else 0.0
			if stable_seconds >= 3.0: _advance()
	elif stage == Stage.PROOF and load_active:
		var ripple := sin(clock * 4.0) * (0.025 if easy else 0.055)
		var desired := load_target() + (load_target() - proof_brake) * 0.85 + ripple
		# Damped spring, integrated in small steps for consistent elastic rebound at low FPS.
		var remaining := delta
		while remaining > 0:
			var dt := minf(remaining, 1.0 / 120.0)
			spring_velocity += ((desired - proof_force) * 30 - spring_velocity * 9) * dt
			proof_force += spring_velocity * dt
			remaining -= dt
		var safe := absf(proof_force - load_target()) <= load_green()
		stable_seconds = stable_seconds + delta if safe else 0.0
		danger_seconds = maxf(0, danger_seconds - delta * 2) if safe else danger_seconds + delta
		if danger_seconds > grace() or proof_force > 1.05:
			reset_failed_load()
			_fail("El dinamómetro excedió el margen de carga. Modula el freno para amortiguar el rebote del saco: un tirón brusco puede romper una cuerda que soportaría el mismo peso en reposo. Conservas las cargas aprobadas.")
		elif stable_seconds >= 1.2:
			proof_checks += 1
			load_active = false
			stable_seconds = 0
			danger_seconds = 0
			worked.emit("load", Vector2(395, 288))
			if proof_checks == 3: _advance()
			else: changed.emit()

func cancel_gesture() -> void:
	tool_active = false
	wrap_active = false
	wrap_angle = 0
	cranking = false
	wheel_velocity = 0

func resume() -> void:
	if stage == Stage.PROOF and not load_active: reset_failed_load()
	paused = false
	danger_seconds = 0
	message = ""

func reset_failed_load() -> void:
	# Preserve approved sacks and the six-stage work. Only unload the failed sack.
	load_active = false
	stable_seconds = 0.0
	danger_seconds = 0.0
	spring_velocity = 0.0
	proof_force = float(LOAD_TARGETS[proof_checks - 1]) if proof_checks > 0 else 0.0
	proof_brake = load_target()
	selected_tool = "sack"

func snapshot() -> Dictionary:
	var saved := {"version": 3}
	for field in ["stage", "clock", "selected_tool", "comb_passes", "portions", "mounted", "twists", "wheel_angle", "carriage", "brake", "tension", "stable_seconds", "danger_seconds", "binding_wraps", "binding_locked", "proof_checks", "load_active", "proof_brake", "proof_force", "spring_velocity"]:
		var value: Variant = get(field)
		saved[field] = value.duplicate() if value is Array else value
	return saved

func restore(saved: Dictionary) -> void:
	if saved.is_empty(): return
	if int(saved.get("version", 0)) < 3:
		# The previous six phases used selection+combing before mounting, and combined twist/tension.
		var old_stage := int(saved.get("stage", 0))
		stage = [0, 0, 1, 2, 4, 5, 6][clampi(old_stage, 0, 6)]
		comb_passes.assign(saved.get("comb_passes", [0, 0, 0]))
		if old_stage >= 2: comb_passes = [2, 2, 2]
		var old_hooks: Array = saved.get("mounted", [])
		if old_hooks.size() == 3:
			mounted.assign(old_hooks)
		else:
			for index in clampi(int(saved.get("mounted_strands", 0)), 0, 3): mounted[index] = true
		# The old mounting stage already validated equal diameter with its feed guide.
		if stage >= Stage.MOUNT: portions = [1.0, 1.0, 1.0]
		if stage >= Stage.TWIST:
			mounted = [true, true, true]
			portions = [1.0, 1.0, 1.0]
		twists = clampf(float(saved.get("twist_progress", 0)) / 20, 0, 5)
		if stage >= Stage.BIND: twists = 5
		carriage = ideal_carriage()
		binding_wraps = clampi(int(saved.get("binding_wraps", 0)), 0, 3)
		if stage >= Stage.PROOF:
			binding_wraps = 3
			binding_locked = true
		proof_checks = clampi(int(saved.get("proof_checks", 0)), 0, 3)
		proof_brake = clampf(float(saved.get("brake", 25)) / 100.0, 0, 1)
	else:
		for field in snapshot():
			if field == "version" or not saved.has(field): continue
			var current: Variant = get(field)
			var value: Variant = saved[field]
			if current is Array and value is Array and value.size() == 3: current.assign(value)
			elif current is int: set(field, int(value))
			elif current is float: set(field, float(value))
			elif current is bool: set(field, bool(value))
			elif current is String: set(field, str(value))
	stage = clampi(stage, 0, 6)
	if stage == Stage.CARD and comb_passes == [2, 2, 2]: stage = Stage.MOUNT
	if stage == Stage.MOUNT and mounted == [true, true, true]: stage = Stage.TWIST
	if stage == Stage.TWIST and twists >= 5 and tension >= 45 and tension <= 70: stage = Stage.TENSION
	if stage == Stage.BIND and binding_locked: stage = Stage.PROOF
	if stage == Stage.PROOF and proof_checks >= 3: stage = Stage.COMPLETE
	# Repair checkpoints saved by the previous implementation during an overload review.
	if stage == Stage.PROOF and saved.has("retry_reason"): reset_failed_load()
	var tools := [["card0", "card1", "card2"], ["portion0", "portion1", "portion2"], ["crank", "carriage"], ["crank", "brake"], ["thread", "pull"], ["sack", "lever"], ["done"]]
	if selected_tool not in tools[stage]: selected_tool = tools[stage][0]
	if selected_tool.begins_with("card") or selected_tool.begins_with("portion"): selected_bundle = int(selected_tool.right(1))
	cancel_gesture()
	paused = false

func _advance() -> void:
	stage = mini(stage + 1, Stage.COMPLETE)
	cancel_gesture()
	stable_seconds = 0
	danger_seconds = 0
	selected_tool = ["card0", "portion0", "crank", "crank", "thread", "sack", "done"][stage]
	message = ""
	changed.emit()
	if stage == Stage.COMPLETE: finished.emit()

func _fail(reason: String) -> void:
	if paused: return
	cancel_gesture()
	paused = true
	message = reason
	mistake.emit(reason)
