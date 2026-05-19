extends Node

signal campaigns_changed

const NPC_CAMPAIGNS: Dictionary = {
	"local": {"name": "Локальная", "cost": 3000, "boost": 1.15, "days": 3},
	"city": {"name": "По городу", "cost": 8000, "boost": 1.25, "days": 5},
	"industrial": {"name": "Промзона", "cost": 15000, "boost": 1.45, "days": 7},
}

const OWNED_DISCOUNT := 0.65

var own_agency_opened: bool = false

## business_id -> { boost, expires_day, type }
var active_campaigns: Dictionary = {}


func _ready() -> void:
	TimeManager.day_changed.connect(_on_day_changed)


func to_save_dict() -> Dictionary:
	return {
		"own_agency": own_agency_opened,
		"campaigns": active_campaigns.duplicate(true),
	}


func from_save_dict(data: Dictionary) -> void:
	own_agency_opened = bool(data.get("own_agency", false))
	active_campaigns = data.get("campaigns", {}).duplicate(true)
	campaigns_changed.emit()


func has_own_agency() -> bool:
	return own_agency_opened or BusinessManager.owns_business("ads_owned")


func get_campaign_cost(campaign_type: String) -> int:
	var base: int = int(NPC_CAMPAIGNS.get(campaign_type, {}).get("cost", 0))
	if has_own_agency():
		return int(round(base * OWNED_DISCOUNT))
	return base


func run_campaign(business_id: String, campaign_type: String) -> bool:
	if not BusinessManager.owns_business(business_id):
		return false
	if not NPC_CAMPAIGNS.has(campaign_type):
		return false
	var def: Dictionary = NPC_CAMPAIGNS[campaign_type]
	var cost := get_campaign_cost(campaign_type)
	var cname: String = def.get("name", campaign_type)
	if not EconomyManager.register_expense(
		cost, "Реклама (%s): %s" % [cname, business_id], "ads"
	):
		return false
	var days: int = int(def.get("days", 3))
	active_campaigns[business_id] = {
		"boost": float(def.get("boost", 1.1)),
		"expires_day": TimeManager.game_day + days,
		"type": campaign_type,
	}
	BusinessManager.owned_businesses[business_id]["demand_mult"] = get_demand_multiplier(business_id)
	campaigns_changed.emit()
	return true


func get_demand_multiplier(business_id: String) -> float:
	if not active_campaigns.has(business_id):
		return 1.0
	var camp: Dictionary = active_campaigns[business_id]
	if TimeManager.game_day > int(camp.get("expires_day", 0)):
		return 1.0
	return float(camp.get("boost", 1.0))


func get_campaign_status(business_id: String) -> String:
	if not active_campaigns.has(business_id):
		return "Нет активной кампании"
	var camp: Dictionary = active_campaigns[business_id]
	var expires_day: int = int(camp.get("expires_day", 0))
	if TimeManager.game_day > expires_day:
		return "Кампания завершена"
	return "Буст ×%.2f до дня %d" % [float(camp.get("boost", 1.0)), expires_day]


func _on_day_changed(_day: int) -> void:
	var changed := false
	for business_id in active_campaigns.keys():
		var camp: Dictionary = active_campaigns[business_id]
		if TimeManager.game_day > int(camp.get("expires_day", 0)):
			active_campaigns.erase(business_id)
			changed = true
	if changed:
		campaigns_changed.emit()
