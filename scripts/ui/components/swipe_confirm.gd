extends Control

signal confirmed

@export var hint_text: String = "Сдвиньте, чтобы принять"
@export var confirm_label: String = "Готово!"

var _locked := false

const CONFIRM_RATIO := 0.85
const THUMB_MARGIN := 4.0

@onready var _track: Panel = $Track
@onready var _thumb: Panel = $Thumb
@onready var _hint: Label = $Track/Hint

var _dragging := false
var _drag_offset_x := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_track.mouse_filter = MOUSE_FILTER_IGNORE
	_thumb.mouse_filter = MOUSE_FILTER_IGNORE
	_track.add_theme_stylebox_override("panel", UiStyles.swipe_track())
	_thumb.add_theme_stylebox_override("panel", UiStyles.swipe_thumb())
	if _hint:
		_hint.text = hint_text
		_hint.mouse_filter = MOUSE_FILTER_IGNORE
	call_deferred("_reset_thumb")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_reset_thumb")


func set_locked(value: bool) -> void:
	_locked = value
	mouse_filter = MOUSE_FILTER_IGNORE if _locked else MOUSE_FILTER_STOP


func is_locked() -> bool:
	return _locked


func reset() -> void:
	_locked = false
	mouse_filter = MOUSE_FILTER_STOP
	if _hint:
		_hint.text = hint_text
		_hint.modulate.a = 1.0
	_reset_thumb()


func _reset_thumb() -> void:
	if not is_node_ready():
		return
	var h := maxf(maxf(custom_minimum_size.y, size.y), 56.0) - THUMB_MARGIN * 2.0
	_thumb.size = Vector2(_get_thumb_size(), h)
	_thumb.position = Vector2(THUMB_MARGIN, THUMB_MARGIN)
	if _track:
		_track.custom_minimum_size.y = _thumb.size.y + THUMB_MARGIN * 2.0


func _get_thumb_size() -> float:
	return maxf(52.0, minf(size.y - THUMB_MARGIN * 2.0, 64.0))


func _get_max_thumb_x() -> float:
	return maxf(THUMB_MARGIN, size.x - _thumb.size.x - THUMB_MARGIN)


func _get_progress() -> float:
	var travel := _get_max_thumb_x() - THUMB_MARGIN
	if travel <= 0.0:
		return 0.0
	return clampf((_thumb.position.x - THUMB_MARGIN) / travel, 0.0, 1.0)


func _local_pointer(event: InputEvent) -> Vector2:
	return event.position


func _is_press_event(event: InputEvent) -> bool:
	return (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
		or event is InputEventScreenTouch
	)


func _is_release_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	if event is InputEventScreenTouch:
		return not event.pressed
	return false


func _is_motion_event(event: InputEvent) -> bool:
	return event is InputEventMouseMotion or event is InputEventScreenDrag


func _gui_input(event: InputEvent) -> void:
	if _locked:
		return

	if _is_press_event(event) and event.pressed:
		var pos := _local_pointer(event)
		if _thumb_rect().has_point(pos) or pos.x <= _thumb.position.x + _thumb.size.x + 20.0:
			_dragging = true
			_drag_offset_x = pos.x - _thumb.position.x
			set_process_input(true)
			accept_event()
		return

	if _is_release_event(event):
		if _dragging:
			_release_thumb()
			accept_event()
		return

	if _is_motion_event(event) and _dragging:
		_apply_drag(_local_pointer(event))
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging or _locked:
		return
	if _is_motion_event(event):
		var local_event := make_input_local(event)
		_apply_drag(_local_pointer(local_event))
	elif _is_release_event(event):
		_release_thumb()


func _apply_drag(local_pos: Vector2) -> void:
	_set_thumb_x(local_pos.x - _drag_offset_x)
	if _hint:
		_hint.modulate.a = 1.0 - _get_progress() * 0.65


func _thumb_rect() -> Rect2:
	return Rect2(_thumb.position, _thumb.size)


func _set_thumb_x(x: float) -> void:
	_thumb.position.x = clampf(x, THUMB_MARGIN, _get_max_thumb_x())


func _release_thumb() -> void:
	if not _dragging:
		return
	_dragging = false
	set_process_input(false)
	if _get_progress() >= CONFIRM_RATIO:
		if _hint:
			_hint.text = confirm_label
		confirmed.emit()
		set_locked(true)
	else:
		var tween := create_tween()
		tween.tween_property(_thumb, "position:x", THUMB_MARGIN, 0.2).set_trans(Tween.TRANS_BACK)
		if _hint:
			tween.parallel().tween_property(_hint, "modulate:a", 1.0, 0.15)
