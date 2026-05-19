extends Node

signal tax_updated
signal random_event(message: String, amount: int)
signal documents_updated

const INCOME_TAX_RATE := 0.13
const LATE_PAYMENT_PENALTY_RATE := 0.2
const PLAYER_TAX_ID := "VL-4821"
const TREASURY_NAME := "Казначейство Зелёного Домика"
const TAX_SERVICE_NAME := "Служба сбора VL, г. Солнышково"
var tax_owed: int = 0
var disclaimer_accepted: bool = false
var documents: Array[Dictionary] = []

const RANDOM_EVENTS: Array[Dictionary] = [
	{"id": "gibdd_fine", "message": "Штраф ДПС Солнышково", "amount": -500, "weight": 3},
	{"id": "tips", "message": "Щедрые чаевые", "amount": 200, "weight": 4},
	{"id": "breakdown", "message": "Поломка — ремонт", "amount": -800, "weight": 2},
]


func _ready() -> void:
	TimeManager.week_changed.connect(_on_week_changed)


func on_income(gross_amount: int) -> void:
	var reserve := int(ceil(gross_amount * INCOME_TAX_RATE))
	tax_owed += reserve
	if reserve > 0:
		add_accrual_document(reserve)
	tax_updated.emit()


func add_accrual_document(amount: int) -> void:
	var doc := {
		"id": _new_doc_id(),
		"type": "accrual",
		"title": "Уведомление о начислении",
		"amount": amount,
		"paid": false,
		"game_day": TimeManager.game_day,
		"payment_code": _generate_payment_code(),
		"lines": [
			"Получатель: %s" % TREASURY_NAME,
			"Служба: %s" % TAX_SERVICE_NAME,
			"Игровой ID: %s" % PLAYER_TAX_ID,
			"Сумма к уплате: %s ₽" % GameState.format_amount(amount),
			"Срок: до конца игровой недели",
		],
	}
	documents.insert(0, doc)
	documents_updated.emit()


func add_payment_receipt(amount: int, auto: bool = false) -> void:
	var doc := {
		"id": _new_doc_id(),
		"type": "receipt",
		"title": "Квитанция об оплате" if not auto else "Списание по неделе",
		"amount": amount,
		"paid": true,
		"game_day": TimeManager.game_day,
		"payment_code": _generate_payment_code(),
		"lines": [
			"Получатель: %s" % TREASURY_NAME,
			"Игровой ID: %s" % PLAYER_TAX_ID,
			"Оплачено: %s ₽" % GameState.format_amount(amount),
			"Статус: исполнено",
		],
	}
	documents.insert(0, doc)
	documents_updated.emit()


func get_documents() -> Array[Dictionary]:
	return documents


func get_tax_badge_text() -> String:
	if tax_owed <= 0:
		return "Налог: 0 ₽"
	return "Налог: %s ₽" % GameState.format_amount(tax_owed)


func get_tax_status_text() -> String:
	if tax_owed <= 0:
		return "Налог к оплате: 0 ₽"
	return "Налог к оплате: %s ₽" % GameState.format_amount(tax_owed)


func pay_tax_manual() -> bool:
	if tax_owed <= 0:
		return false
	var amount := tax_owed
	if not EconomyManager.register_expense(amount, "Оплата в Зелёный Домик", "tax"):
		return false
	tax_owed = 0
	add_payment_receipt(amount)
	_mark_accruals_paid()
	tax_updated.emit()
	return true


func try_pay_weekly_tax() -> Dictionary:
	var result := {"paid": 0, "penalty": 0, "remaining": tax_owed}
	if tax_owed <= 0:
		return result
	if GameState.balance_rub >= tax_owed:
		var amount := tax_owed
		EconomyManager.register_expense(amount, "Налог за неделю", "tax")
		tax_owed = 0
		add_payment_receipt(amount, true)
		_mark_accruals_paid()
		result.paid = amount
		result.remaining = 0
	else:
		var penalty := int(ceil(tax_owed * LATE_PAYMENT_PENALTY_RATE))
		tax_owed += penalty
		var partial := GameState.balance_rub
		if partial > 0:
			EconomyManager.register_expense(partial, "Частичная оплата налога", "tax")
			tax_owed -= partial
			add_payment_receipt(partial, true)
		result.paid = partial
		result.penalty = penalty
		result.remaining = tax_owed
	tax_updated.emit()
	return result


func mark_disclaimer_seen() -> void:
	disclaimer_accepted = true


func try_random_event() -> bool:
	if RANDOM_EVENTS.is_empty():
		return false
	var total_weight := 0
	for event in RANDOM_EVENTS:
		total_weight += int(event.get("weight", 1))
	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for event in RANDOM_EVENTS:
		cumulative += int(event.get("weight", 1))
		if roll > cumulative:
			continue
		_apply_random_event(event)
		return true
	return false


func _apply_random_event(event: Dictionary) -> void:
	var amount: int = event.get("amount", 0)
	var message: String = event.get("message", "Событие")
	if amount >= 0:
		EconomyManager.register_income(amount, message, "event")
	else:
		EconomyManager.register_expense(absi(amount), message, "event")
	random_event.emit(message, amount)


func _on_week_changed(_week: int) -> void:
	var payment := try_pay_weekly_tax()
	if payment.penalty > 0:
		random_event.emit(
			"Не хватило на налог — пеня +%s ₽" % GameState.format_amount(payment.penalty),
			-payment.penalty
		)


func _mark_accruals_paid() -> void:
	for doc in documents:
		if doc.get("type") == "accrual":
			doc["paid"] = true
	documents_updated.emit()


func _new_doc_id() -> String:
	return "VL-DOC-%d-%d" % [TimeManager.game_day, documents.size() + 1]


func _generate_payment_code() -> String:
	return "VL-%04d-%04d" % [TimeManager.game_day, randi_range(1000, 9999)]


func to_save_dict() -> Dictionary:
	return {
		"tax_owed": tax_owed,
		"disclaimer_accepted": disclaimer_accepted,
		"documents": documents.duplicate(true),
	}


func from_save_dict(data: Dictionary) -> void:
	tax_owed = int(data.get("tax_owed", 0))
	disclaimer_accepted = bool(data.get("disclaimer_accepted", false))
	documents.clear()
	for doc in data.get("documents", []):
		if doc is Dictionary:
			documents.append(doc)
	tax_updated.emit()
	documents_updated.emit()
