extends Area2D
class_name Chapel

signal collected(is_bad: bool)

@export var item_texture: Texture2D
@export var item_size: Vector2 = Vector2(72.0, 72.0)
@export var is_bad: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _polygon: Polygon2D = $Polygon2D

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	monitoring = true
	monitorable = true
	_apply_visuals()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _apply_visuals() -> void:
	var rect := RectangleShape2D.new()
	rect.size = item_size
	_collision.shape = rect

	var texture: Texture2D = item_texture
	if texture == null:
		texture = _generate_placeholder_texture(Vector2i(96, 96))

	_sprite.texture = texture
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		_sprite.scale = item_size / tex_size

	_polygon.visible = false

	# Visual remains identical for good/bad to confuse the player.
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		collected.emit(is_bad)
		queue_free()

func _generate_placeholder_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.95, 0.85, 0.25, 1.0))
	image.fill_rect(Rect2i(12, 20, 72, 40), Color(0.2, 0.2, 0.2, 1.0))
	return ImageTexture.create_from_image(image)
