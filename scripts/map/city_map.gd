extends Control

@onready var _badge_taxi: Label = %BadgeTaxi
@onready var _badge_business: Label = %BadgeBusiness
@onready var _badge_exchange: Label = %BadgeExchange
@onready var _badge_licenses: Label = %BadgeLicenses


func _ready() -> void:
	%BackHomeButton.pressed.connect(SceneNav.go_to_main)
	%PoiTaxi.pressed.connect(_on_taxi)
	%PoiBusiness.pressed.connect(_on_business)
	%PoiExchange.pressed.connect(_on_exchange)
	%PoiAds.pressed.connect(_on_ads)
	%PoiLicenses.pressed.connect(_on_licenses)
	LicenseManager.licenses_updated.connect(_refresh_badges)
	BusinessManager.business_updated.connect(_refresh_badges)
	MarketManager.market_updated.connect(_refresh_badges)
	_refresh_badges()


func _refresh_badges() -> void:
	_badge_taxi.visible = not LicenseManager.has_license("transport")
	_badge_taxi.text = "!"

	var biz_hint := false
	for bid in BusinessManager.get_owned_ids():
		if BusinessManager.can_upgrade(bid):
			biz_hint = true
			break
	if BusinessManager.get_openable_ids().size() > 0:
		biz_hint = true
	_badge_business.visible = biz_hint
	_badge_business.text = "!"

	_badge_exchange.visible = not LicenseManager.has_license("exchange_broker")
	_badge_exchange.text = "₽"

	var lic_exp := LicenseManager.get_expired_licenses().size() > 0
	for lid in LicenseManager.get_all_license_ids():
		if LicenseManager.can_purchase(lid):
			lic_exp = true
			break
	_badge_licenses.visible = lic_exp
	_badge_licenses.text = "!"


func _on_taxi() -> void:
	if LicenseManager.has_license("transport"):
		SceneNav.go_to(SceneNav.TAXI_SHIFT)
	else:
		SceneNav.go_to(SceneNav.WORK_HUB)


func _on_business() -> void:
	if BusinessManager.get_owned_ids().is_empty() and not ProgressionManager.business_opened:
		SceneNav.go_to(SceneNav.WORK_HUB)
	else:
		SceneNav.go_to(SceneNav.BUSINESS_LIST)


func _on_exchange() -> void:
	SceneNav.go_to(SceneNav.EXCHANGE)


func _on_ads() -> void:
	SceneNav.go_to(SceneNav.AD_AGENCY)


func _on_licenses() -> void:
	SceneNav.go_to(SceneNav.LICENSE_OFFICE)
