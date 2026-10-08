extends Control
## London exploration, railway arrival and a resumable horse-coach journey.
const Journey := preload("res://scripts/world/london_journey.gd")
const Campaign := preload("res://scripts/core/phase2_campaign.gd")
const Journal := preload("res://scripts/ui/chapter_journal.gd")
const RailAudio := preload("res://scripts/world/railway_audio.gd")
const BodyBounds := preload("res://scripts/world/sprite_body_bounds.gd")
const CoachRide := preload("res://scripts/world/london_coach_ride.gd")
const COACHMAN := preload("res://assets/gba/ramon_coachman_v1.png")
const SIZE := Vector2(1152, 648)
const ARRIVAL_DURATION := 9.5
const BACKGROUNDS := {
	"platform": preload("res://assets/phase2/london_platform_pixel_v1.png"),
	"hall": preload("res://assets/phase2/london_ticket_hall_pixel_v1.png"),
	"street": preload("res://assets/phase2/london_street_pixel_v1.png"),
	"coach_depot": preload("res://assets/phase2/london_coach_depot_v1.png"),
	"industrial": preload("res://assets/phase2/london_industrial_depot_v1.png")
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
	"coachman": ["William, cochero", "Los talleres están al otro lado del canal. Mi coche te llevará hasta la parada del distrito industrial por 10 monedas; el regreso está incluido. Verás cómo las tiendas dejan paso a almacenes, carbón y chimeneas."]
}

var content: Control
var world: Node2D
var backdrop: TextureRect
var player: CharacterBody2D
var scenery: Node2D
var train: Node2D
var ride: CoachRide
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var state := Journey.ensure()
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
			walk_bounds = Rect2(28, 410, 1096, 208)
			_park_coach(Vector2(470, 515), true)
			_actor("coachman", COACHMAN, Vector2(350, 560))
	# Physical perimeter and NPC footprints prevent walking on tracks or walls.
	_block(Rect2(-50, walk_bounds.position.y - 100, 1252, 100))
	_block(Rect2(-50, walk_bounds.end.y + 10, 1252, 100))
	_block(Rect2(-60, 0, 70, 648))
	_block(Rect2(1142, 0, 70, 648))
	var saved_positions: Dictionary = state.positions
	var previous: Array = saved_positions.get(area, [])
	if spawn != Vector2.ZERO: player.position = spawn
	elif previous.size() == 2: player.position = Vector2(float(previous[0]), float(previous[1]))
	else: player.position = {"platform": Vector2(548, 460), "hall": Vector2(110, 468), "street": Vector2(252, 447), "coach_depot": Vector2(576, 465), "industrial": Vector2(350, 580)}[area]
	player.position = player.position.clamp(walk_bounds.position, walk_bounds.end)
	player.velocity = Vector2.ZERO
	player.facing = "down"
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
	var scale_factor := character_height / maxf(1.0, visible_rect.size.y)
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(0, -character_height * 0.5)
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
		else: direction = player.position.direction_to(target) * minf(1.0, distance / maxf(1, player.speed * delta))
	player.velocity = direction * player.speed
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
	return false

func _blocked() -> bool:
	return _modal_blocked() or (is_instance_valid(ride) and ride.active)

func _modal_blocked() -> bool:
	if not is_instance_valid(journal_overlay) or not is_instance_valid(dialogue): return true
	return not application_focused or changing_area or journal_overlay.visible or dialogue.visible or (is_instance_valid(hud) and hud.inventory_overlay.visible)

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
		"coachman": _offer_city_coach()
		_:
			if DIALOGUES.has(id): _message(id, DIALOGUES[id][0], DIALOGUES[id][1])

func _offer_city_coach() -> void:
	if area == "industrial":
		_message("coach_trip", "William, cochero", "Tu pasaje incluye el regreso a la parada junto a la estación de Londres. ¿Volvemos? No pagarás más monedas.")
	elif GameState.coins < Journey.COACH_FARE:
		_message("coach_unaffordable", "William, cochero", "El viaje al distrito industrial cuesta 10 monedas. Ahora tienes %d. Puedes seguir explorando y volver cuando tengas el importe; no te cobraré nada todavía." % GameState.coins)
	else:
		_message("coach_trip", DIALOGUES.coachman[0], DIALOGUES.coachman[1])

func _book_city_coach() -> bool:
	if ride.active or area not in ["coach_depot", "industrial"]: return false
	var returning := area == "industrial"
	if not returning and GameState.coins < Journey.COACH_FARE:
		_offer_city_coach()
		return false
	if not returning:
		GameState.coins -= Journey.COACH_FARE
		var transport: Dictionary = GameState.phase_two.city_transport
		transport.outbound_trips = int(transport.outbound_trips) + 1
		transport.fares_paid = int(transport.fares_paid) + Journey.COACH_FARE
		EventBus.coins_changed.emit(GameState.coins)
		GameState.record_event("Pagó 10 monedas por el coche al distrito industrial de Londres, con regreso incluido.")
	ride.begin(returning, player.position)
	target = Vector2.INF
	pending_interaction = ""
	_update_modal_feedback()
	GameState.save_progress()
	return true

func _finish_city_ride() -> void:
	var returning := ride.returning
	_set_area("coach_depot" if returning else "industrial", Vector2(650, 590) if returning else Vector2(350, 590))
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
		options = [{"label": "Regresar · Incluido" if area == "industrial" else "Viajar · 10 monedas", "action": "continue_london"}, {"label": "Todavía no", "action": "cancel_london"}]
	hud._show_dialogue({"speaker": title, "text": text, "options": options})
	target = Vector2.INF
	pending_interaction = ""
	player.controls_enabled = false
	(hud.dialogue_options.get_child(0) as Button).grab_focus()
	_update_modal_feedback()
	GameState.save_progress()

func _close_dialogue() -> void:
	var kind := dialogue_kind
	dialogue.hide()
	dialogue_kind = ""
	if kind == "coach_trip":
		_book_city_coach()
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
	dialogue.hide()
	dialogue_kind = ""
	_update_modal_feedback()
	GameState.save_progress()

func _refresh() -> void:
	journal.refresh(GameState.build_report())

func _show_journal() -> void:
	if dialogue.visible or changing_area or hud.inventory_overlay.visible: return
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
	_update_modal_feedback()
	GameState.save_progress()

func _show_inventory() -> void:
	if not hud.inventory_overlay.visible and _modal_blocked(): return
	target = Vector2.INF
	pending_interaction = ""
	hud._toggle_inventory()
	_update_modal_feedback()
	GameState.save_progress()

func _request_restart() -> void:
	journal_overlay.hide()
	_message("restart", "Reiniciar fase 2", "Volverás a la historia y a la llegada del tren a Londres. Conservarás la Fase 1 completada, la dificultad y los trabajos guardados de los talleres. ¿Quieres reiniciar este recorrido?")

func _return_home() -> void:
	GameState.save_progress()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if not is_instance_valid(journal_overlay): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB and (journal_overlay.visible or dialogue.visible or hud.inventory_overlay.visible):
			_cycle_focus(event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif journal_overlay.visible and event.keycode in [KEY_LEFT, KEY_RIGHT]:
			journal.turn_to(1 if event.keycode == KEY_LEFT else 2)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if hud.inventory_overlay.visible: hud._close_inventory()
			elif dialogue.visible: _cancel_dialogue()
			elif journal_overlay.visible: _hide_journal()
			else: _show_journal()
			get_viewport().set_input_as_handled()

func _cycle_focus(reverse: bool) -> void:
	var buttons: Array[Button] = []
	var modal: Node = hud.inventory_overlay if hud.inventory_overlay.visible else (dialogue if dialogue.visible else journal)
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
	pending_interaction = ""
	for id in points:
		if str(id).ends_with("_exit"): continue
		if pos.distance_to(points[id] - Vector2(0, 30)) < 45 or (interaction_zones.has(id) and interaction_zones[id].has_point(pos)):
			pending_interaction = id
			var point: Vector2 = points[id]
			target = (point + Vector2(-45 if point.x > player.position.x else 45, 18)).clamp(walk_bounds.position, walk_bounds.end)
			return
	target = pos.clamp(walk_bounds.position, walk_bounds.end)

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
	steam.speed_scale = 0.0 if blocked else 1.0
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
	return {"arrival_version": 2, "area": area, "elapsed": elapsed, "position": [player.position.x, player.position.y], "facing": player.facing, "journal_open": journal_overlay.visible, "journal_page": journal.current_page, "dialogue_kind": dialogue_kind, "dialogue_heading": dialogue_heading.text, "dialogue_text": dialogue_text.text if dialogue.visible else "", "hud": shared_hud, "city_ride": ride.snapshot()}

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
	ride.restore(saved.get("city_ride", {}))
	var restored_dialogue := str(saved.get("dialogue_kind", ""))
	if restored_dialogue == "inventory":
		_show_inventory()
	elif restored_dialogue not in ["city_intro", "wayfinding", "passenger", "commuter", "porter"] and not str(saved.get("dialogue_text", "")).is_empty():
		_message(str(saved.get("dialogue_kind", "")), str(saved.get("dialogue_heading", "")), str(saved.dialogue_text))
	_refresh()
	_update_modal_feedback()
