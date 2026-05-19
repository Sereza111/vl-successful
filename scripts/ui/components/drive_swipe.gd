extends Control

signal resolved(success: bool)

@export var hint_text: String = "Свайп в сторону стрелки"

@onready var _arrow: Label = %Arrow
@onready var _hint: Label = %Hint

var _active := false
var _want_left := false
var _start_x := 0.0
const SWIPE_THRESHOLD := 80.0


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP


func start() -> void:
	_active = true
	_want_left = randf() < 0.5
	_arrow.text = "←" if _want_left else "→"
	_hint.text = "Свайп %s" % ("влево" if _want_left else "вправо")
	visible = true


func stop() -> void:
	_active = false
	visible = false


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_x = event.position.x
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_check_swipe(event.position.x - _start_x)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_x = event.position.x
		else:
			_check_swipe(event.position.x - _start_x)


func _check_swipe(delta_x: float) -> void:
	if not _active:
		return
	var success := false
	if _want_left and delta_x < -SWIPE_THRESHOLD:
		success = true
	if not _want_left and delta_x > SWIPE_THRESHOLD:
		success = true
	if absf(delta_x) >= SWIPE_THRESHOLD:
		_finish(success)


func _finish(success: bool) -> void:
	stop()
	resolved.emit(success)
