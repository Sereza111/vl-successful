extends Control

const SHIFT_SEC := 180.0
const DELIVERY_INTERVAL_MIN := 12.0
const DELIVERY_INTERVAL_MAX := 22.0

@onready var _timer_label: Label = %TimerLabel
@onready var _status: Label = %StatusLabel
@onready var _payout_label: Label = %PayoutLabel
@onready var _accept_btn: Button = %AcceptButton
@onready var _skip_btn: Button = %SkipButton

var _time_left: float = SHIFT_SEC
var _wait: float = 3.0
var _active: bool = false
var _delivery_timer: float = 0.0
var _current: Dictionary = {}
var _earned: int = 0
var _done: int = 0


func _ready() -> void:
	%BackButton.pressed.connect(_end_shift)
	_accept_btn.pressed.connect(_complete_delivery)
	_skip_btn.pressed.connect(_skip_delivery)
	_start()


func _process(delta: float) -> void:
	if not _active:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_timer_label.text = "Смена: %d:%02d" % [int(_time_left) / 60, int(_time_left) % 60]
	if _time_left <= 0.0:
		_end_shift()
		return
	if _current.is_empty():
		_wait -= delta
		if _wait <= 0.0:
			_spawn_delivery()
	else:
		_delivery_timer -= delta
		if _delivery_timer <= 0.0:
			_complete_delivery()


func _start() -> void:
	_active = true
	_status.text = "Курьер VL — ждём заказы…"


func _spawn_delivery() -> void:
	var districts := TaxiCareerManager.DISTRICTS.keys()
	var did: String = districts[randi_range(0, districts.size() - 1)]
	var dname: String = TaxiCareerManager.DISTRICTS[did].get("name", did)
	var payout := randi_range(250, 900)
	_current = {"district": dname, "payout": payout, "seconds": randf_range(8.0, 18.0)}
	_payout_label.text = "Доставка в %s — %s ₽" % [dname, GameState.format_amount(payout)]
	_delivery_timer = _current.seconds
	_status.text = "Везём посылку…"
	_accept_btn.visible = false
	_skip_btn.disabled = false


func _complete_delivery() -> void:
	if _current.is_empty():
		return
	var payout: int = _current.payout
	EconomyManager.register_income(payout, "Доставка курьер", "courier")
	_earned += payout
	_done += 1
	_current.clear()
	_status.text = "Доставлено! (%d)" % _done
	_wait = randf_range(DELIVERY_INTERVAL_MIN, DELIVERY_INTERVAL_MAX)
	_skip_btn.disabled = true


func _skip_delivery() -> void:
	_current.clear()
	_wait = randf_range(6.0, 12.0)
	_status.text = "Заказ пропущен"
	_payout_label.text = "—"


func _end_shift() -> void:
	if not _active:
		SceneNav.go_to(SceneNav.WORK_HUB)
		return
	_active = false
	JobManager.set_shift_result(
		{
			"gross": _earned,
			"fuel": 0,
			"events": 0,
			"net": _earned,
			"accepted": _done,
			"declined": 0,
			"tax_owed": TaxManager.tax_owed,
			"courier": true,
		}
	)
	SceneNav.go_to(SceneNav.SHIFT_REPORT)
