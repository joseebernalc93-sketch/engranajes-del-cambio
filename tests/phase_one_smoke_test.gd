extends Node

var previous_save := PackedByteArray()
var previous_report := PackedByteArray()
var had_save := false
var had_report := false


func _ready() -> void:
	had_save = FileAccess.file_exists(GameState.SAVE_PATH)
	had_report = FileAccess.file_exists(GameState.REPORT_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	if had_report:
		previous_report = FileAccess.get_file_as_bytes(GameState.REPORT_PATH)
	GameState.reset_progress(false)

	var player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player._update_walk_animation(Vector2.RIGHT, 0.3)
	assert(player.sprite.region_rect.position == Vector2(724, 724))
	player._update_walk_animation(Vector2.ZERO, 0.0)
	player._update_walk_animation(Vector2.UP, 0.3)
	assert(player.sprite.region_rect.position == Vector2(724, 1086))
	assert(is_equal_approx(player.sprite.position.y, -23.58))
	player.queue_free()

	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/main_menu.tscn")
	var story = preload("res://scenes/ui/enclosure_story.tscn").instantiate()
	add_child(story)
	story.is_overlay = false
	story._show_page(false)
	assert(story.current_index == 0)
	assert(story.get_node("StoryPanel/Margin/VBox/StoryText").text == "Las ovejas llenan los antiguos pastos comunales. Junto a la mansión, una máquina procesa su lana: la tierra empieza a producir riqueza de una manera diferente.")
	story._advance_story()
	assert(story.current_index == 1)
	assert(story.get_node("StoryPanel/Margin/VBox/StoryText").text == "El portón permanece cerrado. El propietario controla el rebaño y la producción; quienes dependían de aquellos pastos deben buscar otra forma de ganarse la vida.")
	story._advance_story()
	assert(story.current_index == 2)
	assert(story.get_node("StoryPanel/Margin/VBox/StoryText").text == "Elena señala el campo al otro lado de la cerca. La lana sigue saliendo hacia los telares, pero su familia ha perdido el acceso a la tierra que la alimentaba.")
	story._advance_story()
	assert(story.current_index == 3)
	assert(story.get_node("StoryPanel/Margin/VBox/StoryText").text == "La ciudad promete trabajo, pero llegar hasta ella no será sencillo. El relato de Elena te impulsa a reunir lo necesario para emprender tu propio viaje.")
	assert(story.get_node("StoryPanel/Margin/VBox/Header/Actions/NextButton").text == "Empesar primera fase")
	story.free()

	var village = preload("res://scenes/game.tscn").instantiate()
	add_child(village)
	assert(village.get_node_or_null("World/StationExit"))
	assert(village.get_node_or_null("World/SheepFarmExit"))
	assert(village.get_node_or_null("World/MillFieldExit"))
	assert(village.get_node("World/MillFieldExit").automatic)
	assert(village.get_node("World/SheepFarmExit").automatic)
	assert(not village.get_node_or_null("World/Train"))
	assert(not village.get_node_or_null("World/TicketClerk"))
	assert(village.get_node_or_null("World/Villager/MovementBlocker"))
	assert(village.get_node_or_null("World/Baker/MovementBlocker"))
	assert(village.get_node("World/Baker").interaction_id == "baker")
	assert(village.get_node("World/Baker").texture.resource_path == "res://assets/gba/tomas_baker_idle_v1.png")
	assert(not village.get_node_or_null("World/FieldFence"))
	for wheat_name in ["Wheat1", "Wheat2", "Wheat3"]:
		assert(not village.get_node_or_null("World/" + wheat_name))
	await get_tree().process_frame
	var cart := village.get_node("World/ElenaMigrationCart") as Sprite2D
	assert(cart.position == Vector2(300, 285))
	assert(village.get_node("World/ElenaMigrationCartCollision").position == Vector2(259.5, 248.5))
	assert(village.get_node("World/ElenaHorseCollision").position == Vector2(352, 267.5))
	assert(not village.get_node_or_null("World/BakeryCounter"))
	assert(not village.get_node_or_null("World/BreadRack"))
	assert(not village.get_node_or_null("World/SteelForge"))
	var oven_fire := village.get_node("World/BakeryOvenFire") as AnimatedSprite2D
	assert(oven_fire.is_playing())
	assert(oven_fire.position == Vector2(1031, 214))
	var workbench_shape := village.get_node("World/BakeryCounterCollision").get_child(0).shape as RectangleShape2D
	var materials_shape := village.get_node("World/BreadRackCollision").get_child(0).shape as RectangleShape2D
	assert(workbench_shape.size == Vector2(108, 72))
	assert(materials_shape.size == Vector2(136, 76))
	assert(not village.get_node_or_null("World/NorthAppleTree"))
	assert(not village.get_node_or_null("World/FieldAppleTree"))
	assert(not village.get_node_or_null("World/RoadAppleTree"))
	var animated_water := village.get_node("World/VillageBackdrop/AnimatedWater") as Sprite2D
	assert(animated_water.material is ShaderMaterial)
	var boat_left := village.get_node("World/FishingBoatLeft") as Sprite2D
	var boat_right := village.get_node("World/FishingBoatRight") as Sprite2D
	assert(boat_left.region_rect.position == Vector2(30, 190))
	assert(boat_right.region_rect.position == Vector2(917, 190))
	assert(boat_left.has_meta("bob_base_y"))
	assert(boat_right.has_meta("bob_base_y"))
	assert(not is_equal_approx(boat_left.position.y, float(boat_left.get_meta("bob_base_y"))))
	assert(not is_equal_approx(boat_right.position.y, float(boat_right.get_meta("bob_base_y"))))
	var hud := village.get_node("HUD")
	assert(not hud.get_node("Root/ObjectivePanel").visible)
	assert(hud.get_node_or_null("%PauseObjectiveLabel"))
	hud._open_pause()
	assert(hud.get_node("Root/PauseOverlay").visible)
	assert(hud.get_node("%PauseObjectiveLabel").text == GameState.get_objective())
	hud._close_pause()
	hud._toggle_inventory()
	assert(hud.get_node("Root/InventoryOverlay").visible)
	assert(hud.get_node("Root/InventoryOverlay/Panel/Margin/VBox/Content/ItemListHost/ItemList").get_child_count() > 0)
	hud._close_inventory()
	village.free()

	var station = preload("res://scenes/station.tscn").instantiate()
	add_child(station)
	assert(station.get_node_or_null("World/VillageExit"))
	assert(not station.get_node_or_null("World/Train"))
	assert(station.get_node_or_null("World/Ramon"))
	assert(not station.get_node_or_null("World/TicketClerk"))
	station.free()
	var platform = preload("res://scenes/station_platform.tscn").instantiate()
	add_child(platform)
	assert(platform.get_node_or_null("World/Train"))
	assert(platform.get_node_or_null("TrainDepartureController"))
	platform.free()

	var station_interior = preload("res://scenes/station_interior.tscn").instantiate()
	add_child(station_interior)
	assert(station_interior.get_node_or_null("World/TicketClerk"))
	assert(station_interior.get_node_or_null("World/Bounds/TicketCounter"))
	station_interior.free()

	var mill_field = preload("res://scenes/mill_field.tscn").instantiate()
	add_child(mill_field)
	await get_tree().process_frame
	assert(mill_field.get_node_or_null("World/VillageExit"))
	assert(mill_field.get_node("World/VillageExit").automatic)
	assert(mill_field.get_node_or_null("World/WheelwrightExit"))
	assert(mill_field.get_node("World/WheelwrightExit").automatic)
	assert(mill_field.get_node_or_null("World/BrokenMillInfo"))
	assert(not mill_field.get_node_or_null("World/WitheredWheatInfo"))
	assert(not mill_field.get_node_or_null("World/Bounds/WitheredFieldBlock"))
	assert(mill_field.get_node("World/FieldFence").get_child_count() == 5)
	assert(mill_field.get_node("World/Wheat1").texture_region.position.x == 0.0)
	assert(mill_field.get_node("World/Wheat2").texture_region.position.x == 512.0)
	assert(mill_field.get_node("World/Wheat3").texture_region.position.x == 1024.0)
	for index in range(1, 4):
		assert(mill_field.get_node("World/Wheat%d" % index).interaction_id == "wheat_%d" % index)
	assert(mill_field.get_node_or_null("World/BrokenMillCollision"))
	assert(mill_field.get_node_or_null("World/MillFieldBackdrop/AnimatedWater"))
	assert(not mill_field.get_node_or_null("World/BoatToWoodIsland"))
	assert(not mill_field.get_node_or_null("World/MillFieldBackdrop/BoatDock"))
	mill_field.free()

	var wood_island = preload("res://scenes/wood_island.tscn").instantiate()
	add_child(wood_island)
	await get_tree().process_frame
	assert(wood_island.get_node_or_null("World/IslandBackdrop"))
	assert(wood_island.get_node_or_null("World/Bruno"))
	assert(wood_island.get_node("World/Bruno").interaction_id == "lumberjack")
	assert(wood_island.get_node_or_null("World/BoatToLakeDock"))
	assert(wood_island.get_node_or_null("LumberPuzzlePopup"))
	wood_island.free()

	GameState.pending_travel_scene = "res://scenes/wood_island.tscn"
	var boat_travel = preload("res://scenes/boat_travel.tscn").instantiate()
	add_child(boat_travel)
	await get_tree().process_frame
	assert(boat_travel.get_node_or_null("Boat"))
	assert(boat_travel.get_node_or_null("TravelWater"))
	assert(boat_travel.get_node("Boat").region_rect.size == Vector2(543, 724))
	boat_travel.free()
	GameState.pending_travel_scene = ""

	var wheelwright_yard = preload("res://scenes/wheelwright_yard.tscn").instantiate()
	add_child(wheelwright_yard)
	await get_tree().process_frame
	assert(wheelwright_yard.get_node_or_null("World/WheelwrightBackdrop"))
	assert(wheelwright_yard.get_node_or_null("World/Mateo"))
	assert(wheelwright_yard.get_node("World/Mateo").interaction_id == "wheelwright")
	assert(wheelwright_yard.get_node("World/Mateo").texture.resource_path == "res://assets/gba/mateo_sheet_v1.png")
	assert(wheelwright_yard.get_node_or_null("World/MillFieldExit"))
	assert(wheelwright_yard.get_node("World/MillFieldExit").automatic)
	assert(wheelwright_yard.get_node_or_null("World/Bounds/MateoHouse"))
	assert(wheelwright_yard.get_node_or_null("World/Bounds/CoveredWagon"))
	assert(wheelwright_yard.get_node_or_null("WheelwrightForgePopup"))
	var yard_player := wheelwright_yard.get_node("World/Player") as CharacterBody2D
	yard_player.position = Vector2(720, 560)
	yard_player.move_and_collide(Vector2(0, -260))
	assert(yard_player.position.y > 520.0) # The north shrub wall blocks this path.
	yard_player.position = Vector2(800, 470)
	yard_player.move_and_collide(Vector2(200, -240))
	assert(yard_player.position.y > 382.0) # The approach stops at the house facade.
	wheelwright_yard.free()

	var mill_interior = preload("res://scenes/mill_interior.tscn").instantiate()
	add_child(mill_interior)
	await get_tree().process_frame
	assert(mill_interior.get_node_or_null("World/MillMechanism"))
	assert(mill_interior.get_node_or_null("World/MillExit"))
	assert(mill_interior.get_node_or_null("MillRepairPopup"))
	assert(not mill_interior.get_node_or_null("World/GearPickup"))
	assert(not mill_interior.get_node_or_null("World/RopePickup"))
	assert(not mill_interior.get_node_or_null("World/PlankPickup"))
	mill_interior.free()

	var sheep_farm = preload("res://scenes/sheep_farm.tscn").instantiate()
	add_child(sheep_farm)
	await get_tree().process_frame
	assert(sheep_farm.get_node_or_null("World/VillageExit"))
	assert(sheep_farm.get_node("World/VillageExit").automatic)
	assert(sheep_farm.get_node("World/ClosedFence").get_child_count() == 4)
	assert(not sheep_farm.get_node_or_null("World/PrivatePropertySign"))
	assert(sheep_farm.get_node_or_null("World/IndustrialGate/MovementBlocker"))
	assert(sheep_farm.get_node("World/IndustrialGate").get_prompt() == "E  Examinar puerta cerrada")
	assert(sheep_farm.get_node("World/IndustrialPerimeter").get_child_count() == 2)
	var animated_sheep := 0
	for child in sheep_farm.get_node("World").get_children():
		if child is AnimatedSprite2D and child.name.begins_with("Sheep"):
			animated_sheep += 1
			assert(child.is_playing())
	assert(animated_sheep == 8)
	var steam_machine := sheep_farm.get_node("World/SteamTextileMachine") as Node2D
	assert(steam_machine.is_playing())
	assert(steam_machine.position == Vector2(900, 263))
	assert(steam_machine.has_node("Flywheel") and steam_machine.has_node("DrivePulley"))
	assert(not sheep_farm.get_node_or_null("World/SteamTextileMachineInfo/MovementBlocker"))
	assert(sheep_farm.get_node_or_null("World/Bounds/FactoryYardWall"))
	assert(sheep_farm.get_node_or_null("World/Bounds/CentralTree"))
	assert(sheep_farm.get_node("World/WalkablePathLimits").get_child_count() == 2)
	var farm_player := sheep_farm.get_node("World/Player") as CharacterBody2D
	farm_player.position = Vector2(576, 540)
	farm_player.move_and_collide(Vector2(-300, 0))
	assert(farm_player.position.x >= 500.0)
	farm_player.position = Vector2(576, 540)
	farm_player.move_and_collide(Vector2(300, 0))
	assert(farm_player.position.x <= 650.0)
	farm_player.position = Vector2(576, 500)
	farm_player.move_and_collide(Vector2(0, -150))
	assert(farm_player.position.y >= 455.0)
	sheep_farm.free()

	GameState.reset_progress(false)
	assert(GameState.has_item("herramientas"))
	assert(GameState.get_objective().contains("Elena"))
	var mateo_dialogue := {}
	EventBus.dialogue_requested.connect(func(payload: Dictionary): mateo_dialogue.merge(payload), CONNECT_ONE_SHOT)
	GameState.interact("wheelwright")
	assert(mateo_dialogue.get("speaker", "").contains("Mateo"))
	assert(mateo_dialogue.get("text", "").contains("rueda dentada"))
	assert(GameState.flags.get("wheelwright_spoken", false))
	var gate_dialogue := {}
	EventBus.dialogue_requested.connect(func(payload: Dictionary): gate_dialogue.merge(payload), CONNECT_ONE_SHOT)
	GameState.interact("industrial_gate")
	assert(gate_dialogue.get("text", "") == "No puedes acceder: es una propiedad industrial privada.")

	assert(GameState.interact("wheat_1"))
	assert(GameState.interact("wheat_2"))
	assert(GameState.interact("wheat_3"))
	GameState.interact("villager")
	assert(GameState.get_objective().contains("Mateo"))

	EventBus.dialogue_action_selected.emit("begin_wheelwright_forge")
	assert(not GameState.has_item("herramientas"))
	assert(GameState.complete_wheelwright_forge())
	assert(GameState.complete_lumber_puzzle())
	assert(GameState.has_item("tabla"))
	assert(GameState.complete_rope_puzzle())
	assert(GameState.has_item("cuerda"))
	assert(GameState.install_mill_part("rueda_dentada"))
	assert(GameState.install_mill_part("cuerda"))
	assert(GameState.install_mill_part("tabla"))
	assert(GameState.flags.get("mill_repaired", false))
	EventBus.dialogue_action_selected.emit("mill_wheat")
	assert(GameState.has_item("costal_harina"))
	assert(not GameState.has_item("trigo"))
	EventBus.dialogue_action_selected.emit("sell_flour")
	assert(GameState.coins == 100)
	assert(not GameState.has_item("herramientas"))
	assert(not GameState.has_item("costal_harina"))
	assert(GameState.get_objective().contains("carretas"))
	assert(GameState.book_passenger_coach("res://scenes/station.tscn"))
	assert(GameState.complete_passenger_coach_trip("res://scenes/station.tscn"))
	assert(GameState.get_objective().contains("boleto"))

	EventBus.dialogue_action_selected.emit("buy_ticket")
	assert(GameState.coins == 87)
	assert(GameState.has_item("boleto"))
	assert(GameState.get_objective().contains("tren"))

	assert(GameState.get_puzzle_progress().size() == 4)
	GameState.complete_train_departure()
	assert(GameState.phase_complete)
	assert(int(GameState.phase_two_entry.coins) == 87)
	assert(GameState.phase_two_entry.inventory == GameState.inventory)
	assert(not GameState.phase_two_entry.inventory.has("boleto"))
	assert(FileAccess.file_exists(GameState.REPORT_PATH))
	print("SMOKE TEST OK: recorrido completo de la Fase 1")

	_restore_file(GameState.SAVE_PATH, previous_save, had_save)
	_restore_file(GameState.REPORT_PATH, previous_report, had_report)
	get_tree().quit()


func _restore_file(path: String, contents: PackedByteArray, existed: bool) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_buffer(contents)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

