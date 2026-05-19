extends Node

signal career_updated

const CAR_UPGRADES: Dictionary = {
	0: {"name": "Эконом", "cost": 0, "payout_mult": 1.0, "premium_chance": 0.1},
	1: {"name": "Комфорт", "cost": 15000, "payout_mult": 1.15, "premium_chance": 0.25},
	2: {"name": "Бизнес-класс", "cost": 40000, "payout_mult": 1.35, "premium_chance": 0.4},
}

const DISTRICTS: Dictionary = {
	"center": {"name": "Центр", "mult": 1.0},
	"port": {"name": "Порт", "mult": 1.12},
	"industrial": {"name": "Промзона", "mult": 1.2},
	"suburbs": {"name": "Спальник", "mult": 0.95},
	"airport": {"name": "Аэропорт", "mult": 1.25},
}

const PASSENGER_TYPES: Dictionary = {
	"econom": {"label": "Эконом", "payout_mult": 1.0, "time_mult": 1.0},
	"comfort": {"label": "Комфорт", "payout_mult": 1.2, "time_mult": 0.95},
	"corp": {"label": "Корпоратив", "payout_mult": 1.45, "time_mult": 1.1},
}

var rating: float = 3.5
var car_level: int = 0
var combo_streak: int = 0
var shifts_completed: int = 0


func _ready() -> void:
	pass


func to_save_dict() -> Dictionary:
	return {
		"rating": rating,
		"car_level": car_level,
		"combo_streak": combo_streak,
		"shifts_completed": shifts_completed,
	}


func from_save_dict(data: Dictionary) -> void:
	rating = float(data.get("rating", 3.5))
	car_level = int(data.get("car_level", 0))
	combo_streak = int(data.get("combo_streak", 0))
	shifts_completed = int(data.get("shifts_completed", 0))
	career_updated.emit()


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
	career_updated.emit()


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
