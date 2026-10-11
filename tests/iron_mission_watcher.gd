extends Node
const EngineHouse := preload("res://scripts/world/engine_house_art.gd")
const Mission := preload("res://scripts/core/iron_mission.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Journey := preload("res://scripts/world/london_journey.gd")
const MineArt := preload("res://scripts/world/mine_art.gd")
const Hazards := preload("res://scripts/world/mine_hazards.gd")
const Lift := preload("res://scripts/world/mine_lift_sequence.gd")
const BACKUP := "user://iron_mission_backup.json"
var scene: Control
var failures: Array[String] = []
var checks: int = 0
var capture: bool = false

func begin() -> void:
	capture = "--capture-ui" in OS.get_cmdline_user_args()
	if "--restore-iron" in OS.get_cmdline_user_args():
		_restore_files()
		get_tree().quit()
		return
	if "--read-iron" in OS.get_cmdline_user_args(): await _read()
	else: await _write()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _switch(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await _settle()

func _freeze() -> void:
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.application_focused = true
	scene.iron_popup.set_process(false)
	scene.iron_popup.application_focused = true

func _write() -> void:
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	FileAccess.open(BACKUP, FileAccess.WRITE).store_string(JSON.stringify(backups))
	for difficulty in ["facil", "dificil"]:
		await _switch("res://scenes/ui/main_menu.tscn")
		GameState.reset_progress(false)
		GameState.run_started = true
		GameState.difficulty = difficulty
		GameState.phase_complete = true
		GameState.coins = 87
		var arrival := Journey.ensure()
		arrival.arrived = true
		arrival.elapsed = 9.5
		await _switch(GameState.PHASE_TWO_SCENE)
		scene = get_tree().current_scene
		_freeze()
		var mission: Mission = scene.iron
		_check(Campaign.total() == (15 if difficulty == "facil" else 10), "Shared chapter opportunity budget")
		scene._set_area("coach_depot", Vector2(610, 560))
		scene._interact("coachman")
		var choices: Array[Node] = scene.hud.dialogue_options.find_children("*", "Button", true, false)
		_check(choices.size() == 4 and not choices[1].disabled and not choices[2].disabled and choices[3].disabled, "Engine, mine and foundry destinations available")
		(choices[1] as Button).pressed.emit()
		_check(scene.dialogue_text.text.contains("El pozo minero") and GameState.coins == 87, "Mine selection names its destination before charging")
		scene._close_dialogue()
		_check(scene.ride.active and scene.ride.destination_area == "mine_yard" and GameState.coins == 77, "Mine trip charges ten exactly once")
		scene.ride.elapsed = 17.5
		var travel: Dictionary = scene.ride.snapshot()
		scene.ride.restore(travel)
		_check(scene.ride.destination_area == "mine_yard" and is_equal_approx(scene.ride.elapsed, 17.5), "Saved trip retains mine destination")
		scene.ride.complete()
		_check(scene.area == "mine_yard", "Coach arrives at new mine yard")
		_check(scene.player.position.distance_to(scene.actors.coachman.position) > 60, "Mine landing does not overlap coachman")
		await _shot(difficulty + "_01_patio")
		scene.player.position = scene.points.caleb + Vector2(-40, 15)
		scene._interact("caleb")
		_check(bool(mission.data.started) and scene.dialogue_text.text.contains("carbón"), "Caleb introduces the adventure")
		scene._close_dialogue()
		scene.player.position = scene.points.mine_door + Vector2(0, 20)
		scene._interact("mine_door")
		await get_tree().create_timer(0.6).timeout
		_check(scene.area == "mine_house", "Mine door opens the indoor winding-house before descending")
		scene.player.position = scene.points.lift + Vector2(0, 20)
		scene._interact("lift")
		scene._process(2.0)
		_check(is_equal_approx(scene.lift_elapsed, 2.0) and scene._blocked(), "Descent is an actual blocking animation")
		scene._show_journal()
		scene._process(2.0)
		_check(is_equal_approx(scene.lift_elapsed, 2.0), "Journal pauses lift animation")
		scene._hide_journal()
		scene._process(Lift.DURATION - 2.0)
		_check(scene.area == "mine_gallery" and scene.lift_elapsed < 0, "Lift reaches the underground gallery")
		mission.data.hazard_clock = 0.2
		_check(scene.hazards.phase(0) == 1 and not scene.hazards.collision_at(Vector2(390, MineArt.FLOOR_Y)), "Dust warning precedes harmful rockfall")
		mission.data.hazard_clock = scene.hazards.warning_seconds() + 0.8
		scene.player.position = Vector2(390, MineArt.FLOOR_Y)
		scene._process(0.01)
		_check(not str(mission.data.review).is_empty() and Campaign.remaining() == Campaign.total() - 1, "Rockfall costs one opportunity and opens explanation")
		var budget := Campaign.remaining()
		scene._process(4.0)
		mission.fail("duplicate")
		_check(Campaign.remaining() == budget, "Paused mistake cannot consume repeated opportunities")
		await _shot(difficulty + "_02_revision")
		scene._close_dialogue()
		_check(str(mission.data.review).is_empty() and mission.stage() == 0, "Continue resumes current stage")
		for index in 3:
			# Wait for each fall to clear, then walk the same horizontal lane as players.
			for wait_step in 110:
				if scene.hazards.phase(index) == 0 and scene.hazards.local_time(index) < 8.3: break
				scene._process(0.1)
			scene._navigate_pointer(Vector2(Hazards.CHECKPOINTS[index] + 10, MineArt.FLOOR_Y))
			for frame in 180:
				await get_tree().physics_frame
				scene._physics_process(1.0 / 60)
				scene._process(1.0 / 60)
				if scene.target == Vector2.INF: break
			scene._process(0.0)
		_check(mission.stage() == 1 and int(mission.data.route) == 3, "Walking gallery advances the first stage: %s stage=%d route=%d area=%s pos=%s blocked=%s" % [difficulty, mission.stage(), int(mission.data.route), scene.area, scene.player.position, scene._blocked()])
		await _shot(difficulty + "_03_galeria")
		await _walk_exit(Vector2(1095, MineArt.FLOOR_Y))
		_check(scene.area == "mine_face", "Walking right enters the separate extraction gallery")
		scene.player.position = scene.points.vein
		scene._interact("vein")
		_check(scene.coal_view.is_open() and scene._blocked(), "Coal vein opens the six-step mining workshop")
		preload("res://tests/coal_extraction_driver.gd").extract(scene)
		_check(int(mission.data.hits) == 6, "Six workshop steps complete the extraction batch")
		await _shot(difficulty + "_04_criba")
		_check(not scene.coal_view.is_open() and str(mission.data.review).is_empty(), "Delivery closes the completed workshop without leaving a review")
		_check(mission.stage() == 2 and GameState.has_item(Mission.COAL_ITEM, 4), "Three sacks plus reserve enter actual inventory")
		mission.sort_fragment(5, false)
		_check(int(GameState.inventory.get(Mission.COAL_ITEM, 0)) == 4, "Completed extraction cannot duplicate initial reward")
		_check(ContentDB.get_item_icon(Mission.COAL_ITEM) is AtlasTexture, "Coal inventory uses its own cropped sprite")
		scene._set_area("mine_yard", Vector2(70, 480))
		await _walk_exit(Vector2(28, 480))
		_check(scene.area == "industrial" and GameState.coins == 77, "Walking mine-to-factory road charges no additional fare")
		scene._set_area("forge_hall", Vector2(575, 550))
		scene._interact("cort")
		scene._close_dialogue()
		preload("res://tests/foundry_workshop_driver.gd").finish(scene)
		_check(Campaign.done("forge") and GameState.has_item("biela") and GameState.has_item(Mission.COAL_ITEM, 4), "Cort's six tasks manufacture the engine link while reserving fuel")
		scene._close_dialogue()
		scene._set_area("industrial", EngineHouse.YARD_DOOR + Vector2(0, 45))
		await _walk_exit(EngineHouse.YARD_DOOR)
		_check(scene.area == "engine_hall", "Factory entrance reaches the separate reception nave")
		scene.player.position = EngineHouse.HALL_MOUNTING + Vector2(0, 45)
		await _walk_exit(EngineHouse.HALL_MOUNTING + Vector2(0, -25))
		_check(scene.area == "engine_room", "The nave arch reaches the motor assembly room")
		scene.player.position = EngineHouse.BENCH + Vector2(-50, 35)
		scene._interact("engine_bench")
		_check(scene.dialogue_kind == "motor_biela", "Engine bench requests delivery of Cort's biela")
		scene._close_dialogue()
		_check(scene.iron_popup.is_open(), "Engine bench opens only after coal stage")
		mission.place_gear(0, 0)
		mission.test_gears()
		_check(mission.stage() == 2 and not str(mission.data.review).is_empty(), "Incorrect gear geometry does not pass")
		scene.iron_popup._resume()
		mission.data.gears[0] = -1
		for index in 3:
			if capture:
				await _settle()
				scene.iron_popup.board._pointer(Vector2(300 + Mission.GEAR_ORDER[index] * 200, 339), true)
				scene.iron_popup.board._pointer(scene.iron_popup.board.gear_center(index), false)
			else: scene.iron_popup._action("place", index, Mission.GEAR_ORDER[index])
		_check(mission.data.gears == Mission.GEAR_ORDER, "Direct manipulation installs the three gears")
		await _shot(difficulty + "_05_engranajes")
		scene.iron_popup._action("gears", -1, 0)
		_check(scene.iron_popup.board.gears_turning, "Manivela animates the meshing gear train before advancing")
		scene.iron_popup._process(1.3)
		_check(mission.stage() == 3, "All three meshing gears pass the transmission test")
		mission.test_water()
		_check(mission.stage() == 3 and not str(mission.data.review).is_empty(), "Open pipe circuits cannot pass water test")
		scene.iron_popup._resume()
		if capture:
			await _settle()
			var before_turn := int(mission.data.pipes[0])
			scene.iron_popup.board._pointer(scene.iron_popup.board.pipe_center(0), true)
			scene.iron_popup.board._pointer(scene.iron_popup.board.pipe_center(0), false)
			_check(int(mission.data.pipes[0]) == posmod(before_turn + 1, 4), "Click turns the actual copper pipe")
		for index in 6:
			for turn in 4:
				if int(mission.data.pipes[index]) != Mission.PIPE_SOLUTION[index]: scene.iron_popup._action("pipe", index, 0)
		_check(mission.circuit_connected(0) and mission.circuit_connected(1), "Both water circuits connect their endpoints")
		await _shot(difficulty + "_06_tuberias")
		scene.iron_popup._action("water_test", -1, 0)
		_check(mission.stage() == 4, "Water test advances only with two closed circuits")
		mission.ignite()
		_check(not str(mission.data.review).is_empty() and not bool(mission.data.lit), "Ignition requires water and fuel")
		scene.iron_popup._resume()
		mission.fill_water()
		mission.feed()
		mission.feed()
		_check(int(GameState.inventory.get(Mission.COAL_ITEM, 0)) == 3 and int(mission.data.portion) == 4, "Opening sack and feeding consume inventory and individual portions")
		mission.ignite()
		_check(mission.stage() == 5 and bool(mission.data.lit), "Prepared machine reaches the final trial")
		scene.iron_popup._sync()
		if capture:
			await _settle()
			scene.iron_popup.board._pointer(Vector2(900, 160), true)
			scene.iron_popup.board._pointer(Vector2(900, 160), false)
			_check(float(mission.data.valve) > 0.7, "Pointer adjusts the textured pressure lever")
			mission.set_valve(0.5)
		mission.run()
		scene.iron_popup._process(1.0)
		var stable := float(mission.data.stable_seconds)
		scene._show_journal()
		scene.iron_popup._process(8.0)
		_check(is_equal_approx(float(mission.data.stable_seconds), stable) and scene.iron_popup.suspended, "Journal freezes pressure clock and tools")
		await _shot(difficulty + "_07_cuaderno")
		scene._hide_journal()
		scene._show_inventory()
		scene.iron_popup._process(8.0)
		_check(is_equal_approx(float(mission.data.stable_seconds), stable), "Inventory freezes pressure clock")
		scene.hud._close_inventory()
		scene._update_modal_feedback()
		scene.iron_popup.application_focused = false
		scene.iron_popup._process(8.0)
		_check(is_equal_approx(float(mission.data.stable_seconds), stable), "Lost application focus freezes pressure clock")
		scene.iron_popup.application_focused = true
		# Fail through real simulation, retain elapsed progress, then recover with no free coal.
		mission.data.fuel = 0.0
		mission.data.valve = 0.0
		mission.tick(8.0)
		_check(not str(mission.data.review).is_empty(), "Starved fire triggers review even with discharge fully closed")
		var kept_seconds := float(mission.data.stable_seconds)
		var kept_coal := mission.fuel_available()
		Campaign.fail("iron_test", "exhaust budget")
		while Campaign.remaining() > 0: Campaign.fail("iron_test", "exhaust budget")
		scene.iron_popup._sync()
		scene.iron_popup._resume()
		_check(Campaign.remaining() == Campaign.total() and mission.stage() == 5 and is_equal_approx(float(mission.data.stable_seconds), kept_seconds), "New round preserves stages and stable seconds")
		_check(mission.fuel_available() == kept_coal and not bool(mission.data.running), "Retry does not duplicate coal or run unattended")
		# Replenishment after leaving the machine preserves the assembled engine.
		scene.iron_popup.close()
		GameState.inventory.erase(Mission.COAL_ITEM)
		mission.data.portion = 0
		scene._set_area("mine_face", Vector2(720, MineArt.FLOOR_Y))
		scene._interact("vein")
		_check(scene.coal_view.model.refill, "Returning to mine offers replenishment without resetting engine")
		preload("res://tests/coal_extraction_driver.gd").extract(scene)
		preload("res://tests/coal_extraction_driver.gd").classify_and_tie(scene)
		_check(GameState.has_item(Mission.COAL_ITEM, 4) and mission.stage() == 5 and is_equal_approx(float(mission.data.stable_seconds), kept_seconds), "Replenished fuel retains every passed stage and timer")
		scene._set_area("engine_room", EngineHouse.BENCH + Vector2(-50, 35))
		scene._interact("engine_bench")
		mission.feed()
		mission.feed()
		mission.run()
		for second in 180:
			if float(mission.data.stable_seconds) >= 119.0 or mission.blocked(): break
			if float(mission.data.fuel) < 0.34: mission.feed()
			mission.tick(1.0)
		_check(not bool(mission.data.complete) and float(mission.data.stable_seconds) >= 119.0 and str(mission.data.review).is_empty(), "Trial cannot finish before 120 stable seconds")
		await _shot(difficulty + "_08_presion")
		mission.tick(1.0)
		_check(bool(mission.data.complete) and is_equal_approx(float(mission.data.stable_seconds), 120.0), "Full two-minute trial completes in both difficulties")
		_check(GameState.has_item("potencia_vapor") and Campaign.done("engine"), "Engine completion grants shared transmission reward")
		_check(bool(Phase2Metrics.report().completada) and float(Phase2Metrics.report().mision_carbon_vapor.segundos_estables) == 120.0, "Teacher report records completion and the full stable trial")
		mission.advance()
		_check(int(GameState.inventory.get("potencia_vapor", 0)) == 1, "Repeated completion does not duplicate final reward")
		scene._close_dialogue()
		scene.player.position = Vector2(1110, 435)
		scene._interact("textile_exit")
		await get_tree().create_timer(0.6).timeout
		_check(scene.area == "textile_view", "Completed motor unlocks the textile hall")
		scene._process(0.5)
		_check(scene.production != null and float(scene.production.elapsed) >= 0.5, "Powered textile hall animates its shuttles and wheels")
		await _shot(difficulty + "_09_telares")
		if difficulty == "dificil":
			# Leave a genuinely unfinished, paid session for a fresh independent process.
			mission.data.complete = false
			mission.data.stable_seconds = 37.25
			mission.data.fuel = 0.48
			mission.data.pressure = 0.5
			mission.data.running = true
			scene._set_area("engine_room", EngineHouse.BENCH + Vector2(-50, 35))
			scene.iron_popup.open(mission)
			scene._show_journal()
			GameState.save_progress()
	print("IRON MISSION WRITE: %d checks, %d failures" % [checks, failures.size()])
	if not failures.is_empty(): _restore_files()
	get_tree().quit(0 if failures.is_empty() else 1)

func _read() -> void:
	_check(GameState.continue_saved_game(), "Fresh process opens saved mission")
	await get_tree().scene_changed
	await _settle()
	scene = get_tree().current_scene
	_freeze()
	var mission: Mission = scene.iron
	_check(scene.area == "engine_room" and mission.stage() == 5 and scene.iron_popup.is_open(), "Exact map and machine stage restore")
	_check(scene.journal_overlay.visible and scene.iron_popup.suspended and is_equal_approx(float(mission.data.stable_seconds), 37.25), "Journal and exact pressure time survive process restart")
	_check(GameState.coins == 77 and GameState.has_item(Mission.COAL_ITEM), "Paid journey and remaining real coal survive restart")
	_check(mission.data.gears == Mission.GEAR_ORDER and mission.circuit_connected(0) and mission.circuit_connected(1), "Installed gears and both water networks survive restart")
	var seconds := float(mission.data.stable_seconds)
	scene.iron_popup._process(5.0)
	_check(is_equal_approx(float(mission.data.stable_seconds), seconds), "Restored journal still pauses simulation")
	scene._hide_journal()
	scene.iron_popup._process(0.25)
	_check(float(mission.data.stable_seconds) > seconds, "Closing journal resumes the exact saved trial")
	_restore_files()
	print("IRON MISSION READ: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _walk_exit(destination: Vector2) -> void:
	scene._navigate_pointer(destination)
	for frame in 120:
		await get_tree().physics_frame
		scene._physics_process(1.0 / 60.0)
		if scene.changing_area: break
	await get_tree().create_timer(0.6).timeout

func _restore_files() -> void:
	if not FileAccess.file_exists(BACKUP): return
	Phase2Metrics.set_process(false)
	if Phase2Metrics.task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(Phase2Metrics.task_id)
		Phase2Metrics.task_id = -1
	var backups: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKUP))
	for path in backups:
		if backups[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else: FileAccess.open(path, FileAccess.WRITE).store_buffer(Marshalls.base64_to_raw(str(backups[path])))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))

func _shot(label: String) -> void:
	if not capture: return
	if scene.iron_popup.is_open(): scene.iron_popup._sync()
	await _settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/ui/iron_mission"))
	get_viewport().get_texture().get_image().save_png("res://output/ui/iron_mission/%s.png" % label)
