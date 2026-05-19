extends Node2D

@onready var body: Polygon2D = $Body
@onready var roof: Polygon2D = $Roof
@onready var window_glass: Polygon2D = $Window
@onready var wheel_left: Polygon2D = $WheelLeft
@onready var wheel_right: Polygon2D = $WheelRight
@onready var checker: Line2D = $Checker
@onready var headlight: Polygon2D = $Headlight
@onready var route_line: Line2D = $RouteLine

var _drive_tween: Tween
var _route_tween: Tween
var _base_y: float

const DISTRICT_OFFSETS: Dictionary = {
	"center": Vector2(0, 0),
	"port": Vector2(-80, 20),
	"industrial": Vector2(100, -30),
	"suburbs": Vector2(-40, 60),
	"airport": Vector2(120, 40),
}


func _ready() -> void:
	_base_y = position.y
	_build_taxi()
	if route_line:
		route_line.visible = false
		route_line.width = 3.0
		route_line.default_color = Color(0.4, 0.75, 1.0, 0.85)


func pulse_accept() -> void:
	var base_scale := scale
	var tween := create_tween()
	tween.tween_property(self, "scale", base_scale * 1.08, 0.12)
	tween.tween_property(self, "scale", base_scale, 0.15)


func start_drive(district_id: String = "center") -> void:
	if _drive_tween:
		_drive_tween.kill()
	_drive_tween = create_tween().set_loops()
	_drive_tween.tween_property(self, "position:y", _base_y - 4.0, 0.35).set_trans(Tween.TRANS_SINE)
	_drive_tween.tween_property(self, "position:y", _base_y + 4.0, 0.35).set_trans(Tween.TRANS_SINE)
	_show_route(district_id)


func stop_drive() -> void:
	if _drive_tween:
		_drive_tween.kill()
		_drive_tween = null
	if _route_tween:
		_route_tween.kill()
		_route_tween = null
	position.y = _base_y
	if route_line:
		route_line.visible = false


func _show_route(district_id: String) -> void:
	if not route_line:
		return
	var off: Vector2 = DISTRICT_OFFSETS.get(district_id, Vector2.ZERO)
	var start := Vector2(-120, 30) + off * 0.3
	var end := Vector2(140, -20) + off
	route_line.points = PackedVector2Array([start, Vector2(0, -40) + off * 0.5, end])
	route_line.visible = true
	if _route_tween:
		_route_tween.kill()
	_route_tween = create_tween().set_loops()
	_route_tween.tween_property(route_line, "modulate:a", 0.45, 0.6)
	_route_tween.tween_property(route_line, "modulate:a", 1.0, 0.6)


func set_car_tier(tier: int) -> void:
	var colors := [
		Color(0.98, 0.82, 0.12),
		Color(0.2, 0.55, 0.95),
		Color(0.15, 0.15, 0.18),
	]
	var c: Color = colors[mini(tier, colors.size() - 1)]
	body.color = c
	roof.color = c.darkened(0.15)
	if tier >= 2:
		scale = Vector2(1.08, 1.08)


func _build_taxi() -> void:
	body.polygon = PackedVector2Array([
		Vector2(-72, -20),
		Vector2(80, -20),
		Vector2(92, 0),
		Vector2(80, 20),
		Vector2(-72, 20),
		Vector2(-86, 0),
	])
	body.color = Color(0.98, 0.82, 0.12)

	roof.polygon = PackedVector2Array([
		Vector2(-24, -34),
		Vector2(40, -34),
		Vector2(50, -18),
		Vector2(-14, -18),
	])
	roof.color = Color(0.88, 0.72, 0.1)

	window_glass.polygon = PackedVector2Array([
		Vector2(-10, -32),
		Vector2(36, -32),
		Vector2(42, -22),
		Vector2(-4, -22),
	])
	window_glass.color = Color(0.5, 0.72, 0.92, 0.95)

	headlight.polygon = PackedVector2Array([
		Vector2(82, -8),
		Vector2(94, -4),
		Vector2(94, 4),
		Vector2(82, 8),
	])
	headlight.color = Color(1.0, 0.95, 0.7, 0.9)

	wheel_left.polygon = _circle_polygon(Vector2(-44, 24), 12, 14)
	wheel_left.color = Color(0.1, 0.1, 0.12)
	wheel_right.polygon = _circle_polygon(Vector2(50, 24), 12, 14)
	wheel_right.color = Color(0.1, 0.1, 0.12)

	checker.points = PackedVector2Array([
		Vector2(-12, 4),
		Vector2(4, 4),
		Vector2(4, 16),
		Vector2(-12, 16),
		Vector2(-12, 4),
		Vector2(4, 16),
	])
	checker.width = 2.5
	checker.default_color = Color(0.08, 0.08, 0.1)


func _circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
