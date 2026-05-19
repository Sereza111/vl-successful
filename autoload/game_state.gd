extends Node

signal balance_changed
signal cashflow_updated

## TODO: active_card_id + per-card balances, e.g. { "rub_main": 12500, "usd_card": 0 }
var balance_rub: int = 12500
var today_income: int = 0
var today_expenses: int = 0
var cashflow_log: Array[Dictionary] = []

const MAX_LOG_ENTRIES := 50


func get_formatted_balance() -> String:
	return "%s ₽" % format_amount(balance_rub)


func format_amount(value: int) -> String:
	return _format_thousands(value)


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	balance_rub += amount
	balance_changed.emit()


func try_spend(amount: int) -> bool:
	if amount <= 0 or balance_rub < amount:
		return false
	balance_rub -= amount
	balance_changed.emit()
	return true


func log_transaction(amount: int, reason: String, category: String, is_income: bool) -> void:
	if is_income:
		today_income += amount
	else:
		today_expenses += amount
	cashflow_log.insert(
		0,
		{
			"amount": amount if is_income else -amount,
			"reason": reason,
			"category": category,
			"game_day": TimeManager.game_day,
			"is_income": is_income,
		}
	)
	if cashflow_log.size() > MAX_LOG_ENTRIES:
		cashflow_log.resize(MAX_LOG_ENTRIES)
	cashflow_updated.emit()


func reset_daily_totals() -> void:
	today_income = 0
	today_expenses = 0
	cashflow_updated.emit()


func to_save_dict() -> Dictionary:
	return {
		"balance_rub": balance_rub,
		"today_income": today_income,
		"today_expenses": today_expenses,
		"cashflow_log": cashflow_log.duplicate(true),
	}


func from_save_dict(data: Dictionary) -> void:
	balance_rub = int(data.get("balance_rub", 12500))
	today_income = int(data.get("today_income", 0))
	today_expenses = int(data.get("today_expenses", 0))
	var log_data = data.get("cashflow_log", [])
	cashflow_log.clear()
	for entry in log_data:
		if entry is Dictionary:
			cashflow_log.append(entry)
	balance_changed.emit()
	cashflow_updated.emit()


func _format_thousands(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var parts: PackedStringArray = []
	while digits.length() > 3:
		parts.insert(0, digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.insert(0, digits)
	var formatted := " ".join(parts)
	return "-%s" % formatted if negative else formatted
