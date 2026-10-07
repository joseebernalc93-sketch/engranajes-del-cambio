extends Area2D

@export var title := "Camino"
@export_multiline var question := "¿Deseas continuar?"
@export var confirm_label := "Sí"
@export var confirm_action := "close"
@export var cancel_label := "No"
@export var automatic := false

var awaiting_choice := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if awaiting_choice or not body.is_in_group("player"):
		return
	awaiting_choice = true
	body.set("controls_enabled", false)
	if automatic:
		EventBus.dialogue_action_selected.emit(confirm_action)
		return
	EventBus.show_dialogue(
		title,
		question,
		[
			{"label": confirm_label, "action": confirm_action},
			{"label": cancel_label, "action": "close"},
		]
	)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		awaiting_choice = false
