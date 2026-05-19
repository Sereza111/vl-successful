extends Node

signal progression_updated

const BUSINESS_BALANCE_THRESHOLD := 50000
const BUSINESS_LICENSE_COST := 5000

var has_business_license: bool = false
var business_opened: bool = false


func get_progress_to_business_text() -> String:
	if business_opened:
		return "ИП открыто"
	if has_business_license:
		if GameState.balance_rub >= BUSINESS_BALANCE_THRESHOLD:
			return "Можно открыть ИП!"
		var need := BUSINESS_BALANCE_THRESHOLD - GameState.balance_rub
		return "До открытия ИП: %s ₽" % GameState.format_amount(need)
	if GameState.balance_rub >= BUSINESS_LICENSE_COST:
		return "Купите лицензию ИП (%s ₽)" % GameState.format_amount(BUSINESS_LICENSE_COST)
	var need_license_savings := BUSINESS_LICENSE_COST - GameState.balance_rub
	return "До лицензии ИП: %s ₽" % GameState.format_amount(maxi(0, need_license_savings))


func can_buy_license() -> bool:
	return not has_business_license and GameState.balance_rub >= BUSINESS_LICENSE_COST


func buy_license() -> bool:
	if not can_buy_license():
		return false
	if LicenseManager.purchase_license("ip_retail"):
		has_business_license = true
		progression_updated.emit()
		return true
	return false


func can_open_business() -> bool:
	return (
		has_business_license
		and not business_opened
		and GameState.balance_rub >= BUSINESS_BALANCE_THRESHOLD
		and GameState.balance_rub >= BusinessManager.BUSINESS_OPEN_COST
	)


func open_business() -> bool:
	if not can_open_business():
		return false
	if not EconomyManager.register_expense(
		BusinessManager.BUSINESS_OPEN_COST, "Открытие ИП", "progression"
	):
		return false
	business_opened = true
	BusinessManager.open_retail_with_ip()
	progression_updated.emit()
	return true


func to_save_dict() -> Dictionary:
	return {
		"has_business_license": has_business_license,
		"business_opened": business_opened,
	}


func from_save_dict(data: Dictionary) -> void:
	has_business_license = bool(data.get("has_business_license", false))
	business_opened = bool(data.get("business_opened", false))
	if has_business_license and not LicenseManager.has_license("ip_retail"):
		LicenseManager.active_licenses["ip_retail"] = {
			"purchased_day": 1,
			"expires_day": 0,
		}
	progression_updated.emit()
