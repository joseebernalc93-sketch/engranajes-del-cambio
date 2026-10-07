extends Node
## Exercises the real HUD without writing or resetting the player's progress.
var capture := false


func _ready() -> void:
	capture = "--capture-ui" in OS.get_cmdline_user_args()
	GameState.inventory = {"herramientas": 1, "trigo": 3, "rueda_dentada": 1, "cuerda": 1, "tabla": 1}
	GameState.coins = 10
	var village := preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	var hud = village.get_node("HUD")
	var player = village.get_node("World/Player")
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("status")
	hud._toggle_inventory()
	await get_tree().create_timer(0.2).timeout
	assert(not player.controls_enabled)
	assert(hud.slot_buttons.size() == 5)
	assert(hud.item_list.get_child_count() == 12)
	hud.slot_buttons["rueda_dentada"].pressed.emit()
	assert(hud.selected_item_id == "rueda_dentada")
	assert(hud.item_name.text == "Rueda dentada reforzada")
	assert(hud.slot_buttons["rueda_dentada"].button_pressed)
	hud.get_node("%InventoryTab").pressed.emit()
	assert(hud.selected_item_id == "rueda_dentada")
	await _capture("inventory")
	# Refreshes preserve the inspected object and replace old nodes immediately.
	GameState.inventory["trigo"] = 12
	EventBus.inventory_changed.emit()
	assert(hud.selected_item_id == "rueda_dentada")
	assert(hud.item_list.get_child_count() == 12)
	GameState.inventory.clear()
	EventBus.inventory_changed.emit()
	assert(hud.slot_buttons.is_empty())
	assert(hud.item_name.text == "Mochila vacía")
	assert(hud.item_icon.texture == null)
	await _capture("empty")
	# Historical entries remain accessible after the item has been used.
	hud.get_node("%GlossaryTab").pressed.emit()
	assert(hud.slot_buttons.size() == ContentDB.ITEMS.size())
	hud.slot_buttons["boleto"].pressed.emit()
	assert(hud.item_name.text == "Boleto de tren")
	assert(hud.item_description.text.contains("ferrocarril"))
	await _capture("glossary")
	# A reduced viewport must contain the whole panel, including the close button.
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	await get_tree().process_frame
	hud._fit_inventory_panel()
	var panel: Control = hud.get_node("Root/InventoryOverlay/Panel")
	var panel_rect := panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)
	assert(panel_rect.position.x >= 0 and panel_rect.position.y >= 0)
	assert(panel_rect.end.x <= get_viewport().get_visible_rect().size.x + 1)
	assert(panel_rect.end.y <= get_viewport().get_visible_rect().size.y + 1)
	await _capture("small")
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	hud._unhandled_input(escape)
	assert(not hud.inventory_overlay.visible)
	assert(player.controls_enabled)
	# Large balances cannot push the status bar out of the viewport.
	hud._set_coins(999999)
	await get_tree().process_frame
	var status: Control = hud.get_node("Root/StatusPanel")
	assert(status.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x)
	print("INVENTORY UI OK: selection, refresh, empty state, glossary, scaling and controls")
	get_tree().quit()


func _capture(name: String) -> void:
	if not capture:
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://tmp/inventory_ui")
	DirAccess.make_dir_recursive_absolute(output)
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)
