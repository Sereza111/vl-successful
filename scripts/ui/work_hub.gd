extends Control

@onready var progress_label: Label = %ProgressLabel
@onready var taxi_button: Button = %TaxiButton
@onready var courier_button: Button = %CourierButton
@onready var license_button: Button = %LicenseButton
@onready var business_button: Button = %BusinessButton
@onready var back_button: Button = %BackButton
@onready var rating_label: Label = %RatingLabel
@onready var car_upgrade_button: Button = %CarUpgradeButton
@onready var transport_license_button: Button = %TransportLicenseButton


func _ready() -> void:
	_style_job_card(%TaxiCard)
	_style_job_card(%CourierCard)
	taxi_button.pressed.connect(_on_taxi_pressed)
	courier_button.pressed.connect(_on_courier_pressed)
	license_button.pressed.connect(_on_license_pressed)
	business_button.pressed.connect(_on_business_pressed)
	back_button.pressed.connect(_on_back_pressed)
	car_upgrade_button.pressed.connect(_on_car_upgrade)
	transport_license_button.pressed.connect(_on_transport_license)
	GameState.balance_changed.connect(_refresh_ui)
	ProgressionManager.progression_updated.connect(_refresh_ui)
	LicenseManager.licenses_updated.connect(_refresh_ui)
	TaxiCareerManager.career_updated.connect(_refresh_ui)
	_refresh_ui()


func _style_job_card(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", UiStyles.app_panel())


func _refresh_ui() -> void:
	progress_label.text = ProgressionManager.get_progress_to_business_text()
	license_button.visible = ProgressionManager.can_buy_license()
	license_button.disabled = not ProgressionManager.can_buy_license()
	business_button.visible = (
		ProgressionManager.can_open_business() or ProgressionManager.business_opened
	)
	business_button.disabled = not ProgressionManager.can_open_business()
	if ProgressionManager.business_opened:
		business_button.text = "Мой бизнес"
	elif ProgressionManager.can_open_business():
		business_button.text = "Открыть ИП (%s ₽)" % GameState.format_amount(
			BusinessManager.BUSINESS_OPEN_COST
		)
	else:
		business_button.text = "Бизнес (закрыто)"

	rating_label.text = "Рейтинг такси: %s (%.1f)" % [
		TaxiCareerManager.get_rating_stars(),
		TaxiCareerManager.rating,
	]
	var car: Dictionary = TaxiCareerManager.get_car_info()
	car_upgrade_button.text = "Авто: %s" % car.get("name", "—")
	car_upgrade_button.disabled = not TaxiCareerManager.can_upgrade_car()

	var has_transport := LicenseManager.has_license("transport")
	transport_license_button.visible = not has_transport
	transport_license_button.disabled = not LicenseManager.can_purchase("transport")
	transport_license_button.text = "Лицензия перевозок (3 000 ₽)"

	courier_button.disabled = not has_transport
	courier_button.text = (
		"Курьер VL — смена 3 мин" if has_transport else "Курьер (нужна лицензия перевозок)"
	)


func _on_taxi_pressed() -> void:
	SceneNav.go_to(SceneNav.TAXI_SHIFT)


func _on_courier_pressed() -> void:
	if LicenseManager.has_license("transport"):
		SceneNav.go_to(SceneNav.COURIER_SHIFT)
	else:
		progress_label.text = "Купите лицензию перевозок на карте или ниже"


func _on_license_pressed() -> void:
	if ProgressionManager.buy_license():
		_refresh_ui()


func _on_business_pressed() -> void:
	if ProgressionManager.business_opened:
		SceneNav.go_to(SceneNav.BUSINESS_LIST)
	elif ProgressionManager.open_business():
		SceneNav.go_to(SceneNav.BUSINESS_LIST)


func _on_car_upgrade() -> void:
	if TaxiCareerManager.upgrade_car():
		_refresh_ui()


func _on_transport_license() -> void:
	if LicenseManager.purchase_license("transport"):
		_refresh_ui()


func _on_back_pressed() -> void:
	SceneNav.go_to_main()
