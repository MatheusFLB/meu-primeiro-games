extends CharacterBody2D
class_name Player

signal died
signal reached_goal
signal advanced_row(points: int)

@export var tile_size: float = 128.0
@export var step_duration: float = 0.12
@export var frog_size: Vector2 = Vector2(128.0, 128.0)
@export var frog_color: Color = Color(0.20, 0.85, 0.25, 1.0)
@export var sprite_texture: Texture2D
@export var crushed_texture: Texture2D

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _polygon: Polygon2D = $Polygon2D

var _arena_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1080.0, 1920.0))
var _goal_y_threshold: float = 0.0
var _is_moving: bool = false
var _is_alive: bool = true
var _tween: Tween
var _start_position: Vector2 = Vector2.ZERO
var _start_row_y: float = 0.0
var _max_row_reached: int = 0
var _last_direction: Vector2i = Vector2i.UP
var _safe_zone_count: int = 0
var _touch_active: bool = false
var _touch_start: Vector2 = Vector2.ZERO
var _touch_threshold: float = 48.0
var _use_touch: bool = false
var _row_centers: Array[float] = []
var _start_row_index: int = 0
var _current_row_index: int = 0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_use_touch = OS.has_feature("mobile")
	_touch_threshold = tile_size * 0.35
	_apply_visuals()

func setup(arena_rect: Rect2, start_position: Vector2, goal_y_threshold: float, row_centers: Array[float] = []) -> void:
	_arena_rect = arena_rect
	_start_position = start_position
	_goal_y_threshold = goal_y_threshold
	global_position = start_position
	_row_centers = row_centers.duplicate()
	if _row_centers.size() > 0:
		_start_row_index = _find_closest_row_index(start_position.y)
		_current_row_index = _start_row_index
		_start_row_y = _row_centers[_start_row_index]
		global_position.y = _start_row_y
	else:
		_start_row_y = start_position.y
	_max_row_reached = 0
	_is_moving = false
	_is_alive = true
	_safe_zone_count = 0
	_last_direction = Vector2i.UP
	_touch_threshold = tile_size * 0.35
	if is_inside_tree():
		_apply_visuals()
	else:
		call_deferred("_apply_visuals")

func reset_to_start() -> void:
	global_position = _start_position
	_max_row_reached = 0
	_is_moving = false
	_is_alive = true
	_safe_zone_count = 0
	_last_direction = Vector2i.UP

func enter_safe_zone() -> void:
	_safe_zone_count += 1

func exit_safe_zone() -> void:
	_safe_zone_count = max(_safe_zone_count - 1, 0)

func is_in_safe_zone() -> bool:
	return _safe_zone_count > 0

func die() -> void:
	if not _is_alive:
		return
	_is_alive = false
	_is_moving = false
	if _tween and _tween.is_running():
		_tween.kill()
	if crushed_texture != null and _sprite != null:
		var was_flipped: bool = _sprite.flip_h
		_fit_sprite_to_size(crushed_texture, frog_size)
		_sprite.flip_h = was_flipped
	died.emit()

func request_move(direction: Vector2i) -> void:
	if not _is_alive or _is_moving:
		return
	if direction == Vector2i.ZERO:
		return

	_last_direction = direction
	_update_sprite_orientation(direction)

	var target: Vector2 = global_position
	var target_row_index := _current_row_index
	if direction.y != 0 and _row_centers.size() > 0:
		target_row_index = clamp(_current_row_index + direction.y, 0, _row_centers.size() - 1)
		target.y = _row_centers[target_row_index]
	else:
		target.y = global_position.y
		target += Vector2(direction) * tile_size
	target = _clamp_to_arena(target)
	if target.is_equal_approx(global_position):
		return

	_handle_row_advance(target, target_row_index)
	_start_tween(target)
	_current_row_index = target_row_index
	_check_goal(target, target_row_index)

func _physics_process(_delta: float) -> void:
	if not _is_alive or _is_moving:
		return

	if Input.is_action_just_pressed("move_up"):
		request_move(Vector2i.UP)
	elif Input.is_action_just_pressed("move_down"):
		request_move(Vector2i.DOWN)
	elif Input.is_action_just_pressed("move_left"):
		request_move(Vector2i.LEFT)
	elif Input.is_action_just_pressed("move_right"):
		request_move(Vector2i.RIGHT)

func _unhandled_input(event: InputEvent) -> void:
	if not _use_touch or not _is_alive:
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_touch_active = true
			_touch_start = touch_event.position
		else:
			_touch_active = false
	elif event is InputEventScreenDrag and _touch_active and not _is_moving:
		var drag_event := event as InputEventScreenDrag
		var delta: Vector2 = drag_event.position - _touch_start
		if delta.length() < _touch_threshold:
			return

		var direction: Vector2i
		if absf(delta.x) > absf(delta.y):
			direction = Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
		else:
			direction = Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP

		_touch_start = drag_event.position
		request_move(direction)

func _clamp_to_arena(target: Vector2) -> Vector2:
	var half: Vector2 = frog_size * 0.5
	var min_x: float = _arena_rect.position.x + half.x
	var max_x: float = _arena_rect.position.x + _arena_rect.size.x - half.x
	var min_y: float = _arena_rect.position.y + half.y
	var max_y: float = _arena_rect.position.y + _arena_rect.size.y - half.y

	return Vector2(clamp(target.x, min_x, max_x), clamp(target.y, min_y, max_y))

func _handle_row_advance(target: Vector2, target_row_index: int) -> void:
	if _row_centers.size() > 0:
		var rows_up_index: int = _start_row_index - target_row_index
		if rows_up_index > _max_row_reached:
			var rows_gained: int = rows_up_index - _max_row_reached
			_max_row_reached = rows_up_index
			advanced_row.emit(rows_gained * 10)
		return

	var rows_up_fallback: int = int(round((_start_row_y - target.y) / tile_size))
	if rows_up_fallback > _max_row_reached:
		var rows_gained: int = rows_up_fallback - _max_row_reached
		_max_row_reached = rows_up_fallback
		advanced_row.emit(rows_gained * 10)

func _start_tween(target: Vector2) -> void:
	_is_moving = true
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target, step_duration)
	_tween.finished.connect(_on_tween_finished)

func _on_tween_finished() -> void:
	_is_moving = false

func _check_goal(target: Vector2, target_row_index: int) -> void:
	if _row_centers.size() > 0:
		if target_row_index == 0 and _is_alive:
			reached_goal.emit()
		return
	if target.y <= _goal_y_threshold and _is_alive:
		reached_goal.emit()

func set_safe_zone_hint(row_index: int, row_centers: Array[float]) -> void:
	if row_centers.size() == 0:
		return
	_row_centers = row_centers.duplicate()
	_current_row_index = clamp(row_index, 0, _row_centers.size() - 1)

func get_row_index() -> int:
	return _current_row_index

func _find_closest_row_index(y_value: float) -> int:
	if _row_centers.is_empty():
		return 0
	var closest_index: int = 0
	var closest_dist: float = absf(_row_centers[0] - y_value)
	for i in range(1, _row_centers.size()):
		var dist: float = absf(_row_centers[i] - y_value)
		if dist < closest_dist:
			closest_dist = dist
			closest_index = i
	return closest_index

func _apply_visuals() -> void:
	if _collision_shape == null or _sprite == null or _polygon == null:
		return
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = frog_size * 0.9
	_collision_shape.shape = rect_shape

	var half: Vector2 = frog_size * 0.5
	_polygon.color = frog_color
	_polygon.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])

	var texture: Texture2D = sprite_texture
	if texture == null:
		var tex_width: int = int(maxf(96.0, frog_size.x * 2.0))
		var tex_height: int = int(maxf(96.0, frog_size.y * 2.0))
		texture = _generate_frog_texture(Vector2i(tex_width, tex_height), frog_color)

	_fit_sprite_to_size(texture, frog_size)
	_polygon.visible = false
	_update_sprite_orientation(_last_direction)

func _fit_sprite_to_size(texture: Texture2D, target_size: Vector2) -> void:
	_sprite.texture = texture
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		_sprite.scale = Vector2.ONE
		return
	_sprite.scale = target_size / tex_size

func _update_sprite_orientation(direction: Vector2i) -> void:
	if direction == Vector2i.LEFT:
		_sprite.flip_h = true
	elif direction == Vector2i.RIGHT:
		_sprite.flip_h = false

func _generate_frog_texture(size: Vector2i, base_color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(base_color)

	var belly_color: Color = base_color.lightened(0.25)
	var eye_color: Color = Color(0.05, 0.05, 0.05, 1.0)
	var cheek_color: Color = base_color.lightened(0.15)

	image.fill_rect(
		Rect2i(int(size.x * 0.18), int(size.y * 0.42), int(size.x * 0.64), int(size.y * 0.44)),
		belly_color
	)
	image.fill_rect(
		Rect2i(int(size.x * 0.18), int(size.y * 0.18), int(size.x * 0.18), int(size.y * 0.18)),
		eye_color
	)
	image.fill_rect(
		Rect2i(int(size.x * 0.64), int(size.y * 0.18), int(size.x * 0.18), int(size.y * 0.18)),
		eye_color
	)
	image.fill_rect(
		Rect2i(int(size.x * 0.10), int(size.y * 0.55), int(size.x * 0.14), int(size.y * 0.18)),
		cheek_color
	)
	image.fill_rect(
		Rect2i(int(size.x * 0.76), int(size.y * 0.55), int(size.x * 0.14), int(size.y * 0.18)),
		cheek_color
	)

	return ImageTexture.create_from_image(image)
