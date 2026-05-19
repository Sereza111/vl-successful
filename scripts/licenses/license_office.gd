extends Control

@onready var _list: VBoxContainer = %LicenseList


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneNav.go_to_map())
	LicenseManager.licenses_updated.connect(_rebuild_list)
	_rebuild_list()


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	for license_id in LicenseManager.get_all_license_ids():
		_list.add_child(_make_row(str(license_id)))


func _make_row(license_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyles.app_panel())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var def: Dictionary = LicenseManager.get_license_info(license_id)
	var title := Label.new()
	title.text = def.get("name", license_id)
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = def.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	desc.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc)

	var status := Label.new()
	status.text = LicenseManager.get_status_text(license_id)
	status.add_theme_font_size_override("font_size", 13)
	vbox.add_child(status)

	if not LicenseManager.has_license(license_id):
		var btn := Button.new()
		btn.text = "Купить"
		btn.disabled = not LicenseManager.can_purchase(license_id)
		var lid := license_id
		btn.pressed.connect(func(): LicenseManager.purchase_license(lid))
		vbox.add_child(btn)

	return panel
