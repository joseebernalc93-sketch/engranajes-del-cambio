extends Node
const Journey := preload("res://scripts/world/london_journey.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Art := preload("res://scripts/world/mine_art.gd")
const Hazards := preload("res://scripts/world/mine_hazards.gd")
const Lift := preload("res://scripts/world/mine_lift_sequence.gd")
const BACKUP := "user://mine_tunnel_backup.json"
var checks: int = 0
var failures: Array[String] = []
var scene: Control
var capture: bool = false

func begin() -> void:
	capture = "--capture-ui" in OS.get_cmdline_user_args()
	if "--restore-tunnel" in OS.get_cmdline_user_args():
		_restore_files()
		get_tree().quit()
	elif "--read-descent" in OS.get_cmdline_user_args(): await _read_descent()
	elif "--read-ascent" in OS.get_cmdline_user_args(): await _read_ascent()
	else: await _write()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _settle() -> void:
	for frame in 4: await get_tree().process_frame
	if capture and is_instance_valid(scene): scene.application_focused = true

func _freeze() -> void:
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.application_focused = true
	scene.iron_popup.set_process(false)

func _switch(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await _settle()

func _press_e() -> void:
	scene._update_nearest()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = true
	scene._unhandled_input(event)

func _write() -> void:
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	FileAccess.open(BACKUP, FileAccess.WRITE).store_string(JSON.stringify(backups))
	for difficulty in ["facil", "dificil"]:
		await _switch("res://scenes/ui/main_menu.tscn")
		GameState.reset_progress(false)
		GameState.difficulty = difficulty
		GameState.phase_complete = true
		GameState.run_started = true
		GameState.coins = 77
		var journey := Journey.ensure()
		journey.arrived = true
		journey.elapsed = 9.5
		journey.area = "mine_yard"
		await _switch(GameState.PHASE_TWO_SCENE)
		scene = get_tree().current_scene
		_freeze()
		scene.iron.start()
		_check(scene.points.has("mine_door") and not scene.points.has("lift") and scene.lift_rig == null, "Exterior offers a door, not a visible elevator or shaft")
		await _shot(difficulty + "_00_puerta")
		scene.player.position = scene.points.mine_door + Vector2(0, 20)
		_press_e()
		await get_tree().create_timer(0.6).timeout
		_check(scene.area == "mine_house" and scene.backdrop.texture == Art.HOUSE, "E at exterior door enters the independent winding-house")
		_check(scene.actors.is_empty() and scene.player.scale == Vector2.ONE * Art.HERO_SCALE, "Indoor room has only the playable human-scale protagonist")
		await _shot(difficulty + "_00_casa")
		scene.player.position = scene.points.house_door
		_press_e()
		await get_tree().create_timer(0.6).timeout
		_check(scene.area == "mine_yard" and scene.player.scale == Vector2.ONE, "Indoor door returns to the yard and normal exterior scale")
		scene.player.position = scene.points.mine_door + Vector2(0, 20)
		_press_e()
		await get_tree().create_timer(0.6).timeout
		scene._navigate_pointer(Vector2(600, 505))
		for frame in 150:
			await get_tree().physics_frame
			if capture and not scene.application_focused:
				scene.application_focused = true
				scene._navigate_pointer(Vector2(600, 505))
			scene._physics_process(1.0 / 60)
			if scene.target == Vector2.INF: break
		_check(scene.player.position.distance_to(Vector2(600, 505)) < 8, "Pointer walking crosses the room without colliding with the backdrop furniture")
		scene.player.position = scene.points.lift + Vector2(0, 20)
		_press_e()
		_check(scene.lift_elapsed == 0.0 and not scene.lift_returning, "E at surface starts descent")
		_check(scene.lift_movie.visible and not scene.player.visible, "One cinematic protagonist boards the independent cage")
		scene._process(1.7)
		_check(scene.lift_movie.gate_closed > 0.0, "Compuerta closes before travel")
		await _shot(difficulty + "_01_compuerta")
		scene._process(2.55)
		var down_pose: Vector2 = scene.lift_movie.cage_feet
		_check(down_pose.y > Art.HOUSE_LANDING.y and down_pose.y < Lift.DEPTH_Y, "Cage is visibly inside the shaft during descent")
		_check(scene.lift_movie.camera_origin.y > 0.0, "Camera follows the cage past geological walls")
		_check(scene.lift_movie.in_shaft(), "Travel shot uses the dedicated underground shaft")
		await _shot(difficulty + "_02_descenso")
		scene._show_journal()
		scene._process(2.0)
		_check(is_equal_approx(scene.lift_elapsed, 4.25) and scene.lift_movie.cage_feet == down_pose, "Journal freezes cabin, camera, gate and time")
		scene._hide_journal()
		scene.application_focused = false
		scene._process(2.0)
		_check(is_equal_approx(scene.lift_elapsed, 4.25), "Lost focus freezes descent")
		scene.application_focused = true
		scene._process(Lift.DURATION - 4.25)
		_check(scene.area == "mine_gallery" and scene.lift_elapsed < 0.0 and scene.player.visible, "Descent opens into playable tunnel")
		_check(scene.player.position == Vector2(195, Art.FLOOR_Y) and scene.player.scale == Vector2.ONE * Art.HERO_SCALE, "Human-scale hero exits onto the horizontal floor")
		_check(scene.backdrop.texture == Art.TUNNEL and scene.points.lift_up.x < 150 and scene.exit_zones.has("coal_gallery_exit") and not scene.points.has("vein"), "Chosen model has left lift and a right passage to the separate extraction gallery")
		var position: Vector2 = scene.player.position
		Input.action_press("move_up")
		scene._physics_process(1.0 / 60)
		Input.action_release("move_up")
		_check(scene.player.position == position, "Up cannot leave the tunnel lane")
		Input.action_press("move_right")
		await get_tree().physics_frame
		scene._physics_process(1.0 / 60)
		Input.action_release("move_right")
		_check(scene.player.position.x > position.x and scene.player.position.y == Art.FLOOR_Y, "Right walks without vertical drift")
		scene._navigate_pointer(Vector2(520, 35))
		_check(scene.target == Vector2(520, Art.FLOOR_Y), "Click height projects onto the same horizontal route")
		scene.target = Vector2.INF
		var sizes_ok := true
		for stone in 16:
			sizes_ok = sizes_ok and scene.hazards.stone_size(stone) >= 8 and scene.hazards.stone_size(stone) <= scene.character_height * Art.HERO_SCALE / 5
		_check(sizes_ok, "Falling rocks stay hand-to-head sized relative to visible hero")
		for index in 3:
			var point := Vector2(Hazards.ZONES[index].get_center().x, Art.FLOOR_Y)
			scene.iron.data.hazard_clock = fposmod(0.2 - index * 3.2, Hazards.CYCLE)
			_check(scene.hazards.phase(index) == 1 and not scene.hazards.collision_at(point), "Dust warns before fall " + str(index + 1))
			scene.iron.data.hazard_clock = fposmod(scene.hazards.warning_seconds() + 0.8 - index * 3.2, Hazards.CYCLE)
			scene.player.position = point
			var budget := Campaign.remaining()
			scene._process(0.0)
			_check(scene.dialogue.visible and Campaign.remaining() == budget - 1, "Fall opens review and spends exactly one opportunity")
			_check(scene.player.position == Vector2(Hazards.SAFE_STOPS[index], Art.FLOOR_Y), "Impact returns to the preceding safe stop")
			var frozen := float(scene.iron.data.hazard_clock)
			scene._process(10.0)
			_check(Campaign.remaining() == budget - 1 and is_equal_approx(float(scene.iron.data.hazard_clock), frozen), "Review freezes rocks and prevents cascading penalties")
			scene._close_dialogue()
			_check(str(scene.iron.data.review).is_empty(), "Continue releases this attempt")
		var staggered := true
		for tick in 100:
			scene.iron.data.hazard_clock = tick / 10.0
			var active: int = 0
			for zone in 3:
				if scene.hazards.phase(zone) == 2: active += 1
			staggered = staggered and active <= 1
		_check(staggered, "Three falls are staggered rather than closing the entire tunnel together")
		scene.player.position = Vector2(Hazards.SAFE_STOPS[0], Art.FLOOR_Y)
		scene.iron.data.hazard_clock = scene.hazards.warning_seconds() + 0.8
		await _shot(difficulty + "_03_piedras")
		var waited: float = 0.0
		for index in 3:
			for wait_step in 110:
				if scene.hazards.phase(index) == 0 and scene.hazards.local_time(index) < 8.3: break
				scene._process(0.1)
				waited += 0.1
			scene._navigate_pointer(Vector2(Hazards.CHECKPOINTS[index] + 10, Art.FLOOR_Y))
			for frame in 220:
				await get_tree().physics_frame
				# The interactive native preview can lose OS focus to the inspection tools.
				if capture and not scene.application_focused:
					scene.application_focused = true
					scene._navigate_pointer(Vector2(Hazards.CHECKPOINTS[index] + 10, Art.FLOOR_Y))
				scene._physics_process(1.0 / 60)
				scene._process(1.0 / 60)
				if scene.target == Vector2.INF: break
			_check(int(scene.iron.data.route) == index + 1 and not scene.dialogue.visible, "Waiting and crossing clears tramo " + str(index + 1))
		_check(waited > 0 and scene.iron.stage() == 1, "All three actual crossings unlock coal extraction")
		if scene.iron_popup.is_open(): scene.iron_popup.close()
		await _shot(difficulty + "_04_veta")
		scene.player.position = Vector2(165, Art.FLOOR_Y)
		scene._update_nearest()
		_check(scene.nearest == "lift_up", "Left landing offers the lift as a nearby E interaction")
		_press_e()
		_check(scene.lift_returning and scene.lift_elapsed == 0.0, "E inside tunnel starts ascent")
		scene._process(4.25)
		var up_pose: Vector2 = scene.lift_movie.cage_feet
		scene._process(0.2)
		_check(scene.lift_movie.cage_feet.y < up_pose.y, "Ascending cage actually moves upwards")
		await _shot(difficulty + "_05_ascenso")
		scene._show_inventory()
		var time: float = scene.lift_elapsed
		scene._process(2.0)
		_check(scene.hud.inventory_overlay.visible and is_equal_approx(scene.lift_elapsed, time), "Inventory pauses ascent")
		scene.hud._close_inventory()
		scene._update_modal_feedback()
		scene._process(Lift.DURATION - time)
		_check(scene.area == "mine_house" and scene.player.position == Art.HOUSE_EXIT and scene.player.scale == Vector2.ONE * Art.HERO_SCALE and scene.player.visible, "Ascent delivers the passenger inside the winding-house")
		_check(GameState.coins == 77 and scene.iron.stage() == 1, "Round trip does not charge coins or reset the mission")
		await _shot(difficulty + "_06_superficie")
		if difficulty == "dificil":
			scene.player.position = scene.points.lift + Vector2(0, 20)
			_press_e()
			scene._process(4.25)
			scene._show_journal()
			GameState.save_progress()
	_finish("WRITE", false)

func _continue() -> void:
	_check(GameState.continue_saved_game(), "Saved elevator session opens")
	await get_tree().scene_changed
	await _settle()
	scene = get_tree().current_scene
	_freeze()

func _read_descent() -> void:
	await _continue()
	_check(scene.area == "mine_house" and not scene.lift_returning and is_equal_approx(scene.lift_elapsed, 4.25), "New process restores exact descending time and indoor source landing")
	_check(scene.journal_overlay.visible and scene.lift_movie.visible and not scene.player.visible, "Saved journal overlays one visible cinematic passenger")
	var position: Vector2 = scene.lift_movie.cage_feet
	scene._process(3.0)
	_check(scene.lift_movie.cage_feet == position, "Restored journal keeps descent paused")
	scene._hide_journal()
	scene._process(Lift.DURATION - 4.25)
	_check(scene.area == "mine_gallery" and scene.player.position == Vector2(195, Art.FLOOR_Y), "Resumed descent finishes at left tunnel entrance")
	scene.player.position = Vector2(165, Art.FLOOR_Y)
	_press_e()
	scene._process(4.25)
	scene._show_inventory()
	GameState.save_progress()
	_check(scene.lift_returning and scene.hud.inventory_overlay.visible and GameState.coins == 77, "Ascending checkpoint saves inventory pause without payment")
	_finish("READ DESCENT", false)

func _read_ascent() -> void:
	await _continue()
	_check(scene.area == "mine_gallery" and scene.lift_returning and is_equal_approx(scene.lift_elapsed, 4.25), "New process restores exact ascending time and source tunnel")
	_check(scene.hud.inventory_overlay.visible and scene.lift_movie.visible and not scene.player.visible, "Ascending save restores inventory and cinematic passenger")
	scene._process(2.0)
	_check(is_equal_approx(scene.lift_elapsed, 4.25), "Restored inventory freezes ascent")
	scene.hud._close_inventory()
	scene._update_modal_feedback()
	scene._process(Lift.DURATION - 4.25)
	_check(scene.area == "mine_house" and scene.player.visible and scene.lift_elapsed < 0, "Resumed ascent delivers passenger to indoor surface")
	_check(GameState.coins == 77 and scene.iron.stage() == 1 and int(scene.iron.data.route) == 3, "Progress and balance survive both independent process restarts")
	var indoor: Dictionary = scene.get_session_state()
	scene._set_area("mine_yard", Vector2.ZERO)
	scene.restore_session_state(indoor)
	_check(scene.area == "mine_house" and scene.player.position == Art.HOUSE_EXIT and scene.player.visible, "Free exploration checkpoint restores the indoor room and exact position")
	var old_exterior: Dictionary = scene.get_session_state()
	old_exterior.arrival_version = 4
	old_exterior.area = "mine_yard"
	old_exterior.lift_elapsed = 4.25
	old_exterior.lift_returning = false
	old_exterior.lift_start = [765, 383]
	scene.restore_session_state(old_exterior)
	_check(scene.area == "mine_house" and is_equal_approx(scene.lift_elapsed, 4.25) and scene.lift_movie.in_shaft(), "Version four exterior ride migrates without changing its saved time")
	scene._process(Lift.DURATION)
	_check(scene.area == "mine_gallery" and GameState.coins == 77, "Version four migration preserves the destination and balance")
	var legacy: Dictionary = scene.get_session_state()
	legacy.area = "mine_gallery"
	legacy.position = [1040, 565]
	legacy.arrival_version = 3
	legacy.lift_elapsed = -1.0
	legacy.hud = {}
	scene.restore_session_state(legacy)
	_check(scene.player.position == Vector2(1040, Art.FLOOR_Y), "Existing free-walk mine save projects onto new floor")
	legacy.lift_elapsed = 3.5
	legacy.lift_returning = false
	legacy.erase("lift_start")
	scene.restore_session_state(legacy)
	_check(is_equal_approx(scene.lift_elapsed, Lift.DURATION * 0.5) and scene.lift_movie.visible, "Old seven-second lift checkpoint migrates into continuous ride")
	_check(scene.area == "mine_house", "Legacy exterior descent migrates to the indoor landing")
	scene._process(Lift.DURATION)
	_check(scene.area == "mine_gallery" and scene.lift_elapsed < 0.0, "Migrated descent remains completable")
	_finish("READ ASCENT", true)

func _finish(label: String, restore: bool) -> void:
	print("MINE TUNNEL %s: %d checks, %d failures" % [label, checks, failures.size()])
	if restore or not failures.is_empty(): _restore_files()
	get_tree().quit(0 if failures.is_empty() else 1)

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
	await _settle()
	# Capture even if inspecting another window made the native test minimized.
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/ui/mine_tunnel"))
	get_viewport().get_texture().get_image().save_png("res://output/ui/mine_tunnel/%s.png" % label)
