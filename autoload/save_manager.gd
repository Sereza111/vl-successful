extends Node

signal save_completed
signal load_completed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL_SEC := 45.0

var _autosave_timer: float = 0.0
var _loaded := false


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL_SEC:
		_autosave_timer = 0.0
		save_game()


func _on_scene_changed() -> void:
	if _loaded:
		save_game()


func save_game() -> bool:
	var data := _collect_state()
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot write %s" % SAVE_PATH)
		return false
	file.store_string(json)
	file.close()
	save_completed.emit()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		_loaded = true
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_loaded = true
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_loaded = true
		return false
	_apply_state(parsed)
	_loaded = true
	load_completed.emit()
	return true


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	get_tree().reload_current_scene()


func _collect_state() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"game_state": GameState.to_save_dict(),
		"time": TimeManager.to_save_dict(),
		"tax": TaxManager.to_save_dict(),
		"progression": ProgressionManager.to_save_dict(),
		"license": LicenseManager.to_save_dict(),
		"business": BusinessManager.to_save_dict(),
		"market": MarketManager.to_save_dict(),
		"ad": AdManager.to_save_dict(),
		"taxi_career": TaxiCareerManager.to_save_dict(),
		"economy": EconomyManager.to_save_dict(),
		"expense": ExpenseManager.to_save_dict(),
		"loan": LoanManager.to_save_dict(),
		"taxi_fleet": TaxiFleetManager.to_save_dict(),
		"property": PropertyManager.to_save_dict(),
	}


func _apply_state(data: Dictionary) -> void:
	var version: int = int(data.get("save_version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: newer save version %d" % version)
	if data.has("game_state"):
		GameState.from_save_dict(data.game_state)
	if data.has("time"):
		TimeManager.from_save_dict(data.time)
	if data.has("tax"):
		TaxManager.from_save_dict(data.tax)
	if data.has("progression"):
		ProgressionManager.from_save_dict(data.progression)
	if data.has("license"):
		LicenseManager.from_save_dict(data.license)
	if data.has("business"):
		BusinessManager.from_save_dict(data.business)
	if data.has("market"):
		MarketManager.from_save_dict(data.market)
	if data.has("ad"):
		AdManager.from_save_dict(data.ad)
	if data.has("taxi_career"):
		TaxiCareerManager.from_save_dict(data.taxi_career)
	if data.has("economy"):
		EconomyManager.from_save_dict(data.economy)
	if data.has("expense"):
		ExpenseManager.from_save_dict(data.expense)
	if data.has("loan"):
		LoanManager.from_save_dict(data.loan)
	if data.has("taxi_fleet"):
		TaxiFleetManager.from_save_dict(data.taxi_fleet)
	if data.has("property"):
		PropertyManager.from_save_dict(data.property)
