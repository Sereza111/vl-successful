extends Control


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneNav.go_to_map())
	TaxiFleetManager.fleet_updated.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for c in %DriverList.get_children():
		c.queue_free()
	%SummaryLabel.text = TaxiFleetManager.get_summary()
	for i in range(TaxiFleetManager.DRIVER_DEFS.size()):
		var def: Dictionary = TaxiFleetManager.DRIVER_DEFS[i]
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s — %s ₽" % [def.get("name", ""), GameState.format_amount(int(def.get("hire_cost", 0)))]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var hired := false
		for h in TaxiFleetManager.hired_drivers:
			if int(h.get("def_index", -1)) == i:
				hired = true
				break
		if hired:
			var ok := Label.new()
			ok.text = "Нанят"
			row.add_child(ok)
		else:
			var btn := Button.new()
			btn.text = "Нанять"
			btn.disabled = not TaxiFleetManager.can_hire(i)
			var idx := i
			btn.pressed.connect(func(): TaxiFleetManager.hire_driver(idx))
			row.add_child(btn)
		%DriverList.add_child(row)
