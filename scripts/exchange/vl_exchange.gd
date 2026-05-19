extends Control

@onready var _news: Label = %NewsLabel
@onready var _portfolio: Label = %PortfolioLabel
@onready var _ticker_list: VBoxContainer = %TickerList
@onready var _qty_spin: SpinBox = %QtySpin


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneNav.go_to_map())
	MarketManager.market_updated.connect(_refresh)
	MarketManager.market_news.connect(func(msg): _news.text = msg)
	_refresh()


func _refresh() -> void:
	_news.text = MarketManager.last_news if MarketManager.last_news != "" else "VL-Биржа Солнышково"
	_portfolio.text = "Портфель: %s ₽" % GameState.format_amount(MarketManager.get_portfolio_value())
	if not MarketManager.can_trade():
		_portfolio.text += "\n(нужна лицензия брокера — Дом лицензий)"

	for c in _ticker_list.get_children():
		c.queue_free()

	for ticker in MarketManager.INSTRUMENTS.keys():
		_ticker_list.add_child(_make_ticker_row(ticker))


func _make_ticker_row(ticker: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var def: Dictionary = MarketManager.INSTRUMENTS[ticker]
	var head := Label.new()
	head.text = "%s (%s) — %.2f ₽" % [ticker, def.get("name", ""), MarketManager.get_price(ticker)]
	head.add_theme_font_size_override("font_size", 15)
	box.add_child(head)

	var hold := Label.new()
	hold.text = "В портфеле: %d шт." % MarketManager.get_holding(ticker)
	box.add_child(hold)

	var row := HBoxContainer.new()
	var qty := maxi(1, int(_qty_spin.value))
	var buy := Button.new()
	buy.text = "Купить"
	buy.disabled = not MarketManager.can_trade()
	var t := ticker
	buy.pressed.connect(func(): MarketManager.buy(t, qty))
	row.add_child(buy)
	var sell := Button.new()
	sell.text = "Продать"
	sell.disabled = not MarketManager.can_trade() or MarketManager.get_holding(ticker) < qty
	sell.pressed.connect(func(): MarketManager.sell(t, qty))
	row.add_child(sell)
	box.add_child(row)
	return box
