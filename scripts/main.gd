extends Node

const GAME_SCENE: PackedScene = preload("res://scenes/Game.tscn")
const MENU_BG_PATH: String = "res://assets/tech-forest.png"

@onready var _menu_layer: CanvasLayer = $MenuLayer
@onready var _start_button: Button = $MenuLayer/MenuRoot/Panel/VBoxContainer/StartButton
@onready var _menu_background: TextureRect = $MenuLayer/MenuRoot/MenuBackground

var _game: Node = null

func _ready() -> void:
	_ensure_input_actions()
	_connect_menu()
	_configure_menu_background()
	_show_menu()

func _connect_menu() -> void:
	if not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)

func _configure_menu_background() -> void:
	if _menu_background == null:
		return

	if ResourceLoader.exists(MENU_BG_PATH):
		_menu_background.texture = load(MENU_BG_PATH)
	else:
		_menu_background.texture = null

func _show_menu() -> void:
	_menu_layer.visible = true

func _hide_menu() -> void:
	_menu_layer.visible = false

func _on_start_pressed() -> void:
	_start_button.release_focus()
	_hide_menu()
	_load_game()

func _load_game() -> void:
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = GAME_SCENE.instantiate()
	add_child(_game)
	if _game.has_signal("request_main_menu"):
		_game.request_main_menu.connect(_on_game_request_menu)

func _on_game_request_menu() -> void:
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		_game = null
	_show_menu()

func _ensure_input_actions() -> void:
	_ensure_action("move_up", [Key.KEY_W, Key.KEY_UP])
	_ensure_action("move_down", [Key.KEY_S, Key.KEY_DOWN])
	_ensure_action("move_left", [Key.KEY_A, Key.KEY_LEFT])
	_ensure_action("move_right", [Key.KEY_D, Key.KEY_RIGHT])

func _ensure_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		if not _action_has_key(action, key):
			var event := InputEventKey.new()
			event.keycode = key
			InputMap.action_add_event(action, event)

func _action_has_key(action: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false
