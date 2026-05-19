extends Node

signal property_updated

const PROPERTIES: Array[Dictionary] = [
	{
		"id": "apt_sunny",
		"name": "Квартира «Солнечная»",
		"cost": 120000,
		"rent_per_week": 3500,
	},
	{
		"id": "apt_port",
		"name": "Студия у порта",
		"cost": 85000,
		"rent_per_week": 2200,
	},
]

var owned_ids: Array[String] = []


func _ready() -> void:
	TimeManager.week_changed.connect(_on_week_changed)


func to_save_dict() -> Dictionary:
	return {"owned": owned_ids.duplicate()}


func from_save_dict(data: Dictionary) -> void:
	owned_ids.clear()
	for id in data.get("owned", []):
		owned_ids.append(str(id))
	property_updated.emit()


func owns(property_id: String) -> bool:
	return property_id in owned_ids


func can_buy(property_id: String) -> bool:
	if owns(property_id):
		return false
	for p in PROPERTIES:
		if p.get("id", "") == property_id:
			return GameState.balance_rub >= int(p.get("cost", 0))
	return false


func buy_property(property_id: String) -> bool:
	if not can_buy(property_id):
		return false
	for p in PROPERTIES:
		if p.get("id", "") == property_id:
			if EconomyManager.register_expense(
				int(p.get("cost", 0)), "Покупка: %s" % p.get("name", ""), "property"
			):
				owned_ids.append(property_id)
				property_updated.emit()
				return true
	return false


func get_definition(property_id: String) -> Dictionary:
	for p in PROPERTIES:
		if p.get("id", "") == property_id:
			return p
	return {}


func get_weekly_income() -> int:
	var total := 0
	for pid in owned_ids:
		for p in PROPERTIES:
			if p.get("id", "") == pid:
				total += int(p.get("rent_per_week", 0))
	return total


func _on_week_changed(_week: int) -> void:
	var income := get_weekly_income()
	if income > 0:
		EconomyManager.register_income(income, "Аренда недвижимости", "property")
	property_updated.emit()
