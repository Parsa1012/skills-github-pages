class_name TouchActionButton
extends Control
## دکمه اکشن چندلمسی (تغییر سلاح / شارژ مجدد / جهش تاکتیکی) با پشتیبانی از نوار انتظار (Cooldown).

signal action_triggered()

@export var title_text: String = "تغییر سلاح"
@export var accent_color: Color = Color(0.219608, 0.741176, 0.972549, 1.0)

var _pressed: bool = false
var _touch_index: int = -1
var _cooldown_ratio: float = 0.0
var _override_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_reset_button()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_button()


func set_cooldown_state(cooldown_ratio: float, label_override: String = "") -> void:
	_cooldown_ratio = clampf(cooldown_ratio, 0.0, 1.0)
	_override_text = label_override
	queue_redraw()


func _reset_button() -> void:
	_touch_index = -1
	_pressed = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * touch.position
				if Rect2(Vector2.ZERO, size).has_point(local_pos):
					_touch_index = touch.index
					_pressed = true
					queue_redraw()
					action_triggered.emit()
		elif touch.index == _touch_index:
			_touch_index = -1
			_pressed = false
			queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var ready_alpha: float = 0.10 if _cooldown_ratio > 0.001 else (0.42 if _pressed else 0.18)
	var bg_col := Color(accent_color.r, accent_color.g, accent_color.b, ready_alpha)
	var border_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.38 if _cooldown_ratio > 0.001 else (0.95 if _pressed else 0.68))
	draw_rect(rect, bg_col, true)

	if _cooldown_ratio > 0.001:
		var ready_w: float = size.x * (1.0 - _cooldown_ratio)
		draw_rect(Rect2(Vector2.ZERO, Vector2(ready_w, size.y)), Color(accent_color.r, accent_color.g, accent_color.b, 0.24), true)

	draw_rect(rect, border_col, false, 2.0)

	var label_str: String = _override_text if not _override_text.is_empty() else title_text
	var font: Font = get_theme_default_font()
	if font != null and not label_str.is_empty():
		var font_size: int = 17 if SaveManager.large_text_enabled else 14
		var text_y: float = size.y * 0.5 + float(font_size) * 0.36
		var text_col := Color(0.85, 0.90, 0.96, 0.72) if _cooldown_ratio > 0.001 else Color(0.97, 0.98, 1.0, 0.96)
		draw_string(font, Vector2(0.0, text_y), label_str, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_col, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_RTL)
