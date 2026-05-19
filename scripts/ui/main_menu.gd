extends Control

enum TxFilter { ALL, INCOME, EXPENSE }

@onready var balance_label: Label = %BalanceLabel
@onready var expenses_label: Label = %ExpensesLabel
@onready var tax_badge: Button = %TaxBadge
@onready var tax_dock_button: Button = %TaxDockButton
@onready var work_dock_button: Button = %WorkDockButton
@onready var map_dock_button: Button = %MapDockButton
@onready var tx_list: VBoxContainer = %TxList
@onready var loan_summary: Label = %LoanSummary
@onready var filter_all: Button = %FilterAll
@onready var filter_income: Button = %FilterIncome
@onready var filter_expense: Button = %FilterExpense
@onready var bankruptcy_dialog: AcceptDialog = %BankruptcyDialog
@onready var toast_label: Label = %ToastLabel

var _tx_filter: TxFilter = TxFilter.ALL
var _displayed_balance: int = 0
var _balance_tween: Tween
var _toast_tween: Tween


func _ready() -> void:
	_style_dock()
	_style_tax_badge()
	_displayed_balance = GameState.balance_rub
	GameState.balance_changed.connect(_on_balance_changed)
	GameState.cashflow_updated.connect(_refresh_tx_list)
	EconomyManager.expenses_updated.connect(_refresh_expenses)
	TaxManager.tax_updated.connect(_refresh_tax_badge)
	LoanManager.loans_updated.connect(_refresh_loans)
	ExpenseManager.bankruptcy_triggered.connect(_on_bankruptcy)
	ExpenseManager.expenses_processed.connect(_refresh_expenses)
	tax_badge.pressed.connect(_open_tax_app)
	tax_dock_button.pressed.connect(_open_tax_app)
	work_dock_button.pressed.connect(_open_work)
	map_dock_button.pressed.connect(_open_map)
	filter_all.pressed.connect(func(): _set_tx_filter(TxFilter.ALL))
	filter_income.pressed.connect(func(): _set_tx_filter(TxFilter.INCOME))
	filter_expense.pressed.connect(func(): _set_tx_filter(TxFilter.EXPENSE))
	%LoanConsumerButton.pressed.connect(func(): _take_loan("consumer", 10000))
	%LoanPayButton.pressed.connect(_pay_first_loan)
	bankruptcy_dialog.confirmed.connect(_on_bankruptcy_confirmed)
	NotificationManager.toast_requested.connect(_on_toast)
	toast_label.modulate.a = 0.0
	_refresh_all()


func _refresh_all() -> void:
	_refresh_tax_badge()
	_refresh_expenses()
	_refresh_loans()
	_refresh_tx_list()
	_animate_balance_to(GameState.balance_rub)


func _on_balance_changed() -> void:
	_animate_balance_to(GameState.balance_rub)
	_refresh_tax_badge()


func _animate_balance_to(target: int) -> void:
	if _balance_tween:
		_balance_tween.kill()
	if _displayed_balance == target:
		balance_label.text = GameState.get_formatted_balance()
		return
	_balance_tween = create_tween()
	_balance_tween.tween_method(_set_balance_display, float(_displayed_balance), float(target), 0.45)
	_balance_tween.tween_callback(func(): _displayed_balance = target)


func _set_balance_display(value: float) -> void:
	var v := int(round(value))
	balance_label.text = "%s ₽" % GameState.format_amount(v)


func _refresh_tax_badge() -> void:
	var owed := TaxManager.tax_owed
	if owed > 0:
		tax_badge.text = "%s ₽" % GameState.format_amount(owed)
	else:
		tax_badge.text = "Налог ✓"


func _refresh_expenses() -> void:
	expenses_label.text = "%s\n%s" % [
		EconomyManager.get_today_expenses_text(),
		ExpenseManager.get_upcoming_expenses_text(),
	]


func _refresh_loans() -> void:
	var debt := LoanManager.get_total_debt()
	if debt > 0:
		loan_summary.text = "Долг: %s ₽\n%s" % [
			GameState.format_amount(debt),
			LoanManager.get_loans_summary(),
		]
	else:
		loan_summary.text = "Кредитов нет · потребительский до 30 000 ₽"


func _set_tx_filter(filter: TxFilter) -> void:
	_tx_filter = filter
	_refresh_tx_list()


func _refresh_tx_list() -> void:
	for child in tx_list.get_children():
		child.queue_free()
	var count := 0
	for entry in GameState.cashflow_log:
		if count >= 18:
			break
		var is_income: bool = entry.get("is_income", false)
		if _tx_filter == TxFilter.INCOME and not is_income:
			continue
		if _tx_filter == TxFilter.EXPENSE and is_income:
			continue
		tx_list.add_child(_make_tx_row(entry))
		count += 1
	if count == 0:
		var empty := Label.new()
		empty.text = "Операций пока нет"
		empty.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
		tx_list.add_child(empty)


func _make_tx_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var is_income: bool = entry.get("is_income", false)
	var amount: int = absi(int(entry.get("amount", 0)))
	var amount_sign := "+" if is_income else "−"
	var amount_lbl := Label.new()
	amount_lbl.text = "%s%s ₽" % [amount_sign, GameState.format_amount(amount)]
	amount_lbl.custom_minimum_size.x = 100
	var color := Color(0.45, 0.9, 0.55) if is_income else Color(0.95, 0.55, 0.5)
	amount_lbl.add_theme_color_override("font_color", color)
	amount_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(amount_lbl)
	var info := Label.new()
	info.text = "%s · д.%d" % [entry.get("reason", "—"), int(entry.get("game_day", 0))]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	row.add_child(info)
	return row


func _take_loan(loan_type: String, amount: int) -> void:
	if LoanManager.take_loan(loan_type, amount):
		_refresh_loans()


func _pay_first_loan() -> void:
	if LoanManager.active_loans.is_empty():
		return
	var loan: Dictionary = LoanManager.active_loans[0]
	LoanManager.pay_loan(int(loan.get("id", 0)))


func _on_bankruptcy() -> void:
	bankruptcy_dialog.dialog_text = (
		"Баланс 0 ₽. Возьмите экстренный займ 5 000 ₽ или начните заново."
	)
	bankruptcy_dialog.popup_centered()


func _on_bankruptcy_confirmed() -> void:
	if LoanManager.take_emergency_loan():
		ExpenseManager.clear_bankruptcy()
		_refresh_all()


func _open_tax_app() -> void:
	SceneNav.go_to(SceneNav.TAX_APP)


func _open_work() -> void:
	SceneNav.go_to(SceneNav.WORK_HUB)


func _open_map() -> void:
	SceneNav.go_to_map()


func _style_dock() -> void:
	_style_dock_button(
		tax_dock_button,
		Color(0.18, 0.38, 0.28),
		Color(0.9, 0.75, 0.55)
	)
	_style_dock_button(
		map_dock_button,
		Color(0.22, 0.2, 0.32),
		Color(0.85, 0.8, 0.95)
	)
	_style_dock_button(
		work_dock_button,
		Color(0.18, 0.24, 0.42),
		Color(0.75, 0.82, 0.95)
	)


func _style_dock_button(btn: Button, bg: Color, label_color: Color) -> void:
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal := _dock_style(bg)
	var hover := _dock_style(bg.lightened(0.12))
	var pressed := _dock_style(bg.darkened(0.08))
	btn.flat = false
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", label_color)
	btn.add_theme_color_override("font_hover_color", label_color)
	btn.add_theme_color_override("font_pressed_color", label_color)
	btn.add_theme_font_size_override("font_size", 14)


func _dock_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(16)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _style_tax_badge() -> void:
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.15, 0.28, 0.22, 0.95)
	chip.border_color = Color(0.45, 0.72, 0.55, 0.6)
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(10)
	chip.content_margin_left = 10
	chip.content_margin_right = 10
	chip.content_margin_top = 5
	chip.content_margin_bottom = 5
	tax_badge.add_theme_stylebox_override("normal", chip)
	tax_badge.add_theme_stylebox_override("hover", chip)
	tax_badge.add_theme_stylebox_override("pressed", chip)
	tax_badge.add_theme_stylebox_override("focus", chip)


func _on_toast(message: String, is_income: bool) -> void:
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.text = message
	toast_label.modulate = Color(0.45, 0.95, 0.55, 1) if is_income else Color(1, 0.55, 0.45, 1)
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
