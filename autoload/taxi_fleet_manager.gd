extends Node

signal fleet_updated

const DRIVER_DEFS: Array[Dictionary] = [
	{"name": "Водитель Алексей", "hire_cost": 8000, "salary_per_day": 400, "income_share": 0.12},
	{"name": "Водитель Марина", "hire_cost": 12000, "salary_per_day": 550, "income_share": 0.15},
	{"name": "Водитель Олег", "hire_cost": 18000, "salary_per_day": 700, "income_share": 0.18},
]

var hired_drivers: Array[Dictionary] = []


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)


func to_save_dict() -> Dictionary:
	return {"hired": hired_drivers.duplicate(true)}


func from_save_dict(data: Dictionary) -> void:
	hired_drivers.clear()
	for d in data.get("hired", []):
		if d is Dictionary:
			hired_drivers.append(d)
	fleet_updated.emit()


func can_hire(index: int) -> bool:
	if index < 0 or index >= DRIVER_DEFS.size():
		return false
	if hired_drivers.size() >= 3:
		return false
	for h in hired_drivers:
		if int(h.get("def_index", -1)) == index:
			return false
	return GameState.balance_rub >= int(DRIVER_DEFS[index].get("hire_cost", 0))


func hire_driver(index: int) -> bool:
	if not can_hire(index):
		return false
	var def: Dictionary = DRIVER_DEFS[index]
	if not EconomyManager.register_expense(
		int(def.get("hire_cost", 0)), "Найм: %s" % def.get("name", ""), "fleet"
	):
		return false
	hired_drivers.append({"def_index": index, "hired_day": TimeManager.game_day})
	fleet_updated.emit()
	return true


func get_available_slots() -> int:
	return 3 - hired_drivers.size()


func get_summary() -> String:
	if hired_drivers.is_empty():
		return "Нет водителей в автопарке"
	var lines: PackedStringArray = []
	for h in hired_drivers:
		var idx: int = int(h.get("def_index", 0))
		var def: Dictionary = DRIVER_DEFS[idx]
		lines.append(def.get("name", "Водитель"))
	return "Автопарк: " + ", ".join(lines)


func _on_day_changed(_day: int) -> void:
	if hired_drivers.is_empty():
		return
	if not ProgressionManager.business_opened:
		return
	for h in hired_drivers:
		var idx: int = int(h.get("def_index", 0))
		var def: Dictionary = DRIVER_DEFS[idx]
		var salary: int = int(def.get("salary_per_day", 0))
		EconomyManager.register_expense(salary, "Зарплата: %s" % def.get("name", ""), "fleet")
		var base_income := randi_range(800, 2200)
		var share := int(round(base_income * float(def.get("income_share", 0.1))))
		if share > 0:
			EconomyManager.register_income(share, "Доля смены: %s" % def.get("name", ""), "fleet")
	fleet_updated.emit()
