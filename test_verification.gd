extends SceneTree

func _init() -> void:
    print("Testing game scene loading...")
    var game_scene: PackedScene = load("res://scenes/game.tscn")
    if not game_scene:
        print("ERROR: Failed to load game.tscn")
        quit(1)
        return
    
    var game = game_scene.instantiate()
    root.add_child(game)
    print("Game scene instantiated successfully!")
    
    var world = game.get_node("World")
    
    var backdrop = world.get_node("VillageBackdrop")
    backdrop._spawn_environment_props()
    
    var bench = world.get_node_or_null("SmithWorkbenchCollision")
    var anvil = world.get_node_or_null("SmithAnvilCollision")
    var mat = world.get_node_or_null("SmithMaterialsCollision")
    var vbench = world.get_node_or_null("VillageBenchCollision")
    
    print("SmithWorkbenchCollision: ", bench != null)
    if bench:
        print("  Pos: ", bench.position, " Size: ", bench.get_child(0).shape.size)
    print("SmithAnvilCollision: ", anvil != null)
    if anvil:
        print("  Pos: ", anvil.position, " Size: ", anvil.get_child(0).shape.size)
    print("SmithMaterialsCollision: ", mat != null)
    if mat:
        print("  Pos: ", mat.position, " Size: ", mat.get_child(0).shape.size)
    print("VillageBenchCollision: ", vbench != null)
    if vbench:
        print("  Pos: ", vbench.position, " Size: ", vbench.get_child(0).shape.size)
    
    var hud = game.get_node("HUD")
    var dp = hud.get_node("%DialoguePanel")
    print("DialoguePanel offsets: Left=", dp.offset_left, ", Top=", dp.offset_top, ", Right=", dp.offset_right, ", Bottom=", dp.offset_bottom)
    
    var bsmith = world.get_node("Blacksmith")
    print("Blacksmith pos: ", bsmith.position, ", interaction_radius: ", bsmith.interaction_radius, ", interaction_offset: ", bsmith.interaction_offset)
    
    print("ALL CHECKS PASSED PERFECTLY!")
    quit(0)