extends Control

@onready var balance_label: Label = %BalanceLabel
@onready var expenses_label: Label = %ExpensesLabel
@onready var tax_badge: Button = %TaxBadge
@onready var tax_dock_button: Button = %TaxDockButton
@onready var work_dock_button: Button = %WorkDockButton
@onready var map_dock_button: Button = %MapDockButton


func _ready() -> void:
	_style_dock()
	_style_tax_badge()
	GameState.balance_changed.connect(_refresh_ui)
	GameState.cashflow_updated.connect(_refresh_ui)
	EconomyManager.expenses_updated.connect(_refresh_ui)
	TaxManager.tax_updated.connect(_refresh_ui)
	tax_badge.pressed.connect(_open_tax_app)
	tax_dock_button.pressed.connect(_open_tax_app)
	work_dock_button.pressed.connect(_open_work)
	map_dock_button.pressed.connect(_open_map)
	_refresh_ui()


func _refresh_ui() -> void:
	balance_label.text = GameState.get_formatted_balance()
	expenses_label.text = EconomyManager.get_today_expenses_text()
	var owed := TaxManager.tax_owed
	if owed > 0:
		tax_badge.text = "%s ₽" % GameState.format_amount(owed)
	else:
		tax_badge.text = "Налог ✓"


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
