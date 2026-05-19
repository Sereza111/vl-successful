extends Control

@onready var summary_label: Label = %SummaryLabel
@onready var details_label: Label = %DetailsLabel
@onready var tax_label: Label = %TaxHint
@onready var continue_button: Button = %ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	_populate_report()


func _populate_report() -> void:
	var result: Dictionary = JobManager.last_shift_result
	if result.is_empty():
		summary_label.text = "Нет данных смены"
		return
	if not result.get("courier", false):
		TaxiCareerManager.apply_shift_result(
			result.get("accepted", 0),
			result.get("declined", 0),
			result.get("events", 0)
		)
	var net: int = result.get("net", 0)
	var net_sign := "+" if net >= 0 else "−"
	var title := "Итог курьера" if result.get("courier", false) else "Итог смены такси"
	summary_label.text = "%s: %s%s ₽" % [title, net_sign, GameState.format_amount(absi(net))]
	var events: int = result.get("events", 0)
	var events_sign := "+" if events >= 0 else "−"
	details_label.text = (
		"Заработано: %s ₽\nБензин: −%s ₽\nСобытия: %s%s ₽\nПринято: %d | Отклонено: %d"
		% [
			GameState.format_amount(result.get("gross", 0)),
			GameState.format_amount(result.get("fuel", 0)),
			events_sign,
			GameState.format_amount(absi(events)),
			result.get("accepted", 0),
			result.get("declined", 0),
		]
	)
	if not result.get("courier", false):
		tax_label.text = "%s\nРейтинг: %s\n%s" % [
			TaxManager.get_tax_status_text(),
			TaxiCareerManager.get_rating_stars(),
			TaxiCareerManager.get_xp_progress_text(),
		]
	else:
		tax_label.text = TaxManager.get_tax_status_text()


func _on_continue_pressed() -> void:
	JobManager.clear_shift_result()
	SceneNav.go_to(SceneNav.WORK_HUB)
