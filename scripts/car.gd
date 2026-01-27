extends Area2D
class_name Car

@export var speed: float = 320.0
@export var direction: int = 1
@export var car_size: Vector2 = Vector2(180.0, 64.0)
@export var car_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var sprite_texture: Texture2D
@export var arena_width: float = 1080.0
@export var despawn_margin: float = 256.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _polygon: Polygon2D = $Polygon2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	monitoring = true
	monitorable = true
	_apply_visuals()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position.x += float(direction) * speed * delta
	_sprite.flip_h = direction < 0

	var min_x: float = -despawn_margin
	var max_x: float = arena_width + despawn_margin
	if direction > 0 and global_position.x > max_x:
		queue_free()
	elif direction < 0 and global_position.x < min_x:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("is_in_safe_zone") and body.call("is_in_safe_zone"):
		return
	if body.has_method("die"):
		body.call("die")

func _apply_visuals() -> void:
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = car_size * 0.95
	_collision_shape.shape = rect_shape

	var texture: Texture2D = sprite_texture
	if texture == null:
		texture = _generate_car_texture(Vector2i(256, 96), car_color)

	_fit_sprite_to_size(texture, car_size)
	_sprite.modulate = car_color
	_polygon.visible = false

	var half: Vector2 = car_size * 0.5
	_polygon.color = car_color
	_polygon.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])

func _fit_sprite_to_size(texture: Texture2D, target_size: Vector2) -> void:
	_sprite.texture = texture
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		_sprite.scale = Vector2.ONE
		return
	_sprite.scale = target_size / tex_size

func _generate_car_texture(size: Vector2i, base_color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(base_color)

	var window_color: Color = base_color.lightened(0.35)
	var wheel_color: Color = base_color.darkened(0.45)

	image.fill_rect(
		Rect2i(int(size.x * 0.18), int(size.y * 0.18), int(size.x * 0.64), int(size.y * 0.32)),
		window_color
	)
	image.fill_rect(
		Rect2i(int(size.x * 0.08), int(size.y * 0.74), int(size.x * 0.22), int(size.y * 0.20)),
		wheel_color
	)
	image.fill_rect(
		Rect2i(int(size.x * 0.70), int(size.y * 0.74), int(size.x * 0.22), int(size.y * 0.20)),
		wheel_color
	)

	return ImageTexture.create_from_image(image)