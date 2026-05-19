extends Node

const SHIFT_DURATION_SEC := 300.0
const ORDER_MIN_INTERVAL := 8.0
const ORDER_MAX_INTERVAL := 15.0
const OFFER_TIMEOUT_SEC := 12.0
const SHIFT_FUEL_MAX := 100

const ORDER_TEMPLATES: Array[Dictionary] = [
	{
		"title": "Центр → Аэропорт",
		"from_street": "ул. Солнечная",
		"to_street": "Аэропорт VL",
		"payout": 1400,
		"fuel": 18,
		"distance": 22.0,
		"risk": "Пробки",
	},
	{
		"title": "Вокзал → Университет",
		"from_street": "Вокзал Солнышково",
		"to_street": "ул. Студенческая",
		"payout": 650,
		"fuel": 8,
		"distance": 7.5,
		"risk": "Низкий",
	},
	{
		"title": "ТЦ → Спальный район",
		"from_street": "ТЦ «Орион»",
		"to_street": "ул. Тихая",
		"payout": 480,
		"fuel": 12,
		"distance": 11.0,
		"risk": "Средний",
	},
	{
		"title": "Клуб → Ночной район",
		"from_street": "Клуб «Неон»",
		"to_street": "ул. Ночная",
		"payout": 900,
		"fuel": 10,
		"distance": 9.0,
		"risk": "Пьяный клиент",
	},
	{
		"title": "Офисный квартал",
		"from_street": "БЦ «Вектор»",
		"to_street": "ул. Деловая",
		"payout": 350,
		"fuel": 5,
		"distance": 3.0,
		"risk": "Низкий",
	},
	{
		"title": "Дальний заказ",
		"from_street": "ул. Крайняя",
		"to_street": "пос. Зелёный",
		"payout": 2100,
		"fuel": 28,
		"distance": 35.0,
		"risk": "Мало топлива",
	},
]

var last_shift_result: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func create_random_order() -> Dictionary:
	var template: Dictionary = ORDER_TEMPLATES[_rng.randi_range(0, ORDER_TEMPLATES.size() - 1)]
	var order := template.duplicate(true)
	if not order.has("from_street"):
		order["from_street"] = "ул. Солнечная"
	if not order.has("to_street"):
		order["to_street"] = "ул. Центральная"
	_enrich_order(order)
	return order


func _enrich_order(order: Dictionary) -> void:
	var district_ids: Array = TaxiCareerManager.DISTRICTS.keys()
	var district_id: String = district_ids[_rng.randi_range(0, district_ids.size() - 1)]
	var district: Dictionary = TaxiCareerManager.DISTRICTS[district_id]
	order["district_id"] = district_id
	order["district_name"] = district.get("name", district_id)

	var car_info: Dictionary = TaxiCareerManager.get_car_info()
	var premium_chance: float = float(car_info.get("premium_chance", 0.1))
	premium_chance += (TaxiCareerManager.rating - 3.0) * 0.05
	var ptype := "econom"
	if _rng.randf() < premium_chance:
		ptype = "corp" if _rng.randf() < 0.4 else "comfort"
	var pdef: Dictionary = TaxiCareerManager.PASSENGER_TYPES.get(ptype, {})
	order["passenger_type"] = ptype
	order["passenger_label"] = pdef.get("label", ptype)

	var payout_mult := float(car_info.get("payout_mult", 1.0))
	payout_mult *= float(pdef.get("payout_mult", 1.0))
	payout_mult *= float(district.get("mult", 1.0))
	payout_mult *= TaxiCareerManager.get_combo_bonus_mult()
	payout_mult *= TaxiCareerManager.get_rush_mult()
	order["payout"] = int(round(int(order.get("payout", 0)) * payout_mult))

	var time_mult: float = float(pdef.get("time_mult", 1.0))
	order["distance"] = float(order.get("distance", 5.0)) * time_mult


func get_random_order_interval() -> float:
	return _rng.randf_range(ORDER_MIN_INTERVAL, ORDER_MAX_INTERVAL)


func set_shift_result(result: Dictionary) -> void:
	last_shift_result = result.duplicate(true)


func clear_shift_result() -> void:
	last_shift_result = {}
