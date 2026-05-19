extends Control

signal resolved(success: bool)

@onready var _marker: ColorRect = %Marker
@onready var _track: Control = %TrackArea
@onready var _hint: Label = %Hint

var _active := false
var _pos := 0.0
var _dir := 1.0
var _speed := 1.2
var _green_min := 0.35
var _green_max := 0.65


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if not _active:
		return
	_pos += _dir * _speed * delta
	if _pos >= 1.0:
		_pos = 1.0
		_dir = -1.0
	elif _pos <= 0.0:
		_pos = 0.0
		_dir = 1.0
	_update_marker()


func start() -> void:
	_active = true
	_pos = randf_range(0.1, 0.3)
	_dir = 1.0
	visible = true
	_hint.text = "Тап в зелёной зоне!"
	_update_marker()


func stop() -> void:
	_active = false
	visible = false


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish(_pos >= _green_min and _pos <= _green_max)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_finish(_pos >= _green_min and _pos <= _green_max)
		accept_event()


func _finish(success: bool) -> void:
	stop()
	resolved.emit(success)


func _update_marker() -> void:
	if not is_node_ready():
		return
	var w := maxf(_track.size.x - _marker.size.x, 1.0)
	_marker.position.x = _pos * w
