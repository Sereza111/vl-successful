extends Node

signal progression_updated

const BUSINESS_BALANCE_THRESHOLD := 50000
const BUSINESS_LICENSE_COST := 5000
const LLC_BALANCE_THRESHOLD := 150000
const LLC_COST := 50000
const HOLDING_BALANCE_THRESHOLD := 500000
const HOLDING_COST := 200000

var has_business_license: bool = false
var business_opened: bool = false
## worker | ip | llc | holding
var company_tier: String = "worker"


func get_progress_to_business_text() -> String:
	if company_tier == "holding":
		return "Холдинг VL — вершина карьеры"
	if company_tier == "llc":
		return "ООО открыто · можно масштабировать"
	if business_opened:
		return "ИП открыто · цель: ООО (%s ₽)" % GameState.format_amount(LLC_BALANCE_THRESHOLD)
	if has_business_license:
		if GameState.balance_rub >= BUSINESS_BALANCE_THRESHOLD:
			return "Можно открыть ИП!"
		var need := BUSINESS_BALANCE_THRESHOLD - GameState.balance_rub
		return "До открытия ИП: %s ₽" % GameState.format_amount(need)
	if GameState.balance_rub >= BUSINESS_LICENSE_COST:
		return "Купите лицензию ИП (%s ₽)" % GameState.format_amount(BUSINESS_LICENSE_COST)
	var need_license_savings := BUSINESS_LICENSE_COST - GameState.balance_rub
	return "До лицензии ИП: %s ₽" % GameState.format_amount(maxi(0, need_license_savings))


func get_company_tier_label() -> String:
	match company_tier:
		"holding":
			return "Холдинг"
		"llc":
			return "ООО"
		"ip":
			return "ИП"
		_:
			return "Работник"


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
	company_tier = "ip"
	BusinessManager.open_retail_with_ip()
	progression_updated.emit()
	return true


func can_upgrade_to_llc() -> bool:
	return company_tier == "ip" and GameState.balance_rub >= LLC_BALANCE_THRESHOLD + LLC_COST


func upgrade_to_llc() -> bool:
	if not can_upgrade_to_llc():
		return false
	if not EconomyManager.register_expense(LLC_COST, "Регистрация ООО", "progression"):
		return false
	company_tier = "llc"
	progression_updated.emit()
	return true


func can_upgrade_to_holding() -> bool:
	return company_tier == "llc" and GameState.balance_rub >= HOLDING_BALANCE_THRESHOLD + HOLDING_COST


func upgrade_to_holding() -> bool:
	if not can_upgrade_to_holding():
		return false
	if not EconomyManager.register_expense(HOLDING_COST, "Создание холдинга", "progression"):
		return false
	company_tier = "holding"
	progression_updated.emit()
	return true


func to_save_dict() -> Dictionary:
	return {
		"has_business_license": has_business_license,
		"business_opened": business_opened,
		"company_tier": company_tier,
	}


func from_save_dict(data: Dictionary) -> void:
	has_business_license = bool(data.get("has_business_license", false))
	business_opened = bool(data.get("business_opened", false))
	company_tier = str(data.get("company_tier", "worker"))
	if business_opened and company_tier == "worker":
		company_tier = "ip"
	if has_business_license and not LicenseManager.has_license("ip_retail"):
		LicenseManager.active_licenses["ip_retail"] = {
			"purchased_day": 1,
			"expires_day": 0,
		}
	progression_updated.emit()
