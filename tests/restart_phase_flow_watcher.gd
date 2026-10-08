extends Node

var previous_save := PackedByteArray()
var previous_report := PackedByteArray()
var had_save := false
var had_report := false
var stage := 0
var failures: Array[String] = []


func begin() -> void:
	had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	had_report = FileAccess.file_exists(GameState.REPORT_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	if had_report:
		previous_report = FileAccess.get_file_as_bytes(GameState.REPORT_PATH)
	var old_report := FileAccess.open(GameState.REPORT_PATH, FileAccess.WRITE)
	if old_report:
		old_report.store_string("reporte anterior")
		old_report.close()

	GameState.reset_progress(false)
	GameState.run_started = true
	# reset_progress removes an old report; create the completed report afterwards.
	old_report = FileAccess.open(GameState.REPORT_PATH, FileAccess.WRITE)
	old_report.store_string("reporte anterior")
	old_report.close()
	GameState.coins = 10
	GameState.inventory = {"boleto": 1}
	GameState.flags["tools_given_to_mateo"] = true
	GameState.flags["wheelwright_forge_completed"] = true
	GameState.flags["flour_sold"] = true
	GameState.flags["ticket_bought"] = true
	GameState.phase_complete = true
	get_tree().scene_changed.connect(_on_scene_changed)
	GameState.restart_phase()


func _on_scene_changed() -> void:
	await get_tree().process_frame
	if stage == 0:
		var countryside := get_tree().current_scene
		_check(countryside.scene_file_path == "res://scenes/sheep_farm.tscn", "Una fase completada vuelve al campo sin repetir el relato")
		_check(GameState.coins == 10 and GameState.has_item("boleto"), "Regresar conserva monedas e inventario")
		_check(GameState.phase_complete and GameState.flags.wheelwright_forge_completed, "Regresar conserva los puzzles completados")
		_check(GameState.is_phase_two_unlocked(), "Regresar conserva la fase 2 desbloqueada")
		_check(FileAccess.get_file_as_string(GameState.REPORT_PATH) == "reporte anterior", "Regresar conserva el reporte")
		stage = 1
		GameState.start_new_game(GameState.difficulty)
		return

	if stage == 1:
		var story = get_tree().current_scene
		_check(story.scene_file_path == GameState.PHASE_INTRO_SCENE, "Debe abrir el relato inicial")
		_check(story.current_index == 0, "El relato debe comenzar en la página 1")
		_check(GameState.coins == 0, "Las monedas deben reiniciarse")
		_check(GameState.has_item("herramientas"), "Las herramientas iniciales deben restaurarse")
		_check(not GameState.has_item("boleto"), "El boleto anterior debe eliminarse")
		_check(not GameState.phase_complete, "La fase debe volver a estar activa")
		_check(not FileAccess.file_exists(GameState.REPORT_PATH), "El reporte anterior debe eliminarse")
		stage = 2
		call_deferred("_finish_story", story)
		return

	if stage == 2:
		var sheep_farm = get_tree().current_scene
		var player: CharacterBody2D = sheep_farm.get_node("World/Player")
		_check(sheep_farm.scene_file_path == "res://scenes/sheep_farm.tscn", "El relato debe terminar en el criadero")
		_check(player.position == GameState.PHASE_START_SPAWN, "El personaje debe aparecer frente a la cerca cerrada")
		_restore_files()
		if failures.is_empty():
			print("RESTART PHASE FLOW TEST OK")
			get_tree().quit(0)
		else:
			for failure in failures:
				push_error(failure)
			get_tree().quit(1)


func _finish_story(story: Control) -> void:
	for page in 4:
		story._advance_story()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _restore_files() -> void:
	GameState.run_started = false
	_restore_file(GameState.SAVE_PATH, previous_save, had_save)
	_restore_file(GameState.REPORT_PATH, previous_report, had_report)


func _restore_file(path: String, contents: PackedByteArray, existed: bool) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_buffer(contents)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
