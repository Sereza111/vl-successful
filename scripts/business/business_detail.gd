extends Control

@onready var _title: Label = %TitleLabel
@onready var _stats: Label = %StatsLabel
@onready var _upgrade_btn: Button = %UpgradeButton
@onready var _ads_btn: Button = %AdsButton

var _business_id: String = ""


func _ready() -> void:
	_business_id = BusinessManager.selected_business_id
	if _business_id.is_empty() and BusinessManager.get_owned_ids().size() > 0:
		_business_id = BusinessManager.get_owned_ids()[0]
	%BackButton.pressed.connect(func(): SceneNav.go_to(SceneNav.BUSINESS_LIST))
	_upgrade_btn.pressed.connect(_on_upgrade)
	_ads_btn.pressed.connect(func(): SceneNav.go_to(SceneNav.AD_AGENCY))
	BusinessManager.business_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _business_id.is_empty() or not BusinessManager.owns_business(_business_id):
		_title.text = "Бизнес не найден"
		return
	var def: Dictionary = BusinessManager.get_definition(_business_id)
	var lvl := BusinessManager.get_level(_business_id)
	_title.text = def.get("name", _business_id)
	var levels: Array = def.get("upgrade_levels", [])
	var lvl_name := "Базовый"
	if lvl >= 0 and lvl < levels.size():
		lvl_name = levels[lvl].get("name", "Уровень %d" % (lvl + 1))
	elif lvl >= levels.size() and levels.size() > 0:
		lvl_name = "Макс."
	_stats.text = (
		"Уровень: %s\n"
		+ "Чистая прибыль: %s ₽/день\n"
		+ "Спрос (реклама): ×%.2f\n"
		+ "%s"
		% [
			lvl_name,
			GameState.format_amount(BusinessManager.get_daily_net(_business_id)),
			BusinessManager.get_demand_mult(_business_id),
			AdManager.get_campaign_status(_business_id),
		]
	)
	if BusinessManager.can_upgrade(_business_id):
		_upgrade_btn.visible = true
		_upgrade_btn.text = "Улучшить (%s ₽)" % GameState.format_amount(
			BusinessManager.get_upgrade_cost(_business_id)
		)
		_upgrade_btn.disabled = GameState.balance_rub < BusinessManager.get_upgrade_cost(_business_id)
	else:
		_upgrade_btn.visible = false


func _on_upgrade() -> void:
	if BusinessManager.upgrade_business(_business_id):
		_refresh()
