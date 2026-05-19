extends Node

signal toast_requested(message: String, is_income: bool)

var _pending_toasts: Array[Dictionary] = []


func _ready() -> void:
	GameState.cashflow_updated.connect(_on_cashflow)


func _on_cashflow() -> void:
	if GameState.cashflow_log.is_empty():
		return
	var entry: Dictionary = GameState.cashflow_log[0]
	var is_income: bool = entry.get("is_income", false)
	var amount: int = absi(int(entry.get("amount", 0)))
	if amount <= 0:
		return
	var amount_sign := "+" if is_income else "−"
	var msg := "%s%s ₽ · %s" % [amount_sign, GameState.format_amount(amount), entry.get("reason", "")]
	toast_requested.emit(msg, is_income)


func pop_toast() -> Dictionary:
	if _pending_toasts.is_empty():
		return {}
	return _pending_toasts.pop_front()
