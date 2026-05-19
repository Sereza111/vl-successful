extends Control

enum Phase { WAITING, OFFER, PICKUP, TRIP }
enum DriveMode { NORMAL, FAST, ECO }

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
@onready var shift_progress_bar: ProgressBar = %ShiftProgressBar
@onready var passenger_panel: PanelContainer = %PassengerPanel
@onready var passenger_text: Label = %PassengerText
@onready var choice_a: Button = %ChoiceA
@onready var choice_b: Button = %ChoiceB
@onready var drive_qte: Control = %DriveQte
@onready var drive_swipe: Control = %DriveSwipe
@onready var drive_mode_fast: Button = %DriveModeFast
@onready var drive_mode_eco: Button = %DriveModeEco
@onready var taxi_layer: CanvasLayer = $TaxiLayer

var _trip_event_panel: HBoxContainer
var _trip_event_timer: float = 0.0
var _trip_event_resolved: bool = true

var _phase: Phase = Phase.WAITING
var _shift_time_left: float = 0.0
var _wait_timer: float = 0.0
var _offer_time_left: float = 0.0
var _fuel: int = JobManager.SHIFT_FUEL_MAX
var _current_order: Dictionary = {}
var _shift_active: bool = false

var _gross_earned: int = 0
var _fuel_spent: int = 0
var _event_delta: int = 0
var _orders_accepted: int = 0
var _orders_declined: int = 0
var _trip_phase_done: bool = false

var _payout_mult_bonus: float = 1.0
var _extra_fuel_cost: int = 0
var _passenger_moment_done: bool = false
var _skill_event_done: bool = false
var _orders_since_skill: int = 0
var _passenger_timer: float = 0.0
var _drive_mode: DriveMode = DriveMode.NORMAL
var _trip_duration_mult: float = 1.0
var _event_timer: float = 0.0
var _interaction_queue: Array[String] = []
var _first_order_tutorial: bool = true


func _ready() -> void:
	order_panel.visible = false
	offer_content.visible = false
	waiting_content.visible = true
	payout_flash.visible = false
	passenger_panel.visible = false
	skip_button.pressed.connect(_decline_order)
	end_shift_button.pressed.connect(_on_end_shift_pressed)
	swipe_confirm.confirmed.connect(_on_swipe_confirmed)
	choice_a.pressed.connect(func(): _resolve_passenger_moment("a"))
	choice_b.pressed.connect(func(): _resolve_passenger_moment("b"))
	drive_qte.resolved.connect(_on_qte_resolved)
	drive_swipe.resolved.connect(_on_swipe_resolved)
	drive_mode_fast.pressed.connect(func(): _set_drive_mode(DriveMode.FAST))
	drive_mode_eco.pressed.connect(func(): _set_drive_mode(DriveMode.ECO))
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
	if passenger_panel.visible:
		_passenger_timer -= delta
		if has_node("%PassengerTimer"):
			%PassengerTimer.text = "⏱ %d" % maxi(1, int(ceil(_passenger_timer)))
		event_label.text = "%s  •  Ответьте за %d сек" % [
			passenger_text.text, maxi(1, int(ceil(_passenger_timer)))
		]
		if _passenger_timer <= 0.0:
			_resolve_passenger_moment("timeout")
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
	_payout_mult_bonus = 1.0
	_extra_fuel_cost = 0
	_passenger_moment_done = false
	_skill_event_done = false
	_drive_mode = DriveMode.NORMAL
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
	order_meta.text = (
		"%.1f км  •  −%d топливо  •  %s\n%s  •  %s"
		% [
			_current_order.get("distance", 0.0),
			fuel,
			_current_order.get("risk", "—"),
			_current_order.get("district_name", "—"),
			_current_order.get("passenger_label", "—"),
		]
	)
	if TaxiCareerManager.combo_streak >= 2:
		order_meta.text += "\nСерия %d — бонус!" % TaxiCareerManager.combo_streak
	var can_accept := _fuel >= fuel
	if swipe_confirm.has_method("set_locked"):
		swipe_confirm.set_locked(not can_accept)
	if can_accept and swipe_confirm.has_method("reset"):
		swipe_confirm.reset()
	else:
		status_label.text = "Мало топлива"
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
	_hide_drive_ui()
	if taxi_visual.has_method("start_drive"):
		var district_id: String = _current_order.get("district_id", "center")
		taxi_visual.start_drive(district_id)
	if _first_order_tutorial or randf() < 0.7:
		_offer_passenger_moment()


func _start_trip() -> void:
	_trip_phase_done = false
	_phase = Phase.TRIP
	var distance: float = _current_order.get("distance", 5.0)
	var duration := clampf((3.0 + distance * 0.15) * _trip_duration_mult, 3.0, 10.0)
	trip_progress.start_phase("В пути с пассажиром", duration)
	status_label.text = "Везём клиента…"
	_show_drive_mode_buttons()
	_build_trip_interaction_queue()
	_advance_interaction_queue()


func _build_trip_interaction_queue() -> void:
	_interaction_queue.clear()
	if not _passenger_moment_done:
		_interaction_queue.append("moment")
	if not _skill_event_done and (_orders_since_skill >= 1 or _passenger_moment_done):
		_interaction_queue.append("skill" if randf() < 0.55 else "swipe")
	elif randf() < 0.2:
		_interaction_queue.append("legacy")


func _advance_interaction_queue() -> void:
	if _interaction_queue.is_empty():
		return
	var next: String = _interaction_queue.pop_front()
	match next:
		"moment":
			_offer_passenger_moment()
		"skill":
			drive_qte.start()
			_skill_event_done = true
		"swipe":
			drive_swipe.start()
			_skill_event_done = true
		"legacy":
			_offer_legacy_trip_event()


func _complete_trip() -> void:
	var fuel: int = _current_order.get("fuel", 0) + _extra_fuel_cost
	var payout: int = int(round(_current_order.get("payout", 0) * _payout_mult_bonus))
	_fuel -= fuel
	_fuel_spent += fuel
	EconomyManager.register_expense(fuel, "Бензин (смена)", "shift")
	EconomyManager.register_income(payout, "Заказ такси", "shift")
	_gross_earned += payout
	_orders_accepted += 1
	_orders_since_skill += 1
	_first_order_tutorial = false
	TaxiCareerManager.register_trip_complete(false)
	_hide_drive_ui()
	_show_payout_flash(payout)
	if taxi_visual.has_method("stop_drive"):
		taxi_visual.stop_drive()
	if taxi_visual.has_method("pulse_accept"):
		taxi_visual.pulse_accept()
	_current_order.clear()
	trip_progress.stop()
	_close_offer()
	_enter_waiting(randf_range(8.0, 15.0))


func _offer_passenger_moment() -> void:
	var ptype: String = _current_order.get("passenger_type", "econom")
	var plabel: String = _current_order.get("passenger_label", "Пассажир")
	var moment: Dictionary = PassengerMoments.get_moment(ptype)
	var line: String = moment.get("text", "…")
	passenger_text.text = line
	choice_a.text = moment.get("choice_a", "A")
	choice_b.text = moment.get("choice_b", "B")
	passenger_panel.visible = true
	_passenger_timer = 4.0
	_passenger_moment_done = true
	status_label.text = "%s говорит:" % plabel
	event_label.text = "%s  •  Ответьте за %d сек" % [line, int(ceil(_passenger_timer))]
	if has_node("%PassengerTimer"):
		%PassengerTimer.text = "⏱ %d" % int(ceil(_passenger_timer))
	if has_node("%InteractionDock"):
		%InteractionDock.move_to_front()
	passenger_panel.move_to_front()


func _resolve_passenger_moment(choice: String) -> void:
	if not passenger_panel.visible:
		return
	passenger_panel.visible = false
	var ptype: String = _current_order.get("passenger_type", "econom")
	var moment: Dictionary = PassengerMoments.get_moment(ptype)
	var effect: Dictionary = moment.get("effect_a", {}) if choice == "a" else moment.get("effect_b", {})
	if choice == "timeout":
		effect = {}
	_apply_moment_effect(effect)
	if taxi_visual.has_method("pulse_accept"):
		taxi_visual.pulse_accept()
	_advance_interaction_queue()


func _apply_moment_effect(effect: Dictionary) -> void:
	if effect.is_empty():
		event_label.text = "Пассажир промолчал — без изменений"
		return
	if effect.has("rating"):
		TaxiCareerManager.adjust_rating(float(effect.rating))
	if effect.has("payout_mult"):
		_payout_mult_bonus *= float(effect.payout_mult)
	if effect.has("tip"):
		var tip: int = int(effect.tip)
		EconomyManager.register_income(tip, "Чаевые пассажира", "shift")
		_event_delta += tip
		event_label.text = "+%s ₽ чаевые" % GameState.format_amount(tip)
	elif effect.has("fuel"):
		_extra_fuel_cost += int(effect.fuel)
		event_label.text = "Доп. топливо −%d" % int(effect.fuel)
	elif effect.has("payout_mult") and float(effect.payout_mult) < 1.0:
		event_label.text = "Скидка пассажиру"
	elif effect.has("payout_mult") and float(effect.payout_mult) > 1.0:
		event_label.text = "Срочная поездка — бонус!"
	else:
		event_label.text = "Решение принято"
	TaxiCareerManager.add_xp(5)


func _on_qte_resolved(success: bool) -> void:
	if success:
		_payout_mult_bonus *= 1.08
		EconomyManager.register_income(50, "QTE — чаевые", "shift")
		_event_delta += 50
		event_label.text = "Идеальный момент! +8%"
	else:
		_extra_fuel_cost += 3
		event_label.text = "Промах — лишний расход"
	if taxi_visual.has_method("pulse_accept"):
		taxi_visual.pulse_accept()
	_advance_interaction_queue()


func _on_swipe_resolved(success: bool) -> void:
	if success:
		EconomyManager.register_income(60, "Объезд — бонус", "shift")
		_event_delta += 60
		event_label.text = "Уверенный объезд +60 ₽"
	else:
		if EconomyManager.register_expense(80, "Пробка", "shift"):
			_event_delta -= 80
		event_label.text = "Пробка −80 ₽"


func _set_drive_mode(mode: DriveMode) -> void:
	_drive_mode = mode
	match mode:
		DriveMode.FAST:
			_trip_duration_mult = 0.85
			_extra_fuel_cost += 2
			event_label.text = "Режим: быстро"
		DriveMode.ECO:
			_trip_duration_mult = 1.15
			event_label.text = "Режим: эконом"
		_:
			_trip_duration_mult = 1.0


func _show_drive_mode_buttons() -> void:
	drive_mode_fast.visible = true
	drive_mode_eco.visible = true


func _hide_drive_ui() -> void:
	passenger_panel.visible = false
	_interaction_queue.clear()
	drive_qte.stop()
	drive_swipe.stop()
	drive_mode_fast.visible = false
	drive_mode_eco.visible = false
	_hide_trip_events()
	if has_node("%PassengerTimer"):
		%PassengerTimer.text = ""


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
	_trip_duration_mult = 1.0
	status_label.text = "Ищем следующий заказ…"


func _on_random_event(message: String, amount: int) -> void:
	_event_delta += amount
	var amount_sign := "+" if amount >= 0 else "−"
	event_label.text = "%s: %s%s ₽" % [message, amount_sign, GameState.format_amount(absi(amount))]


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
	if has_node("%InteractionDock"):
		%InteractionDock.add_child(_trip_event_panel)
	else:
		add_child(_trip_event_panel)
	for label_text in ["Объезд", "Чаевые", "Жалоба"]:
		var b := Button.new()
		b.text = label_text
		b.pressed.connect(_resolve_legacy_trip_event.bind(label_text))
		_trip_event_panel.add_child(b)


func _offer_legacy_trip_event() -> void:
	_trip_event_resolved = false
	_trip_event_timer = 2.5
	_trip_event_panel.visible = true


func _hide_trip_events() -> void:
	_trip_event_resolved = true
	if _trip_event_panel:
		_trip_event_panel.visible = false


func _resolve_legacy_trip_event(action: String) -> void:
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
			EconomyManager.register_income(120, "Чаевые", "shift")
			_event_delta += 120
			event_label.text = "Чаевые: +120 ₽"
		"Жалоба":
			if EconomyManager.register_expense(200, "Жалоба", "shift"):
				_event_delta -= 200
			event_label.text = "Жалоба: −200 ₽"


func _refresh_hud() -> void:
	var minutes := int(_shift_time_left) / 60
	var seconds := int(_shift_time_left) % 60
	shift_timer_label.text = "Смена: %02d:%02d" % [minutes, seconds]
	fuel_label.text = "Топливо: %d%%" % _fuel
	if shift_progress_bar:
		shift_progress_bar.value = _shift_time_left / JobManager.SHIFT_DURATION_SEC
