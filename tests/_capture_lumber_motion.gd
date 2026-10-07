extends Node
## Render in the isolated validation project, preserving the player's save.

const FRAME_DIRECTORY := "res://tmp/lumber_motion_frames"
const FRAME_TIME := 1.0 / 20.0
var frame_index := 0
var popup: Node
var backups := {}


func _ready() -> void:
	for path in [GameState.SAVE_PATH, GameState.REPORT_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIRECTORY))
	GameState.reset_progress(false)
	GameState.set_difficulty(GameState.DIFFICULTY_HARD)
	var island = preload("res://scenes/wood_island.tscn").instantiate()
	add_child(island)
	await get_tree().process_frame
	popup = island.get_node("LumberPuzzlePopup")
	popup.open()
	popup.set_process(false)
	popup.workbench.set_process(false)
	for frame in 12:
		await _frame()
	popup.straight_grain.pressed.emit()
	for frame in 15:
		await _frame()
	await get_tree().create_timer(0.8).timeout
	assert(popup.stage == popup.STAGE_MEASURE)
	popup.length_slider.value = 160
	popup.angle_slider.value = 90
	for mark in 3:
		while popup.marking_meter.value < popup.marking_meter.low or popup.marking_meter.value > popup.marking_meter.high:
			await _frame()
		popup.mark_button.pressed.emit()
		for frame in 12:
			await _frame()
	await get_tree().create_timer(0.75).timeout
	for button in [popup.left_support, popup.center_wedge, popup.right_clamp]:
		button.pressed.emit()
		for frame in 10:
			await _frame()
	popup.clamp_slider.value = 60
	popup.stability_test.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	for stroke in 5:
		var direction: int = popup.saw_expected_edge
		var area: Control = popup.saw_drag_area
		var start: float = popup.saw_sprite.position.x + (-94 if direction == 1 else 94) - area.position.x
		popup._begin_saw_stroke(Vector2(start, area.size.y / 2))
		for step in 12:
			popup._move_saw(Vector2(start + direction * 170 * (step + 1) / 12.0, area.size.y / 2))
			await _frame()
	for frame in 18:
		await _frame()
	await get_tree().create_timer(1.15).timeout
	assert(popup.stage == popup.STAGE_PLANE)
	popup.depth_slider.value = 50
	for lane in 4:
		var area: Control = popup.plane_drag_area
		var start: float = popup.PLANE_VISUAL_LEFT - area.position.x
		popup._begin_plane_pass(Vector2(start, area.size.y / 2))
		for step in 16:
			popup._move_plane(Vector2(start + (popup.PLANE_VISUAL_RIGHT - popup.PLANE_VISUAL_LEFT) * (step + 1) / 16.0, area.size.y / 2))
			await _frame()
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_TEST)
	for index in 3:
		var button: Button = [popup.sack_one, popup.sack_two, popup.sack_three][index]
		button.pressed.emit()
		for frame in 40:
			popup.brace_slider.value = [42, 58, 72][index] - sin((popup.work_clock + FRAME_TIME) * 2.4) * 7
			await _frame()
		assert(popup.verified_loads == index + 1)
	await get_tree().create_timer(0.8).timeout
	assert(popup.stage == popup.STAGE_COMPLETE)
	for frame in 20:
		await _frame()
	for path in backups:
		if backups[path] != null:
			FileAccess.open(path, FileAccess.WRITE).store_buffer(backups[path])
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LUMBER MOTION CAPTURE OK: %d frames at 20 FPS" % frame_index)
	get_tree().quit()


func _frame() -> void:
	popup._process(FRAME_TIME)
	popup.workbench._process(FRAME_TIME)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	var path := "%s/frame_%04d.png" % [FRAME_DIRECTORY, frame_index]
	assert(screenshot.save_png(ProjectSettings.globalize_path(path)) == OK)
	frame_index += 1
