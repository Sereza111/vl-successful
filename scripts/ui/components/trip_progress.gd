extends Control

@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar

var _duration := 1.0
var _elapsed := 0.0
var _active := false
var _finished := false


func start_phase(title: String, duration_sec: float) -> void:
	_title.text = title
	_duration = maxf(duration_sec, 0.1)
	_elapsed = 0.0
	_active = true
	_finished = false
	_bar.value = 0.0
	show()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_bar.value = clampf(_elapsed / _duration, 0.0, 1.0) * 100.0
	if _elapsed >= _duration:
		_active = false
		_finished = true


func is_complete() -> bool:
	return _finished


func stop() -> void:
	_active = false
	_finished = false
	_elapsed = 0.0
	hide()
