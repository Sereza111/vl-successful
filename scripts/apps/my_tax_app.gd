extends Control

@onready var _home_tab: Control = %HomeTab
@onready var _docs_tab: Control = %DocumentsTab
@onready var _pay_tab: Control = %PayTab
@onready var _disclaimer: AcceptDialog = %DisclaimerDialog
@onready var _tax_amount_label: Label = %TaxAmountLabel
@onready var _player_id_label: Label = %PlayerIdLabel
@onready var _docs_list: VBoxContainer = %DocumentsList
@onready var _pay_amount: Label = %PayAmount
@onready var _pay_swipe: Control = %PaySwipe
@onready var _tab_home: Button = %TabHome
@onready var _tab_docs: Button = %TabDocs
@onready var _tab_pay: Button = %TabPay



func _ready() -> void:
	%BackButton.pressed.connect(_on_back)
	_tab_home.pressed.connect(func(): _show_tab(0))
	_tab_docs.pressed.connect(func(): _show_tab(1))
	_tab_pay.pressed.connect(func(): _show_tab(2))
	_pay_swipe.confirmed.connect(_on_pay_confirmed)
	TaxManager.tax_updated.connect(_refresh_all)
	TaxManager.documents_updated.connect(_refresh_documents)
	_disclaimer.confirmed.connect(func(): TaxManager.mark_disclaimer_seen())
	if not TaxManager.disclaimer_accepted:
		_disclaimer.popup_centered()
	_refresh_all()
	_show_tab(0)


func _show_tab(index: int) -> void:
	_home_tab.visible = index == 0
	_docs_tab.visible = index == 1
	_pay_tab.visible = index == 2
	_tab_home.disabled = index == 0
	_tab_docs.disabled = index == 1
	_tab_pay.disabled = index == 2


func _refresh_all() -> void:
	_tax_amount_label.text = GameState.format_amount(TaxManager.tax_owed) + " ₽"
	_player_id_label.text = "Игровой ID: %s" % TaxManager.PLAYER_TAX_ID
	_pay_amount.text = "К оплате: %s ₽" % GameState.format_amount(TaxManager.tax_owed)
	if _pay_swipe.has_method("set_locked"):
		_pay_swipe.set_locked(TaxManager.tax_owed <= 0)
	if TaxManager.tax_owed > 0 and _pay_swipe.has_method("reset"):
		_pay_swipe.reset()
	_refresh_documents()


func _refresh_documents() -> void:
	for child in _docs_list.get_children():
		child.queue_free()
	for doc in TaxManager.get_documents():
		_docs_list.add_child(_build_document_card(doc))


func _build_document_card(doc: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyles.document_panel())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = doc.get("title", "Документ")
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.1, 0.12, 0.18))
	vbox.add_child(title)
	for line in doc.get("lines", []):
		var line_label := Label.new()
		line_label.text = str(line)
		line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line_label.add_theme_font_size_override("font_size", 13)
		line_label.add_theme_color_override("font_color", Color(0.25, 0.28, 0.35))
		vbox.add_child(line_label)
	var status := Label.new()
	var paid: bool = doc.get("paid", false)
	status.text = "Оплачено" if paid else "К оплате"
	status.add_theme_color_override(
		"font_color",
		Color(0.2, 0.55, 0.35) if paid else Color(0.7, 0.45, 0.15)
	)
	vbox.add_child(status)
	return panel


func _on_pay_confirmed() -> void:
	if TaxManager.pay_tax_manual():
		_refresh_all()
		_show_tab(1)


func _on_back() -> void:
	SceneNav.go_to_main()
