extends Node2D

signal request_main_menu

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const CAR_SCENE: PackedScene = preload("res://scenes/Car.tscn")
const CHAPEL_SCENE: PackedScene = preload("res://scenes/Chapel.tscn")

const CAR_TEXTURE_RED: Texture2D = preload("res://assets/car_red.png")
const CAR_TEXTURE_BLUE: Texture2D = preload("res://assets/car_blue.png")
const CAR_TEXTURE_YELLOW: Texture2D = preload("res://assets/car_yellow.png")
const CAR_TEXTURE_VECAO: Texture2D = preload("res://assets/vecao.png")
const CHAPEL_TEXTURE_PATH: String = "res://assets/chapel.png"
const VECAO_RAIL_MULTIPLIER: float = 0.35
const VECAO_RAIL_SPEED_MULTIPLIER: float = 2.6
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
const TOP_LANES: int = 4
const MID_LANES: int = 2
const BOTTOM_LANES: int = 4

# Extra spacing (in pixels) between consecutive cars in the same lane.
const MIN_CAR_GAP_PX: float = 180.0
const CHAPEL_SPAWN_MIN: float = 1.4
const CHAPEL_SPAWN_MAX: float = 2.6

const SFX_CHAPEL_BOM: AudioStream = preload("res://assets/barulho/vaitomano.mp3")
const SFX_CHAPEL_RUIM: AudioStream = preload("res://assets/barulho/chapel.mp3")
const SFX_GANHAR: AudioStream = preload("res://assets/barulho/lisolisoliso.mp3")
const SFX_COLISAO: Array[AudioStream] = [
	preload("res://assets/barulho/secosecoseco.mp3"),
	preload("res://assets/barulho/caraifi.mp3"),
	preload("res://assets/barulho/gap.mp3")
]

@export var goal_zone_texture: Texture2D
@export var road_texture: Texture2D
@export var rail_texture: Texture2D
@export var start_zone_texture: Texture2D
@export var sidewalk_texture: Texture2D

@export var difficulty_multiplier: float = 1.0
@export var chapel_bad_chance: float = 0.25
@export var vecao_chance_base: float = 0.15
@export var row_score_enabled: bool = false

# Lane settings are generated dynamically based on layout.
var _lane_settings: Array[Dictionary] = []

@onready var _goal_zone_sprite: Sprite2D = $Background/GoalZoneSprite
@onready var _road_sprite: Sprite2D = $Background/RoadSprite
@onready var _rail_sprite: Sprite2D = $Background/RailSprite
@onready var _start_zone_sprite: Sprite2D = $Background/StartZoneSprite
@onready var _sidewalk1_sprite: Sprite2D = $Background/Sidewalk1Sprite
@onready var _sidewalk2_sprite: Sprite2D = $Background/Sidewalk2Sprite
@onready var _goal_zone_visual: Polygon2D = $Background/GoalZoneVisual
@onready var _road_visual: Polygon2D = $Background/RoadVisual
@onready var _rail_visual: Polygon2D = $Background/RailVisual
@onready var _start_zone_visual: Polygon2D = $Background/StartZoneVisual

@onready var _cars: Node2D = $Cars
@onready var _collectibles: Node2D = $Collectibles
@onready var _chapel_timer: Timer = $ChapelTimer
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
var _state: GameState = GameState.PLAYING as GameState
var _score: int = 0
var _player: Player = null
var _sidewalk_positions: Array[float] = []
var _lane_positions: Array[float] = []
var _rail_lane_positions: Array[float] = []
var _row_centers: Array[float] = []
var _lane_height: float = TILE_SIZE
var _chapel_texture: Texture2D = null
var _sfx_player: AudioStreamPlayer
var _empty_floats: Array[float] = []
var _metro_texture: Texture2D = null
var _music_player: AudioStreamPlayer

func _ready() -> void:
	randomize()
	_state = GameState.PLAYING as GameState
	_score = 0
	_chapel_texture = _load_chapel_texture()
	_metro_texture = _generate_metro_texture(Vector2i(512, 128))
	_setup_audio()
	_setup_music()

	_apply_background_visuals()
	_connect_goal_zone()
	_connect_safe_zones()
	_build_lane_settings()
	_setup_lanes()
	_connect_ui()
	_spawn_player()

	_ui.set_score(_score)
	_ui.set_vga_enabled(false)
	_ui.hide_overlay()
	_ui.hide_pause_overlay()

	_start_spawners()
	_start_chapel_timer()

func reset_game() -> void:
	get_tree().paused = false
	_state = GameState.PLAYING as GameState
	_score = 0

	_clear_cars()
	_clear_collectibles()
	_spawn_player()

	_ui.set_score(_score)
	_ui.set_vga_enabled(false)
	_ui.hide_overlay()
	_ui.hide_pause_overlay()

	_start_spawners()
	_start_chapel_timer()

func _apply_background_visuals() -> void:
	_goal_zone_visual.visible = false
	_road_visual.visible = false
	_start_zone_visual.visible = false
	_rail_visual.visible = false

	var layout := _build_layout()
	_sidewalk_positions = _to_float_array(layout.get("sidewalks", _empty_floats))
	_lane_positions = _to_float_array(layout.get("lanes", _empty_floats))
	_rail_lane_positions = _to_float_array(layout.get("rail_lanes", _empty_floats))
	_row_centers = _build_row_centers(layout)
	_lane_height = float(layout.get("lane_height", TILE_SIZE))

	var goal_size: Vector2 = Vector2(ARENA_SIZE.x, GOAL_ZONE_HEIGHT)
	var road_size: Vector2 = Vector2(ARENA_SIZE.x, float(layout["road_height"]))
	var start_height: float = float(layout.get("start_height", START_ZONE_HEIGHT))
	var start_size: Vector2 = Vector2(ARENA_SIZE.x, start_height)
	var sidewalk_size: Vector2 = Vector2(ARENA_SIZE.x, SIDEWALK_HEIGHT)
	var safe_zone_height: float = minf(SIDEWALK_HEIGHT, _lane_height * 0.9)
	var safe_zone_size: Vector2 = Vector2(ARENA_SIZE.x, safe_zone_height)
	var rail_size: Vector2 = Vector2(ARENA_SIZE.x, float(layout["rail_height"]))
	var rail_center_y: float = float(layout["rail_top"]) + rail_size.y * 0.5
	var start_center_y: float = float(layout["start_center"])

	_goal_zone_sprite.position = Vector2(ARENA_SIZE.x * 0.5, GOAL_ZONE_HEIGHT * 0.5)
	_road_sprite.position = Vector2(ARENA_SIZE.x * 0.5, GOAL_ZONE_HEIGHT + road_size.y * 0.5)
	_start_zone_sprite.position = Vector2(ARENA_SIZE.x * 0.5, start_center_y)
	_rail_sprite.position = Vector2(ARENA_SIZE.x * 0.5, rail_center_y)
	if _row_centers.size() > 0:
		_player_spawn.position = Vector2(ARENA_SIZE.x * 0.5, _row_centers[_row_centers.size() - 1])
	else:
		_player_spawn.position = Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y - _lane_height * 0.5)

	# Keep collision areas in sync with the visual sizes.
	_goal_zone.position = _goal_zone_sprite.position
	_set_rect_shape(_goal_shape, goal_size)

	_sidewalk1_area.position = Vector2(ARENA_SIZE.x * 0.5, _sidewalk_positions[0])
	_sidewalk2_area.position = Vector2(ARENA_SIZE.x * 0.5, _sidewalk_positions[1])
	_set_rect_shape(_sidewalk1_shape, safe_zone_size)
	_set_rect_shape(_sidewalk2_shape, safe_zone_size)

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
			Color(0.14, 0.14, 0.16, 1.0)
		)
	_fit_sprite(_road_sprite, road_tex, road_size)
	_generate_lane_markings()

	var rail_tex: Texture2D = rail_texture
	if rail_tex == null:
		rail_tex = _generate_rail_texture(
			Vector2i(int(rail_size.x), int(rail_size.y)),
			Color(0.08, 0.08, 0.12, 1.0),
			Color(0.55, 0.55, 0.6, 1.0),
			_rail_lane_positions,
			float(layout.get("rail_top", 0.0)),
			_lane_height
		)
	_fit_sprite(_rail_sprite, rail_tex, rail_size)

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

	_sidewalk1_sprite.position = Vector2(ARENA_SIZE.x * 0.5, _sidewalk_positions[0])
	_sidewalk2_sprite.position = Vector2(ARENA_SIZE.x * 0.5, _sidewalk_positions[1])
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
			var toggle: bool = int((float(x) / float(step)) + (float(y) / float(step))) % 2 == 0
			if toggle:
				image.fill_rect(Rect2i(x, y, patch, patch), patch_color)

	return ImageTexture.create_from_image(image)

func _generate_road_texture(size: Vector2i, base_color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(base_color)

	return ImageTexture.create_from_image(image)

func _generate_lane_markings() -> void:
	if _lane_positions.is_empty():
		return

	var layout := _build_layout()
	var road_height: float = float(layout.get("road_height", ARENA_SIZE.y - START_ZONE_HEIGHT - GOAL_ZONE_HEIGHT))
	var white_positions: Array[int] = []
	var yellow_positions: Array[int] = []

	var top_dirs: Array[int] = [1, 1, -1, -1]
	for i in range(TOP_LANES - 1):
		var border_y_top: int = int((_lane_positions[i] + _lane_positions[i + 1]) * 0.5 - GOAL_ZONE_HEIGHT)
		if top_dirs[i] == top_dirs[i + 1]:
			white_positions.append(border_y_top)
		else:
			yellow_positions.append(border_y_top)

	var bottom_dirs: Array[int] = [1, 1, -1, -1]
	var bottom_offset: int = TOP_LANES + MID_LANES
	for i in range(BOTTOM_LANES - 1):
		var idx: int = bottom_offset + i
		var border_y_bottom: int = int((_lane_positions[idx] + _lane_positions[idx + 1]) * 0.5 - GOAL_ZONE_HEIGHT)
		if bottom_dirs[i] == bottom_dirs[i + 1]:
			white_positions.append(border_y_bottom)
		else:
			yellow_positions.append(border_y_bottom)

	var white_mark := _generate_marking_texture(Vector2i(int(ARENA_SIZE.x), int(road_height)), true, white_positions)
	var yellow_mark := _generate_marking_texture(Vector2i(int(ARENA_SIZE.x), int(road_height)), false, yellow_positions)

	var white_sprite := _get_or_create_sprite("WhiteMarkings")
	var yellow_sprite := _get_or_create_sprite("YellowMarkings")
	_fit_sprite(white_sprite, white_mark, Vector2(ARENA_SIZE.x, road_height))
	_fit_sprite(yellow_sprite, yellow_mark, Vector2(ARENA_SIZE.x, road_height))
	white_sprite.position = Vector2(ARENA_SIZE.x * 0.5, GOAL_ZONE_HEIGHT + road_height * 0.5)
	yellow_sprite.position = Vector2(ARENA_SIZE.x * 0.5, GOAL_ZONE_HEIGHT + road_height * 0.5)

func _generate_marking_texture(size: Vector2i, dashed: bool, positions: Array[int]) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var dash_width: int = 90
	var dash_gap: int = 70
	var line_height: int = 4
	var half_line: int = int(line_height * 0.5)
	for border_y in positions:
		if border_y <= line_height or border_y >= size.y - line_height:
			continue

		if dashed:
			for x in range(0, size.x, dash_width + dash_gap):
				image.fill_rect(Rect2i(x, border_y - half_line, dash_width, line_height), Color(1.0, 1.0, 1.0, 1.0))
		else:
			var gap_between: int = 6
			var offset: int = int((line_height + gap_between) * 0.5)
			image.fill_rect(Rect2i(0, border_y - offset - half_line, size.x, line_height), Color(1.0, 0.86, 0.1, 1.0))
			image.fill_rect(Rect2i(0, border_y + offset - half_line, size.x, line_height), Color(1.0, 0.86, 0.1, 1.0))

	return ImageTexture.create_from_image(image)

func _get_or_create_sprite(node_name: String) -> Sprite2D:
	var sprite := $Background.get_node_or_null(node_name) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = node_name
		$Background.add_child(sprite)
	return sprite

func _generate_rail_texture(
	size: Vector2i,
	base_color: Color,
	rail_color: Color,
	rail_lanes: Array[float],
	rail_top: float,
	lane_height: float
) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(base_color)

	var wood_color: Color = Color(0.28, 0.20, 0.12, 1.0)
	var wood_dark: Color = Color(0.22, 0.16, 0.10, 1.0)
	var tie_width: int = 16
	var rail_thickness: float = 6.0
	var rail_offset: float = lane_height * 0.20

	# Draw sleepers (wood) first so rails stay on top.
	for lane_y in rail_lanes:
		var local_center: float = lane_y - rail_top
		var tie_height: int = int(lane_height * 0.70)
		var tie_top: int = int(local_center - tie_height * 0.5)
		for x in range(0, size.x, 48):
			image.fill_rect(Rect2i(x, tie_top, tie_width, tie_height), wood_color)
			image.fill_rect(Rect2i(x + 4, tie_top, tie_width - 8, tie_height), wood_dark)

	# Draw rails on top of the sleepers (two rails per lane).
	for lane_y in rail_lanes:
		var local_center: float = lane_y - rail_top
		var rail_y_top: int = int(local_center - rail_offset)
		var rail_y_bottom: int = int(local_center + rail_offset)
		var half_thickness: float = rail_thickness * 0.5
		image.fill_rect(
			Rect2i(0, int(round(rail_y_top - half_thickness)), size.x, int(round(rail_thickness))),
			rail_color
		)
		image.fill_rect(
			Rect2i(0, int(round(rail_y_bottom - half_thickness)), size.x, int(round(rail_thickness))),
			rail_color
		)

	return ImageTexture.create_from_image(image)

func _build_layout() -> Dictionary:
	var total_lanes: int = TOP_LANES + MID_LANES + BOTTOM_LANES
	var available: float = ARENA_SIZE.y - GOAL_ZONE_HEIGHT - START_ZONE_HEIGHT - 2.0 * SIDEWALK_HEIGHT
	var lane_height: float = floor(available / float(total_lanes))
	if int(lane_height) % 2 == 1:
		lane_height -= 1.0
	var lane_positions: Array[float] = []
	var rail_lanes: Array[float] = []

	var cursor: float = GOAL_ZONE_HEIGHT
	# Top car lanes
	for i in range(TOP_LANES):
		var lane_y: float = cursor + lane_height * 0.5 + i * lane_height
		lane_positions.append(lane_y)
	cursor += TOP_LANES * lane_height

	var sidewalk1: float = cursor + SIDEWALK_HEIGHT * 0.5
	cursor += SIDEWALK_HEIGHT

	# Middle rail lanes
	for i in range(MID_LANES):
		var rail_y: float = cursor + lane_height * 0.5 + i * lane_height
		lane_positions.append(rail_y)
		rail_lanes.append(rail_y)
	cursor += MID_LANES * lane_height

	var sidewalk2: float = cursor + SIDEWALK_HEIGHT * 0.5
	cursor += SIDEWALK_HEIGHT

	# Bottom car lanes
	for i in range(BOTTOM_LANES):
		var lane_y: float = cursor + lane_height * 0.5 + i * lane_height
		lane_positions.append(lane_y)
	cursor += BOTTOM_LANES * lane_height

	var remaining: float = available - lane_height * float(total_lanes)
	var start_height: float = START_ZONE_HEIGHT + maxf(remaining, 0.0)
	var start_center: float = cursor + start_height * 0.5
	var road_height: float = cursor - GOAL_ZONE_HEIGHT
	var rail_top: float = rail_lanes[0] - lane_height * 0.5
	var rail_height: float = MID_LANES * lane_height

	return {
		"lane_height": lane_height,
		"lanes": lane_positions,
		"rail_lanes": rail_lanes,
		"sidewalks": [sidewalk1, sidewalk2],
		"start_center": start_center,
		"start_height": start_height,
		"road_height": road_height,
		"rail_top": rail_top,
		"rail_height": rail_height
	}

func _build_row_centers(layout: Dictionary) -> Array[float]:
	var rows: Array[float] = []
	rows.append(GOAL_ZONE_HEIGHT * 0.5)

	var lanes: Array[float] = _to_float_array(layout.get("lanes", _empty_floats))
	var sidewalks: Array[float] = _to_float_array(layout.get("sidewalks", _empty_floats))
	var start_center: float = float(layout.get("start_center", ARENA_SIZE.y - START_ZONE_HEIGHT * 0.5))

	if lanes.size() >= TOP_LANES + MID_LANES + BOTTOM_LANES and sidewalks.size() >= 2:
		rows.append_array(lanes.slice(0, TOP_LANES))
		rows.append(sidewalks[0])
		rows.append_array(lanes.slice(TOP_LANES, TOP_LANES + MID_LANES))
		rows.append(sidewalks[1])
		rows.append_array(lanes.slice(TOP_LANES + MID_LANES, lanes.size()))
	else:
		rows.append_array(lanes)

	rows.append(start_center)
	return rows

func _to_float_array(value) -> Array[float]:
	var result: Array[float] = []
	if value is Array:
		for item in value:
			result.append(float(item))
	return result

func _generate_sidewalk_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.60, 0.60, 0.60, 1.0))

	var stripe_a: Color = Color(0.68, 0.68, 0.68, 1.0)
	var stripe_b: Color = Color(0.52, 0.52, 0.52, 1.0)
	for y in range(8, size.y - 8, 48):
		for x in range(8, size.x - 8, 64):
			var tile_color: Color = stripe_a if int((float(x) / 64.0) + (float(y) / 48.0)) % 2 == 0 else stripe_b
			image.fill_rect(Rect2i(x, y, 56, 40), tile_color)

	image.fill_rect(Rect2i(0, 0, size.x, 10), Color(0.42, 0.42, 0.42, 1.0))
	image.fill_rect(Rect2i(0, size.y - 10, size.x, 10), Color(0.42, 0.42, 0.42, 1.0))

	return ImageTexture.create_from_image(image)

func _generate_metro_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.12, 0.12, 0.16, 1.0))

	var stripe: Color = Color(0.55, 0.58, 0.62, 1.0)
	image.fill_rect(Rect2i(0, int(size.y * 0.18), size.x, 14), stripe)
	image.fill_rect(Rect2i(0, int(size.y * 0.68), size.x, 14), stripe)

	var window: Color = Color(0.25, 0.35, 0.45, 1.0)
	image.fill_rect(Rect2i(int(size.x * 0.15), int(size.y * 0.30), int(size.x * 0.22), int(size.y * 0.26)), window)
	image.fill_rect(Rect2i(int(size.x * 0.42), int(size.y * 0.30), int(size.x * 0.22), int(size.y * 0.26)), window)
	image.fill_rect(Rect2i(int(size.x * 0.69), int(size.y * 0.30), int(size.x * 0.16), int(size.y * 0.26)), window)

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

func _build_lane_settings() -> void:
	_lane_settings.clear()

	var layout := _build_layout()
	var lane_positions: Array[float] = _to_float_array(layout.get("lanes", _empty_floats))
	var rail_lanes: Array[float] = _to_float_array(layout.get("rail_lanes", _empty_floats))

	# Directions: 2 lanes each direction for top and bottom, and 1 each for rails.
	var directions_top: Array[int] = [1, 1, -1, -1]
	var directions_bottom: Array[int] = [1, 1, -1, -1]
	var base_car_speed: float = 420.0
	var base_metro_speed: float = 520.0

	var lane_index: int = 0
	for i in range(TOP_LANES):
		_lane_settings.append(_make_lane_setting(
			lane_index + 1,
			lane_positions[lane_index],
			directions_top[i],
			base_car_speed + float(i) * 30.0,
			"car",
			Vector2(320.0, 96.0),
			0.70,
			0.60,
			1.35
		))
		lane_index += 1

	for i in range(MID_LANES):
		var dir: int = -1 if i == 0 else 1
		_lane_settings.append(_make_lane_setting(
			lane_index + 1,
			lane_positions[lane_index],
			dir,
			base_metro_speed + float(i) * 40.0,
			"metro",
			Vector2(360.0, 96.0),
			0.45,
			0.80,
			1.40
		))
		lane_index += 1

	for i in range(BOTTOM_LANES):
		_lane_settings.append(_make_lane_setting(
			lane_index + 1,
			lane_positions[lane_index],
			directions_bottom[i],
			base_car_speed + float(i) * 35.0,
			"car",
			Vector2(320.0, 96.0),
			0.68,
			0.65,
			1.40
		))
		lane_index += 1

	# Keep backgrounds aligned to this layout.
	_sidewalk_positions = _to_float_array(layout.get("sidewalks", _empty_floats))
	_rail_lane_positions = _to_float_array(rail_lanes)

func _make_lane_setting(
	lane_number: int,
	y_pos: float,
	direction: int,
	speed: float,
	lane_type: String,
	size: Vector2,
	spawn_chance: float,
	min_interval: float,
	max_interval: float
) -> Dictionary:
	return {
		"path": NodePath("Lanes/Lane%d" % lane_number),
		"y": y_pos,
		"direction": direction,
		"speed": speed,
		"lane_type": lane_type,
		"min_interval": min_interval,
		"max_interval": max_interval,
		"spawn_chance": spawn_chance,
		"size": size
	}

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
			"setting": setting_copy,
			"lane": lane_node
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

func apply_settings(settings: Dictionary) -> void:
	if settings.has("difficulty"):
		difficulty_multiplier = float(settings["difficulty"])
	if settings.has("chapelada"):
		chapel_bad_chance = float(settings["chapelada"])
	if settings.has("vecao"):
		vecao_chance_base = float(settings["vecao"])

func _spawn_player() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()

	_goal_zone.monitoring = false

	var player: Player = PLAYER_SCENE.instantiate() as Player
	if player == null:
		push_error("Failed to instantiate Player scene.")
		_goal_zone.monitoring = true
		return

	var arena_rect: Rect2 = Rect2(Vector2.ZERO, ARENA_SIZE)
	var goal_threshold: float = GOAL_ZONE_HEIGHT * 0.5
	var spawn_position: Vector2 = _player_spawn.global_position
	player.tile_size = _lane_height
	player.setup(arena_rect, spawn_position, goal_threshold, _row_centers)
	player.global_position = spawn_position
	_sync_player_to_lane()

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
		var lane_node: Node2D = spawner.get("lane") as Node2D
		if lane_node and String(setting.get("lane_type", "")) == "car":
			_spawn_initial_car(lane_node.global_position.y, setting)
		_schedule_next_spawn(timer, setting)

	if not _chapel_timer.timeout.is_connected(_on_chapel_timeout):
		_chapel_timer.timeout.connect(_on_chapel_timeout)

func _stop_spawners() -> void:
	for spawner: Dictionary in _lane_spawners:
		var timer: Timer = spawner["timer"] as Timer
		if timer:
			timer.stop()
	_chapel_timer.stop()

func _schedule_next_spawn(timer: Timer, setting: Dictionary) -> void:
	if _state != GameState.PLAYING:
		return
	if timer == null:
		return

	var min_interval: float = float(setting.get("min_interval", 0.9))
	var max_interval: float = float(setting.get("max_interval", min_interval + 0.7))

	# Enforce a physical minimum spacing based on car width and speed.
	var car_size: Vector2 = setting.get("size", Vector2(300.0, 96.0)) as Vector2
	var speed: float = _get_lane_speed(setting)
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

func _clear_collectibles() -> void:
	for child in _collectibles.get_children():
		child.queue_free()

func _on_lane_timeout(lane_node: Node2D, setting: Dictionary, timer: Timer) -> void:
	if _state != GameState.PLAYING:
		return

	var spawn_chance: float = float(setting.get("spawn_chance", 0.65))
	if randf() <= spawn_chance:
		_spawn_car(lane_node.global_position.y, setting)

	_schedule_next_spawn(timer, setting)

func _spawn_initial_car(lane_y: float, setting: Dictionary) -> void:
	if randf() > float(setting.get("spawn_chance", 0.65)):
		return

	var car_size: Vector2 = setting.get("size", Vector2(300.0, 96.0)) as Vector2
	var margin: float = car_size.x * 0.5
	var spawn_x: float = randf_range(margin, ARENA_SIZE.x - margin)
	_spawn_car(lane_y, setting, spawn_x)

func _spawn_car(lane_y: float, setting: Dictionary, spawn_x_override: float = NAN) -> void:
	var car: Car = CAR_SCENE.instantiate() as Car
	if car == null:
		push_error("Failed to instantiate Car scene.")
		return

	var lane_type: String = String(setting.get("lane_type", "car"))
	car.speed = _get_lane_speed(setting)
	car.direction = int(setting["direction"])
	car.car_size = setting["size"] as Vector2
	car.arena_width = ARENA_SIZE.x

	var chosen_texture: Texture2D = _random_car_texture(lane_type)
	car.sprite_texture = chosen_texture
	if chosen_texture == CAR_TEXTURE_VECAO:
		car.car_color = Color(1.0, 1.0, 1.0, 1.0)
		if lane_type == "metro":
			car.speed *= VECAO_RAIL_SPEED_MULTIPLIER
	else:
		if lane_type == "metro":
			car.car_color = Color(1.0, 1.0, 1.0, 1.0)
			car.sprite_texture = _metro_texture
		else:
			car.car_color = _random_car_color()

	var spawn_x: float = spawn_x_override
	if is_nan(spawn_x):
		spawn_x = _get_spawn_x(car.direction, car.car_size.x)
	car.global_position = Vector2(spawn_x, lane_y)
	_cars.add_child(car)

func _random_car_texture(lane_type: String) -> Texture2D:
	var chance: float = _get_vecao_chance(lane_type)
	if randf() <= chance:
		return CAR_TEXTURE_VECAO
	if lane_type == "metro":
		return _metro_texture
	return CAR_TEXTURES[randi() % CAR_TEXTURES.size()]

func _get_lane_speed(setting: Dictionary) -> float:
	var base_speed: float = float(setting.get("speed", 420.0))
	var lane_type: String = String(setting.get("lane_type", "car"))
	var multiplier: float = maxf(difficulty_multiplier, 0.1)
	if lane_type == "metro":
		multiplier *= 2.2
	return base_speed * multiplier

func _get_vecao_chance(lane_type: String) -> float:
	var base: float = clampf(vecao_chance_base, 0.0, 1.0)
	if lane_type == "metro":
		return base * VECAO_RAIL_MULTIPLIER
	return base

func _random_car_color() -> Color:
	return CAR_COLOR_PALETTE[randi() % CAR_COLOR_PALETTE.size()]

func _get_spawn_x(direction: int, car_width: float) -> float:
	var margin: float = maxf(180.0, car_width)
	if direction >= 0:
		return -margin
	return ARENA_SIZE.x + margin

func _load_chapel_texture() -> Texture2D:
	if ResourceLoader.exists(CHAPEL_TEXTURE_PATH):
		return load(CHAPEL_TEXTURE_PATH)
	return null

func _start_chapel_timer() -> void:
	if _chapel_timer == null:
		return
	_chapel_timer.stop()
	_chapel_timer.one_shot = true
	_chapel_timer.wait_time = randf_range(CHAPEL_SPAWN_MIN, CHAPEL_SPAWN_MAX)
	_chapel_timer.start()

func _on_chapel_timeout() -> void:
	if _state != GameState.PLAYING:
		return
	if _lane_positions.is_empty():
		return

	var lane_y: float = _lane_positions[randi() % _lane_positions.size()]
	_spawn_chapel(lane_y)
	_start_chapel_timer()

func _spawn_chapel(lane_y: float) -> void:
	var chapel: Chapel = CHAPEL_SCENE.instantiate() as Chapel
	if chapel == null:
		return

	var margin: float = 120.0
	var spawn_x: float = randf_range(margin, ARENA_SIZE.x - margin)
	chapel.global_position = Vector2(spawn_x, lane_y)
	chapel.item_texture = _chapel_texture
	chapel.is_bad = randf() <= clampf(chapel_bad_chance, 0.0, 1.0)
	chapel.collected.connect(_on_chapel_collected)
	_collectibles.add_child(chapel)

func _on_chapel_collected(is_bad: bool) -> void:
	if _state != GameState.PLAYING:
		return
	if is_bad:
		_score = 0
		_ui.set_score(_score)
		_ui.set_vga_enabled(true)
		_play_sfx(SFX_CHAPEL_RUIM)
	else:
		_score += 1
		_ui.set_score(_score)
		_play_sfx(SFX_CHAPEL_BOM)

func _setup_audio() -> void:
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

func _play_sfx(stream: AudioStream) -> void:
	if _sfx_player == null or stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()

func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.autoplay = false
	_music_player.bus = "Master"
	_music_player.volume_db = -6.0
	add_child(_music_player)

	var music_path: String = "res://assets/barulho/melodia.mp3"
	if ResourceLoader.exists(music_path):
		var music_stream: AudioStream = load(music_path)
		if music_stream is AudioStreamMP3:
			(music_stream as AudioStreamMP3).loop = true
		_music_player.stream = music_stream
		_music_player.play()

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
	_state = GameState.PAUSED as GameState
	_ui.show_pause_overlay()
	get_tree().paused = true

func _on_ui_resume_pressed() -> void:
	if _state != GameState.PAUSED:
		return
	get_tree().paused = false
	_state = GameState.PLAYING as GameState
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
		if _player != null and _player.has_method("get_row_index"):
			if _player.get_row_index() != 0:
				return
		_on_player_reached_goal()

func _on_player_died() -> void:
	if _state != GameState.PLAYING:
		return
	_state = GameState.GAME_OVER as GameState
	_stop_spawners()
	_ui.hide_pause_overlay()
	_ui.show_overlay("SECO SECO SECO!", "Reiniciar")
	_play_sfx(SFX_COLISAO[randi() % SFX_COLISAO.size()])

func _on_player_reached_goal() -> void:
	if _state != GameState.PLAYING:
		return
	if _player != null and _player.has_method("get_row_index"):
		if _player.get_row_index() != 0:
			return
	_state = GameState.WIN as GameState
	_stop_spawners()
	_ui.hide_pause_overlay()
	_ui.show_overlay("LISO LISO LISO!", "Jogar novamente")
	_play_sfx(SFX_GANHAR)

func _on_player_advanced_row(points: int) -> void:
	if _state != GameState.PLAYING:
		return
	if not row_score_enabled:
		return
	_score += points
	_ui.set_score(_score)

func _sync_player_to_lane() -> void:
	if _player == null:
		return
	var row_index: int = _get_row_index_from_y(_player.global_position.y)
	if row_index >= 0 and row_index < _row_centers.size():
		_player.global_position.y = _row_centers[row_index]
		_player.call_deferred("set_safe_zone_hint", row_index, _row_centers)

func _get_row_index_from_y(y_value: float) -> int:
	if _row_centers.is_empty():
		return -1
	var closest_index: int = 0
	var closest_dist: float = absf(_row_centers[0] - y_value)
	for i in range(1, _row_centers.size()):
		var dist: float = absf(_row_centers[i] - y_value)
		if dist < closest_dist:
			closest_dist = dist
			closest_index = i
	return closest_index
