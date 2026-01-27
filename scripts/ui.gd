extends CanvasLayer
class_name GameUI

signal move_pressed(direction: Vector2i)
signal restart_pressed
signal pause_pressed
signal resume_pressed
signal menu_pressed

@onready var _overlay: Control = $Overlay
@onready var _overlay_message: Label = $Overlay/Panel/VBoxContainer/MessageLabel
@onready var _overlay_button: Button = $Overlay/Panel/VBoxContainer/RestartButton

@onready var _pause_button: Button = $PauseButton
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _resume_button: Button = $PauseOverlay/Panel/VBoxContainer/ResumeButton
@onready var _pause_restart_button: Button = $PauseOverlay/Panel/VBoxContainer/PauseRestartButton
@onready var _menu_button: Button = $PauseOverlay/Panel/VBoxContainer/MenuButton

@onready var _dpad: Control = $DPad
@onready var _up_button: Button = $DPad/UpButton
@onready var _down_button: Button = $DPad/DownButton
@onready var _left_button: Button = $DPad/LeftButton
@onready var _right_button: Button = $DPad/RightButton

var _is_mobile: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_mobile = OS.has_feature("mobile")
	hide_overlay()
	hide_pause_overlay()
	_connect_buttons()
	set_dpad_enabled(true)
	set_pause_button_visible(true)

func show_overlay(message: String, button_text: String = "Reiniciar") -> void:
	_overlay_message.text = message
	_overlay_button.text = button_text
	_overlay.visible = true
	set_pause_button_visible(false)
	set_dpad_enabled(false)

func hide_overlay() -> void:
	_overlay.visible = false
	set_pause_button_visible(true)
	set_dpad_enabled(true)

func show_pause_overlay() -> void:
	_pause_overlay.visible = true
	set_pause_button_visible(false)
	set_dpad_enabled(false)

func hide_pause_overlay() -> void:
	_pause_overlay.visible = false
	set_pause_button_visible(true)
	set_dpad_enabled(true)

func set_pause_button_visible(visible: bool) -> void:
	_pause_button.visible = visible
	_pause_button.disabled = not visible

func set_dpad_enabled(enabled: bool) -> void:
	var show: bool = enabled and _is_mobile
	_dpad.visible = show
	_up_button.disabled = not show
	_down_button.disabled = not show
	_left_button.disabled = not show
	_right_button.disabled = not show

func _connect_buttons() -> void:
	if not _overlay_button.pressed.is_connected(_on_restart_pressed):
		_overlay_button.pressed.connect(_on_restart_pressed)
	if not _pause_button.pressed.is_connected(_on_pause_pressed):
		_pause_button.pressed.connect(_on_pause_pressed)
	if not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
	if not _pause_restart_button.pressed.is_connected(_on_restart_pressed):
		_pause_restart_button.pressed.connect(_on_restart_pressed)
	if not _menu_button.pressed.is_connected(_on_menu_pressed):
		_menu_button.pressed.connect(_on_menu_pressed)
	if not _up_button.pressed.is_connected(_on_up_pressed):
		_up_button.pressed.connect(_on_up_pressed)
	if not _down_button.pressed.is_connected(_on_down_pressed):
		_down_button.pressed.connect(_on_down_pressed)
	if not _left_button.pressed.is_connected(_on_left_pressed):
		_left_button.pressed.connect(_on_left_pressed)
	if not _right_button.pressed.is_connected(_on_right_pressed):
		_right_button.pressed.connect(_on_right_pressed)

func _on_restart_pressed() -> void:
	restart_pressed.emit()

func _on_pause_pressed() -> void:
	pause_pressed.emit()

func _on_resume_pressed() -> void:
	resume_pressed.emit()

func _on_menu_pressed() -> void:
	menu_pressed.emit()

func _on_up_pressed() -> void:
	move_pressed.emit(Vector2i.UP)

func _on_down_pressed() -> void:
	move_pressed.emit(Vector2i.DOWN)

func _on_left_pressed() -> void:
	move_pressed.emit(Vector2i.LEFT)

func _on_right_pressed() -> void:
	move_pressed.emit(Vector2i.RIGHT)
