extends Node

signal expenses_updated

func _ready() -> void:
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


func _on_day_changed(_day: int) -> void:
	GameState.reset_daily_totals()
	expenses_updated.emit()


func to_save_dict() -> Dictionary:
	return {}


func from_save_dict(_data: Dictionary) -> void:
	pass
