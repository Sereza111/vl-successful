extends Node

signal business_updated

const BUSINESS_OPEN_COST := 20000
const RETAIL_STARTER_ID := "retail_starter"

const BUSINESS_DEFS: Dictionary = {
	"retail_starter": {
		"name": "Магазин «Солнышко»",
		"sector": "retail",
		"unlock_license": "ip_retail",
		"open_cost": 0,
		"base_income_per_day": 800,
		"passive_expense_per_day": 200,
		"upgrade_levels": [
			{"name": "Витрина", "cost": 5000, "income_mult": 1.25, "expense_mult": 1.05},
			{"name": "Склад", "cost": 12000, "income_mult": 1.5, "expense_mult": 1.1},
			{"name": "Вторая точка", "cost": 25000, "income_mult": 2.0, "expense_mult": 1.2},
		],
	},
	"oil_prom": {
		"name": "Нефтяная вышка VL",
		"sector": "oil",
		"unlock_license": "oil_gas",
		"open_cost": 80000,
		"base_income_per_day": 4500,
		"passive_expense_per_day": 1200,
		"upgrade_levels": [
			{"name": "Насосная", "cost": 30000, "income_mult": 1.3, "expense_mult": 1.08},
			{"name": "Резервуар", "cost": 55000, "income_mult": 1.6, "expense_mult": 1.12},
		],
	},
	"gas_prom": {
		"name": "Газовый узел VL",
		"sector": "gas",
		"unlock_license": "oil_gas",
		"open_cost": 65000,
		"base_income_per_day": 3800,
		"passive_expense_per_day": 1000,
		"upgrade_levels": [
			{"name": "Компрессор", "cost": 28000, "income_mult": 1.28, "expense_mult": 1.07},
			{"name": "Магистраль", "cost": 50000, "income_mult": 1.55, "expense_mult": 1.1},
		],
	},
	"ads_owned": {
		"name": "Агентство VL Media",
		"sector": "ads_owned",
		"unlock_license": "advertising_agency",
		"open_cost": 40000,
		"base_income_per_day": 1500,
		"passive_expense_per_day": 400,
		"upgrade_levels": [
			{"name": "Билборды", "cost": 20000, "income_mult": 1.35, "expense_mult": 1.05},
			{"name": "Digital-отдел", "cost": 35000, "income_mult": 1.7, "expense_mult": 1.1},
		],
	},
}

## id -> { level, demand_mult }
var owned_businesses: Dictionary = {}
var selected_business_id: String = ""


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)
	AdManager.campaigns_changed.connect(_on_campaigns_changed)


func to_save_dict() -> Dictionary:
	return {"owned": owned_businesses.duplicate(true)}


func from_save_dict(data: Dictionary) -> void:
	owned_businesses = data.get("owned", {}).duplicate(true)
	business_updated.emit()


func get_definition(business_id: String) -> Dictionary:
	return BUSINESS_DEFS.get(business_id, {})


func owns_business(business_id: String) -> bool:
	return owned_businesses.has(business_id)


func can_open(business_id: String) -> bool:
	if owns_business(business_id):
		return false
	var def: Dictionary = get_definition(business_id)
	if def.is_empty():
		return false
	var lic: String = def.get("unlock_license", "")
	if lic != "" and not LicenseManager.has_license(lic):
		return false
	var cost: int = int(def.get("open_cost", 0))
	if business_id == RETAIL_STARTER_ID and ProgressionManager.business_opened:
		return false
	return GameState.balance_rub >= cost


func open_business(business_id: String) -> bool:
	if not can_open(business_id):
		return false
	var def: Dictionary = get_definition(business_id)
	var cost: int = int(def.get("open_cost", 0))
	if cost > 0:
		if not EconomyManager.register_expense(
			cost, "Открытие: %s" % def.get("name", business_id), "business"
		):
			return false
	owned_businesses[business_id] = {"level": 0, "demand_mult": 1.0}
	business_updated.emit()
	return true


func open_retail_with_ip() -> bool:
	if not ProgressionManager.business_opened:
		return false
	if owns_business(RETAIL_STARTER_ID):
		return true
	owned_businesses[RETAIL_STARTER_ID] = {"level": 0, "demand_mult": 1.0}
	business_updated.emit()
	return true


func get_level(business_id: String) -> int:
	if not owns_business(business_id):
		return -1
	return int(owned_businesses[business_id].get("level", 0))


func can_upgrade(business_id: String) -> bool:
	if not owns_business(business_id):
		return false
	var def: Dictionary = get_definition(business_id)
	var levels: Array = def.get("upgrade_levels", [])
	var lvl := get_level(business_id)
	return lvl < levels.size()


func get_upgrade_cost(business_id: String) -> int:
	var def: Dictionary = get_definition(business_id)
	var levels: Array = def.get("upgrade_levels", [])
	var lvl := get_level(business_id)
	if lvl >= levels.size():
		return 0
	return int(levels[lvl].get("cost", 0))


func upgrade_business(business_id: String) -> bool:
	if not can_upgrade(business_id):
		return false
	var cost := get_upgrade_cost(business_id)
	var def: Dictionary = get_definition(business_id)
	var levels: Array = def.get("upgrade_levels", [])
	var lvl := get_level(business_id)
	var up_name: String = levels[lvl].get("name", "Улучшение")
	if not EconomyManager.register_expense(
		cost, "Улучшение: %s — %s" % [def.get("name", ""), up_name], "business"
	):
		return false
	owned_businesses[business_id]["level"] = lvl + 1
	business_updated.emit()
	return true


func get_demand_mult(business_id: String) -> float:
	if not owns_business(business_id):
		return 1.0
	return float(owned_businesses[business_id].get("demand_mult", 1.0))


func get_daily_net(business_id: String) -> int:
	if not owns_business(business_id):
		return 0
	var def: Dictionary = get_definition(business_id)
	var lvl := get_level(business_id)
	var income := float(def.get("base_income_per_day", 0))
	var expense := float(def.get("passive_expense_per_day", 0))
	var levels: Array = def.get("upgrade_levels", [])
	for i in range(mini(lvl, levels.size())):
		income *= float(levels[i].get("income_mult", 1.0))
		expense *= float(levels[i].get("expense_mult", 1.0))
	var mult := get_demand_mult(business_id)
	return int(round((income - expense) * mult))


func get_owned_ids() -> Array:
	var ids: Array = []
	for key in owned_businesses.keys():
		ids.append(key)
	return ids


func get_openable_ids() -> Array:
	var ids: Array = []
	for key in BUSINESS_DEFS.keys():
		if not owns_business(key) and can_open(key):
			ids.append(key)
	return ids


func _on_day_changed(_day: int) -> void:
	for business_id in get_owned_ids():
		var net := get_daily_net(business_id)
		if net >= 0:
			EconomyManager.register_income(
				net, "Прибыль: %s" % get_definition(business_id).get("name", business_id), "business"
			)
		else:
			EconomyManager.register_expense(
				absi(net), "Убыток: %s" % get_definition(business_id).get("name", business_id), "business"
			)
		_check_license_fine(business_id)


func _check_license_fine(business_id: String) -> void:
	var def: Dictionary = get_definition(business_id)
	var sector: String = def.get("sector", "")
	if sector in ["oil", "gas"] and not LicenseManager.has_license("oil_gas"):
		EconomyManager.register_expense(2000, "Штраф: нет разрешения нефть/газ", "fine")


func _on_campaigns_changed() -> void:
	for business_id in get_owned_ids():
		owned_businesses[business_id]["demand_mult"] = AdManager.get_demand_multiplier(business_id)
	business_updated.emit()
