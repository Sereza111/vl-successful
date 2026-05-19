extends Control

enum Phase { WAITING, OFFER, PICKUP, TRIP }

@onready var shift_timer_label: Label = %ShiftTimerLabel
@onready var fuel_label: Label = %FuelLabel
@onready var order_panel: PanelContainer = %OrderPanel
@onready var order_route: Label = %OrderRoute
@onready var order_payout: Label = %OrderPayout
@onready var order_meta: Label = %OrderMeta
@onready var offer_timer_label: Label = %OfferTimerLabel
@onready var swipe_confirm: Control = %SwipeConfirm
@onready var skip_button: Button = %SkipButton
@onready var status_label: Label = %StatusLabel
@onready var event_label: Label = %EventLabel
@onready var payout_flash: Label = %PayoutFlash
@onready var trip_progress: Control = %TripProgress
@onready var taxi_visual: Node2D = %TaxiVisual
@onready var offer_content: Control = %OfferContent
@onready var waiting_content: Control = %WaitingContent
@onready var end_shift_button: Button = %EndShiftButton
@onready var taxi_layer: CanvasLayer = $TaxiLayer


var _trip_event_panel: HBoxContainer
var _trip_event_timer: float = 0.0
var _trip_event_resolved: bool = true

var _phase: Phase = Phase.WAITING
var _shift_time_left: float = 0.0
var _wait_timer: float = 0.0
var _offer_time_left: float = 0.0
var _phase_timer: float = 0.0
var _event_timer: float = 45.0
var _fuel: int = JobManager.SHIFT_FUEL_MAX
var _current_order: Dictionary = {}
var _shift_active: bool = false

var _gross_earned: int = 0
var _fuel_spent: int = 0
var _event_delta: int = 0
var _orders_accepted: int = 0
var _orders_declined: int = 0
var _trip_phase_done: bool = false


func _ready() -> void:
	order_panel.visible = false
	offer_content.visible = false
	waiting_content.visible = true
	payout_flash.visible = false
	skip_button.pressed.connect(_decline_order)
	end_shift_button.pressed.connect(_on_end_shift_pressed)
	swipe_confirm.confirmed.connect(_on_swipe_confirmed)
	TaxManager.random_event.connect(_on_random_event)
	taxi_layer.layer = 0
	_build_trip_event_ui()
	if taxi_visual.has_method("set_car_tier"):
		taxi_visual.set_car_tier(TaxiCareerManager.car_level)
	_start_shift()


func _process(delta: float) -> void:
	if not _shift_active:
		return
	_shift_time_left = maxf(_shift_time_left - delta, 0.0)
	_event_timer -= delta
	_refresh_hud()
	match _phase:
		Phase.WAITING:
			_process_waiting(delta)
		Phase.OFFER:
			_process_offer(delta)
		Phase.PICKUP, Phase.TRIP:
			_process_trip_phase(delta)
	if _event_timer <= 0.0:
		_event_timer = randf_range(50.0, 90.0)
		if randf() < 0.35 and _phase != Phase.OFFER:
			TaxManager.try_random_event()
	if _phase == Phase.TRIP and not _trip_event_resolved:
		_trip_event_timer -= delta
		if _trip_event_timer <= 0.0:
			_hide_trip_events()
	if _shift_time_left <= 0.0 or _fuel <= 0:
		_end_shift()


func _process_waiting(delta: float) -> void:
	_wait_timer -= delta
	if _wait_timer <= 0.0:
		_spawn_order()


func _process_offer(delta: float) -> void:
	_offer_time_left -= delta
	offer_timer_label.text = "Осталось: %d сек" % maxi(0, int(ceil(_offer_time_left)))
	if _offer_time_left <= 0.0:
		_decline_order()


func _process_trip_phase(_delta: float) -> void:
	if not trip_progress.is_complete() or _trip_phase_done:
		return
	_trip_phase_done = true
	if _phase == Phase.PICKUP:
		_start_trip()
	elif _phase == Phase.TRIP:
		_complete_trip()


func _start_shift() -> void:
	_shift_active = true
	_shift_time_left = JobManager.SHIFT_DURATION_SEC
	_fuel = JobManager.SHIFT_FUEL_MAX
	_wait_timer = 3.0
	_event_timer = 40.0
	_phase = Phase.WAITING
	var rush := " • Час пик!" if TaxiCareerManager.is_rush_hour() else ""
	status_label.text = "Ищем заказы…%s  ★ %.1f" % [rush, TaxiCareerManager.rating]
	_refresh_hud()


func _spawn_order() -> void:
	_current_order = JobManager.create_random_order()
	_phase = Phase.OFFER
	_offer_time_left = JobManager.OFFER_TIMEOUT_SEC
	waiting_content.visible = false
	offer_content.visible = true
	order_panel.visible = true
	var from_s: String = _current_order.get("from_street", "Точка А")
	var to_s: String = _current_order.get("to_street", "Точка Б")
	order_route.text = "%s\n↓\n%s" % [from_s, to_s]
	order_payout.text = "%s ₽" % GameState.format_amount(_current_order.get("payout", 0))
	var fuel: int = _current_order.get("fuel", 0)
	var district: String = _current_order.get("district_name", "—")
	var passenger: String = _current_order.get("passenger_label", "—")
	order_meta.text = (
		"%.1f км  •  −%d топливо  •  %s\n%s  •  %s"
		% [
			_current_order.get("distance", 0.0),
			fuel,
			_current_order.get("risk", "—"),
			district,
			passenger,
		]
	)
	if TaxiCareerManager.combo_streak >= 2:
		order_meta.text += "\nСерия %d — бонус к выплате!" % TaxiCareerManager.combo_streak
	var can_accept := _fuel >= fuel
	if swipe_confirm.has_method("set_locked"):
		swipe_confirm.set_locked(not can_accept)
	if can_accept and swipe_confirm.has_method("reset"):
		swipe_confirm.reset()
	else:
		status_label.text = "Мало топлива для этого заказа"
	skip_button.disabled = false


func _on_swipe_confirmed() -> void:
	if _current_order.is_empty() or _phase != Phase.OFFER:
		return
	_start_pickup()


func _decline_order() -> void:
	if _phase != Phase.OFFER:
		return
	_orders_declined += 1
	TaxiCareerManager.register_trip_complete(true)
	_close_offer()
	status_label.text = "Заказ пропущен"
	_enter_waiting(8.0)


func _start_pickup() -> void:
	var fuel: int = _current_order.get("fuel", 0)
	if _fuel < fuel:
		return
	_trip_phase_done = false
	_phase = Phase.PICKUP
	offer_content.visible = false
	order_panel.visible = false
	trip_progress.start_phase("Еду к клиенту", randf_range(2.0, 4.0))
	status_label.text = "Забираем пассажира…"
	if taxi_visual.has_method("start_drive"):
		taxi_visual.start_drive()


func _start_trip() -> void:
	_trip_phase_done = false
	_phase = Phase.TRIP
	var distance: float = _current_order.get("distance", 5.0)
	var duration := clampf(3.0 + distance * 0.15, 3.0, 8.0)
	trip_progress.start_phase("В пути с пассажиром", duration)
	status_label.text = "Везём клиента…"
	_offer_trip_event()


func _complete_trip() -> void:
	var fuel: int = _current_order.get("fuel", 0)
	var payout: int = _current_order.get("payout", 0)
	_fuel -= fuel
	_fuel_spent += fuel
	EconomyManager.register_expense(fuel, "Бензин (смена)", "shift")
	EconomyManager.register_income(payout, "Заказ такси", "shift")
	_gross_earned += payout
	_orders_accepted += 1
	TaxiCareerManager.register_trip_complete(false)
	_hide_trip_events()
	_show_payout_flash(payout)
	if taxi_visual.has_method("stop_drive"):
		taxi_visual.stop_drive()
	if taxi_visual.has_method("pulse_accept"):
		taxi_visual.pulse_accept()
	_current_order.clear()
	trip_progress.stop()
	_close_offer()
	_enter_waiting(randf_range(8.0, 15.0))


func _show_payout_flash(amount: int) -> void:
	payout_flash.text = "+%s ₽" % GameState.format_amount(amount)
	payout_flash.visible = true
	var tween := create_tween()
	tween.tween_property(payout_flash, "modulate:a", 0.0, 1.2).set_delay(0.8)
	tween.tween_callback(func(): payout_flash.visible = false; payout_flash.modulate.a = 1.0)


func _close_offer() -> void:
	order_panel.visible = false
	offer_content.visible = false
	waiting_content.visible = true


func _enter_waiting(delay: float) -> void:
	_phase = Phase.WAITING
	_wait_timer = delay
	status_label.text = "Ищем следующий заказ…"


func _on_random_event(message: String, amount: int) -> void:
	_event_delta += amount
	var sign := "+" if amount >= 0 else "−"
	event_label.text = "%s: %s%s ₽" % [message, sign, GameState.format_amount(absi(amount))]


func _on_end_shift_pressed() -> void:
	if not _shift_active:
		SceneNav.go_to(SceneNav.WORK_HUB)
		return
	_end_shift()


func _end_shift() -> void:
	if not _shift_active:
		return
	_shift_active = false
	var net := _gross_earned - _fuel_spent + _event_delta
	JobManager.set_shift_result(
		{
			"gross": _gross_earned,
			"fuel": _fuel_spent,
			"events": _event_delta,
			"net": net,
			"accepted": _orders_accepted,
			"declined": _orders_declined,
			"tax_owed": TaxManager.tax_owed,
		}
	)
	SceneNav.go_to(SceneNav.SHIFT_REPORT)


func _build_trip_event_ui() -> void:
	_trip_event_panel = HBoxContainer.new()
	_trip_event_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_trip_event_panel.visible = false
	add_child(_trip_event_panel)
	for label_text in ["Объезд", "Чаевые", "Жалоба"]:
		var b := Button.new()
		b.text = label_text
		var action := label_text
		b.pressed.connect(func(): _resolve_trip_event(action))
		_trip_event_panel.add_child(b)


func _offer_trip_event() -> void:
	if randf() > 0.45:
		_trip_event_resolved = true
		return
	_trip_event_resolved = false
	_trip_event_timer = 2.5
	_trip_event_panel.visible = true


func _hide_trip_events() -> void:
	_trip_event_resolved = true
	if _trip_event_panel:
		_trip_event_panel.visible = false


func _resolve_trip_event(action: String) -> void:
	if _trip_event_resolved:
		return
	_trip_event_resolved = true
	_hide_trip_events()
	match action:
		"Объезд":
			if EconomyManager.register_expense(50, "Объезд", "shift"):
				_event_delta -= 50
			event_label.text = "Объезд: −50 ₽"
		"Чаевые":
			EconomyManager.register_income(120, "Чаевые в поездке", "shift")
			_event_delta += 120
			event_label.text = "Чаевые: +120 ₽"
		"Жалоба":
			if EconomyManager.register_expense(200, "Жалоба пассажира", "shift"):
				_event_delta -= 200
			event_label.text = "Жалоба: −200 ₽"


func _refresh_hud() -> void:
	var minutes := int(_shift_time_left) / 60
	var seconds := int(_shift_time_left) % 60
	shift_timer_label.text = "Смена: %02d:%02d" % [minutes, seconds]
	fuel_label.text = "Топливо: %d%%" % _fuel
