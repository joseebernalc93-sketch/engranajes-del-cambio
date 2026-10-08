extends Node

var previous_save := PackedByteArray()
var had_save := false
var failures: Array[String] = []


func _ready() -> void:
	had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)

	GameState.reset_progress(false)
	EventBus.dialogue_action_selected.emit("sell_flour")
	_check(GameState.coins == 0, "No debe pagar si falta el costal de harina")
	_check(GameState.has_item("herramientas"), "Tomás no debe retirar las herramientas")

	GameState.interact("wheat_1")
	GameState.interact("wheat_2")
	GameState.interact("wheat_3")
	GameState.interact("villager")
	_check(GameState.has_item("trigo", 3), "Deben existir tres unidades de trigo")

	var raw_wheat_dialogue := {}
	EventBus.dialogue_requested.connect(func(payload: Dictionary): raw_wheat_dialogue.merge(payload), CONNECT_ONE_SHOT)
	GameState.interact("baker")
	_check(str(raw_wheat_dialogue.get("text", "")).contains("molino"), "Tomás debe rechazar el trigo sin procesar")
	_check((raw_wheat_dialogue.get("options", []) as Array).is_empty(), "El trigo sin moler no debe ofrecer una venta")

	EventBus.dialogue_action_selected.emit("begin_wheelwright_forge")
	_check(not GameState.has_item("herramientas"), "Mateo debe recibir las herramientas")
	_check(GameState.complete_wheelwright_forge(), "La misión de Mateo debe producir la rueda")
	_check(GameState.complete_lumber_puzzle(), "La misión de Bruno debe producir la tabla")
	_check(GameState.complete_rope_puzzle(), "La misión de Silas debe producir la cuerda")
	GameState.install_mill_part("rueda_dentada")
	GameState.install_mill_part("cuerda")
	GameState.install_mill_part("tabla")
	EventBus.dialogue_action_selected.emit("mill_wheat")
	_check(GameState.has_item("costal_harina"), "El molino debe transformar el trigo en harina")
	_check(not GameState.has_item("trigo"), "El trigo debe consumirse al molerlo")

	var smith_dialogue := {}
	EventBus.dialogue_requested.connect(func(payload: Dictionary): smith_dialogue.merge(payload), CONNECT_ONE_SHOT)
	GameState.interact("baker")
	_check(str(smith_dialogue.get("text", "")).contains("100 monedas"), "Tomás debe ofrecer 100 monedas por la harina")
	var smith_options: Array = smith_dialogue.get("options", [])
	_check(not smith_options.is_empty() and smith_options[0].get("action", "") == "sell_flour", "El diálogo debe vender únicamente el costal")

	EventBus.dialogue_action_selected.emit("sell_flour")
	_check(GameState.coins == 100, "La venta del costal debe entregar 100 monedas")
	_check(not GameState.has_item("costal_harina"), "El costal debe salir del inventario")
	_check(GameState.flags.get("flour_sold", false), "La venta de harina debe quedar registrada")
	EventBus.dialogue_action_selected.emit("sell_flour")
	_check(GameState.coins == 100, "No debe pagar dos veces por el mismo costal")
	_check(not GameState.flags.get("cart_mission_completed", false), "Elena no debe ser un requisito del viaje")
	_check(GameState.get_objective().contains("carretas"), "El siguiente objetivo debe conducir a la nueva terminal")
	_check(GameState.book_passenger_coach("res://scenes/station.tscn"), "El jugador debe poder pagar la diligencia")
	_check(GameState.coins == 97, "El pasaje debe reservar las 10 monedas del tren")
	_check(GameState.complete_passenger_coach_trip("res://scenes/station.tscn"), "La llegada debe habilitar el objetivo de la taquilla")
	_check(GameState.get_objective().contains("boleto"), "Tras llegar debe indicar la compra del boleto")
	EventBus.dialogue_action_selected.emit("buy_ticket")
	_check(GameState.coins == 87, "La compra debe descontar las 10 monedas")
	_check(GameState.has_item("boleto"), "El boleto debe añadirse al inventario")
	_check(GameState.get_objective().contains("tren"), "El siguiente objetivo debe ser abordar el tren")

	GameState.coins = 6
	GameState.inventory = {"trigo": 3}
	GameState.flags["tools_sold"] = true
	GameState.flags["ticket_bought"] = false
	GameState._migrate_legacy_economy()
	_check(GameState.coins == 0, "La migración debe retirar el saldo del flujo anterior")
	_check(GameState.has_item("herramientas"), "La migración debe restaurar las herramientas")
	_check(GameState.has_item("trigo", 3), "La migración debe conservar la cosecha")
	_check(not GameState.flags.get("flour_sold", true), "La migración debe abrir la nueva venta de harina")

	_restore_save()
	if failures.is_empty():
		print("ECONOMY FLOW TEST OK: Tomás compra solamente harina")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_buffer(previous_save)
	elif FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
