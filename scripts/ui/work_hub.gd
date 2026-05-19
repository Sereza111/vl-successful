extends Control

@onready var progress_label: Label = %ProgressLabel
@onready var taxi_button: Button = %TaxiButton
@onready var courier_button: Button = %CourierButton
@onready var license_button: Button = %LicenseButton
@onready var business_button: Button = %BusinessButton
@onready var back_button: Button = %BackButton
@onready var rating_label: Label = %RatingLabel
@onready var xp_label: Label = %XpLabel
@onready var car_upgrade_button: Button = %CarUpgradeButton
@onready var transport_license_button: Button = %TransportLicenseButton
@onready var tier_label: Label = %TierLabel
@onready var llc_button: Button = %LlcButton
@onready var holding_button: Button = %HoldingButton
@onready var fleet_button: Button = %FleetButton


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
	llc_button.pressed.connect(_on_llc_upgrade)
	holding_button.pressed.connect(_on_holding_upgrade)
	fleet_button.pressed.connect(_on_fleet)
	GameState.balance_changed.connect(_refresh_ui)
	ProgressionManager.progression_updated.connect(_refresh_ui)
	LicenseManager.licenses_updated.connect(_refresh_ui)
	TaxiCareerManager.career_updated.connect(_refresh_ui)
	TaxiFleetManager.fleet_updated.connect(_refresh_ui)
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
	xp_label.text = TaxiCareerManager.get_xp_progress_text()
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

	tier_label.text = "Статус: %s" % ProgressionManager.get_company_tier_label()
	llc_button.visible = ProgressionManager.company_tier == "ip"
	llc_button.disabled = not ProgressionManager.can_upgrade_to_llc()
	if ProgressionManager.company_tier == "ip":
		llc_button.text = "ООО (%s ₽)" % GameState.format_amount(ProgressionManager.LLC_COST)
	holding_button.visible = ProgressionManager.company_tier == "llc"
	holding_button.disabled = not ProgressionManager.can_upgrade_to_holding()
	if ProgressionManager.company_tier == "llc":
		holding_button.text = "Холдинг (%s ₽)" % GameState.format_amount(
			ProgressionManager.HOLDING_COST
		)
	fleet_button.visible = ProgressionManager.business_opened
	fleet_button.text = "Автопарк (%d/3)" % TaxiFleetManager.hired_drivers.size()


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


func _on_llc_upgrade() -> void:
	if ProgressionManager.upgrade_to_llc():
		_refresh_ui()


func _on_holding_upgrade() -> void:
	if ProgressionManager.upgrade_to_holding():
		_refresh_ui()


func _on_fleet() -> void:
	SceneNav.go_to(SceneNav.TAXI_FLEET)


func _on_back_pressed() -> void:
	SceneNav.go_to_main()
