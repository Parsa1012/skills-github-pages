class_name HitDirectionIndicator
extends Control
## کمان جهت‌نمای آسیب روی صفحه برای تشخیص سریع سمت شلیک دشمن.

const PULSE_DURATION: float = 0.65

var _pulses: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_hit_direction(angle_rad: float) -> void:
	_pulses.append({"angle": angle_rad, "timer": PULSE_DURATION})
	if _pulses.size() > 4:
		_pulses.remove_at(0)
	queue_redraw()


func _process(delta: float) -> void:
	if _pulses.is_empty():
		return
	for i in range(_pulses.size() - 1, -1, -1):
		var item: Dictionary = _pulses[i]
		item["timer"] = float(item["timer"]) - delta
		if float(item["timer"]) <= 0.0:
			_pulses.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if _pulses.is_empty():
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.24
	for item in _pulses:
		var t: float = clampf(float(item["timer"]) / PULSE_DURATION, 0.0, 1.0)
		var ui_angle: float = float(item["angle"]) - PI * 0.5
		var col := Color(0.937255, 0.266667, 0.266667, t * 0.88)
		draw_arc(center, radius, ui_angle - 0.34, ui_angle + 0.34, 16, col, 6.0, true)
		draw_arc(center, radius - 5.0, ui_angle - 0.22, ui_angle + 0.22, 12, Color(0.984314, 0.572549, 0.235294, t * 0.72), 2.5, true)
