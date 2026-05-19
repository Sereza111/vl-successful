extends Node

signal bankruptcy_triggered
signal expenses_processed

const FOOD_PER_DAY := 200
const RENT_AMOUNT := 1500
const RENT_EVERY_DAYS := 7
const PHONE_PER_MINUTE := 10
const PHONE_TICK_SECONDS := 60

var is_bankrupt: bool = false
var _phone_accumulator: int = 0


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.second_tick.connect(_on_second_tick)


func to_save_dict() -> Dictionary:
	return {"is_bankrupt": is_bankrupt, "_phone_accumulator": _phone_accumulator}


func from_save_dict(data: Dictionary) -> void:
	is_bankrupt = bool(data.get("is_bankrupt", false))
	_phone_accumulator = int(data.get("_phone_accumulator", 0))


func _on_day_changed(day: int) -> void:
	_charge_food()
	if day % RENT_EVERY_DAYS == 0:
		_charge_rent()
	expenses_processed.emit()
	_check_bankruptcy()


func _on_second_tick() -> void:
	_phone_accumulator += 1
	if _phone_accumulator >= PHONE_TICK_SECONDS:
		_phone_accumulator = 0
		if EconomyManager.register_expense(PHONE_PER_MINUTE, "Связь (телефон)", "passive"):
			_check_bankruptcy()


func _charge_food() -> void:
	if not EconomyManager.register_expense(FOOD_PER_DAY, "Еда", "living"):
		_check_bankruptcy()


func _charge_rent() -> void:
	if not EconomyManager.register_expense(RENT_AMOUNT, "Аренда жилья", "living"):
		_check_bankruptcy()


func _check_bankruptcy() -> void:
	if GameState.balance_rub <= 0 and not is_bankrupt:
		is_bankrupt = true
		bankruptcy_triggered.emit()


func clear_bankruptcy() -> void:
	is_bankrupt = false


func get_upcoming_expenses_text() -> String:
	return "Еда %s/день · аренда %s/%d дн." % [
		GameState.format_amount(FOOD_PER_DAY),
		GameState.format_amount(RENT_AMOUNT),
		RENT_EVERY_DAYS,
	]
