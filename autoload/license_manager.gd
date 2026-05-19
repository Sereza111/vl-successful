extends Node

signal licenses_updated

const LICENSE_DEFS: Dictionary = {
	"ip_retail": {
		"name": "Лицензия ИП (розница)",
		"cost": 5000,
		"duration_days": 0,
		"description": "Право открыть ИП и торговую точку.",
	},
	"transport": {
		"name": "Лицензия перевозок",
		"cost": 3000,
		"duration_days": 14,
		"description": "Такси и курьер в городе Солнышково.",
	},
	"oil_gas": {
		"name": "Разрешение нефть/газ",
		"cost": 25000,
		"duration_days": 21,
		"description": "Добыча и переработка в промзоне.",
	},
	"advertising_agency": {
		"name": "Лицензия рекламного агентства",
		"cost": 15000,
		"duration_days": 30,
		"description": "Своё агентство VL Media.",
	},
	"exchange_broker": {
		"name": "Лицензия брокера VL-Биржи",
		"cost": 12000,
		"duration_days": 30,
		"description": "Покупка и продажа бумаг VL-OIL, VL-GAS, VL-GREEN.",
	},
}

## id -> { purchased_day, expires_day } ; duration_days 0 = permanent
var active_licenses: Dictionary = {}


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)


func to_save_dict() -> Dictionary:
	return {"active": active_licenses.duplicate(true)}


func from_save_dict(data: Dictionary) -> void:
	active_licenses = data.get("active", {}).duplicate(true)
	licenses_updated.emit()


func has_license(license_id: String) -> bool:
	if not active_licenses.has(license_id):
		return false
	var entry: Dictionary = active_licenses[license_id]
	var expires: int = int(entry.get("expires_day", 0))
	if expires <= 0:
		return true
	return TimeManager.game_day <= expires


func get_license_info(license_id: String) -> Dictionary:
	return LICENSE_DEFS.get(license_id, {})


func get_all_license_ids() -> Array:
	var ids: Array = []
	for key in LICENSE_DEFS.keys():
		ids.append(key)
	return ids


func can_purchase(license_id: String) -> bool:
	if not LICENSE_DEFS.has(license_id):
		return false
	if has_license(license_id):
		return false
	var cost: int = int(LICENSE_DEFS[license_id].get("cost", 0))
	return GameState.balance_rub >= cost


func purchase_license(license_id: String) -> bool:
	if not can_purchase(license_id):
		return false
	var def: Dictionary = LICENSE_DEFS[license_id]
	var cost: int = int(def.get("cost", 0))
	var reason: String = "Лицензия: %s" % def.get("name", license_id)
	if not EconomyManager.register_expense(cost, reason, "license"):
		return false
	var duration: int = int(def.get("duration_days", 0))
	var expires := 0
	if duration > 0:
		expires = TimeManager.game_day + duration
	active_licenses[license_id] = {
		"purchased_day": TimeManager.game_day,
		"expires_day": expires,
	}
	licenses_updated.emit()
	if license_id == "ip_retail":
		ProgressionManager.has_business_license = true
		ProgressionManager.progression_updated.emit()
	return true


func get_status_text(license_id: String) -> String:
	if not LICENSE_DEFS.has(license_id):
		return "—"
	if has_license(license_id):
		var entry: Dictionary = active_licenses[license_id]
		var expires_day_val: int = int(entry.get("expires_day", 0))
		if expires_day_val <= 0:
			return "Активна (бессрочно)"
		var days_left := expires_day_val - TimeManager.game_day
		return "Активна до дня %d (%d дн.)" % [expires_day_val, maxi(0, days_left)]
	var cost: int = int(LICENSE_DEFS[license_id].get("cost", 0))
	return "Купить за %s ₽" % GameState.format_amount(cost)


func get_expired_licenses() -> Array[String]:
	var expired: Array[String] = []
	for license_id in active_licenses.keys():
		if not has_license(license_id):
			expired.append(license_id)
	return expired


func _on_day_changed(_day: int) -> void:
	var had_expired := false
	for license_id in get_expired_licenses():
		active_licenses.erase(license_id)
		had_expired = true
	if had_expired:
		licenses_updated.emit()
