extends Node

signal market_updated
signal market_news(message: String)

const INSTRUMENTS: Dictionary = {
	"VL-OIL": {"name": "VL Нефть", "base_price": 120.0, "volatility": 0.04},
	"VL-GAS": {"name": "VL Газ", "base_price": 85.0, "volatility": 0.035},
	"VL-GREEN": {"name": "VL Зелёная энергия", "base_price": 42.0, "volatility": 0.05},
}

const NEWS_LINES: Array[String] = [
	"В порту задержка поставок — нефть растёт",
	"Газовый узел на профилактике",
	"Инвесторы смотрят на VL-GREEN",
	"Спрос на топливо стабилен",
	"Промзона увеличила закупки",
]

var prices: Dictionary = {}
var holdings: Dictionary = {}
var last_news: String = ""
var _tick_accumulator: float = 0.0


func _ready() -> void:
	_reset_prices()
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.second_tick.connect(_on_second_tick)


func to_save_dict() -> Dictionary:
	return {
		"prices": prices.duplicate(true),
		"holdings": holdings.duplicate(true),
		"last_news": last_news,
	}


func from_save_dict(data: Dictionary) -> void:
	if data.has("prices") and not data.prices.is_empty():
		prices = data.prices.duplicate(true)
	else:
		_reset_prices()
	holdings = data.get("holdings", {}).duplicate(true)
	last_news = str(data.get("last_news", ""))
	market_updated.emit()


func _reset_prices() -> void:
	for ticker in INSTRUMENTS.keys():
		prices[ticker] = INSTRUMENTS[ticker].base_price
		if not holdings.has(ticker):
			holdings[ticker] = 0


func can_trade() -> bool:
	return LicenseManager.has_license("exchange_broker")


func get_price(ticker: String) -> float:
	return float(prices.get(ticker, 0.0))


func get_holding(ticker: String) -> int:
	return int(holdings.get(ticker, 0))


func buy(ticker: String, qty: int) -> bool:
	if not can_trade() or qty <= 0 or not INSTRUMENTS.has(ticker):
		return false
	var cost := int(ceil(get_price(ticker) * qty))
	if not EconomyManager.register_expense(cost, "Покупка %s ×%d" % [ticker, qty], "exchange"):
		return false
	holdings[ticker] = get_holding(ticker) + qty
	market_updated.emit()
	return true


func sell(ticker: String, qty: int) -> bool:
	if not can_trade() or qty <= 0:
		return false
	var have := get_holding(ticker)
	if have < qty:
		return false
	var revenue := int(floor(get_price(ticker) * qty))
	EconomyManager.register_income(revenue, "Продажа %s ×%d" % [ticker, qty], "exchange")
	holdings[ticker] = have - qty
	market_updated.emit()
	return true


func get_portfolio_value() -> int:
	var total := 0.0
	for ticker in INSTRUMENTS.keys():
		total += get_price(ticker) * get_holding(ticker)
	return int(total)


func _on_day_changed(_day: int) -> void:
	_tick_prices(1.5)
	if BusinessManager.owns_business("oil_prom"):
		var bonus := int(get_holding("VL-OIL") * get_price("VL-OIL") * 0.01)
		if bonus > 0:
			EconomyManager.register_income(bonus, "Бонус владельца VL-OIL", "exchange")


func _on_second_tick() -> void:
	_tick_accumulator += 1.0
	if _tick_accumulator >= 45.0:
		_tick_accumulator = 0.0
		_tick_prices(0.3)


func _tick_prices(strength: float) -> void:
	for ticker in INSTRUMENTS.keys():
		var def: Dictionary = INSTRUMENTS[ticker]
		var vol: float = float(def.volatility) * strength
		var change := randf_range(-vol, vol)
		var p: float = get_price(ticker)
		p = maxf(p * (1.0 + change), def.base_price * 0.5)
		prices[ticker] = snappedf(p, 0.01)
	if randf() < 0.15:
		last_news = NEWS_LINES[randi_range(0, NEWS_LINES.size() - 1)]
		market_news.emit(last_news)
	market_updated.emit()
