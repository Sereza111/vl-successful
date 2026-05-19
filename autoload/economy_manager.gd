extends Node

signal expenses_updated

const PHONE_RENT_PER_MINUTE := 10
const PASSIVE_EXPENSES_ENABLED := true

var _seconds_since_phone_rent: int = 0


func _ready() -> void:
	TimeManager.second_tick.connect(_on_second_tick)
	TimeManager.day_changed.connect(_on_day_changed)


func register_income(amount: int, reason: String, category: String = "income") -> void:
	if amount <= 0:
		return
	GameState.add_money(amount)
	GameState.log_transaction(amount, reason, category, true)
	TaxManager.on_income(amount)


func register_expense(amount: int, reason: String, category: String = "expense") -> bool:
	if amount <= 0:
		return true
	if not GameState.try_spend(amount):
		return false
	GameState.log_transaction(amount, reason, category, false)
	expenses_updated.emit()
	return true


func get_today_expenses_text() -> String:
	var spent := GameState.today_expenses
	if spent <= 0:
		return "Сегодня расходов пока нет"
	return "Сегодня: −%s ₽ расходы" % GameState.format_amount(spent)


func _on_second_tick() -> void:
	if not PASSIVE_EXPENSES_ENABLED:
		return
	_seconds_since_phone_rent += 1
	if _seconds_since_phone_rent >= 60:
		_seconds_since_phone_rent = 0
		register_expense(PHONE_RENT_PER_MINUTE, "Аренда телефона", "passive")


func _on_day_changed(_day: int) -> void:
	GameState.reset_daily_totals()
	expenses_updated.emit()


func to_save_dict() -> Dictionary:
	return {"_seconds_since_phone_rent": _seconds_since_phone_rent}


func from_save_dict(data: Dictionary) -> void:
	_seconds_since_phone_rent = int(data.get("_seconds_since_phone_rent", 0))
