extends Control


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneNav.go_to_map())
	PropertyManager.property_updated.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for c in %PropertyList.get_children():
		c.queue_free()
	for p in PropertyManager.PROPERTIES:
		var pid: String = p.get("id", "")
		var row := HBoxContainer.new()
		var lbl := Label.new()
		var owned := PropertyManager.owns(pid)
		lbl.text = "%s — %s ₽/нед%s" % [
			p.get("name", ""),
			GameState.format_amount(int(p.get("rent_per_week", 0))),
			" ✓" if owned else "",
		]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if not owned:
			var btn := Button.new()
			btn.text = "Купить %s ₽" % GameState.format_amount(int(p.get("cost", 0)))
			btn.disabled = not PropertyManager.can_buy(pid)
			var id := pid
			btn.pressed.connect(func(): PropertyManager.buy_property(id))
			row.add_child(btn)
		%PropertyList.add_child(row)
