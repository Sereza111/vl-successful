extends Control

@onready var _business_option: OptionButton = %BusinessOption
@onready var _campaign_option: OptionButton = %CampaignOption
@onready var _cost_label: Label = %CostLabel
@onready var _status_label: Label = %StatusLabel
@onready var _swipe: Control = %CampaignSwipe


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneNav.go_to_map())
	_campaign_option.item_selected.connect(_on_campaign_changed)
	_business_option.item_selected.connect(_refresh_cost)
	_swipe.confirmed.connect(_on_campaign_confirmed)
	_rebuild_options()
	AdManager.campaigns_changed.connect(_refresh_status)
	_refresh_cost()
	_refresh_status()


func _rebuild_options() -> void:
	_business_option.clear()
	var ids := BusinessManager.get_owned_ids()
	for i in range(ids.size()):
		var bid: String = ids[i]
		var def: Dictionary = BusinessManager.get_definition(bid)
		_business_option.add_item(def.get("name", bid), i)
		_business_option.set_item_metadata(i, bid)

	_campaign_option.clear()
	var idx := 0
	for ctype in AdManager.NPC_CAMPAIGNS.keys():
		var cdef: Dictionary = AdManager.NPC_CAMPAIGNS[ctype]
		_campaign_option.add_item(cdef.get("name", ctype), idx)
		_campaign_option.set_item_metadata(idx, ctype)
		idx += 1


func _get_selected_business_id() -> String:
	var i := _business_option.selected
	if i < 0:
		return ""
	return str(_business_option.get_item_metadata(i))


func _get_selected_campaign_type() -> String:
	var i := _campaign_option.selected
	if i < 0:
		return "local"
	return str(_campaign_option.get_item_metadata(i))


func _on_campaign_changed(_idx: int) -> void:
	_refresh_cost()


func _refresh_cost() -> void:
	var ctype := _get_selected_campaign_type()
	var cost := AdManager.get_campaign_cost(ctype)
	_cost_label.text = "Стоимость: %s ₽" % GameState.format_amount(cost)
	if AdManager.has_own_agency():
		_cost_label.text += " (скидка своего агентства)"


func _refresh_status() -> void:
	var bid := _get_selected_business_id()
	if bid.is_empty():
		_status_label.text = "Нет бизнесов для рекламы"
		return
	_status_label.text = AdManager.get_campaign_status(bid)


func _on_campaign_confirmed() -> void:
	var bid := _get_selected_business_id()
	var ctype := _get_selected_campaign_type()
	if bid.is_empty():
		return
	if AdManager.run_campaign(bid, ctype):
		_refresh_status()
		if _swipe.has_method("reset"):
			_swipe.reset()
