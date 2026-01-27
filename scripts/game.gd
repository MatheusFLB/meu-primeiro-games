extends Node2D

signal request_main_menu

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const CAR_SCENE: PackedScene = preload("res://scenes/Car.tscn")

const CAR_TEXTURE_RED: Texture2D = preload("res://assets/car_red.png")
const CAR_TEXTURE_BLUE: Texture2D = preload("res://assets/car_blue.png")
const CAR_TEXTURE_YELLOW: Texture2D = preload("res://assets/car_yellow.png")
const CAR_TEXTURE_VECAO: Texture2D = preload("res://assets/vecao.png")
const VECAO_CHANCE: float = 0.15
const CAR_TEXTURES: Array[Texture2D] = [CAR_TEXTURE_RED, CAR_TEXTURE_BLUE, CAR_TEXTURE_YELLOW]

const CAR_COLOR_PALETTE: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(0.98, 0.28, 0.25, 1.0),
	Color(0.20, 0.55, 0.98, 1.0),
	Color(0.98, 0.86, 0.22, 1.0),
	Color(0.15, 0.86, 0.45, 1.0),
	Color(0.80, 0.35, 0.95, 1.0),
	Color(1.0, 0.55, 0.18, 1.0)
]

enum GameState {
	PLAYING,
	PAUSED,
	GAME_OVER,
	WIN
}

const ARENA_SIZE: Vector2 = Vector2(1080.0, 1920.0)
const START_ZONE_HEIGHT: float = 256.0
const GOAL_ZONE_HEIGHT: float = 256.0
const TILE_SIZE: float = 128.0

const SIDEWALK_HEIGHT: float = 128.0
const SIDEWALK_Y_VALUES: Array[float] = [704.0, 1216.0]

# Extra spacing (in pixels) between consecutive cars in the same lane.
const MIN_CAR_GAP_PX: float = 180.0

@export var goal_zone_texture: Texture2D
@export var road_texture: Texture2D
@export var start_zone_texture: Texture2D
@export var sidewalk_texture: Texture2D

# Nine lanes with a sidewalk after every three lanes.
# Speeds are set here.
var _lane_settings: Array[Dictionary] = [
	{
		"path": NodePath("Lanes/Lane1"),
		"y": 320.0,
		"direction": 1,
		"speed": 420.0,
		"min_interval": 0.80,
		"max_interval": 1.45,
		"spawn_chance": 0.72,
		"size": Vector2(320.0, 96.0)
	},
	{
		"path": NodePath("Lanes/Lane2"),
		"y": 448.0,
		"direction": -1,
		"speed": 520.0,
		"min_interval": 0.70,
		"max_interval": 1.35,
		"spawn_chance": 0.70,
		"size": Vector2(340.0, 96.0)
	},
	{
		"path": NodePath("Lanes/Lane3"),
		"y": 576.0,
		"direction": 1,
		"speed": 460.0,
		"min_interval": 0.78,
		"max_interval": 1.50,
		"spawn_chance": 0.68,
		"size": Vector2(340.0, 96.0)
	},
	{
		"path": NodePath("Lanes/Lane4"),
		"y": 832.0,
		"direction": -1,
		"speed": 500.0,
		"min_interval": 0.72,
		"max_interval": 1.40,
		"spawn_chance": 0.66,
		"size": Vector2(340.0, 96.0)
	},
	{
		"path": NodePath("Lanes/Lane5"),
		"y": 960.0,
		"direction": 1,
		"speed": 560.0,
		"min_interval": 0.68,
		"max_interval": 1.30,
		"spawn_chance": 0.64,
		"size": Vector2(320.0, 96.0)
	},
	{
		"path": NodePath("Lanes/Lane6"),
		"y": 1088.0,
		"direction": -1,
		"speed": 520.0,
		"min_interval": 0.70,
		"max_interval": 1.38,
		"spawn_chance": 0.62,
		"size": Vector2(360.0, 96.0)
	},
	{
		"path": NodePath("Lanes/Lane7"),
		"y": 1344.0,
		"direction": 1,
		"speed": 580.0,
		"min_interval": 0.66,
		"max_interval": 1.26,
		"spawn_chance": 0.60,
		"size": Vector2(340.0, 96.0)
	},
	{
		"path": NodePath("Lanes/Lane8"),
		"y": 1472.0,
		"direction": -1,
		"speed": 540.0,
		"min_interval": 0.68,
		"max_interval": 1.30,
		"spawn_chance": 0.58,
		"size": Vector2(340.0, 96.0)
	},
	{
		"path": NodePath("Lanes/Lane9"),
		"y": 1600.0,
		"direction": 1,
		"speed": 620.0,
		"min_interval": 0.64,
		"max_interval": 1.20,
		"spawn_chance": 0.56,
		"size": Vector2(360.0, 96.0)
	}
]

@onready var _goal_zone_sprite: Sprite2D = $Background/GoalZoneSprite
@onready var _road_sprite: Sprite2D = $Background/RoadSprite
@onready var _start_zone_sprite: Sprite2D = $Background/StartZoneSprite
@onready var _sidewalk1_sprite: Sprite2D = $Background/Sidewalk1Sprite
@onready var _sidewalk2_sprite: Sprite2D = $Background/Sidewalk2Sprite
@onready var _goal_zone_visual: Polygon2D = $Background/GoalZoneVisual
@onready var _road_visual: Polygon2D = $Background/RoadVisual
@onready var _start_zone_visual: Polygon2D = $Background/StartZoneVisual

@onready var _cars: Node2D = $Cars
@onready var _goal_zone: Area2D = $GoalZone
@onready var _sidewalk1_area: Area2D = $Sidewalk1
@onready var _sidewalk2_area: Area2D = $Sidewalk2
@onready var _goal_shape: CollisionShape2D = $GoalZone/CollisionShape2D
@onready var _sidewalk1_shape: CollisionShape2D = $Sidewalk1/CollisionShape2D
@onready var _sidewalk2_shape: CollisionShape2D = $Sidewalk2/CollisionShape2D
@onready var _player_spawn: Marker2D = $PlayerSpawn
@onready var _ui: GameUI = $UI as GameUI

# Each entry holds a timer and its lane setting.
var _lane_spawners: Array[Dictionary] = []
var _state: GameState = GameState.PLAYING
var _score: int = 0
var _player: Player = null

func _ready() -> void:
	randomize()
	_state = GameState.PLAYING
	_score = 0

	_apply_background_visuals()
	_connect_goal_zone()
	_connect_safe_zones()
	_setup_lanes()
	_connect_ui()
	_spawn_player()

	_ui.hide_overlay()
	_ui.hide_pause_overlay()

	_start_spawners()

func reset_game() -> void:
	get_tree().paused = false
	_state = GameState.PLAYING
	_score = 0

	_clear_cars()
	_spawn_player()

	_ui.hide_overlay()
	_ui.hide_pause_overlay()

	_start_spawners()

func _apply_background_visuals() -> void:
	_goal_zone_visual.visible = false
	_road_visual.visible = false
	_start_zone_visual.visible = false

	var road_height: float = ARENA_SIZE.y - START_ZONE_HEIGHT - GOAL_ZONE_HEIGHT
	var goal_size: Vector2 = Vector2(ARENA_SIZE.x, GOAL_ZONE_HEIGHT)
	var road_size: Vector2 = Vector2(ARENA_SIZE.x, road_height)
	var start_size: Vector2 = Vector2(ARENA_SIZE.x, START_ZONE_HEIGHT)
	var sidewalk_size: Vector2 = Vector2(ARENA_SIZE.x, SIDEWALK_HEIGHT)

	_goal_zone_sprite.position = Vector2(ARENA_SIZE.x * 0.5, GOAL_ZONE_HEIGHT * 0.5)
	_road_sprite.position = Vector2(ARENA_SIZE.x * 0.5, GOAL_ZONE_HEIGHT + road_height * 0.5)
	_start_zone_sprite.position = Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y - START_ZONE_HEIGHT * 0.5)

	# Keep collision areas in sync with the visual sizes.
	_goal_zone.position = _goal_zone_sprite.position
	_set_rect_shape(_goal_shape, goal_size)

	_sidewalk1_area.position = Vector2(ARENA_SIZE.x * 0.5, SIDEWALK_Y_VALUES[0])
	_sidewalk2_area.position = Vector2(ARENA_SIZE.x * 0.5, SIDEWALK_Y_VALUES[1])
	_set_rect_shape(_sidewalk1_shape, sidewalk_size)
	_set_rect_shape(_sidewalk2_shape, sidewalk_size)

	var goal_tex: Texture2D = goal_zone_texture
	if goal_tex == null:
		goal_tex = _generate_grass_texture(
			Vector2i(int(goal_size.x), int(goal_size.y)),
			Color(0.18, 0.60, 0.22, 1.0),
			Color(0.22, 0.72, 0.28, 1.0)
		)
	_fit_sprite(_goal_zone_sprite, goal_tex, goal_size)

	var road_tex: Texture2D = road_texture
	if road_tex == null:
		road_tex = _generate_road_texture(
			Vector2i(int(road_size.x), int(road_size.y)),
			Color(0.14, 0.14, 0.16, 1.0),
			Color(0.95, 0.95, 0.95, 0.22)
		)
	_fit_sprite(_road_sprite, road_tex, road_size)

	var start_tex: Texture2D = start_zone_texture
	if start_tex == null:
		start_tex = _generate_grass_texture(
			Vector2i(int(start_size.x), int(start_size.y)),
			Color(0.16, 0.50, 0.20, 1.0),
			Color(0.20, 0.62, 0.26, 1.0)
		)
	_fit_sprite(_start_zone_sprite, start_tex, start_size)

	var sidewalk_tex: Texture2D = sidewalk_texture
	if sidewalk_tex == null:
		sidewalk_tex = _generate_sidewalk_texture(Vector2i(512, 128))

	_sidewalk1_sprite.position = Vector2(ARENA_SIZE.x * 0.5, SIDEWALK_Y_VALUES[0])
	_sidewalk2_sprite.position = Vector2(ARENA_SIZE.x * 0.5, SIDEWALK_Y_VALUES[1])
	_fit_sprite(_sidewalk1_sprite, sidewalk_tex, sidewalk_size)
	_fit_sprite(_sidewalk2_sprite, sidewalk_tex, sidewalk_size)

func _fit_sprite(sprite: Sprite2D, texture: Texture2D, target_size: Vector2) -> void:
	sprite.texture = texture
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		sprite.scale = Vector2.ONE
		return
	sprite.scale = target_size / tex_size
func _set_rect_shape(shape_node: CollisionShape2D, size: Vector2) -> void:
	if shape_node == null:
		return
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_node.shape = rect
	rect.size = size

func _generate_grass_texture(size: Vector2i, base_color: Color, patch_color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(base_color)

	var step: int = 48
	var patch: int = 20
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var toggle: bool = int((x / step) + (y / step)) % 2 == 0
			if toggle:
				image.fill_rect(Rect2i(x, y, patch, patch), patch_color)

	return ImageTexture.create_from_image(image)

func _generate_road_texture(size: Vector2i, base_color: Color, line_color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(base_color)

	var lane_centers: Array[int] = []
	for setting: Dictionary in _lane_settings:
		var lane_y: float = float(setting.get("y", 960.0))
		lane_centers.append(int(lane_y - GOAL_ZONE_HEIGHT))

	var dash_width: int = 140
	var dash_gap: int = 90
	var line_height: int = 12
	var half_line: int = int(line_height * 0.5)

	for center_y in lane_centers:
		var clamped_y: int = clamp(center_y, half_line, size.y - half_line)
		for x in range(0, size.x, dash_width + dash_gap):
			image.fill_rect(Rect2i(x, clamped_y - half_line, dash_width, line_height), line_color)

	return ImageTexture.create_from_image(image)

func _generate_sidewalk_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.60, 0.60, 0.60, 1.0))

	var stripe_a: Color = Color(0.68, 0.68, 0.68, 1.0)
	var stripe_b: Color = Color(0.52, 0.52, 0.52, 1.0)
	for y in range(8, size.y - 8, 48):
		for x in range(8, size.x - 8, 64):
			var tile_color: Color = stripe_a if int((x / 64) + (y / 48)) % 2 == 0 else stripe_b
			image.fill_rect(Rect2i(x, y, 56, 40), tile_color)

	image.fill_rect(Rect2i(0, 0, size.x, 10), Color(0.42, 0.42, 0.42, 1.0))
	image.fill_rect(Rect2i(0, size.y - 10, size.x, 10), Color(0.42, 0.42, 0.42, 1.0))

	return ImageTexture.create_from_image(image)

func _connect_goal_zone() -> void:
	_goal_zone.collision_layer = 4
	_goal_zone.collision_mask = 1
	_goal_zone.monitoring = true
	_goal_zone.monitorable = true
	if not _goal_zone.body_entered.is_connected(_on_goal_zone_body_entered):
		_goal_zone.body_entered.connect(_on_goal_zone_body_entered)

func _connect_safe_zones() -> void:
	var safe_areas: Array[Area2D] = [_sidewalk1_area, _sidewalk2_area]
	for area in safe_areas:
		if area == null:
			continue
		area.collision_layer = 8
		area.collision_mask = 1
		area.monitoring = true
		area.monitorable = true
		if not area.body_entered.is_connected(_on_safe_zone_body_entered):
			area.body_entered.connect(_on_safe_zone_body_entered)
		if not area.body_exited.is_connected(_on_safe_zone_body_exited):
			area.body_exited.connect(_on_safe_zone_body_exited)

func _setup_lanes() -> void:
	_lane_spawners.clear()
	for setting: Dictionary in _lane_settings:
		var lane_path: NodePath = setting["path"] as NodePath
		var lane_node: Node2D = get_node(lane_path) as Node2D
		if lane_node == null:
			push_warning("Lane node not found: %s" % [lane_path])
			continue

		lane_node.position = Vector2(0.0, float(setting.get("y", lane_node.position.y)))

		var timer: Timer = lane_node.get_node("SpawnTimer") as Timer
		if timer == null:
			push_warning("SpawnTimer missing under: %s" % [lane_path])
			continue

		timer.one_shot = true
		timer.stop()

		var setting_copy: Dictionary = setting.duplicate(true)
		timer.timeout.connect(_on_lane_timeout.bind(lane_node, setting_copy, timer))

		_lane_spawners.append({
			"timer": timer,
			"setting": setting_copy
		})

func _connect_ui() -> void:
	if not _ui.restart_pressed.is_connected(_on_ui_restart_pressed):
		_ui.restart_pressed.connect(_on_ui_restart_pressed)
	if not _ui.pause_pressed.is_connected(_on_ui_pause_pressed):
		_ui.pause_pressed.connect(_on_ui_pause_pressed)
	if not _ui.resume_pressed.is_connected(_on_ui_resume_pressed):
		_ui.resume_pressed.connect(_on_ui_resume_pressed)
	if not _ui.menu_pressed.is_connected(_on_ui_menu_pressed):
		_ui.menu_pressed.connect(_on_ui_menu_pressed)
	if not _ui.move_pressed.is_connected(_on_ui_move_pressed):
		_ui.move_pressed.connect(_on_ui_move_pressed)

func _spawn_player() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()

	_goal_zone.monitoring = false

	var player: Player = PLAYER_SCENE.instantiate() as Player
	if player == null:
		push_error("Failed to instantiate Player scene.")
		_goal_zone.monitoring = true
		return

	player.tile_size = TILE_SIZE
	var arena_rect: Rect2 = Rect2(Vector2.ZERO, ARENA_SIZE)
	var goal_threshold: float = GOAL_ZONE_HEIGHT - TILE_SIZE * 0.5
	var spawn_position: Vector2 = _player_spawn.global_position
	player.setup(arena_rect, spawn_position, goal_threshold)
	player.global_position = spawn_position

	add_child(player)
	_player = player

	_goal_zone.monitoring = true

	player.died.connect(_on_player_died)
	player.reached_goal.connect(_on_player_reached_goal)
	player.advanced_row.connect(_on_player_advanced_row)

func _start_spawners() -> void:
	for spawner: Dictionary in _lane_spawners:
		var timer: Timer = spawner["timer"] as Timer
		var setting: Dictionary = spawner["setting"] as Dictionary
		_schedule_next_spawn(timer, setting)

func _stop_spawners() -> void:
	for spawner: Dictionary in _lane_spawners:
		var timer: Timer = spawner["timer"] as Timer
		if timer:
			timer.stop()

func _schedule_next_spawn(timer: Timer, setting: Dictionary) -> void:
	if _state != GameState.PLAYING:
		return
	if timer == null:
		return

	var min_interval: float = float(setting.get("min_interval", 0.9))
	var max_interval: float = float(setting.get("max_interval", min_interval + 0.7))

	# Enforce a physical minimum spacing based on car width and speed.
	var car_size: Vector2 = setting.get("size", Vector2(300.0, 96.0)) as Vector2
	var speed: float = float(setting.get("speed", 420.0))
	var dynamic_min: float = (car_size.x + MIN_CAR_GAP_PX) / maxf(speed, 1.0)
	min_interval = maxf(min_interval, dynamic_min)

	if max_interval < min_interval:
		max_interval = min_interval + 0.30

	timer.stop()
	timer.wait_time = randf_range(min_interval, max_interval)
	timer.start()

func _clear_cars() -> void:
	for child in _cars.get_children():
		child.queue_free()

func _on_lane_timeout(lane_node: Node2D, setting: Dictionary, timer: Timer) -> void:
	if _state != GameState.PLAYING:
		return

	var spawn_chance: float = float(setting.get("spawn_chance", 0.65))
	if randf() <= spawn_chance:
		_spawn_car(lane_node.global_position.y, setting)

	_schedule_next_spawn(timer, setting)

func _spawn_car(lane_y: float, setting: Dictionary) -> void:
	var car: Car = CAR_SCENE.instantiate() as Car
	if car == null:
		push_error("Failed to instantiate Car scene.")
		return

	car.speed = float(setting["speed"])
	car.direction = int(setting["direction"])
	car.car_size = setting["size"] as Vector2
	car.arena_width = ARENA_SIZE.x

	var chosen_texture: Texture2D = _random_car_texture()
	car.sprite_texture = chosen_texture
	if chosen_texture == CAR_TEXTURE_VECAO:
		car.car_color = Color(1.0, 1.0, 1.0, 1.0)
	else:
		car.car_color = _random_car_color()

	var spawn_x: float = _get_spawn_x(car.direction, car.car_size.x)
	car.global_position = Vector2(spawn_x, lane_y)
	_cars.add_child(car)

func _random_car_texture() -> Texture2D:
	if randf() <= VECAO_CHANCE:
		return CAR_TEXTURE_VECAO
	return CAR_TEXTURES[randi() % CAR_TEXTURES.size()]

func _random_car_color() -> Color:
	return CAR_COLOR_PALETTE[randi() % CAR_COLOR_PALETTE.size()]

func _get_spawn_x(direction: int, car_width: float) -> float:
	var margin: float = maxf(180.0, car_width)
	if direction >= 0:
		return -margin
	return ARENA_SIZE.x + margin

func _on_safe_zone_body_entered(body: Node) -> void:
	if _player == null or body != _player:
		return
	if _player.has_method("enter_safe_zone"):
		_player.enter_safe_zone()

func _on_safe_zone_body_exited(body: Node) -> void:
	if _player == null or body != _player:
		return
	if _player.has_method("exit_safe_zone"):
		_player.exit_safe_zone()

func _on_ui_move_pressed(direction: Vector2i) -> void:
	if _state != GameState.PLAYING:
		return
	if _player and is_instance_valid(_player):
		_player.request_move(direction)

func _on_ui_pause_pressed() -> void:
	if _state != GameState.PLAYING:
		return
	_state = GameState.PAUSED
	_ui.show_pause_overlay()
	get_tree().paused = true

func _on_ui_resume_pressed() -> void:
	if _state != GameState.PAUSED:
		return
	get_tree().paused = false
	_state = GameState.PLAYING
	_ui.hide_pause_overlay()

func _on_ui_menu_pressed() -> void:
	get_tree().paused = false
	_ui.hide_pause_overlay()
	request_main_menu.emit()

func _on_ui_restart_pressed() -> void:
	get_tree().paused = false
	reset_game()

func _on_goal_zone_body_entered(body: Node) -> void:
	if _state != GameState.PLAYING:
		return
	if body == _player:
		_on_player_reached_goal()

func _on_player_died() -> void:
	if _state != GameState.PLAYING:
		return
	_state = GameState.GAME_OVER
	_stop_spawners()
	_ui.hide_pause_overlay()
	_ui.show_overlay("SECO SECO SECO!", "Reiniciar")

func _on_player_reached_goal() -> void:
	if _state != GameState.PLAYING:
		return
	_state = GameState.WIN
	_stop_spawners()
	_ui.hide_pause_overlay()
	_ui.show_overlay("LISO LISO LISO!", "Jogar novamente")

func _on_player_advanced_row(points: int) -> void:
	if _state != GameState.PLAYING:
		return
	_score += points
