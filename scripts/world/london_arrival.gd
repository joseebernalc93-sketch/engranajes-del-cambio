extends Control
## London exploration, railway arrival and a resumable horse-coach journey.
const Journey := preload("res://scripts/world/london_journey.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Journal := preload("res://scripts/ui/chapter_journal.gd")
const RailAudio := preload("res://scripts/world/railway_audio.gd")
const BodyBounds := preload("res://scripts/world/sprite_body_bounds.gd")
const CoachRide := preload("res://scripts/world/london_coach_ride.gd")
const IronMission := preload("res://scripts/core/iron_mission.gd")
const IronPopup := preload("res://scripts/puzzles/iron_mission_popup.gd")
const MineHazards := preload("res://scripts/world/mine_hazards.gd")
const MineArt := preload("res://scripts/world/mine_art.gd")
const MineLift := preload("res://scripts/world/mine_lift_sequence.gd")
const MineLiftRig := preload("res://scripts/world/mine_lift_rig.gd")
const CoalView := preload("res://scripts/puzzles/coal_extraction_view.gd")
const FoundryView := preload("res://scripts/puzzles/foundry_workshop_view.gd")
const FoundryArt := preload("res://scripts/world/foundry_art.gd")
const EngineHouse := preload("res://scripts/world/engine_house_art.gd")
const CALEB := preload("res://assets/phase2/caleb_miner_pixel_v1.png")
const COACHMAN := preload("res://assets/phase2/william_coachman_pixel_v2.png")
const COACH_DESTINATIONS := [
	{"id": "engine", "label": "Ensamble del motor", "available": true},
	{"id": "mine", "label": "El pozo minero", "available": true},
	{"id": "forge", "label": "La forja y fundición", "available": true},
	{"id": "textile", "label": "Nave Textil", "available": false}
]
const SIZE := Vector2(1152, 648)
const ARRIVAL_DURATION := 9.5
const BACKGROUNDS := {
	"platform": preload("res://assets/phase2/london_platform_pixel_v1.png"),
	"hall": preload("res://assets/phase2/london_ticket_hall_pixel_v1.png"),
	"street": preload("res://assets/phase2/london_street_pixel_v1.png"),
	"coach_depot": preload("res://assets/phase2/london_coach_depot_v1.png"),
	"industrial": EngineHouse.YARD,
	"mine_yard": MineArt.SURFACE,
	"mine_house": MineArt.HOUSE,
	"mine_gallery": MineArt.TUNNEL,
	"mine_face": MineArt.EXTRACTION,
	"engine_hall": EngineHouse.HALL,
	"engine_room": EngineHouse.ASSEMBLY,
	"textile_view": preload("res://assets/phase2/textile_pixel_v1.png"),
	"forge_yard": FoundryArt.YARD,
	"forge_hall": FoundryArt.HALL
}
const STAFF := preload("res://assets/phase2/london_staff_pixel_v2.png")
const NEWS_STALL := preload("res://assets/phase2/london_news_stall_pixel_v1.png")
const TRAIN := preload("res://assets/gba/train_industrial_v2.png")
const PEOPLE := preload("res://assets/phase2/london_people_pixel_v1.png")
const DIALOGUES := {
	"guide": ["Henry, encargado del tren", "Bienvenido a Londres. ¿Buscas la salida? Sigue este andén hacia la derecha, bajo el reloj. La arcada conduce al vestíbulo de las boleterías; al otro extremo están las puertas de la ciudad. Camina siempre por el andén: las vías siguen en servicio."],
	"clerk": ["Arthur, boletero", "Has llegado al vestíbulo. No necesitas otro boleto para salir: las puertas de Londres están a tu derecha. Guarda bien tus pertenencias. Si algún día vuelves a viajar, aquí podrás consultar los destinos y comprar tu pasaje."],
	"news": ["Edward, vendedor de periódicos", "¡Noticias de Londres! Llegan nuevos viajeros cada día. Unos buscan trabajo; otros traen mercancías. Acércate, observa y pregunta: esta ciudad tiene más historias de las que caben en una página."],
	"resident": ["Rose, vecina de Londres", "Acabas de llegar, ¿verdad? Tómate un momento para orientarte. Aquí compartimos la calle con carros, caballos y viajeros. La estación es un buen punto de referencia para encontrar el camino de vuelta."],
	"clock": ["El reloj de la estación", "Los horarios ayudan a coordinar la salida de los trenes, los cambios de andén y el trabajo de la estación. El viaje empieza a depender de un tiempo compartido."],
	"coachman": ["William, cochero", "Los talleres están al otro lado del canal. Mi coche te llevará hasta la parada del distrito industrial por 10 monedas; el regreso está incluido. Verás cómo las tiendas dejan paso a almacenes, carbón y chimeneas."],
	"caleb": ["Caleb, minero", "La fábrica necesita carbón. Entra por la puerta bajo el castillete: dentro está la casa del pozo. Acércate al elevador de la derecha y pulsa E para bajar. En el túnel solo puedes ir a izquierda o derecha: cuando escuches crujidos y veas polvo, espera antes del tramo hasta que terminen de caer las piedras. Extrae y separa la hulla al fondo: llenarás tres costales y uno de reserva. Para subir, vuelve al elevador de la izquierda y pulsa E; llegarás a la casa y podrás salir por su puerta. El camino de la izquierda en el patio lleva al motor sin pagar otro coche."],
	"murdoch": ["Murdoch, ingeniero", "El carbón aporta calor, el agua produce vapor y el hierro transmite el movimiento. Primero visita a Caleb en el pozo; después montaremos los engranajes y cerraremos los dos circuitos de agua."],
	"cort": ["Cort, maestro de fundición", "Bienvenido a la fundición. Aquí fundimos el hierro y damos forma a las piezas con el martillo de vapor. Los ejes y las correas mueven los rodillos. Esta planta tiene su propia fuerza motriz; reserva el carbón de la mina para la caldera de Murdoch, que moverá los telares."]
}

var content: Control
var world: Node2D
var backdrop: TextureRect
var player: CharacterBody2D
var scenery: Node2D
var train: Node2D
var ride: CoachRide
var iron: IronMission
var iron_popup: IronPopup
var hazards: MineHazards
var production: Node2D
var pending_city_destination: String = "industrial"
var lift_elapsed: float = -1.0
var lift_returning: bool = false
var lift_start := Vector2.ZERO
var lift_movie: MineLift
var lift_rig: MineLiftRig
var coal_view: CoalView
var foundry_view: FoundryView
var steam: CPUParticles2D
var door: Sprite2D
var hud: CanvasLayer
var journal_overlay: ColorRect
var journal: Journal
var dialogue: PanelContainer
var dialogue_heading: Label
var dialogue_text: Label
var dialogue_kind: String = ""
var journal_home: Button
var map_fade: ColorRect
var fade_tween: Tween
var area: String = "platform"
var elapsed: float = 0.0
var nearest: String = ""
var points: Dictionary = {}
var exit_zones: Dictionary = {}
var interaction_zones: Dictionary = {}
var character_height: float = 60.0
var body_bounds_cache: Dictionary = {}
var character_textures: Dictionary = {}
var actors: Dictionary = {}
var target: Vector2 = Vector2.INF
var pending_interaction: String = ""
var application_focused: bool = true
var changing_area: bool = false
var arrival_announced: bool = false
var sound_elapsed: float = 0.0
var walk_bounds := Rect2(28, 426, 1096, 140)

func _foundry_mistake(reason: String) -> void:
	_message("forge_review", "Cort: revisemos el trabajo", reason + "\nQuedan %d / %d oportunidades. Conservas los pasos aprobados." % [Campaign.remaining(), Campaign.total()])

func _open_foundry(saved: Dictionary = {}) -> void:
	foundry_view.open(saved)
	foundry_view.model.mistake.connect(_foundry_mistake)
	_update_modal_feedback()

func _iron_mistake(reason: String) -> void:
	if is_instance_valid(iron_popup) and iron_popup.is_open():
		iron_popup.show_review()
		return
	var encouragement := "\nNo se ha perdido tu trabajo. Podemos iniciar una nueva ronda." if Campaign.remaining() == 0 else ""
	_message("iron_review", "Caleb: revisemos el trabajo", reason + "\nQuedan %d / %d oportunidades." % [Campaign.remaining(), Campaign.total()] + encouragement)

func _iron_finished() -> void:
	if is_instance_valid(iron_popup): iron_popup.close()
	_message("motor_complete", "Murdoch, ingeniero", "¡Dos minutos de marcha estable! El carbón, el agua y el hierro sostienen ahora el trabajo de la fábrica. Camina hacia la derecha para ver los telares en funcionamiento.")

func _iron_closed() -> void:
	_refresh()
	_update_modal_feedback()

func _begin_lift(returning: bool) -> void:
	if lift_elapsed >= 0.0: return
	lift_returning = returning
	lift_elapsed = 0.0
	lift_start = player.position
	target = Vector2.INF
	pending_interaction = ""
	player.velocity = Vector2.ZERO
	player.controls_enabled = false
	lift_movie.configure(player, character_height, lift_start, returning)
	lift_movie.pose(0.0)
	player.hide()
	if is_instance_valid(lift_rig): lift_rig.hide()
	if DisplayServer.get_name() != "headless": RailAudio.tone(self)
	GameState.save_progress()

func _advance_lift(delta: float) -> void:
	lift_elapsed = minf(MineLift.DURATION, lift_elapsed + maxf(0, delta))
	lift_movie.pose(lift_elapsed)
	if lift_elapsed >= MineLift.DURATION:
		lift_elapsed = -1.0
		var landing := MineArt.HOUSE_EXIT if lift_returning else Vector2(MineArt.LIFT_X + 100, MineArt.FLOOR_Y)
		_set_area("mine_house" if lift_returning else "mine_gallery", landing)
		player.facing = "left" if lift_returning else "right"
		player._set_sprite_frame(1)
		lift_movie.hide()
		player.show()
		if DisplayServer.get_name() != "headless": RailAudio.mechanism(self)
		_update_modal_feedback()
		GameState.save_progress()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var state := Journey.ensure()
	iron = IronMission.new()
	iron.mistake.connect(_iron_mistake)
	iron.finished.connect(_iron_finished)
	if GameState.phase_complete: GameState.consume_train_ticket()
	GameState.phase_two.active = true
	GameState.phase_two.intro_seen = true
	area = str(state.area) if str(state.area) in Journey.AREAS else "platform"
	elapsed = clampf(float(state.elapsed), 0.0, ARRIVAL_DURATION)
	_build()
	_set_area(area, Vector2.ZERO)
	if not state.arrived:
		area = "platform"
		_apply_arrival()
	else:
		elapsed = ARRIVAL_DURATION
	get_viewport().size_changed.connect(_fit)
	_fit()
	_refresh()
	GameState.restore_scene_session.call_deferred(self)

func _build() -> void:
	content = Control.new()
	content.name = "ArrivalContent"
	content.size = SIZE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	backdrop = TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = SIZE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(backdrop)
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	content.add_child(world)
	player = preload("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	# This map supplies keyboard and click-to-walk navigation through the same body.
	player.set_physics_process(false)
	var hero_sprite: Sprite2D = player.get_node("Sprite2D")
	var hero_image := hero_sprite.texture.get_image().get_region(Rect2i(hero_sprite.region_rect))
	character_height = BodyBounds.measure(hero_image).size.y * absf(hero_sprite.scale.y)
	train = Node2D.new()
	train.name = "ArrivalTrain"
	train.z_index = 0
	world.add_child(train)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = TRAIN
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * 0.52
	train.add_child(sprite)
	var wheels := Node2D.new()
	wheels.set_script(preload("res://scripts/world/steam_train.gd"))
	train.add_child(wheels)
	door = Sprite2D.new()
	door.texture = TRAIN
	door.region_enabled = true
	door.region_rect = Rect2(980, 205, 61, 225)
	door.scale = sprite.scale
	door.position = Vector2(-40, -23)
	door.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	train.add_child(door)
	steam = CPUParticles2D.new()
	steam.texture = preload("res://assets/gba/steam_puff_v2.png")
	steam.amount = 22
	steam.lifetime = 2.0
	steam.direction = Vector2(-0.4, -1)
	steam.spread = 24
	steam.gravity = Vector2(-6, -14)
	steam.initial_velocity_min = 17
	steam.initial_velocity_max = 32
	steam.scale_amount_min = 0.10
	steam.scale_amount_max = 0.22
	steam.color = Color(0.9, 0.85, 0.72, 0.40)
	steam.position = Vector2(-470, -104)
	train.add_child(steam)
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	hud.inventory_only = true
	add_child(hud)
	dialogue = hud.dialogue_panel
	dialogue_heading = hud.dialogue_speaker
	dialogue_text = hud.dialogue_text
	hud.local_dialogue_action.connect(func(action: String):
		if action == "cancel_london": _cancel_dialogue()
		elif action.begins_with("coach_destination_"): _select_city_destination(action.trim_prefix("coach_destination_"))
		else: _close_dialogue()
	)
	journal_overlay = ColorRect.new()
	journal_overlay.size = SIZE
	journal_overlay.color = Color(0, 0, 0, 0.73)
	journal_overlay.z_index = 20
	content.add_child(journal_overlay)
	journal = Journal.new()
	journal.journey_mode = true
	journal_overlay.add_child(journal)
	journal.build()
	journal.enable_navigation()
	journal.show_page(2)
	journal.position = Vector2(76, 21)
	journal.continued.connect(_hide_journal)
	journal.restart_requested.connect(GameState.restart_phase)
	journal.page_changed.connect(func(_page: int): GameState.save_progress())
	journal_home = Button.new()
	journal._place_button(journal_home, journal.future, "Menú principal", Rect2(546, 548, 169, 30), false)
	journal_home.pressed.connect(_return_home)
	var restart := Button.new()
	journal._place_button(restart, journal.future, "Reiniciar fase 2", Rect2(726, 548, 169, 30), false)
	restart.pressed.connect(_request_restart)
	journal_overlay.hide()
	map_fade = ColorRect.new()
	map_fade.color = Color(0.09, 0.07, 0.04, 0)
	map_fade.size = SIZE
	map_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_fade.z_index = 30
	content.add_child(map_fade)
	ride = CoachRide.new()
	content.add_child(ride)
	ride.finished.connect(_finish_city_ride)
	iron_popup = preload("res://scenes/iron_mission_puzzle.tscn").instantiate()
	add_child(iron_popup)
	iron_popup.closed.connect(_iron_closed)
	lift_movie = MineLift.new()
	lift_movie.z_index = 15
	content.add_child(lift_movie)
	foundry_view = preload("res://scenes/foundry_workshop.tscn").instantiate()
	foundry_view.z_index = 12
	content.add_child(foundry_view)
	foundry_view.closed.connect(_iron_closed)
	foundry_view.completed.connect(func():
		_message("forge_complete", "Cort, maestro de fundición", "La biela está lista en tu mochila. Llévala a Murdoch en Ensamble del motor: unirá el pistón con la transmisión. Tus costales siguen reservados para su caldera."))
	coal_view = preload("res://scenes/coal_extraction_workface.tscn").instantiate()
	coal_view.z_index = 12
	content.add_child(coal_view)
	coal_view.closed.connect(_iron_closed)
	coal_view.completed.connect(func():
		_refresh()
		_message("coal_ready", "Caleb, minero", "Tres costales de hulla y uno de reserva preparados. Vuelve por la galería y sube en el ascensor; el camino de la izquierda del patio te lleva al motor."))

func _fit() -> void:
	var factor := minf(size.x / SIZE.x, size.y / SIZE.y)
	content.scale = Vector2.ONE * factor
	content.position = (size - SIZE * factor) * 0.5

func _set_area(next_area: String, spawn: Vector2) -> void:
	if next_area not in Journey.AREAS: return
	area = next_area
	var state := Journey.ensure()
	state.area = area
	backdrop.texture = BACKGROUNDS[area]
	if is_instance_valid(scenery):
		world.remove_child(scenery)
		scenery.queue_free()
	scenery = Node2D.new()
	scenery.name = "MapScenery"
	world.add_child(scenery)
	actors.clear()
	points.clear()
	exit_zones.clear()
	interaction_zones.clear()
	hazards = null
	production = null
	lift_rig = null
	player.scale = Vector2.ONE * (MineArt.HERO_SCALE if area in ["mine_house", "mine_gallery", "mine_face"] else 1.0)
	if area == "forge_hall": player.scale = Vector2.ONE * FoundryArt.HERO_SCALE
	if area in ["engine_hall", "engine_room"]: player.scale = Vector2.ONE * EngineHouse.HERO_SCALE
	match area:
		"platform":
			walk_bounds = Rect2(28, 428, 1096, 138)
			_actor("guide", _staff_texture(0), Vector2(803, 472))
			points["hall_exit"] = Vector2(1090, 463)
			exit_zones["hall_exit"] = Rect2(1096, 428, 28, 139)
		"hall":
			walk_bounds = Rect2(28, 383, 1096, 184)
			_actor("clerk", _staff_texture(1), Vector2(568, 407))
			points["platform_exit"] = Vector2(55, 468)
			points["street_exit"] = Vector2(1090, 466)
			points["clock"] = Vector2(465, 391)
			exit_zones["platform_exit"] = Rect2(28, 383, 29, 185)
			exit_zones["street_exit"] = Rect2(1096, 383, 29, 185)
		"street":
			walk_bounds = Rect2(28, 410, 1096, 157)
			_news_stall()
			_actor("news", _person_texture(1), Vector2(289, 539))
			_actor("resident", _person_texture(2), Vector2(984, 500))
			points["station_exit"] = Vector2(227, 418)
			exit_zones["station_exit"] = Rect2(155, 410, 145, 31)
			points["coach_exit"] = Vector2(576, 563)
			exit_zones["coach_exit"] = Rect2(28, 558, 1096, 10)
		"coach_depot":
			walk_bounds = Rect2(28, 410, 1096, 208)
			_park_coach(Vector2(750, 485), false)
			_actor("coachman", COACHMAN, Vector2(650, 560))
			points["plaza_exit"] = Vector2(576, 422)
			exit_zones["plaza_exit"] = Rect2(466, 410, 220, 27)
		"industrial":
			walk_bounds = Rect2(28, 390, 1096, 228)
			_park_coach(EngineHouse.COACH_BERTH, true)
			_actor("coachman", COACHMAN, EngineHouse.COACHMAN_POSITION)
			points["engine_door"] = EngineHouse.YARD_DOOR
			interaction_zones["engine_door"] = Rect2(590, 210, 180, 185)
			points["engine_exit"] = EngineHouse.YARD_DOOR
			exit_zones["engine_exit"] = Rect2(620, 390, 110, 18)
			points["mine_road_exit"] = Vector2(1100, 445)
			exit_zones["mine_road_exit"] = Rect2(1096, 410, 28, 65)
			points["forge_road_exit"] = Vector2(40, 445)
			exit_zones["forge_road_exit"] = Rect2(28, 410, 28, 65)
			_block(Rect2(0, 475, 385, 173))
			_block(Rect2(760, 480, 392, 168))
		"forge_yard":
			walk_bounds = Rect2(28, 455, 1096, 163)
			_park_coach(FoundryArt.COACH_BERTH, true)
			_actor("coachman", COACHMAN, Vector2(650, 560))
			points["forge_door"] = FoundryArt.YARD_DOOR
			interaction_zones["forge_door"] = Rect2(797, 340, 65, 120)
			points["forge_district_exit"] = Vector2(1100, 485)
			exit_zones["forge_district_exit"] = Rect2(1096, 455, 28, 65)
			_block(Rect2(0, 545, 142, 103))
			_block(Rect2(960, 520, 192, 128))
		"forge_hall":
			walk_bounds = Rect2(70, 480, 960, 138)
			_actor("cort", FoundryArt.CORT, FoundryArt.CORT_POSITION)
			points["forge_hall_door"] = FoundryArt.HALL_DOOR
			interaction_zones["forge_hall_door"] = Rect2(70, 330, 80, 170)
			points["forge_hall_exit"] = Vector2(80, 520)
			exit_zones["forge_hall_exit"] = Rect2(70, 480, 28, 138)
			_block(Rect2(955, 480, 197, 168))
		"mine_yard":
			walk_bounds = Rect2(28, 320, 1096, 298)
			_park_coach(Vector2(420, 520), true)
			_actor("coachman", COACHMAN, Vector2(560, 560))
			_actor("caleb", CALEB, Vector2(630, 425))
			points["mine_door"] = Vector2(765, 355)
			interaction_zones["mine_door"] = Rect2(720, 260, 90, 95)
			points["factory_road_exit"] = Vector2(40, 450)
			exit_zones["factory_road_exit"] = Rect2(28, 358, 28, 260)
		"mine_house":
			walk_bounds = Rect2(70, 452, 1010, 80)
			points["house_door"] = Vector2(145, 480)
			interaction_zones["house_door"] = Rect2(85, 240, 130, 230)
			points["lift"] = MineArt.HOUSE_LANDING + Vector2(0, 28)
			interaction_zones["lift"] = Rect2(685, 245, 160, 235)
			_place_lift(MineArt.HOUSE_LANDING, character_height * MineArt.HERO_SCALE)
		"mine_gallery":
			walk_bounds = Rect2(58, MineArt.FLOOR_Y, 1032, 0)
			points["lift_up"] = Vector2(MineArt.LIFT_X, MineArt.FLOOR_Y)
			interaction_zones["lift_up"] = Rect2(50, 300, 105, 115)
			points["coal_gallery_exit"] = Vector2(1105, MineArt.FLOOR_Y)
			exit_zones["coal_gallery_exit"] = Rect2(1070, MineArt.FLOOR_Y - 5, 60, 15)
			_place_lift(Vector2(MineArt.LIFT_X, MineArt.FLOOR_Y), character_height * MineArt.HERO_SCALE)
			hazards = MineHazards.new()
			hazards.mission = iron
			scenery.add_child(hazards)
			hazards.warned.connect(func():
				if not _blocked() and DisplayServer.get_name() != "headless": RailAudio.mechanism(self))
		"mine_face":
			walk_bounds = Rect2(58, MineArt.FLOOR_Y, 1032, 0)
			var wagon := preload("res://scripts/world/mine_wagon.gd").new()
			wagon.name = "MineWagon"
			wagon.mission = iron
			scenery.add_child(wagon)
			points["gallery_back_exit"] = Vector2(65, MineArt.FLOOR_Y)
			exit_zones["gallery_back_exit"] = Rect2(45, MineArt.FLOOR_Y - 5, 35, 15)
			points["vein"] = Vector2(720, MineArt.FLOOR_Y)
			interaction_zones["vein"] = Rect2(560, 215, 340, 200)
		"engine_hall":
			walk_bounds = Rect2(75, 365, 1000, 253)
			_actor("murdoch", EngineHouse.MURDOCH, EngineHouse.MURDOCH_POSITION)
			points["engine_hall_door"] = EngineHouse.HALL_OUTSIDE
			interaction_zones["engine_hall_door"] = Rect2(55, 140, 125, 300)
			points["engine_hall_back_exit"] = Vector2(80, 435)
			exit_zones["engine_hall_back_exit"] = Rect2(75, 410, 28, 80)
			points["engine_mount_door"] = EngineHouse.HALL_MOUNTING
			interaction_zones["engine_mount_door"] = Rect2(815, 100, 210, 300)
			points["engine_mount_exit"] = EngineHouse.HALL_MOUNTING
			exit_zones["engine_mount_exit"] = Rect2(850, 365, 150, 20)
			_block(Rect2(210, 355, 600, 70))
			_block(Rect2(0, 500, 170, 148))
			_block(Rect2(1040, 450, 112, 198))
		"engine_room":
			walk_bounds = Rect2(75, 420, 1049, 198)
			points["engine_bench"] = EngineHouse.BENCH
			interaction_zones["engine_bench"] = Rect2(755, 425, 330, 120)
			points["engine_return_door"] = EngineHouse.ROOM_DOOR
			interaction_zones["engine_return_door"] = Rect2(60, 150, 145, 285)
			points["engine_back_exit"] = Vector2(80, 435)
			exit_zones["engine_back_exit"] = Rect2(75, 420, 28, 65)
			points["textile_exit"] = EngineHouse.TEXTILE_EXIT
			exit_zones["textile_exit"] = Rect2(1096, 420, 28, 45)
			_block(Rect2(0, 465, 180, 183))
			_block(Rect2(760, 465, 392, 183))
		"textile_view":
			walk_bounds = Rect2(260, 550, 735, 68)
			points["motor_exit"] = Vector2(270, 585)
			exit_zones["motor_exit"] = Rect2(260, 550, 28, 68)
			production = preload("res://scripts/world/textile_production.gd").new()
			production.elapsed = float(iron.data.production_seconds)
			scenery.add_child(production)
	# Physical perimeter and NPC footprints prevent walking on tracks or walls.
	if area not in ["mine_gallery", "mine_face"]:
		_block(Rect2(-50, walk_bounds.position.y - 100, 1252, 100))
		_block(Rect2(-50, walk_bounds.end.y + 10, 1252, 100))
	_block(Rect2(-60, 0, 70, 648))
	_block(Rect2(1142, 0, 70, 648))
	var saved_positions: Dictionary = state.positions
	var previous: Array = saved_positions.get(area, [])
	if spawn != Vector2.ZERO: player.position = spawn
	elif previous.size() == 2: player.position = Vector2(float(previous[0]), float(previous[1]))
	else: player.position = {"platform": Vector2(548, 460), "hall": Vector2(110, 468), "street": Vector2(252, 447), "coach_depot": Vector2(576, 465), "industrial": EngineHouse.COACH_LANDING, "mine_yard": Vector2(650, 590), "mine_house": Vector2(260, 495), "mine_gallery": Vector2(195, MineArt.FLOOR_Y), "mine_face": Vector2(150, MineArt.FLOOR_Y), "engine_hall": EngineHouse.HALL_LANDING, "engine_room": EngineHouse.ROOM_LANDING, "textile_view": Vector2(320, 590), "forge_yard": FoundryArt.COACH_LANDING, "forge_hall": Vector2(200, 535)}[area]
	player.position = player.position.clamp(walk_bounds.position, walk_bounds.end)
	player.position = EngineHouse.safe_position(area, player.position)
	player.velocity = Vector2.ZERO
	player.facing = "right" if area in ["mine_gallery", "mine_face"] else "down"
	player._set_sprite_frame(1)
	target = Vector2.INF
	pending_interaction = ""
	train.visible = area == "platform"
	steam.emitting = train.visible
	if bool(state.arrived):
		train.position = Vector2(576, 280)
		player.show()
	state.positions[area] = [player.position.x, player.position.y]
	_refresh()
	_update_nearest()

func _place_lift(point: Vector2, height: float) -> void:
	lift_rig = MineLiftRig.new()
	lift_rig.position = point
	lift_rig.hero_height = height
	scenery.add_child(lift_rig)

func _park_coach(pos: Vector2, facing_left: bool) -> void:
	var coach := preload("res://scenes/world/passenger_coach.tscn").instantiate()
	coach.name = "LondonParkedCoach"
	coach.position = pos
	coach.scale = Vector2.ONE * 0.92
	coach.facing_left = facing_left
	coach.driver_visible = false
	scenery.add_child(coach)
	coach.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	interaction_zones["coachman"] = Rect2(pos - Vector2(180, 125), Vector2(360, 125))
	_block(Rect2(pos - Vector2(85, 18), Vector2(165, 22)))

func _actor(id: String, texture: Texture2D, pos: Vector2) -> void:
	var actor := Node2D.new()
	actor.position = pos
	scenery.add_child(actor)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	if not body_bounds_cache.has(texture):
		body_bounds_cache[texture] = BodyBounds.measure(texture.get_image())
	var visible_rect: Rect2i = body_bounds_cache[texture]
	sprite.region_rect = Rect2(visible_rect)
	sprite.region_filter_clip_enabled = true
	# Match the opaque body, not the atlas padding or almost invisible alpha haze.
	var visible_height := character_height * absf(player.scale.y)
	var scale_factor := visible_height / maxf(1.0, visible_rect.size.y)
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(0, -visible_height * 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.add_child(sprite)
	actors[id] = actor
	points[id] = pos
	_block(Rect2(pos - Vector2(13, 15), Vector2(26, 18)))

func _news_stall() -> void:
	var stall := Node2D.new()
	stall.name = "NewspaperStall"
	stall.position = Vector2(166, 552)
	scenery.add_child(stall)
	var sprite := Sprite2D.new()
	sprite.texture = NEWS_STALL
	sprite.region_enabled = true
	sprite.region_rect = Rect2(NEWS_STALL.get_image().get_used_rect())
	sprite.scale = Vector2.ONE * (144.0 / sprite.region_rect.size.x)
	sprite.position.y = -sprite.region_rect.size.y * sprite.scale.y * 0.5
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stall.add_child(sprite)
	interaction_zones["news"] = Rect2(94, 552 - sprite.region_rect.size.y * sprite.scale.y, 144, sprite.region_rect.size.y * sprite.scale.y)
	_block(Rect2(108, 534, 116, 18))

func _person_texture(index: int) -> AtlasTexture:
	return _character_texture("person_%d" % index, PEOPLE, Vector2i(2, 2), index)

func _staff_texture(index: int) -> AtlasTexture:
	return _character_texture("staff_%d" % index, STAFF, Vector2i(2, 1), index)

func _character_texture(key: String, atlas: Texture2D, grid: Vector2i, index: int) -> AtlasTexture:
	if character_textures.has(key): return character_textures[key]
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	var cell := atlas.get_size() / Vector2(grid)
	texture.region = Rect2(Vector2(index % grid.x, floori(float(index) / grid.x)) * cell, cell)
	character_textures[key] = texture
	return texture

func _block(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	scenery.add_child(body)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if is_instance_valid(foundry_view) and foundry_view.is_open():
		_update_modal_feedback()
		foundry_view.advance(delta)
		player.controls_enabled = false
		return
	if is_instance_valid(coal_view) and coal_view.is_open():
		_update_modal_feedback()
		coal_view.advance(delta)
		player.controls_enabled = false
		return
	if lift_elapsed >= 0.0:
		if not _modal_blocked(): _advance_lift(delta)
		player.controls_enabled = not _blocked()
		_update_modal_feedback()
		return
	if area == "mine_gallery" and not _blocked() and is_instance_valid(hazards):
		hazards.advance(delta)
		if hazards.collision_at(player.position) and not bool(iron.data.complete):
			player.position = hazards.safe_position(player.position)
			target = Vector2.INF
			pending_interaction = ""
			player.velocity = Vector2.ZERO
			iron.fail("El polvo y los crujidos anunciaban un desprendimiento. Detente antes del tramo y espera a que terminen de caer las piedras; el túnel tiene un solo paso. Conservas las galerías recorridas y el carbón recogido.")
		elif iron.stage() == 0:
			for checkpoint_index in 3:
				if player.position.x >= MineHazards.CHECKPOINTS[checkpoint_index]: iron.reach_route(checkpoint_index)
		iron.tick(delta)
	if area == "textile_view" and bool(iron.data.complete) and not _blocked():
		iron.data.production_seconds = float(iron.data.production_seconds) + delta
		production.elapsed = float(iron.data.production_seconds)
		production.queue_redraw()
	if is_instance_valid(ride) and ride.active:
		if not _modal_blocked(): ride.advance(delta)
		player.controls_enabled = not _blocked()
		_update_modal_feedback()
		return
	var blocked := _blocked()
	steam.speed_scale = 0.0 if blocked else 1.0
	if not Journey.ensure().arrived and not blocked:
		elapsed = minf(ARRIVAL_DURATION, elapsed + delta)
		_apply_arrival()
		if elapsed >= ARRIVAL_DURATION:
			Journey.ensure().arrived = true
			player.show()
			RailAudio.tone(self)
			_refresh()
			GameState.save_progress()
		elif elapsed >= 6.0 and not arrival_announced:
			arrival_announced = true
			RailAudio.tone(self, false)
	else:
		_update_nearest()
	player.controls_enabled = not blocked and bool(Journey.ensure().arrived)
	_update_modal_feedback()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or _blocked() or not Journey.ensure().arrived: return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var walk_speed: float = player.speed / MineArt.HERO_SCALE if area in ["mine_gallery", "mine_face"] else player.speed
	if area in ["mine_gallery", "mine_face"]:
		direction = Vector2(Input.get_axis("move_left", "move_right"), 0)
		player.position.y = MineArt.FLOOR_Y
	if direction != Vector2.ZERO:
		target = Vector2.INF
		pending_interaction = ""
	elif target != Vector2.INF:
		var distance := player.position.distance_to(target)
		if distance <= 6.0:
			target = Vector2.INF
			if not pending_interaction.is_empty():
				var id := pending_interaction
				pending_interaction = ""
				_interact(id)
		else: direction = player.position.direction_to(target) * minf(1.0, distance / maxf(1, walk_speed * delta))
	player.velocity = direction * walk_speed
	player._update_walk_animation(direction, delta)
	player.move_and_slide()
	player.position = player.position.clamp(walk_bounds.position, walk_bounds.end)
	# Broad edge zones allow walking out at any height along each corridor.
	for id in exit_zones:
		if _leaves_map(str(id), direction) and exit_zones[id].has_point(player.position):
			_interact(id)
			break

func _leaves_map(id: String, direction: Vector2) -> bool:
	match id:
		"coach_exit": return direction.y > 0.0
		"station_exit", "plaza_exit": return direction.y < 0.0
		"hall_exit", "street_exit": return direction.x > 0.0
		"platform_exit": return direction.x < 0.0
		"engine_exit", "engine_mount_exit": return direction.y < 0.0
		"mine_road_exit", "textile_exit": return direction.x > 0.0
		"factory_road_exit", "engine_back_exit", "engine_hall_back_exit", "motor_exit", "forge_road_exit", "forge_hall_exit": return direction.x < 0.0
		"forge_district_exit": return direction.x > 0.0
		"coal_gallery_exit": return direction.x > 0.0
		"gallery_back_exit": return direction.x < 0.0
	return false

func _blocked() -> bool:
	return _modal_blocked() or (is_instance_valid(ride) and ride.active) or lift_elapsed >= 0.0

func _modal_blocked() -> bool:
	if not is_instance_valid(journal_overlay) or not is_instance_valid(dialogue): return true
	return not application_focused or changing_area or journal_overlay.visible or dialogue.visible or (is_instance_valid(hud) and hud.inventory_overlay.visible) or (is_instance_valid(iron_popup) and iron_popup.is_open()) or (is_instance_valid(coal_view) and coal_view.is_open()) or (is_instance_valid(foundry_view) and foundry_view.is_open())

func _apply_arrival() -> void:
	var progress := clampf(elapsed / 6.0, 0, 1)
	train.position = Vector2(576 + 1480 * pow(1.0 - progress, 3), 280)
	door.position.x = -40 + 30 * clampf((elapsed - 6.2) / 0.6, 0, 1)
	player.visible = elapsed >= 7.1
	if player.visible:
		player.position = Vector2(548, lerpf(379, 462, clampf((elapsed - 7.1) / 1.8, 0, 1)))
		player.facing = "down"
		player._update_walk_animation(Vector2.DOWN, 0.016)
		player.modulate.a = clampf((elapsed - 7.1) / 0.35, 0, 1)
	if elapsed >= ARRIVAL_DURATION: player.modulate.a = 1.0
	# Wheel/rail cadence follows the deceleration rather than a looping animation.
	if elapsed < 5.5:
		sound_elapsed += get_process_delta_time()
		if sound_elapsed > lerpf(0.14, 0.65, progress):
			sound_elapsed = 0
			RailAudio.mechanism(self)

func _update_nearest() -> void:
	nearest = ""
	var distance := 88.0
	for id in points:
		if str(id).ends_with("_exit"): continue
		var candidate := player.position.distance_to(points[id])
		if candidate < distance:
			distance = candidate
			nearest = id
	_update_prompt()

func _update_prompt() -> void:
	if not is_instance_valid(hud) or not hud.is_node_ready() or not hud.is_inside_tree(): return
	var text := ""
	if not _blocked() and Journey.ensure().arrived and not nearest.is_empty():
		if actors.has(nearest): text = "E  Hablar con " + str(DIALOGUES[nearest][0])
		elif nearest == "clock": text = "E  Observar el reloj"
		elif nearest == "lift": text = "E  Bajar al pozo"
		elif nearest == "mine_door": text = "E  Entrar a la mina"
		elif nearest == "house_door": text = "E  Salir al patio"
		elif nearest == "lift_up": text = "E  Subir a la superficie"
		elif nearest == "vein": text = "E  Extraer y clasificar carbón"
		elif nearest == "engine_bench": text = "E  Trabajar en el motor"
		elif nearest == "engine_door": text = "E  Entrar a la casa de máquinas"
		elif nearest == "engine_hall_door": text = "E  Salir al patio"
		elif nearest == "engine_mount_door": text = "E  Entrar a la sala de montaje"
		elif nearest == "engine_return_door": text = "E  Volver a la nave de ensamble"
		elif nearest == "forge_door": text = "E  Entrar a la fundición"
		elif nearest == "forge_hall_door": text = "E  Salir al patio"
	hud._set_prompt(text)

func _interact_nearest() -> void:
	if not nearest.is_empty(): _interact(nearest)

func _interact(id: String) -> void:
	if _blocked() or not Journey.ensure().arrived or not points.has(id): return
	if not exit_zones.has(id) and player.position.distance_to(points[id]) > 100: return
	match id:
		"hall_exit": _travel("hall", Vector2(114, 468))
		"platform_exit": _travel("platform", Vector2(1030, 465))
		"street_exit": _travel("street", Vector2(252, 447))
		"station_exit": _travel("hall", Vector2(1030, 468))
		"coach_exit": _travel("coach_depot", Vector2(576, 465))
		"plaza_exit": _travel("street", Vector2(576, 522))
		"mine_road_exit": _travel("mine_yard", Vector2(100, 480))
		"factory_road_exit": _travel("industrial", Vector2(1030, 490))
		"forge_road_exit": _travel("forge_yard", Vector2(1050, 485))
		"forge_district_exit": _travel("industrial", Vector2(100, 490))
		"forge_door": _travel("forge_hall", Vector2(200, 535))
		"forge_hall_door", "forge_hall_exit": _travel("forge_yard", FoundryArt.YARD_DOOR + Vector2(0, 35))
		"mine_door": _travel("mine_house", Vector2(260, 495))
		"house_door": _travel("mine_yard", Vector2(765, 385))
		"coal_gallery_exit":
			if iron.stage() > 0: _travel("mine_face", Vector2(150, MineArt.FLOOR_Y))
		"gallery_back_exit": _travel("mine_gallery", Vector2(1030, MineArt.FLOOR_Y))
		"engine_door", "engine_exit": _travel("engine_hall", EngineHouse.HALL_LANDING)
		"engine_hall_door", "engine_hall_back_exit": _travel("industrial", EngineHouse.YARD_DOOR + Vector2(0, 45))
		"engine_mount_door", "engine_mount_exit": _travel("engine_room", EngineHouse.ROOM_LANDING)
		"engine_return_door", "engine_back_exit": _travel("engine_hall", EngineHouse.HALL_MOUNTING + Vector2(0, 50))
		"motor_exit": _travel("engine_room", Vector2(1030, 435))
		"textile_exit":
			if bool(iron.data.complete): _travel("textile_view", Vector2(320, 590))
			else: _message("motor_pending", "Murdoch, ingeniero", "La transmisión aún está detenida. Completa el ensayo de dos minutos para mover los telares.")
		"lift":
			if not bool(iron.data.started): _message("caleb_intro", "Caleb, minero", "Habla conmigo junto al pozo antes de bajar: te indicaré cómo reconocer los desprendimientos y dónde recoger la hulla.")
			else: _begin_lift(false)
		"lift_up": _begin_lift(true)
		"caleb":
			iron.start()
			_message("caleb", DIALOGUES.caleb[0], DIALOGUES.caleb[1] if iron.stage() <= 1 else "Puedes volver a extraer carbón al fondo del pozo. El camino de la izquierda conecta con Ensamble del motor sin otro pasaje; conserva los costales para alimentar el fuego.")
		"murdoch":
			_message("murdoch", DIALOGUES.murdoch[0], "Bienvenido a la casa de máquinas. El arco del fondo lleva a la sala de montaje: acércate allí al motor y pulsa E para trabajar. " + ("Traes la biela de Cort; podrás instalarla junto al pistón. Conserva los costales para la caldera." if GameState.has_item("biela") else "Necesitaremos el carbón del pozo y la biela de Cort. Los caminos del patio conectan con ambos talleres."))
		"engine_bench":
			if bool(iron.data.complete): _message("motor_complete", "Murdoch, ingeniero", "¡La máquina mantiene su marcha! El carbón produce calor, el vapor mueve el pistón y los engranajes transmiten la fuerza. Camina hacia la derecha para observar la nave textil en funcionamiento.")
			elif iron.stage() < 2: _message("murdoch", DIALOGUES.murdoch[0], DIALOGUES.murdoch[1])
			elif iron.stage() == 2 and not bool(iron.data.biela_installed):
				if GameState.has_item("biela"): _message("motor_biela", "Murdoch, ingeniero", "La biela de Cort encaja entre el pistón y el volante. ¿La instalamos para empezar el montaje de los engranajes?")
				else: _message("biela_pending", "Murdoch, ingeniero", "Ya tienes el combustible. Visita a Cort en la forja y fundición, por el camino de la izquierda del distrito industrial, para fabricar la biela. Guarda los costales para mi caldera.")
			else: iron_popup.open(iron)
		"vein":
			if iron.stage() == 0: _message("route_pending", "Caleb, minero", "Primero recorre los tres tramos de la galería. Espera antes de los desprendimientos y cruza cuando dejen de caer piedras.")
			elif int(GameState.inventory.get(IronMission.COAL_ITEM, 0)) >= 4: _message("coal_full", "Caleb, minero", "Ya llevas los cuatro costales preparados. Guárdalos para la caldera; podrás reponerlos cuando necesites combustible.")
			else: coal_view.open(iron, iron.stage() > 1)
		"cort":
			if Campaign.done("forge"): _message("forge_complete", DIALOGUES.cort[0], "La biela ya está terminada. Llévala a Murdoch en Ensamble del motor; si ya la instalaste, continúa allí con los engranajes y el agua.")
			else: _message("cort", DIALOGUES.cort[0], "Fabricaremos la biela que unirá el pistón con la transmisión de Murdoch. Elegirás el hierro, lo calentarás, le darás forma, perforarás los ojos, ajustarás la pieza y probarás su movimiento. La planta aporta el hierro y su combustible: guarda tus costales para la caldera.")
		"coachman": _offer_city_coach()
		_:
			if DIALOGUES.has(id): _message(id, DIALOGUES[id][0], DIALOGUES[id][1])

func _offer_city_coach() -> void:
	_message("coach_destinations", "William, cochero", "¿A dónde deseas ir? El pasaje cuesta 10 monedas e incluye el regreso a la estación.")

func _select_city_destination(destination: String) -> void:
	if not Journey.COACH_ROUTES.has(destination) or dialogue_kind != "coach_destinations": return
	pending_city_destination = Journey.COACH_ROUTES[destination]
	if area == "industrial":
		pending_city_destination = area
		_message("coach_trip", "William, cochero", "Ya estamos en Ensamble del motor. Tu pasaje incluye el regreso a la parada junto a la estación de Londres. ¿Volvemos? No pagarás más monedas.")
	elif area == "mine_yard":
		pending_city_destination = "mine_yard"
		_message("coach_trip", "William, cochero", "Tu pasaje incluye el regreso a la estación. También puedes ir al motor por el camino de la izquierda, sin pagar otro viaje. ¿Regresamos en coche?")
	elif area == "forge_yard":
		pending_city_destination = area
		_message("coach_trip", "William, cochero", "Tu pasaje incluye el regreso a la estación. El camino de la derecha también lleva al distrito industrial, sin pagar otro viaje. ¿Regresamos en coche?")
	elif GameState.coins < Journey.COACH_FARE:
		_message("coach_unaffordable", "William, cochero", "El viaje cuesta 10 monedas. Ahora tienes %d. Puedes seguir explorando y volver cuando tengas el importe; no te cobraré nada todavía." % GameState.coins)
	else:
		var label: String = {"engine": "Ensamble del motor", "mine": "El pozo minero", "forge": "La forja y fundición"}[destination]
		_message("coach_trip", "William, cochero", "Te llevaré a %s por 10 monedas. El pasaje incluye el regreso a esta parada. ¿Salimos?" % label)

func _book_city_coach() -> bool:
	if ride.active or (area != "coach_depot" and area not in Journey.COACH_STOPS): return false
	var returning := area != "coach_depot"
	if not returning and pending_city_destination not in Journey.COACH_STOPS: return false
	if not returning and GameState.coins < Journey.COACH_FARE:
		_message("coach_unaffordable", "William, cochero", "El viaje cuesta 10 monedas. Ahora tienes %d; no te cobraré nada todavía." % GameState.coins)
		return false
	if not returning:
		GameState.coins -= Journey.COACH_FARE
		var transport: Dictionary = GameState.phase_two.city_transport
		transport.outbound_trips = int(transport.outbound_trips) + 1
		transport.fares_paid = int(transport.fares_paid) + Journey.COACH_FARE
		EventBus.coins_changed.emit(GameState.coins)
		GameState.record_event("Pagó 10 monedas por el coche al distrito industrial de Londres, con regreso incluido.")
	ride.begin(returning, player.position, 0.0, area if returning else pending_city_destination)
	target = Vector2.INF
	pending_interaction = ""
	_update_modal_feedback()
	GameState.save_progress()
	return true

func _finish_city_ride() -> void:
	var returning := ride.returning
	var landing := Vector2(650, 590) if returning or ride.destination_area == "mine_yard" else Vector2(350, 590)
	if not returning and ride.destination_area == "industrial": landing = EngineHouse.COACH_LANDING
	_set_area("coach_depot" if returning else ride.destination_area, landing)
	if not returning: GameState.phase_two.city_transport.industrial_reached = true
	_update_modal_feedback()
	_refresh()
	GameState.save_progress()

func _travel(destination: String, spawn: Vector2) -> void:
	if changing_area: return
	Journey.ensure().positions[area] = [player.position.x, player.position.y]
	changing_area = true
	target = Vector2.INF
	pending_interaction = ""
	fade_tween = create_tween()
	fade_tween.tween_property(map_fade, "color:a", 1.0, 0.22)
	fade_tween.tween_callback(func():
		_set_area(destination, spawn)
		changing_area = false
		if destination == "street" and not Journey.ensure().city_reached:
			Journey.ensure().city_reached = true
		_refresh()
		GameState.save_progress())
	fade_tween.tween_property(map_fade, "color:a", 0.0, 0.28)

func _message(kind: String, title: String, text: String) -> void:
	dialogue_kind = kind
	var options: Array[Dictionary] = [{"label": "Sí, reiniciar fase 2" if kind == "restart" else "Continuar", "action": "continue_london"}]
	if kind == "restart": options.append({"label": "Cancelar", "action": "cancel_london"})
	if kind == "coach_trip":
		options = [{"label": "Regresar · Incluido" if area in Journey.COACH_STOPS else "Viajar · 10 monedas", "action": "continue_london"}, {"label": "Todavía no", "action": "cancel_london"}]
	if kind in ["iron_review", "forge_review"]: options = [{"label": "Iniciar nueva ronda" if Campaign.remaining() == 0 else "Continuar esta fase", "action": "continue_london"}]
	if kind in ["cort", "motor_biela"]:
		options = [{"label": "Trabajar con Cort" if kind == "cort" else "Entregar e instalar biela", "action": "continue_london"}, {"label": "Ahora no", "action": "cancel_london"}]
	if kind == "coach_destinations":
		options.clear()
		for destination in COACH_DESTINATIONS:
			options.append({"label": destination.label, "action": "coach_destination_" + str(destination.id), "disabled": not bool(destination.available), "tooltip": "" if bool(destination.available) else "Este destino aún no ofrece viajes."})
	hud._show_dialogue({"speaker": title, "text": text, "options": options})
	target = Vector2.INF
	pending_interaction = ""
	player.controls_enabled = false
	(hud.dialogue_options.find_children("*", "Button", true, false)[0] as Button).grab_focus()
	_update_modal_feedback()
	GameState.save_progress()

func _close_dialogue() -> void:
	var kind := dialogue_kind
	dialogue.hide()
	dialogue_kind = ""
	if kind == "coach_trip":
		_book_city_coach()
		return
	if kind == "forge_review":
		foundry_view.model.resume()
		_update_modal_feedback()
		GameState.save_progress()
		return
	if kind == "motor_biela":
		if iron.install_biela(): iron_popup.open(iron)
		_update_modal_feedback()
		GameState.save_progress()
		return
	if kind == "cort":
		var talked: Array = Journey.ensure().talked
		if "cort" not in talked: talked.append("cort")
		_open_foundry()
		return
	if kind == "iron_review":
		iron.resume()
		_refresh()
		_update_modal_feedback()
		GameState.save_progress()
		return
	if kind == "restart":
		GameState.restart_phase_two()
		return
	var state := Journey.ensure()
	if kind == "guide":
		state.guide_spoken = true
	if kind == "clerk": state.clerk_spoken = true
	if kind in DIALOGUES and kind not in state.talked: state.talked.append(kind)
	_refresh()
	_update_modal_feedback()
	GameState.save_progress()

func _cancel_dialogue() -> void:
	if dialogue_kind in ["iron_review", "forge_review"]:
		_close_dialogue()
		return
	dialogue.hide()
	dialogue_kind = ""
	_update_modal_feedback()
	GameState.save_progress()

func _refresh() -> void:
	journal.refresh(GameState.build_report())

func _show_journal() -> void:
	if dialogue.visible or changing_area or hud.inventory_overlay.visible: return
	if coal_view.is_open(): coal_view.cancel_gesture()
	if foundry_view.is_open(): foundry_view.cancel_gesture()
	if iron_popup.is_open():
		iron_popup.board.cancel_drag()
		iron_popup.suspended = true
		iron_popup.layer = -1
	_refresh()
	journal_overlay.show()
	target = Vector2.INF
	pending_interaction = ""
	player.controls_enabled = false
	_update_modal_feedback()
	journal.continue_button.grab_focus() if journal.current_page == 1 else journal.journey_continue.grab_focus()
	GameState.save_progress()

func _hide_journal() -> void:
	journal_overlay.hide()
	if iron_popup.is_open():
		iron_popup.layer = 20
		iron_popup.suspended = false
	_update_modal_feedback()
	GameState.save_progress()

func _show_inventory() -> void:
	if not hud.inventory_overlay.visible and _modal_blocked() and not iron_popup.is_open() and not coal_view.is_open() and not foundry_view.is_open(): return
	if iron_popup.is_open():
		iron_popup.suspended = not hud.inventory_overlay.visible
		iron_popup.layer = -1 if iron_popup.suspended else 20
	target = Vector2.INF
	pending_interaction = ""
	hud._toggle_inventory()
	_update_modal_feedback()
	GameState.save_progress()

func _request_restart() -> void:
	journal_overlay.hide()
	_message("restart", "Reiniciar fase 2", "La Fase 2 volverá a comenzar desde la historia y la llegada a Londres. Se borrarán sus puzzles, descubrimientos y objetos; recuperarás las monedas y pertenencias con las que terminaste la Fase 1. La Fase 1 seguirá completada y conservarás la dificultad. ¿Quieres reiniciar?")

func _return_home() -> void:
	GameState.save_progress()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if not is_instance_valid(journal_overlay): return
	if event is InputEventKey and foundry_view.is_open() and not foundry_view.paused and event.keycode not in [KEY_ESCAPE, KEY_I, KEY_TAB]:
		foundry_view.keyboard(event)
		return
	if event is InputEventKey and is_instance_valid(coal_view) and coal_view.is_open() and not coal_view.paused and event.keycode not in [KEY_ESCAPE, KEY_I]:
		coal_view.keyboard(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB and (journal_overlay.visible or dialogue.visible or hud.inventory_overlay.visible or iron_popup.is_open() or foundry_view.is_open()):
			_cycle_focus(event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif journal_overlay.visible and event.keycode in [KEY_LEFT, KEY_RIGHT]:
			journal.turn_to(1 if event.keycode == KEY_LEFT else 2)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if hud.inventory_overlay.visible:
				hud._close_inventory()
				if iron_popup.is_open():
					iron_popup.suspended = false
					iron_popup.layer = 20
			elif dialogue.visible: _cancel_dialogue()
			elif journal_overlay.visible: _hide_journal()
			else: _show_journal()
			get_viewport().set_input_as_handled()

func _cycle_focus(reverse: bool) -> void:
	var buttons: Array[Button] = []
	var modal: Node = hud.inventory_overlay if hud.inventory_overlay.visible else (dialogue if dialogue.visible else (journal if journal_overlay.visible else foundry_view if foundry_view.is_open() else iron_popup.panel))
	if iron_popup.is_open() and iron_popup.notice.visible and not journal_overlay.visible and not hud.inventory_overlay.visible: modal = iron_popup.notice
	for child in modal.find_children("*", "Button", true, false):
		if child.is_visible_in_tree() and not child.disabled: buttons.append(child)
	if buttons.is_empty(): return
	var index := buttons.find(get_viewport().gui_get_focus_owner())
	buttons[posmod(index + (-1 if reverse else 1), buttons.size())].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if hud.inventory_overlay.visible: hud._close_inventory()
		elif dialogue.visible: _cancel_dialogue()
		elif journal_overlay.visible: _hide_journal()
		else: _show_journal()
	elif event.is_action_pressed("inventory"): _show_inventory()
	elif event.is_action_pressed("interact") and not _blocked(): _interact_nearest()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_navigate_pointer(content.get_global_transform().affine_inverse() * event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_navigate_pointer(content.get_global_transform().affine_inverse() * event.position)
	else: return
	get_viewport().set_input_as_handled()

func _navigate_pointer(pos: Vector2) -> void:
	if _blocked() or not Journey.ensure().arrived: return
	var walk_pos := Vector2(pos.x, MineArt.FLOOR_Y) if area in ["mine_gallery", "mine_face"] else pos
	pending_interaction = ""
	for id in points:
		if str(id).ends_with("_exit"): continue
		if pos.distance_to(points[id] - Vector2(0, 30)) < 45 or (interaction_zones.has(id) and interaction_zones[id].has_point(pos)):
			pending_interaction = id
			var point: Vector2 = points[id]
			target = (point + Vector2(-45 if point.x > player.position.x else 45, 18)).clamp(walk_bounds.position, walk_bounds.end)
			return
	target = walk_pos.clamp(walk_bounds.position, walk_bounds.end)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_focused = false
		target = Vector2.INF
		pending_interaction = ""
		if is_instance_valid(player): player.velocity = Vector2.ZERO
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: application_focused = true
	if is_instance_valid(steam): _update_modal_feedback()

func _update_modal_feedback() -> void:
	# Focus notifications can arrive while the shared HUD enters or leaves the tree.
	if not is_instance_valid(hud) or not hud.is_node_ready() or not hud.is_inside_tree() or not is_instance_valid(journal_overlay) or not is_instance_valid(dialogue): return
	var blocked := _blocked()
	if is_instance_valid(foundry_view):
		foundry_view.set_paused(not application_focused or changing_area or journal_overlay.visible or dialogue.visible or hud.inventory_overlay.visible)
	if is_instance_valid(coal_view):
		coal_view.set_paused(not application_focused or changing_area or journal_overlay.visible or dialogue.visible or hud.inventory_overlay.visible)
	if is_instance_valid(iron_popup) and iron_popup.is_open() and iron_popup.suspended and not journal_overlay.visible and not hud.inventory_overlay.visible:
		iron_popup.suspended = false
		iron_popup.layer = 20
	steam.speed_scale = 0.0 if blocked else 1.0
	if is_instance_valid(lift_movie): lift_movie.pause_audio(_modal_blocked())
	hud.get_node("Root/StatusPanel").visible = not journal_overlay.visible and not dialogue.visible
	_update_prompt()
	if hud.inventory_overlay.visible:
		target = Vector2.INF
		pending_interaction = ""
	for child in get_children():
		if blocked and child is AudioStreamPlayer:
			# Railway sounds are short accents, not a soundtrack: discard them on
			# pause instead of retaining a paused playback until application exit.
			child.stop()
			child.stream = null
			child.queue_free()

func _exit_tree() -> void:
	# Release the railway's shared procedural sample before script teardown.
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stream_paused = false
			child.stop()
			child.stream = null
	RailAudio.mechanism_stream = null

func get_session_state() -> Dictionary:
	var state := Journey.ensure()
	state.area = area
	state.elapsed = elapsed
	if is_instance_valid(player): state.positions[area] = [player.position.x, player.position.y]
	var shared_hud: Dictionary = hud.get_session_state()
	shared_hud.erase("dialogue") # London owns the serialized conversation and its outcome.
	return {"arrival_version": 7, "area": area, "elapsed": elapsed, "position": [player.position.x, player.position.y], "facing": player.facing, "journal_open": journal_overlay.visible, "journal_page": journal.current_page, "dialogue_kind": dialogue_kind, "dialogue_heading": dialogue_heading.text, "dialogue_text": dialogue_text.text if dialogue.visible else "", "hud": shared_hud, "city_ride": ride.snapshot(), "coach_destination": pending_city_destination, "foundry_open": foundry_view.is_open(), "foundry_state": foundry_view.snapshot(), "coal_open": coal_view.is_open(), "coal_refill": coal_view.model.refill if coal_view.model != null else false, "coal_state": coal_view.snapshot(), "iron_open": iron_popup.is_open(), "iron_refill": iron_popup.refill, "lift_elapsed": lift_elapsed, "lift_returning": lift_returning, "lift_start": [lift_start.x, lift_start.y]}

func restore_session_state(saved: Dictionary) -> void:
	var restored_area := str(saved.get("area", Journey.ensure().area))
	var coordinates: Array = saved.get("position", [])
	var spawn := Vector2(float(coordinates[0]), float(coordinates[1])) if coordinates.size() == 2 else Vector2.ZERO
	_set_area(restored_area, spawn)
	elapsed = clampf(float(saved.get("elapsed", Journey.ensure().elapsed)), 0, ARRIVAL_DURATION)
	if not Journey.ensure().arrived: _apply_arrival()
	player.facing = str(saved.get("facing", "down")) if str(saved.get("facing", "down")) in ["up", "down", "left", "right"] else "down"
	player._set_sprite_frame(1)
	journal.show_page(int(saved.get("journal_page", 2)))
	journal_overlay.visible = bool(saved.get("journal_open", false))
	hud.restore_session_state(saved.get("hud", {}))
	pending_city_destination = str(saved.get("coach_destination", "industrial"))
	if pending_city_destination not in Journey.COACH_STOPS: pending_city_destination = "industrial"
	lift_elapsed = float(saved.get("lift_elapsed", -1.0))
	lift_returning = bool(saved.get("lift_returning", false))
	var boarding: Array = saved.get("lift_start", [])
	lift_start = Vector2(float(boarding[0]), float(boarding[1])) if boarding.size() == 2 else (Vector2(195, MineArt.FLOOR_Y) if lift_returning else MineArt.HOUSE_LANDING + Vector2(-60, 28))
	if lift_elapsed >= 0.0:
		if int(saved.get("arrival_version", 0)) < 5 and not lift_returning:
			_set_area("mine_house", MineArt.HOUSE_EXIT)
			lift_start = MineArt.HOUSE_LANDING + Vector2(-60, 28)
		if int(saved.get("arrival_version", 0)) < 4: lift_elapsed = lift_elapsed * MineLift.DURATION / 7.0
		lift_movie.configure(player, character_height, lift_start, lift_returning)
		lift_movie.pose(lift_elapsed)
		player.hide()
		if is_instance_valid(lift_rig): lift_rig.hide()
	else:
		lift_movie.hide()
	var legacy_coal := bool(saved.get("iron_open", false)) and (iron.stage() == 1 or bool(saved.get("iron_refill", false)))
	if bool(saved.get("foundry_open", false)) and not Campaign.done("forge"):
		_open_foundry(saved.get("foundry_state", {}))
	elif bool(saved.get("coal_open", false)) or legacy_coal:
		if area == "mine_gallery": _set_area("mine_face", Vector2(720, MineArt.FLOOR_Y))
		coal_view.open(iron, bool(saved.get("coal_refill", saved.get("iron_refill", false))), saved.get("coal_state", {}))
	elif bool(saved.get("iron_open", false)) and (iron.stage() != 2 or bool(iron.data.biela_installed)):
		iron_popup.open(iron, bool(saved.get("iron_refill", false)))
		iron_popup.suspended = journal_overlay.visible or hud.inventory_overlay.visible
		iron_popup.layer = -1 if iron_popup.suspended else 20
	ride.restore(saved.get("city_ride", {}))
	var restored_dialogue := str(saved.get("dialogue_kind", ""))
	if restored_dialogue == "inventory":
		_show_inventory()
	elif restored_dialogue not in ["city_intro", "wayfinding", "passenger", "commuter", "porter"] and not str(saved.get("dialogue_text", "")).is_empty():
		_message(str(saved.get("dialogue_kind", "")), str(saved.get("dialogue_heading", "")), str(saved.dialogue_text))
	_refresh()
	_update_modal_feedback()
