extends Node

const GAME_SCENE: PackedScene = preload("res://scenes/Game.tscn")
const MENU_BG_PATH: String = "res://assets/tech-forest.png"
const SFX_OPEN: AudioStream = preload("res://assets/barulho/salve.mp3")
const SFX_START: AudioStream = preload("res://assets/barulho/ismaili.mp3")

@onready var _menu_layer: CanvasLayer = $MenuLayer
@onready var _start_button: Button = $MenuLayer/MenuRoot/Panel/VBoxContainer/StartButton
@onready var _remendo_button: Button = $MenuLayer/MenuRoot/Panel/VBoxContainer/RemendoButton
@onready var _menu_background: TextureRect = $MenuLayer/MenuRoot/MenuBackground
@onready var _remendo_panel: Panel = $MenuLayer/MenuRoot/RemendoPanel
@onready var _difficulty_input: LineEdit = $MenuLayer/MenuRoot/RemendoPanel/VBoxContainer/DifficultyRow/DifficultyInput
@onready var _chapel_slider: HSlider = $MenuLayer/MenuRoot/RemendoPanel/VBoxContainer/ChapelRow/ChapelSlider
@onready var _chapel_value: Label = $MenuLayer/MenuRoot/RemendoPanel/VBoxContainer/ChapelRow/ChapelValue
@onready var _vecao_slider: HSlider = $MenuLayer/MenuRoot/RemendoPanel/VBoxContainer/VecaoRow/VecaoSlider
@onready var _vecao_value: Label = $MenuLayer/MenuRoot/RemendoPanel/VBoxContainer/VecaoRow/VecaoValue
@onready var _remendo_close: Button = $MenuLayer/MenuRoot/RemendoPanel/VBoxContainer/CloseButton

var _game: Node = null
var _settings: Dictionary = {
	"difficulty": 0.5,
	"chapelada": 0.25,
	"vecao": 0.15
}
var _audio_player: AudioStreamPlayer

func _ready() -> void:
	_ensure_input_actions()
	_connect_menu()
	_configure_menu_background()
	_setup_remendo()
	_setup_audio()
	_show_menu()
	_play_open()

func _connect_menu() -> void:
	if not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)
	if not _remendo_button.pressed.is_connected(_on_remendo_pressed):
		_remendo_button.pressed.connect(_on_remendo_pressed)
	if not _remendo_close.pressed.is_connected(_on_remendo_close):
		_remendo_close.pressed.connect(_on_remendo_close)
	if not _difficulty_input.text_changed.is_connected(_on_difficulty_changed):
		_difficulty_input.text_changed.connect(_on_difficulty_changed)
	if not _difficulty_input.text_submitted.is_connected(_on_difficulty_submitted):
		_difficulty_input.text_submitted.connect(_on_difficulty_submitted)
	if not _chapel_slider.value_changed.is_connected(_on_remendo_changed):
		_chapel_slider.value_changed.connect(_on_remendo_changed)
	if not _vecao_slider.value_changed.is_connected(_on_remendo_changed):
		_vecao_slider.value_changed.connect(_on_remendo_changed)

func _configure_menu_background() -> void:
	if _menu_background == null:
		return

	if ResourceLoader.exists(MENU_BG_PATH):
		_menu_background.texture = load(MENU_BG_PATH)
	else:
		_menu_background.texture = null

func _show_menu() -> void:
	_menu_layer.visible = true
	_remendo_panel.visible = false

func _hide_menu() -> void:
	_menu_layer.visible = false

func _on_start_pressed() -> void:
	_start_button.release_focus()
	_play_start()
	_hide_menu()
	_load_game()

func _load_game() -> void:
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = GAME_SCENE.instantiate()
	if _game.has_method("apply_settings"):
		_game.apply_settings(_settings)
	add_child(_game)
	if _game.has_signal("request_main_menu"):
		_game.request_main_menu.connect(_on_game_request_menu)

func _setup_remendo() -> void:
	_remendo_panel.visible = false
	_difficulty_input.text = str(_settings["difficulty"])
	_chapel_slider.value = _settings["chapelada"]
	_vecao_slider.value = _settings["vecao"]
	_update_remendo_labels()

func _on_remendo_pressed() -> void:
	_remendo_panel.visible = true

func _on_remendo_close() -> void:
	_remendo_panel.visible = false

func _on_remendo_changed(_value: float) -> void:
	_settings["chapelada"] = _chapel_slider.value
	_settings["vecao"] = _vecao_slider.value
	_update_remendo_labels()

func _update_remendo_labels() -> void:
	_chapel_value.text = "%d%%" % int(round(_chapel_slider.value * 100.0))
	_vecao_value.text = "%d%%" % int(round(_vecao_slider.value * 100.0))

func _on_difficulty_changed(new_text: String) -> void:
	_settings["difficulty"] = _parse_difficulty(new_text)

func _on_difficulty_submitted(new_text: String) -> void:
	var value := _parse_difficulty(new_text)
	_settings["difficulty"] = value
	_difficulty_input.text = str(value)

func _parse_difficulty(text: String) -> float:
	var cleaned: String = text.strip_edges()
	if cleaned.is_empty():
		return _settings["difficulty"]
	if cleaned.is_valid_float():
		var value := cleaned.to_float()
		if value <= 0.0:
			return 0.05
		return value
	return _settings["difficulty"]

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)

func _play_open() -> void:
	if _audio_player == null:
		return
	_audio_player.stream = SFX_OPEN
	_audio_player.play()

func _play_start() -> void:
	if _audio_player == null:
		return
	_audio_player.stream = SFX_START
	_audio_player.play()

func _on_game_request_menu() -> void:
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		_game = null
	_show_menu()
	_play_open()

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
			event.keycode = key as Key
			InputMap.action_add_event(action, event)

func _action_has_key(action: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false
