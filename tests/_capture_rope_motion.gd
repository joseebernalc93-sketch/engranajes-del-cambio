extends Node
## Capture with an isolated project/user-data directory, as with the screenshot scene.

const FRAME_DIRECTORY := "res://tmp/rope_motion_frames"
const FRAME_TIME := 1.0 / 20.0
var frame_index := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIRECTORY))
	GameState.reset_progress(false)
	var yard = preload("res://scenes/spinner_yard.tscn").instantiate()
	add_child(yard)
	await get_tree().process_frame
	var popup = yard.get_node("RopePuzzlePopup")
	popup.open()
	for button in [popup.hemp_long, popup.hemp_flexible, popup.hemp_clean]:
		button.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	for index in 3:
		popup._select_bundle(index)
		popup._perform_precision(0.5)
		popup._perform_precision(0.5)
	await get_tree().create_timer(0.75).timeout
	popup.feed_slider.value = 60
	for button in popup._hook_buttons():
		button.pressed.emit()
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_TENSION)
	# Fixed simulated time keeps capture speed independent of PNG encoding/render speed.
	popup.set_process(false)
	popup.machine_display.set_process(false)
	popup.tension = 55.0
	for frame in 60:
		popup.carriage_slider.value = 45.0 + sin(frame * 0.07) * 8.0
		popup._set_cranking(true)
		popup._process(FRAME_TIME)
		popup.machine_display._process(FRAME_TIME)
		await _capture_frame()
	popup.carriage_slider.value = 45.0
	for tick in 130:
		popup._set_cranking(true)
		popup._process(0.1)
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_FINISH)
	popup.seizing_knot.pressed.emit()
	for wrap in 3:
		popup._perform_precision(0.5)
	await get_tree().create_timer(1.05).timeout
	assert(popup.stage == popup.STAGE_PROOF)
	popup.machine_display._process(1.0)
	for frame in 90:
		popup.proof_brake_slider.value = 50.0 + popup.proof_checks * 9.0 / 0.65
		popup._set_testing(true)
		popup._process(FRAME_TIME)
		popup.machine_display._process(FRAME_TIME)
		await _capture_frame()
	await get_tree().create_timer(0.75).timeout
	assert(popup.stage == popup.STAGE_COMPLETE)
	for frame in 20:
		popup.machine_display._process(FRAME_TIME)
		await _capture_frame()
	print("ROPE MOTION CAPTURE OK: %d frames at 20 FPS" % frame_index)
	get_tree().quit()


func _capture_frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	var path := "%s/frame_%04d.png" % [FRAME_DIRECTORY, frame_index]
	assert(screenshot.save_png(ProjectSettings.globalize_path(path)) == OK)
	frame_index += 1
