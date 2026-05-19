extends Node

signal second_tick
signal day_changed(day: int)
signal week_changed(week: int)

const SECONDS_PER_GAME_DAY := 1800.0

var game_seconds: float = 0.0
var game_day: int = 1
var game_week: int = 1

var _second_accumulator: float = 0.0
var _last_day_index: int = 0
var _last_week_index: int = 0


func _process(delta: float) -> void:
	game_seconds += delta
	_second_accumulator += delta
	while _second_accumulator >= 1.0:
		_second_accumulator -= 1.0
		second_tick.emit()
	_update_calendar()


func get_day_progress() -> float:
	return fmod(game_seconds, SECONDS_PER_GAME_DAY) / SECONDS_PER_GAME_DAY


func _update_calendar() -> void:
	var day_index := int(game_seconds / SECONDS_PER_GAME_DAY)
	if day_index != _last_day_index:
		_last_day_index = day_index
		game_day = day_index + 1
		day_changed.emit(game_day)
	var week_index := int((game_day - 1) / 7.0)
	if week_index != _last_week_index:
		_last_week_index = week_index
		game_week = week_index + 1
		week_changed.emit(game_week)


func to_save_dict() -> Dictionary:
	return {
		"game_seconds": game_seconds,
		"game_day": game_day,
		"game_week": game_week,
		"_last_day_index": _last_day_index,
		"_last_week_index": _last_week_index,
	}


func from_save_dict(data: Dictionary) -> void:
	game_seconds = float(data.get("game_seconds", 0.0))
	game_day = int(data.get("game_day", 1))
	game_week = int(data.get("game_week", 1))
	_last_day_index = int(data.get("_last_day_index", 0))
	_last_week_index = int(data.get("_last_week_index", 0))
