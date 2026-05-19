extends Node

signal career_updated

const CAR_UPGRADES: Dictionary = {
	0: {"name": "Эконом", "cost": 0, "payout_mult": 1.0, "premium_chance": 0.1},
	1: {"name": "Комфорт", "cost": 15000, "payout_mult": 1.15, "premium_chance": 0.25},
	2: {"name": "Бизнес-класс", "cost": 40000, "payout_mult": 1.35, "premium_chance": 0.4},
}

const DISTRICTS: Dictionary = {
	"center": {"name": "Центр", "mult": 1.0, "min_level": 1},
	"port": {"name": "Порт", "mult": 1.12, "min_level": 1},
	"suburbs": {"name": "Спальник", "mult": 0.95, "min_level": 1},
	"industrial": {"name": "Промзона", "mult": 1.2, "min_level": 3},
	"airport": {"name": "Аэропорт", "mult": 1.25, "min_level": 2},
}

const PASSENGER_TYPES: Dictionary = {
	"econom": {"label": "Эконом", "payout_mult": 1.0, "time_mult": 1.0},
	"comfort": {"label": "Комфорт", "payout_mult": 1.2, "time_mult": 0.95},
	"corp": {"label": "Корпоратив", "payout_mult": 1.45, "time_mult": 1.1},
}

const LEVEL_THRESHOLDS: Array[int] = [0, 100, 250, 500, 1000, 2000]
const XP_PER_ACCEPTED_TRIP := 25
const XP_PER_DECLINED := -8
const XP_RATING_BONUS := 15

var rating: float = 3.5
var car_level: int = 0
var combo_streak: int = 0
var shifts_completed: int = 0
var xp: int = 0
var level: int = 1


func _ready() -> void:
	_recalc_level()


func to_save_dict() -> Dictionary:
	return {
		"rating": rating,
		"car_level": car_level,
		"combo_streak": combo_streak,
		"shifts_completed": shifts_completed,
		"xp": xp,
		"level": level,
	}


func from_save_dict(data: Dictionary) -> void:
	rating = float(data.get("rating", 3.5))
	car_level = int(data.get("car_level", 0))
	combo_streak = int(data.get("combo_streak", 0))
	shifts_completed = int(data.get("shifts_completed", 0))
	xp = int(data.get("xp", 0))
	level = int(data.get("level", 1))
	_recalc_level()
	career_updated.emit()


func add_xp(amount: int) -> void:
	if amount == 0:
		return
	var old_level := level
	xp = maxi(0, xp + amount)
	_recalc_level()
	if level != old_level:
		career_updated.emit()
	else:
		career_updated.emit()


func _recalc_level() -> void:
	level = 1
	for i in range(LEVEL_THRESHOLDS.size() - 1, 0, -1):
		if xp >= LEVEL_THRESHOLDS[i]:
			level = i + 1
			break


func get_xp_for_next_level() -> int:
	if level >= LEVEL_THRESHOLDS.size():
		return xp
	return LEVEL_THRESHOLDS[level]


func get_xp_progress_text() -> String:
	var next := get_xp_for_next_level()
	if level >= LEVEL_THRESHOLDS.size():
		return "Уровень %d · макс." % level
	var prev := LEVEL_THRESHOLDS[level - 1] if level > 0 else 0
	return "Уровень %d · %d/%d XP" % [level, xp - prev, next - prev]


func get_level_payout_mult() -> float:
	return 1.0 + (level - 1) * 0.05


func can_access_district(district_id: String) -> bool:
	var def: Dictionary = DISTRICTS.get(district_id, {})
	return level >= int(def.get("min_level", 1))


func get_accessible_districts() -> Array:
	var ids: Array = []
	for district_id in DISTRICTS.keys():
		if can_access_district(district_id):
			ids.append(district_id)
	return ids


func get_car_info() -> Dictionary:
	return CAR_UPGRADES.get(car_level, CAR_UPGRADES[0])


func can_upgrade_car() -> bool:
	var next := car_level + 1
	if not CAR_UPGRADES.has(next):
		return false
	return GameState.balance_rub >= int(CAR_UPGRADES[next].cost)


func upgrade_car() -> bool:
	var next := car_level + 1
	if not CAR_UPGRADES.has(next):
		return false
	var cost: int = int(CAR_UPGRADES[next].cost)
	if not EconomyManager.register_expense(cost, "Апгрейд авто: %s" % CAR_UPGRADES[next].name, "taxi"):
		return false
	car_level = next
	career_updated.emit()
	return true


func adjust_rating(delta: float) -> void:
	rating = clampf(rating + delta, 1.0, 5.0)
	career_updated.emit()


func apply_shift_result(accepted: int, declined: int, events_delta: int) -> void:
	shifts_completed += 1
	var total := accepted + declined
	var accept_rate := 1.0 if total == 0 else float(accepted) / float(total)
	var delta := (accept_rate - 0.5) * 0.4
	if events_delta > 0:
		delta += 0.05
	elif events_delta < -500:
		delta -= 0.1
	rating = clampf(rating + delta, 1.0, 5.0)
	var xp_gain := accepted * XP_PER_ACCEPTED_TRIP + declined * XP_PER_DECLINED
	if rating >= 4.0:
		xp_gain += XP_RATING_BONUS
	add_xp(xp_gain)


func register_trip_complete(skipped: bool) -> void:
	if skipped:
		combo_streak = 0
	else:
		combo_streak += 1


func get_combo_bonus_mult() -> float:
	if combo_streak >= 3:
		return 1.1
	return 1.0


func is_rush_hour() -> bool:
	var p := TimeManager.get_day_progress()
	return p >= 0.35 and p <= 0.55 or p >= 0.75 and p <= 0.9


func get_rush_mult() -> float:
	return 1.15 if is_rush_hour() else 1.0


func get_rating_stars() -> String:
	var full := int(floor(rating))
	var half := 1 if rating - full >= 0.5 else 0
	var s := ""
	for i in range(full):
		s += "★"
	if half:
		s += "½"
	while s.length() < 5:
		s += "☆"
	return s
