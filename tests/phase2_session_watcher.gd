extends Node
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const BACKUP := "user://phase2_session_test_backup.json"
var failed: bool = false

func begin() -> void:
	if "--read-phase2" in OS.get_cmdline_user_args(): await _read()
	else: await _write()

func _write() -> void:
	var backups := {}
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH, Phase2Metrics.PATH]:
		backups[path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null
	FileAccess.open(BACKUP, FileAccess.WRITE).store_string(JSON.stringify(backups))
	GameState.reset_progress(false)
	GameState.difficulty = "facil"
	GameState.run_started = true
	GameState.phase_complete = true
	GameState.phase_summary = {"fase": "El éxodo rural", "tiempo_segundos": 556, "puzzles": []}
	Campaign.ensure()
	for id in ["mine", "forge", "engine"]: Campaign.reward(id)
	get_tree().change_scene_to_file(GameState.PHASE_TWO_FACTORY)
	await get_tree().scene_changed
	await get_tree().process_frame
	var hub: Control = get_tree().current_scene
	hub._enter(3)
	var popup: CanvasLayer = hub.workshops[3]
	popup.set_process(false)
	for index in 4: popup._act("belt", 0.0, index)
	for index in 4: popup._act("adjust", 0.5, index)
	popup._act("confirm")
	for index in 4: popup._act("clutch", 0.0, index)
	popup._act("start")
	popup.work.data.elapsed = 47.6
	popup.work.data.bales = 4.2
	popup.work.data.stocks = [0.7, 0.8, 0.4, 0.9]
	popup.work.data.broken = [false, true, false, false]
	popup._act("knot", 0.0, 1)
	_check(popup.work.paused and Campaign.remaining() == 14, "Pending technical review costs once")
	GameState.save_progress()
	Phase2Metrics.flush()
	_check(GameState.checkpoint.active_workshop == 3, "Session captures active textile workshop")
	print("PHASE 2 SESSION WRITE ", "FAILED" if failed else "OK", ": active shift, pending review, stock, output and shared budget")
	get_tree().quit(1 if failed else 0)

func _read() -> void:
	_check(GameState.has_saved_game(), "Fresh process detects saved game")
	_check(GameState.continue_saved_game(), "Continue opens the new arrival while reserving workshop work")
	await get_tree().scene_changed
	for frame in 3: await get_tree().process_frame
	var hub: Control = get_tree().current_scene
	_check(hub.scene_file_path == GameState.PHASE_TWO_SCENE and hub.area == "platform", "Old hub save now opens the London adventure")
	var work := preload("res://scripts/puzzles/factory_work_state.gd").new("textile", true)
	work.restore(GameState.phase_two.work.textile)
	_check(work.stage == 3 and work.paused, "Reserved review and stage are retained")
	_check(is_equal_approx(float(work.data.elapsed), 47.6) and is_equal_approx(float(work.data.bales), 4.2), "Shift time and accepted production remain exact")
	_check(bool(work.data.broken[1]) and is_equal_approx(float(work.data.stocks[2]), 0.4), "Thread break and bobbin stock remain stored")
	work.tick(30.0)
	_check(Campaign.remaining() == 14 and is_equal_approx(float(work.data.elapsed), 47.6), "Hidden review cannot drain time or opportunities")
	work.resume()
	work.action("stop", 0.0, 1)
	work.action("knot", 0.0, 1)
	work.action("restart", 0.0, 1)
	work.tick(0.1)
	_check(not work.paused and not bool(work.data.broken[1]) and float(work.data.elapsed) > 47.6, "Reserved puzzle remains resumable when reintroduced")
	_check(Campaign.done("engine") and int(GameState.phase_summary.tiempo_segundos) == 556, "Earlier workshops and chapter remain complete")
	work = null
	hub._show_journal()
	for frame in 4: await get_tree().process_frame
	GameState.run_started = false
	Phase2Metrics.set_process(false)
	Phase2Metrics.flush()
	if FileAccess.file_exists(BACKUP):
		var backups: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKUP))
		for path in backups:
			if backups[path] == null:
				if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			else: FileAccess.open(path, FileAccess.WRITE).store_buffer(Marshalls.base64_to_raw(str(backups[path])))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
	print("PHASE 2 SESSION READ ", "FAILED" if failed else "OK", ": fresh-process Continue opens London and retains exact reserved shift and repair")
	get_tree().quit(1 if failed else 0)

func _check(condition: bool, text: String) -> void:
	if not condition:
		failed = true
		push_error("PHASE 2 SESSION: " + text)
