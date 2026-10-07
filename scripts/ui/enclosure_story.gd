extends Control

const STORY_IMAGES := [
	preload("res://assets/gba/story/wool_price_01_wealth.png"),
	preload("res://assets/gba/story/wool_price_02_gate.png"),
	preload("res://assets/gba/story/wool_price_03_elena.png"),
	preload("res://assets/gba/story/wool_price_04_departure.png"),
]

const STORY_TITLES := [
	"La nueva riqueza",
	"Una puerta, dos realidades",
	"Lo que la lana no cuenta",
	"El coste del cambio",
]

const STORY_TEXTS := [
	"Las ovejas llenan los antiguos pastos comunales. Junto a la mansión, una máquina procesa su lana: la tierra empieza a producir riqueza de una manera diferente.",
	"El portón permanece cerrado. El propietario controla el rebaño y la producción; quienes dependían de aquellos pastos deben buscar otra forma de ganarse la vida.",
	"Elena señala el campo al otro lado de la cerca. La lana sigue saliendo hacia los telares, pero su familia ha perdido el acceso a la tierra que la alimentaba.",
	"La ciudad promete trabajo, pero llegar hasta ella no será sencillo. El relato de Elena te impulsa a reunir lo necesario para emprender tu propio viaje."
]

@onready var story_image: TextureRect = %StoryImage
@onready var story_panel: PanelContainer = %StoryPanel
@onready var story_text: Label = %StoryText
@onready var story_heading: Label = %StoryHeading
@onready var page_counter: Label = %PageCounter
@onready var header: BoxContainer = $StoryPanel/Margin/VBox/Header
@onready var actions: BoxContainer = %Actions
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var close_button: Button = %CloseButton

var current_index := 0
var changing_scene := false
var is_overlay := false
var image_fade: Tween


func _ready() -> void:
	is_overlay = (get_tree().current_scene != self)
	if not is_overlay and GameState.restoring_session:
		current_index = clampi(int(GameState.checkpoint.get("story_index", 0)), 0, 3)
	GameState.restore_scene_session.call_deferred(self)
	next_button.pressed.connect(_advance_story)
	prev_button.pressed.connect(_previous_story)
	close_button.visible = is_overlay
	close_button.pressed.connect(_close_overlay)
	resized.connect(_update_layout)
	story_text.resized.connect(_queue_panel_fit)
	header.minimum_size_changed.connect(_queue_panel_fit)
	$ChapterPanel/Margin/VBox.minimum_size_changed.connect(_queue_panel_fit)
	_update_layout()
	_show_page(false)
	next_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_advance_story()
		get_viewport().set_input_as_handled()
	elif is_overlay and event.is_action_pressed("pause"):
		_close_overlay()
		get_viewport().set_input_as_handled()


func _advance_story() -> void:
	if changing_scene:
		return
	if current_index < STORY_IMAGES.size() - 1:
		current_index += 1
		_show_page(true)
		return

	if is_overlay:
		_close_overlay()
		return

	changing_scene = true
	GameState.pending_spawn = GameState.PHASE_START_SPAWN
	get_tree().change_scene_to_file("res://scenes/sheep_farm.tscn")


func _previous_story() -> void:
	if changing_scene:
		return
	if current_index > 0:
		current_index -= 1
		_show_page(true)


func _close_overlay() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.controls_enabled = true
	queue_free()


func _show_page(animate := true) -> void:
	if not is_overlay and not changing_scene:
		GameState.save_progress()
	story_image.texture = STORY_IMAGES[current_index]
	story_text.text = STORY_TEXTS[current_index]
	story_heading.text = STORY_TITLES[current_index]
	page_counter.text = "%d / %d" % [current_index + 1, STORY_IMAGES.size()]
	call_deferred("_fit_story_panel", current_index)
	
	prev_button.visible = current_index > 0
	
	if is_overlay:
		next_button.text = "Volver al juego" if current_index == STORY_IMAGES.size() - 1 else "Siguiente  >"
	else:
		next_button.text = "Empesar primera fase" if current_index == STORY_IMAGES.size() - 1 else "Siguiente  >"

	if not animate:
		return
	story_image.modulate.a = 0.2
	if image_fade and image_fade.is_running():
		image_fade.kill()
	image_fade = create_tween()
	image_fade.set_trans(Tween.TRANS_QUAD)
	image_fade.set_ease(Tween.EASE_OUT)
	image_fade.tween_property(story_image, "modulate:a", 1.0, 0.3)


func _update_layout() -> void:
	var narrow := size.x < 560.0
	header.vertical = size.x < 700.0
	actions.vertical = narrow
	story_panel.offset_left = 16.0 if narrow else 28.0
	story_panel.offset_right = -16.0 if narrow else -28.0
	$ChapterPanel.offset_left = story_panel.offset_left
	close_button.offset_top = 112.0 if is_overlay and size.x < 730.0 else 22.0
	close_button.offset_bottom = close_button.offset_top + 46.0
	story_text.add_theme_font_size_override("font_size", 16 if narrow else 18)
	story_heading.add_theme_font_size_override("font_size", 20 if narrow else 22)
	_queue_panel_fit()


func _queue_panel_fit() -> void:
	call_deferred("_fit_story_panel", current_index)


func _fit_story_panel(expected_index: int) -> void:
	if expected_index != current_index:
		return
	var chapter_panel: PanelContainer = $ChapterPanel
	var chapter_size := chapter_panel.get_combined_minimum_size()
	chapter_panel.offset_right = chapter_panel.offset_left + chapter_size.x
	chapter_panel.offset_bottom = chapter_panel.offset_top + chapter_size.y
	var panel_height := story_panel.get_combined_minimum_size().y
	story_panel.offset_top = story_panel.offset_bottom - panel_height
