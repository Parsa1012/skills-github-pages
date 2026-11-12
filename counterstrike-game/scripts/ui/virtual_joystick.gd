class_name VirtualJoystick
extends Control
## جوی‌استیک لمسی چندلمسی مستقل (Multi-Touch) برای موبایل با پشتیبانی از شبیه‌سازی ماوس و ناحیه امن.

signal stick_updated(vector: Vector2, is_active: bool, is_fire_zone: bool)

@export var stick_title: String = "حرکت"
@export var accent_color: Color = Color(0.219608, 0.741176, 0.972549, 1.0)
@export var fire_accent_color: Color = Color(0.984314, 0.45098, 0.086275, 1.0)
@export var deadzone_ratio: float = 0.14
@export var max_radius: float = 76.0
@export var knob_radius: float = 28.0
@export var floating_origin: bool = true
@export var enable_fire_threshold: bool = false
@export_range(0.55, 0.95, 0.01) var fire_threshold_ratio: float = 0.74

var output_vector: Vector2 = Vector2.ZERO
var is_active: bool = false
var is_fire_engaged: bool = false
var excluded_controls: Array[Control] = []

var _touch_index: int = -1
var _base_center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_to_rest()
	resized.connect(_on_resized)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		reset_stick()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_stick()


func _on_resized() -> void:
	if _touch_index == -1:
		_reset_to_rest()
		queue_redraw()


func reset_stick() -> void:
	var was_active: bool = is_active or output_vector != Vector2.ZERO or is_fire_engaged
	_touch_index = -1
	is_active = false
	is_fire_engaged = false
	output_vector = Vector2.ZERO
	_reset_to_rest()
	queue_redraw()
	if was_active:
		stick_updated.emit(Vector2.ZERO, false, false)


func _reset_to_rest() -> void:
	_base_center = _get_rest_center()
	_knob_offset = Vector2.ZERO


func _get_rest_center() -> Vector2:
	var pad: float = max_radius + 20.0
	var cx: float = clampf(size.x * 0.5, pad, maxf(pad, size.x - pad))
	var cy: float = clampf(size.y * 0.60, pad, maxf(pad, size.y - pad))
	return Vector2(cx, cy)


func _clamp_base_center(local_pos: Vector2) -> Vector2:
	var pad: float = max_radius + 12.0
	var max_x: float = maxf(pad, size.x - pad)
	var max_y: float = maxf(pad, size.y - pad)
	return Vector2(
		clampf(local_pos.x, pad, max_x),
		clampf(local_pos.y, pad, max_y)
	)


func _is_point_excluded(canvas_pos: Vector2) -> bool:
	for ctrl in excluded_controls:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.is_visible_in_tree():
			if ctrl.get_global_rect().grow(6.0).has_point(canvas_pos):
				return true
	return false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				if _is_point_excluded(touch.position):
					return
				var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * touch.position
				if Rect2(Vector2.ZERO, size).has_point(local_pos):
					_touch_index = touch.index
					is_active = true
					_base_center = _clamp_base_center(local_pos) if floating_origin else _get_rest_center()
					_update_stick_from_local(local_pos)
		elif touch.index == _touch_index:
			reset_stick()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * drag.position
			_update_stick_from_local(local_pos)


func _update_stick_from_local(local_pos: Vector2) -> void:
	var delta: Vector2 = local_pos - _base_center
	var dist: float = delta.length()
	var effective_radius: float = maxf(max_radius, 16.0)

	if dist > effective_radius:
		_knob_offset = delta.normalized() * effective_radius
	else:
		_knob_offset = delta

	var raw_norm: float = clampf(dist / effective_radius, 0.0, 1.0)
	if raw_norm <= deadzone_ratio or dist < 0.001:
		output_vector = Vector2.ZERO
		is_fire_engaged = false
	else:
		var scaled: float = (raw_norm - deadzone_ratio) / maxf(1.0 - deadzone_ratio, 0.01)
		output_vector = delta.normalized() * clampf(scaled, 0.0, 1.0)
		is_fire_engaged = enable_fire_threshold and (raw_norm >= fire_threshold_ratio)

	queue_redraw()
	stick_updated.emit(output_vector, is_active, is_fire_engaged)


func _draw() -> void:
	var alpha_mult: float = 0.95 if is_active else 0.45
	var active_col: Color = fire_accent_color if is_fire_engaged else accent_color

	var bg_col := Color(0.05, 0.08, 0.14, 0.46 * alpha_mult)
	draw_circle(_base_center, max_radius, bg_col)

	var ring_col := Color(active_col.r, active_col.g, active_col.b, 0.85 * alpha_mult)
	draw_arc(_base_center, max_radius, 0.0, TAU, 40, ring_col, 3.0, true)

	if enable_fire_threshold:
		var fire_ring_r: float = max_radius * fire_threshold_ratio
		var fire_ring_col := Color(fire_accent_color.r, fire_accent_color.g, fire_accent_color.b, (0.80 if is_fire_engaged else 0.35) * alpha_mult)
		draw_arc(_base_center, fire_ring_r, 0.0, TAU, 32, fire_ring_col, 2.0, true)

	var cross_col := Color(1.0, 1.0, 1.0, 0.14 * alpha_mult)
	draw_line(_base_center + Vector2(-14, 0), _base_center + Vector2(14, 0), cross_col, 1.5, true)
	draw_line(_base_center + Vector2(0, -14), _base_center + Vector2(0, 14), cross_col, 1.5, true)

	var knob_pos: Vector2 = _base_center + _knob_offset
	var knob_fill := Color(active_col.r, active_col.g, active_col.b, 0.88 * alpha_mult)
	draw_circle(knob_pos, knob_radius, knob_fill)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 28, Color(0.97, 0.98, 1.0, 0.90 * alpha_mult), 2.5, true)

	var font: Font = get_theme_default_font()
	if font != null and not stick_title.is_empty():
		var text_col := Color(0.95, 0.97, 1.0, 0.80 if not is_active else 0.40)
		var label_pos := _base_center + Vector2(-56.0, max_radius + 16.0)
		draw_string(font, label_pos, stick_title, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 14, text_col, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_RTL)
