extends Node

const MAIN_MENU := "res://scenes/main_menu.tscn"
const CITY_MAP := "res://scenes/map/city_map.tscn"
const WORK_HUB := "res://scenes/work/work_hub.tscn"
const TAXI_SHIFT := "res://scenes/work/taxi_shift.tscn"
const SHIFT_REPORT := "res://scenes/work/shift_report.tscn"
const TAX_APP := "res://scenes/apps/my_tax_app.tscn"
const AD_AGENCY := "res://scenes/apps/ad_agency.tscn"
const BUSINESS_LIST := "res://scenes/business/business_list.tscn"
const BUSINESS_DETAIL := "res://scenes/business/business_detail.tscn"
const EXCHANGE := "res://scenes/exchange/vl_exchange.tscn"
const LICENSE_OFFICE := "res://scenes/licenses/license_office.tscn"
const COURIER_SHIFT := "res://scenes/work/courier_shift.tscn"
const TAXI_FLEET := "res://scenes/fleet/taxi_fleet_screen.tscn"
const PROPERTY_OFFICE := "res://scenes/property/property_office.tscn"


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func go_to_main() -> void:
	go_to(MAIN_MENU)


func go_to_map() -> void:
	go_to(CITY_MAP)
