extends Node

signal loans_updated

const LOAN_TYPES: Dictionary = {
	"consumer": {
		"name": "Потребительский",
		"max_amount": 30000,
		"interest_per_day": 0.002,
		"term_days": 14,
		"late_penalty": 500,
	},
	"business": {
		"name": "Бизнес-кредит",
		"max_amount": 100000,
		"interest_per_day": 0.0015,
		"term_days": 30,
		"late_penalty": 1500,
		"requires_ip": true,
	},
	"emergency": {
		"name": "Экстренный займ",
		"max_amount": 5000,
		"interest_per_day": 0.005,
		"term_days": 7,
		"late_penalty": 300,
	},
}

## { id, type, principal, interest_rate, due_day, overdue_days }
var active_loans: Array[Dictionary] = []
var _next_id: int = 1


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)


func to_save_dict() -> Dictionary:
	return {"active_loans": active_loans.duplicate(true), "_next_id": _next_id}


func from_save_dict(data: Dictionary) -> void:
	active_loans.clear()
	for entry in data.get("active_loans", []):
		if entry is Dictionary:
			active_loans.append(entry)
	_next_id = int(data.get("_next_id", 1))
	loans_updated.emit()


func can_take_loan(loan_type: String, amount: int) -> bool:
	if not LOAN_TYPES.has(loan_type):
		return false
	var def: Dictionary = LOAN_TYPES[loan_type]
	if def.get("requires_ip", false) and not ProgressionManager.business_opened:
		return false
	return amount > 0 and amount <= int(def.get("max_amount", 0))


func take_loan(loan_type: String, amount: int) -> bool:
	if not can_take_loan(loan_type, amount):
		return false
	var def: Dictionary = LOAN_TYPES[loan_type]
	var term: int = int(def.get("term_days", 14))
	var loan := {
		"id": _next_id,
		"type": loan_type,
		"principal": amount,
		"interest_rate": float(def.get("interest_per_day", 0.002)),
		"due_day": TimeManager.game_day + term,
		"overdue_days": 0,
	}
	_next_id += 1
	active_loans.append(loan)
	EconomyManager.register_income(amount, "Кредит: %s" % def.get("name", loan_type), "loan")
	loans_updated.emit()
	return true


func pay_loan(loan_id: int, amount: int = -1) -> bool:
	var idx := _find_loan_index(loan_id)
	if idx < 0:
		return false
	var loan: Dictionary = active_loans[idx]
	var principal: int = int(loan.get("principal", 0))
	if principal <= 0:
		return false
	var pay_amount := principal if amount < 0 else mini(amount, principal)
	if not EconomyManager.register_expense(pay_amount, "Погашение кредита #%d" % loan_id, "loan"):
		return false
	loan["principal"] = principal - pay_amount
	if loan["principal"] <= 0:
		active_loans.remove_at(idx)
	loans_updated.emit()
	return true


func take_emergency_loan() -> bool:
	return take_loan("emergency", 5000)


func get_total_debt() -> int:
	var total := 0
	for loan in active_loans:
		total += int(loan.get("principal", 0))
	return total


func get_loans_summary() -> String:
	if active_loans.is_empty():
		return "Кредитов нет"
	var lines: PackedStringArray = []
	for loan in active_loans:
		var def: Dictionary = LOAN_TYPES.get(loan.get("type", ""), {})
		lines.append(
			"%s: %s ₽ до дня %d"
			% [
				def.get("name", "Кредит"),
				GameState.format_amount(int(loan.get("principal", 0))),
				int(loan.get("due_day", 0)),
			]
		)
	return "\n".join(lines)


func _on_day_changed(_day: int) -> void:
	var to_remove: Array[int] = []
	for i in range(active_loans.size()):
		var loan: Dictionary = active_loans[i]
		var principal: int = int(loan.get("principal", 0))
		if principal <= 0:
			to_remove.append(i)
			continue
		var interest := maxi(1, int(ceil(principal * float(loan.get("interest_rate", 0.002)))))
		loan["principal"] = principal + interest
		if TimeManager.game_day > int(loan.get("due_day", 0)):
			loan["overdue_days"] = int(loan.get("overdue_days", 0)) + 1
			var def: Dictionary = LOAN_TYPES.get(loan.get("type", ""), {})
			var penalty: int = int(def.get("late_penalty", 500))
			EconomyManager.register_expense(penalty, "Просрочка кредита #%d" % loan.get("id", 0), "loan")
	for i in range(to_remove.size() - 1, -1, -1):
		active_loans.remove_at(to_remove[i])
	loans_updated.emit()


func _find_loan_index(loan_id: int) -> int:
	for i in range(active_loans.size()):
		if int(active_loans[i].get("id", -1)) == loan_id:
			return i
	return -1
