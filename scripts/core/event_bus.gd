extends Node

signal inventory_changed
signal objective_changed(text: String)
signal coins_changed(value: int)
signal interaction_prompt_changed(text: String)
signal dialogue_requested(payload: Dictionary)
signal dialogue_action_selected(action: String)
signal toast_requested(text: String)
signal phase_completed(report: Dictionary)
signal mill_repair_requested
signal mill_operation_requested
signal wheelwright_forge_requested
signal lumber_puzzle_requested
signal rope_puzzle_requested
signal migration_cart_requested
signal rail_dispatch_requested


func show_dialogue(speaker: String, text: String, options: Array = []) -> void:
	dialogue_requested.emit({
		"speaker": speaker,
		"text": text,
		"options": options,
	})


func show_toast(text: String) -> void:
	toast_requested.emit(text)
