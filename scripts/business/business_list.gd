extends Control

@onready var _list: VBoxContainer = %BusinessList


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneNav.go_to_map())
	BusinessManager.business_updated.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()

	for bid in BusinessManager.get_owned_ids():
		_list.add_child(_owned_row(bid))

	for bid in BusinessManager.get_openable_ids():
		_list.add_child(_open_row(bid))

	if BusinessManager.get_owned_ids().is_empty():
		var hint := Label.new()
		hint.text = "Откройте ИП в разделе «Работа» или купите лицензии на карте."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(hint)


func _owned_row(business_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var def: Dictionary = BusinessManager.get_definition(business_id)
	var lbl := Label.new()
	lbl.text = "%s — %s ₽/день" % [
		def.get("name", business_id),
		GameState.format_amount(BusinessManager.get_daily_net(business_id)),
	]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = "Управление"
	var bid := business_id
	btn.pressed.connect(func():
		BusinessManager.selected_business_id = bid
		SceneNav.go_to(SceneNav.BUSINESS_DETAIL)
	)
	row.add_child(btn)
	return row


func _open_row(business_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var def: Dictionary = BusinessManager.get_definition(business_id)
	var lbl := Label.new()
	lbl.text = "Открыть: %s (%s ₽)" % [
		def.get("name", business_id),
		GameState.format_amount(int(def.get("open_cost", 0))),
	]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = "Открыть"
	btn.disabled = not BusinessManager.can_open(business_id)
	var bid := business_id
	btn.pressed.connect(func():
		if BusinessManager.open_business(bid):
			_rebuild()
	)
	row.add_child(btn)
	return row
